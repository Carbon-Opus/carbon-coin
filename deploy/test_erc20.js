const { log } = require('../js-helpers/utils');
const { verifyContract } = require('../js-helpers/verifyContract');

module.exports = async (hre) => {
  const { getNamedAccounts, deployments } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();
  const network = await hre.network;

  const isHardhat = () => {
    const isForked = network?.config?.forking?.enabled ?? false;
    return isForked || network?.name === 'hardhat';
  };

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  log('CarbonOpus - Mock Contracts');
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

  //
  // Deploy Contracts
  //
  log('\nDeploying Mock ERC20...');
  log(`Deployer = ${deployer}`);

  const constructorArgs = [ 'USDC Clone', 'USDC' ];
  await deploy('ERC20Mintable', {
    from: deployer,
    args: constructorArgs,
    log: true,
  });
  const erc20 = await ethers.getContract('ERC20Mintable');

  if (!isHardhat(network)) {
    await verifyContract('ERC20Mintable', erc20, constructorArgs);
  }

  const amount = ethers.utils.parseUnits('5000', 6);
  log(`  Minting ${amount} Tokens to Deployer: ${deployer}`);
  await erc20.mint(deployer, amount);
};

module.exports.tags = ['ERC20Mintable']
