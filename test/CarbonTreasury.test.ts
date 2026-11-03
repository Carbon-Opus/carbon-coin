import { ethers } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { CarbonTreasury, ERC20Mintable } from "../typechain-types";

describe("CarbonTreasury - Purchase & Allowance Protection (Issue #8)", () => {
  let carbonTreasury: CarbonTreasury;
  let usdcToken: ERC20Mintable;

  let deployer: SignerWithAddress;
  let user: SignerWithAddress;
  let attacker: SignerWithAddress;
  let receiver: SignerWithAddress;

  const memberId = ethers.utils.formatBytes32String("member_123");
  const orderId = ethers.utils.formatBytes32String("order_456");
  const orderType = ethers.utils.formatBytes32String("song_purchase");
  const price = ethers.utils.parseUnits("50", 6); // 50 USDC

  beforeEach(async () => {
    [deployer, user, attacker, receiver] = await ethers.getSigners();

    // 1. Deploy mock USDC token
    const ERC20MintableFactory = await ethers.getContractFactory("ERC20Mintable");
    usdcToken = (await ERC20MintableFactory.deploy("USDC Mock", "USDC")) as ERC20Mintable;
    await usdcToken.deployed();

    // 2. Deploy CarbonTreasury
    const CarbonTreasuryFactory = await ethers.getContractFactory("CarbonTreasury");
    carbonTreasury = (await CarbonTreasuryFactory.deploy(usdcToken.address)) as CarbonTreasury;
    await carbonTreasury.deployed();

    // 3. Mint USDC to user and approve treasury
    await usdcToken.mint(user.address, ethers.utils.parseUnits("1000", 6));
    await usdcToken.connect(user).approve(carbonTreasury.address, ethers.utils.parseUnits("500", 6));
  });

  describe("Purchase Allowance Authorization", () => {
    it("should revert if an attacker attempts to call purchase using another user's allowance", async () => {
      // Attacker tries to extract user's approved USDC
      await expect(
        carbonTreasury.connect(attacker).purchase(
          memberId,
          user.address,
          orderId,
          orderType,
          price
        )
      ).to.be.revertedWithCustomError(carbonTreasury, "Unauthorized");

      // Verify no USDC was taken from user
      expect(await usdcToken.balanceOf(carbonTreasury.address)).to.equal(0);
      expect(await usdcToken.balanceOf(user.address)).to.equal(ethers.utils.parseUnits("1000", 6));
    });

    it("should succeed when user calls purchase for their own memberAddress", async () => {
      await expect(
        carbonTreasury.connect(user).purchase(
          memberId,
          user.address,
          orderId,
          orderType,
          price
        )
      ).to.emit(carbonTreasury, "PurchaseCompleted")
        .withArgs(memberId, user.address, orderId, orderType, price);

      // Verify payment was collected
      expect(await usdcToken.balanceOf(carbonTreasury.address)).to.equal(price);
      expect(await usdcToken.balanceOf(user.address)).to.equal(ethers.utils.parseUnits("950", 6));
    });

    it("should allow purchaseWithPermit using a valid permit signature", async () => {
      const permitAmount = ethers.utils.parseUnits("75", 6);
      const nonce = await usdcToken.nonces(user.address);
      const deadline = ethers.constants.MaxUint256;
      const { chainId } = await ethers.provider.getNetwork();

      const domain = {
        name: "USDC Mock",
        version: "1",
        chainId,
        verifyingContract: usdcToken.address,
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
        owner: user.address,
        spender: carbonTreasury.address,
        value: permitAmount,
        nonce,
        deadline,
      };

      const signature = await user._signTypedData(domain, types, values);
      const { v, r, s } = ethers.utils.splitSignature(signature);

      // Relayer/Attacker can submit valid permit on user's behalf
      await expect(
        carbonTreasury.connect(attacker).purchaseWithPermit(
          memberId,
          user.address,
          orderId,
          orderType,
          permitAmount,
          deadline,
          v,
          r,
          s
        )
      ).to.emit(carbonTreasury, "PurchaseCompleted")
        .withArgs(memberId, user.address, orderId, orderType, permitAmount);

      expect(await usdcToken.balanceOf(carbonTreasury.address)).to.equal(permitAmount);
    });

    it("should revert purchaseWithPermit if permit signature is invalid", async () => {
      const permitAmount = ethers.utils.parseUnits("75", 6);
      const deadline = ethers.constants.MaxUint256;
      const fakeV = 27;
      const fakeR = ethers.utils.formatBytes32String("fake_r");
      const fakeS = ethers.utils.formatBytes32String("fake_s");

      await expect(
        carbonTreasury.connect(attacker).purchaseWithPermit(
          memberId,
          user.address,
          orderId,
          orderType,
          permitAmount,
          deadline,
          fakeV,
          fakeR,
          fakeS
        )
      ).to.be.reverted;
    });

    it("should allow owner to withdraw accumulated funds and reject non-owners", async () => {
      // User makes a purchase
      await carbonTreasury.connect(user).purchase(
        memberId,
        user.address,
        orderId,
        orderType,
        price
      );

      // Non-owner withdraw attempt reverts
      await expect(
        carbonTreasury.connect(attacker).withdraw(attacker.address, price)
      ).to.be.revertedWithCustomError(carbonTreasury, "OwnableUnauthorizedAccount").withArgs(attacker.address);

      // Owner withdraw succeeds
      await expect(
        carbonTreasury.connect(deployer).withdraw(receiver.address, price)
      ).to.emit(carbonTreasury, "Withdrawn");

      expect(await usdcToken.balanceOf(receiver.address)).to.equal(price);
      expect(await usdcToken.balanceOf(carbonTreasury.address)).to.equal(0);
    });

    it("should allow owner to collect LP fee rewards", async () => {
      const MockNPMFactory = await ethers.getContractFactory("MockNonfungiblePositionManager");
      const mockPositionManager = await MockNPMFactory.deploy();

      const tokenId = 42;

      await expect(
        carbonTreasury.connect(deployer).collectLpRewards(
          mockPositionManager.address,
          tokenId
        )
      ).to.emit(carbonTreasury, "LpRewardsCollected");

      const lastCollect = await mockPositionManager.lastCollect();
      expect(lastCollect.tokenId).to.equal(tokenId);
      expect(lastCollect.recipient).to.equal(carbonTreasury.address);
      expect(lastCollect.amount0Max).to.equal(ethers.constants.MaxUint256.shr(128)); // type(uint128).max
      expect(lastCollect.amount1Max).to.equal(ethers.constants.MaxUint256.shr(128));
    });

    it("should allow owner to collect LP fee rewards with custom amount caps", async () => {
      const MockNPMFactory = await ethers.getContractFactory("MockNonfungiblePositionManager");
      const mockPositionManager = await MockNPMFactory.deploy();

      const tokenId = 42;

      await carbonTreasury.connect(deployer).collectLpRewardsWithLimits(
        mockPositionManager.address,
        tokenId,
        50,
        75
      );

      const lastCollect = await mockPositionManager.lastCollect();
      expect(lastCollect.tokenId).to.equal(tokenId);
      expect(lastCollect.recipient).to.equal(carbonTreasury.address);
      expect(lastCollect.amount0Max).to.equal(50);
      expect(lastCollect.amount1Max).to.equal(75);
    });

    it("should revert collectLpRewards if called by non-owner", async () => {
      const MockNPMFactory = await ethers.getContractFactory("MockNonfungiblePositionManager");
      const mockPositionManager = await MockNPMFactory.deploy();

      await expect(
        carbonTreasury.connect(attacker).collectLpRewards(
          mockPositionManager.address,
          42
        )
      ).to.be.revertedWithCustomError(carbonTreasury, "OwnableUnauthorizedAccount").withArgs(attacker.address);
    });

    it("should revert collectLpRewards if invalid position manager is provided", async () => {
      await expect(
        carbonTreasury.connect(deployer).collectLpRewards(
          ethers.constants.AddressZero,
          42
        )
      ).to.be.revertedWith("Invalid position manager");
    });
  });
});
