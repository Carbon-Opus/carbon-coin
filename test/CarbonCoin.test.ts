import { ethers, deployments } from "hardhat";
import { expect } from "chai";
import { CarbonCoin, CarbonCoinLauncher, CarbonCoinConfig, CarbonCoinProtection, CarbonCoinPaymaster, ERC20Mintable } from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("CarbonCoin", () => {
  let carbonCoin: CarbonCoin;
  let carbonCoinLauncher: CarbonCoinLauncher;
  let carbonCoinConfig: CarbonCoinConfig;
  let carbonCoinProtection: CarbonCoinProtection;
  let carbonCoinPaymaster: CarbonCoinPaymaster;
  let mockUsdc: ERC20Mintable;
  let deployer: SignerWithAddress;
  let trader: SignerWithAddress;

  beforeEach(async () => {
    await deployments.fixture(["Carbon"]);
    const signers = await ethers.getSigners();
    deployer = signers[0];
    trader = signers[2];

    carbonCoinConfig = await ethers.getContract<CarbonCoinConfig>("CarbonCoinConfig");
    carbonCoinLauncher = await ethers.getContract<CarbonCoinLauncher>("CarbonCoinLauncher");
    carbonCoinProtection = await ethers.getContract<CarbonCoinProtection>("CarbonCoinProtection");
    carbonCoinPaymaster = await ethers.getContract<CarbonCoinPaymaster>("CarbonCoinPaymaster");
    mockUsdc = await ethers.getContract<ERC20Mintable>("ERC20Mintable");

    const bondingCurveParams = {
      virtualUsdc: ethers.utils.parseUnits("50000", 6),
      virtualTokens: ethers.utils.parseEther("6000000"),
      creatorReserve: ethers.utils.parseEther("1000000"),
      liquiditySupply: ethers.utils.parseEther("4500000"),
      curveSupply: ethers.utils.parseEther("4500000"),
      maxSupply: ethers.utils.parseEther("10000000"),
      graduationThreshold: ethers.utils.parseUnits("150000", 6)
    };

    const createTokenTx = await carbonCoinLauncher.createToken(
      "Test Carbon Coin",
      "TCC",
      deployer.address,
      bondingCurveParams
    );

    const receipt = await createTokenTx.wait();
    let tokenCreatedEvent = receipt.events?.find(e => e.event === 'TokenCreated');
    if (!tokenCreatedEvent && receipt.logs) {
      for (const logItem of receipt.logs) {
        try {
          const parsed = carbonCoinLauncher.interface.parseLog(logItem);
          if (parsed.name === 'TokenCreated') {
            tokenCreatedEvent = parsed as any;
            break;
          }
        } catch (e) {}
      }
    }
    const tokenAddress = tokenCreatedEvent?.args?.tokenAddress;

    carbonCoin = await ethers.getContractAt("CarbonCoin", tokenAddress);

    // Fund trader with USDC and approve carbonCoin
    await mockUsdc.mint(trader.address, ethers.utils.parseUnits("100000", 6));
    await mockUsdc.connect(trader).approve(carbonCoin.address, ethers.constants.MaxUint256);

    // Advance beyond anti-bot 120s launch window
    await ethers.provider.send("evm_increaseTime", [150]);
    await ethers.provider.send("evm_mine", []);
  });

  it("should have the correct name and symbol", async () => {
    expect(await carbonCoin.name()).to.equal("Test Carbon Coin");
    expect(await carbonCoin.symbol()).to.equal("TCC");
  });

  describe("Whale Protection (Intent-to-Trade)", () => {
    const whaleBuyAmount = ethers.utils.parseUnits("1200", 6); // whaleThreshold is 1000 USDC

    it("should revert if whale buy is attempted without registering intent", async () => {
      await expect(
        carbonCoin.connect(trader).buy(whaleBuyAmount, 0)
      ).to.be.revertedWithCustomError(carbonCoin, "WhaleIntentRequired");
    });

    it("should allow registering whale intent and persist it in storage", async () => {
      await expect(
        carbonCoin.connect(trader).registerWhaleIntent(whaleBuyAmount, true)
      ).to.emit(carbonCoinProtection, "WhaleIntentRegistered");

      const intent = await carbonCoinProtection.getWhaleIntent(carbonCoin.address, trader.address);
      expect(intent.amount).to.equal(whaleBuyAmount);
      expect(intent.isBuy).to.be.true;
      expect(intent.intentTime).to.be.gt(0);
      expect(intent.canExecute).to.be.false;
    });

    it("should revert if whale trade is executed before delay expires", async () => {
      await carbonCoin.connect(trader).registerWhaleIntent(whaleBuyAmount, true);

      // Advance by only 60 seconds (delay is 300 seconds)
      await ethers.provider.send("evm_increaseTime", [60]);
      await ethers.provider.send("evm_mine", []);

      await expect(
        carbonCoin.connect(trader).buy(whaleBuyAmount, 0)
      ).to.be.revertedWithCustomError(carbonCoinProtection, "WhaleIntentNotReady");
    });

    it("should execute whale buy successfully after delay has elapsed", async () => {
      await carbonCoin.connect(trader).registerWhaleIntent(whaleBuyAmount, true);

      // Advance past whaleDelay (5 minutes = 300 seconds)
      await ethers.provider.send("evm_increaseTime", [305]);
      await ethers.provider.send("evm_mine", []);

      const intentBefore = await carbonCoinProtection.getWhaleIntent(carbonCoin.address, trader.address);
      expect(intentBefore.canExecute).to.be.true;

      await expect(
        carbonCoin.connect(trader).buy(whaleBuyAmount, 0)
      ).to.emit(carbonCoin, "TokensPurchased")
        .and.to.emit(carbonCoinProtection, "WhaleTradeExecuted");

      // Verify intent was cleaned up
      const intentAfter = await carbonCoinProtection.getWhaleIntent(carbonCoin.address, trader.address);
      expect(intentAfter.intentTime).to.equal(0);
      expect(await carbonCoin.balanceOf(trader.address)).to.be.gt(0);
    });

    it("should allow cancelling a registered whale intent", async () => {
      await carbonCoin.connect(trader).registerWhaleIntent(whaleBuyAmount, true);

      await expect(
        carbonCoin.connect(trader).cancelWhaleIntent()
      ).to.emit(carbonCoinProtection, "WhaleIntentCancelled");

      const intent = await carbonCoinProtection.getWhaleIntent(carbonCoin.address, trader.address);
      expect(intent.intentTime).to.equal(0);
    });

    it("should enforce cooldown between consecutive whale trades", async () => {
      await carbonCoin.connect(trader).registerWhaleIntent(whaleBuyAmount, true);
      await ethers.provider.send("evm_increaseTime", [305]);
      await ethers.provider.send("evm_mine", []);
      await carbonCoin.connect(trader).buy(whaleBuyAmount, 0);

      // Immediate attempt to register another whale intent must revert with WhaleDelayActive
      await expect(
        carbonCoin.connect(trader).registerWhaleIntent(whaleBuyAmount, true)
      ).to.be.revertedWithCustomError(carbonCoinProtection, "WhaleDelayActive");

      // After cooldown expires (300s), should be able to register again
      await ethers.provider.send("evm_increaseTime", [305]);
      await ethers.provider.send("evm_mine", []);

      await expect(
        carbonCoin.connect(trader).registerWhaleIntent(whaleBuyAmount, true)
      ).to.emit(carbonCoinProtection, "WhaleIntentRegistered");
    });

    it("should support whale sell intent and execution", async () => {
      // Set maxSellPercentage to 100% so whale sell amount is permitted under percentage limits
      await carbonCoinConfig.connect(deployer).updateDefaultWhaleLimitConfig({
        whaleThreshold: ethers.utils.parseUnits("1000", 6),
        whaleDelay: 300,
        maxTradeSize: ethers.utils.parseUnits("2500", 6),
        maxSellPercentage: 10000
      });

      // First buy tokens as whale
      await carbonCoin.connect(trader).registerWhaleIntent(whaleBuyAmount, true);
      await ethers.provider.send("evm_increaseTime", [305]);
      await ethers.provider.send("evm_mine", []);
      await carbonCoin.connect(trader).buy(whaleBuyAmount, 0);

      const traderTokens = await carbonCoin.balanceOf(trader.address);
      expect(traderTokens).to.be.gt(0);

      // Wait for trade cooldown
      await ethers.provider.send("evm_increaseTime", [305]);
      await ethers.provider.send("evm_mine", []);

      // Sell without intent should revert WhaleIntentRequired
      await expect(
        carbonCoin.connect(trader).sell(traderTokens, 0)
      ).to.be.revertedWithCustomError(carbonCoin, "WhaleIntentRequired");

      // Register sell intent
      await expect(
        carbonCoin.connect(trader).registerWhaleIntent(traderTokens, false)
      ).to.emit(carbonCoinProtection, "WhaleIntentRegistered");

      // Execute after delay
      await ethers.provider.send("evm_increaseTime", [305]);
      await ethers.provider.send("evm_mine", []);

      const usdcBefore = await mockUsdc.balanceOf(trader.address);
      await expect(
        carbonCoin.connect(trader).sell(traderTokens, 0)
      ).to.emit(carbonCoin, "TokensSold")
        .and.to.emit(carbonCoinProtection, "WhaleTradeExecuted");

      const usdcAfter = await mockUsdc.balanceOf(trader.address);
      expect(usdcAfter).to.be.gt(usdcBefore);
    });
  });

  describe("Circuit Breaker & Price Impact Protection", () => {
    it("should revert on extreme price impact (> 2x maxPriceImpact) without triggering circuit breaker", async () => {
      // 2500 USDC trade has ~10.14% price impact (> 10% extreme threshold)
      const extremeTradeSize = ethers.utils.parseUnits("2500", 6);

      await carbonCoin.connect(trader).registerWhaleIntent(extremeTradeSize, true);
      await ethers.provider.send("evm_increaseTime", [305]);
      await ethers.provider.send("evm_mine", []);

      await expect(
        carbonCoin.connect(trader).buy(extremeTradeSize, 0)
      ).to.be.revertedWithCustomError(carbonCoinProtection, "PriceImpactTooHigh");

      // Confirm circuit breaker was NOT activated because transaction reverted
      const cbStatus = await carbonCoinProtection.getCircuitBreakerStatus(carbonCoin.address);
      expect(cbStatus.isActive).to.be.false;
      expect(cbStatus.triggeredAt).to.equal(0);
    });

    it("should trigger circuit breaker on high price impact (between 1x and 2x maxPriceImpact) and halt subsequent trades", async () => {
      // 1800 USDC trade has ~7.25% price impact (between 5% and 10%)
      const highImpactTradeSize = ethers.utils.parseUnits("1800", 6);

      await carbonCoin.connect(trader).registerWhaleIntent(highImpactTradeSize, true);
      await ethers.provider.send("evm_increaseTime", [305]);
      await ethers.provider.send("evm_mine", []);

      await expect(
        carbonCoin.connect(trader).buy(highImpactTradeSize, 0)
      ).to.emit(carbonCoinProtection, "HighPriceImpact")
        .and.to.emit(carbonCoinProtection, "CircuitBreakerTriggered");

      // Verify circuit breaker IS active in storage
      const cbStatus = await carbonCoinProtection.getCircuitBreakerStatus(carbonCoin.address);
      expect(cbStatus.isActive).to.be.true;
      expect(cbStatus.triggeredAt).to.be.gt(0);
      expect(cbStatus.timeRemaining).to.be.gt(0);

      // Advance past anti-bot cooldown (15 seconds) but well within circuit breaker duration (900 seconds)
      await ethers.provider.send("evm_increaseTime", [20]);
      await ethers.provider.send("evm_mine", []);

      // Subsequent trades should revert while circuit breaker is active
      const smallBuy = ethers.utils.parseUnits("50", 6);
      await expect(
        carbonCoin.connect(trader).buy(smallBuy, 0)
      ).to.be.revertedWithCustomError(carbonCoinProtection, "CircuitBreakerActive");

      // Advance past circuitBreakerDuration (15 minutes = 900 seconds)
      await ethers.provider.send("evm_increaseTime", [905]);
      await ethers.provider.send("evm_mine", []);

      const cbStatusAfter = await carbonCoinProtection.getCircuitBreakerStatus(carbonCoin.address);
      expect(cbStatusAfter.isActive).to.be.false;

      // Now trading should succeed again
      await expect(
        carbonCoin.connect(trader).buy(smallBuy, 0)
      ).to.emit(carbonCoin, "TokensPurchased");
    });

    it("should store lastPrice and lastPriceTimestamp in packed slot and reset on window expiration without DoS", async () => {
      // Initially lastPrice is 0
      let state = await carbonCoinProtection.tokenStates(carbonCoin.address);
      expect(state.lastPrice).to.equal(0);
      expect(state.lastPriceTimestamp).to.equal(0);
      expect(state.volatilityMoveCount).to.equal(0);

      // Perform a small trade (50 USDC) to establish lastPrice
      const buyAmount = ethers.utils.parseUnits("50", 6);
      await carbonCoin.connect(trader).buy(buyAmount, 0);

      state = await carbonCoinProtection.tokenStates(carbonCoin.address);
      expect(state.lastPrice).to.be.gt(0);
      expect(state.lastPriceTimestamp).to.be.gt(0);
      expect(state.volatilityMoveCount).to.equal(0);

      // Advance past anti-bot cooldown (15s) and past volatilityWindow (300s = 5 min)
      await ethers.provider.send("evm_increaseTime", [310]);
      await ethers.provider.send("evm_mine", []);

      // Trade after window expiration should reset volatility state cleanly in O(1) gas
      await carbonCoin.connect(trader).buy(buyAmount, 0);

      const stateAfter = await carbonCoinProtection.tokenStates(carbonCoin.address);
      expect(stateAfter.lastPrice).to.be.gt(0);
      expect(stateAfter.lastPriceTimestamp).to.be.gt(state.lastPriceTimestamp);
      expect(stateAfter.volatilityMoveCount).to.equal(0);
    });

    it("should track consecutive volatile price moves and trigger circuit breaker on excessive volatility", async () => {
      // Configure higher whale threshold and max trade size so test trades are not treated as whales
      await carbonCoinConfig.connect(deployer).updateDefaultWhaleLimitConfig({
        whaleThreshold: ethers.utils.parseUnits("50000", 6),
        whaleDelay: 300,
        maxTradeSize: ethers.utils.parseUnits("50000", 6),
        maxSellPercentage: 1000
      });

      // Configure circuit breaker: maxPriceImpact = 20% (so single 7% trades do not trigger price impact CB),
      // maxVolatilityMoves = 2 moves
      await carbonCoinConfig.connect(deployer).updateDefaultCircuitBreakerConfig({
        maxPriceImpact: 2000,
        volatilityWindow: 300,
        maxVolatilityMoves: 2,
        circuitBreakerDuration: 900
      });

      // Trade 1: establishes baseline lastPrice
      const tradeSize = ethers.utils.parseUnits("1800", 6);
      await carbonCoin.connect(trader).buy(tradeSize, 0);

      let state = await carbonCoinProtection.tokenStates(carbonCoin.address);
      expect(state.volatilityMoveCount).to.equal(0);

      // Advance past anti-bot cooldown (15s)
      await ethers.provider.send("evm_increaseTime", [20]);
      await ethers.provider.send("evm_mine", []);

      // Trade 2: 1800 USDC buy produces ~7% price increase (> 5% threshold) -> moveCount = 1
      await carbonCoin.connect(trader).buy(tradeSize, 0);

      state = await carbonCoinProtection.tokenStates(carbonCoin.address);
      expect(state.volatilityMoveCount).to.equal(1);

      // Advance past anti-bot cooldown (15s)
      await ethers.provider.send("evm_increaseTime", [20]);
      await ethers.provider.send("evm_mine", []);

      // Trade 3: another ~7% increase -> moveCount = 2 (reaches maxVolatilityMoves = 2)
      // Should emit VolatilityWarning and CircuitBreakerTriggered
      await expect(
        carbonCoin.connect(trader).buy(tradeSize, 0)
      ).to.emit(carbonCoinProtection, "VolatilityWarning")
        .and.to.emit(carbonCoinProtection, "CircuitBreakerTriggered");

      const cbStatus = await carbonCoinProtection.getCircuitBreakerStatus(carbonCoin.address);
      expect(cbStatus.isActive).to.be.true;
      expect(cbStatus.volatilityMoves).to.equal(2);

      // Advance past anti-bot cooldown
      await ethers.provider.send("evm_increaseTime", [20]);
      await ethers.provider.send("evm_mine", []);

      // Subsequent trade reverts due to CircuitBreakerActive
      const smallBuy = ethers.utils.parseUnits("10", 6);
      await expect(
        carbonCoin.connect(trader).buy(smallBuy, 0)
      ).to.be.revertedWithCustomError(carbonCoinProtection, "CircuitBreakerActive");

      // Owner resets circuit breaker
      await expect(
        carbonCoinProtection.connect(deployer).resetCircuitBreaker(carbonCoin.address)
      ).to.emit(carbonCoinProtection, "CircuitBreakerReset");

      state = await carbonCoinProtection.tokenStates(carbonCoin.address);
      expect(state.circuitBreakerTriggeredAt).to.equal(0);
      expect(state.volatilityMoveCount).to.equal(0);
      expect(state.lastPrice).to.equal(0);
      expect(state.lastPriceTimestamp).to.equal(0);

      // Trading resumes successfully
      await expect(
        carbonCoin.connect(trader).buy(smallBuy, 0)
      ).to.emit(carbonCoin, "TokensPurchased");
    });
  });

  describe("Creator Pre-Graduation Lock", () => {
    it("should prevent creator from selling reserve tokens before graduation", async () => {
      const creatorBalance = await carbonCoin.balanceOf(deployer.address);
      expect(creatorBalance).to.be.gt(0);

      // Creator attempts to sell tokens before graduation
      await expect(
        carbonCoin.connect(deployer).sell(ethers.utils.parseEther("100"), 0)
      ).to.be.revertedWithCustomError(carbonCoin, "CreatorCannotSellBeforeGraduation");
    });

    it("should prevent creator from transferring tokens before graduation via transfer", async () => {
      await expect(
        carbonCoin.connect(deployer).transfer(trader.address, ethers.utils.parseEther("100"))
      ).to.be.revertedWithCustomError(carbonCoin, "CreatorCannotSellBeforeGraduation");
    });

    it("should prevent creator from transferring tokens before graduation via transferFrom", async () => {
      await carbonCoin.connect(deployer).approve(trader.address, ethers.utils.parseEther("100"));

      await expect(
        carbonCoin.connect(trader).transferFrom(deployer.address, trader.address, ethers.utils.parseEther("100"))
      ).to.be.revertedWithCustomError(carbonCoin, "CreatorCannotSellBeforeGraduation");
    });

    it("should allow non-creator users to transfer and sell tokens freely", async () => {
      const buyAmount = ethers.utils.parseUnits("50", 6);
      await carbonCoin.connect(trader).buy(buyAmount, 0);

      const traderBalance = await carbonCoin.balanceOf(trader.address);
      expect(traderBalance).to.be.gt(0);

      // Non-creator transfer should succeed
      const transferAmount = ethers.utils.parseEther("10");
      const signers = await ethers.getSigners();
      const user3 = signers[3];

      await expect(
        carbonCoin.connect(trader).transfer(user3.address, transferAmount)
      ).to.changeTokenBalances(carbonCoin, [trader, user3], [transferAmount.mul(-1), transferAmount]);

      // Non-creator sell should succeed
      await expect(
        carbonCoin.connect(user3).sell(transferAmount, 0)
      ).to.emit(carbonCoin, "TokensSold");
    });
  });

  describe("CarbonCoinPaymaster Integration", () => {
    it("should reject sellOnBehalf from unauthorized non-controller caller", async () => {
      await expect(
        carbonCoinPaymaster.connect(trader).sellOnBehalf(
          trader.address,
          carbonCoin.address,
          ethers.utils.parseEther("100"),
          0
        )
      ).to.be.revertedWithCustomError(carbonCoinPaymaster, "Unauthorized");
    });

    it("should reject sellOnBehalf for creator before graduation", async () => {
      await expect(
        carbonCoinPaymaster.connect(deployer).sellOnBehalf(
          deployer.address,
          carbonCoin.address,
          ethers.utils.parseEther("100"),
          0
        )
      ).to.be.revertedWithCustomError(carbonCoin, "CreatorCannotSellBeforeGraduation");
    });

    it("should correctly execute sellOnBehalf, burning user tokens and paying user USDC", async () => {
      // First, trader buys tokens
      const buyAmount = ethers.utils.parseUnits("100", 6);
      await carbonCoin.connect(trader).buy(buyAmount, 0);

      const traderTokens = await carbonCoin.balanceOf(trader.address);
      expect(traderTokens).to.be.gt(0);

      // Sell within maxSellPercentage limits
      const limits = await carbonCoin.getTradeLimits();
      const tokensToSell = limits.currentMaxSellTokens;
      expect(tokensToSell).to.be.gt(0);

      const usdcBefore = await mockUsdc.balanceOf(trader.address);

      // Controller executes sellOnBehalf for trader
      await expect(
        carbonCoinPaymaster.connect(deployer).sellOnBehalf(
          trader.address,
          carbonCoin.address,
          tokensToSell,
          0
        )
      ).to.emit(carbonCoinPaymaster, "TokenSell")
        .withArgs(carbonCoin.address, trader.address, tokensToSell, 0)
        .and.to.emit(carbonCoin, "TokensSold");

      // Verify trader tokens were burned
      expect(await carbonCoin.balanceOf(trader.address)).to.equal(traderTokens.sub(tokensToSell));

      // Verify trader received USDC
      const usdcAfter = await mockUsdc.balanceOf(trader.address);
      expect(usdcAfter).to.be.gt(usdcBefore);
    });
  });

  describe("Sell Limits Enforcement (Issue #7)", () => {
    it("should revert with ExceedsMaxSellAmount if sell exceeds maxSellPercentage", async () => {
      const buyAmount = ethers.utils.parseUnits("100", 6);
      await carbonCoin.connect(trader).buy(buyAmount, 0);

      const traderBalance = await carbonCoin.balanceOf(trader.address);
      const limits = await carbonCoin.getTradeLimits();
      expect(traderBalance).to.be.gt(limits.currentMaxSellTokens);

      await expect(
        carbonCoin.connect(trader).sell(traderBalance, 0)
      ).to.be.revertedWithCustomError(carbonCoin, "ExceedsMaxSellAmount");
    });

    it("should allow sell when tokensIn <= currentMaxSellTokens", async () => {
      const buyAmount = ethers.utils.parseUnits("100", 6);
      await carbonCoin.connect(trader).buy(buyAmount, 0);

      const limits = await carbonCoin.getTradeLimits();
      const allowedSell = limits.currentMaxSellTokens;

      await expect(
        carbonCoin.connect(trader).sell(allowedSell, 0)
      ).to.emit(carbonCoin, "TokensSold");
    });

    it("should allow whitelisted user to sell beyond maxSellPercentage", async () => {
      const buyAmount = ethers.utils.parseUnits("100", 6);
      await carbonCoin.connect(trader).buy(buyAmount, 0);

      const traderBalance = await carbonCoin.balanceOf(trader.address);

      // Whitelist trader
      await carbonCoinProtection.connect(deployer).addToWhitelist(carbonCoin.address, trader.address);

      // Trader can now sell full balance exceeding maxSellPercentage
      await expect(
        carbonCoin.connect(trader).sell(traderBalance, 0)
      ).to.emit(carbonCoin, "TokensSold");
    });

    it("should revert with 'Trade size too large' when sell trade size exceeds maxTradeSize", async () => {
      // Set maxSellPercentage to 100% so percentage limit is not the barrier
      await carbonCoinConfig.connect(deployer).updateDefaultWhaleLimitConfig({
        whaleThreshold: ethers.utils.parseUnits("1000", 6),
        whaleDelay: 300,
        maxTradeSize: ethers.utils.parseUnits("2500", 6),
        maxSellPercentage: 10000
      });

      // Whitelist trader for buy to accumulate enough tokens without buy trade size limit
      await carbonCoinProtection.connect(deployer).addToWhitelist(carbonCoin.address, trader.address);
      await mockUsdc.connect(trader).approve(carbonCoin.address, ethers.utils.parseUnits("3500", 6));
      await carbonCoin.connect(trader).buy(ethers.utils.parseUnits("3500", 6), 0);

      // Remove from whitelist so sell limits apply
      await carbonCoinProtection.connect(deployer).removeFromWhitelist(carbonCoin.address, trader.address);

      const traderTokens = await carbonCoin.balanceOf(trader.address);
      const [usdcOut, feeAmount] = await carbonCoin.calculateUsdcOutWithFee(traderTokens);
      expect(usdcOut.add(feeAmount)).to.be.gt(ethers.utils.parseUnits("2500", 6));

      await expect(
        carbonCoin.connect(trader).sell(traderTokens, 0)
      ).to.be.revertedWith("Trade size too large");
    });

    it("should enforce maxSellPercentage in sellOnBehalf", async () => {
      const buyAmount = ethers.utils.parseUnits("100", 6);
      await carbonCoin.connect(trader).buy(buyAmount, 0);

      const traderBalance = await carbonCoin.balanceOf(trader.address);

      await expect(
        carbonCoinPaymaster.connect(deployer).sellOnBehalf(
          trader.address,
          carbonCoin.address,
          traderBalance,
          0
        )
      ).to.be.revertedWithCustomError(carbonCoin, "ExceedsMaxSellAmount");
    });
  });

  describe("Controller Key Rotation in CarbonCoinProtection", () => {
    it("should allow owner to update controller and prevent unauthorized rotation", async () => {
      // Controller initialized to deployer
      expect(await carbonCoinProtection.controller()).to.equal(deployer.address);

      // Owner updates controller
      const signers = await ethers.getSigners();
      const newController = signers[3];

      await expect(
        carbonCoinProtection.connect(deployer).updateController(newController.address)
      ).to.emit(carbonCoinProtection, "ControllerUpdated")
        .withArgs(newController.address);

      expect(await carbonCoinProtection.controller()).to.equal(newController.address);

      // Non-owner cannot update controller
      await expect(
        carbonCoinProtection.connect(trader).updateController(trader.address)
      ).to.be.revertedWithCustomError(carbonCoinProtection, "OwnableUnauthorizedAccount");

      // Cannot set zero address
      await expect(
        carbonCoinProtection.connect(deployer).updateController(ethers.constants.AddressZero)
      ).to.be.revertedWith("Invalid controller");
    });
  });

  describe("Bonding Curve Rounding Invariant Protection", () => {
    it("should round in favor of curve reserves and prevent attrition", async () => {
      // Configure maxSellPercentage so trader can sell back tokens in roundtrip test
      await carbonCoinConfig.connect(deployer).updateDefaultWhaleLimitConfig({
        whaleThreshold: ethers.utils.parseUnits("1000", 6),
        whaleDelay: 300,
        maxTradeSize: ethers.utils.parseUnits("2500", 6),
        maxSellPercentage: 10000
      });

      const initialReserves = await carbonCoin.getReserves();
      const buyAmount = ethers.utils.parseUnits("50", 6);

      // Trader buys tokens
      await carbonCoin.connect(trader).buy(buyAmount, 0);
      const tokensReceived = await carbonCoin.balanceOf(trader.address);
      expect(tokensReceived).to.be.gt(0);

      // Advance anti-bot cooldown
      await ethers.provider.send("evm_increaseTime", [20]);
      await ethers.provider.send("evm_mine", []);

      // Trader sells all tokens received
      const [usdcOut, feeAmount] = await carbonCoin.calculateUsdcOutWithFee(tokensReceived);
      await carbonCoin.connect(trader).sell(tokensReceived, 0);

      const finalReserves = await carbonCoin.getReserves();
      // Total USDC out must be strictly less than buyAmount (fees + ceilDiv rounding favor the curve)
      expect(usdcOut.add(feeAmount)).to.be.lte(buyAmount);

      // Reserves can never be lower than initial reserves after a complete buy/sell roundtrip
      expect(finalReserves.usdcReserves).to.be.gte(initialReserves.usdcReserves);
    });
  });
});
