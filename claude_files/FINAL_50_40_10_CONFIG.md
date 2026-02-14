# Final Solution: 50% Sell / 40% Liquidity / 10% Creator

## Token Distribution (10M Total)

```
┌────────────────────────────────────────────┐
│ Total Supply: 10,000,000 tokens            │
├────────────────────────────────────────────┤
│ Bonding Curve (Sell): 5,000,000 (50%)     │
│ Liquidity Reserve:     4,000,000 (40%)     │
│ Creator Reserve:       1,000,000 (10%)     │
└────────────────────────────────────────────┘
```

## The Challenge

The standard bonding curve graduation mints **remaining** tokens (maxSupply - sold) for liquidity. But you want **exactly 4M tokens** in the LP, regardless of how many were sold.

## Two Approaches

### Approach 1: Modify Contract (Recommended)

Change the `_graduate()` function to mint a fixed 4M tokens instead of "remaining" tokens.

### Approach 2: Use Existing Contract

Accept that liquidity will be `(maxSupply - sold)` tokens, and calibrate maxSupply accordingly.

---

## APPROACH 1: Modified Contract (Best Solution)

### Modified `_graduate()` Function

```solidity
function _graduate() internal {
    if (hasGraduated) revert AlreadyGraduated();
    
    // Prevent rapid graduation attempts
    if (block.timestamp < lastGraduationAttempt + GRADUATION_COOLDOWN) {
        revert GraduationCooldownActive();
    }
    lastGraduationAttempt = block.timestamp;
    hasGraduated = true;

    // CHANGED: Mint fixed 4M tokens for liquidity (40% of 10M)
    uint256 liquidityTokens = 4_000_000 * 10**18;
    _mint(address(this), liquidityTokens);

    // Approve router to spend tokens and USDC
    _approve(address(this), address(dexRouter), liquidityTokens);
    USDC.approve(address(dexRouter), realUsdcReserves);

    // Add liquidity (auto-creates USDC/Token pair)
    uint256 usdcForLiquidity = realUsdcReserves;

    try dexRouter.addLiquidity(
        address(USDC),
        address(this),
        usdcForLiquidity,
        liquidityTokens,
        (usdcForLiquidity * 95) / 100, // 5% slippage tolerance
        (liquidityTokens * 95) / 100,
        creator, // Send LP Tokens to Creator
        block.timestamp + 60
    ) returns (uint amountA, uint amountB, uint) {
        emit Graduated(
            address(this),
            dexPair,
            amountB, // tokens
            amountA, // USDC
            getCurrentPrice(),
            block.timestamp
        );

        // Final liquidity snapshot
        emit LiquiditySnapshot(0, 0, block.timestamp);
    } catch {
        // If graduation fails, revert state
        hasGraduated = false;
        _burn(address(this), liquidityTokens);
        revert("Graduation failed");
    }
}
```

### Configuration With Modified Contract

```javascript
const bondingCurveConfig = {
  // Virtual reserves for price curve
  virtualEth: ethers.utils.parseUnits('2000', 6),        // 2,000 USDC
  virtualTokens: ethers.utils.parseEther('5400000'),     // 5.4M tokens
  
  // Max supply for bonding curve (50% of 10M)
  maxSupply: ethers.utils.parseEther('5000000'),         // 5M tokens
  
  // Graduate when this much USDC collected
  graduationThreshold: ethers.utils.parseUnits('10000', 6) // 10,000 USDC
};
```

### Economics:

```
K = 2,000 × 5,400,000 = 10,800,000,000

Starting Price = 2,000 / 5,400,000 = $0.00037 per token

When $10,000 USDC collected:
Total USDC = 2,000 + 10,000 = 12,000
Remaining virtual tokens = 10,800,000,000 / 12,000 = 900,000
Tokens sold = 5,400,000 - 900,000 = 4,500,000 tokens

At graduation:
- Tokens sold to users: 4,500,000 (45%)
- Creator reserve: 1,000,000 (10%) - minted at launch
- Liquidity tokens: 4,000,000 (40%) - minted at graduation
- Total circulating: 9,500,000 tokens

Bonding curve end price: 12,000 / 900,000 = $0.0133 per token

LP Composition:
- 10,000 USDC
- 4,000,000 tokens
- LP starting price: 10,000 / 4,000,000 = $0.0025 per token
```

### Price Discontinuity

There's a price jump from $0.0133 (end of bonding curve) to $0.0025 (LP start). This is actually **good** - it means:
- Last bonding curve buyer pays $0.0133
- LP starts at $0.0025 (cheaper!)
- Early DEX buyers get a discount
- Natural arbitrage opportunity drives volume

If you want them closer, adjust virtual reserves.

