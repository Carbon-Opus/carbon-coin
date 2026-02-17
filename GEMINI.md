# CarbonOpus Contracts (`CarbonCoinLauncher`, `CarbonCoin`, & `CarbonOpus`)

This document provides context for interacting with the CarbonOpus smart contracts, specifically `CarbonCoinLauncher`, `CarbonCoin`, `CarbonOpus`, `CarbonCoinProtection`, `CarbonCoinConfig`, and `PermitAndTransfer`. It is intended for Dapp developers and as a reference for understanding the system's mechanics.

## 1. Overview

The CarbonOpus system is a two-part ecosystem for launching and trading new tokens, often called "memecoins":

1.  **`CarbonCoinLauncher.sol`**: A factory contract that allows anyone to create their own `CarbonCoin` token for a small fee.
2.  **`CarbonCoin.sol`**: The token contract itself. Each token operates on a bonding curve for initial price discovery and trading. Once it gains enough traction (liquidity), it "graduates" by migrating its liquidity to a decentralized exchange (DEX).
3.  **`CarbonOpus.sol`**: An ERC-1155 NFT contract for minting and buying music.
4.  **`CarbonCoinProtection.sol`**: A contract that provides various protection mechanisms for `CarbonCoin` tokens, including anti-bot, whale limits, and circuit breakers.
5.  **`CarbonCoinConfig.sol`**: A contract that stores default configurations for new `CarbonCoin` tokens.
6.  **`PermitAndTransfer.sol`**: A utility contract for performing EIP-2612 permit and transfer operations.

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
  address creatorAddress,
  ICarbonCoin.BondingCurveConfig memory curveConfig
) public returns (address);
```

-   **Parameters:**
    -   `name`: The desired name of the token (e.g., "My Awesome Coin").
    -   `symbol`: The token's symbol (e.g., "MAC").
    -   `creatorAddress`: The address of the creator of the token.
    -   `curveConfig`: A struct defining the bonding curve's initial parameters:
        -   `virtualEth`: The virtual ETH reserve, which helps set the initial price.
        -   `virtualTokens`: The virtual token supply, also for setting the initial price.
        -   `maxSupply`: The total possible supply of the token.
        -   `graduationThreshold`: The amount of ETH reserves required in the bonding curve to trigger graduation to a DEX.
-   **Returns:** The address of the newly deployed `CarbonCoin` contract.

#### **Events**

To display a list of tokens and monitor launcher activities, a Dapp should listen for the following events:

-   `FeeReceived(address indexed sender, uint256 value, uint256 timestamp)`: Emitted when ETH is received by the launcher contract, typically as a creation fee.
-   `TokenCreated(address indexed tokenAddress, address indexed creator, string name, string symbol, uint256 createdAt)`: Emitted when a new `CarbonCoin` token is successfully created through the launcher.
    -   `tokenAddress`: The address of the newly created token contract.
    -   `creator`: The address of the user who created the token.
    -   `name`: The name of the new token.
    -   `symbol`: The symbol of the new token.
    -   `createdAt`: The timestamp of the token creation.
-   `MaxTokensPerCreatorUpdated(uint256 oldMax, uint256 newMax, uint256 timestamp)`: Emitted when the maximum number of tokens a single address can create is updated.
    -   `oldMax`: The previous maximum token count.
    -   `newMax`: The new maximum token count.
    -   `timestamp`: The timestamp of the update.
-   `ControllerUpdated(address newController)`: Emitted when the controller address of the launcher contract is updated.
    -   `newController`: The address of the new controller.
-   `LauncherPaused(uint256 timestamp)`: Emitted when the launcher contract is paused, preventing new token creations.
    -   `timestamp`: The timestamp of the pause.
-   `LauncherUnpaused(uint256 timestamp)`: Emitted when the launcher contract is unpaused, allowing new token creations.
    -   `timestamp`: The timestamp of the unpause.
-   `FeesWithdrawn(address indexed to, uint256 amount, uint256 timestamp)`: Emitted when collected fees are withdrawn from the contract.
    -   `to`: The address to which the fees were withdrawn.
    -   `amount`: The amount of fees withdrawn.
    -   `timestamp`: The timestamp of the withdrawal.
-   `TokenGraduated(address indexed tokenAddress, uint256 timestamp)`: Emitted when a token is marked as graduated by the launcher (usually called by the token itself).
    -   `tokenAddress`: The address of the token that graduated.
    -   `timestamp`: The timestamp of the graduation.

#### **Other Useful Functions**

-   `getStats()`: Returns platform-wide statistics like total tokens created and fees collected.
-   `tokens(address tokenAddress)`: Returns `TokenInfo` for a specific token.

---

## 3. `CarbonCoin` - The Token (USDC-based)

Each `CarbonCoin` contract has a two-phase lifecycle. This implementation uses USDC as the base currency for its bonding curve.

### Phase 1: Bonding Curve Trading (Pre-Graduation)

In this initial phase, all buying and selling occurs directly with the contract. The price is determined algorithmically by a bonding curve.

#### **Buying and Selling**

-   **To Buy:** A user calls `buy(uint256 usdcAmount, uint256 minTokensOut)` (or `buyWithPermit`) and approves USDC. The contract calculates the number of tokens they receive based on the current price and a buy fee. `minTokensOut` is a slippage parameter.
-   **To Sell:** A user first approves the contract to spend their tokens, then calls `sell(uint256 tokensIn, uint256 minUsdcOut)`. The contract calculates the USDC returned based on the current price and a sell fee. `minUsdcOut` is a slippage parameter.

#### **Price Calculations**

Your Dapp should use these view functions to estimate trades for users:

-   `getCurrentPrice()`: Returns the current instantaneous price of 1 token in USDC (with 6 decimals for USDC).
-   `calculateTokensOut(uint256 usdcIn)`: Calculates how many tokens a user will get for a given amount of USDC.
-   `calculateUsdcOut(uint256 tokensIn)`: Calculates how much USDC a user will get for selling a given amount of tokens.

#### **Built-in Protections (Important for Dapp UX)**

The contract has several protection mechanisms a Dapp must be aware of to provide a good user experience. These protections are largely managed by the `CarbonCoinProtection` contract.

**1. Anti-Bot Measures:**
-   Users have a cooldown period between buys (`getUserCooldown` via `CarbonCoinProtection`). Your UI should reflect this.
-   There are limits on buy amounts in the first few minutes after launch (`getAntiBotInfo` via `CarbonCoinConfig`).

**2. Whale Protection (Intent-to-Trade):**
Large trades (both buys and sells) that exceed the `whaleThreshold` require a two-step process to prevent price manipulation.

-   **Step 1: Register Intent:**
    -   The user attempts a large trade by calling `buy` or `sell`.
    -   The transaction will **revert** with a `WhaleIntentRequired` error. This is expected.
    -   The Dapp should catch this, and immediately call the **same function again** with the **same parameters**. This second call registers the user's "intent to trade" and will also revert, but this time with a `WhaleIntentNotReady` error.
-   **Step 2: Execute Trade:**
    -   The user must now wait for a cooldown period (`whaleDelay`). The Dapp can query `getWhaleIntent(address)` (on `CarbonCoinProtection`) to see the status and when the trade can be executed.
    -   After the delay, the user calls the **same `buy` or `sell` function a third time** with the exact same parameters. This will finally execute the trade.

Your Dapp's UI must guide the user through this "register, wait, execute" flow for large trades.

**3. Circuit Breaker:**
-   Trading can be automatically halted if the system detects extreme volatility or a high-impact trade.
-   Use `getCircuitBreakerStatus()` (on `CarbonCoinProtection`) to check if trading is paused and for how long. Your UI should disable trading and inform the user if the circuit breaker is active.

#### **Events**

Dapps should monitor the following events for `CarbonCoin` token activities:

-   `CreatorReserveMinted(address indexed creator, uint256 amount, uint256 timestamp)`: Emitted when the initial token reserve for the creator is minted.
    -   `creator`: The address of the token creator.
    -   `amount`: The amount of tokens minted as reserve.
    -   `timestamp`: The timestamp of the minting.
-   `TokenDeployed(address indexed tokenAddress, address indexed creator, string name, string symbol, uint256 maxSupply, uint256 graduationThreshold, uint256 createdAt)`: Emitted when this `CarbonCoin` token contract is deployed.
    -   `tokenAddress`: The address of this token contract.
    -   `creator`: The address of the token's creator.
    -   `name`: The name of the token.
    -   `symbol`: The symbol of the token.
    -   `maxSupply`: The maximum total supply of the token.
    -   `graduationThreshold`: The USDC reserve amount required for graduation.
    -   `createdAt`: The timestamp of the token deployment.
-   `TokensPurchased(address indexed buyer, uint256 usdcAmount, uint256 tokensOut, uint256 price, uint256 realUsdcReserves, uint256 realTokenSupply, uint256 timestamp)`: Emitted after a successful token purchase.
    -   `buyer`: The address of the buyer.
    -   `usdcAmount`: The amount of USDC spent.
    -   `tokensOut`: The amount of tokens received by the buyer.
    -   `price`: The new price after the purchase.
    -   `realUsdcReserves`: The current real USDC reserves in the bonding curve.
    -   `realTokenSupply`: The current real token supply in circulation.
    -   `timestamp`: The timestamp of the purchase.
-   `PriceUpdate(uint256 price, uint256 usdcReserves, uint256 tokenSupply, uint256 timestamp)`: Emitted when the token's price, USDC reserves, or token supply changes.
    -   `price`: The current instantaneous price of 1 token in USDC.
    -   `usdcReserves`: The current real USDC reserves in the bonding curve.
    -   `tokenSupply`: The current real token supply in circulation.
    -   `timestamp`: The timestamp of the update.
-   `TokensSold(address indexed seller, uint256 tokensIn, uint256 usdcOut, uint256 price, uint256 realUsdcReserves, uint256 realTokenSupply, uint256 timestamp)`: Emitted after a successful token sale.
    -   `seller`: The address of the seller.
    -   `tokensIn`: The amount of tokens sold.
    -   `usdcOut`: The amount of USDC received by the seller.
    -   `price`: The new price after the sale.
    -   `realUsdcReserves`: The current real USDC reserves in the bonding curve.
    -   `realTokenSupply`: The current real token supply in circulation.
    -   `timestamp`: The timestamp of the sale.
-   `Graduated(address indexed tokenAddress, uint256 tokenAmount, uint256 usdcAmount, uint256 price, uint256 timestamp)`: Emitted when the token graduates and liquidity is added to a DEX.
    -   `tokenAddress`: The address of this token contract.
    -   `tokenAmount`: The amount of tokens added to the liquidity pool.
    -   `usdcAmount`: The amount of USDC added to the liquidity pool.
    -   `price`: The price at the time of graduation.
    -   `timestamp`: The timestamp of the graduation.
-   `LiquiditySnapshot(uint256 usdcAmount, uint256 tokenAmount, uint256 lpAmount, uint256 timestamp)`: Emitted to capture liquidity details, especially after graduation.
    -   `usdcAmount`: The amount of USDC in the liquidity pool.
    -   `tokenAmount`: The amount of tokens in the liquidity pool.
    -   `lpAmount`: The amount of LP tokens minted.
    -   `timestamp`: The timestamp of the snapshot.
-   `TradingPaused(uint256 timestamp)`: Emitted when trading for this token is paused.
    -   `timestamp`: The timestamp of the pause.
-   `TradingUnpaused(uint256 timestamp)`: Emitted when trading for this token is unpaused.
    -   `timestamp`: The timestamp of the unpause.
-   `EmergencyWithdraw(address indexed to, uint256 amount, uint256 timestamp)`: Emitted when USDC is emergency withdrawn from the contract (pre-graduation).
    -   `to`: The address to which USDC was withdrawn.
    -   `amount`: The amount of USDC withdrawn.
    -   `timestamp`: The timestamp of the withdrawal.

#### **Key View Functions for a Dapp UI**

-   `getReserves()`: Get the current state of the bonding curve reserves.
-   `getTradeLimits()`: Get current trade size limits and whale thresholds (from `CarbonCoinProtection`).
-   `getAntiBotInfo()`: Get status of anti-bot measures (from `CarbonCoinProtection`).
-   `getUserCooldown(address)`: Check the remaining buy cooldown for a user (from `CarbonCoinProtection`).
-   `getCircuitBreakerStatus()`: Check if trading is paused (from `CarbonCoinProtection`).
-   `getWhaleIntent(address)`: Check a user's pending whale trade intent (from `CarbonCoinProtection`).

### Phase 2: Graduation & DEX Trading

When the contract's USDC balance (`realUsdcReserves`) reaches the `GRADUATION_THRESHOLD`, it automatically "graduates".

#### **What Happens During Graduation?**

1.  The `_graduate()` function is triggered.
2.  The `buy()` and `sell()` functions on the `CarbonCoin` contract are permanently disabled.
3.  The contract mints its remaining token supply.
4.  It takes all the USDC it holds and all the newly minted tokens and adds them as a liquidity pair on the designated DEX (e.g., Somnia Exchange) via `CarbonCoinDex`.
5.  The LP (Liquidity Provider) tokens are sent to the original `creator` of the coin.

#### **Dapp Integration After Graduation**

-   **Detection:** Your Dapp must monitor the `hasGraduated` boolean variable on the `CarbonCoin` contract. Once `true`, the Dapp should change its UI. The `Graduated` event is also emitted.
-   **UI Change:** The Dapp should replace its native "buy/sell" interface with a link or widget that directs users to the token's trading page on the DEX. The address of the new DEX pair can be found in the `Graduated` event or by calling `dexPair()` on the `CarbonCoinDex` contract (if exposed).
-   **Trading:** All future trades happen on the DEX, not the `CarbonCoin` contract.

---

## 4. `CarbonOpus` - The Music NFT Marketplace

The `CarbonOpus` contract is an ERC-1155 NFT marketplace designed for artists to sell their music. It uses a USDC token for all payment and reward transactions and a `memberId` system to track artists and their creations independent of their current wallet address.

### Key Purpose

-   To allow artists to mint their music as NFTs. **Minting is restricted to the platform controller** (on behalf of the artist).
-   To enable public users to purchase these music NFTs using USDC.
-   To distribute royalties from sales to artists and referrers in USDC.
-   To collect a protocol fee on each transaction in USDC.

### Dapp Integration: Minting and Purchasing Music

#### **Creating a Song (Restricted Mint)**

New songs are created via the `createMusic` function. **This function is restricted to the contract's `controller`**. In the CarbonOpus platform, when an artist uploads a song, the platform (acting as the controller) calls this function to mint the NFT to the artist's address.

```solidity
function createMusic(bytes32 memberId, address memberAddress, uint256 price, uint256 referralPct) external;
```

-   **Parameters:**
    -   `memberId`: The artist's unique identifier (managed by the platform).
    -   `memberAddress`: The artist's wallet address where the NFT will be minted.
    -   `price`: The price in USDC for one edition of the song.
    -   `referralPct`: The percentage of the sale price (in basis points, e.g., 500 = 5%) that will be given to a referrer.

#### **Events**

Dapps should monitor the following events for `CarbonOpus` activities:

-   `SongCreated(uint256 indexed tokenId, bytes32 indexed memberId, uint256 price, uint256 referralPct)`: Emitted when a new music NFT is created by the controller.
    -   `tokenId`: The ID of the newly created song NFT.
    -   `memberId`: The `memberId` of the artist who created the song.
    -   `price`: The price of the song in USDC.
    -   `referralPct`: The referral percentage set for the song.
-   `RewardsDistributed(bytes32 indexed artistMemberId, bytes32 indexed referrerMemberId, uint256 artistAmount, uint256 referrerAmount, uint256 protocolAmount)`: Emitted when rewards from a song purchase are distributed.
    -   `artistMemberId`: The `memberId` of the artist receiving royalties.
    -   `referrerMemberId`: The `memberId` of the referrer (if any) receiving a referral fee.
    -   `artistAmount`: The amount of USDC distributed to the artist.
    -   `referrerAmount`: The amount of USDC distributed to the referrer.
    -   `protocolAmount`: The amount of USDC sent to the protocol treasury.
-   `SongPurchased(uint256 indexed tokenId, bytes32 indexed buyerMemberId, bytes32 indexed referrerMemberId, uint256 price)`: Emitted when a song NFT is purchased.
    -   `tokenId`: The ID of the song NFT purchased.
    -   `buyerMemberId`: The `memberId` of the buyer.
    -   `referrerMemberId`: The `memberId` of the referrer (if any).
    -   `price`: The price at which the song was purchased.
-   `RewardsClaimed(bytes32 indexed memberId, address indexed receiverAddress, uint256 amount)`: Emitted when a user successfully claims their accumulated USDC rewards.
    -   `memberId`: The `memberId` of the user claiming rewards.
    -   `receiverAddress`: The wallet address where the rewards were sent.
    -   `amount`: The amount of USDC claimed.
-   `SongPriceScaled(uint256 indexed tokenId, uint256 newPrice)`: Emitted when a song's price is updated by an authorized entity (e.g., the artist or controller).
    -   `tokenId`: The ID of the song whose price was updated.
    -   `newPrice`: The new price of the song in USDC.
-   `SongReferralPctUpdated(uint256 indexed tokenId, uint256 newReferralPct)`: Emitted when a song's referral percentage is updated by an authorized entity.
    -   `tokenId`: The ID of the song whose referral percentage was updated.
    -   `newReferralPct`: The new referral percentage for the song.
-   `ProtocolFeeUpdated(uint256 newFee)`: Emitted when the global protocol fee is updated by the owner.
    -   `newFee`: The new protocol fee in basis points.
-   `ControllerUpdated(address newController)`: Emitted when the controller address of the `CarbonOpus` contract is updated.
    -   `newController`: The address of the new controller.

#### **Managing Member Identity**

The platform can update the association between a `memberId` and a wallet address. This is also restricted to the `controller`.

```solidity
function updateMemberMapping(bytes32 memberId, address memberAddress) external;
```

#### **Purchasing a Song (Public)**

Any user can purchase a song NFT by calling `purchaseMusic`. This requires approving the `CarbonOpus` contract to spend the user's USDC.

```solidity
function purchaseMusic(bytes32 memberId, address memberAddress, uint256 tokenId, bytes32 referrer) external;
```

-   **Parameters:**
    -   `memberId`: The buyer's unique identifier.
    -   `memberAddress`: The buyer's wallet address.
    -   `tokenId`: The ID of the song to purchase.
    -   `referrer`: An optional `memberId` of a user who referred the sale.

#### **Batch Purchasing**

Users can buy multiple songs in one transaction using `purchaseBatch`:

```solidity
function purchaseBatch(bytes32 memberId, address memberAddress, uint256[] memory tokenIds, bytes32[] memory referrers) external;
```

### Managing Songs and Rewards

#### **For Artists (Song Owners):**

-   `updateSongPrice(uint256 tokenId, uint256 newPrice)`: Allows the artist (owner of the `memberId` associated with the song) to change the price in USDC.
-   `updateSongReferralPct(uint256 tokenId, uint256 newPct)`: Allows the artist to change the referral percentage.

#### **For All Users:**

-   `claimRewards(bytes32 memberId)`: Allows any user (artist or referrer) to withdraw their accumulated USDC rewards to their registered wallet address.
-   `rewards(bytes32 memberId)`: Public mapping to check a user's claimable USDC balance.
-   `musicBalance(bytes32 memberId)`: Returns the token IDs and balances of songs owned by a user's wallet.

### Administrative Functions

These functions are restricted to the contract `owner` or `controller`:

-   `updateProtocolFee(uint256 newFee)`: Change the protocol fee (Owner).
-   `updateTreasury(address newTreasury)`: Change the address where protocol fees are sent (Owner).
-   `updateController(address newController)`: Transfer the `controller` role (Owner).
-   `scaleSongPrice(uint256 tokenId, uint256 newPrice)`: A privileged function for the `controller` to update a song's price.
-   `setURI(string memory newUri)`: Update the base URI for the token metadata (Owner).

### Tokenomics and Fees

-   **Protocol Fee:** A percentage of every sale is sent to the treasury. The fee is set by `protocolFee` (in basis points).
-   **Referral Fee:** A percentage of the sale, set by the artist, is awarded to a referrer.
-   **Artist's Share:** The remainder of the sale price goes to the artist.

### Constructor

```solidity
constructor(string memory uri, address usdcTokenAddress) public;
```

-   **Parameters:**
    -   `uri`: The base URI for the token metadata.
    -   `usdcTokenAddress`: The address of the USDC token contract.

---

## 5. `CarbonCoinProtection` - The Protection Mechanism

This contract provides various protection mechanisms for `CarbonCoin` tokens, including anti-bot, whale limits, and circuit breakers.

### Key Purpose

-   To centralize and manage protection features across multiple `CarbonCoin` tokens.
-   To prevent front-running, price manipulation, and bot activities.
-   To provide emergency measures during extreme market volatility.

### Dapp Integration

Dapps should integrate with `CarbonCoinProtection` by calling its view functions to get status information (e.g., `getCircuitBreakerStatus`, `getWhaleIntent`, `getUserCooldown`) and handling reverts from `CarbonCoin`'s buy/sell functions which indicate that `CarbonCoinProtection` has flagged a trade (e.g., `WhaleIntentRequired`).

#### **Events**

Dapps should monitor the following events from `CarbonCoinProtection` for detailed protection-related activities:

-   `WhaleIntentRegistered(address indexed token, address indexed user, uint256 amount, bool isBuy, uint256 executeAfter, uint256 timestamp)`: Emitted when a user registers an intent for a large "whale" trade.
    -   `token`: The address of the `CarbonCoin` token.
    -   `user`: The address of the user who registered the intent.
    -   `amount`: The amount of tokens/USDC for which the intent was registered.
    -   `isBuy`: `true` if it's a buy intent, `false` if it's a sell intent.
    -   `executeAfter`: The timestamp after which the trade can be executed.
    -   `timestamp`: The timestamp of the intent registration.
-   `WhaleTradeExecuted(address indexed token, address indexed user, uint256 amount, bool isBuy, uint256 timestamp)`: Emitted when a previously registered whale trade intent is successfully executed.
    -   `token`: The address of the `CarbonCoin` token.
    -   `user`: The address of the user whose intent was executed.
    -   `amount`: The amount of tokens/USDC involved in the trade.
    -   `isBuy`: `true` if it was a buy trade, `false` if a sell trade.
    -   `timestamp`: The timestamp of the trade execution.
-   `CircuitBreakerReset(address indexed token, uint256 timestamp)`: Emitted when the circuit breaker for a specific token is reset, allowing trading to resume.
    -   `token`: The address of the `CarbonCoin` token.
    -   `timestamp`: The timestamp of the reset.
-   `VolatilityWarning(address indexed token, uint256 volatilityMoveCount, uint256 timestamp)`: Emitted when a token experiences a high number of significant price movements within a defined window.
    -   `token`: The address of the `CarbonCoin` token.
    -   `volatilityMoveCount`: The number of significant price moves detected.
    -   `timestamp`: The timestamp of the warning.
-   `CircuitBreakerTriggered(address indexed token, string reason, uint256 timestamp, uint256 duration)`: Emitted when the circuit breaker for a token is activated due to detected issues (e.g., excessive volatility, price impact).
    -   `token`: The address of the `CarbonCoin` token.
    -   `reason`: A string explaining why the circuit breaker was triggered.
    -   `timestamp`: The timestamp of the trigger.
    -   `duration`: The duration for which the circuit breaker will be active.
-   `HighPriceImpact(address indexed token, address indexed user, uint224 priceImpact, uint256 timestamp)`: Emitted when a trade causes a price impact exceeding a defined threshold.
    -   `token`: The address of the `CarbonCoin` token.
    -   `user`: The address of the user making the trade.
    -   `priceImpact`: The calculated price impact (in basis points).
    -   `timestamp`: The timestamp of the event.
-   `WhaleIntentCancelled(address indexed token, address indexed user, uint256 timestamp)`: Emitted when a user's pending whale trade intent is cancelled.
    -   `token`: The address of the `CarbonCoin` token.
    -   `user`: The address of the user whose intent was cancelled.
    -   `timestamp`: The timestamp of the cancellation.
-   `AddressBlacklisted(address indexed token, address indexed user, bool blacklisted, uint256 timestamp)`: Emitted when an address is blacklisted (or unblacklisted) for trading a specific token.
    -   `token`: The address of the `CarbonCoin` token.
    -   `user`: The address being blacklisted/unblacklisted.
    -   `blacklisted`: `true` if blacklisted, `false` if unblacklisted.
    -   `timestamp`: The timestamp of the action.
-   `BotDetected(address indexed token, address indexed user, string reason, uint256 timestamp)`: Emitted when a bot is detected, often leading to blacklisting.
    -   `token`: The address of the `CarbonCoin` token.
    -   `user`: The address identified as a bot.
    -   `reason`: A string describing the reason for bot detection.
    -   `timestamp`: The timestamp of the detection.
-   `AddressWhitelisted(address indexed token, address indexed user, bool whitelisted, uint256 timestamp)`: Emitted when an address is whitelisted (or unwhitelisted) for a specific token, bypassing certain protections.
    -   `token`: The address of the `CarbonCoin` token.
    -   `user`: The address being whitelisted/unwhitelisted.
    -   `whitelisted`: `true` if whitelisted, `false` if unwhitelisted.
    -   `timestamp`: The timestamp of the action.
-   `ConfigUpdated(address indexed newConfig, uint256 timestamp)`: Emitted when the address of the `CarbonCoinConfig` contract used by `CarbonCoinProtection` is updated.
    -   `newConfig`: The address of the new `CarbonCoinConfig` contract.
    -   `timestamp`: The timestamp of the update.
-   `LauncherUpdated(address indexed newLauncher, uint256 timestamp)`: Emitted when the address of the `CarbonCoinLauncher` contract is updated.
    -   `newLauncher`: The address of the new `CarbonCoinLauncher` contract.
    -   `timestamp`: The timestamp of the update.

---

## 6. `CarbonCoinConfig` - The Configuration Store

This contract holds the default configuration parameters for new `CarbonCoin` tokens, including fee structures, anti-bot settings, circuit breaker thresholds, and whale trading limits.

### Key Purpose

-   To provide a centralized and upgradeable source of configuration for `CarbonCoin` tokens.
-   To allow the owner to adjust critical parameters for new token launches.

### Dapp Integration

Dapps can query the view functions of `CarbonCoinConfig` to retrieve the current default settings for various protection mechanisms and fees.

#### **Events**

Dapps should monitor the following event for updates to the default configurations:

-   `DefaultConfigUpdated(string indexed configType, uint256 timestamp)`: Emitted when any of the default configuration types (e.g., "Dex", "Fee", "AntiBot", "CircuitBreaker", "WhaleLimit") are updated.
    -   `configType`: A string indicating which configuration type was updated.
    -   `timestamp`: The timestamp of the update.

---

## 7. `PermitAndTransfer` - The Utility Contract

This is a utility contract designed to facilitate gasless token transfers using EIP-2612 `permit` signatures followed by a `transferFrom` call.

### Key Purpose

-   To allow users to authorize and transfer ERC-20 tokens (that support EIP-2612 `permit`) in a single transaction, potentially saving gas costs or enabling certain interaction flows.

### Dapp Integration

Dapps can interact with this contract to initiate `permitAndTransfer` operations, where a user signs an off-chain message to approve token spending, and then a third party (or the Dapp itself) can execute the transfer without the user needing to send a separate approval transaction.

#### **Events**

Dapps should monitor the following event for successful `permitAndTransfer` operations:

-   `PermitTransfer(bytes32 indexed senderId, address indexed token, address owner, address spender, uint256 value, bytes32 uuid)`: Emitted after a successful `permit` and `transferFrom` sequence.
    -   `senderId`: An identifier for the sender, useful for filtering events.
    -   `token`: The address of the ERC-20 token being transferred.
    -   `owner`: The address of the token owner who signed the permit.
    -   `spender`: The address of the spender (this contract).
    -   `value`: The amount of tokens transferred.
    -   `uuid`: A unique identifier for matching to a specific order or transaction.

---

Setting Up Dune Analytics for Somnia Testnet

Step 1: Verify Your Contract on Somnia Block Explorer

  Before you can decode your contract on Dune, you should verify it on the Somnia Testnet explorer:

  Go to the Somnia Testnet Block Explorer at https://shannon-explorer.somnia.network/
  Find your deployed contract
  Verify your contract by uploading the source code and ABI
  This makes the ABI publicly available for Dune to fetch

Step 2: Submit Your Contract for Decoding on Dune

  To decode your contract, you'll need four pieces of information: the blockchain (Somnia), contract address, project name, and the contract's ABI Dune Docs.

  Go to Dune's Contract Submission Page: Visit https://dune.com/contracts/new
  Fill in the required information:

  Blockchain: Select "Somnia" from the dropdown
  Contract Address: Your smart contract address on Somnia Testnet
  Project Name: Name of your project (e.g., "MyGameProject")
  Contract Name: Name of the specific contract (e.g., "GameToken", "NFTMarketplace")
  ABI: If your contract is verified on the chain's explorer, Dune will attempt to auto-fetch the ABI; otherwise, you'll need to enter it manually Dune Docs

  Special Contract Types:

  If your contract is a factory contract (creates other contracts), check the factory box to decode all instances
  If it's a proxy contract, submit using the proxy address but with the implementation contract's ABI

Step 3: Wait for Decoding

  It usually takes about 24 hours to initially decode smart contracts Layer3. You can check if your contract has been decoded by querying the somnia.contracts table or using Dune's contract verification dashboard.

Step 4: Create Queries and Dashboards

  Once decoded, your contract data will be available in tables with this naming convention:

  Events: [projectname]."contractName_evt_eventName"
  Function calls: [projectname]."contractName_call_functionName"

  Example queries you can create:
    sql-- Track all transactions to your contract
    SELECT * FROM somnia.transactions
    WHERE "to" = 0xYourContractAddress
    ORDER BY block_time DESC

    -- Query decoded events (after decoding)
    SELECT * FROM your_project."YourContract_evt_Transfer"
    WHERE evt_block_time >= NOW() - INTERVAL '7' DAY

    -- Monitor contract interactions
    SELECT
        evt_block_time,
        evt_tx_hash,
        "from",
        "to",
        value
    FROM your_project."YourContract_evt_EventName"
    ORDER BY evt_block_time DESC

Step 5: Build Dashboards

  Create a new dashboard on Dune
  Add visualizations based on your queries
  Track metrics like:

    Transaction volume
    Active users
    Token transfers
    Contract interactions over time
    Gas usage patterns


Dune Somnia Documentation: https://docs.dune.com/data-catalog/evm/somnia/overview
Somnia Dashboard: https://dune.com/chains/somnia
Contract Submission: https://dune.com/contracts/new
Somnia Testnet Explorer: https://shannon-explorer.somnia.network/

Since Somnia is now live on Dune with full chain history Layer3, you'll have access to all the data you need to build comprehensive analytics for your smart contract!
