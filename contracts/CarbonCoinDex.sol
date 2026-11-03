// SPDX-License-Identifier: MIT

// CarbonCoinDex.sol
// Copyright (c) 2026 Firma Lux Labs, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ICarbonCoinDex } from "./interface/ICarbonCoinDex.sol";
import { ICarbonCoinConfig } from "./interface/ICarbonCoinConfig.sol";
import { INonfungiblePositionManager } from "./interface/INonfungiblePositionManager.sol";


contract CarbonCoinDex is ICarbonCoinDex, ReentrancyGuard, Ownable, Pausable {
  // USDC token integration
  IERC20 public immutable USDC;
  address public config;
  INonfungiblePositionManager public dexRouter;
  int24 internal tickLower;
  int24 internal tickUpper;

  /**
   * @notice Constructor for the CarbonCoinDex contract.
   * @param _usdc The address of the USDC token contract.
   * @param _router The address of the Somnia Exchange V2 router.
   * @param _config The address of the token configuration contract.
   */
  constructor(
    address _usdc,
    address _router,
    address _config,
    int24 _tickLower,
    int24 _tickUpper
  ) Ownable(msg.sender) ReentrancyGuard() Pausable() {
    // Validate inputs
    require(_usdc != address(0), "Invalid USDC address");
    require(_router != address(0), "Invalid router");
    require(_config != address(0), "Invalid config");

    USDC = IERC20(_usdc);
    config = _config;
    dexRouter = INonfungiblePositionManager(_router);
    tickLower = _tickLower;
    tickUpper = _tickUpper;
  }

  /**
   * @notice Deploy Liquidity to Somnia Exchange with USDC/Token pair.
   * @dev Creates a USDC/Token liquidity pool.
   */
  function deployLiquidity(address recipient, address token, uint256 tokensAmount, uint256 usdcAmount)
    external onlyAuthorized(token) nonReentrant whenNotPaused
    returns (uint256 amountA, uint256 amountB, uint256 liquidity, uint256 lpTokenId)
  {
    address lpRecipient = recipient;
    if (lpRecipient == address(0)) {
      lpRecipient = ICarbonCoinConfig(config).getTreasury();
      if (lpRecipient == address(0)) {
        lpRecipient = _owner();
      }
    }

    // Ensure the caller has approved the DEX to spend their tokens and USDC
    // require(IERC20(token).allowance(msg.sender, address(this)) >= tokensAmount, "Insufficient token allowance");
    // require(USDC.allowance(msg.sender, address(this)) >= usdcAmount, "Insufficient USDC allowance");

    // Transfer tokens and USDC from the caller to this contract
    require(IERC20(token).transferFrom(msg.sender, address(this), tokensAmount), "Token transfer failed");
    require(USDC.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");

    // Sort tokens to satisfy token0 < token1 required by concentrated liquidity AMMs
    bool isUsdc0 = address(USDC) < token;
    address token0 = isUsdc0 ? address(USDC) : token;
    address token1 = isUsdc0 ? token : address(USDC);

    uint256 amount0Desired = isUsdc0 ? usdcAmount : tokensAmount;
    uint256 amount1Desired = isUsdc0 ? tokensAmount : usdcAmount;

    uint256 amount0Min = (amount0Desired * 95) / 100; // 5% slippage tolerance
    uint256 amount1Min = (amount1Desired * 95) / 100;

    int24 positionTickLower = isUsdc0 ? tickLower : -tickUpper;
    int24 positionTickUpper = isUsdc0 ? tickUpper : -tickLower;

    // Approve router to spend tokens and USDC
    IERC20(token).approve(address(dexRouter), tokensAmount);
    USDC.approve(address(dexRouter), usdcAmount);

    // Initialize pool if necessary
    uint160 sqrtPriceX96 = uint160((Math.sqrt(amount1Desired) * (uint256(1) << 96)) / Math.sqrt(amount0Desired));
    try dexRouter.createAndInitializePoolIfNecessary(token0, token1, sqrtPriceX96) {} catch {}

    // Add liquidity
    uint256 minted0;
    uint256 minted1;
    INonfungiblePositionManager.MintParams memory params =
      INonfungiblePositionManager.MintParams({
        token0: token0,
        token1: token1,
        tickLower: positionTickLower,
        tickUpper: positionTickUpper,
        amount0Desired: amount0Desired,
        amount1Desired: amount1Desired,
        amount0Min: amount0Min,
        amount1Min: amount1Min,
        recipient: lpRecipient,
        deadline: block.timestamp
      });
    (lpTokenId, liquidity, minted0, minted1) = dexRouter.mint(params);

    amountA = isUsdc0 ? minted0 : minted1; // USDC
    amountB = isUsdc0 ? minted1 : minted0; // Tokens

    // Emit Liquidity event
    emit LiquidityDeployed(
      token,
      lpRecipient,
      lpTokenId,
      amountB,
      amountA,
      liquidity,
      block.timestamp
    );
  }

  /**
   * @notice Pause the DEX
   */
  function pause() external onlyOwner {
    _pause();
    emit DexPaused(block.timestamp);
  }

  /**
   * @notice Unpause the DEX
   */
  function unpause() external onlyOwner {
    _unpause();
    emit DexUnpaused(block.timestamp);
  }

  /**
   * @notice Update the config address
   */
  function updateConfig(address newConfig) external onlyOwner {
    config = newConfig;
    emit ConfigUpdated(newConfig, block.timestamp);
  }

  function updateRouter(address newRouter) external onlyOwner {
    dexRouter = INonfungiblePositionManager(newRouter);
    emit RouterUpdated(newRouter, block.timestamp);
  }

  function _owner() internal view returns (address) {
    return Ownable(config).owner();
  }

  modifier onlyAuthorized(address token) {
    if (msg.sender != _owner() && msg.sender != token) revert Unauthorized();
    _;
  }
}
