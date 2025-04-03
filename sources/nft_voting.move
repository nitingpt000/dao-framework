module dao_creator::nft_voting {
    use std::signer;
    use std::string::{Self, String};
    
    struct NFTVotingModule has key {
        name: String,
        description: String,
    }
    
    struct NFTVotingPower has key {
        nft_count: u64,
        multiplier: u64,
    }
    
    const ERROR_UNAUTHORIZED: u64 = 1;
    
    // Initialize the NFT voting module
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @dao_creator, ERROR_UNAUTHORIZED);
        
        if (!exists<NFTVotingModule>(admin_addr)) {
            move_to(admin, NFTVotingModule {
                name: string::utf8(b"NFTVoting"),
                description: string::utf8(b"Voting power based on NFT holdings"),
            });
        };
    }
    
public entry fun set_voting_power(
    admin: &signer, 
    user: address, 
    nft_count: u64, 
    multiplier: u64
) acquires NFTVotingPower {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @dao_creator, ERROR_UNAUTHORIZED);
        
        if (exists<NFTVotingPower>(user)) {
            let voting_power = borrow_global_mut<NFTVotingPower>(user);
            voting_power.nft_count = nft_count;
            voting_power.multiplier = multiplier;
        } else {
            move_to(admin, NFTVotingPower { 
                nft_count,
                multiplier
            });
        }
    }
    
    public fun get_voting_power(user: address): u64 acquires NFTVotingPower {
        if (exists<NFTVotingPower>(user)) {
            let voting_power = borrow_global<NFTVotingPower>(user);
            voting_power.nft_count * voting_power.multiplier
        } else {
            0
        }
    }
}