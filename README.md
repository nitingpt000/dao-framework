# DAO Framework

A composable, flexible DAO (Decentralized Autonomous Organization) governance system built on Aptos Move.

## Overview

This framework provides a complete solution for creating and managing DAOs with pluggable voting mechanisms.

## Key Features

- **Pluggable Voting**: Switch between different voting mechanisms (token-based, NFT-based)
- **Proposal Management**: Complete lifecycle for proposals with creation, voting, and execution
- **Governance Controls**: Configurable voting periods, quorum requirements, and execution delays
- **Event System**: Comprehensive event emission for tracking DAO activities

## Architecture

The framework consists of three main modules:

1. **Core DAO Module**: Manages DAOs, proposals, voting, and execution
2. **Token Voting Module**: Implements token-weighted voting
3. **NFT Voting Module**: Implements NFT-based voting

### Directory Structure

```
dao-framework/
├── Move.toml                // Project configuration
├── README.md                // Documentation
└── sources/                 // Move code files
    ├── core_dao.move        // Core DAO functionality
    ├── token_voting.move    // Token-based voting module
    └── nft_voting.move      // NFT-based voting module
```

## Getting Started

### Prerequisites

- Aptos CLI installed
- An Aptos account with funds on devnet

### Installation

1. Clone the repository:
```bash
git clone https://github.com/nitingpt000/dao-framework.git
cd dao-framework
```

2. Compile the modules:
```bash
aptos move compile
```

3. Publish to blockchain:
```bash
aptos move publish --profile default
```

## Usage

### Initialize DAO Registry

```bash
aptos move run --function-id 'default::core_dao::initialize_registry' --profile default
```

### Initialize Token Voting Module

```bash
aptos move run --function-id 'default::token_voting::initialize' --profile default
```

### Set Voting Power

```bash
aptos move run --function-id 'default::token_voting::set_voting_power' \
--args 'address:YOUR_ADDRESS' 'u64:1000' \
--profile default
```

### Create a DAO

```bash
aptos move run --function-id 'default::core_dao::create_dao' \
--args 'string:MyDAO' 'string:DAO description' 'address:VOTING_MODULE_ADDRESS' \
'string:TokenVoting' 'u64:100' 'u64:500' 'u64:86400' 'u64:3600' \
--profile default
```

### Create a Proposal

```bash
aptos move run --function-id 'default::core_dao::create_proposal' \
--args 'address:DAO_ADDRESS' 'string:Proposal description' 'hex:[]' 'hex:[]' \
--profile default
```

### Vote on a Proposal

```bash
aptos move run --function-id 'default::core_dao::vote' \
--args 'address:DAO_ADDRESS' 'u64:PROPOSAL_ID' 'u8:VOTE_TYPE' \
--profile default
```
Where VOTE_TYPE is:
- 0: No
- 1: Yes
- 2: Abstain

### Execute a Proposal

```bash
aptos move run --function-id 'default::core_dao::execute_proposal' \
--args 'address:DAO_ADDRESS' 'u64:PROPOSAL_ID' \
--profile default
```

### View DAO Info

```bash
aptos move view --function-id 'default::core_dao::get_dao_info' \
--args 'address:DAO_ADDRESS' \
--profile default
```

### View Proposal Info

```bash
aptos move view --function-id 'default::core_dao::get_proposal_info' \
--args 'address:DAO_ADDRESS' 'u64:PROPOSAL_ID' \
--profile default
```



## License

MIT

