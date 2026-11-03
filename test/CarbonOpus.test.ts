import { ethers } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { CarbonOpus, ERC20Mintable } from "../typechain-types";

describe("CarbonOpus - Song Locking, Reward Locking, and Reassignment", () => {
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
    carbonOpusVault = (await CarbonOpusVaultFactory.deploy(usdcToken.address, carbonTreasury.address)) as CarbonOpusVault;

    const CarbonOpusFactory = await ethers.getContractFactory("CarbonOpus");
    carbonOpus = (await CarbonOpusFactory.deploy(uri, usdcToken.address, carbonTreasury.address, carbonOpusVault.address)) as CarbonOpus;

    // 3. Set the controller and opus address
    await carbonOpus.connect(deployer).updateController(controller.address);
    await carbonOpus.connect(deployer).updateOpusVault(carbonOpusVault.address);
    await carbonOpusVault.connect(deployer).updateCarbonOpus(carbonOpus.address);

    // 4. Mint some USDC to the buyer
    const mintAmount = ethers.utils.parseUnits("1000", 6);
    await usdcToken.connect(deployer).mint(buyer.address, mintAmount);
    await usdcToken.connect(deployer).mint(controller.address, mintAmount);


    // 5. Approve CarbonOpusVault to spend buyer's USDC
    await usdcToken.connect(buyer).approve(carbonOpusVault.address, mintAmount);
    await usdcToken.connect(controller).approve(carbonOpusVault.address, mintAmount);
  });

  describe("Song Initialization & Creation", () => {
    it("should allow controller to create a song with correct parameters", async () => {
      const tx = await carbonOpus.connect(controller).createMusic(
        memberIdA,
        artistA.address,
        songPrice,
        referralPct
      );

      const receipt = await tx.wait();
      expect(receipt).to.not.be.null;

      const song = await carbonOpus.songs(1);
      expect(song.memberId).to.equal(memberIdA);
      expect(song.price).to.equal(songPrice);
      expect(song.referralPct).to.equal(referralPct);
      expect(song.locked).to.be.false;

      // Artist should receive 1 edition of the song
      expect(await carbonOpus.balanceOf(artistA.address, 1)).to.equal(1);
    });

    it("should reject song creation if not authorized", async () => {
      await expect(
        carbonOpus.connect(artistA).createMusic(
          memberIdA,
          artistA.address,
          songPrice,
          referralPct
        )
      ).to.be.revertedWithCustomError(carbonOpus, "NotAuthorized");
    });
  });

  describe("Song Locking & Purchasing Protections", () => {
    let tokenId = 1;

    beforeEach(async () => {
      await carbonOpus.connect(controller).createMusic(
        memberIdA,
        artistA.address,
        songPrice,
        referralPct
      );
    });

    it("should allow purchasing an unlocked song", async () => {
      await expect(
        carbonOpus.connect(controller).purchaseMusic(
          buyerMemberId,
          buyer.address,
          tokenId,
          referrerMemberId
        )
      ).to.emit(carbonOpus, "SongPurchased");

      expect(await carbonOpus.balanceOf(buyer.address, tokenId)).to.equal(1);
    });

    it("should lock and unlock a song and update status", async () => {
      // Lock song
      await expect(carbonOpus.connect(controller).updateSongLockStatus(tokenId, true))
        .to.emit(carbonOpus, "SongLockStatusUpdated")
        .withArgs(tokenId, true);

      let song = await carbonOpus.songs(tokenId);
      expect(song.locked).to.be.true;

      // Unlock song
      await expect(carbonOpus.connect(controller).updateSongLockStatus(tokenId, false))
        .to.emit(carbonOpus, "SongLockStatusUpdated")
        .withArgs(tokenId, false);

      song = await carbonOpus.songs(tokenId);
      expect(song.locked).to.be.false;
    });

    it("should revert single purchases if the song is locked", async () => {
      // Lock the song
      await carbonOpus.connect(controller).updateSongLockStatus(tokenId, true);

      // Attempt to purchase
      await expect(
        carbonOpus.connect(controller).purchaseMusic(
          buyerMemberId,
          buyer.address,
          tokenId,
          referrerMemberId
        )
      ).to.be.revertedWithCustomError(carbonOpus, "SongLocked").withArgs(tokenId);
    });

    it("should revert batch purchases if any of the songs are locked", async () => {
      // Create second song (tokenId = 2)
      await carbonOpus.connect(controller).createMusic(
        memberIdA,
        artistA.address,
        songPrice,
        referralPct
      );

      // Lock second song
      await carbonOpus.connect(controller).updateSongLockStatus(2, true);

      // Attempt to purchase batch of song 1 and song 2
      await expect(
        carbonOpus.connect(controller).purchaseBatch(
          buyerMemberId,
          buyer.address,
          [1, 2],
          [referrerMemberId, referrerMemberId]
        )
      ).to.be.revertedWithCustomError(carbonOpus, "SongLocked").withArgs(2);
    });
  });

  describe("Reward Tracking and Locking", () => {
    let tokenId = 1;

    beforeEach(async () => {
      await carbonOpus.connect(controller).createMusic(
        memberIdA,
        artistA.address,
        songPrice,
        referralPct
      );
    });

    it("should correctly track and accumulate rewards in the vault", async () => {
      // Buy the song once
      await carbonOpus.connect(controller).purchaseMusic(
        buyerMemberId,
        buyer.address,
        tokenId,
        referrerMemberId
      );

      // protocol fee = 10% (1000 basis points) of 10 USDC = 1 USDC = 1,000,000 (with 6 decimals)
      // referral pct = 5% (500 basis points) of 9 USDC = 0.45 USDC = 450,000
      // artist share = 9 USDC - 0.45 USDC = 8.55 USDC = 8,550,000
      const protocolFee = (songPrice.mul(100)) / 10000;
      const referralShare = (songPrice.sub(protocolFee).mul(referralPct)) / 10000;
      const artistShare = songPrice.sub(protocolFee).sub(referralShare);

      expect(await carbonOpusVault.rewards(memberIdA)).to.equal(artistShare);
      expect(await carbonOpusVault.rewards(referrerMemberId)).to.equal(referralShare);
      expect(await carbonOpusVault.rewards(treasuryId)).to.equal(protocolFee);
    });

    it("should allow artist to claim their rewards from the vault", async () => {
      // Buy the song
      await carbonOpus.connect(controller).purchaseMusic(
        buyerMemberId,
        buyer.address,
        tokenId,
        referrerMemberId
      );

      const protocolFee = (songPrice.mul(100)) / 10000;
      const referralShare = (songPrice.sub(protocolFee).mul(referralPct)) / 10000;
      const artistShare = songPrice.sub(protocolFee).sub(referralShare);

      // Claim rewards
      const oldBalance = await usdcToken.balanceOf(artistA.address);
      await carbonOpusVault.connect(artistA).claimRewards(memberIdA, artistA.address);
      const newBalance = await usdcToken.balanceOf(artistA.address);

      expect(newBalance.sub(oldBalance)).to.equal(artistShare);
      expect(await carbonOpusVault.rewards(memberIdA)).to.equal(0);
    });
  });

  describe("Song Reassignment", () => {
    let tokenId = 1;

    beforeEach(async () => {
      await carbonOpus.connect(controller).createMusic(
        memberIdA,
        artistA.address,
        songPrice,
        referralPct
      );

      // Buy the song once to generate accrued (unclaimed) historical rewards
      await carbonOpus.connect(controller).purchaseMusic(
        buyerMemberId,
        buyer.address,
        tokenId,
        referrerMemberId
      );
    });

    it("should reattribute song and future rewards to new member, but not unclaimed rewards", async () => {
      const protocolFee = (songPrice.mul(100)) / 10000;
      const referralShare = (songPrice.sub(protocolFee).mul(referralPct)) / 10000;
      const artistShare = songPrice.sub(protocolFee).sub(referralShare);

      // Historical rewards are currently with Artist A
      expect(await carbonOpusVault.rewards(memberIdA)).to.equal(artistShare);

      // Reassign song from Artist A to Artist B
      await expect(
        carbonOpus.connect(controller).reassignSong(
          tokenId,
          memberIdB,
          artistA.address,
          artistB.address
        )
      )
        .to.emit(carbonOpus, "SongReassigned")
        .withArgs(tokenId, memberIdA, memberIdB, artistB.address);

      // Song's creator/memberId should be Artist B now
      const song = await carbonOpus.songs(tokenId);
      expect(song.memberId).to.equal(memberIdB);

      // Artist A should still have their claimable rewards
      expect(await carbonOpusVault.rewards(memberIdA)).to.equal(artistShare);

      // Artist B should have no rewards yet
      expect(await carbonOpusVault.rewards(memberIdB)).to.equal(0);

      // Purchase the song again
      await carbonOpus.connect(controller).purchaseMusic(
        buyerMemberId,
        buyer.address,
        tokenId,
        referrerMemberId
      );

      // Artist B should now have their new rewards
      expect(await carbonOpusVault.rewards(memberIdB)).to.equal(artistShare);

      // Check NFT balances
      expect(await carbonOpus.balanceOf(artistA.address, tokenId)).to.equal(0);
      expect(await carbonOpus.balanceOf(artistB.address, tokenId)).to.equal(1);

      // Claim rewards for Artist A
      const oldBalanceA = await usdcToken.balanceOf(artistA.address);
      await carbonOpusVault.connect(artistA).claimRewards(memberIdA, artistA.address);
      expect((await usdcToken.balanceOf(artistA.address)).sub(oldBalanceA)).to.equal(artistShare);

      // Claim rewards for Artist B
      const oldBalanceB = await usdcToken.balanceOf(artistB.address);
      await carbonOpusVault.connect(artistB).claimRewards(memberIdB, artistB.address);
      expect((await usdcToken.balanceOf(artistB.address)).sub(oldBalanceB)).to.equal(artistShare);
    });

    it("should correctly update ownership lists (musicBalance) upon reassignment", async () => {
      // Reassign song from Artist A to Artist B
      await carbonOpus.connect(controller).reassignSong(
        tokenId,
        memberIdB,
        artistA.address,
        artistB.address
      );

      // Query musicBalance for both artists
      const [artistATokenIds, artistABalances] = await carbonOpus.musicBalance(artistA.address);
      const [artistBTokenIds, artistBBalances] = await carbonOpus.musicBalance(artistB.address);

      expect(artistATokenIds.length).to.equal(0);
      expect(artistBTokenIds.length).to.equal(1);
      expect(artistBTokenIds[0]).to.equal(tokenId);
      expect(artistBBalances[0]).to.equal(1);
    });
  });

  describe("Security Boundaries & Complex Edge Cases", () => {
    let tokenId = 1;

    beforeEach(async () => {
      await carbonOpus.connect(controller).createMusic(
        memberIdA,
        artistA.address,
        songPrice,
        referralPct
      );
    });

    it("should reject unauthorized attempts to lock/unlock a song", async () => {
      await expect(
        carbonOpus.connect(artistA).updateSongLockStatus(tokenId, true)
      ).to.be.revertedWithCustomError(carbonOpus, "NotAuthorized");
    });

    it("should reject unauthorized attempts to reassign a song", async () => {
      await expect(
        carbonOpus.connect(artistA).reassignSong(
          tokenId,
          memberIdB,
          artistA.address,
          artistB.address
        )
      ).to.be.revertedWithCustomError(carbonOpus, "NotAuthorized");
    });

    it("should revert if locking a non-existent song", async () => {
      const nonExistentId = 999;
      await expect(
        carbonOpus.connect(controller).updateSongLockStatus(nonExistentId, true)
      ).to.be.revertedWithCustomError(carbonOpus, "SongDoesNotExist").withArgs(nonExistentId);
    });

    it("should revert if reassigning a non-existent song", async () => {
      const nonExistentId = 999;
      await expect(
        carbonOpus.connect(controller).reassignSong(
          nonExistentId,
          memberIdB,
          artistA.address,
          artistB.address
        )
      ).to.be.revertedWithCustomError(carbonOpus, "SongDoesNotExist").withArgs(nonExistentId);
    });

    it("should handle self-reassignment gracefully and return early", async () => {
      // Reassign to current owner (Artist A)
      const tx = await carbonOpus.connect(controller).reassignSong(
        tokenId,
        memberIdA,
        artistA.address,
        artistA.address
      );

      const receipt = await tx.wait();
      // Should not emit SongReassigned if they are equal
      const reassignedEvent = receipt.events?.find(e => e.event === 'SongReassigned');
      expect(reassignedEvent).to.be.undefined;

      const song = await carbonOpus.songs(tokenId);
      expect(song.memberId).to.equal(memberIdA);
    });

    it("should succeed in reassigning even if the old artist has a zero NFT balance", async () => {
      // Artist A transfers their token to buyer
      await carbonOpus.connect(artistA).safeTransferFrom(
        artistA.address,
        buyer.address,
        tokenId,
        1,
        "0x"
      );

      expect(await carbonOpus.balanceOf(artistA.address, tokenId)).to.equal(0);

      // Now reassign to Artist B. Since oldBalance is 0, it won't call internal _update transfer.
      await expect(
        carbonOpus.connect(controller).reassignSong(
          tokenId,
          memberIdB,
          artistA.address,
          artistB.address
        )
      )
        .to.emit(carbonOpus, "SongReassigned")
        .withArgs(tokenId, memberIdA, memberIdB, artistB.address);

      expect(await carbonOpus.balanceOf(artistA.address, tokenId)).to.equal(0);
      expect(await carbonOpus.balanceOf(artistB.address, tokenId)).to.equal(0);
    });

    it("should allow referrers to claim their rewards", async () => {
      // Buy the song once to generate referral rewards for the referrer
      await carbonOpus.connect(controller).purchaseMusic(
        buyerMemberId,
        buyer.address,
        tokenId,
        referrerMemberId
      );

      const protocolFee = (songPrice.mul(100)) / 10000;
      const referralShare = (songPrice.sub(protocolFee).mul(referralPct)) / 10000;

      expect(await carbonOpusVault.rewards(referrerMemberId)).to.equal(referralShare);

      // Referrer claims successfully
      const oldBalance = await usdcToken.balanceOf(referrer.address);
      await carbonOpusVault.connect(referrer).claimRewards(referrerMemberId, referrer.address);
      expect((await usdcToken.balanceOf(referrer.address)).sub(oldBalance)).to.equal(referralShare);
    });

    it("should allow the treasury to claim protocol fees", async () => {
      // Buy the song once to generate protocol fees
      await carbonOpus.connect(controller).purchaseMusic(
        buyerMemberId,
        buyer.address,
        tokenId,
        referrerMemberId
      );

      const protocolFee = (songPrice.mul(100)) / 10000;
      expect(await carbonOpusVault.rewards(treasuryId)).to.equal(protocolFee);

      // Treasury claims successfully
      const oldBalance = await usdcToken.balanceOf(carbonTreasury.address);
      await carbonTreasury.connect(deployer).claimRewards(carbonOpusVault.address);
      expect((await usdcToken.balanceOf(carbonTreasury.address)).sub(oldBalance)).to.equal(protocolFee);
    });
  });
});
