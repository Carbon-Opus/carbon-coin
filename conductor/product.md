# CarbonOpus Product Specification & Codebase Reference (`product.md`)

This document serves as the authoritative product, architectural, and technical specification for the **CarbonOpus** codebase. It is designed to provide Gemini Conductor and development contributors with a complete, structured context of the product's vision, system components, smart contracts, GraphQL entities, economic models, and design standards.

---

## 1. Executive Product Overview & Core Vision

**CarbonOpus** is a social-first music platform and decentralized creator economy ecosystem designed to eliminate intermediaries and return financial control to independent musicians. Built on the **Somnia** blockchain, CarbonOpus replaces exploitative streaming models with direct music sales, viral fan resale rewards, creator tokenization, and AI-driven promotion tools.

### 1.1 The Core Problem
* **Streaming Exploitation**: Legacy platforms (Spotify, Apple Music) pay approximately \$0.003 per stream. Artists keep only 15–30% of generated revenue while distributors, labels, and platforms extract 70–85%. An independent artist requires over 300,000 monthly streams to reach a minimum wage income (\$15,000/year).
* **Fan Disenfranchisement**: Over 100 million engaged music fans discover and champion emerging talent with zero financial upside or true ownership of purchased digital audio.

### 1.2 The CarbonOpus Solution
* **Direct Sales with Fair Economics**: Artists set custom track pricing (\$0.09–\$4.99) and keep 84–99% of every sale. CarbonOpus collects a flat 1% platform fee.
* **Fan Resale Rewards (The Viral Loop)**: Fans who purchase music receive a unique shareable link. When new buyers purchase music via that link, the referring fan receives an artist-configurable reward (typically 15%, selectable from 1–50%).
* **Creator Tokens**: Artists launch personal ERC-20 tokens via bonding curves that graduate to Uniswap V3 liquidity pools. Fans buy tokens to invest in an artist's career trajectory.
* **AI Character Auto-Promotion**: Integrated AI tools (powered by Google Gemini & Imagen) allow artists and fans to deploy customized AI characters that generate posts, images, and automated cross-platform marketing content.
* **Audio-First Social Discovery**: A fusion of SoundCloud audio streaming and Twitter social discovery, featuring chronological and algorithmic feeds.

---

## 2. The Viral Loop Mechanics & Economic Flow

The core growth engine of CarbonOpus relies on aligned incentives across creators, fans, and the platform.

### 2.1 Standard Purchase & Resale Flow
When a track priced at **\$1.00** is purchased and shared:
1. **Artist Upload**: The artist uploads a track, sets the price at \$1.00, and specifies a 15% Fan Resale Reward.
2. **Initial Fan Purchase**: Fan A buys the song for \$1.00.
   - **Artist Earnings**: \$0.84 (84%)
   - **Resale Vault Allocation**: \$0.15 (15%)
   - **Platform Fee**: \$0.01 (1%)
3. **Viral Share & Subsequent Purchase**: Fan A generates a referral link and shares it. Fan B clicks the link and purchases the song for \$1.00.
   - **Artist Earnings**: \$0.84
   - **Fan A (Referrer Reward)**: \$0.15
   - **Platform Fee**: \$0.01

```
[ Artist Uploads Track ($1.00, 15% Reward) ]
                     │
                     ▼
[ Fan A Buys Track ($1.00) ] ──► Artist keeps $0.84 | Platform takes $0.01 | Vault holds $0.15
                     │
                     ▼
[ Fan A Shares Referral Link ]
                     │
                     ▼
[ Fan B Buys via Link ($1.00) ] ──► Artist keeps $0.84 | Fan A earns $0.15 | Platform takes $0.01
                     │
                     ▼
[ Repeatable Viral Expansion Loop ]
```

---

## 3. User Personas & Ecosystem Roles

| Role | Primary Activities | Value Proposition |
| :--- | :--- | :--- |
| **Artist (Creator)** | Uploads audio (MP3/WAV), sets pricing & resale percentages, launches creator tokens, configures AI characters. | Retains 84–99% of revenue, instant payouts, direct fan ownership, automated marketing. |
| **Buyer / Fan** | Discovers music on the feed, purchases tracks via ThirdWeb (fiat/crypto), streams & downloads audio. | True music ownership via non-transferable NFTs, unlimited streaming/downloads. |
| **Referrer (Promoter)** | Generates and shares unique track links across the Carbonverse or connected social media. | Earns 15% cash/crypto rewards per secondary sale generated through shared links. |
| **Token Holder** | Buys and trades Creator Tokens via bonding curves and decentralized exchanges. | Participates in artist growth, unlocks exclusive content, voting rights, and community perks. |
| **Protocol / Platform** | Enforces smart contract logic, manages treasury, executes circuit breakers, monitors bot activity. | Collects 1% music sales fee, 1% token launch fee, and 0.3% token trading fee. |

