# CarbonOpus: CarbonCoin Launcher & Token Contracts

This repository contains the Solidity smart contracts for the CarbonOpus ecosystem, a platform for launching and trading new tokens (creator-coins) on a bonding curve.

## Overview

The CarbonOpus system is designed to provide a fair, transparent, and bot-resistant launch for new crypto tokens. It consists of two primary components:

1.  **`CarbonCoinLauncher.sol`**: A factory contract that allows anyone to deploy their own `CarbonCoin` token for a small fee.
2.  **`CarbonCoin.sol`**: The ERC20-compliant token contract that includes a built-in bonding curve for initial price discovery. Once a token achieves a certain liquidity threshold, it "graduates" by migrating its liquidity to a decentralized exchange (DEX).

This system aims to democratize token creation while providing robust mechanisms to protect against common launch issues like sniping bots and price manipulation.

---

## Key Contracts

### `CarbonCoinLauncher.sol` (The Factory)

This contract serves as the entry point for creating new tokens.

-   **Purpose**:
    -   Allows any user to deploy a new `CarbonCoin` with a custom name, symbol, and bonding curve configuration.
    -   Acts as a public registry for all tokens launched through the platform.
    -   Collects a fee for each token creation, contributing to the platform's ecosystem.
-   **Key Function**: `createToken(name, symbol, curveConfig)`
-   **Key Event**: `TokenCreated` which can be monitored to discover new tokens.

### `CarbonCoin.sol` (The Token)

Each token created by the launcher is an instance of this contract. It has a two-phase lifecycle.

#### Phase 1: Bonding Curve Trading

-   **Price Discovery**: All buys and sells happen directly with the contract's bonding curve. The price is determined algorithmically based on the ratio of ETH reserves to the token supply.
-   **Trading Functions**: `buy(minTokensOut)` and `sell(tokensIn, minEthOut)`.
-   **Fees**: Small fees are applied to buys and sells to reward the token creator and contribute to the liquidity pool.

#### Phase 2: DEX Graduation

-   **Trigger**: When the token's ETH reserves reach a predefined `graduationThreshold`.
-   **Process**:
    1.  Bonding curve trading is permanently disabled.
    2.  The contract mints its remaining supply.
    3.  All ETH reserves and the newly minted tokens are used to create a new liquidity pool on a designated DEX (e.g., Somnia Exchange).
    4.  The LP (Liquidity Provider) tokens are transferred to the original creator of the coin.
-   **Post-Graduation**: All future trading occurs on the DEX.

---

## Core Features & Protections

The `CarbonCoin` contract includes several features designed to ensure a fair and stable trading environment, especially during the critical launch phase.

-   **Anti-Bot Measures**:
    -   A cooldown period between buys for each user.
    -   Limits on transaction sizes during the initial minutes of trading.
-   **Whale Protection (Intent-to-Trade)**:
    -   Large trades that could significantly impact the price require a two-step "register intent, then execute" process with a time delay. This prevents price manipulation by front-running bots and large holders.
-   **Circuit Breaker**:
    -   An automated mechanism that can temporarily halt trading if the system detects extreme price volatility, protecting traders from flash crashes.
-   **Gas-Efficient**: The contracts are optimized for gas efficiency.

---

## For Developers

### Getting Started

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-repo/carbon-coin.git
    cd carbon-coin
    ```

2.  **Install dependencies:**
    ```bash
    npm install
    # or
    yarn install
    ```

3.  **Compile the contracts:**
    ```bash
    npx hardhat compile
    ```

4.  **Run the tests:**
    ```bash
    npx hardhat test
    ```

### Interacting with the Contracts

-   **Deployment**: Use the scripts in the `deploy/` directory with Hardhat Deploy.
-   **Dapp Integration**: See `GEMINI.md` for a detailed guide on how to integrate a frontend Dapp with these contracts, including how to handle the whale protection flow and listen for events.

---

## Project Structure

```
/
├── contracts/         # Solidity source code
│   ├── CarbonCoin.sol
│   ├── CarbonCoinLauncher.sol
│   └── interface/
├── deploy/            # Deployment scripts
├── test/              # Hardhat tests
├── abis/              # Contract ABIs (generated after compilation)
└── hardhat.config.ts  # Hardhat configuration
```

---

This project is built with Hardhat. For more details on the development environment and available commands, please refer to the [Hardhat documentation](https://hardhat.org/).
