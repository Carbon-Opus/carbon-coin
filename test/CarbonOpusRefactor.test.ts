import { ethers } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { CarbonOpus, CarbonOpusVault, CarbonTreasury, ERC20Mintable } from "../typechain-types";

describe("CarbonOpus Refactor", () => {
  let carbonOpus: CarbonOpus;
  let carbonOpusVault: CarbonOpusVault;
  let carbonTreasury: CarbonTreasury;
  let usdcToken: ERC20Mintable;
  
  let deployer: SignerWithAddress;
  let controller: SignerWithAddress;
  let artistA: SignerWithAddress;
  let artistB: SignerWithAddress;
  let buyer: SignerWithAddress;
  let referrer: SignerWithAddress;

  const memberIdA = ethers.utils.formatBytes32String("artist_a_member_id");
  const memberIdB = ethers.utils.formatBytes32String("artist_b_member_id");
  const buyerMemberId = ethers.utils.formatBytes32String("buyer_member_id");
  const referrerMemberId = ethers.utils.formatBytes32String("referrer_member_id");
  const treasuryId = ethers.utils.formatBytes32String("treasury");

  const uri = "https://api-plxgamnywq-uc.a.run.app/nft/{id}.json";
  const songPrice = ethers.utils.parseUnits("10", 6); // 10 USDC (6 decimals)
  const referralPct = 500; // 5% (500 basis points)

  beforeEach(async () => {
    [deployer, controller, artistA, artistB, buyer, referrer] = await ethers.getSigners();

    // 1. Deploy mock USDC token
    const ERC20MintableFactory = await ethers.getContractFactory("ERC20Mintable");
    usdcToken = (await ERC20MintableFactory.deploy("USDC Mock", "USDC")) as ERC20Mintable;

    // 2. Deploy the contracts
    const CarbonTreasuryFactory = await ethers.getContractFactory("CarbonTreasury");
    carbonTreasury = (await CarbonTreasuryFactory.deploy(usdcToken.address)) as CarbonTreasury;

    const CarbonOpusVaultFactory = await ethers.getContractFactory("CarbonOpusVault");
    const CarbonOpusFactory = await ethers.getContractFactory("CarbonOpus");
    carbonOpus = (await CarbonOpusFactory.deploy(uri, usdcToken.address, carbonTreasury.address, ethers.constants.AddressZero)) as CarbonOpus;

    carbonOpusVault = (await CarbonOpusVaultFactory.deploy(carbonOpus.address, usdcToken.address, carbonTreasury.address)) as CarbonOpusVault;

    await carbonOpus.connect(deployer).updateOpusVault(carbonOpusVault.address);

    // 3. Set the controller and opus address
    await carbonOpus.connect(deployer).updateController(controller.address);
    await carbonOpusVault.connect(deployer).updateCarbonOpus(carbonOpus.address);

    // 4. Mint some USDC to the buyer
    const mintAmount = ethers.utils.parseUnits("1000", 6);
    await usdcToken.connect(deployer).mint(buyer.address, mintAmount);

    // 5. Approve CarbonOpusVault to spend buyer's USDC
    await usdcToken.connect(buyer).approve(carbonOpusVault.address, mintAmount);
  });

  describe("Reward Distribution through Vault", () => {
    let tokenId = 1;

    beforeEach(async () => {
      await carbonOpus.connect(controller).createMusic(
        memberIdA,
        artistA.address,
        songPrice,
        referralPct
      );
    });

    it("should correctly calculate and store rewards in the vault", async () => {
      await carbonOpus.connect(buyer).purchaseMusic(
        buyerMemberId,
        buyer.address,
        tokenId,
        referrerMemberId
      );

      // protocol fee = 1% (100 basis points) of 10 USDC = 0.1 USDC = 100,000 (with 6 decimals)
      const expectedTreasuryReward = songPrice.mul(100).div(10000);
      // referral pct = 5% (500 basis points) of (10 - 0.1) USDC = 0.495 USDC = 495,000
      const expectedReferrerReward = songPrice.sub(expectedTreasuryReward).mul(referralPct).div(10000);
      // artist share = 10 - 0.1 - 0.495 = 9.405 USDC = 9405000
      const expectedArtistReward = songPrice.sub(expectedTreasuryReward).sub(expectedReferrerReward);

      expect(await carbonOpusVault.rewards(memberIdA)).to.equal(expectedArtistReward);
      expect(await carbonOpusVault.rewards(referrerMemberId)).to.equal(expectedReferrerReward);
      expect(await carbonOpusVault.rewards(treasuryId)).to.equal(expectedTreasuryReward);
    });

    it("should allow artist to claim rewards from the vault", async () => {
        await carbonOpus.connect(buyer).purchaseMusic(
            buyerMemberId,
            buyer.address,
            tokenId,
            referrerMemberId
        );

        const artistReward = await carbonOpusVault.rewards(memberIdA);
        const oldBalance = await usdcToken.balanceOf(artistA.address);

        await carbonOpusVault.connect(artistA).claimRewards(memberIdA, artistA.address);

        const newBalance = await usdcToken.balanceOf(artistA.address);
        expect(newBalance.sub(oldBalance)).to.equal(artistReward);
        expect(await carbonOpusVault.rewards(memberIdA)).to.equal(0);
    });

    it("should allow referrer to claim rewards from the vault", async () => {
        await carbonOpus.connect(buyer).purchaseMusic(
            buyerMemberId,
            buyer.address,
            tokenId,
            referrerMemberId
        );

        const referrerReward = await carbonOpusVault.rewards(referrerMemberId);
        const oldBalance = await usdcToken.balanceOf(referrer.address);

        await carbonOpusVault.connect(referrer).claimRewards(referrerMemberId, referrer.address);

        const newBalance = await usdcToken.balanceOf(referrer.address);
        expect(newBalance.sub(oldBalance)).to.equal(referrerReward);
        expect(await carbonOpusVault.rewards(referrerMemberId)).to.equal(0);
    });

    it("should allow treasury to claim rewards from the vault", async () => {
        await carbonOpus.connect(buyer).purchaseMusic(
            buyerMemberId,
            buyer.address,
            tokenId,
            referrerMemberId
        );

        const treasuryReward = await carbonOpusVault.rewards(treasuryId);
        const oldBalance = await usdcToken.balanceOf(carbonTreasury.address);

        await carbonTreasury.connect(deployer).claimRewards(carbonOpusVault.address);

        const newBalance = await usdcToken.balanceOf(carbonTreasury.address);
        expect(newBalance.sub(oldBalance)).to.equal(treasuryReward);
        expect(await carbonOpusVault.rewards(treasuryId)).to.equal(0);
    });

    it("should not allow non-treasury to claim treasury rewards", async () => {
        await carbonOpus.connect(buyer).purchaseMusic(
            buyerMemberId,
            buyer.address,
            tokenId,
            referrerMemberId
        );

        await expect(
            carbonOpusVault.connect(buyer).claimTreasuryRewards(carbonTreasury.address)
        ).to.be.revertedWith("Only treasury can claim");
    });
  });

  describe("CarbonOpus Contract Refactor Verification", () => {
    it("should not have a rewards mapping", async () => {
        const contract = new ethers.Contract(carbonOpus.address, carbonOpus.interface, ethers.provider);
        expect(contract.rewards).to.be.undefined;
    });

    it("should not have a claimRewards function", async () => {
        const contract = new ethers.Contract(carbonOpus.address, carbonOpus.interface, ethers.provider);
        expect(contract.claimRewards).to.be.undefined;
    });
  });
});
