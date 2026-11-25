import { ethers, deployments, getNamedAccounts } from 'hardhat';
import { expect } from 'chai';
import { Contract, Signer } from 'ethers';
import { findNearestValidTick } from '../js-helpers/utils';

describe('PhoenixEggs', () => {
  let deployer: Signer;
  let user1: Signer;
  let user2: Signer;
  let user3: Signer;
  let user4: Signer;
  let treasury: Signer;
  let referrer: Signer;

  let phoenixEggs: Contract;
  let phoenixNft: Contract;
  let phoenixToken: Contract;
  let usdcToken: Contract;
  let phoenixDex: Contract;

  const signPhoenixBurn = async (signer: Signer, tokenId: number, deadline: number, domain: any) => {
    const types = {
      PhoenixSig: [
        { name: 'tokenId', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
      ],
    };
    const value = {
      tokenId: tokenId,
      deadline: deadline,
    };
    const signature = await (signer as any)._signTypedData(domain, types, value);
    return ethers.utils.splitSignature(signature);
  };

  const setupFixture = deployments.createFixture(async ({ deployments, getNamedAccounts, ethers }, options) => {
    const { deployer: deployerAddress, treasury: treasuryAddress, user1, user2, user3, user4, referrer } = await getNamedAccounts();
    const accounts = await ethers.getSigners();
    const deployer = accounts.find(a => a.address === deployerAddress);
    
    // Deploy Mock USDC
    const usdcDeployment = await deployments.deploy('ERC20Mintable', {
      from: deployerAddress,
      args: ['USDC Token', 'USDC'],
    });
    const usdcToken = await ethers.getContractAt('ERC20Mintable', usdcDeployment.address);

    // Deploy PhoenixNFT
    const phoenixNftDeployment = await deployments.deploy('PhoenixNFT_v1', {
      from: deployerAddress,
    });
    const phoenixNft = await ethers.getContractAt('PhoenixNFT_v1', phoenixNftDeployment.address);

    // Deploy PhoenixToken
    const phoenixTokenDeployment = await deployments.deploy('PhoenixToken', {
      from: deployerAddress,
    });
    const phoenixToken = await ethers.getContractAt('PhoenixToken', phoenixTokenDeployment.address);

    const tickLower = BigInt(findNearestValidTick(60, true));
    const tickUpper = BigInt(findNearestValidTick(60, false));

    // Deploy PhoenixDex
    const phoenixDexDeployment = await deployments.deploy('PhoenixDex', {
        from: deployerAddress,
        args: [
            usdcToken.address,
            (await ethers.getContract('MockNonfungiblePositionManager')).address, // Assuming a mock router is available
            tickLower.toString(),
            tickUpper.toString(),
        ],
    });
    const phoenixDex = await ethers.getContractAt('PhoenixDex', phoenixDexDeployment.address);
    
    // Deploy PhoenixEggs
    const phoenixEggsDeployment = await deployments.deploy('PhoenixEggs', {
      from: deployerAddress,
    });
    const phoenixEggs = await ethers.getContractAt('PhoenixEggs', phoenixEggsDeployment.address);

    // Configure PhoenixEggs
    await phoenixEggs.connect(deployer).setPhoenixNFT(phoenixNft.address);
    await phoenixEggs.connect(deployer).setPhoenixToken(phoenixToken.address);
    await phoenixEggs.connect(deployer).setUsdcToken(usdcToken.address);
    await phoenixEggs.connect(deployer).setPhoenixDex(phoenixDex.address);
    await phoenixEggs.connect(deployer).setPhoenixTreasury(treasuryAddress);
    await phoenixEggs.connect(deployer).setMaxNfts(100);
    await phoenixEggs.connect(deployer).setMaxTeamEggs(10);
    
    // Configure other contracts
    await phoenixToken.connect(deployer).setPhoenixEggs(phoenixEggs.address);
    await phoenixNft.connect(deployer).setLastPhoenix(phoenixEggs.address); // Eggs contract is the 'last' phoenix for minting

    // Fund users with USDC
    await usdcToken.connect(deployer).mint(user1, ethers.utils.parseUnits('1000', 6));
    await usdcToken.connect(deployer).mint(user2, ethers.utils.parseUnits('1000', 6));
    await usdcToken.connect(deployer).mint(user3, ethers.utils.parseUnits('1000', 6));
    await usdcToken.connect(deployer).mint(user4, ethers.utils.parseUnits('1000', 6));

    return {
        phoenixEggs,
        phoenixNft,
        phoenixToken,
        usdcToken,
        phoenixDex
    };
  });

  beforeEach(async () => {
    const { deployer: deployerAddress, user1: user1Address, user2: user2Address, user3: user3Address, user4: user4Address, treasury: treasuryAddress, referrer: referrerAddress } = await getNamedAccounts();
    const accounts = await ethers.getSigners();
    deployer = accounts.find(a => a.address === deployerAddress)!;
    user1 = accounts.find(a => a.address === user1Address)!;
    user2 = accounts.find(a => a.address === user2Address)!;
    user3 = accounts.find(a => a.address === user3Address)!;
    user4 = accounts.find(a => a.address === user4Address)!;
    treasury = accounts.find(a => a.address === treasuryAddress)!;
    referrer = accounts.find(a => a.address === referrerAddress)!;

    const contracts = await setupFixture();
    phoenixEggs = contracts.phoenixEggs;
    phoenixNft = contracts.phoenixNft;
    phoenixToken = contracts.phoenixToken;
    usdcToken = contracts.usdcToken;
    phoenixDex = contracts.phoenixDex;
  });

  describe('Core Functionality', () => {
    it('Should be owned by the deployer', async () => {
        expect(await phoenixEggs.owner()).to.equal(await deployer.getAddress());
    });

    it('Initial PHX supply should be 0', async () => {
        expect(await phoenixEggs.phxTotalSupply()).to.equal(0);
    });
  });

  describe('burn()', () => {
    let signers: Signer[];
    let domain: any;

    beforeEach(async () => {
      signers = [user2, user3, user4];
      // Create some initial Phoenix NFTs for the signers
      await phoenixEggs.connect(deployer).teamBurn(await user2.getAddress());
      await phoenixEggs.connect(deployer).teamBurn(await user3.getAddress());
      await phoenixEggs.connect(deployer).teamBurn(await user4.getAddress());
      expect(await phoenixNft.balanceOf(await user2.getAddress())).to.equal(1);

      domain = {
        name: 'PhoenixEggs',
        version: '1',
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: phoenixEggs.address,
      };
    });

    it('should successfully burn an egg with valid signatures', async () => {
      const user1Address = await user1.getAddress();
      const referrerAddress = await referrer.getAddress();
      const tokenId = await phoenixEggs.tokenOf(user1Address);
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

      const sig1 = await signPhoenixBurn(signers[0], tokenId, deadline, domain);
      const sig2 = await signPhoenixBurn(signers[1], tokenId, deadline, domain);
      const sig3 = await signPhoenixBurn(signers[2], tokenId, deadline, domain);
      
      const burnPrice = await phoenixEggs.getBurnPrice();
      await usdcToken.connect(user1).approve(phoenixEggs.address, burnPrice);

      const initialPhxTotalSupply = await phoenixEggs.phxTotalSupply();
      const phxPerBurn = await phoenixEggs.PHX_PER_BURN();
      const phxPerVote = await phoenixEggs.PHX_PER_VOTE();
      const phxPerReferral = await phoenixEggs.PHX_PER_REFERRAL();

      await expect(phoenixEggs.connect(user1).burn(referrerAddress, deadline, sig1, sig2, sig3))
        .to.emit(phoenixEggs, 'PhoenixBurned');
      
      // Check balances
      expect(await phoenixEggs.balanceOf(user1Address)).to.equal(0); // Egg is gone
      expect(await phoenixNft.balanceOf(user1Address)).to.equal(1); // New Phoenix NFT is minted
      
      // Check rewards
      const expectedSupply = initialPhxTotalSupply.add(ethers.utils.parseEther(
          (phxPerBurn.add(phxPerVote.mul(3)).add(phxPerReferral)).toString()
      ));
      expect(await phoenixEggs.phxTotalSupply()).to.equal(expectedSupply);
      
      expect(await phoenixEggs.phxBalanceOf(user1Address)).to.equal(ethers.utils.parseEther(phxPerBurn.toString()));
      expect(await phoenixEggs.phxBalanceOf(await signers[0].getAddress())).to.equal(ethers.utils.parseEther(phxPerVote.toString()).mul(2)); // 1 from teamBurn + 1 from vote
      expect(await phoenixEggs.phxBalanceOf(referrerAddress)).to.equal(ethers.utils.parseEther(phxPerReferral.toString()));
    });

    it('should revert with duplicate signers', async () => {
        const user1Address = await user1.getAddress();
        const tokenId = await phoenixEggs.tokenOf(user1Address);
        const deadline = Math.floor(Date.now() / 1000) + 3600;

        const sig1 = await signPhoenixBurn(signers[0], tokenId, deadline, domain);
        const sig2 = await signPhoenixBurn(signers[1], tokenId, deadline, domain);

        const burnPrice = await phoenixEggs.getBurnPrice();
        await usdcToken.connect(user1).approve(phoenixEggs.address, burnPrice);

        await expect(phoenixEggs.connect(user1).burn(
            await referrer.getAddress(), deadline, sig1, sig2, sig1 // Duplicate sig1
        )).to.be.revertedWithCustomError(phoenixEggs, "DuplicateSigners");
    });

    it('should revert if a signer is not a Phoenix holder', async () => {
        const user1Address = await user1.getAddress();
        const tokenId = await phoenixEggs.tokenOf(user1Address);
        const deadline = Math.floor(Date.now() / 1000) + 3600;

        // user1 is not a Phoenix holder yet
        const sig1 = await signPhoenixBurn(user1, tokenId, deadline, domain);
        const sig2 = await signPhoenixBurn(signers[1], tokenId, deadline, domain);
        const sig3 = await signPhoenixBurn(signers[2], tokenId, deadline, domain);

        await expect(phoenixEggs.connect(user1).burn(
            await referrer.getAddress(), deadline, sig1, sig2, sig3
        )).to.be.revertedWithCustomError(phoenixEggs, "SignerNotPhoenix");
    });
  });

  describe('createLiquidity()', () => {
    beforeEach(async () => {
        // Have some users burn eggs to accumulate USDC
        const burnPrice = await phoenixEggs.getBurnPrice();
        await usdcToken.connect(user1).approve(phoenixEggs.address, burnPrice.mul(2));
        await phoenixEggs.connect(deployer).teamBurn(await user2.getAddress());
        await phoenixEggs.connect(deployer).teamBurn(await user3.getAddress());
        await phoenixEggs.connect(deployer).teamBurn(await user4.getAddress());

        const domain = {
            name: 'PhoenixEggs', version: '1', chainId: (await ethers.provider.getNetwork()).chainId, verifyingContract: phoenixEggs.address
        };
        const deadline = Math.floor(Date.now() / 1000) + 3600;
        const tokenId = await phoenixEggs.tokenOf(await user1.getAddress());
        const sigs = await Promise.all([user2, user3, user4].map(s => signPhoenixBurn(s, tokenId, deadline, domain)));
        
        await phoenixEggs.connect(user1).burn(ethers.constants.AddressZero, deadline, sigs[0], sigs[1], sigs[2]);
    });

    it('should only be callable by the owner', async () => {
        await expect(phoenixEggs.connect(user1).createLiquidity()).to.be.revertedWithCustomError(phoenixEggs, 'OwnableUnauthorizedAccount');
    });

    it('should correctly create liquidity and distribute funds', async () => {
        const initialContractUsdc = await usdcToken.balanceOf(phoenixEggs.address);
        const poolUsdcBp = await phoenixEggs.POOL_USDC_BP();
        const reserveUsdcBp = await phoenixEggs.RESERVE_USDC_BP();
        const basisPoints = await phoenixEggs.BASIS_POINTS();

        const expectedPoolUsdc = initialContractUsdc.mul(poolUsdcBp).div(basisPoints);
        const expectedTreasuryUsdc = initialContractUsdc.mul(basisPoints.sub(poolUsdcBp).sub(reserveUsdcBp)).div(basisPoints);
        const treasuryBalanceBefore = await usdcToken.balanceOf(await treasury.getAddress());

        const mockPositionManager = await ethers.getContract('MockNonfungiblePositionManager');
        await mockPositionManager.setMintRecipient(await deployer.getAddress());

        await expect(phoenixEggs.connect(deployer).createLiquidity()).to.emit(phoenixEggs, 'LiquidityCreated');

        expect(await usdcToken.balanceOf(await treasury.getAddress())).to.equal(treasuryBalanceBefore.add(expectedTreasuryUsdc));
        expect(await phoenixEggs.getLiquidityCreationTimestamp()).to.be.gt(0);
        
        // Check if PHX was minted and sent to DEX
        const accumulatedPHX = await phoenixEggs.phxTotalSupply();
        expect(await phoenixToken.balanceOf(phoenixDex.address)).to.equal(0); // Should be transferred inside deployLiquidity
        expect(await usdcToken.balanceOf(phoenixDex.address)).to.equal(0);
    });

    it('should revert if called twice', async () => {
        const mockPositionManager = await ethers.getContract('MockNonfungiblePositionManager');
        await mockPositionManager.setMintRecipient(await deployer.getAddress());
        await phoenixEggs.connect(deployer).createLiquidity();
        await expect(phoenixEggs.connect(deployer).createLiquidity()).to.be.revertedWithCustomError(phoenixEggs, "LiquidityAlreadyCreated");
    });
  });

  describe('claimPhx()', () => {
    it('should revert if liquidity is not created yet', async () => {
        await expect(phoenixEggs.connect(user1).claimPhx()).to.be.revertedWithCustomError(phoenixEggs, "LiquidityNotCreated");
    });

    context('after liquidity creation', () => {
        let user1Address: string;

        beforeEach(async () => {
            user1Address = await user1.getAddress();
            // Have some users burn eggs to accumulate USDC
            const burnPrice = await phoenixEggs.getBurnPrice();
            await usdcToken.connect(user1).approve(phoenixEggs.address, burnPrice.mul(2));
            await phoenixEggs.connect(deployer).teamBurn(await user2.getAddress());
            await phoenixEggs.connect(deployer).teamBurn(await user3.getAddress());
            await phoenixEggs.connect(deployer).teamBurn(await user4.getAddress());

            const domain = {
                name: 'PhoenixEggs', version: '1', chainId: (await ethers.provider.getNetwork()).chainId, verifyingContract: phoenixEggs.address
            };
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            const tokenId = await phoenixEggs.tokenOf(await user1.getAddress());
            const sigs = await Promise.all([user2, user3, user4].map(s => signPhoenixBurn(s, tokenId, deadline, domain)));
            
            await phoenixEggs.connect(user1).burn(ethers.constants.AddressZero, deadline, sigs[0], sigs[1], sigs[2]);

            // Set the recipient for the mock position manager
            const mockPositionManager = await ethers.getContract('MockNonfungiblePositionManager');
            await mockPositionManager.setMintRecipient(await deployer.getAddress());
            // Create liquidity
            await phoenixEggs.connect(deployer).createLiquidity();
        });

        it('should allow a user to claim their earned PHX', async () => {
            const earnings = await phoenixEggs.phxBalanceOf(user1Address);
            expect(earnings).to.be.gt(0);

            const initialPhxBalance = await phoenixToken.balanceOf(user1Address);
            await expect(phoenixEggs.connect(user1).claimPhx()).to.emit(phoenixEggs, 'PhxClaimed');

            expect(await phoenixToken.balanceOf(user1Address)).to.equal(initialPhxBalance.add(earnings));
            expect(await phoenixEggs.phxBalanceOf(user1Address)).to.equal(0);
        });

        it('should revert if user has no PHX to claim', async () => {
            // User1 already claimed
            await phoenixEggs.connect(user1).claimPhx();
            await expect(phoenixEggs.connect(user1).claimPhx()).to.be.revertedWithCustomError(phoenixEggs, "NoPhxToClaim");
        });
    });
  });
});
