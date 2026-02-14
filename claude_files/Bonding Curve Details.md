# Bonding Curve Configuration - CORRECTED (10M Total Supply)

## Corrected Supply Structure

- **Total Supply**: 10,000,000 tokens (10M)
- **Bonding Curve Max**: 9,000,000 tokens (90%)
- **Creator Reserve**: 1,000,000 tokens (10% - auto-calculated)
- **Graduation Target**: $10,000 USDC

---

## Original ETH Configuration (Interpreted Correctly)

Your original config was likely:
```javascript
{
  virtualEth: '15000',        // 15,000 SOMI (in full units, not wei)
  virtualTokens: '9506250',   // 9.50625M tokens (in full units, not wei)
  maxSupply: '9000000',       // 9M tokens (you had extra zeros!)
  graduationThreshold: '50000' // 50,000 SOMI (in full units)
}
```

**Economics (ETH version):**
- Virtual liquidity: 15,000 SOMI × $0.20 = $3,000
- Graduation: 50,000 SOMI × $0.20 = $10,000 ✓
- Virtual tokens: 9.50625M
- Max supply: 9M tokens

---

## NEW USDC Configuration

### JavaScript (Recommended - Using ethers.js)

```javascript
const bondingCurveConfig = {
  // 3,000 USDC virtual reserves
  virtualEth: ethers.utils.parseUnits('3000', 6),

  // 9.50625M tokens virtual supply
  virtualTokens: ethers.utils.parseEther('9506250'),

  // 9M tokens max for bonding curve (90% of 10M total)
  maxSupply: ethers.utils.parseEther('9000000'),

  // Graduate at 10,000 USDC
  graduationThreshold: ethers.utils.parseUnits('10000', 6)
};
```

### Raw Values (if not using ethers.js)

```javascript
const bondingCurveConfig = {
  virtualEth: '3000000000',                    // 3,000 USDC (3000 * 10^6)
  virtualTokens: '9506250000000000000000000',  // 9.50625M tokens (9506250 * 10^18)
  maxSupply: '9000000000000000000000000',      // 9M tokens (9000000 * 10^18)
  graduationThreshold: '10000000000'           // 10,000 USDC (10000 * 10^6)
};
```

### Solidity (Foundry/Hardhat Tests)

```solidity
ICarbonCoin.BondingCurveConfig memory config = ICarbonCoin.BondingCurveConfig({
    virtualEth: 3_000 * 10**6,           // 3,000 USDC
    virtualTokens: 9_506_250 * 10**18,   // 9.50625M tokens
    maxSupply: 9_000_000 * 10**18,       // 9M tokens
    graduationThreshold: 10_000 * 10**6  // 10,000 USDC
});
```

---

## Bonding Curve Economics

### Starting Conditions
```
K = virtualUsdc × virtualTokens
K = 3,000 × 9,506,250 = 28,518,750,000

Starting Price = virtualUsdc / virtualTokens
Starting Price = 3,000 / 9,506,250
Starting Price ≈ $0.0003156 per token
```

### At Graduation (10,000 USDC collected)
```
Total USDC = 3,000 (virtual) + 10,000 (real) = 13,000 USDC

Using K = 28,518,750,000:
Remaining Virtual Tokens = K / Total USDC
Remaining Virtual Tokens = 28,518,750,000 / 13,000
Remaining Virtual Tokens ≈ 2,193,750

Tokens Sold = 9,506,250 - 2,193,750 = 7,312,500 tokens

Graduation Price = 13,000 / 2,193,750 ≈ $0.00593 per token
```

### Summary Stats
- **Starting Price**: ~$0.000316 per token
- **Graduation Price**: ~$0.00593 per token
- **Price Appreciation**: ~18.8x from start to graduation
- **Tokens Sold at Graduation**: ~7.31M out of 9M (81%)
- **Tokens Remaining**: ~1.69M (minted and added to DEX)
- **Creator Reserve**: 1M tokens (10% of 10M total)

---

## Token Distribution Breakdown

### At Launch
```
┌─────────────────────────────────────────┐
│ Total Supply: 10,000,000 tokens         │
├─────────────────────────────────────────┤
│ Creator Reserve: 1,000,000 (10%)        │ ← Minted immediately
│ Bonding Curve: 9,000,000 (90%)          │ ← Sold over time
└─────────────────────────────────────────┘
```

### At Graduation (~10,000 USDC collected)
```
┌─────────────────────────────────────────┐
│ Total Supply: 10,000,000 tokens         │
├─────────────────────────────────────────┤
│ Creator Reserve: 1,000,000 (10%)        │ ← Still held by creator
│ Sold via Bonding: ~7,312,500 (73%)     │ ← In user wallets
│ Added to DEX: ~1,687,500 (17%)         │ ← Minted for liquidity
└─────────────────────────────────────────┘
```

### After Graduation (Trading on DEX)
- All 10M tokens exist
- 10,000 USDC + 1.69M tokens in liquidity pool
- Trading happens on Somnia DEX
- Bonding curve is disabled

---

## Deployment Example (Complete)

