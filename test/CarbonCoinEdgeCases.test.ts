import { ethers, deployments } from "hardhat";
import { expect } from "chai";
import {
  CarbonCoin,
  CarbonCoinLauncher,
  CarbonCoinConfig,
  CarbonCoinProtection,
  CarbonCoinPaymaster,
  CarbonCoinDex,
  MockNonfungiblePositionManager,
  ERC20Mintable
} from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("CarbonCoin - Comprehensive Edge Cases & Invariant Hardening", () => {
  let carbonCoin: CarbonCoin;
  let carbonCoinLauncher: CarbonCoinLauncher;
  let carbonCoinConfig: CarbonCoinConfig;
  let carbonCoinProtection: CarbonCoinProtection;
  let carbonCoinPaymaster: CarbonCoinPaymaster;
  let mockUsdc: ERC20Mintable;

  let deployer: SignerWithAddress;
  let creator: SignerWithAddress;
  let trader1: SignerWithAddress;
  let trader2: SignerWithAddress;
  let attacker: SignerWithAddress;

  const bondingCurveParams = {
    virtualUsdc: ethers.utils.parseUnits("50000", 6),
    virtualTokens: ethers.utils.parseEther("6000000"),
    creatorReserve: ethers.utils.parseEther("1000000"),
    liquiditySupply: ethers.utils.parseEther("4500000"),
    curveSupply: ethers.utils.parseEther("4500000"),
    maxSupply: ethers.utils.parseEther("10000000"),
    graduationThreshold: ethers.utils.parseUnits("150000", 6)
  };

  async function deployFreshToken(customParams?: Partial<typeof bondingCurveParams>, customCreator?: SignerWithAddress) {
    const params = { ...bondingCurveParams, ...customParams };
    const tokenCreator = customCreator || creator;

    const createTokenTx = await carbonCoinLauncher.createToken(
      "EdgeCase Coin",
      "ECC",
      tokenCreator.address,
      params
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
    const token = await ethers.getContractAt("CarbonCoin", tokenAddress);

    // Whitelist launcher and creator in protection
    await mockUsdc.connect(trader1).approve(token.address, ethers.constants.MaxUint256);
    await mockUsdc.connect(trader2).approve(token.address, ethers.constants.MaxUint256);
    await mockUsdc.connect(attacker).approve(token.address, ethers.constants.MaxUint256);

    return token;
  }

  beforeEach(async () => {
    await deployments.fixture(["Everything"]);
    const signers = await ethers.getSigners();
    deployer = signers[0];
    creator = signers[1];
    trader1 = signers[2];
    trader2 = signers[3];
    attacker = signers[4];

    carbonCoinConfig = await ethers.getContract<CarbonCoinConfig>("CarbonCoinConfig");
    carbonCoinLauncher = await ethers.getContract<CarbonCoinLauncher>("CarbonCoinLauncher");
    carbonCoinProtection = await ethers.getContract<CarbonCoinProtection>("CarbonCoinProtection");
    carbonCoinPaymaster = await ethers.getContract<CarbonCoinPaymaster>("CarbonCoinPaymaster");
    mockUsdc = await ethers.getContract<ERC20Mintable>("ERC20Mintable");

    // Mint USDC to participants
    await mockUsdc.mint(trader1.address, ethers.utils.parseUnits("500000", 6));
    await mockUsdc.mint(trader2.address, ethers.utils.parseUnits("500000", 6));
    await mockUsdc.mint(attacker.address, ethers.utils.parseUnits("500000", 6));

    // Deploy standard carbonCoin for test suite
    carbonCoin = await deployFreshToken();

    // Advance beyond initial 120s anti-bot window for standard tests
    await ethers.provider.send("evm_increaseTime", [150]);
    await ethers.provider.send("evm_mine", []);
  });

  describe("1. Zero & Boundary Arithmetic Invariants", () => {
    it("should revert if buy amount is 0", async () => {
      await expect(
        carbonCoin.connect(trader1).buy(0, 0)
      ).to.be.revertedWithCustomError(carbonCoin, "InvalidAmount");
    });

    it("should revert if sell tokensIn is 0", async () => {
      await expect(
        carbonCoin.connect(trader1).sell(0, 0)
      ).to.be.revertedWithCustomError(carbonCoin, "InvalidAmount");
    });

    it("should revert if selling more tokens than balance", async () => {
      const balance = await carbonCoin.balanceOf(trader1.address);
      expect(balance).to.equal(0);

      await expect(
        carbonCoin.connect(trader1).sell(ethers.utils.parseEther("1"), 0)
      ).to.be.revertedWithCustomError(carbonCoin, "InvalidAmount");
    });

    it("should return zero for calculate view functions with zero inputs", async () => {
      expect(await carbonCoin.calculateTokensOut(0)).to.equal(0);
      expect(await carbonCoin.calculateUsdcIn(0)).to.equal(0);
      expect(await carbonCoin.calculateUsdcOut(0)).to.equal(0);

      const [usdcOut, fee] = await carbonCoin.calculateUsdcOutWithFee(0);
      expect(usdcOut).to.equal(0);
      expect(fee).to.equal(0);
    });

    it("should return (0, 0) for calculateUsdcOutWithFee when tokensIn exceeds realTokenSupply", async () => {
      const [usdcOut, fee] = await carbonCoin.calculateUsdcOutWithFee(ethers.utils.parseEther("999999999"));
      expect(usdcOut).to.equal(0);
      expect(fee).to.equal(0);
    });
  });

  describe("2. Slippage Protection", () => {
    it("should revert buy if tokensOut is less than minTokensOut", async () => {
      const buyAmount = ethers.utils.parseUnits("50", 6);
      const actualTokensOut = await carbonCoin.calculateTokensOut(buyAmount);

      // Require 1 wei more tokens than actual output
      const unreasonableMinTokens = actualTokensOut.add(1);

      await expect(
        carbonCoin.connect(trader1).buy(buyAmount, unreasonableMinTokens)
      ).to.be.revertedWithCustomError(carbonCoin, "SlippageTooHigh");
    });

    it("should revert sell if usdcOut is less than minUsdcOut", async () => {
      // First buy tokens
      const buyAmount = ethers.utils.parseUnits("50", 6);
      await carbonCoin.connect(trader1).buy(buyAmount, 0);

      await ethers.provider.send("evm_increaseTime", [20]);
      await ethers.provider.send("evm_mine", []);

      const limits = await carbonCoin.getTradeLimits();
      const tokensToSell = limits.currentMaxSellTokens;
      const actualUsdcOut = await carbonCoin.calculateUsdcOut(tokensToSell);

      // Require 1 wei more USDC than actual output
      const unreasonableMinUsdc = actualUsdcOut.add(1);

      await expect(
        carbonCoin.connect(trader1).sell(tokensToSell, unreasonableMinUsdc)
      ).to.be.revertedWithCustomError(carbonCoin, "SlippageTooHigh");
    });
  });

  describe("3. Supply Cap Enforcement", () => {
    it("should revert buy if tokensOut would exceed curve supply", async () => {
      // Create a token with a very low curve supply
      const tinyCurveSupply = ethers.utils.parseEther("100");
      const lowSupplyCoin = await deployFreshToken({
        curveSupply: tinyCurveSupply,
        maxSupply: ethers.utils.parseEther("200")
      });

      // Advance past anti-bot
      await ethers.provider.send("evm_increaseTime", [150]);
      await ethers.provider.send("evm_mine", []);

      // Large buy that would mint more than 100 tokens
      const largeBuy = ethers.utils.parseUnits("500", 6);
      await expect(
        lowSupplyCoin.connect(trader1).buy(largeBuy, 0)
      ).to.be.revertedWithCustomError(lowSupplyCoin, "ExceedsMaxSupply");
    });
  });

  describe("4. Anti-Bot Early Launch Window Protections", () => {
    let freshToken: CarbonCoin;

    beforeEach(async () => {
      // Deploy a fresh token without advancing time (in early launch window)
      freshToken = await deployFreshToken();
    });

    it("should revert if buy amount is below minBuyAmount (< 1 USDC)", async () => {
      const dustBuy = ethers.utils.parseUnits("0.5", 6); // 0.5 USDC < 1 USDC minBuyAmount

      await expect(
        freshToken.connect(trader1).buy(dustBuy, 0)
      ).to.be.revertedWithCustomError(freshToken, "InvalidAmount");
    });

    it("should revert if buy amount exceeds maxBuyAmountEarly in first 2 minutes", async () => {
      // default maxBuyAmountEarly is 500 USDC
      const excessiveBuy = ethers.utils.parseUnits("501", 6);

      await expect(
        freshToken.connect(trader1).buy(excessiveBuy, 0)
      ).to.be.revertedWith("Buy amount too high");
    });

    it("should revert if trader buys twice within anti-bot cooldown period (15s)", async () => {
      const validEarlyBuy = ethers.utils.parseUnits("10", 6);

      // First buy succeeds
      await freshToken.connect(trader1).buy(validEarlyBuy, 0);

      // Immediate second buy reverts with cooldown
      await expect(
        freshToken.connect(trader1).buy(validEarlyBuy, 0)
      ).to.be.revertedWith("Cooldown active");

      // Advance 16 seconds (past cooldown)
      await ethers.provider.send("evm_increaseTime", [16]);
      await ethers.provider.send("evm_mine", []);

      // Next buy succeeds
      await expect(
        freshToken.connect(trader1).buy(validEarlyBuy, 0)
      ).to.emit(freshToken, "TokensPurchased");
    });
  });

  describe("5. Whale Intent Lifecycle Edge Cases", () => {
    const whaleAmount = ethers.utils.parseUnits("1200", 6); // > 1000 USDC whaleThreshold

    it("should revert if cancelling when no whale intent exists", async () => {
      await expect(
        carbonCoin.connect(trader1).cancelWhaleIntent()
      ).to.be.revertedWithCustomError(carbonCoinProtection, "NoWhaleIntentFound");
    });

    it("should revert registering whale intent below whaleThreshold", async () => {
      const subWhaleAmount = ethers.utils.parseUnits("999", 6);

      await expect(
        carbonCoin.connect(trader1).registerWhaleIntent(subWhaleAmount, true)
      ).to.be.revertedWith("Amount below whale threshold");
    });

    it("should revert registering a duplicate whale intent when one is already pending", async () => {
      await carbonCoin.connect(trader1).registerWhaleIntent(whaleAmount, true);

      await expect(
        carbonCoin.connect(trader1).registerWhaleIntent(whaleAmount, true)
      ).to.be.revertedWithCustomError(carbonCoinProtection, "WhaleIntentAlreadyExists");
    });

    it("should successfully cancel a pending whale intent and allow registering a new one", async () => {
      await carbonCoin.connect(trader1).registerWhaleIntent(whaleAmount, true);

      await expect(
        carbonCoin.connect(trader1).cancelWhaleIntent()
      ).to.emit(carbonCoinProtection, "WhaleIntentCancelled")
        .withArgs(carbonCoin.address, trader1.address, (val: any) => val > 0);

      const intent = await carbonCoinProtection.getWhaleIntent(carbonCoin.address, trader1.address);
      expect(intent.intentTime).to.equal(0);

      // Now registering a new intent succeeds
      await expect(
        carbonCoin.connect(trader1).registerWhaleIntent(whaleAmount, true)
      ).to.emit(carbonCoinProtection, "WhaleIntentRegistered");
    });

    it("should enforce whaleDelay cooldown between consecutive executed whale trades", async () => {
      await carbonCoin.connect(trader1).registerWhaleIntent(whaleAmount, true);
      await ethers.provider.send("evm_increaseTime", [305]);
      await ethers.provider.send("evm_mine", []);

      // Execute first whale trade
      await carbonCoin.connect(trader1).buy(whaleAmount, 0);

      // Immediately attempting to register another intent reverts WhaleDelayActive
      await expect(
        carbonCoin.connect(trader1).registerWhaleIntent(whaleAmount, true)
      ).to.be.revertedWithCustomError(carbonCoinProtection, "WhaleDelayActive");

      // Advance past whaleDelay (300 seconds)
      await ethers.provider.send("evm_increaseTime", [305]);
      await ethers.provider.send("evm_mine", []);

      // Now registration succeeds
      await expect(
        carbonCoin.connect(trader1).registerWhaleIntent(whaleAmount, true)
      ).to.emit(carbonCoinProtection, "WhaleIntentRegistered");
    });
  });

  describe("6. Creator Pre-Graduation Lockout & Post-Graduation Freedom", () => {
    it("should strictly prevent creator from transferring tokens via transfer pre-graduation", async () => {
      await expect(
        carbonCoin.connect(creator).transfer(trader1.address, ethers.utils.parseEther("100"))
      ).to.be.revertedWithCustomError(carbonCoin, "CreatorCannotSellBeforeGraduation");
    });

    it("should strictly prevent creator from transferring tokens via transferFrom pre-graduation", async () => {
      await carbonCoin.connect(creator).approve(trader1.address, ethers.utils.parseEther("100"));

      await expect(
        carbonCoin.connect(trader1).transferFrom(creator.address, trader1.address, ethers.utils.parseEther("100"))
      ).to.be.revertedWithCustomError(carbonCoin, "CreatorCannotSellBeforeGraduation");
    });

    it("should strictly prevent creator from calling sell pre-graduation", async () => {
      await expect(
        carbonCoin.connect(creator).sell(ethers.utils.parseEther("100"), 0)
      ).to.be.revertedWithCustomError(carbonCoin, "CreatorCannotSellBeforeGraduation");
    });

    it("should allow creator to transfer tokens freely AFTER graduation", async () => {
      // Deploy token with 100 USDC graduation threshold and mock router
      const MockNPMFactory = await ethers.getContractFactory("MockNonfungiblePositionManager");
      const mockPositionManager = await MockNPMFactory.deploy();

      const DexFactory = await ethers.getContractFactory("CarbonCoinDex");
      const dex = await DexFactory.deploy(
        mockUsdc.address,
        mockPositionManager.address,
        carbonCoinConfig.address,
        -887220,
        887220
      );

      await carbonCoinConfig.connect(deployer).updateDexAddress(dex.address);
      await carbonCoinConfig.connect(deployer).updateTreasury(deployer.address);

      const MockLauncherFactory = await ethers.getContractFactory("MockLauncher");
      const mockLauncher = await MockLauncherFactory.deploy();

      const gradThreshold = ethers.utils.parseUnits("100", 6);
      const tx = await mockLauncher.createToken(
        "Graduated Coin",
        "GC",
        creator.address,
        mockUsdc.address,
        deployer.address,
        carbonCoinConfig.address,
        carbonCoinProtection.address,
        {
          virtualUsdc: ethers.utils.parseUnits("50000", 6),
          virtualTokens: ethers.utils.parseEther("6000000"),
          creatorReserve: ethers.utils.parseEther("1000000"),
          liquiditySupply: ethers.utils.parseEther("4500000"),
          curveSupply: ethers.utils.parseEther("4500000"),
          maxSupply: ethers.utils.parseEther("10000000"),
          graduationThreshold: gradThreshold
        }
      );
      const receipt = await tx.wait();
      const coinAddress = receipt.logs[receipt.logs.length - 1].address;
      const gradCoin = (await ethers.getContractFactory("CarbonCoin")).attach(coinAddress);

      // Buy to trigger graduation
      const buyAmount = ethers.utils.parseUnits("110", 6);
      await mockUsdc.connect(trader1).approve(gradCoin.address, buyAmount);
      await gradCoin.connect(trader1).buy(buyAmount, 0);

      expect(await gradCoin.hasGraduated()).to.be.true;

      // Creator CAN now transfer tokens after graduation!
      const transferAmount = ethers.utils.parseEther("500");
      await expect(
        gradCoin.connect(creator).transfer(trader2.address, transferAmount)
      ).to.changeTokenBalances(gradCoin, [creator, trader2], [transferAmount.mul(-1), transferAmount]);
    });
  });

  describe("7. Post-Graduation Bonding Curve Lockdown", () => {
    let graduatedCoin: CarbonCoin;

    beforeEach(async () => {
      const MockNPMFactory = await ethers.getContractFactory("MockNonfungiblePositionManager");
      const mockPositionManager = await MockNPMFactory.deploy();

      const DexFactory = await ethers.getContractFactory("CarbonCoinDex");
      const dex = await DexFactory.deploy(
        mockUsdc.address,
        mockPositionManager.address,
        carbonCoinConfig.address,
        -887220,
        887220
      );

      await carbonCoinConfig.connect(deployer).updateDexAddress(dex.address);
      await carbonCoinConfig.connect(deployer).updateTreasury(deployer.address);

      const MockLauncherFactory = await ethers.getContractFactory("MockLauncher");
      const mockLauncher = await MockLauncherFactory.deploy();

      const gradThreshold = ethers.utils.parseUnits("100", 6);
      const tx = await mockLauncher.createToken(
        "Grad Coin",
        "GC",
        creator.address,
        mockUsdc.address,
        deployer.address,
        carbonCoinConfig.address,
        carbonCoinProtection.address,
        {
          virtualUsdc: ethers.utils.parseUnits("50000", 6),
          virtualTokens: ethers.utils.parseEther("6000000"),
          creatorReserve: ethers.utils.parseEther("1000000"),
          liquiditySupply: ethers.utils.parseEther("4500000"),
          curveSupply: ethers.utils.parseEther("4500000"),
          maxSupply: ethers.utils.parseEther("10000000"),
          graduationThreshold: gradThreshold
        }
      );
      const receipt = await tx.wait();
      const coinAddress = receipt.logs[receipt.logs.length - 1].address;
      graduatedCoin = (await ethers.getContractFactory("CarbonCoin")).attach(coinAddress);

      // Buy to trigger graduation
      const buyAmount = ethers.utils.parseUnits("110", 6);
      await mockUsdc.connect(trader1).approve(graduatedCoin.address, buyAmount);
      await graduatedCoin.connect(trader1).buy(buyAmount, 0);
      expect(await graduatedCoin.hasGraduated()).to.be.true;
    });

    it("should revert buy after graduation", async () => {
      await expect(
        graduatedCoin.connect(trader1).buy(ethers.utils.parseUnits("10", 6), 0)
      ).to.be.revertedWithCustomError(graduatedCoin, "AlreadyGraduated");
    });

    it("should revert sell after graduation", async () => {
      await expect(
        graduatedCoin.connect(trader1).sell(ethers.utils.parseEther("10"), 0)
      ).to.be.revertedWithCustomError(graduatedCoin, "AlreadyGraduated");
    });

    it("should revert buyOnBehalf after graduation", async () => {
      await expect(
        graduatedCoin.connect(deployer).buyOnBehalf(trader1.address, ethers.utils.parseUnits("10", 6), 0)
      ).to.be.revertedWithCustomError(graduatedCoin, "AlreadyGraduated");
    });

    it("should revert sellOnBehalf after graduation", async () => {
      await expect(
        graduatedCoin.connect(deployer).sellOnBehalf(trader1.address, ethers.utils.parseEther("10"), 0)
      ).to.be.revertedWithCustomError(graduatedCoin, "AlreadyGraduated");
    });

    it("should revert registerWhaleIntent after graduation", async () => {
      await expect(
        graduatedCoin.connect(trader1).registerWhaleIntent(ethers.utils.parseUnits("1000", 6), true)
      ).to.be.revertedWithCustomError(graduatedCoin, "AlreadyGraduated");
    });

    it("should revert pause after graduation", async () => {
      await expect(
        graduatedCoin.connect(deployer).pause()
      ).to.be.revertedWithCustomError(graduatedCoin, "AlreadyGraduated");
    });

    it("should revert emergencyWithdraw after graduation", async () => {
      await expect(
        graduatedCoin.connect(deployer).emergencyWithdraw()
      ).to.be.revertedWithCustomError(graduatedCoin, "AlreadyGraduated");
    });
  });

  describe("8. Pause State Machine & Emergency Withdrawal", () => {
    it("should block buys and sells when contract is paused", async () => {
      await carbonCoin.connect(deployer).pause();

      await expect(
        carbonCoin.connect(trader1).buy(ethers.utils.parseUnits("10", 6), 0)
      ).to.be.revertedWithCustomError(carbonCoin, "EnforcedPause");

      await expect(
        carbonCoin.connect(trader1).sell(ethers.utils.parseEther("10"), 0)
      ).to.be.revertedWithCustomError(carbonCoin, "EnforcedPause");

      // Unpause resumes trading
      await carbonCoin.connect(deployer).unpause();

      await expect(
        carbonCoin.connect(trader1).buy(ethers.utils.parseUnits("10", 6), 0)
      ).to.emit(carbonCoin, "TokensPurchased");
    });

    it("should reject emergencyWithdraw if contract is not paused", async () => {
      await expect(
        carbonCoin.connect(deployer).emergencyWithdraw()
      ).to.be.revertedWith("Must be paused first");
    });

    it("should reject emergencyWithdraw from non-owner even if paused", async () => {
      await carbonCoin.connect(deployer).pause();

      await expect(
        carbonCoin.connect(attacker).emergencyWithdraw()
      ).to.be.revertedWithCustomError(carbonCoin, "Unauthorized");
    });

    it("should allow owner to execute emergencyWithdraw to treasury when paused", async () => {
      // First buy tokens so contract has USDC balance
      const buyAmount = ethers.utils.parseUnits("100", 6);
      await carbonCoin.connect(trader1).buy(buyAmount, 0);

      const contractUsdcBefore = await mockUsdc.balanceOf(carbonCoin.address);
      expect(contractUsdcBefore).to.be.gt(0);

      const treasuryAddress = await carbonCoinConfig.getTreasury();
      const treasuryBefore = await mockUsdc.balanceOf(treasuryAddress);

      // Pause and emergency withdraw
      await carbonCoin.connect(deployer).pause();
      await expect(
        carbonCoin.connect(deployer).emergencyWithdraw()
      ).to.emit(carbonCoin, "EmergencyWithdraw");

      expect(await mockUsdc.balanceOf(carbonCoin.address)).to.equal(0);
      expect(await mockUsdc.balanceOf(treasuryAddress)).to.equal(treasuryBefore.add(contractUsdcBefore));
    });
  });

  describe("9. Paymaster Authorization & Access Control", () => {
    it("should reject buyOnBehalf from non-paymaster", async () => {
      await expect(
        carbonCoin.connect(attacker).buyOnBehalf(trader1.address, ethers.utils.parseUnits("10", 6), 0)
      ).to.be.revertedWithCustomError(carbonCoin, "Unauthorized");
    });

    it("should reject sellOnBehalf from non-paymaster", async () => {
      await expect(
        carbonCoin.connect(attacker).sellOnBehalf(trader1.address, ethers.utils.parseEther("10"), 0)
      ).to.be.revertedWithCustomError(carbonCoin, "Unauthorized");
    });

    it("should reject registerWhaleIntentOnBehalf from non-paymaster", async () => {
      await expect(
        carbonCoin.connect(attacker).registerWhaleIntentOnBehalf(trader1.address, ethers.utils.parseUnits("1000", 6), true)
      ).to.be.revertedWithCustomError(carbonCoin, "Unauthorized");
    });
  });

  describe("10. Multi-Trade Price Monotonicity & Conservation", () => {
    it("should strictly increase price across consecutive buys and decrease across consecutive sells", async () => {
      let previousPrice = await carbonCoin.getCurrentPrice();
      const buySize = ethers.utils.parseUnits("20", 6);

      // Execute 5 consecutive buys
      for (let i = 0; i < 5; i++) {
        await carbonCoin.connect(trader1).buy(buySize, 0);
        const currentPrice = await carbonCoin.getCurrentPrice();
        expect(currentPrice).to.be.gt(previousPrice);
        previousPrice = currentPrice;

        // Advance past anti-bot cooldown
        await ethers.provider.send("evm_increaseTime", [20]);
        await ethers.provider.send("evm_mine", []);
      }

      // Configure maxSellPercentage to allow sells
      await carbonCoinConfig.connect(deployer).updateDefaultWhaleLimitConfig({
        whaleThreshold: ethers.utils.parseUnits("1000", 6),
        whaleDelay: 300,
        maxTradeSize: ethers.utils.parseUnits("2500", 6),
        maxSellPercentage: 10000
      });

      const totalBalance = await carbonCoin.balanceOf(trader1.address);
      const sellChunk = totalBalance.div(5);

      // Execute 5 consecutive sells
      for (let i = 0; i < 5; i++) {
        await carbonCoin.connect(trader1).sell(sellChunk, 0);
        const currentPrice = await carbonCoin.getCurrentPrice();
        expect(currentPrice).to.be.lt(previousPrice);
        previousPrice = currentPrice;

        await ethers.provider.send("evm_increaseTime", [20]);
        await ethers.provider.send("evm_mine", []);
      }
    });
  });

  describe("11. EIP-2612 Permit Buy Gasless Verification", () => {
    it("should execute buyWithPermit with valid signature in a single transaction", async () => {
      const buyAmount = ethers.utils.parseUnits("50", 6);
      const deadline = ethers.constants.MaxUint256;
      const nonce = await (mockUsdc as any).nonces(trader1.address);
      const { chainId } = await ethers.provider.getNetwork();

      const domain = {
        name: "USDC Clone",
        version: "1",
        chainId,
        verifyingContract: mockUsdc.address,
      };

      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      };

      const values = {
        owner: trader1.address,
        spender: carbonCoin.address,
        value: buyAmount,
        nonce,
        deadline,
      };

      const signature = await trader1._signTypedData(domain, types, values);
      const { v, r, s } = ethers.utils.splitSignature(signature);

      // Buy with permit succeeds
      await expect(
        carbonCoin.connect(trader1).buyWithPermit(buyAmount, 0, deadline, v, r, s)
      ).to.emit(carbonCoin, "TokensPurchased");
    });

    it("should revert buyWithPermit if permit deadline has passed", async () => {
      const buyAmount = ethers.utils.parseUnits("50", 6);
      const block = await ethers.provider.getBlock("latest");
      const pastDeadline = block.timestamp - 100;
      const nonce = await (mockUsdc as any).nonces(trader1.address);
      const { chainId } = await ethers.provider.getNetwork();

      const domain = {
        name: "USDC Clone",
        version: "1",
        chainId,
        verifyingContract: mockUsdc.address,
      };

      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      };

      const values = {
        owner: trader1.address,
        spender: carbonCoin.address,
        value: buyAmount,
        nonce,
        deadline: pastDeadline,
      };

      const signature = await trader1._signTypedData(domain, types, values);
      const { v, r, s } = ethers.utils.splitSignature(signature);

      await expect(
        carbonCoin.connect(trader1).buyWithPermit(buyAmount, 0, pastDeadline, v, r, s)
      ).to.be.reverted;
    });
  });
});
