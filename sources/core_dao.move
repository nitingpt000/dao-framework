module dao_creator::core_dao {
    use std::string::String;
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::timestamp;
    use aptos_framework::table::{Self, Table};
    
    // error codes
    const ERROR_UNAUTHORIZED: u64 = 1;
    const ERROR_DAO_EXISTS: u64 = 2;
    const ERROR_DAO_NOT_FOUND: u64 = 3;
    const ERROR_PROPOSAL_NOT_FOUND: u64 = 4;
    const ERROR_PROPOSAL_ACTIVE: u64 = 5;
    const ERROR_PROPOSAL_EXPIRED: u64 = 6;
    const ERROR_ALREADY_VOTED: u64 = 7;
    const ERROR_VOTING_POWER_REQUIRED: u64 = 8;
    const ERROR_QUORUM_NOT_REACHED: u64 = 9;
    
    struct DAOConfig has key, store {
        admin: address,
        name: String,
        description: String,
        voting_module_address: address,
        voting_module_name: String,
        minimum_voting_power: u64,
        quorum_votes: u64,
        voting_period: u64, // in seconds
        execution_delay: u64, // in seconds
        create_proposal_events: EventHandle<CreateProposalEvent>,
        vote_events: EventHandle<VoteEvent>,
        execute_events: EventHandle<ExecuteEvent>,
    }
    
    struct DAORegistry has key {
        daos: vector<address>,
    }
    
    struct ProposalStore has key {
        proposals: Table<u64, Proposal>,
        next_proposal_id: u64,
    }
    
    struct Proposal has store {
        id: u64,
        creator: address,
        description: String,
        execution_script: vector<u8>,
        script_args: vector<vector<u8>>,
        creation_time: u64,
        expiration_time: u64,
        execution_time: u64,
        yes_votes: u64,
        no_votes: u64,
        abstain_votes: u64,
        executed: bool,
        voters: Table<address, bool>, 
    }
    
    struct VotingPower has key {
        power: u64,
    }
    
    // events
    struct CreateProposalEvent has drop, store {
        proposal_id: u64,
        creator: address,
        description: String,
        creation_time: u64,
    }
    
    struct VoteEvent has drop, store {
        proposal_id: u64,
        voter: address,
        vote: u8, // 0 = no, 1 = yes, 2 = abstain
        voting_power: u64,
        time: u64,
    }
    
    struct ExecuteEvent has drop, store {
        proposal_id: u64,
        executor: address,
        execution_time: u64,
    }
    
    struct VotingModuleRegistry has key {
        modules: vector<String>,
    }
    
    struct VotingModule has store {
        name: String,
        description: String,
    }
    
public fun get_voting_power(
    _voting_module_address: address, 
    _voting_module_name: String, 
    voter: address
): u64 acquires VotingPower {
    if (exists<VotingPower>(voter)) {
        borrow_global<VotingPower>(voter).power
    } else {
        0
    }
}
    
    
    // Initialize the DAO registry
    public entry fun initialize_registry(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        if (!exists<DAORegistry>(admin_addr)) {
            move_to(admin, DAORegistry {
                daos: vector::empty(),
            });
        };
        
        if (!exists<VotingModuleRegistry>(admin_addr)) {
            move_to(admin, VotingModuleRegistry {
                modules: vector::empty(),
            });
        };
    }
    
    // Create a new DAO
public entry fun create_dao(
    creator: &signer,
    name: String,
    description: String,
    voting_module_address: address,
    voting_module_name: String,
    minimum_voting_power: u64,
    quorum_votes: u64,
    voting_period: u64,
    execution_delay: u64
) acquires DAORegistry {
        let creator_addr = signer::address_of(creator);
        assert!(!exists<DAOConfig>(creator_addr), ERROR_DAO_EXISTS);
        
        let dao_config = DAOConfig {
            admin: creator_addr,
            name,
            description,
            voting_module_address,
            voting_module_name,
            minimum_voting_power,
            quorum_votes,
            voting_period,
            execution_delay,
            create_proposal_events: account::new_event_handle<CreateProposalEvent>(creator),
            vote_events: account::new_event_handle<VoteEvent>(creator),
            execute_events: account::new_event_handle<ExecuteEvent>(creator),
        };
        
        move_to(creator, dao_config);
        move_to(creator, ProposalStore {
            proposals: table::new(),
            next_proposal_id: 0,
        });
        
        // Register the DAO in the registry
        if (exists<DAORegistry>(@dao_creator)) {
            let registry = borrow_global_mut<DAORegistry>(@dao_creator);
            vector::push_back(&mut registry.daos, creator_addr);
        };
    }
    
    // Create a new proposal
public entry fun create_proposal(
    creator: &signer,
    dao_address: address,
    description: String,
    execution_script: vector<u8>,
    script_args: vector<vector<u8>>
) acquires DAOConfig, ProposalStore, VotingPower {
        assert!(exists<DAOConfig>(dao_address), ERROR_DAO_NOT_FOUND);
        
        let creator_addr = signer::address_of(creator);
        let dao_config = borrow_global<DAOConfig>(dao_address);
        
        // check the voting power
        let voting_power = get_voting_power(
            dao_config.voting_module_address,
            dao_config.voting_module_name,
            creator_addr
        );
        
        assert!(voting_power >= dao_config.minimum_voting_power, ERROR_VOTING_POWER_REQUIRED);
        
        let proposal_store = borrow_global_mut<ProposalStore>(dao_address);
        let proposal_id = proposal_store.next_proposal_id;
        
        let now = timestamp::now_seconds();
        let expiration_time = now + dao_config.voting_period;
        
        let proposal = Proposal {
            id: proposal_id,
            creator: creator_addr,
            description,
            execution_script,
            script_args,
            creation_time: now,
            expiration_time,
            execution_time: 0,
            yes_votes: 0,
            no_votes: 0,
            abstain_votes: 0,
            executed: false,
            voters: table::new(),
        };
        
        table::add(&mut proposal_store.proposals, proposal_id, proposal);
        proposal_store.next_proposal_id = proposal_id + 1;
        
        event::emit_event(
            &mut borrow_global_mut<DAOConfig>(dao_address).create_proposal_events,
            CreateProposalEvent {
                proposal_id,
                creator: creator_addr,
                description: description,
                creation_time: now,
            }
        );
    }
    
public entry fun vote(
    voter: &signer,
    dao_address: address,
    proposal_id: u64,
    vote_type: u8 // 0 = no, 1 = yes, 2 = abstain
) acquires DAOConfig, ProposalStore, VotingPower {
        assert!(exists<DAOConfig>(dao_address), ERROR_DAO_NOT_FOUND);
        let voter_addr = signer::address_of(voter);
        
        let dao_config = borrow_global<DAOConfig>(dao_address);
        let proposal_store = borrow_global_mut<ProposalStore>(dao_address);
        
        assert!(table::contains(&proposal_store.proposals, proposal_id), ERROR_PROPOSAL_NOT_FOUND);
        let proposal = table::borrow_mut(&mut proposal_store.proposals, proposal_id);
        
        let now = timestamp::now_seconds();
        assert!(now <= proposal.expiration_time, ERROR_PROPOSAL_EXPIRED);
        
        assert!(!table::contains(&proposal.voters, voter_addr), ERROR_ALREADY_VOTED);
        
        let voting_power = get_voting_power(
            dao_config.voting_module_address,
            dao_config.voting_module_name,
            voter_addr
        );
        
        assert!(voting_power > 0, ERROR_VOTING_POWER_REQUIRED);
        
        table::add(&mut proposal.voters, voter_addr, true);
        
        if (vote_type == 0) {
            proposal.no_votes = proposal.no_votes + voting_power;
        } else if (vote_type == 1) {
            proposal.yes_votes = proposal.yes_votes + voting_power;
        } else if (vote_type == 2) {
            proposal.abstain_votes = proposal.abstain_votes + voting_power;
        };
        
        event::emit_event(
            &mut borrow_global_mut<DAOConfig>(dao_address).vote_events,
            VoteEvent {
                proposal_id,
                voter: voter_addr,
                vote: vote_type,
                voting_power,
                time: now,
            }
        );
    }
    
    public entry fun execute_proposal(
        executor: &signer,
        dao_address: address,
        proposal_id: u64
    ) acquires DAOConfig, ProposalStore {
        assert!(exists<DAOConfig>(dao_address), ERROR_DAO_NOT_FOUND);
        
        let proposal_store = borrow_global_mut<ProposalStore>(dao_address);
        assert!(table::contains(&proposal_store.proposals, proposal_id), ERROR_PROPOSAL_NOT_FOUND);
        
        let proposal = table::borrow_mut(&mut proposal_store.proposals, proposal_id);
        assert!(!proposal.executed, ERROR_PROPOSAL_ACTIVE);
        
        let now = timestamp::now_seconds();
        assert!(now > proposal.expiration_time, ERROR_PROPOSAL_ACTIVE);
        
        let dao_config = borrow_global<DAOConfig>(dao_address);
        
        assert!(proposal.yes_votes > proposal.no_votes, ERROR_UNAUTHORIZED);
        assert!(proposal.yes_votes + proposal.no_votes + proposal.abstain_votes >= dao_config.quorum_votes, ERROR_QUORUM_NOT_REACHED);
        
        assert!(now >= proposal.expiration_time + dao_config.execution_delay, ERROR_PROPOSAL_ACTIVE);
        
        proposal.executed = true;
        proposal.execution_time = now;
        
        event::emit_event(
            &mut borrow_global_mut<DAOConfig>(dao_address).execute_events,
            ExecuteEvent {
                proposal_id,
                executor: signer::address_of(executor),
                execution_time: now,
            }
        );
        

    }
    
    
public entry fun set_voting_power(
    admin: &signer,
    user: address,
    power: u64
) acquires VotingPower {
    let admin_addr = signer::address_of(admin);
    assert!(admin_addr == @dao_creator, ERROR_UNAUTHORIZED);
    
    if (exists<VotingPower>(user)) {
        let voting_power = borrow_global_mut<VotingPower>(user);
        voting_power.power = power;
    } else {
        let (resource_signer, _resource_cap) = account::create_resource_account(admin, b"voting_power");
        move_to(&resource_signer, VotingPower { power });
    }
}
    
    
    #[view]
    public fun get_dao_info(dao_address: address): (String, String, u64, u64) acquires DAOConfig {
        assert!(exists<DAOConfig>(dao_address), ERROR_DAO_NOT_FOUND);
        let config = borrow_global<DAOConfig>(dao_address);
        
        (config.name, config.description, config.minimum_voting_power, config.quorum_votes)
    }
    
    #[view]
    public fun get_proposal_info(dao_address: address, proposal_id: u64): (String, address, u64, u64, u64, u64, bool) 
        acquires ProposalStore {
        assert!(exists<ProposalStore>(dao_address), ERROR_DAO_NOT_FOUND);
        let proposal_store = borrow_global<ProposalStore>(dao_address);
        assert!(table::contains(&proposal_store.proposals, proposal_id), ERROR_PROPOSAL_NOT_FOUND);
        
        let proposal = table::borrow(&proposal_store.proposals, proposal_id);
        
        (
            proposal.description,
            proposal.creator,
            proposal.yes_votes,
            proposal.no_votes,
            proposal.abstain_votes,
            proposal.expiration_time,
            proposal.executed
        )
    }
    
    #[view]
    public fun get_proposal_count(dao_address: address): u64 acquires ProposalStore {
        assert!(exists<ProposalStore>(dao_address), ERROR_DAO_NOT_FOUND);
        let proposal_store = borrow_global<ProposalStore>(dao_address);
        proposal_store.next_proposal_id
    }
}