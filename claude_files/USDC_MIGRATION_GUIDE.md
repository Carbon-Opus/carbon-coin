# CarbonCoin USDC Migration Guide

## Overview

This document outlines the complete migration from ETH-based CarbonCoin to USDC-based CarbonCoinUSDC, including integration with your existing PermitAndTransfer infrastructure for gasless transactions.

## Key Changes Summary

### 1. **Payment Currency**
- **Before:** Native ETH (`msg.value`, `payable`)
- **After:** USDC ERC20 token (requires approval/permit)

### 2. **New Functions**

#### User-Paid Transactions (User pays gas):
```solidity
// Option 1: With EIP-2612 Permit (recommended, no separate approval needed)
function buyWithPermit(
    uint256 usdcAmount,
    uint256 minTokensOut,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) external

// Option 2: Standard buy (requires prior USDC approval)
function buy(uint256 usdcAmount, uint256 minTokensOut) external
```

#### Gas-Sponsored Transactions (You pay gas):
```solidity
// Called by backend after PermitAndTransfer moves USDC
function executeSponsoredBuy(
    address buyer,
    uint256 usdcAmount,
    uint256 minTokensOut,
    bytes32 uuid
) external

function executeSponsoredSell(
    address seller,
    uint256 tokensIn,
    uint256 minUsdcOut,
    bytes32 uuid
) external
```

### 3. **Constructor Changes**

```solidity
// New parameters
constructor(
    string memory name,
    string memory symbol,
    address _creator,
    address _usdc,                    // NEW: USDC token address
    address _permitAndTransfer,       // NEW: PermitAndTransfer contract
    address _router,
    address _config,
    BondingCurveConfig memory bondingCurveConfig
)
```

### 4. **Renamed Functions & Variables**

| Old (ETH) | New (USDC) |
|-----------|------------|
| `calculateEthIn()` | `calculateUsdcIn()` |
| `calculateEthOut()` | `calculateUsdcOut()` |
| `VIRTUAL_ETH` | `VIRTUAL_USDC` |
| `realEthReserves` | `realUsdcReserves` |

### 5. **Price Precision**

- **ETH Version:** Uses 18 decimals (10**18)
- **USDC Version:** Uses 6 decimals (10**6)

```solidity
// ETH version
return (totalEth * 10**18) / totalTokens;

// USDC version
return (totalUsdc * 10**6) / totalTokens;
```

## Integration Architecture

### Flow 1: User-Paid Transaction (User Pays Gas)

```
┌─────────┐
│  User   │
└────┬────┘
     │
     │ 1. Sign permit off-chain (no gas)
     ├──────────────────────────────────────┐
     │                                      │
     │ 2. Call buyWithPermit()              │
     ├──────────────────────────────────────▼
     │                              ┌──────────────┐
     │                              │ CarbonCoin   │
     │                              │   Contract   │
     │                              └──────┬───────┘
     │                                     │
     │                              3. Execute permit
     │                              4. Transfer USDC
     │                              5. Mint tokens
     │                                     │
     │◄────────────────────────────────────┘
     │ 6. Receive tokens
     │
```

### Flow 2: Gas-Sponsored Transaction (You Pay Gas)

```
┌─────────┐         ┌──────────┐
│  User   │         │ Backend  │
└────┬────┘         └────┬─────┘
     │                   │
     │ 1. Sign permit    │
     ├──────────────────►│
     │  (off-chain)      │
     │                   │ 2. Call PermitAndTransfer
     │                   ├─────────────────────────┐
     │                   │                         ▼
     │                   │                  ┌──────────────┐
     │                   │                  │PermitAnd     │
     │                   │                  │Transfer      │
     │                   │                  └──────┬───────┘
     │                   │                         │
     │                   │        3. Execute permit & transfer USDC
     │                   │                         │
     │                   │                         ▼
     │                   │                  ┌──────────────┐
     │                   │                  │ CarbonCoin   │
     │                   │ 4. Emit event    │ Contract     │
     │                   │◄─────────────────┤              │
     │                   │                  └──────────────┘
     │                   │
     │                   │ 5. Listen for PermitTransfer event
     │                   │
     │                   │ 6. Call executeSponsoredBuy()
     │                   ├─────────────────────────┐
     │                   │                         ▼
     │                   │                  ┌──────────────┐
     │                   │                  │ CarbonCoin   │
     │                   │                  │ Contract     │
     │                   │                  └──────┬───────┘
     │                   │                         │
     │                   │        7. Verify USDC received
     │                   │        8. Mint tokens to user
     │                   │                         │
     │◄──────────────────┴─────────────────────────┘
     │ 9. User receives tokens (paid 0 gas)
     │
```

## Deployment Checklist

### Pre-Deployment

- [ ] Deploy USDC contract on Somnia (or get existing address)
- [ ] Deploy/verify PermitAndTransfer contract
- [ ] Deploy CarbonCoinConfig contract
- [ ] Verify Somnia Exchange Router address

