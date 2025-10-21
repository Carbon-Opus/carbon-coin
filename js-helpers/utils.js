const { ethers } = require('hardhat');
const fs = require('fs');
const path = require('path');
const _ = require('lodash');

const toWei = ethers.utils.parseEther;
const toEth = ethers.utils.formatEther;
const toStr = (val) => ethers.utils.toUtf8String(val).replace(/\0/g, '');
const toBytes = ethers.utils.formatBytes32String;

const toBN = function(number, defaultValue = null) {
  if (number === null) {
    if (defaultValue === null) {
      return null;
    }
    number = defaultValue;
  }
  return ethers.BigNumber.from(number);
}

const log = (...args) => {
  console.log(...args);
};

const isHardhat = (network) => {
  const isForked = network?.config?.forking?.enabled ?? false;
  return isForked || network?.name === 'hardhat';
};

const chainIdByName = (chainName) => {
  switch (_.toLower(chainName)) {
    case 'homestead': return 1;
    case 'mainnet': return 1;
    case 'hardhat': return 34443;
    case 'coverage': return 31337;
    case 'somniatestnet': return 50312;
    default: return 0;
  }
};

const chainNameById = (chainId) => {
  switch (parseInt(chainId, 10)) {
    case 1: return 'Mainnet';
    case 31337: return 'Hardhat';
    case 50312: return 'Somnia Testnet';
    default: return 'Unknown';
  }
};

const chainTypeById = (chainId) => {
  switch (parseInt(chainId, 10)) {
    case 1:
      return {isProd: true, isTestnet: false, isHardhat: false};
    case 50312:
      return {isProd: false, isTestnet: true, isHardhat: false};
    case 31337:
    default:
      return {isProd: false, isTestnet: false, isHardhat: true};
  }
};

const findNearestValidTick = (tickSpacing, nearestToMin) => {
  const MIN_TICK = -887272;
  const MAX_TICK = 887272;

  if (nearestToMin) {
    // Adjust to the nearest valid tick above MIN_TICK
    return Math.ceil(MIN_TICK / tickSpacing) * tickSpacing;
  } else {
    // Adjust to the nearest valid tick below MAX_TICK
    return Math.floor(MAX_TICK / tickSpacing) * tickSpacing;
  }
};

const tryGetContract = async (contractName) => {
  try {
    return await ethers.getContract(contractName);
  } catch (err) {
    return { address: null };
  }
};

const ensureDirectoryExistence = (filePath) => {
  var dirname = path.dirname(filePath);
  if (fs.existsSync(dirname)) {
    return true;
  }
  ensureDirectoryExistence(dirname);
  fs.mkdirSync(dirname);
};

module.exports = {
  toWei,
  toEth,
  toBN,
  toStr,
  toBytes,
  log,
  isHardhat,
  chainTypeById,
  chainNameById,
  chainIdByName,
  findNearestValidTick,
  tryGetContract,
  ensureDirectoryExistence,
}