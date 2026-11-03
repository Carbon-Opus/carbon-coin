# Specification: Refactor CarbonOpus NFT and Rewards Contracts

## 1. Overview

This track focuses on refactoring the core NFT and rewards logic within the CarbonOpus ecosystem. The goal is to improve modularity, security, and clarity by separating distinct concerns into their appropriate contracts. The primary contracts involved are `CarbonOpus.sol`, `CarbonOpusVault.sol`, and `CarbonTreasury.sol`.

## 2. Functional Requirements

### 2.1. `CarbonOpus.sol` - NFT Logic Controller

-   This contract shall be refactored to exclusively manage the NFT lifecycle and user interactions.
-   **MUST** handle the logic for `createMusic` and `purchaseMusic`.
-   **MUST NOT** store reward balances or hold any USDC funds.
-   Upon a `purchaseMusic` transaction, it **MUST** delegate the fee distribution and rewards accounting to the `CarbonOpusVault` contract.

### 2.2. `CarbonOpusVault.sol` - The Central Vault

-   This contract will serve as the central repository for all rewards data and funds.
-   **MUST** hold all USDC funds collected from NFT sales.
-   **MUST** maintain the data structures to track claimable balances for all parties (artists, referrers, and the protocol treasury).
-   **MUST** expose a secure function for users (`claimRewards`) to withdraw their accumulated artist/referrer rewards.
-   **MUST** expose a secure, permissioned function that allows the `CarbonTreasury` contract to claim protocol fees.

### 2.3. `CarbonTreasury.sol` - Treasury Management

-   This contract is responsible for the management and withdrawal of protocol-level fees.
-   Its primary function **MUST** be to call the `CarbonOpusVault` to claim the accumulated protocol fees.
-   It **MUST NOT** interact directly with the `CarbonOpus` NFT contract.

## 3. Non-Functional Requirements

-   **Gas Efficiency:** All new and modified functions must be optimized for gas efficiency.
-   **Security:** The interaction between contracts (especially fund transfers and reward accounting) must be secure against re-entrancy and other common vulnerabilities. Access controls must be strictly enforced.
-   **Upgradability:** The design should consider future upgradability, though no specific proxy pattern is required for this track.

## 4. Out of Scope

-   Modifications to the `CarbonCoin` token, `CarbonCoinLauncher`, or any other contracts not directly related to the NFT/rewards system.
-   Changes to the frontend or Dapp integration logic (this will be handled in a separate track).
-   Changes to the core logic of the bonding curve or token graduation process.
