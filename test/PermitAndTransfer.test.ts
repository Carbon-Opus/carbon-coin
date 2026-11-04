import { ethers, deployments } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { PermitAndTransfer, ERC20Mintable } from "../typechain-types";

describe("PermitAndTransfer", () => {
  let deployer: SignerWithAddress;
  let user1: SignerWithAddress;
  let permitAndTransfer: PermitAndTransfer;
  let usdcToken: ERC20Mintable;

  beforeEach(async () => {
    [deployer, user1] = await ethers.getSigners();
    await deployments.fixture(["Carbon", "Mocks"]);
    permitAndTransfer = await ethers.getContract("PermitAndTransfer");
    usdcToken = await ethers.getContract("ERC20Mintable");
  });

  it("should allow owner to add and remove token", async () => {
    await permitAndTransfer.connect(deployer).addToken(usdcToken.address);
    expect(await permitAndTransfer.isWhitelisted(usdcToken.address)).to.equal(true);

    await permitAndTransfer.connect(deployer).removeToken(usdcToken.address);
    expect(await permitAndTransfer.isWhitelisted(usdcToken.address)).to.equal(false);
  });

  it("should revert addToken from non-owner", async () => {
    await expect(permitAndTransfer.connect(user1).addToken(usdcToken.address))
        .to.be.revertedWithCustomError(permitAndTransfer, "OwnableUnauthorizedAccount");
  });

  it("should revert permitAndTransfer with unwhitelisted token", async () => {
    await expect(permitAndTransfer.connect(user1).permitAndTransfer(
        ethers.constants.HashZero,
        ethers.constants.HashZero,
        usdcToken.address,
        user1.address,
        user1.address,
        100,
        ethers.constants.MaxUint256,
        0, ethers.constants.HashZero, ethers.constants.HashZero
    )).to.be.revertedWith("Token not whitelisted");
  });
});