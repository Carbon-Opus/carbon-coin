import { ethers } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { CarbonOpus, ERC20Mintable } from "../typechain-types";

describe("CarbonOpus - Song Locking, Reward Locking, and Reassignment", () => {
  let carbonOpus: CarbonOpus;
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

  const uri = "https://api-plxgamnywq-uc.a.run.app/nft/{id}.json";
  const songPrice = ethers.utils.parseUnits("10", 6); // 10 USDC (6 decimals)
  const referralPct = 500; // 5% (500 basis points)

  beforeEach(async () => {
    [deployer, controller, artistA, artistB, buyer, referrer] = await ethers.getSigners();

    // 1. Deploy mock USDC token
    const ERC20MintableFactory = await ethers.getContractFactory("ERC20Mintable");
    usdcToken = (await ERC20MintableFactory.deploy("USDC Mock", "USDC")) as ERC20Mintable;
    await usdcToken.deployed();

    // 2. Deploy CarbonOpus
    const CarbonOpusFactory = await ethers.getContractFactory("CarbonOpus");
    carbonOpus = (await CarbonOpusFactory.deploy(uri, usdcToken.address)) as CarbonOpus;
    await carbonOpus.deployed();

    // 3. Set the controller
    await carbonOpus.connect(deployer).updateController(controller.address);

    // 4. Mint some USDC to the controller (since they pay for standard purchases)
    const mintAmount = ethers.utils.parseUnits("1000", 6);
    await usdcToken.connect(deployer).mint(controller.address, mintAmount);

    // 5. Approve CarbonOpus to spend controller's USDC
    await usdcToken.connect(controller).approve(carbonOpus.address, mintAmount);
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

    it("should correctly track and accumulate rewards per song", async () => {
      // Buy the song once
      await carbonOpus.connect(controller).purchaseMusic(
        buyerMemberId,
        buyer.address,
        tokenId,
        referrerMemberId
      );

      // protocol fee = 1% (100 basis points) of 10 USDC = 0.1 USDC = 100,000 (with 6 decimals)
      // referral pct = 5% (500 basis points) of 10 USDC = 0.5 USDC = 500,000
      // artist share = 10 USDC - 0.1 USDC - 0.5 USDC = 9.4 USDC = 9,400,000
      expect(await carbonOpus.songRewards(tokenId)).to.equal(9400000);
      expect(await carbonOpus.getRewards(memberIdA)).to.equal(9400000);
    });

    it("should lock rewards of a song from being claimed when the song is locked", async () => {
      // Buy the song
      await carbonOpus.connect(controller).purchaseMusic(
        buyerMemberId,
        buyer.address,
        tokenId,
        referrerMemberId
      );

      // Create a second song and buy it too so artist has rewards from two songs
      await carbonOpus.connect(controller).createMusic(
        memberIdA,
        artistA.address,
        songPrice,
        referralPct
      );
      await carbonOpus.connect(controller).purchaseMusic(
        buyerMemberId,
        buyer.address,
        2,
        referrerMemberId
      );

      // Total rewards: 2 * 9.4 USDC = 18.8 USDC
      expect(await carbonOpus.getRewards(memberIdA)).to.equal(18800000);

      // Lock the first song
      await carbonOpus.connect(controller).updateSongLockStatus(1, true);

      // Now `getRewards` should only return the claimable amount from the unlocked song (9.4 USDC)
      expect(await carbonOpus.getRewards(memberIdA)).to.equal(9400000);

      // Claim rewards
      const oldBalance = await usdcToken.balanceOf(artistA.address);
      await carbonOpus.connect(controller).claimRewards(memberIdA, artistA.address);
      const newBalance = await usdcToken.balanceOf(artistA.address);

      // Artist should have only claimed 9.4 USDC
      expect(newBalance.sub(oldBalance)).to.equal(9400000);

      // The rewards for the locked song (1) should still be in songRewards[1]
      expect(await carbonOpus.songRewards(1)).to.equal(9400000);
      expect(await carbonOpus.songRewards(2)).to.equal(0);

      // Unlock the first song
      await carbonOpus.connect(controller).updateSongLockStatus(1, false);

      // Claim again
      await carbonOpus.connect(controller).claimRewards(memberIdA, artistA.address);
      expect((await usdcToken.balanceOf(artistA.address)).sub(oldBalance)).to.equal(18800000);
      expect(await carbonOpus.songRewards(1)).to.equal(0);
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

    it("should reattribute song, future rewards, and unclaimed rewards to new member", async () => {
      // Historical rewards are currently 9.4 USDC
      expect(await carbonOpus.songRewards(tokenId)).to.equal(9400000);

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

      // Artist A should have 0 claimable rewards
      expect(await carbonOpus.getRewards(memberIdA)).to.equal(0);

      // Artist B should now be able to claim the 9.4 USDC unclaimed historical rewards!
      expect(await carbonOpus.getRewards(memberIdB)).to.equal(9400000);

      // Purchase the song again
      await carbonOpus.connect(controller).purchaseMusic(
        buyerMemberId,
        buyer.address,
        tokenId,
        referrerMemberId
      );

      // Artist B should now have 18.8 USDC claimable rewards (9.4 historical + 9.4 new)
      expect(await carbonOpus.getRewards(memberIdB)).to.equal(18800000);

      // Check NFT balances
      // Artist A had 1 minted edition. It should be transferred to Artist B.
      expect(await carbonOpus.balanceOf(artistA.address, tokenId)).to.equal(0);
      expect(await carbonOpus.balanceOf(artistB.address, tokenId)).to.equal(1); // 1 transferred

      // Claim rewards for Artist B
      const oldBalance = await usdcToken.balanceOf(artistB.address);
      await carbonOpus.connect(controller).claimRewards(memberIdB, artistB.address);
      expect((await usdcToken.balanceOf(artistB.address)).sub(oldBalance)).to.equal(18800000);
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

    it("should allow referrers to claim rewards even if the associated song is locked", async () => {
      // Buy the song once to generate referral rewards for the referrer
      await carbonOpus.connect(controller).purchaseMusic(
        buyerMemberId,
        buyer.address,
        tokenId,
        referrerMemberId
      );

      // Referrer has 5% of 10 USDC = 0.5 USDC = 500,000
      expect(await carbonOpus.getRewards(referrerMemberId)).to.equal(500000);

      // Lock the song
      await carbonOpus.connect(controller).updateSongLockStatus(tokenId, true);

      // Artist rewards should be locked (getRewards = 0)
      expect(await carbonOpus.getRewards(memberIdA)).to.equal(0);

      // Referrer rewards should STILL be claimable (getRewards = 0.5 USDC)
      expect(await carbonOpus.getRewards(referrerMemberId)).to.equal(500000);

      // Referrer claims successfully
      const oldBalance = await usdcToken.balanceOf(referrer.address);
      await carbonOpus.connect(controller).claimRewards(referrerMemberId, referrer.address);
      expect((await usdcToken.balanceOf(referrer.address)).sub(oldBalance)).to.equal(500000);
    });

    it("should allow the treasury to claim protocol fees even if the associated song is locked", async () => {
      const treasuryId = ethers.utils.formatBytes32String("treasury");

      // Buy the song once to generate protocol fees
      await carbonOpus.connect(controller).purchaseMusic(
        buyerMemberId,
        buyer.address,
        tokenId,
        referrerMemberId
      );

      // Treasury has 1% of 10 USDC = 0.1 USDC = 100,000
      expect(await carbonOpus.getRewards(treasuryId)).to.equal(100000);

      // Lock the song
      await carbonOpus.connect(controller).updateSongLockStatus(tokenId, true);

      // Treasury should STILL be able to claim protocol fees
      const oldBalance = await usdcToken.balanceOf(deployer.address);
      await carbonOpus.connect(deployer).claimRewards(treasuryId, deployer.address);
      expect((await usdcToken.balanceOf(deployer.address)).sub(oldBalance)).to.equal(100000);
    });
  });
});
