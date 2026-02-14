# CarbonCoin: ETH vs USDC Quick Reference

## Function Call Comparison

### BUY TOKENS

#### ETH Version
```solidity
// User pays gas
function buy(uint256 minTokensOut) external payable {
    // Uses msg.value for ETH amount
}
```

```javascript
// Frontend call
await carbonCoin.buy(minTokensOut, {
    value: ethers.utils.parseEther("1.0") // 1 ETH
});
```

#### USDC Version
```solidity
// Option 1: User pays gas with permit
function buyWithPermit(
    uint256 usdcAmount,
    uint256 minTokensOut,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s
) external

// Option 2: User pays gas with pre-approval
function buy(uint256 usdcAmount, uint256 minTokensOut) external

// Option 3: Backend pays gas (GASLESS for user)
function executeSponsoredBuy(
    address buyer,
    uint256 usdcAmount,
    uint256 minTokensOut,
    bytes32 uuid
) external
```

```javascript
// Frontend call - Option 1 (with permit)
const { v, r, s } = await signPermit(usdcAmount, carbonCoinAddress, deadline);
await carbonCoin.buyWithPermit(usdcAmount, minTokensOut, deadline, v, r, s);

// Frontend call - Option 2 (with approval)
await usdc.approve(carbonCoinAddress, usdcAmount);
await carbonCoin.buy(usdcAmount, minTokensOut);

// Frontend call - Option 3 (gasless)
await fetch('/api/sponsored-buy', {
    method: 'POST',
    body: JSON.stringify({ usdcAmount, minTokensOut, ...permitSig })
});
// Backend calls executeSponsoredBuy - user pays 0 gas!
```

---

### SELL TOKENS

#### ETH Version
```solidity
function sell(uint256 tokensIn, uint256 minEthOut) external
```

```javascript
await carbonCoin.sell(tokensAmount, minEthOut);
```

#### USDC Version
```solidity
// Option 1: User pays gas
function sell(uint256 tokensIn, uint256 minUsdcOut) external

// Option 2: Backend pays gas (GASLESS)
function executeSponsoredSell(
    address seller,
    uint256 tokensIn,
    uint256 minUsdcOut,
    bytes32 uuid
) external
```

```javascript
// Option 1
await carbonCoin.sell(tokensAmount, minUsdcOut);

// Option 2 (gasless)
await fetch('/api/sponsored-sell', {
    method: 'POST',
    body: JSON.stringify({ tokensAmount, minUsdcOut })
});
```

---

### PRICE CALCULATIONS

#### ETH Version
```solidity
function getCurrentPrice() public view returns (uint256) {
    return (totalEth * 10**18) / totalTokens; // 18 decimals
}

function calculateTokensOut(uint256 ethIn) public view returns (uint256)
function calculateEthIn(uint256 tokensOut) public view returns (uint256)
function calculateEthOut(uint256 tokensIn) public view returns (uint256)
```

#### USDC Version
```solidity
function getCurrentPrice() public view returns (uint256) {
    return (totalUsdc * 10**6) / totalTokens; // 6 decimals
}

function calculateTokensOut(uint256 usdcIn) public view returns (uint256)
function calculateUsdcIn(uint256 tokensOut) public view returns (uint256)
function calculateUsdcOut(uint256 tokensIn) public view returns (uint256)
```

---

### RESERVES

#### ETH Version
```solidity
uint256 public immutable VIRTUAL_ETH;
uint256 public realEthReserves;

function getReserves() external view returns (
    uint256 ethReserves,
    uint256 tokenSupply,
    uint256 virtualEth,
    uint256 virtualTokens
)
```

#### USDC Version
```solidity
uint256 public immutable VIRTUAL_USDC;
uint256 public realUsdcReserves;

function getReserves() external view returns (
    uint256 usdcReserves,
    uint256 tokenSupply,
    uint256 virtualUsdc,
    uint256 virtualTokens
)
```

---

## Constructor Comparison

