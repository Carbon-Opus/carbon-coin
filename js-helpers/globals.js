const { utils, constants } = require('ethers');

// Chains:
// 1329  - Sei Mainnet
// 1328  - Sei Testnet
// 5031  - Somnia Mainnet
// 50312 - Somnia Testnet (Shannon)

const globals = {
  addresses: {
    // Sei Mainnet
    1329: {
      router: '0xe294d5Eb435807cD21017013Bef620ed1AeafbeB',
      usdc: '0xe15fC38F6D8c56aF07bbCBe3BAf5708A2Bf42392',
    },
    // Sei Testnet
    1328: {
      router: '0xe294d5Eb435807cD21017013Bef620ed1AeafbeB', // TODO: Find Testnet address
      usdc: '0x54F9A3f294dBd6f5a100084647bd0E6EcD4b653e',
    },
    // Somnia Mainnet
    5031: {
      WETH: '0x046EDe9564A72571df6F5e44d0405360c0f4dCab', // WSOMI
      router: '0xCdE9aFDca1AdAb5b5C6E4F9e16c9802C88Dc7e1A', // Somnia Exchange (Router V02)
      usdc: '0x28BEc7E30E6faee657a03e19Bf1128AaD7632A00',
    },
    // Somnia Testnet
    50312: {
      WETH: '0x046EDe9564A72571df6F5e44d0405360c0f4dCab', // WSOMI
      router: '0xb98c15a0dC1e271132e341250703c7e94c059e8D', // Somnia Exchange (Router V02)
      usdc: '0x0673aDBDc50F3501A3a5FaE4acd723D8430e9f18',
    },
    // Hardhat
    34443: {
      WETH: '0x046EDe9564A72571df6F5e44d0405360c0f4dCab', // WSOMI
      router: '0xb98c15a0dC1e271132e341250703c7e94c059e8D', // Somnia Exchange (Router V02)
      usdc: '0x0673aDBDc50F3501A3a5FaE4acd723D8430e9f18',
    },
  },

  // Standard Parameters
  maxTokensPerCreator: 100,
  opusNftUri: {
    1329: 'https://api-6mceyrhrja-uc.a.run.app/metadata/{id}.json',
    1328: 'https://api-plxgamnywq-uc.a.run.app/metadata/{id}.json',
    5031: 'https://api-6mceyrhrja-uc.a.run.app/metadata/{id}.json',
    50312: 'https://api-plxgamnywq-uc.a.run.app/metadata/{id}.json',
    34443: 'https://api-plxgamnywq-uc.a.run.app/metadata/{id}.json',
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