---

## 4. Technical Stack & System Architecture

The CarbonOpus codebase is structured across a modern web and mobile stack integrated with high-performance blockchain infrastructure.

### 4.1 Technology Stack Table

| Layer | Technology | Key Functionality |
| :--- | :--- | :--- |
| **Frontend Web** | React, Vite, Tailwind CSS | Single-page application, audio player, social feed, dashboard. |
| **Frontend Mobile** | React Native | iOS and Android native apps with audio streaming background service. |
| **Web3 & Payments** | ThirdWeb SDK, Ethers.js | Wallet connection, fiat-to-crypto payment rails, credit card processing. |
| **Backend & Cloud** | Node.js / Express, Google Firebase | Cloud Functions, Firestore, Realtime Database, user authentication. |
| **Storage Infrastructure** | Google Cloud / Firebase Storage, IPFS | High-speed global audio streaming, asset hosting, metadata distribution. |
| **AI Engine** | Google Gemini, Google Imagen | Caption generation, social post creation, promotional banner rendering. |
| **Blockchain** | Somnia Testnet / Mainnet | EVM-compatible reactive blockchain providing sub-second settlement and low gas fees. |
| **DEX / Liquidity** | Uniswap V3 | Automated market maker for creator token liquidity post-graduation. |

### 4.2 Somnia Blockchain Advantage
CarbonOpus leverages Somnia's **Reactive Primitives**, **Data Architecture**, and **Network Services**:
* **Reactive Primitives**: Automatically trigger real-time token transaction processing, price updates, and instant fan reward vault distributions upon purchase confirmation.
* **Data Streams**: Index on-chain audio ownership, purchase histories, and referral trees for Dune analytics and real-time app leaderboards.
* **Low-Cost Execution**: Eliminates the \$5–\$50 transaction gas fees typical of legacy chains, enabling micro-transactions at 1/100th of traditional cost.

---

## 5. Smart Contract Architecture

The core on-chain protocol consists of three primary Solidity contracts deployed on Somnia, alongside the auxiliary Phoenix NFT governance model.

### 5.1 Primary Contracts

```
                       ┌─────────────────────────┐
                       │ CarbonCoinLauncher.sol  │
                       │ (ERC-20 Token Factory)  │
                       └────────────┬────────────┘
                                    │ Deploys & Trades
                                    ▼
┌────────────────────────┐    ┌─────────────────────────┐
│     CarbonNFT.sol      │    │    Creator ERC-20       │
│ (Music Ownership NFT)  │    │  (Bonding Curve / DEX) │
└───────────┬────────────┘    └─────────────────────────┘
            │ Triggers Rewards
            ▼
┌────────────────────────┐
│   FanRewardVault.sol   │
│  (Resale Reward Pool)  │
└────────────────────────┘
```

#### 1. `CarbonNFT.sol`
* **Purpose**: Represents purchased music tracks as non-transferable proof-of-ownership NFTs.
* **Key Functions**:
  * `purchaseMusic(address artistAddress, string songId, uint256 price)`: Mints ownership NFT to buyer, routes 84–99% to artist, 1% to platform treasury, and 15% to reward vault.
  * `resaleReward(address originalBuyer, address reseller, uint256 price)`: Computes and triggers referral payouts.
  * `musicBalance(address userAddress)`: Returns array of owned tracks for playback verification.

#### 2. `CarbonCoinLauncher.sol`
* **Purpose**: Factory contract for deploying individual artist Creator Tokens (ERC-20).
* **Key Functions**:
  * `launchCarbonCoin(string artistName, uint256 supply, string symbol)`: Instantiates a new creator token on a bonding curve.
  * `mintTokens(address artistAddress, uint256 amount)`: Allocates initial creator supply.
  * `transferToken(address from, address to, uint256 amount)`: Executes secondary transfers and enforces platform trading fees.