### ETH Version
```solidity
constructor(
    string memory name,
    string memory symbol,
    address _creator,
    address _router,
    address _config,
    BondingCurveConfig memory bondingCurveConfig
)
```

### USDC Version
```solidity
constructor(
    string memory name,
    string memory symbol,
    address _creator,
    address _usdc,                    // NEW
    address _permitAndTransfer,       // NEW
    address _router,
    address _config,
    BondingCurveConfig memory bondingCurveConfig
)
```

---

## Event Comparison

### ETH Version
```solidity
event TokensPurchased(
    address indexed buyer,
    uint256 ethAmount,
    uint256 tokensOut,
    uint256 price,
    uint256 ethReserves,
    uint256 tokenSupply,
    uint256 timestamp
);

event TokensSold(
    address indexed seller,
    uint256 tokensIn,
    uint256 ethOut,
    uint256 price,
    uint256 ethReserves,
    uint256 tokenSupply,
    uint256 timestamp
);
```

### USDC Version
```solidity
event TokensPurchased(
    address indexed buyer,
    uint256 usdcAmount,       // was ethAmount
    uint256 tokensOut,
    uint256 price,
    uint256 usdcReserves,     // was ethReserves
    uint256 tokenSupply,
    uint256 timestamp
);

event TokensSold(
    address indexed seller,
    uint256 tokensIn,
    uint256 usdcOut,          // was ethOut
    uint256 price,
    uint256 usdcReserves,     // was ethReserves
    uint256 tokenSupply,
    uint256 timestamp
);

// NEW EVENTS
event SponsoredBuy(
    address indexed buyer,
    uint256 usdcAmount,
    uint256 tokensOut,
    bytes32 indexed uuid,
    uint256 timestamp
);

event SponsoredSell(
    address indexed seller,
    uint256 tokensIn,
    uint256 usdcOut,
    bytes32 indexed uuid,
    uint256 timestamp
);
```

---

## Graduation Comparison

### ETH Version
```solidity
function _graduate() internal {
    // Add ETH/Token liquidity
    dexRouter.addLiquidityETH{value: ethForLiquidity}(
        address(this),
        remainingTokens,
        (remainingTokens * 95) / 100,
        (ethForLiquidity * 95) / 100,
        creator,
        block.timestamp + 60
    )
}
```

### USDC Version
```solidity
function _graduate() internal {
    // Approve USDC for router
    USDC.approve(address(dexRouter), realUsdcReserves);
    
    // Add USDC/Token liquidity
    dexRouter.addLiquidity(
        address(USDC),           // tokenA (USDC)
        address(this),           // tokenB (this token)
        usdcForLiquidity,
        remainingTokens,
        (usdcForLiquidity * 95) / 100,
        (remainingTokens * 95) / 100,
        creator,
        block.timestamp + 60
    )
}
```

---

## Decimal Handling

### ETH (18 decimals)
```javascript
// JavaScript
const ethAmount = ethers.utils.parseEther("1.5");  // 1.5 ETH
// = 1500000000000000000 (18 zeros)

// Solidity
uint256 oneEth = 1 ether; // = 10**18
```

### USDC (6 decimals)
```javascript
// JavaScript
const usdcAmount = ethers.utils.parseUnits("1000", 6);  // 1000 USDC
// = 1000000000 (6 zeros)

// Solidity
uint256 oneUsdc = 1 * 10**6; // = 1,000,000
uint256 thousandUsdc = 1000 * 10**6; // = 1,000,000,000
```

---

## Price Impact Threshold

### ETH Version
```solidity
// Check price impact for trades >= 1 ETH
if (!whitelist[buyer] && ethAmount >= 1 ether) {
    // Check impact
}
```

### USDC Version
```solidity
// Check price impact for trades >= 1000 USDC
if (!whitelist[buyer] && usdcAmount >= 1000 * 10**6) {
    // Check impact
}
```

---

## Configuration Values

### BondingCurveConfig

