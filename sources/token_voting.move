module dao_creator::token_voting {
    use std::signer;
    use std::string::{Self, String};
    
    struct TokenVotingModule has key {
        name: String,
        description: String,
    }
    
    struct TokenVotingPower has key {
        power: u64,
    }
    
    const ERROR_UNAUTHORIZED: u64 = 1;
    
    // Initialize the token voting module
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @dao_creator, ERROR_UNAUTHORIZED);
        
        if (!exists<TokenVotingModule>(admin_addr)) {
            move_to(admin, TokenVotingModule {
                name: string::utf8(b"TokenVoting"),
                description: string::utf8(b"Voting power based on token holdings"),
            });
        };
    }
    
public entry fun set_voting_power(
    admin: &signer, 
    user: address, 
    power: u64
) acquires TokenVotingPower {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @dao_creator, ERROR_UNAUTHORIZED);
        
        if (exists<TokenVotingPower>(user)) {
            let voting_power = borrow_global_mut<TokenVotingPower>(user);
            voting_power.power = power;
        } else {
            move_to(admin, TokenVotingPower { power });
        }
    }
    
    public fun get_voting_power(user: address): u64 acquires TokenVotingPower {
        if (exists<TokenVotingPower>(user)) {
            borrow_global<TokenVotingPower>(user).power
        } else {
            0
        }
    }
}