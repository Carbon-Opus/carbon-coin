const { isHardhat, log } = require('../js-helpers/utils');
const { verifyContract } = require('../js-helpers/verifyContract');

module.exports = async (hre) => {
  await hre.run('deploy', { tags: 'Phoenix' });
  const { ethers, getNamedAccounts, deployments } = hre;
  const network = await hre.network;

  if (isHardhat(network)) {
    log('Skipping verification on Hardhat network');
    return;
  }

  const deployedContracts = {
    PhoenixEggs: await ethers.getContract('PhoenixEggs'),
    PhoenixToken: await ethers.getContract('PhoenixToken'),
    PhoenixDex: await ethers.getContract('PhoenixDex'),
    PhoenixNFT_v1: await ethers.getContract('PhoenixNFT_v1'),
  };

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  log('Phoenix Contracts - Contract Verification');
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

module.exports.tags = ['PhoenixVerification'];
