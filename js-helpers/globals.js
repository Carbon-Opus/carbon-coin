const { utils, constants } = require('ethers');

// Chains:
// 50312 - Somnia Testnet (Shannon)

const globals = {
  routers: {
    50312: {
      UniversalRouter: '0xb98c15a0dC1e271132e341250703c7e94c059e8D',
    },
  },

  // Standard Parameters
  tokenCreationFee: utils.parseUnits('0.0001', 18),
  maxTokensPerCreator: 1,

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
