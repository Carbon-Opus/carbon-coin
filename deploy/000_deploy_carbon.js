const { chainNameById, chainIdByName, isHardhat, findNearestValidTick, log } = require('../js-helpers/utils');
const globals = require('../js-helpers/globals');

module.exports = async (hre) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const { deploy } = deployments;
  const { deployer, treasury, user1 } = await getNamedAccounts();
  const network = await hre.network;
  const chainId = chainIdByName(network.name);

  console.log(`Using chainId: ${chainId}, network name: ${network.name}`);

  const dexRouter = globals.addresses[chainId].router;
  let usdcAddress = globals.addresses[chainId].usdc;
  if (isHardhat(network)) {
    await deploy('ERC20Mintable', {
      from: deployer,
      args: ['USDC Clone', 'USDC'],
      log: false,
    });
    const mockUsdc = await ethers.getContract('ERC20Mintable');
    usdcAddress = mockUsdc.address;
    await mockUsdc.mint(deployer, ethers.utils.parseUnits('5000000', 6));
    await mockUsdc.mint(user1, ethers.utils.parseUnits('5000000', 6));
  }
  const nftUri = globals.opusNftUri[chainId];
  const tickLower = BigInt(findNearestValidTick(60, true));
  const tickUpper = BigInt(findNearestValidTick(60, false));

  // TESTNET
  const useExistingTreasuryContract = isHardhat(network) ? '' : '0xF7a1C1FD464A0b5DCbbc7AAeCa29D2dB1CC0E2F6';
  const useExistingVaultContract = isHardhat(network) ? '' : '0xd8e555d9cfc86371303CeDc1430A26021DCB7Aa3';
  const useExistingOpusContract = isHardhat(network) ? '' : '0x0f3636bcFDeD6AC3A19a7f63a4278def8E185680';
  const useExistingConfigContract = isHardhat(network) ? '' : '0xc10b0e5Fac8b202007871206136A1D6b5908F90e';
  const useExistingDexContract = isHardhat(network) ? '' : '0x048874304008415344c0E11B89E99EC293A944b5';
  const useExistingProtectionContract = isHardhat(network) ? '' : '0xda3B07BFeDE6FB91aB54C0D0988a468f11A70EbE';
  const useExistingLauncherContract = isHardhat(network) ? '' : '0x306E996ceDD05c33bee051e43fa386DBbB32d611';
  const useExistingPaymasterContract = isHardhat(network) ? '' : '0x0e6779fF55bAA6A7Ee144C9C4c4c3280Fe4d51C8';
  const useExistingCarbonCoinContract = isHardhat(network) ? '' : '';
  const useExistingPermitAndTransferContract = isHardhat(network) ? '' : '0x56EC1564F33Ad819B666982dAB840077E0F99581';

  const sampleCarbonCoinArgs = [
    'Carbon Coin',
    'CCC',
    user1,
    {
      virtualUsdc: ethers.utils.parseUnits('5000', 6),         // 5,000 USDC
      virtualTokens: ethers.utils.parseEther('6000000'),       // 6M tokens
      creatorReserve: ethers.utils.parseEther('1000000'),      // 1M tokens (10%)
      liquiditySupply: ethers.utils.parseEther('4500000'),     // 4.5M tokens (45% - goes to liquidity)
      curveSupply: ethers.utils.parseEther('4500000'),         // 4.5M tokens (45% - initial curve supply, determines initial price and price sensitivity)
      maxSupply: ethers.utils.parseEther('10000000'),          // 10M tokens (max supply including creator reserve)
      graduationThreshold: ethers.utils.parseUnits('15000', 6) // 15,000 USDC
    },
  ];

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  log('Carbon Opus - Carbon Coin - Contract Deployment');
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

  log(`  Using Network: ${chainNameById(chainId)} (${network.name}:${chainId})`);
  log('  Using Accounts:');
  log('  - Deployer: ', deployer);
  log('  - Treasury: ', treasury);
  log('  - User1:    ', user1);
  log(' ');

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy PermitAndTransfer
  if (useExistingPermitAndTransferContract.length === 0) {
    log('  Deploying PermitAndTransfer...');
    const constructorArgs = [];
    await deploy('PermitAndTransfer', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy CarbonTreasury
  if (useExistingTreasuryContract.length === 0) {
    log('  Deploying CarbonTreasury...');
    const constructorArgs = [ usdcAddress ];
    await deploy('CarbonTreasury', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
  }

  // Get Deployed CarbonTreasury
  let carbonTreasury;
  if (useExistingTreasuryContract.length === 0) {
    carbonTreasury = await ethers.getContract('CarbonTreasury');
  } else {
    carbonTreasury = await ethers.getContractAt('CarbonTreasury', useExistingTreasuryContract);
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy CarbonCoinConfig
  if (useExistingConfigContract.length === 0) {
    log('  Deploying CarbonCoinConfig...');
    const constructorArgs = [];
    await deploy('CarbonCoinConfig', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
  }

  // Get Deployed CarbonCoinConfig
  let carbonCoinConfig;
  if (useExistingConfigContract.length === 0) {
    carbonCoinConfig = await ethers.getContract('CarbonCoinConfig');
  } else {
    carbonCoinConfig = await ethers.getContractAt('CarbonCoinConfig', useExistingConfigContract);
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy CarbonCoinDex
  if (useExistingDexContract.length === 0) {
    log('  Deploying CarbonCoinDex...');
    const constructorArgs = [
      usdcAddress,
      dexRouter,
      carbonCoinConfig.address,
      tickLower.toString(),
      tickUpper.toString(),
    ];
    await deploy('CarbonCoinDex', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
  }

  // Get Deployed CarbonCoinDex
  let carbonCoinDex;
  if (useExistingDexContract.length === 0) {
    carbonCoinDex = await ethers.getContract('CarbonCoinDex');
  } else {
    carbonCoinDex = await ethers.getContractAt('CarbonCoinDex', useExistingDexContract);
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy CarbonCoinPaymaster
  if (useExistingPaymasterContract.length === 0) {
    log('  Deploying CarbonCoinPaymaster...');
    const constructorArgs = [
      usdcAddress,
    ];
    await deploy('CarbonCoinPaymaster', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
  }

  // Get Deployed CarbonCoinPaymaster
  let carbonCoinPaymaster;
  if (useExistingPaymasterContract.length === 0) {
    carbonCoinPaymaster = await ethers.getContract('CarbonCoinPaymaster');
  } else {
    carbonCoinPaymaster = await ethers.getContractAt('CarbonCoinPaymaster', useExistingPaymasterContract);
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy CarbonCoinProtection
  if (useExistingProtectionContract.length === 0) {
    log('  Deploying CarbonCoinProtection...');
    const constructorArgs = [
      deployer,
    ];
    await deploy('CarbonCoinProtection', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
  }

  // Get Deployed CarbonCoinProtection
  let carbonCoinProtection;
  if (useExistingProtectionContract.length === 0) {
    carbonCoinProtection = await ethers.getContract('CarbonCoinProtection');
  } else {
    carbonCoinProtection = await ethers.getContractAt('CarbonCoinProtection', useExistingProtectionContract);
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy CarbonCoinLauncher
  if (useExistingLauncherContract.length === 0) {
    log('  Deploying CarbonCoinLauncher...');
    const constructorArgs = [
      carbonCoinConfig.address,
      usdcAddress,
      carbonCoinProtection.address,
      carbonCoinPaymaster.address,
    ];
    await deploy('CarbonCoinLauncher', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
  }

  // Get Deployed CarbonCoinLauncher
  let carbonCoinLauncher;
  if (useExistingLauncherContract.length === 0) {
    carbonCoinLauncher = await ethers.getContract('CarbonCoinLauncher');
  } else {
    carbonCoinLauncher = await ethers.getContractAt('CarbonCoinLauncher', useExistingLauncherContract);
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy CarbonOpusVault
  let carbonOpusVault;
  if (useExistingVaultContract.length === 0) {
    log('  Deploying CarbonOpusVault...');
    const constructorArgs = [
      usdcAddress,
      carbonTreasury.address,
    ];
    const vaultDeploy = await deploy('CarbonOpusVault', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
    carbonOpusVault = { address: vaultDeploy.address };
  } else {
    carbonOpusVault = { address: useExistingVaultContract };
  }
  const carbonOpusVaultContract = await ethers.getContractAt('CarbonOpusVault', carbonOpusVault.address);

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy CarbonOpus
  let carbonOpus;
  if (useExistingOpusContract.length === 0) {
    log('  Deploying CarbonOpus...');
    const constructorArgs = [
      nftUri,
      usdcAddress,
      carbonTreasury.address,
      carbonOpusVault.address,
    ];
    const opusDeploy = await deploy('CarbonOpus', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
    carbonOpus = { address: opusDeploy.address };
  } else {
    carbonOpus = { address: useExistingOpusContract };
  }
  const carbonOpusContract = await ethers.getContractAt('CarbonOpus', carbonOpus.address);

  //
  //////////////////////////////////////////////////////////////
  //
  // Configure Newly Deployed CarbonCoinConfig
  if (useExistingConfigContract.length === 0 || useExistingDexContract.length === 0) {
    log(`  Setting CarbonCoinDex in CarbonCoinConfig: ${carbonCoinDex.address}`);
    await carbonCoinConfig.updateDexAddress(carbonCoinDex.address).then(tx => tx.wait());
  }

  if (useExistingConfigContract.length === 0 || useExistingTreasuryContract.length === 0) {
    log(`  Setting CarbonTreasury in CarbonCoinConfig: ${carbonTreasury.address}`);
    await carbonCoinConfig.updateTreasury(carbonTreasury.address).then(tx => tx.wait());
  }

  // Configure Newly Deployed CarbonCoinLauncher
  if (useExistingLauncherContract.length === 0) {
    log(`  Setting Max Tokens per Creator in CarbonCoinLauncher: ${globals.maxTokensPerCreator}`);
    await carbonCoinLauncher.setMaxTokensPerCreator(globals.maxTokensPerCreator).then(tx => tx.wait());
  }

  // Configure CarbonOpusVault with CarbonOpus address
  if (useExistingVaultContract.length === 0) {
    log('  Updating CarbonOpusVault with CarbonOpus address...');
    await carbonOpusVaultContract.updateCarbonOpus(carbonOpus.address);
  }

  // Configure Newly Deployed CarbonCoinProtection
  if (useExistingProtectionContract.length === 0 || useExistingLauncherContract.length === 0 || useExistingConfigContract.length === 0) {
    log(`  Setting Config in CarbonCoinProtection: ${carbonCoinConfig.address}`);
    await carbonCoinProtection.updateConfig(carbonCoinConfig.address).then(tx => tx.wait());

    log(`  Setting Launcher in CarbonCoinProtection: ${carbonCoinLauncher.address}`);
    await carbonCoinProtection.updateLauncher(carbonCoinLauncher.address).then(tx => tx.wait());
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy a test CarbonCoin on Hardhat
  if (isHardhat(network)) {
    log('  Deploying a test CarbonCoin...');
    let newCarbonCoinAddress;
    await carbonCoinLauncher.createToken(
      ...sampleCarbonCoinArgs,
      // { value: globals.tokenCreationFee }
    ).then(tx => tx.wait())
    .then(async (receipt) => {
      let event = receipt.events && receipt.events.find(e => e.event === 'TokenCreated');
      if (!event && receipt.logs) {
        for (const logItem of receipt.logs) {
          try {
            const parsed = carbonCoinLauncher.interface.parseLog(logItem);
            if (parsed.name === 'TokenCreated') {
              event = parsed;
              break;
            }
          } catch (e) {}
        }
      }
      if (event && event.args) {
        newCarbonCoinAddress = event.args.tokenAddress;
        log(`  Test CarbonCoin deployed at: ${newCarbonCoinAddress}`);
      }
    });
  }
};

module.exports.tags = ['Carbon']
