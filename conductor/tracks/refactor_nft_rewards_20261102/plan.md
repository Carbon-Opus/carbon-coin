# Implementation Plan: Refactor CarbonOpus NFT and Rewards Contracts

## Phase 1: Analysis & Design

- [x] Task: Thoroughly review the existing implementations of `CarbonOpus.sol`, `CarbonOpusVault.sol`, and `CarbonTreasury.sol` to understand the current logic. [8273023]
- [x] Task: Design the precise data structures for storing reward balances within `CarbonOpusVault.sol`. [525fe19]
- [x] Task: Define the function signatures and interfaces required for the interaction between the three contracts (e.g., `CarbonOpus` calling `Vault` to record a sale, `Treasury` calling `Vault` to claim fees). [fce00bd]
- [ ] Task: Create or update local tests to replicate the current functionality, which will be used to verify the refactor.
- [ ] Task: Conductor - User Manual Verification 'Analysis & Design' (Protocol in workflow.md)

## Phase 2: Contract Refactoring

- [ ] Task: Refactor `CarbonOpus.sol`.
    - [ ] Task: Write unit tests to verify that all reward calculation and storage logic has been removed.
    - [ ] Task: Implement the changes, removing reward logic and adding the external call to `CarbonOpusVault` upon a successful purchase.
- [ ] Task: Implement `CarbonOpusVault.sol`.
    - [ ] Task: Write unit tests for all new functionality, including reward accounting, fund storage, user claims, and treasury claims.
    - [ ] Task: Implement the core logic for the vault, ensuring all security and access control measures are in place.
- [ ] Task: Refactor `CarbonTreasury.sol`.
    - [ ] Task: Write unit tests to verify its ability to claim funds from the `CarbonOpusVault`.
    - [ ] Task: Implement the `claim` function and remove any outdated logic.
- [ ] Task: Conductor - User Manual Verification 'Contract Refactoring' (Protocol in workflow.md)

## Phase 3: Integration & Verification

- [ ] Task: Update the Hardhat deployment scripts to correctly deploy and link the three refactored contracts.
- [ ] Task: Write comprehensive integration tests that simulate the entire lifecycle:
    - [ ] Test: A user purchases an NFT.
    - [ ] Test: The correct amounts are sent to the `CarbonOpusVault`.
    - [ ] Test: The artist, referrer, and treasury balances are correctly updated in the vault.
    - [ ] Test: The artist and referrer can successfully claim their rewards.
    - [ ] Test: The `CarbonTreasury` can successfully claim the protocol fees.
- [ ] Task: Run the full project test suite to ensure the refactoring has not introduced any regressions in other parts of the system.
- [ ] Task: Conductor - User Manual Verification 'Integration & Verification' (Protocol in workflow.md)