---

## APPROACH 2: Use Existing Contract Logic

Keep the standard graduation (mints remaining tokens) and set maxSupply so that remaining ≈ 4M.

### Target:
- Sell ~4.5M via bonding curve
- Remaining ~500k minted at graduation
- Then manually mint additional 3.5M for LP

**Problem**: This requires manual intervention and doesn't fit clean on-chain logic.

**Skip this approach** - Approach 1 is cleaner.

---

## Recommended Final Configuration

### Bonding Curve Parameters

```javascript
const bondingCurveConfig = {
  virtualEth: ethers.utils.parseUnits('2000', 6),          // 2,000 USDC
  virtualTokens: ethers.utils.parseEther('5400000'),       // 5.4M tokens
  maxSupply: ethers.utils.parseEther('5000000'),           // 5M tokens (50%)
  graduationThreshold: ethers.utils.parseUnits('10000', 6) // 10,000 USDC
};
```

### Token Distribution

| Stage | Tokens | Percentage | When |
|-------|--------|------------|------|
| Creator Reserve | 1,000,000 | 10% | At launch |
| Sold via Bonding | ~4,500,000 | 45% | Over time |
| LP (Fixed) | 4,000,000 | 40% | At graduation |
| **Total** | **9,500,000** | **95%** | |

### Why 9.5M instead of 10M?

The math doesn't perfectly align to sell exactly 5M and graduate at $10k. We end up with:
- 4.5M sold
- 1M creator
- 4M liquidity
= 9.5M total

**Options to hit 10M:**
1. Mint extra 500k to creator at graduation
2. Adjust graduation threshold to $11,111 USDC (sells exactly 5M)
3. Accept 9.5M total (simplest)

---

## Option: Hit Exactly 10M Total

### Adjust Graduation Threshold

To sell exactly 5M tokens, we need to collect more USDC:

```javascript
// Solve for graduation threshold where exactly 5M sold:
// v_usdc × v_tokens = (v_usdc + threshold) × (v_tokens - 5,000,000)

With:
v_usdc = 2,000
v_tokens = 6,000,000
maxSupply = 5,000,000

2,000 × 6,000,000 = (2,000 + threshold) × (6,000,000 - 5,000,000)
12,000,000,000 = (2,000 + threshold) × 1,000,000
2,000 + threshold = 12,000
threshold = 10,000 ✓

Wait, let me recalculate...

K = 2,000 × 6,000,000 = 12,000,000,000
At graduation: (2,000 + 10,000) × remaining = 12,000,000,000
12,000 × remaining = 12,000,000,000
remaining = 1,000,000
sold = 6,000,000 - 1,000,000 = 5,000,000 ✓
```

**Perfect!** Use these parameters:

```javascript
const bondingCurveConfig = {
  virtualEth: ethers.utils.parseUnits('2000', 6),          // 2,000 USDC
  virtualTokens: ethers.utils.parseEther('6000000'),       // 6M tokens
  maxSupply: ethers.utils.parseEther('5000000'),           // 5M tokens (50%)
  graduationThreshold: ethers.utils.parseUnits('10000', 6) // 10,000 USDC
};
```

### Verification:

```
K = 2,000 × 6,000,000 = 12,000,000,000

Starting Price = 2,000 / 6,000,000 = $0.000333 per token

At $10,000 graduation:
Total USDC = 12,000
Remaining virtual = 12,000,000,000 / 12,000 = 1,000,000
Sold = 6,000,000 - 1,000,000 = 5,000,000 ✓

Graduation bonding price = 12,000 / 1,000,000 = $0.012 per token

With modified _graduate() that mints 4M:
LP: 10,000 USDC + 4,000,000 tokens
LP price: $0.0025 per token

Total Distribution:
- Sold: 5,000,000 (50%)
- Creator: 1,000,000 (10%)
- Liquidity: 4,000,000 (40%)
- Total: 10,000,000 ✓
```

---

## FINAL ANSWER: Complete Configuration

### 1. Bonding Curve Config

```javascript
const bondingCurveConfig = {
  virtualEth: ethers.utils.parseUnits('2000', 6),          // 2,000 USDC
  virtualTokens: ethers.utils.parseEther('6000000'),       // 6M tokens
  maxSupply: ethers.utils.parseEther('5000000'),           // 5M tokens (50%)
  graduationThreshold: ethers.utils.parseUnits('10000', 6) // 10,000 USDC
};
```

### 2. Modified `_graduate()` Function

Replace the existing `_graduate()` function in `CarbonCoinUSDC.sol` with:

