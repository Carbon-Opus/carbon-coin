# CarbonOpus Contracts (`CarbonCoinLauncher`, `CarbonCoin`, & `CarbonOpus`)

This document provides context for interacting with the CarbonOpus smart contracts, specifically `CarbonCoinLauncher`, `CarbonCoin`, and `CarbonOpus`. It is intended for Dapp developers and as a reference for understanding the system's mechanics.

## 1. Overview

The CarbonOpus system is a two-part ecosystem for launching and trading new tokens, often called "memecoins":

1.  **`CarbonCoinLauncher.sol`**: A factory contract that allows anyone to create their own `CarbonCoin` token for a small fee.
2.  **`CarbonCoin.sol`**: The token contract itself. Each token operates on a bonding curve for initial price discovery and trading. Once it gains enough traction (liquidity), it "graduates" by migrating its liquidity to a decentralized exchange (DEX).
3.  **`CarbonOpus.sol`**: An ERC-1155 NFT contract for minting and buying music.

---

## 2. `CarbonCoinLauncher` - The Factory

The `CarbonCoinLauncher` is the entry point for creating new tokens.

### Key Purpose

-   To allow any user to deploy a new `CarbonCoin` token with a custom name, symbol, and bonding curve configuration.
-   To act as a registry for all tokens created through it.
-   To collect a fee for each token creation.

### Dapp Integration: Creating and Discovering Tokens

#### **Creating a Token**

A user can create a new token by calling the `createToken` function:

```solidity
function createToken(
  string memory name,
  string memory symbol,
  ICarbonCoin.BondingCurveConfig memory curveConfig
) public payable returns (address);
```

-   **Parameters:**
    -   `name`: The desired name of the token (e.g., "My Awesome Coin").
    -   `symbol`: The token's symbol (e.g., "MAC").
    -   `curveConfig`: A struct defining the bonding curve's initial parameters:
        -   `virtualEth`: The virtual ETH reserve, which helps set the initial price.
        -   `virtualTokens`: The virtual token supply, also for setting the initial price.
        -   `maxSupply`: The total possible supply of the token.
        -   `graduationThreshold`: The amount of ETH reserves required in the bonding curve to trigger graduation to a DEX.
-   **Value:** The caller must send ETH equal to the `creationFee`.
-   **Returns:** The address of the newly deployed `CarbonCoin` contract.

#### **Discovering Tokens**

To display a list of tokens, a Dapp should listen for the `TokenCreated` event:

```solidity
event TokenCreated(
    address indexed tokenAddress,
    address indexed creator,
    string name,
    string symbol,
    uint256 createdAt,
    uint256 feePaid
);
```

By subscribing to this event, a Dapp can maintain an up-to-date list of all tokens launched through the platform.

#### **Other Useful Functions**

-   `getStats()`: Returns platform-wide statistics like total tokens created and fees collected.
-   `tokens(address tokenAddress)`: Returns `TokenInfo` for a specific token.

---

## 3. `CarbonCoin` - The Token

Each `CarbonCoin` contract has a two-phase lifecycle.

### Phase 1: Bonding Curve Trading (Pre-Graduation)

In this initial phase, all buying and selling occurs directly with the contract. The price is determined algorithmically by a bonding curve.

#### **Buying and Selling**

-   **To Buy:** A user calls `buy(uint256 minTokensOut)` and sends ETH. The contract calculates the number of tokens they receive based on the current price and a buy fee. `minTokensOut` is a slippage parameter.
-   **To Sell:** A user first approves the contract to spend their tokens, then calls `sell(uint256 tokensIn, uint256 minEthOut)`. The contract calculates the ETH returned based on the current price and a sell fee. `minEthOut` is a slippage parameter.

#### **Price Calculations**

Your Dapp should use these view functions to estimate trades for users:

-   `getCurrentPrice()`: Returns the current instantaneous price of 1 token in ETH.
-   `calculateTokensOut(uint256 ethIn)`: Calculates how many tokens a user will get for a given amount of ETH.
-   `calculateEthOut(uint256 tokensIn)`: Calculates how much ETH a user will get for selling a given amount of tokens.

#### **Built-in Protections (Important for Dapp UX)**

The contract has several protection mechanisms a Dapp must be aware of to provide a good user experience.

**1. Anti-Bot Measures:**
-   Users have a cooldown period between buys (`getUserCooldown`). Your UI should reflect this.
-   There are limits on buy amounts in the first few minutes after launch (`getAntiBotInfo`).

**2. Whale Protection (Intent-to-Trade):**
Large trades (both buys and sells) that exceed the `whaleThreshold` require a two-step process to prevent price manipulation.

-   **Step 1: Register Intent:**
    -   The user attempts a large trade by calling `buy` or `sell`.
    -   The transaction will **revert** with a `WhaleIntentRequired` error. This is expected.
    -   The Dapp should catch this, and immediately call the **same function again** with the **same parameters**. This second call registers the user's "intent to trade" and will also revert, but this time with a `WhaleIntentNotReady` error.
-   **Step 2: Execute Trade:**
    -   The user must now wait for a cooldown period (`whaleDelay`). The Dapp can query `getWhaleIntent(address)` to see the status and when the trade can be executed.
    -   After the delay, the user calls the **same `buy` or `sell` function a third time** with the exact same parameters. This will finally execute the trade.

