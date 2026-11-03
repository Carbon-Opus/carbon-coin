const { utils, constants } = require('ethers');

// Chains:
// 5031  - Somnia Mainnet
// 50312 - Somnia Testnet (Shannon)

const globals = {
  addresses: {
    // Somnia Mainnet
    5031: {
      WETH: '0x046EDe9564A72571df6F5e44d0405360c0f4dCab', // WSOMI
      router: '0xCdE9aFDca1AdAb5b5C6E4F9e16c9802C88Dc7e1A', // Somnia Exchange (Router V02)
      usdc: '0x28BEc7E30E6faee657a03e19Bf1128AaD7632A00', // real
      // usdc: '0x3A5281972B7B986116c0f58909689Dc67386e4de', // fake
    },
    // Somnia Testnet
    50312: {
      WETH: '0x046EDe9564A72571df6F5e44d0405360c0f4dCab', // WSOMI
      router: '0xb98c15a0dC1e271132e341250703c7e94c059e8D', // Somnia Exchange (Router V02)
      usdc: '0x7ae5Fd60c89D8F9653d485c3F280Ac3B127676B7',
    },
    8453: {
      WETH: '0x4200000000000000000000000000000000000006',
      router: '0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1', // Uniswap V3 Router
      usdc: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
    },
    84532: {
      WETH: '0x4200000000000000000000000000000000000006',
      router: '0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2', // Uniswap V3 Router
      usdc: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
    },
    // Hardhat
    34443: {
      WETH: '0x046EDe9564A72571df6F5e44d0405360c0f4dCab', // WSOMI
      router: '0xb98c15a0dC1e271132e341250703c7e94c059e8D', // Somnia Exchange (Router V02)
      usdc: '0x7ae5Fd60c89D8F9653d485c3F280Ac3B127676B7',
    },
  },

  // Standard Parameters
  maxTokensPerCreator: 100,
  opusNftUri: {
    8453: 'https://api-6mceyrhrja-uc.a.run.app/nft/{id}.json',
    84532: 'https://api-plxgamnywq-uc.a.run.app/nft/{id}.json',
    5031: 'https://api-6mceyrhrja-uc.a.run.app/nft/{id}.json',
    50312: 'https://api-plxgamnywq-uc.a.run.app/nft/{id}.json',
    34443: 'https://api-plxgamnywq-uc.a.run.app/nft/{id}.json',
  },

  // ABIs
  erc20Abi : [
    'function transfer(address to, uint amount)',
    'function balanceOf(address account) public view returns (uint256)',
    'function approve(address spender, uint256 amount) external returns (bool)'
  ],
  wethAbi : [
    'function deposit() public',
    'function withdraw(uint wad) public',
  ],
};

module.exports = globals;
