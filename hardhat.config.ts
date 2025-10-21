import * as dotenv from 'dotenv';
dotenv.config()

import '@nomicfoundation/hardhat-verify';
import '@nomiclabs/hardhat-ethers';
import '@nomicfoundation/hardhat-chai-matchers';
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import 'hardhat-abi-exporter';
import 'solidity-coverage';

import 'hardhat-deploy-ethers';
import 'hardhat-deploy';
import 'hardhat-watcher';

import { HardhatUserConfig, task } from 'hardhat/config';
import { TASK_TEST } from 'hardhat/builtin-tasks/task-names';

// Task to run deployment fixtures before tests without the need of '--deploy-fixture'
//  - Required to get fixtures deployed before running Coverage Reports
task(
  TASK_TEST,
  'Runs the coverage report',
  async (args: Object, hre, runSuper) => {
    await hre.run('compile');
    await hre.deployments.fixture();
    return runSuper({...args, noCompile: true});
  }
);

const mnemonic = {
  testnet: `${process.env.TESTNET_MNEMONIC}`.replace(/_/g, ' '),
  mainnet: `${process.env.MAINNET_MNEMONIC}`.replace(/_/g, ' '),
};

const optimizerDisabled = process.env.OPTIMIZER_DISABLED || false;

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.7.6',
      },
      {
        version: '0.8.27',
        settings: {
          optimizer: {
            enabled: !optimizerDisabled,
            runs: 200,
          },
          viaIR: true,
        },
      },
    ],
  },
  namedAccounts: {
    deployer: {
      default: 0,
      // mode: process.env.MAINNET_PKEY as string,
    },
    treasury: {
      default: 1,
      // Treasury:
      // 'mode': '0x74D599ddC5c015C45D8033670404C7C23d932C77', // https://safe.optimism.io/address-book?safe=mode:0x74D599ddC5c015C45D8033670404C7C23d932C77
      // 'bsc': '',
    },
    user1: {
      default: 2,
    },
    user2: {
      default: 3,
    },
    user3: {
      default: 4,
    },
  },
  paths: {
      sources: './contracts',
      tests: './test',
      cache: './cache',
      artifacts: './build/contracts',
      deploy: './deploy',
      deployments: './deployments'
  },
  networks: {
    hardhat: {
      chainId: 34443,
      gasPrice: 'auto',
      forking: {
        // url: 'https://polygon-mainnet.g.alchemy.com/v2/' + process.env.ALCHEMY_ETH_APIKEY,
        // blockNumber: 30784049
        url: 'https://mainnet.mode.network',
        blockNumber: 20736394
      },
      accounts: {
        mnemonic: mnemonic.testnet,
        initialIndex: 0,
        count: 10,
      },
    },
    somniaTestnet: {
      url: "https://dream-rpc.somnia.network",
      accounts: {
        mnemonic: mnemonic.testnet,
        initialIndex: 0,
        count: 10,
      },
    },
  },
  etherscan: {
    apiKey: {
      somniaTestnet: "empty",
    },
    customChains: [
      {
        network: "somniaTestnet",
        chainId: 50312,
        urls: {
          apiURL: "https://shannon-explorer.somnia.network/api",
          browserURL: "https://shannon-explorer.somnia.network",
        },
      },
    ],
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 1,
    enabled: process.env.REPORT_GAS ? true : false,
  },
  abiExporter: {
    path: './abis',
    runOnCompile: true,
    clear: true,
    flat: true,
    only: [ 'CarbonCoin', 'CarbonCoinConfig', 'CarbonCoinLauncher' ],
    except: [],
  },
  sourcify: { enabled: true },
};

export default config;