#### ETH Version
```solidity
BondingCurveConfig({
    virtualEth: 30 ether,                    // 30 ETH
    virtualTokens: 1_073_000_000 * 10**18,
    maxSupply: 800_000_000 * 10**18,
    graduationThreshold: 85 ether            // 85 ETH
})
```

#### USDC Version
```solidity
BondingCurveConfig({
    virtualEth: 30 * 10**6,                  // 30 USDC (still called virtualEth)
    virtualTokens: 1_073_000_000 * 10**18,
    maxSupply: 800_000_000 * 10**18,
    graduationThreshold: 85_000 * 10**6      // 85,000 USDC
})
```

### Whale Limits

#### ETH Version
```solidity
WhaleLimitConfig({
    maxTradeSize: 10 ether,
    maxSellPercentage: 500,
    whaleThreshold: 5 ether,
    whaleDelay: 300
})
```

#### USDC Version
```solidity
WhaleLimitConfig({
    maxTradeSize: 10_000 * 10**6,      // 10,000 USDC
    maxSellPercentage: 500,
    whaleThreshold: 5_000 * 10**6,     // 5,000 USDC
    whaleDelay: 300
})
```

---

## Gas Costs (Approximate)

| Operation | ETH Version | USDC Version | Difference |
|-----------|-------------|--------------|------------|
| Buy (user pays) | ~50,000 | ~80,000 | +60% |
| Buy (sponsored) | 0 (user) | 0 (user) | 🎉 FREE |
| Sell (user pays) | ~45,000 | ~75,000 | +67% |
| Sell (sponsored) | 0 (user) | 0 (user) | 🎉 FREE |
| Approve USDC | N/A | ~45,000 | One-time |
| Permit (off-chain) | N/A | 0 | FREE |

---

## Common Patterns

### Pattern: Get Quote for Purchase

#### ETH
```javascript
const ethAmount = ethers.utils.parseEther("1.0");
const tokensOut = await carbonCoin.calculateTokensOut(ethAmount);
const currentPrice = await carbonCoin.getCurrentPrice();
```

#### USDC
```javascript
const usdcAmount = ethers.utils.parseUnits("1000", 6); // 1000 USDC
const tokensOut = await carbonCoin.calculateTokensOut(usdcAmount);
const currentPrice = await carbonCoin.getCurrentPrice(); // Returns USDC price
```

### Pattern: Execute Purchase

#### ETH (User Pays)
```javascript
const tx = await carbonCoin.buy(minTokensOut, {
    value: ethers.utils.parseEther("1.0")
});
await tx.wait();
```

#### USDC (Gasless - Recommended)
```javascript
// 1. Sign permit (free, off-chain)
const { v, r, s, deadline } = await signUSDCPermit(
    usdcAmount,
    carbonCoinAddress
);

// 2. Send to backend
const response = await fetch('/api/sponsored-buy', {
    method: 'POST',
    body: JSON.stringify({
        carbonCoinAddress,
        usdcAmount,
        minTokensOut,
        deadline,
        v, r, s
    })
});

const { orderId, txHash } = await response.json();

// 3. User pays ZERO gas, backend handles everything
```

### Pattern: Check if User Can Trade

#### Both Versions
```javascript
// Check cooldown
const cooldown = await carbonCoin.getUserCooldown(userAddress);
if (cooldown > 0) {
    console.log(`Must wait ${cooldown} seconds`);
}

// Check whale status
const { canTradeNow, nextTradeAvailable } = await carbonCoin.getWhaleCooldown(userAddress);

// Check if whale intent needed
const { whaleThreshold } = await carbonCoin.getTradeLimits();
if (amount >= whaleThreshold) {
    console.log("This requires whale intent registration");
}
```

---

## Backend Integration Snippets

### Listen for Sponsored Buys