Your Dapp's UI must guide the user through this "register, wait, execute" flow for large trades.

**3. Circuit Breaker:**
-   Trading can be automatically halted if the system detects extreme volatility or a high-impact trade.
-   Use `getCircuitBreakerStatus()` to check if trading is paused and for how long. Your UI should disable trading and inform the user if the circuit breaker is active.

#### **Key View Functions for a Dapp UI**

-   `getReserves()`: Get the current state of the bonding curve reserves.
-   `getTradeLimits()`: Get current trade size limits and whale thresholds.
-   `getAntiBotInfo()`: Get status of anti-bot measures.
-   `getUserCooldown(address)`: Check the remaining buy cooldown for a user.
-   `getCircuitBreakerStatus()`: Check if trading is paused.
-   `getWhaleIntent(address)`: Check a user's pending whale trade intent.

### Phase 2: Graduation & DEX Trading

When the contract's ETH balance (`realEthReserves`) reaches the `GRADUATION_THRESHOLD`, it automatically "graduates".

#### **What Happens During Graduation?**

1.  The `_graduate()` function is triggered.
2.  The `buy()` and `sell()` functions on the `CarbonCoin` contract are permanently disabled.
3.  The contract mints its remaining token supply.
4.  It takes all the ETH it holds and all the newly minted tokens and adds them as a liquidity pair on the designated DEX (e.g., Somnia Exchange).
5.  The LP (Liquidity Provider) tokens are sent to the original `creator` of the coin.

#### **Dapp Integration After Graduation**

-   **Detection:** Your Dapp must monitor the `hasGraduated` boolean variable on the `CarbonCoin` contract. Once `true`, the Dapp should change its UI. The `Graduated` event is also emitted.
-   **UI Change:** The Dapp should replace its native "buy/sell" interface with a link or widget that directs users to the token's trading page on the DEX. The address of the new DEX pair can be found in the `Graduated` event or by calling `dexPair()` on the `CarbonCoin` contract.
-   **Trading:** All future trades happen on the DEX, not the `CarbonCoin` contract.

---

## 4. `CarbonOpus` - The Music NFT Marketplace

The `CarbonOpus` contract is an ERC-1155 NFT marketplace designed for artists to sell their music.

### Key Purpose

-   To allow artists to mint their music as NFTs.
-   To enable users to purchase these music NFTs.
-   To distribute royalties from sales to artists and referrers.
-   To collect a protocol fee on each transaction.

### Dapp Integration: Minting and Purchasing Music

#### **Minting a Song (for Artists)**

An artist can mint a new song NFT by calling `mintMusic`:

```solidity
function mintMusic(address receiver, uint256 price, uint256 referralPct) external;
```

-   **Parameters:**
    -   `receiver`: The address that will own the newly minted song (usually the artist).
    -   `price`: The price in ETH for one edition of the song.
    -   `referralPct`: The percentage of the sale price (in basis points) that will be given to a referrer.
-   **Event:** The `SongMinted` event is emitted, which a Dapp can use to track new songs.

#### **Purchasing a Song**

A user can purchase a song NFT by calling `purchaseMusic`:

```solidity
function purchaseMusic(address receiver, uint256 tokenId, address referrer) external payable;
```

-   **Parameters:**
    -   `receiver`: The address that will receive the purchased NFT.
    -   `tokenId`: The ID of the song to purchase.
    -   `referrer`: An optional address of a user who referred the sale.
-   **Value:** The caller must send ETH equal to the song's `price`.
-   **Events:**
    -   `SongPurchased`: Indicates a successful purchase.
    -   `RewardsDistributed`: Details how the payment was split between the artist, referrer, and protocol.

#### **Batch Purchasing**

Users can buy multiple songs in one transaction using `purchaseBatch`:

```solidity
function purchaseBatch(address receiver, uint256[] memory tokenIds, address[] memory referrers) external payable;
```

### Managing Songs and Rewards

#### **For Artists:**

-   `updateSongPrice(uint256 tokenId, uint256 newPrice)`: Allows an artist to change the price of their song.
-   `updateSongReferralPct(uint256 tokenId, uint256 newPct)`: Allows an artist to change the referral percentage.

#### **For All Users:**

-   `claimRewards(address payable receiver)`: Allows any user (artist or referrer) to withdraw their accumulated ETH rewards.
-   `rewards(address user)`: A public mapping to check a user's claimable rewards.
-   `musicBalance(address user)`: Returns the token IDs and balances of songs owned by a user.

### Administrative Functions

These functions are restricted to the contract owner or a designated manager:

-   `updateProtocolFee(uint256 newFee)`: Change the protocol fee.
-   `updateTreasury(address newTreasury)`: Change the address where protocol fees are sent.
-   `updatePriceScaleManager(address newManager)`: Transfer the `priceScaleManager` role.
-   `scaleSongPrice(uint256 tokenId, uint256 newPrice)`: A privileged function for the `priceScaleManager` to update a song's price.
-   `setURI(string memory newUri)`: Update the base URI for the token metadata.

### Tokenomics and Fees

-   **Protocol Fee:** A percentage of every sale is sent to the treasury. The fee is set by `protocolFee` (in basis points).
-   **Referral Fee:** A percentage of the sale, set by the artist, is awarded to a referrer.
-   **Artist's Share:** The remainder of the sale price goes to the artist.