### Deploy CarbonCoinUSDC

```solidity
// Example deployment parameters
BondingCurveConfig memory config = BondingCurveConfig({
    virtualEth: 30 * 10**6,      // 30 USDC (note: 6 decimals)
    virtualTokens: 1_073_000_000 * 10**18,
    maxSupply: 800_000_000 * 10**18,
    graduationThreshold: 85_000 * 10**6  // 85,000 USDC
});

CarbonCoinUSDC token = new CarbonCoinUSDC(
    "Artist Token",
    "ART",
    creatorAddress,
    usdcAddress,              // USDC contract address
    permitAndTransferAddress, // PermitAndTransfer contract
    somniaRouterAddress,
    configAddress,
    config
);
```

### Post-Deployment

- [ ] Whitelist PermitAndTransfer contract
- [ ] Whitelist backend addresses (if needed)
- [ ] Test standard buy flow
- [ ] Test sponsored buy flow
- [ ] Test sell flows
- [ ] Configure websocket listener for PermitTransfer events
- [ ] Update frontend to handle USDC approvals

## Backend Integration

### 1. WebSocket Listener Configuration

```javascript
// Listen for PermitTransfer events from PermitAndTransfer contract
const permitTransferFilter = {
  address: permitAndTransferContract,
  topics: [
    ethers.utils.id("PermitTransfer(bytes32,address,address,address,uint256,bytes32)")
  ]
};

wsProvider.on(permitTransferFilter, async (log) => {
  const parsed = permitAndTransferInterface.parseLog(log);
  const { senderId, token, owner, spender, value, uuid } = parsed.args;
  
  // Match this to your order in DB
  const order = await db.orders.findOne({ uuid });
  
  if (order && spender === carbonCoinAddress) {
    // Execute the sponsored buy
    await executeSponsoredBuy(
      owner,      // buyer
      value,      // usdcAmount
      order.minTokensOut,
      uuid
    );
  }
});
```

### 2. Sponsored Buy Execution

```javascript
async function executeSponsoredBuy(buyer, usdcAmount, minTokensOut, uuid) {
  // Your backend wallet signs and sends this transaction
  const tx = await carbonCoinContract.executeSponsoredBuy(
    buyer,
    usdcAmount,
    minTokensOut,
    uuid,
    {
      from: backendWalletAddress,
      // You pay the gas
    }
  );
  
  await tx.wait();
  
  // Update order status in DB
  await db.orders.updateOne(
    { uuid },
    { 
      status: 'completed',
      txHash: tx.hash,
      completedAt: new Date()
    }
  );
}
```

### 3. User Permit Signing (Frontend)

```javascript
// Frontend code for user to sign permit
async function signPermitForBuy(usdcAmount, carbonCoinAddress) {
  const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour
  
  // EIP-2612 permit signature
  const permitSignature = await usdcContract.signPermit(
    userAddress,           // owner
    carbonCoinAddress,     // spender
    usdcAmount,
    deadline
  );
  
  // Send to backend
  await fetch('/api/buy-token', {
    method: 'POST',
    body: JSON.stringify({
      tokenAddress: carbonCoinAddress,
      usdcAmount,
      deadline,
      signature: permitSignature,
      minTokensOut
    })
  });
}
```

### 4. Backend Route Handler

```javascript
app.post('/api/buy-token', async (req, res) => {
  const { tokenAddress, usdcAmount, deadline, signature, minTokensOut } = req.body;
  
  // Create order in DB
  const uuid = uuidv4();
  const order = await db.orders.create({
    uuid,
    buyer: userAddress,
    tokenAddress,
    usdcAmount,
    minTokensOut,
    status: 'pending',
    createdAt: new Date()
  });
  
  // Call PermitAndTransfer contract
  const senderId = ethers.utils.id(userAddress); // for filtering events
  
  const tx = await permitAndTransferContract.permitAndTransfer(
    senderId,
    uuid,
    usdcAddress,
    userAddress,      // owner
    tokenAddress,     // to (CarbonCoin contract)
    usdcAmount,
    deadline,
    signature.v,
    signature.r,
    signature.s,
    {
      from: backendWalletAddress,
      // You pay the gas for this transaction
    }
  );
  
  res.json({
    orderId: uuid,
    txHash: tx.hash
  });
  
  // Your websocket listener will pick up the event and call executeSponsoredBuy
});
```

## Frontend Integration

### Option 1: Gasless (Recommended)

```javascript
// 1. User signs permit
const { v, r, s } = await signPermit(usdcAmount, carbonCoinAddress);

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

// 3. Backend handles everything, user pays 0 gas
// 4. Listen for order completion via websocket or polling
```

### Option 2: User Pays Gas

