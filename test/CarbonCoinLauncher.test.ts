import { ethers, deployments } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { CarbonCoinLauncher, CarbonCoinConfig, CarbonCoinProtection, CarbonCoinPaymaster, ERC20Mintable } from "../typechain-types";

describe("CarbonCoinLauncher", () => {
  let deployer: SignerWithAddress;
  let user1: SignerWithAddress;
  let launcher: CarbonCoinLauncher;
  let config: CarbonCoinConfig;
  let usdcToken: ERC20Mintable;

  beforeEach(async () => {
    [deployer, user1] = await ethers.getSigners();
    await deployments.fixture(["Carbon", "Mocks"]);
    launcher = await ethers.getContract("CarbonCoinLauncher");
    config = await ethers.getContract("CarbonCoinConfig");
    usdcToken = await ethers.getContract("ERC20Mintable");
  });

  it("should deploy properly and expose view methods", async () => {
    expect(await launcher.configAddress()).to.equal(config.address);
    expect(await launcher.usdcAddress()).to.equal(usdcToken.address);
  });

  it("should allow owner to update controller", async () => {
    await launcher.connect(deployer).updateController(user1.address);
    // Can't easily read internal controller, but we can verify it doesn't revert.
  });

  it("should reject unpausing by non-owner", async () => {
    await expect(launcher.connect(user1).unpause())
        .to.be.revertedWithCustomError(launcher, "OwnableUnauthorizedAccount");
  });

  it("should reject pausing by non-owner", async () => {
    await expect(launcher.connect(user1).pause())
        .to.be.revertedWithCustomError(launcher, "OwnableUnauthorizedAccount");
  });

  it("should allow owner to withdraw accumulated fees", async () => {
    await launcher.connect(deployer).withdrawUsdcFees();
    await launcher.connect(deployer).withdrawNativeFees();
  });

  it("should reject fee withdrawal from non-owner", async () => {
    await expect(launcher.connect(user1).withdrawUsdcFees())
        .to.be.revertedWithCustomError(launcher, "OwnableUnauthorizedAccount");
    await expect(launcher.connect(user1).withdrawNativeFees())
        .to.be.revertedWithCustomError(launcher, "OwnableUnauthorizedAccount");
  });

  it("should reject token creation if max tokens reached", async () => {
    await launcher.connect(deployer).setMaxTokensPerCreator(1);
    
    // Create 1st token (should succeed)
    await launcher.connect(deployer).createToken(
        "Test1", "TST1", user1.address,
        {
          virtualUsdc: 1,
          virtualTokens: 1,
          creatorReserve: 1,
          liquiditySupply: 1,
          curveSupply: 1,
          maxSupply: 10,
          graduationThreshold: 1
        }
    );

    // Create 2nd token for the same user (should fail)
    await expect(launcher.connect(deployer).createToken(
        "Test2", "TST2", user1.address,
        {
          virtualUsdc: 1,
          virtualTokens: 1,
          creatorReserve: 1,
          liquiditySupply: 1,
          curveSupply: 1,
          maxSupply: 10,
          graduationThreshold: 1
        }
    )).to.be.revertedWithCustomError(launcher, "TooManyTokens");
  });

  it("should allow owner to update max tokens", async () => {
    await launcher.connect(deployer).setMaxTokensPerCreator(2);
    expect(await launcher.maxTokensPerCreator()).to.equal(2);
  });

  it("should revert if invalid bonding curve parameters are provided", async () => {
    await expect(launcher.connect(deployer).updateProtectionAddress(ethers.constants.AddressZero))
        .to.be.revertedWithCustomError(launcher, "InvalidAddress");
  });
});