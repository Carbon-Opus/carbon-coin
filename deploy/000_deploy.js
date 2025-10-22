const { chainNameById, chainIdByName, isHardhat, log } = require('../js-helpers/utils');
const { verifyContract } = require('../js-helpers/verifyContract');
const globals = require('../js-helpers/globals');
const _ = require('lodash');

module.exports = async (hre) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const { deploy } = deployments;
  const { deployer, treasury, user1 } = await getNamedAccounts();
  const network = await hre.network;
  const chainId = chainIdByName(network.name);

  console.log(`Using chainId: ${chainId}, network name: ${network.name}`);

  const dexRouter = globals.addresses[chainId].router;
  const useExistingConfigContract = isHardhat(network) ? '' : '0x29BAf302f9FB7cB9fE4cB04CEFE17a1faF2d9E7E';
  const useExistingLauncherContract = isHardhat(network) ? '' : '0x538203da70651B577135a27479ceDc0A26F32539';
  const useExistingOpusContract = isHardhat(network) ? '' : '0xa0E550754C283B2c0943DeD4cBf23098740Bc1d0';

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
  // const constructorArgs = ['https://api.carbonopus.com/metadata/{id}.json'];
  // const tmpContract = await ethers.getContractAt('CarbonOpus', useExistingOpusContract);
  // await verifyContract('CarbonOpus', tmpContract, constructorArgs);
  // return;
  //
  //////////////////////////////////////////////////////////////


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

  // Deploy & Verify CarbonCoinLauncher
  if (useExistingLauncherContract.length === 0) {
    log('  Deploying CarbonCoinLauncher...');
    const constructorArgs = [
      carbonCoinConfig.address,
      dexRouter,
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

  // Deploy & Verify CarbonOpus
  if (useExistingOpusContract.length === 0) {
    log('  Deploying CarbonOpus...');
    const constructorArgs = [
      'https://api.carbonopus.com/metadata/{id}.json',
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

  // Configure Newly Deployed CarbonCoinLauncher
  if (useExistingLauncherContract.length === 0) {
    log(`  Setting Token Creation Fee Fee in CarbonCoinLauncher: ${globals.tokenCreationFee}`);
    await carbonCoinLauncher.setCreationFee(globals.tokenCreationFee).then(tx => tx.wait());

    log(`  Setting Max Tokens per Creator in CarbonCoinLauncher: ${globals.tokenCreationFee}`);
    await carbonCoinLauncher.setMaxTokensPerCreator(globals.maxTokensPerCreator).then(tx => tx.wait());
  }

  // Deploy a test CarbonCoin on Hardhat
  // if (isHardhat(network)) {
  //   log('  Deploying a test CarbonCoin on Hardhat...');
  //   const bondingCurveParams = {
  //     virtualEth: ethers.utils.parseEther('30'),
  //     virtualTokens: ethers.utils.parseEther('1073000000'),
  //     maxSupply: ethers.utils.parseEther('1000000000'),
  //     graduationThreshold: ethers.utils.parseEther('85'),
  //   };

  //   await carbonCoinLauncher.createToken(
  //     'Test Carbon Coin',
  //     'TCC',
  //     bondingCurveParams,
  //     { value: globals.tokenCreationFee }
  //   ).then(tx => tx.wait());

  //   const tokenAddress = await carbonCoinLauncher.tokensByCreator(deployer, 0);
  //   log(`  Test CarbonCoin deployed at: ${tokenAddress}`);
  // }
};

// module.exports.dependencies = ['ERC20Mintable', 'ERC721Mintable'];
module.exports.tags = ['CarbonCoinLauncher']