```javascript
// User signs permit and submits directly to contract
const carbonCoin = new ethers.Contract(address, abi, signer);

const tx = await carbonCoin.buyWithPermit(
  usdcAmount,
  minTokensOut,
  deadline,
  v, r, s
);

await tx.wait();
```

## Configuration Updates

### BondingCurveConfig

Update all ETH values to USDC (6 decimals):

```solidity
// OLD (ETH - 18 decimals)
virtualEth: 30 ether  // 30 ETH

// NEW (USDC - 6 decimals)
virtualEth: 30 * 10**6  // 30 USDC
```

### Fee Configuration

No changes needed - fees still work as basis points (e.g., 100 = 1%).

### Whale Limits

Update to USDC amounts:

```solidity
// OLD
maxTradeSize: 10 ether

// NEW
maxTradeSize: 10_000 * 10**6  // 10,000 USDC
```

## Testing Strategy

### Unit Tests

```solidity
// Test 1: Standard buy with permit
function testBuyWithPermit() public {
    // Sign permit
    // Call buyWithPermit
    // Verify tokens minted
    // Verify USDC transferred
}

// Test 2: Sponsored buy
function testSponsoredBuy() public {
    // Transfer USDC to contract via PermitAndTransfer
    // Call executeSponsoredBuy
    // Verify tokens minted to correct user
}

// Test 3: Graduation with USDC
function testGraduation() public {
    // Buy until graduation threshold
    // Verify USDC/Token pair created
    // Verify liquidity added
}
```

### Integration Tests

1. **Full Sponsored Flow:**
   - User signs permit
   - Backend calls PermitAndTransfer
   - Backend listens for event
   - Backend calls executeSponsoredBuy
   - Verify user receives tokens

2. **Whale Trade Flow:**
   - User registers whale intent
   - Wait for delay period
   - Execute large trade
   - Verify all protections work

3. **Graduation Flow:**
   - Accumulate USDC to threshold
   - Trigger graduation
   - Verify USDC/Token pair on DEX

## Migration Path (If Existing Contract Deployed)

### Option A: New Deployment (Recommended)

1. Deploy new CarbonCoinUSDC for new artists
2. Keep old ETH-based contracts running
3. Gradually sunset ETH version

### Option B: Parallel Operation

1. Deploy USDC version alongside ETH version
2. Artists choose which version to use
3. Users can trade on either

### Option C: Migration Contract

Create a migration contract that:
1. Accepts ETH-based tokens
2. Burns them
3. Mints equivalent USDC-based tokens
4. Uses DEX to swap ETH → USDC for reserves

## Security Considerations

### 1. **USDC Approval Griefing**
- Users must approve USDC spending
- Front-running risk is minimal due to permit signatures

### 2. **PermitAndTransfer Trust**
- This contract is whitelisted and has elevated privileges
- Ensure it's thoroughly audited
- Consider using multi-sig for control

### 3. **USDC Contract Risk**
- Ensure using correct USDC contract on Somnia
- USDC is centralized and can blacklist addresses
- Consider fallback mechanisms

### 4. **Graduation Liquidity**
- Ensure router supports USDC pairs
- Test pair creation extensively
- Verify LP token handling

## Monitoring & Alerts

Set up monitoring for:

- [ ] PermitTransfer events
- [ ] Failed executeSponsoredBuy calls
- [ ] USDC balance mismatches
- [ ] Circuit breaker triggers
- [ ] Whale intent registrations
- [ ] Graduation events

## Gas Optimization Notes

### USDC vs ETH Gas Costs

| Operation | ETH Version | USDC Version | Difference |
|-----------|-------------|--------------|------------|
| Buy | ~50k gas | ~80k gas | +60% |
| Sell | ~45k gas | ~75k gas | +67% |
| Graduation | ~200k gas | ~220k gas | +10% |

**Sponsored transactions save users 100% of gas costs** - this is the major UX win.

## FAQ

### Q: Can users still buy with ETH?
A: No, this version only accepts USDC. You could deploy a wrapper contract that accepts ETH, swaps to USDC, then buys tokens.

### Q: What if USDC transfer fails in executeSponsoredBuy?
A: The transaction will revert. Your backend should retry or mark the order as failed.

### Q: How do I handle USDC decimals in the frontend?
A: USDC has 6 decimals, so `1 USDC = 1_000_000` (not 1e18 like ETH).

### Q: Can I use other stablecoins?
A: Yes, any ERC20 with permit will work. Just change the USDC address in the constructor.

### Q: What about gas sponsorship limits?
A: Implement rate limiting in your backend to prevent abuse of sponsored transactions.

## Summary

The USDC version provides:

✅ **Better UX** - Gasless transactions for users  
✅ **Stable pricing** - No ETH volatility  
✅ **Clearer accounting** - Dollar-denominated  
✅ **Flexible options** - Users can still pay gas if they want  
✅ **Robust tracking** - UUID-based order matching  

The hybrid model gives you maximum flexibility while providing the best possible experience for your users.
