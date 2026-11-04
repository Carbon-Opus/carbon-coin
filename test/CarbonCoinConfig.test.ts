import { ethers, deployments } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { CarbonCoinConfig } from "../typechain-types";

describe("CarbonCoinConfig", () => {
  let deployer: SignerWithAddress;
  let user1: SignerWithAddress;
  let config: CarbonCoinConfig;

  beforeEach(async () => {
    [deployer, user1] = await ethers.getSigners();
    await deployments.fixture(["Carbon", "Mocks"]);
    config = await ethers.getContract("CarbonCoinConfig");
  });

  it("should allow owner to update fees", async () => {
    const feeConfig = {
      buyFee: 200,
      sellFee: 200,
      maxFee: 500
    };
    await config.connect(deployer).updateDefaultFeeConfig(feeConfig);
    const newConfig = await config.getFeeConfig();
    expect(newConfig.buyFee).to.equal(200);
  });

  it("should reject fee updates from non-owner", async () => {
    const feeConfig = {
      buyFee: 200,
      sellFee: 200,
      maxFee: 500
    };
    await expect(config.connect(user1).updateDefaultFeeConfig(feeConfig))
        .to.be.revertedWithCustomError(config, "OwnableUnauthorizedAccount");
  });

  it("should allow owner to update anti-bot settings", async () => {
    const antiBotConfig = {
      antiBotDuration: 100,
      maxBuyAmountEarly: 200,
      maxWalletPercentage: 300,
      cooldownPeriod: 30,
      minBuyAmount: 1
    };
    await config.connect(deployer).updateDefaultAntiBotConfig(antiBotConfig);
    const antiBot = await config.getAntiBotConfig();
    expect(antiBot.antiBotDuration).to.equal(100);
  });

  it("should allow owner to update circuit breaker settings", async () => {
    const cbConfig = {
      maxPriceImpact: 300,
      volatilityWindow: 5,
      maxVolatilityMoves: 3,
      circuitBreakerDuration: 3600
    };
    await config.connect(deployer).updateDefaultCircuitBreakerConfig(cbConfig);
    const cb = await config.getCircuitBreakerConfig();
    expect(cb.maxPriceImpact).to.equal(300);
  });

  it("should allow owner to update whale limit settings", async () => {
    const whaleConfig = {
      whaleThreshold: 1000,
      whaleDelay: 7200,
      maxTradeSize: 2000,
      maxSellPercentage: 500
    };
    await config.connect(deployer).updateDefaultWhaleLimitConfig(whaleConfig);
    const wl = await config.getWhaleLimitConfig();
    expect(wl.whaleThreshold).to.equal(1000);
  });

  it("should allow owner to update dex and treasury addresses", async () => {
    await config.connect(deployer).updateDexAddress(user1.address);
    expect(await config.getCarbonCoinDex()).to.equal(user1.address);

    await config.connect(deployer).updateTreasury(user1.address);
    expect(await config.getTreasury()).to.equal(user1.address);
  });
});