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
  const useExistingConfigContract = isHardhat(network) ? '' : '';
  const useExistingDexContract = isHardhat(network) ? '' : '';
  const useExistingLauncherContract = isHardhat(network) ? '' : '';
  const useExistingOpusContract = isHardhat(network) ? '' : '';
  const useExistingPermitAndTransferContract = isHardhat(network) ? '' : '';

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

  // log(`  Setting Max Tokens per Creator in CarbonCoinLauncher: 100`);
  // const tmpContract = await ethers.getContractAt('CarbonCoinLauncher', useExistingLauncherContract);
  // await tmpContract.setMaxTokensPerCreator(100).then(tx => tx.wait());

  // return;
  //
  //////////////////////////////////////////////////////////////

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy & Verify PermitAndTransfer
  if (useExistingPermitAndTransferContract.length === 0) {
    log('  Deploying PermitAndTransfer...');
    const constructorArgs = [];
    await deploy('PermitAndTransfer', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });

    if (!isHardhat(network)) {
      setTimeout(async () => {
        await verifyContract('PermitAndTransfer', await ethers.getContract('PermitAndTransfer'), constructorArgs);
      }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy & Verify CarbonCoinConfig
  if (useExistingConfigContract.length === 0) {
    log('  Deploying CarbonCoinConfig...');
    const constructorArgs = [];
    await deploy('CarbonCoinConfig', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });

    if (!isHardhat(network)) {
      setTimeout(async () => {
        await verifyContract('CarbonCoinConfig', await ethers.getContract('CarbonCoinConfig'), constructorArgs);
      }, 1000);
    }
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
  // Deploy & Verify CarbonCoinDex
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

    if (!isHardhat(network)) {
      setTimeout(async () => {
        await verifyContract('CarbonCoinDex', await ethers.getContract('CarbonCoinDex'), constructorArgs);
      }, 1000);
    }
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
  // Deploy & Verify CarbonCoinLauncher
  if (useExistingLauncherContract.length === 0) {
    log('  Deploying CarbonCoinLauncher...');
    const constructorArgs = [
      carbonCoinConfig.address,
      usdcAddress,
    ];
    await deploy('CarbonCoinLauncher', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });

    if (!isHardhat(network)) {
      setTimeout(async () => {
        await verifyContract('CarbonCoinLauncher', await ethers.getContract('CarbonCoinLauncher'), constructorArgs);
      }, 1000);
    }
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
  // Deploy & Verify CarbonOpus
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

    if (!isHardhat(network)) {
      setTimeout(async () => {
        await verifyContract('CarbonOpus', await ethers.getContract('CarbonOpus'), constructorArgs);
      }, 1000);
    }
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
    log(`  Setting Max Tokens per Creator in CarbonCoinLauncher: ${globals.tokenCreationFee}`);
    await carbonCoinLauncher.setMaxTokensPerCreator(globals.maxTokensPerCreator).then(tx => tx.wait());
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy a test CarbonCoin on Hardhat
  if (isHardhat(network)) {
    log('  Deploying a test CarbonCoin...');
    const bondingCurveParams = {
      virtualUsdc: ethers.utils.parseUnits('2000', 6),         // 2,000 USDC
      virtualTokens: ethers.utils.parseEther('6000000'),       // 6M tokens
      creatorReserve: ethers.utils.parseEther('1000000'),      // 1M tokens (10%)
      maxSupply: ethers.utils.parseEther('5000000'),           // 5M tokens (50%)
      graduationThreshold: ethers.utils.parseUnits('10000', 6) // 10,000 USDC
    };
    // console.log({ bondingCurveParams });

    let newCarbonCoinAddress;
    await carbonCoinLauncher.createToken(
      'Carbon Coin',
      'CCC',
      user1,
      bondingCurveParams,
      { value: globals.tokenCreationFee }
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