#### 3. `FanRewardVault.sol`
* **Purpose**: Manages referral balances and reward claims.
* **Key Functions**:
  * `recordSale(string buyerId, string artistId, uint256 amount)`: Logs purchase event for referral linkage.
  * `calculateResaleReward(string originalBuyerId, string newBuyerId, uint256 amount)`: Evaluates artist-configured referral percentage.
  * `distributeReward(address recipientAddress, uint256 amount)`: Transfers accumulated ETH/tokens to referral wallet.
  * `claimRewards(address userAddress)`: Allows users to withdraw unclaimed referral earnings.

### 5.2 Auxiliary Incentive: Phoenix NFTs & PHX Token Engine
* **Soulbound Eggs**: Every active wallet receives a non-transferable Egg NFT.
* **Hatching Mechanism**: Users request to hatch their Egg; existing hatched Phoenix holders vote on the queue (3 votes required to hatch).
* **PHX Token Currency**: Voters and referrers earn PHX utility tokens. 70% of mint fees fund the Uniswap liquidity pool, 5% is allocated to a price-support reserve fund (buyback & burn), and 25% goes to the treasury.

---

## 6. GraphQL Subgraph Schemas & Data Entities

CarbonOpus utilizes two dedicated GraphQL subgraphs to query system state across token trading and music marketplace domains.

### 6.1 Token Creation & Trading Subgraph

```graphql
# Token Entity
type Token @entity {
  id: ID!
  creator: Creator!
  name: String!
  symbol: String!
  createdAt: BigInt!
  creationFee: BigInt!
  creatorAllocation: BigInt!
  graduated: Boolean!
  graduatedAt: BigInt
  dexPair: Bytes
  transactions: [Transaction!]!
  virtualEth: BigInt!
  virtualTokens: BigInt!
  maxSupply: BigInt!
  graduationThreshold: BigInt!
  realEthReserves: BigInt!
  realTokenSupply: BigInt!
  price: BigInt!
  totalHolders: BigInt!
  holders: [Holder!]!
  approvals: [Approval!]!
  whaleIntents: [WhaleIntent!]!
  isCircuitBreakerActive: Boolean!
  circuitBreakerTriggeredAt: BigInt
  circuitBreakerDuration: BigInt
  isPaused: Boolean!
  isTradingPaused: Boolean!
  lastPriceUpdate: BigInt!
  volatilityMoveCount: BigInt!
}

# Creator Entity
type Creator @entity {
  id: ID!
  tokens: [Token!]!
  createdAt: BigInt!
  totalFeesCollected: BigInt!
}

# User & Trading Entities
type User @entity {
  id: ID!
  tokens: [Holder!]!
  approvals: [Approval!]!
  whaleIntents: [WhaleIntent!]!
  blacklisted: Boolean!
  whitelisted: Boolean!
  bots: [Bot!]!
}

type Holder @entity {
  id: ID!
  user: User!
  token: Token!
  balance: BigInt!
}

type Transaction @entity {
  id: ID!
  token: Token!
  type: String!
  from: Bytes!
  to: Bytes!
  ethAmount: BigInt!
  tokenAmount: BigInt!
  price: BigInt!
  timestamp: BigInt!
}

type Approval @entity {
  id: ID!
  token: Token!
  owner: User!
  spender: Bytes!
  value: BigInt!
  timestamp: BigInt!
}

type WhaleIntent @entity {
  id: ID!
  token: Token!
  trader: User!
  amount: BigInt!
  isBuy: Boolean!
  executeAfter: BigInt!
  timestamp: BigInt!
  cancelled: Boolean!
  executed: Boolean!
}

type Bot @entity {
  id: ID!
  user: User!
  reason: String!
  timestamp: BigInt!
}

type Launcher @entity {
  id: ID!
  owner: Bytes!
  creationFee: BigInt!
  maxTokensPerCreator: BigInt!
  paused: Boolean!
  totalFeesCollected: BigInt!
  totalTokensCreated: BigInt
}
```

### 6.2 Music NFT Marketplace Subgraph

