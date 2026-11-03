import { ethers } from "hardhat";
import { expect } from "chai";
import {
  CarbonCoinDex,
  CarbonCoinConfig,
  MockNonfungiblePositionManager,
  ERC20Mintable
} from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("CarbonCoinDex - Uniswap V3 / Concentrated Liquidity Integration", () => {
  let owner: SignerWithAddress;
  let creator: SignerWithAddress;
  let unauthorizedUser: SignerWithAddress;
  let carbonCoinConfig: CarbonCoinConfig;
  let mockPositionManager: MockNonfungiblePositionManager;
  let tokenA: ERC20Mintable;
  let tokenB: ERC20Mintable;

  beforeEach(async () => {
    const signers = await ethers.getSigners();
    owner = signers[0];
    creator = signers[1];
    unauthorizedUser = signers[3];

    // Deploy CarbonCoinConfig
    const ConfigFactory = await ethers.getContractFactory("CarbonCoinConfig");
    carbonCoinConfig = (await ConfigFactory.deploy()) as CarbonCoinConfig;

    // Deploy Mock NonfungiblePositionManager
    const MockNPMFactory = await ethers.getContractFactory("MockNonfungiblePositionManager");
    mockPositionManager = (await MockNPMFactory.deploy()) as MockNonfungiblePositionManager;

    // Deploy two ERC20 tokens to guarantee token0 < token1 ordering in both scenarios
    const ERC20Factory = await ethers.getContractFactory("ERC20Mintable");
    const t1 = (await ERC20Factory.deploy("Token 1", "TK1")) as ERC20Mintable;
    const t2 = (await ERC20Factory.deploy("Token 2", "TK2")) as ERC20Mintable;

    if (t1.address.toLowerCase() < t2.address.toLowerCase()) {
      tokenA = t1; // Smaller address
      tokenB = t2; // Larger address
    } else {
      tokenA = t2;
      tokenB = t1;
    }
  });

  it("should deploy liquidity with correct token ordering when address(USDC) < token (USDC is token0)", async () => {
    // In this scenario, USDC has the smaller address (tokenA) and created token has larger address (tokenB)
    const usdc = tokenA;
    const creatorToken = tokenB;

    const DexFactory = await ethers.getContractFactory("CarbonCoinDex");
    const dex = (await DexFactory.deploy(
      usdc.address,
      mockPositionManager.address,
      carbonCoinConfig.address,
      -887220,
      887220
    )) as CarbonCoinDex;

    const usdcAmount = ethers.utils.parseUnits("15000", 6);
    const tokensAmount = ethers.utils.parseEther("4500000");

    // Mint tokens to the authorized caller (owner is _owner() of config)
    await usdc.mint(owner.address, usdcAmount);
    await creatorToken.mint(owner.address, tokensAmount);

    await usdc.connect(owner).approve(dex.address, usdcAmount);
    await creatorToken.connect(owner).approve(dex.address, tokensAmount);

    await expect(
      dex.connect(owner).deployLiquidity(creator.address, creatorToken.address, tokensAmount, usdcAmount)
    ).to.emit(dex, "LiquidityDeployed")
      .withArgs(
        creatorToken.address,
        creator.address,
        42,
        tokensAmount,
        usdcAmount,
        1000000,
        (val: any) => val > 0
      );

    // Verify mock position manager received sorted tokens
    const lastMint = await mockPositionManager.lastMint();
    expect(lastMint.token0.toLowerCase()).to.equal(usdc.address.toLowerCase());
    expect(lastMint.token1.toLowerCase()).to.equal(creatorToken.address.toLowerCase());
    expect(lastMint.token0.toLowerCase() < lastMint.token1.toLowerCase()).to.be.true;
    expect(lastMint.amount0Desired).to.equal(usdcAmount);
    expect(lastMint.amount1Desired).to.equal(tokensAmount);
    expect(lastMint.tickLower).to.equal(-887220);
    expect(lastMint.tickUpper).to.equal(887220);
    expect(lastMint.recipient).to.equal(creator.address);

    // Verify pool was initialized
    expect(await mockPositionManager.poolCreated()).to.be.true;
    expect(await mockPositionManager.lastPoolToken0()).to.equal(usdc.address);
    expect(await mockPositionManager.lastPoolToken1()).to.equal(creatorToken.address);
    expect(await mockPositionManager.lastSqrtPriceX96()).to.be.gt(0);
  });

  it("should deploy liquidity with correct token ordering when token < address(USDC) (Token is token0)", async () => {
    // In this scenario, created token has the smaller address (tokenA) and USDC has larger address (tokenB)
    const creatorToken = tokenA;
    const usdc = tokenB;

    const DexFactory = await ethers.getContractFactory("CarbonCoinDex");
    const dex = (await DexFactory.deploy(
      usdc.address,
      mockPositionManager.address,
      carbonCoinConfig.address,
      -887220,
      887220
    )) as CarbonCoinDex;

    const usdcAmount = ethers.utils.parseUnits("15000", 6);
    const tokensAmount = ethers.utils.parseEther("4500000");

    await usdc.mint(owner.address, usdcAmount);
    await creatorToken.mint(owner.address, tokensAmount);

    await usdc.connect(owner).approve(dex.address, usdcAmount);
    await creatorToken.connect(owner).approve(dex.address, tokensAmount);

    await expect(
      dex.connect(owner).deployLiquidity(creator.address, creatorToken.address, tokensAmount, usdcAmount)
    ).to.emit(dex, "LiquidityDeployed")
      .withArgs(
        creatorToken.address,
        creator.address,
        42,
        tokensAmount,
        usdcAmount,
        1000000,
        (val: any) => val > 0
      );

    // Verify mock position manager received sorted tokens
    const lastMint = await mockPositionManager.lastMint();
    expect(lastMint.token0.toLowerCase()).to.equal(creatorToken.address.toLowerCase());
    expect(lastMint.token1.toLowerCase()).to.equal(usdc.address.toLowerCase());
    expect(lastMint.token0.toLowerCase() < lastMint.token1.toLowerCase()).to.be.true;
    expect(lastMint.amount0Desired).to.equal(tokensAmount);
    expect(lastMint.amount1Desired).to.equal(usdcAmount);
    expect(lastMint.tickLower).to.equal(-887220);
    expect(lastMint.tickUpper).to.equal(887220);
    expect(lastMint.recipient).to.equal(creator.address);

    // Verify pool was initialized
    expect(await mockPositionManager.poolCreated()).to.be.true;
    expect(await mockPositionManager.lastPoolToken0()).to.equal(creatorToken.address);
    expect(await mockPositionManager.lastPoolToken1()).to.equal(usdc.address);
    expect(await mockPositionManager.lastSqrtPriceX96()).to.be.gt(0);
  });

  it("should invert asymmetric ticks correctly when token is token0", async () => {
    const creatorToken = tokenA;
    const usdc = tokenB;

    const DexFactory = await ethers.getContractFactory("CarbonCoinDex");
    const dex = (await DexFactory.deploy(
      usdc.address,
      mockPositionManager.address,
      carbonCoinConfig.address,
      -1000,
      2000
    )) as CarbonCoinDex;

    const usdcAmount = ethers.utils.parseUnits("15000", 6);
    const tokensAmount = ethers.utils.parseEther("4500000");

    await usdc.mint(owner.address, usdcAmount);
    await creatorToken.mint(owner.address, tokensAmount);
    await usdc.connect(owner).approve(dex.address, usdcAmount);
    await creatorToken.connect(owner).approve(dex.address, tokensAmount);

    await dex.connect(owner).deployLiquidity(creator.address, creatorToken.address, tokensAmount, usdcAmount);

    const lastMint = await mockPositionManager.lastMint();
    // Since isUsdc0 is false, tickLower = -2000, tickUpper = 1000
    expect(lastMint.tickLower).to.equal(-2000);
    expect(lastMint.tickUpper).to.equal(1000);
    expect(lastMint.tickLower < lastMint.tickUpper).to.be.true;
  });

  it("should reject unauthorized callers from deploying liquidity", async () => {
    const DexFactory = await ethers.getContractFactory("CarbonCoinDex");
    const dex = (await DexFactory.deploy(
      tokenA.address,
      mockPositionManager.address,
      carbonCoinConfig.address,
      -887220,
      887220
    )) as CarbonCoinDex;

    await expect(
      dex.connect(unauthorizedUser).deployLiquidity(
        creator.address,
        tokenB.address,
        ethers.utils.parseEther("100"),
        ethers.utils.parseUnits("100", 6)
      )
    ).to.be.revertedWithCustomError(dex, "Unauthorized");
  });

  it("should respect pause and unpause", async () => {
    const DexFactory = await ethers.getContractFactory("CarbonCoinDex");
    const dex = (await DexFactory.deploy(
      tokenA.address,
      mockPositionManager.address,
      carbonCoinConfig.address,
      -887220,
      887220
    )) as CarbonCoinDex;

    await dex.connect(owner).pause();

    await expect(
      dex.connect(owner).deployLiquidity(
        creator.address,
        tokenB.address,
        ethers.utils.parseEther("100"),
        ethers.utils.parseUnits("100", 6)
      )
    ).to.be.revertedWithCustomError(dex, "EnforcedPause");

    await dex.connect(owner).unpause();
  });

  describe("Graduation LP Recipient & Rug Pull Protection (Issue #9)", () => {
    let treasury: SignerWithAddress;

    beforeEach(async () => {
      const signers = await ethers.getSigners();
      treasury = signers[4];
    });

    it("should allow owner to update and get treasury in CarbonCoinConfig", async () => {
      expect(await carbonCoinConfig.getTreasury()).to.equal(ethers.constants.AddressZero);

      await expect(
        carbonCoinConfig.connect(owner).updateTreasury(treasury.address)
      ).to.emit(carbonCoinConfig, "DefaultConfigUpdated")
        .withArgs("Treasury", (val: any) => val > 0);

      expect(await carbonCoinConfig.getTreasury()).to.equal(treasury.address);

      // Revert if non-owner tries to update
      await expect(
        carbonCoinConfig.connect(unauthorizedUser).updateTreasury(treasury.address)
      ).to.be.revertedWithCustomError(carbonCoinConfig, "OwnableUnauthorizedAccount");
    });

    it("should route LP tokens to treasury when deployLiquidity is called with address(0)", async () => {
      const usdc = tokenA;
      const creatorToken = tokenB;

      await carbonCoinConfig.connect(owner).updateTreasury(treasury.address);

      const DexFactory = await ethers.getContractFactory("CarbonCoinDex");
      const dex = (await DexFactory.deploy(
        usdc.address,
        mockPositionManager.address,
        carbonCoinConfig.address,
        -887220,
        887220
      )) as CarbonCoinDex;

      const usdcAmount = ethers.utils.parseUnits("15000", 6);
      const tokensAmount = ethers.utils.parseEther("4500000");

      await usdc.mint(owner.address, usdcAmount);
      await creatorToken.mint(owner.address, tokensAmount);
      await usdc.connect(owner).approve(dex.address, usdcAmount);
      await creatorToken.connect(owner).approve(dex.address, tokensAmount);

      // Call deployLiquidity with AddressZero recipient
      await expect(
        dex.connect(owner).deployLiquidity(ethers.constants.AddressZero, creatorToken.address, tokensAmount, usdcAmount)
      ).to.emit(dex, "LiquidityDeployed")
        .withArgs(
          creatorToken.address,
          treasury.address,
          42,
          tokensAmount,
          usdcAmount,
          1000000,
          (val: any) => val > 0
        );

      const lastMint = await mockPositionManager.lastMint();
      expect(lastMint.recipient).to.equal(treasury.address);
      expect(lastMint.recipient).to.not.equal(creator.address);
    });

    it("should send LP position NFT to treasury instead of creator upon CarbonCoin graduation", async () => {
      const usdc = tokenA;

      await carbonCoinConfig.connect(owner).updateTreasury(treasury.address);

      const DexFactory = await ethers.getContractFactory("CarbonCoinDex");
      const dex = (await DexFactory.deploy(
        usdc.address,
        mockPositionManager.address,
        carbonCoinConfig.address,
        -887220,
        887220
      )) as CarbonCoinDex;

      await carbonCoinConfig.connect(owner).updateDexAddress(dex.address);

      // Deploy CarbonCoinProtection
      const ProtectionFactory = await ethers.getContractFactory("CarbonCoinProtection");
      const protection = await ProtectionFactory.deploy(owner.address);
      await protection.updateConfig(carbonCoinConfig.address);

      // Deploy MockLauncher
      const MockLauncherFactory = await ethers.getContractFactory("MockLauncher");
      const mockLauncher = await MockLauncherFactory.deploy();

      // Deploy CarbonCoin through MockLauncher with small graduation threshold (100 USDC)
      const graduationThreshold = ethers.utils.parseUnits("100", 6);
      const tx = await mockLauncher.createToken(
        "Graduation Coin",
        "GCOIN",
        creator.address,
        usdc.address,
        owner.address, // paymaster
        carbonCoinConfig.address,
        protection.address,
        {
          virtualUsdc: ethers.utils.parseUnits("50000", 6),
          virtualTokens: ethers.utils.parseEther("6000000"),
          creatorReserve: ethers.utils.parseEther("1000000"),
          liquiditySupply: ethers.utils.parseEther("4500000"),
          curveSupply: ethers.utils.parseEther("4500000"),
          maxSupply: ethers.utils.parseEther("10000000"),
          graduationThreshold
        }
      );
      const receipt = await tx.wait();
      // Find created coin address from transfer/deployment or getter
      const CarbonCoinFactory = await ethers.getContractFactory("CarbonCoin");
      const coinAddress = receipt.logs[receipt.logs.length - 1].address;
      const coin = CarbonCoinFactory.attach(coinAddress);

      // Mint USDC to owner and buy to reach graduation threshold (buy slightly more to cover fee)
      const buyAmount = ethers.utils.parseUnits("110", 6);
      await usdc.mint(owner.address, buyAmount);
      await usdc.connect(owner).approve(coin.address, buyAmount);

      // Buy enough to trigger graduation
      await coin.connect(owner).buy(buyAmount, 0);

      // Verify token has graduated
      expect(await coin.hasGraduated()).to.be.true;

      // Verify LP position was minted to TREASURY and NOT to creator
      const lastMint = await mockPositionManager.lastMint();
      expect(lastMint.recipient).to.equal(treasury.address);
      expect(lastMint.recipient).to.not.equal(creator.address);
    });
  });
});
