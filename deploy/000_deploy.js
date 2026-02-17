const { run }= require('hardhat');
const { chainNameById, chainIdByName, isHardhat, log } = require('../js-helpers/utils');
const { verifyContract } = require('../js-helpers/verifyContract');
const globals = require('../js-helpers/globals');
const carbonCoinAbi = require('../abis/CarbonCoin.json');
const _ = require('lodash');

module.exports = async (hre) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const { deploy } = deployments;
  const { deployer, treasury, user1 } = await getNamedAccounts();
  const network = await hre.network;
  const chainId = chainIdByName(network.name);

  console.log(`Using chainId: ${chainId}, network name: ${network.name}`);

  const dexRouter = globals.addresses[chainId].router;
  const usdcAddress = globals.addresses[chainId].usdc;
  const nftUri = globals.opusNftUri[chainId];
  const useExistingConfigContract = isHardhat(network) ? '' : '0xdB03C48611C194a78361A6f56d145d014B5Bb213';
  const useExistingDexContract = isHardhat(network) ? '' : '0x96905Aa6671c108b226f963e640545A9F41F3603';
  const useExistingProtectionContract = isHardhat(network) ? '' : '0x99b1026bb4262d129bB3F836A5289c034CF90b8f';
  const useExistingLauncherContract = isHardhat(network) ? '' : '0x719bce16560F9314dB801eaB70A563eab9c15633';
  const useExistingOpusContract = isHardhat(network) ? '' : '0xAE5EDb64d9799B81BAB8D80994879Aaa876f297D';
  const useExistingPermitAndTransferContract = isHardhat(network) ? '' : '0x491DC6e249d0595993751DEED326e12B96Fa38dF';

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  log('Carbon Opus - Carbon Coin - Contract Deployment');
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

  log(`  Using Network: ${chainNameById(chainId)} (${network.name}:${chainId})`);
  log('  Using Accounts:');
  log('  - Deployer: ', deployer);
  log('  - Treasury: ', treasury);
  log('  - User1:    ', user1);
  log(' ');


  //////////////////////////////////////////////////////////////
  // TEMP VERIFY
  // const constructorArgs = [ nftUri, usdcAddress ];
  // const tmpContract = await ethers.getContractAt('CarbonOpus', useExistingOpusContract);
  // await verifyContract('CarbonOpus', tmpContract, constructorArgs);

  // const constructorArgs = [];
  // const tmpContract = await ethers.getContractAt('PermitAndTransfer', useExistingPermitAndTransferContract);
  // await verifyContract('PermitAndTransfer', tmpContract, constructorArgs);

  // const constructorArgs = [ useExistingConfigContract, dexRouter ];
  // const tmpContract = await ethers.getContractAt('CarbonCoinLauncher', useExistingLauncherContract);
  // await verifyContract('CarbonCoinLauncher', tmpContract, constructorArgs);

  // log(`  Setting Max Tokens per Creator in CarbonCoinLauncher: ${globals.maxTokensPerCreator}`);
  // const tmpContract = await ethers.getContractAt('CarbonCoinLauncher', useExistingLauncherContract);
  // await tmpContract.setMaxTokensPerCreator(globals.maxTokensPerCreator).then(tx => tx.wait());

  // return;
  //
  //////////////////////////////////////////////////////////////

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
  // Deploy CarbonCoinProtection
  if (useExistingProtectionContract.length === 0) {
    log('  Deploying CarbonCoinProtection...');
    const constructorArgs = [];
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
  // Deploy CarbonOpus
  if (useExistingOpusContract.length === 0) {
    log('  Deploying CarbonOpus...');
    const constructorArgs = [
      nftUri,
      usdcAddress
    ];
    await deploy('CarbonOpus', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
  }

  // Get Deployed CarbonOpus
  let carbonOpus;
  if (useExistingOpusContract.length === 0) {
    carbonOpus = await ethers.getContract('CarbonOpus');
  } else {
    carbonOpus = await ethers.getContractAt('CarbonOpus', useExistingOpusContract);
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Configure Newly Deployed CarbonCoinConfig
  if (useExistingConfigContract.length === 0 || useExistingDexContract.length === 0) {
    log(`  Setting CarbonCoinDex in CarbonCoinConfig: ${carbonCoinDex.address}`);
    await carbonCoinConfig.updateDexAddress(carbonCoinDex.address).then(tx => tx.wait());
  }

  // Configure Newly Deployed CarbonCoinLauncher
  if (useExistingLauncherContract.length === 0) {
    log(`  Setting Max Tokens per Creator in CarbonCoinLauncher: ${globals.maxTokensPerCreator}`);
    await carbonCoinLauncher.setMaxTokensPerCreator(globals.maxTokensPerCreator).then(tx => tx.wait());
  }

  // Configure Newly Deployed CarbonCoinProtection
  if (useExistingProtectionContract.length === 0) {
    log(`  Setting Config in CarbonCoinProtection: ${carbonCoinConfig.address}`);
    await carbonCoinProtection.updateConfig(carbonCoinConfig.address).then(tx => tx.wait());

    log(`  Setting Launcher in CarbonCoinProtection: ${carbonCoinLauncher.address}`);
    await carbonCoinProtection.updateLauncher(carbonCoinLauncher.address).then(tx => tx.wait());
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify PermitAndTransfer
  if (useExistingPermitAndTransferContract.length === 0) {
    log('  Verifying PermitAndTransfer...');
    if (!isHardhat(network)) {
      setTimeout(async () => {
        await verifyContract('PermitAndTransfer', await ethers.getContract('PermitAndTransfer'), constructorArgs);
      }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify CarbonCoinConfig
  if (useExistingConfigContract.length === 0) {
    log('  Verifying CarbonCoinConfig...');
    const constructorArgs = [];
    if (!isHardhat(network)) {
      setTimeout(async () => {
        await verifyContract('CarbonCoinConfig', await ethers.getContract('CarbonCoinConfig'), constructorArgs);
      }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify CarbonCoinDex
  if (useExistingDexContract.length === 0) {
    log('  Verifying CarbonCoinDex...');
    const constructorArgs = [
      usdcAddress,
      dexRouter,
      carbonCoinConfig.address,
    ];
    if (!isHardhat(network)) {
      setTimeout(async () => {
        await verifyContract('CarbonCoinDex', await ethers.getContract('CarbonCoinDex'), constructorArgs);
      }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify CarbonCoinProtection
  if (useExistingProtectionContract.length === 0) {
    log('  Verifying CarbonCoinProtection...');
    const constructorArgs = [
      carbonCoinConfig.address,
    ];
    if (!isHardhat(network)) {
      setTimeout(async () => {
        await verifyContract('CarbonCoinProtection', await ethers.getContract('CarbonCoinProtection'), constructorArgs);
      }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify CarbonCoinLauncher
  if (useExistingLauncherContract.length === 0) {
    log('  Verifying CarbonCoinLauncher...');
    const constructorArgs = [
      carbonCoinConfig.address,
      usdcAddress,
      carbonCoinProtection.address,
    ];
    if (!isHardhat(network)) {
      setTimeout(async () => {
        await verifyContract('CarbonCoinLauncher', await ethers.getContract('CarbonCoinLauncher'), constructorArgs);
      }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify CarbonOpus
  if (useExistingOpusContract.length === 0) {
    log('  Verifying CarbonOpus...');
    const constructorArgs = [
      nftUri,
      usdcAddress
    ];
    if (!isHardhat(network)) {
      setTimeout(async () => {
        await verifyContract('CarbonOpus', await ethers.getContract('CarbonOpus'), constructorArgs);
      }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy a test CarbonCoin on Hardhat
  if (isHardhat(network)) {
    log('  Deploying a test CarbonCoin...');
    const bondingCurveParams = {
      virtualUsdc: ethers.utils.parseUnits('5000', 6),         // 5,000 USDC
      virtualTokens: ethers.utils.parseEther('6000000'),       // 6M tokens
      creatorReserve: ethers.utils.parseEther('1000000'),      // 1M tokens (10%)
      liquiditySupply: ethers.utils.parseEther('4500000'),     // 4.5M tokens (45% - goes to liquidity)
      curveSupply: ethers.utils.parseEther('4500000'),         // 4.5M tokens (45% - initial curve supply, determines initial price and price sensitivity)
      maxSupply: ethers.utils.parseEther('10000000'),          // 10M tokens (max supply including creator reserve)
      graduationThreshold: ethers.utils.parseUnits('15000', 6) // 15,000 USDC
    };
    // console.log({ bondingCurveParams });

    let newCarbonCoinAddress;
    await carbonCoinLauncher.createToken(
      'Carbon Coin',
      'CCC',
      user1,
      bondingCurveParams,
      // { value: globals.tokenCreationFee }
    ).then(tx => tx.wait())
    .then(async (receipt) => {
      const event = receipt.events.find(e => e.event === 'TokenCreated');
      newCarbonCoinAddress = event.args.tokenAddress;
      log(`  Test CarbonCoin deployed at: ${newCarbonCoinAddress}`);
    });

    // const constructorArgs = [
    //   'Carbon Creator Coin',
    //   'CCC',
    //   deployer,
    //   dexRouter,
    //   useExistingConfigContract,
    //   bondingCurveParams,
    // ];
    // await deploy('CarbonCoin', {
    //   from: deployer,
    //   args: constructorArgs,
    //   log: true,
    // });


    // // const newCarbonCoinAddress = await carbonCoinLauncher.tokensByCreator(deployer, 0);
    // log(`  Test CarbonCoin deployed at: ${newCarbonCoinAddress}`);

    // if (!isHardhat(network)) {
    //   setTimeout(async () => {
    //     const newCarbonCoin = await ethers.getContract('CarbonCoin');
    //     await verifyContract('CarbonCoin', newCarbonCoin, constructorArgs);
    //   }, 1000);
    // }
  }
};

// module.exports.dependencies = ['ERC20Mintable', 'ERC721Mintable'];
module.exports.tags = ['CarbonCoinLauncher']