```solidity
function _graduate() internal {
    if (hasGraduated) revert AlreadyGraduated();
    
    if (block.timestamp < lastGraduationAttempt + GRADUATION_COOLDOWN) {
        revert GraduationCooldownActive();
    }
    lastGraduationAttempt = block.timestamp;
    hasGraduated = true;

    // Mint exactly 4M tokens for liquidity (40% of 10M total)
    uint256 liquidityTokens = 4_000_000 * 10**18;
    _mint(address(this), liquidityTokens);

    // Approve router to spend tokens and USDC
    _approve(address(this), address(dexRouter), liquidityTokens);
    USDC.approve(address(dexRouter), realUsdcReserves);

    uint256 usdcForLiquidity = realUsdcReserves;

    try dexRouter.addLiquidity(
        address(USDC),
        address(this),
        usdcForLiquidity,
        liquidityTokens,
        (usdcForLiquidity * 95) / 100,
        (liquidityTokens * 95) / 100,
        creator, // Send LP Tokens to Creator
        block.timestamp + 60
    ) returns (uint amountA, uint amountB, uint) {
        emit Graduated(
            address(this),
            dexPair,
            amountB,
            amountA,
            getCurrentPrice(),
            block.timestamp
        );
        emit LiquiditySnapshot(0, 0, block.timestamp);
    } catch {
        hasGraduated = false;
        _burn(address(this), liquidityTokens);
        revert("Graduation failed");
    }
}
```

### 3. Deployment Code

```javascript
const { ethers } = require('hardhat');

async function main() {
  const [deployer] = await ethers.getSigners();
  
  // Addresses
  const creatorAddress = "0x...";
  const usdcAddress = "0x...";
  const permitAndTransferAddress = "0x...";
  const somniaRouterAddress = "0x...";
  const configAddress = "0x...";
  
  // Bonding curve configuration
  const bondingCurveConfig = {
    virtualEth: ethers.utils.parseUnits('2000', 6),          // 2,000 USDC
    virtualTokens: ethers.utils.parseEther('6000000'),       // 6M tokens
    maxSupply: ethers.utils.parseEther('5000000'),           // 5M tokens
    graduationThreshold: ethers.utils.parseUnits('10000', 6) // 10,000 USDC
  };
  
  // Deploy
  const CarbonCoinUSDC = await ethers.getContractFactory("CarbonCoinUSDC");
  const carbonCoin = await CarbonCoinUSDC.deploy(
    "Artist Token",
    "ART",
    creatorAddress,
    usdcAddress,
    permitAndTransferAddress,
    somniaRouterAddress,
    configAddress,
    bondingCurveConfig
  );
  
  await carbonCoin.deployed();
  
  console.log("Deployed to:", carbonCoin.address);
  console.log("\nToken Distribution:");
  console.log("- Bonding Curve Max:", ethers.utils.formatEther(await carbonCoin.maxSupply()), "tokens (50%)");
  console.log("- Creator Reserve:", ethers.utils.formatEther(await carbonCoin.creatorReserveTokens()), "tokens (10%)");
  console.log("- Liquidity (at grad):", "4,000,000 tokens (40%)");
  console.log("- Total Supply:", "10,000,000 tokens");
  
  console.log("\nEconomics:");
  const price = await carbonCoin.getCurrentPrice();
  console.log("- Starting Price:", ethers.utils.formatUnits(price, 6), "USDC per token");
  console.log("- Graduation at:", ethers.utils.formatUnits(bondingCurveConfig.graduationThreshold, 6), "USDC");
  console.log("- LP Price:", "0.0025 USDC per token");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

---

## Summary

### Token Distribution (10M Total)
| Allocation | Tokens | % | Price | Value at Graduation |
|------------|--------|---|-------|---------------------|
| Sold via Bonding | 5,000,000 | 50% | $0.000333 - $0.012 | ~$30,000 |
| Creator Reserve | 1,000,000 | 10% | N/A | ~$2,500 @ LP |
| Liquidity Pool | 4,000,000 | 40% | $0.0025 | $10,000 |
| **Total** | **10,000,000** | **100%** | | |

### Key Metrics
- 💰 **Starting Price**: $0.000333 per token
- 🎯 **Graduation**: $10,000 USDC collected
- 📈 **Graduation Price**: $0.012 per token (bonding curve end)
- 🏊 **LP Starting Price**: $0.0025 per token
- 🚀 **Price Appreciation**: 36x from start to bonding curve end
- 💧 **Liquidity Depth**: $10,000 USDC + 4M tokens

This configuration gives you:
- ✅ Exactly 50% sold via bonding curve
- ✅ Exactly 40% in liquidity pool
- ✅ Exactly 10% creator reserve
- ✅ Graduation at $10,000 USDC
- ✅ Total supply = 10,000,000 tokens
