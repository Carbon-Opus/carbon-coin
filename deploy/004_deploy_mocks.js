const { isHardhat } = require('../js-helpers/utils');

module.exports = async (hre) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const network = await hre.network;

  if (isHardhat(network)) {
    await deploy('MockNonfungiblePositionManager', {
      from: deployer,
      args: [],
      log: true,
    });
  }
};

module.exports.tags = ['Mocks'];
