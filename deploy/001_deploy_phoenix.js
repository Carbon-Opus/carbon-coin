const { chainNameById, chainIdByName, isHardhat, findNearestValidTick, log } = require('../js-helpers/utils');
const globals = require('../js-helpers/globals');

module.exports = async (hre) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const { deploy } = deployments;
  const { deployer, treasury } = await getNamedAccounts();
  const network = await hre.network;
  const chainId = chainIdByName(network.name);

  const dexRouter = globals.addresses[chainId].router;
  let usdcAddress = globals.addresses[chainId].usdc;

  const useExistingPhoenixDexContract = isHardhat(network) ? '' : '';
  const useExistingPhoenixEggsContract = isHardhat(network) ? '' : '';
  const useExistingPhoenixNFT_v1Contract = isHardhat(network) ? '' : '';
  const useExistingPhoenixTokenContract = isHardhat(network) ? '' : '';

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy PhoenixEggs
  if (useExistingPhoenixEggsContract.length === 0) {
    log('  Deploying PhoenixEggs...');
    const constructorArgs = [];
    await deploy('PhoenixEggs', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
  }

  // Get Deployed PhoenixEggs
  let phoenixEggs;
  if (useExistingPhoenixEggsContract.length === 0) {
    phoenixEggs = await ethers.getContract('PhoenixEggs');
  } else {
    phoenixEggs = await ethers.getContractAt('PhoenixEggs', useExistingPhoenixEggsContract);
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy PhoenixToken
  if (useExistingPhoenixTokenContract.length === 0) {
    log('  Deploying PhoenixToken...');
    const constructorArgs = [];
    await deploy('PhoenixToken', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
  }

  // Get Deployed PhoenixToken
  let phoenixToken;
  if (useExistingPhoenixTokenContract.length === 0) {
    phoenixToken = await ethers.getContract('PhoenixToken');
  } else {
    phoenixToken = await ethers.getContractAt('PhoenixToken', useExistingPhoenixTokenContract);
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy PhoenixDex
  if (useExistingPhoenixDexContract.length === 0) {
    log('  Deploying PhoenixDex...');
    const constructorArgs = [
      usdcAddress,
      phoenixToken.address,
      phoenixEggs.address,
      dexRouter,
    ];
    await deploy('PhoenixDex', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
  }

  // Get Deployed PhoenixDex
  let phoenixDex;
  if (useExistingPhoenixDexContract.length === 0) {
    phoenixDex = await ethers.getContract('PhoenixDex');
  } else {
    phoenixDex = await ethers.getContractAt('PhoenixDex', useExistingPhoenixDexContract);
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Deploy PhoenixNFT_v1
  if (useExistingPhoenixNFT_v1Contract.length === 0) {
    log('  Deploying PhoenixNFT_v1...');
    const constructorArgs = [];
    await deploy('PhoenixNFT_v1', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
  }

  // Get Deployed PhoenixNFT_v1
  let phoenixNFT_v1;
  if (useExistingPhoenixNFT_v1Contract.length === 0) {
    phoenixNFT_v1 = await ethers.getContract('PhoenixNFT_v1');
  } else {
    phoenixNFT_v1 = await ethers.getContractAt('PhoenixNFT_v1', useExistingPhoenixNFT_v1Contract);
  }

  // Configure Newly Deployed PhoenixEggs
  if (useExistingPhoenixEggsContract.length === 0) {
    log(`  Setting Phoenix NFT in Phoenix Eggs: ${phoenixNFT_v1.address}`);
    await phoenixEggs.setPhoenixNFT(phoenixNFT_v1.address).then(tx => tx.wait());

    log(`  Setting Phoenix Token (PHX) in Phoenix Eggs: ${phoenixToken.address}`);
    await phoenixEggs.setPhoenixToken(phoenixToken.address).then(tx => tx.wait());

    log(`  Setting USDC Token in Phoenix Eggs: ${usdcAddress}`);
    await phoenixEggs.setUsdcToken(usdcAddress).then(tx => tx.wait());

    log(`  Setting Phoenix DEX in Phoenix Eggs: ${phoenixDex.address}`);
    await phoenixEggs.setPhoenixDex(phoenixDex.address).then(tx => tx.wait());

    log(`  Setting Phoenix Treasury in Phoenix Eggs: ${treasury}`);
    await phoenixEggs.setPhoenixTreasury(treasury).then(tx => tx.wait());

    log(`  Setting Max Phoenix NFTs in Phoenix Eggs: ${5000}`);
    await phoenixEggs.setMaxNfts(5000).then(tx => tx.wait());

    log(`  Setting Max Team-Eggs in Phoenix Eggs: ${12}`);
    await phoenixEggs.setMaxTeamEggs(12).then(tx => tx.wait());
  }

  // Configure Newly Deployed PhoenixToken
  if (useExistingPhoenixTokenContract.length === 0) {
    log(`  Setting Phoenix Eggs in Phoenix Token: ${phoenixEggs.address}`);
    await phoenixToken.setPhoenixEggs(phoenixEggs.address).then(tx => tx.wait());
  }
};

module.exports.tags = ['Phoenix']
