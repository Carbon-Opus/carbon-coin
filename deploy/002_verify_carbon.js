const { isHardhat, log } = require('../js-helpers/utils');
const { verifyContract } = require('../js-helpers/verifyContract');

module.exports = async (hre) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const { deployer } = await getNamedAccounts();
  const network = await hre.network;

  if (isHardhat(network)) {
    log('Skipping verification on Hardhat network');
    return;
  }

  const deployedContracts = {
    PermitAndTransfer: await ethers.getContract('PermitAndTransfer'),
    CarbonTreasury: await ethers.getContract('CarbonTreasury'),
    CarbonCoinConfig: await ethers.getContract('CarbonCoinConfig'),
    CarbonCoinDex: await ethers.getContract('CarbonCoinDex'),
    CarbonCoinPaymaster: await ethers.getContract('CarbonCoinPaymaster'),
    CarbonCoinProtection: await ethers.getContract('CarbonCoinProtection'),
    CarbonCoinLauncher: await ethers.getContract('CarbonCoinLauncher'),
    CarbonOpusVault: await ethers.getContract('CarbonOpusVault'),
    CarbonOpus: await ethers.getContract('CarbonOpus'),
  };

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  log('Carbon Opus - Carbon Coin - Contract Verification');
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

  for (const [name, contract] of Object.entries(deployedContracts)) {
    log(`  Verifying ${name}...`);
    try {
      const constructorArgs = (await deployments.get(name)).args;
      await verifyContract(name, contract, constructorArgs, `contracts/${name}.sol:${name}`);
    } catch (e) {
      log(`  Verification failed for ${name}: ${e.message}`);
    }
  }
};

module.exports.tags = ['CarbonVerification'];