```graphql
type Song @entity {
  id: ID!
  artist: Artist!
  price: BigInt!
  referralPct: BigInt!
  createdAt: BigInt!
  purchases: [SongPurchase!]!
}

type Artist @entity {
  id: Bytes!
  address: Bytes!
  songs: [Song!]!
  rewards: BigInt!
  claimedRewards: [Reward!]!
}

type Buyer @entity {
  id: Bytes!
  address: Bytes!
  purchases: [SongPurchase!]!
}

type Referrer @entity {
  id: Bytes!
  address: Bytes!
  referrals: [SongPurchase!]!
  rewards: BigInt!
  claimedRewards: [Reward!]!
}

type SongPurchase @entity {
  id: ID!
  song: Song!
  buyer: Buyer!
  referrer: Referrer
  price: BigInt!
  timestamp: BigInt!
}

type Reward @entity {
  id: ID!
  artist: Artist
  referrer: Referrer
  amount: BigInt!
  timestamp: BigInt!
}

type Protocol @entity {
  id: ID!
  totalRewardsClaimed: BigInt!
  totalRewardsDistributed: BigInt!
  protocolFee: BigInt!
  treasury: Bytes!
  owner: Bytes!
  controller: Bytes!
}
```

---

## 7. Business Model & Revenue Engine

CarbonOpus operates a multi-tiered revenue model spanning seven distinct streams to ensure operational sustainability and high gross margins (70–80%).

### 7.1 Revenue Streams Table

| # | Revenue Stream | Rate / Pricing Structure | Description |
| :---: | :--- | :--- | :--- |
| **1** | **Music Sales Commission** | 1% of track price | Deducted from direct music purchases. |
| **2** | **Creator Token Launch Fee** | 1% of total token supply | Fee collected upon ERC-20 factory deployment. |
| **3** | **Token Trading Fee** | 0.3% per transaction | Fee on bonding curve trades prior to DEX graduation. |
| **4** | **Subscription Tiers** | \$9.99/mo (Pro) / \$29.99/mo (Elite) | Unlocks advanced analytics, higher AI credits, scheduling. |
| **5** | **AI Credit Sales** | \$5 (50 credits) / \$15 (200 credits) | À la carte credits for content generation and image rendering. |
| **6** | **Feed Advertising** | CPM-based ad placements | Displayed in social feed for free-tier users. |
| **7** | **Featured Listings** | \$50–\$500 per campaign | Promoted track placement in social and discovery feeds. |

---

## 8. AI Character & Promotion Subsystem

CarbonOpus integrates an automated marketing layer powered by Google Gemini and Google Imagen.

### 8.1 Functional Capabilities
* **AI Character Creation**: Artists and fans configure customized AI avatars with distinct biographies and voices.
* **Automated Post Generation**: Generates social captions, song reviews, and promotional announcements.
* **Cross-Platform Scheduling**: Schedules and publishes content across connected accounts (Instagram, TikTok, Facebook).
* **Viral Amplification**: AI characters automatically include referral links, continuously driving secondary sales and earning rewards for the account holder.

### 8.2 Strict Operational Constraints
* **No Hashtags**: Hashtags are prohibited within the Carbonverse interface.
* **Platform Nomenclature**: Uses native terminology (**Carbonverse**, **Resale Rewards**, **Creator Tokens**). External platforms are referenced only when citing low industry payout rates.

---

## 9. Branding, Typography & UI/UX Guidelines

The CarbonOpus interface combines a dark, premium aesthetic with vibrant interactive accents.

### 9.1 Color Palette
* **Primary Accent**: Vibrant Purple / Magenta (`#8B3DFF`) — CTAs, action buttons, active badges.
* **Main Background**: Deep Purple (`#1a0a2e` to `#2d1b4e`) — Main dark background container.
* **Secondary Background**: Dark Navy / Black (`#0a0515` to `#151020`) — Deep background contrast sections.
* **Interactive Highlights**: Bright Pink / Magenta — "Follow" states and active toggles.
* **Typography Colors**: White (`#FFFFFF`) for primary text, Light Gray (`#a0a0b0`) for secondary metadata, Mid Gray (`#5a5a6a`) for tertiary elements.

### 9.2 Typography & Structural Styling
* **Font Family**: Modern sans-serif (`Inter`, `SF Pro Display`, or system default).
* **Headings**: Semibold/Bold (600–700 weight), 18–28px.
* **Body Text**: Regular/Medium (400–500 weight), 14–16px.
* **Component Styling**: Cards and buttons utilize a consistent border radius of **12–16px**, padding of **16–24px**, subtle purple gradient overlays, and semi-transparent glassmorphism backgrounds.
