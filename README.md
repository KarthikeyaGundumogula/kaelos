# Kaelos Protocol

Kaelos Protocol is an innovative blockchain gaming and DeFi ecosystem built on the Polygon blockchain. It integrates over-collateralized and under-collateralized systems, decentralized governance, a marketplace, and a decentralized ad network. The protocol leverages Chainlink's oracles for real-time data and cross-chain functionalities, creating a robust and scalable environment for blockchain gaming.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Key Components](#key-components)
4. [Workflow](#workflow)
   - [Cross-Chain Liquidation](#cross-chain-liquidation)
   - [Auction Mechanism](#auction-mechanism)
5. [Challenges Faced](#challenges-faced)
6. [Accomplishments](#accomplishments)
7. [What I Learned](#what-i-learned)
8. [What's Next](#whats-next)
9. [Installation](#installation)
10. [Usage](#usage)

## Overview

Kaelos Protocol offers an ideal environment for blockchain-based gaming and decentralized finance. The protocol includes several components:
- **Games and Players**: Core participants who interact through a decentralized gamer graph.
- **Ad Network**: A decentralized network providing monetization options.
- **Marketplace**: A platform for trading in-game assets.
- **Stable Coin**: Used for all transactions within the protocol.
- **Governance Token**: Enables decentralized governance.

## Architecture

Kaelos Protocol's architecture includes the following smart contracts and components:
- **Game Vaults**: Over-collateralized system for minting stable coins.
- **Asset Vaults**: Under-collateralized system for minting in-game assets.
- **Auction House**: Manages the liquidation of assets.
- **Head Station**: Central hub for collateral and stablecoin management.
- **Liquidation Station**: Executes asset liquidations.
- **Keepers**: Nodes incentivized to execute pending transactions.

## Key Components

### Game Vaults
- **Function**: Manage collateral and mint stablecoins.
- **Mechanism**: Over-collateralized to ensure protocol stability.

### Asset Vaults
- **Function**: Allow games to mint in-game assets.
- **Mechanism**: Under-collateralized to provide flexibility for game developers.

### Auction House
- **Function**: Facilitates the auctioning of assets during liquidation events.
- **Mechanism**: Ensures fair and efficient liquidation processes.

### Liquidation Station
- **Function**: Manages and executes the liquidation of assets.
- **Mechanism**: Coordinates with Keepers to handle gas-intensive operations.

## Workflow

### Cross-Chain Liquidation

1. **Initiation**: The liquidation process starts on the destination chain where the collateral token exists.
2. **Message Sending**: A smart contract on the destination chain sends a message to the receiver contract on the Polygon chain.
3. **Pending Transactions**: The receiver contract on Polygon records the message and adds it to the pending transactions list.
4. **Keeper Execution**: A Keeper node monitors the pending transactions and executes them when conditions are met, receiving incentives for the execution.
5. **Acknowledgment**: After execution, the receiver contract sends an acknowledgment message back to the destination chain, confirming the transaction completion.

### Auction Mechanism

- **Identification of Undercollateralization**: When a reserve becomes undercollateralized, a designated keeper sends a liquidation transaction (liquidationTx) to the head station through the liquidation station.
- **Initiation of Auction**: If the reserve is significantly undercollateralized, the liquidation station begins the auction process in the auction house.
- **Keeper Incentivization**: The liquidation station incentivizes the keeper responsible for notifying the liquidation. This encourages prompt action and ensures the stability of the system.
- **Auction Process**: Auctions follow a Dutch auction model, where the price starts high and gradually decreases until a bidder accepts the current price. We utilize a step exponential decrease function to calculate the current price of the auction. The current price is determined and updated in the rate aggregator.

## What's Next

The next phase for the Kaelos Protocol is to develop a decentralized gamer graph. This feature will connect players through profiles, fostering a more interconnected and vibrant gaming community within the protocol. By leveraging decentralized identity solutions, we aim to enhance social interaction and engagement in the ecosystem.

## Installation

1. Clone the repository: `git clone https://github.com/yourusername/kaelos-protocol.git`
2. Navigate to the project directory: `cd kaelos-protocol`
3. Install dependencies: `npm install`

## Usage

1. Deploy the smart contracts: `npx hardhat run scripts/deploy.js`
2. Start the local development server: `npx hardhat node`
3. Interact with the contracts using the provided scripts or your preferred method (e.g., frontend application).

### Contract Addresses

- BSCchainLinkCollateralId: "0x544553544253434c494e4b000000000000000000000000000000000000000000"
- KelosStableCoin: "0x006220b9b3e8720bfcbb6564431427e98eef76bd"
- RateAggregator: "0xae53ba4e88eec5a367aee5eaeffaec15e5f58404"
- HeadStation: "0xc684a7e13f04e47d208211ee69c8389cf30fbf6a"
- KelCoinTeller: "0xef08e9368d69075396574d871ae58c86937df6ee"
- CollateralTeller: "0x4bA8c9919e6b3C7344B081C90BA88CD6Fcac36A8" //( onAmoy );
- AuctionHouse: "0xd415544e2646718482409a62d36133b6db200bda"
- LiquidationStation: "0x5a1d329c74b7146a1afbbf12e344b22530e0934f"
- GameAssets: "0xd9d258bb22b7b306343db9d9bafc61feeb2f8419"
- GameStation: "0xbd599e13a7937f0396ade2f9ca83198aa2530464";
- AssetWarehouse: "0xc48242df9461db6a3c56de032cbd427eae1c13cb";
- CollateralInterface: "0xAd3d907A27adD7f6eD2ECFc9143702971A4e6462";
- BSCLinkToken: "0x84b9b910527ad5c03a9ca831909e21e236ea7b06";