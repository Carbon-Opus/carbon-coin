import { ethers, deployments } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { CarbonCoinPaymaster, ERC20Mintable } from "../typechain-types";

describe("CarbonCoinPaymaster", () => {
  let deployer: SignerWithAddress;
  let user1: SignerWithAddress;
  let paymaster: CarbonCoinPaymaster;
  let usdcToken: ERC20Mintable;

  beforeEach(async () => {
    [deployer, user1] = await ethers.getSigners();
    await deployments.fixture(["Carbon", "Mocks"]);
    paymaster = await ethers.getContract("CarbonCoinPaymaster");
    usdcToken = await ethers.getContract("ERC20Mintable");
  });

  it("should allow controller to update treasury", async () => {
    await paymaster.connect(deployer).updateController(user1.address);
  });

  it("should revert buy on behalf if not authorized", async () => {
    await expect(paymaster.connect(user1).buyOnBehalf(
        user1.address,
        user1.address,
        100,
        10,
        ethers.constants.MaxUint256,
        0, ethers.constants.HashZero, ethers.constants.HashZero
    )).to.be.revertedWithCustomError(paymaster, "Unauthorized");
  });

  it("should revert sell on behalf if not authorized", async () => {
    await expect(paymaster.connect(user1).sellOnBehalf(
        user1.address,
        user1.address,
        100,
        10
    )).to.be.revertedWithCustomError(paymaster, "Unauthorized");
  });

  it("should revert register whale intent if not authorized", async () => {
    await expect(paymaster.connect(user1).registerWhaleIntent(
        user1.address,
        user1.address,
        100,
        true
    )).to.be.revertedWithCustomError(paymaster, "Unauthorized");
  });
});