```javascript
// ETH Version - Not applicable

// USDC Version
const permitFilter = permitAndTransfer.filters.PermitTransfer(
    null,  // senderId
    usdcAddress,  // token
    null,  // owner
    carbonCoinAddress  // spender
);

permitAndTransfer.on(permitFilter, async (senderId, token, owner, spender, value, uuid, event) => {
    console.log(`USDC transferred for order ${uuid}`);
    
    // Execute sponsored buy
    await carbonCoin.executeSponsoredBuy(
        owner,  // buyer
        value,  // usdcAmount
        minTokensOut,
        uuid
    );
});
```

### Monitor Sponsored Events

```javascript
// USDC Version Only
carbonCoin.on('SponsoredBuy', (buyer, usdcAmount, tokensOut, uuid, timestamp) => {
    console.log(`Sponsored buy completed for ${buyer}`);
    // Update order in database
    db.orders.update({ uuid }, { 
        status: 'completed',
        tokensReceived: tokensOut.toString(),
        completedAt: new Date(timestamp * 1000)
    });
});
```

---

## Key Differences Summary

| Feature | ETH Version | USDC Version |
|---------|-------------|--------------|
| **Payment** | Native ETH | USDC ERC20 |
| **Approval** | Not needed | Required (or use permit) |
| **Decimals** | 18 | 6 |
| **Gas (user)** | Yes | Optional |
| **Gasless option** | No | Yes (via backend) |
| **Price volatility** | Volatile | Stable |
| **Graduation pair** | ETH/Token | USDC/Token |
| **Order tracking** | txHash only | UUID + txHash |
| **Backend integration** | Minimal | Extensive |

---

## Migration Checklist

When switching from ETH to USDC:

- [ ] Update all ETH amounts to USDC (divide by ~1e12 for similar value)
- [ ] Change decimals from 18 to 6 in all amount handling
- [ ] Add USDC token address parameter
- [ ] Add PermitAndTransfer address parameter
- [ ] Implement permit signing in frontend
- [ ] Set up PermitTransfer event listener
- [ ] Implement executeSponsoredBuy in backend
- [ ] Update graduation logic for USDC pair
- [ ] Test all flows thoroughly
- [ ] Update frontend to show USDC instead of ETH
- [ ] Update price calculations for 6 decimals

---

## Quick Start: Minimal Working Example

### USDC Gasless Buy (Full Flow)

```javascript
// 1. FRONTEND: User signs permit
const permitData = {
    owner: userAddress,
    spender: carbonCoinAddress,
    value: usdcAmount,
    nonce: await usdc.nonces(userAddress),
    deadline: Math.floor(Date.now() / 1000) + 3600
};

const domain = {
    name: 'USD Coin',
    version: '2',
    chainId: await provider.getNetwork().chainId,
    verifyingContract: usdcAddress
};

const types = {
    Permit: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' }
    ]
};

const signature = await signer._signTypedData(domain, types, permitData);
const { v, r, s } = ethers.utils.splitSignature(signature);

// 2. Send to backend
await fetch('/api/buy', {
    method: 'POST',
    body: JSON.stringify({
        carbonCoinAddress,
        usdcAmount,
        minTokensOut,
        deadline: permitData.deadline,
        v, r, s
    })
});

// 3. BACKEND: Handle request
app.post('/api/buy', async (req, res) => {
    const { carbonCoinAddress, usdcAmount, deadline, v, r, s } = req.body;
    const uuid = uuidv4();
    
    // Call PermitAndTransfer
    await permitAndTransfer.permitAndTransfer(
        ethers.utils.id(userAddress),
        uuid,
        usdcAddress,
        userAddress,
        carbonCoinAddress,
        usdcAmount,
        deadline,
        v, r, s
    );
    
    res.json({ uuid });
});

// 4. BACKEND: Listen for event
permitAndTransfer.on('PermitTransfer', async (...args) => {
    const uuid = args[5];
    
    // Execute sponsored buy
    await carbonCoin.executeSponsoredBuy(
        userAddress,
        usdcAmount,
        minTokensOut,
        uuid
    );
});

// 5. User receives tokens - paid ZERO gas! 🎉
```

This is the complete flow that makes your platform incredibly user-friendly!