```javascript
const { ethers } = require('hardhat');

async function main() {
  // Get addresses
  const [deployer] = await ethers.getSigners();
  const creatorAddress = "0x..."; // Artist wallet
  const usdcAddress = "0x...";    // USDC on Somnia
  const permitAndTransferAddress = "0x..."; // Your PermitAndTransfer contract
  const somniaRouterAddress = "0x...";      // Somnia DEX Router
  const configAddress = "0x...";            // CarbonCoinConfig contract

  // Bonding curve configuration
  const bondingCurveConfig = {
    virtualEth: ethers.utils.parseUnits('3000', 6),        // 3,000 USDC
    virtualTokens: ethers.utils.parseEther('9506250'),     // 9.50625M tokens
    maxSupply: ethers.utils.parseEther('9000000'),         // 9M tokens (90%)
    graduationThreshold: ethers.utils.parseUnits('10000', 6) // 10,000 USDC
  };

  // Deploy contract
  const CarbonCoinUSDC = await ethers.getContractFactory("CarbonCoinUSDC");
  const carbonCoin = await CarbonCoinUSDC.deploy(
    "Artist Token",              // name
    "ART",                      // symbol
    creatorAddress,             // creator
    usdcAddress,                // USDC token
    permitAndTransferAddress,   // PermitAndTransfer
    somniaRouterAddress,        // DEX router
    configAddress,              // Config contract
    bondingCurveConfig          // Bonding curve params
  );

  await carbonCoin.deployed();

  console.log("CarbonCoinUSDC deployed to:", carbonCoin.address);
  console.log("Creator:", creatorAddress);
  console.log("Total max supply:", ethers.utils.formatEther(await carbonCoin.getTotalMaxSupply()));
  console.log("Bonding curve max:", ethers.utils.formatEther(await carbonCoin.getBondingCurveMaxSupply()));
  console.log("Creator reserve:", ethers.utils.formatEther(await carbonCoin.creatorReserveTokens()));

  // Verify creator received their reserve
  const creatorBalance = await carbonCoin.balanceOf(creatorAddress);
  console.log("Creator balance:", ethers.utils.formatEther(creatorBalance));

  // Check starting price
  const startingPrice = await carbonCoin.getCurrentPrice();
  console.log("Starting price:", ethers.utils.formatUnits(startingPrice, 6), "USDC per token");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

Expected output:
```
CarbonCoinUSDC deployed to: 0x...
Creator: 0x...
Total max supply: 10000000.0
Bonding curve max: 9000000.0
Creator reserve: 1000000.0
Creator balance: 1000000.0
Starting price: 0.0003156 USDC per token
```

---

## Verification Checklist

Before deploying to mainnet, verify:

- [ ] Total supply = 10M tokens
- [ ] Creator reserve = 1M tokens (10%)
- [ ] Bonding curve max = 9M tokens (90%)
- [ ] Starting price ≈ $0.000316 per token
- [ ] Graduation threshold = 10,000 USDC
- [ ] Virtual USDC = 3,000 USDC (with 6 decimals)
- [ ] Virtual tokens = 9.50625M tokens (with 18 decimals)
- [ ] Creator receives 1M tokens immediately
- [ ] Contract graduates at exactly 10,000 USDC
- [ ] All token amounts use 18 decimals (10^18)
- [ ] All USDC amounts use 6 decimals (10^6)

---

## Comparison: Old vs New

| Metric | Old (ETH) | New (USDC) |
|--------|-----------|------------|
| **Supply** |
| Total | 10M | 10M |
| Bonding Curve | 9M (90%) | 9M (90%) |
| Creator Reserve | 1M (10%) | 1M (10%) |
| **Economics** |
| Virtual Liquidity | 15,000 SOMI ($3,000) | 3,000 USDC |
| Virtual Tokens | 9.50625M | 9.50625M |
| Graduation | 50,000 SOMI ($10,000) | 10,000 USDC |
| Starting Price | ~$0.000316 | ~$0.000316 |
| Graduation Price | ~$0.00593 | ~$0.00593 |
| **Technical** |
| Payment Token | SOMI (18 decimals) | USDC (6 decimals) |
| Gasless Option | No | Yes ✓ |
| Permit Support | No | Yes ✓ |

---

## Price Chart Estimation

Here's how the price would progress as USDC is collected:

| USDC Collected | Total USDC | Tokens Sold | Price per Token | Total Value |
|----------------|------------|-------------|-----------------|-------------|
| $0 | 3,000 | 0 | $0.000316 | $0 |
| $1,000 | 4,000 | ~1.28M | $0.000421 | $541 |
| $2,500 | 5,500 | ~2.61M | $0.000579 | $1,514 |
| $5,000 | 8,000 | ~4.44M | $0.000843 | $3,742 |
| $7,500 | 10,500 | ~6.21M | $0.00110 | $6,847 |
| **$10,000** | **13,000** | **~7.31M** | **$0.00593** | **~$43,000** |

**Note**: The "Total Value" column shows the theoretical market cap if all sold tokens were valued at the current price.

---

## Quick Reference

### When deploying, remember:

```javascript
// ✓ CORRECT - 10M total supply
maxSupply: ethers.utils.parseEther('9000000')  // 9M for bonding curve

// ✗ WRONG - 1B total supply (your old typo)
maxSupply: ethers.utils.parseEther('900000000')  // 900M - too many zeros!
```

### Token counts at a glance:
- 9M = bonding curve max
- 1M = creator reserve (auto-calculated)
- 10M = total supply

All set! 🚀
