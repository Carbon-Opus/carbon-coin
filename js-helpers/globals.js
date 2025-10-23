const { utils, constants } = require('ethers');

// Chains:
// 50312 - Somnia Testnet (Shannon)

const globals = {
  addresses: {
    // Somnia Mainnet
    5031: {
      WETH: '0x046EDe9564A72571df6F5e44d0405360c0f4dCab', // WSOMI
      router: '0xCdE9aFDca1AdAb5b5C6E4F9e16c9802C88Dc7e1A', // Somnia Exchange (Router V02)
    },
    // Somnia Testnet
    50312: {
      WETH: '0x046EDe9564A72571df6F5e44d0405360c0f4dCab', // WSOMI
      router: '0xb98c15a0dC1e271132e341250703c7e94c059e8D', // Somnia Exchange (Router V02)
    },
  },

  // Standard Parameters
  tokenCreationFee: utils.parseUnits('0.0001', 18),
  maxTokensPerCreator: 1,
  opusNftUri: 'https://api.carbonopus.com/metadata/{id}.json',

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
