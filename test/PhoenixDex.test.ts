import { ethers, deployments, getNamedAccounts } from 'hardhat';
import { expect } from 'chai';
import { Contract, Signer } from 'ethers';
import { findNearestValidTick } from '../js-helpers/utils';

describe('PhoenixDex', () => {
  let deployer: Signer;
  let user1: Signer;
  let treasury: Signer;

  let phoenixDex: Contract;
  let usdcToken: Contract;
  let testToken: Contract;
  let mockNftPositionManager: Contract;

  const setupFixture = deployments.createFixture(async ({ deployments, getNamedAccounts, ethers }, options) => {
    const { deployer: deployerAddress, treasury: treasuryAddress, user1: user1Address } = await getNamedAccounts();
    const accounts = await ethers.getSigners();
    deployer = accounts.find(a => a.address === deployerAddress)!;
    user1 = accounts.find(a => a.address === user1Address)!;
    treasury = accounts.find(a => a.address === treasuryAddress)!;

    // Deploy Mock Tokens
    const usdcDeployment = await deployments.deploy('ERC20Mintable', { from: deployerAddress, args: ['USDC', 'USDC'] });
    usdcToken = await ethers.getContractAt('ERC20Mintable', usdcDeployment.address);

    const testTokenDeployment = await deployments.deploy('ERC20Mintable', { from: deployerAddress, args: ['Test Token', 'TEST'] });
    testToken = await ethers.getContractAt('ERC20Mintable', testTokenDeployment.address);

    // Deploy Mock NFT Position Manager
    const mockNftPositionManagerDeployment = await deployments.deploy('MockNonfungiblePositionManager', { from: deployerAddress });
    mockNftPositionManager = await ethers.getContractAt('MockNonfungiblePositionManager', mockNftPositionManagerDeployment.address);
    
    const tickLower = BigInt(findNearestValidTick(60, true));
    const tickUpper = BigInt(findNearestValidTick(60, false));

    // Deploy PhoenixDex
    const phoenixDexDeployment = await deployments.deploy('PhoenixDex', {
      from: deployerAddress,
      args: [usdcToken.address, mockNftPositionManager.address, tickLower.toString(), tickUpper.toString()],
    });
    phoenixDex = await ethers.getContractAt('PhoenixDex', phoenixDexDeployment.address);

    // Fund user1 with tokens
    await usdcToken.connect(deployer).mint(user1Address, ethers.utils.parseUnits('10000', 6));
    await testToken.connect(deployer).mint(user1Address, ethers.utils.parseEther('10000'));

    return {
      phoenixDex,
      usdcToken,
      testToken,
      mockNftPositionManager
    };
  });

  beforeEach(async () => {
    await setupFixture();
  });

  describe('Deployment and Configuration', () => {
    it('Should set the correct owner', async () => {
      expect(await phoenixDex.owner()).to.equal(await deployer.getAddress());
    });

    it('Should set the correct initial values', async () => {
      expect(await phoenixDex.USDC()).to.equal(usdcToken.address);
      expect(await phoenixDex.dexRouter()).to.equal(mockNftPositionManager.address);
      expect(await phoenixDex.poolFee()).to.equal(100);
    });

    it('Should allow owner to update the router', async () => {
      const newRouter = '0x0000000000000000000000000000000000000001';
      await expect(phoenixDex.connect(deployer).updateRouter(newRouter))
        .to.emit(phoenixDex, 'RouterUpdated').withArgs(newRouter, (await ethers.provider.getBlock('latest')).timestamp);
      expect(await phoenixDex.dexRouter()).to.equal(newRouter);
    });

    it('Should prevent non-owner from updating the router', async () => {
      const newRouter = '0x0000000000000000000000000000000000000001';
      await expect(phoenixDex.connect(user1).updateRouter(newRouter)).to.be.revertedWithCustomError(phoenixDex, 'OwnableUnauthorizedAccount');
    });

    it('Should allow owner to update the pool fee', async () => {
      const newFee = 500;
      await expect(phoenixDex.connect(deployer).updatePoolFee(newFee))
        .to.emit(phoenixDex, 'PoolFeeUpdated').withArgs(newFee, (await ethers.provider.getBlock('latest')).timestamp);
      expect(await phoenixDex.poolFee()).to.equal(newFee);
    });

    it('Should prevent non-owner from updating the pool fee', async () => {
      const newFee = 500;
      await expect(phoenixDex.connect(user1).updatePoolFee(newFee)).to.be.revertedWithCustomError(phoenixDex, 'OwnableUnauthorizedAccount');
    });

    it('Should allow owner to pause and unpause', async () => {
        await expect(phoenixDex.connect(deployer).pause()).to.emit(phoenixDex, 'DexPaused');
        expect(await phoenixDex.paused()).to.be.true;
    
        await expect(phoenixDex.connect(deployer).unpause()).to.emit(phoenixDex, 'DexUnpaused');
        expect(await phoenixDex.paused()).to.be.false;
    });
    
    it('Should prevent non-owner from pausing', async () => {
        await expect(phoenixDex.connect(user1).pause()).to.be.revertedWithCustomError(phoenixDex, 'OwnableUnauthorizedAccount');
    });
  });

  describe('deployLiquidity()', () => {
    const usdcAmount = ethers.utils.parseUnits('1000', 6);
    const tokenAmount = ethers.utils.parseEther('100');
    let user1Address: string;

    beforeEach(async () => {
        user1Address = await user1.getAddress();
        await usdcToken.connect(user1).approve(phoenixDex.address, usdcAmount);
        await testToken.connect(user1).approve(phoenixDex.address, tokenAmount);
    });

    it('should successfully deploy liquidity and emit an event', async () => {
        await mockNftPositionManager.setMintRecipient(user1Address);
        await expect(phoenixDex.connect(user1).deployLiquidity(user1Address, testToken.address, tokenAmount, usdcAmount))
            .to.emit(phoenixDex, 'LiquidityDeployed');
        
        // Check if tokens were transferred from user
        expect(await usdcToken.balanceOf(user1Address)).to.equal(ethers.utils.parseUnits('9000', 6));
        expect(await testToken.balanceOf(user1Address)).to.equal(ethers.utils.parseEther('9900'));
    });

    it('should send the LP token to the recipient', async () => {
        const treasuryAddress = await treasury.getAddress();
        // Mock the mint function to check the recipient
        await mockNftPositionManager.setMintRecipient(treasuryAddress);
        
        await phoenixDex.connect(user1).deployLiquidity(treasuryAddress, testToken.address, tokenAmount, usdcAmount);
        
        // The mock contract's last recipient should be our treasury
        expect(await mockNftPositionManager.lastRecipient()).to.equal(treasuryAddress);
    });

    it('should send LP token to owner if recipient is address(0)', async () => {
        const ownerAddress = await deployer.getAddress();
        await mockNftPositionManager.setMintRecipient(ownerAddress);

        await phoenixDex.connect(user1).deployLiquidity(ethers.constants.AddressZero, testToken.address, tokenAmount, usdcAmount);
        
        expect(await mockNftPositionManager.lastRecipient()).to.equal(ownerAddress);
    });

    it('should revert if paused', async () => {
        await phoenixDex.connect(deployer).pause();
        await expect(phoenixDex.connect(user1).deployLiquidity(user1Address, testToken.address, tokenAmount, usdcAmount))
            .to.be.revertedWithCustomError(phoenixDex, 'EnforcedPause');
    });

    it('should revert if token is USDC', async () => {
        await expect(phoenixDex.connect(user1).deployLiquidity(user1Address, usdcToken.address, tokenAmount, usdcAmount))
            .to.be.revertedWith('Token cannot be USDC');
    });

    it('should revert if token is not a contract', async () => {
        await expect(phoenixDex.connect(user1).deployLiquidity(user1Address, user1Address, tokenAmount, usdcAmount))
            .to.be.revertedWith('Token must be a contract');
    });
  });
});
