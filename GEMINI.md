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
-   **Events:** `SongCreated`, `MemberAddressUpdated`.

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
-   **Events:** `SongPurchased`, `RewardsDistributed`.

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


-------

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
