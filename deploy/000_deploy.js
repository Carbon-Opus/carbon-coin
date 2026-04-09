const { chainNameById, chainIdByName, isHardhat, findNearestValidTick, log } = require('../js-helpers/utils');
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
  const usdcAddress = globals.addresses[chainId].usdc;
  const nftUri = globals.opusNftUri[chainId];
  const tickLower = BigInt(findNearestValidTick(60, true));
  const tickUpper = BigInt(findNearestValidTick(60, false));

  // SOMNIA TESTNET
  const useExistingOpusContract = isHardhat(network) ? '' : '0x383AdAe8837f6Ef807d59b6cd3FB9a914348e6b2';
  const useExistingConfigContract = isHardhat(network) ? '' : '0x3418FE1D6983BD939A4489AF9B69Dad08d937119';
  const useExistingDexContract = isHardhat(network) ? '' : '0xcDBD208D03b73451Ad44E16eAb82AFD5dd99936f';
  const useExistingProtectionContract = isHardhat(network) ? '' : '0x066DC275F91a2946C0eCCF7e024d44E3a776D140';
  const useExistingLauncherContract = isHardhat(network) ? '' : '0x65B9C4e18631e7f6331EC6c3813c082265fdEbd2';
  const useExistingPaymasterContract = isHardhat(network) ? '' : '0x7229dcC37da168Ca9b761Dc69e5e6E31211F1ba6';
  const useExistingCarbonCoinContract = isHardhat(network) ? '' : '0x73CAc5E7a6FedCFe0987C5daccf41Ea16c7Ea822';
  const useExistingPhoenixDexContract = isHardhat(network) ? '' : '0xE0e31277327F73B1a3D07Fbb486C514E9aaB4bE7';
  const useExistingPhoenixEggsContract = isHardhat(network) ? '' : '0x978c2dC96eAdc9703C7af3ae88B89D1e39606Ea4';
  const useExistingPhoenixNFT_v1Contract = isHardhat(network) ? '' : '0x7329cE38b205E63663EC4a9e33aE1F421FFf8255';
  const useExistingPhoenixTokenContract = isHardhat(network) ? '' : '0x2aEF61f7e8ce921139d0a724E0C10f016F572d32';
  const useExistingPermitAndTransferContract = isHardhat(network) ? '' : '0xB186B434d7A2b6c462b92C5B93296163D66a011D';

  // SEI TESTNET
  // const useExistingOpusContract = isHardhat(network) ? '' : '0xAd368881763e7B80A73798e5327092F3FC45336a';
  // const useExistingConfigContract = isHardhat(network) ? '' : '0xd7240874cf781531520ce59373624B30d788d27f';
  // const useExistingDexContract = isHardhat(network) ? '' : '0x39af2c049b52D9408E3f63Ef55f3eD28f0d7750a';
  // const useExistingProtectionContract = isHardhat(network) ? '' : '0xd8bFF003AcfF6067B5F6AB1EC966eD650C6f0740';
  // const useExistingLauncherContract = isHardhat(network) ? '' : '0x62a961BAF49d015075e6B0e1a8F59e29d0aa4588';
  // const useExistingPaymasterContract = isHardhat(network) ? '' : '';
  // const useExistingCarbonCoinContract = isHardhat(network) ? '' : '0x63106e73AaeAaC5DF3345A3c32ea735c40D1Dc2C';
  // const useExistingPhoenixDex = isHardhat(network) ? '' : '';
  // const useExistingPhoenixEggs = isHardhat(network) ? '' : '';
  // const useExistingPhoenixNFT_v1 = isHardhat(network) ? '' : '';
  // const useExistingPhoenixToken = isHardhat(network) ? '' : '';
  // const useExistingPermitAndTransferContract = isHardhat(network) ? '' : '0x653bca3d87630e0Bd826ccfFa39De9f776a554FB';

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
  // Deploy CarbonCoin (Sample)
  if (useExistingCarbonCoinContract.length === 0) {
    log('  Deploying CarbonCoin...');
    const constructorArgs = [
      sampleCarbonCoinArgs[0],
      sampleCarbonCoinArgs[1],
      sampleCarbonCoinArgs[2],
      usdcAddress,
      deployer,
      carbonCoinConfig.address,
      carbonCoinProtection.address,
      sampleCarbonCoinArgs[3]
    ];
    await deploy('CarbonCoin', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });
  }

  // Get Deployed CarbonCoin
  let carbonCoin;
  if (useExistingCarbonCoinContract.length === 0) {
    carbonCoin = await ethers.getContract('CarbonCoin');
  } else {
    carbonCoin = await ethers.getContractAt('CarbonCoin', useExistingCarbonCoinContract);
  }

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
  if (useExistingProtectionContract.length === 0 || useExistingLauncherContract.length === 0 || useExistingConfigContract.length === 0) {
    log(`  Setting Config in CarbonCoinProtection: ${carbonCoinConfig.address}`);
    await carbonCoinProtection.updateConfig(carbonCoinConfig.address).then(tx => tx.wait());

    log(`  Setting Launcher in CarbonCoinProtection: ${carbonCoinLauncher.address}`);
    await carbonCoinProtection.updateLauncher(carbonCoinLauncher.address).then(tx => tx.wait());
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

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify PermitAndTransfer
  if (useExistingPermitAndTransferContract.length === 0) {
    log('  Verifying PermitAndTransfer...');
    const constructorArgs = [];
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
  if (carbonCoinConfig || useExistingConfigContract.length !== 0) {
    log('  Verifying CarbonCoinConfig...');
    const constructorArgs = [];
    if (!isHardhat(network)) {
      // setTimeout(async () => {
        console.log(`  Verifying CarbonCoinConfig...: ${useExistingConfigContract}`);
        const contract = carbonCoinConfig || await ethers.getContractAt('CarbonCoinConfig', useExistingConfigContract);
        await verifyContract('CarbonCoinConfig', contract, constructorArgs);
      // }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify CarbonCoinDex
  if (carbonCoinDex || useExistingDexContract.length !== 0) {
    log('  Verifying CarbonCoinDex...');
    const constructorArgs = [
      usdcAddress,
      dexRouter,
      carbonCoinConfig.address,
      tickLower.toString(),
      tickUpper.toString(),
    ];
    if (!isHardhat(network)) {
      // setTimeout(async () => {
        console.log(`  Verifying CarbonCoinDex...: ${useExistingDexContract}`);
        const contract = carbonCoinDex || await ethers.getContractAt('CarbonCoinDex', useExistingDexContract);
        await verifyContract('CarbonCoinDex', contract, constructorArgs);
      // }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify CarbonCoinPaymaster
  if (carbonCoinPaymaster || useExistingPaymasterContract.length !== 0) {
    log('  Verifying CarbonCoinPaymaster...');
    const constructorArgs = [
      usdcAddress,
    ];
    if (!isHardhat(network)) {
      // setTimeout(async () => {
        console.log(`  Verifying CarbonCoinPaymaster...: ${useExistingPaymasterContract}`);
        const contract = carbonCoinPaymaster || await ethers.getContractAt('CarbonCoinPaymaster', useExistingPaymasterContract);
        await verifyContract('CarbonCoinPaymaster', contract, constructorArgs);
      // }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify CarbonCoinProtection
  if (carbonCoinProtection || useExistingProtectionContract.length !== 0) {
    log('  Verifying CarbonCoinProtection...');
    const constructorArgs = [
      deployer,
    ];
    if (!isHardhat(network)) {
      // setTimeout(async () => {
        console.log(`  Verifying CarbonCoinProtection...: ${useExistingProtectionContract}`);
        const contract = carbonCoinProtection || await ethers.getContractAt('CarbonCoinProtection', useExistingProtectionContract);
        await verifyContract('CarbonCoinProtection', contract, constructorArgs);
      // }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify CarbonCoinLauncher
  if (carbonCoinLauncher || useExistingLauncherContract.length !== 0) {
    log('  Verifying CarbonCoinLauncher...');
    const constructorArgs = [
      carbonCoinConfig.address,
      usdcAddress,
      carbonCoinProtection.address,
      carbonCoinPaymaster.address,
    ];
    if (!isHardhat(network)) {
      // setTimeout(async () => {
        console.log(`  Verifying CarbonCoinLauncher...: ${useExistingLauncherContract}`);
        const contract = carbonCoinLauncher || await ethers.getContractAt('CarbonCoinLauncher', useExistingLauncherContract);
        await verifyContract('CarbonCoinLauncher', contract, constructorArgs);
      // }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify CarbonCoin
  if (carbonCoin || useExistingCarbonCoinContract.length !== 0) {
    log('  Verifying CarbonCoin...');
    const constructorArgs = [
      sampleCarbonCoinArgs[0],
      sampleCarbonCoinArgs[1],
      sampleCarbonCoinArgs[2],
      usdcAddress,
      deployer,
      carbonCoinConfig.address,
      carbonCoinProtection.address,
      sampleCarbonCoinArgs[3],
    ];
    if (!isHardhat(network)) {
      // setTimeout(async () => {
        console.log(`  Verifying CarbonCoin...: ${useExistingCarbonCoinContract}`);
        const contract = carbonCoin || await ethers.getContractAt('CarbonCoin', useExistingCarbonCoinContract);
        await verifyContract('CarbonCoin', contract, constructorArgs);
      // }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify CarbonOpus
  if (carbonOpus || useExistingOpusContract.length !== 0) {
    log('  Verifying CarbonOpus...');
    const constructorArgs = [
      nftUri,
      usdcAddress
    ];
    if (!isHardhat(network)) {
      // setTimeout(async () => {
        console.log(`  Verifying CarbonOpus...: ${useExistingOpusContract}`);
        const contract = carbonOpus || await ethers.getContractAt('CarbonOpus', useExistingOpusContract);
        await verifyContract('CarbonOpus', contract, constructorArgs);
      // }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify PhoenixEggs
  if (phoenixEggs || useExistingPhoenixEggsContract.length !== 0) {
    log('  Verifying PhoenixEggs...');
    const constructorArgs = [];
    if (!isHardhat(network)) {
      // setTimeout(async () => {
        console.log(`  Verifying PhoenixEggs...: ${useExistingPhoenixEggsContract}`);
        const contract = phoenixEggs || await ethers.getContractAt('PhoenixEggs', useExistingPhoenixEggsContract);
        await verifyContract('PhoenixEggs', contract, constructorArgs);
      // }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify PhoenixToken
  if (phoenixToken || useExistingPhoenixTokenContract.length !== 0) {
    log('  Verifying PhoenixToken...');
    const constructorArgs = [];
    if (!isHardhat(network)) {
      // setTimeout(async () => {
        console.log(`  Verifying PhoenixToken...: ${useExistingPhoenixTokenContract}`);
        const contract = phoenixToken || await ethers.getContractAt('PhoenixToken', useExistingPhoenixTokenContract);
        await verifyContract('PhoenixToken', contract, constructorArgs);
      // }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify PhoenixDex
  if (phoenixDex || useExistingPhoenixDexContract.length !== 0) {
    log('  Verifying PhoenixDex...');
    const constructorArgs = [
      usdcAddress,
      phoenixToken.address,
      phoenixEggs.address,
      dexRouter,
    ];
    if (!isHardhat(network)) {
      // setTimeout(async () => {
        console.log(`  Verifying PhoenixDex...: ${useExistingPhoenixDexContract}`);
        const contract = phoenixDex || await ethers.getContractAt('PhoenixDex', useExistingPhoenixDexContract);
        await verifyContract('PhoenixDex', contract, constructorArgs);
      // }, 1000);
    }
  }

  //
  //////////////////////////////////////////////////////////////
  //
  // Verify PhoenixNFT_v1
  if (phoenixNFT_v1 || useExistingPhoenixNFT_v1Contract.length !== 0) {
    log('  Verifying PhoenixNFT_v1...');
    const constructorArgs = [];
    if (!isHardhat(network)) {
      // setTimeout(async () => {
        console.log(`  Verifying PhoenixNFT_v1...: ${useExistingPhoenixNFT_v1Contract}`);
        const contract = phoenixNFT_v1 || await ethers.getContractAt('PhoenixNFT_v1', useExistingPhoenixNFT_v1Contract);
        await verifyContract('PhoenixNFT_v1', contract, constructorArgs);
      // }, 1000);
    }
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
module.exports.tags = ['Everything']
