// SPDX-License-Identifier: MIT

// ICarbonCoinDex.sol
// Copyright (c) 2025 CarbonOpus
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

pragma solidity 0.8.27;

interface ICarbonCoinDex {
  /**
   * @notice Emitted when liquidity is deployed for a graduated token
   * @param token The address of the CarbonCoin token
   * @param creator The address of the token creator
   * @param pair The address of the DEX pair created
   * @param tokenAmount The amount of tokens added to liquidity
   * @param usdcAmount The amount of USDC added to liquidity
   * @param liquidity The amount of LP tokens minted
   * @param timestamp The timestamp of the deployment
   */
  event LiquidityDeployed(
    address indexed token,
    address indexed creator,
    address indexed pair,
    uint256 tokenAmount,
    uint256 usdcAmount,
    uint256 liquidity,
    uint256 timestamp
  );

  /**
   * @notice Emitted when the DEX is paused
   * @param timestamp The timestamp of the pause
   */
  event DexPaused(uint256 timestamp);

  /**
   * @notice Emitted when the DEX is unpaused
   * @param timestamp The timestamp of the unpause
   */
  event DexUnpaused(uint256 timestamp);

  /**
   * @notice Emitted when the config address is updated
   * @param newConfig The new config address
   * @param timestamp The timestamp of the update
   */
  event ConfigUpdated(address indexed newConfig, uint256 timestamp);

  /**
   * @notice Emitted when the router address is updated
   * @param newRouter The new router address
   * @param timestamp The timestamp of the update
   */
  event RouterUpdated(address indexed newRouter, uint256 timestamp);

  error Unauthorized();

  /**
   * @notice Deploy Liquidity to Somnia Exchange with USDC/Token pair.
   * @dev Creates a USDC/Token liquidity pool.
   */
  function deployLiquidity(address creator, address token, uint256 tokensAmount, uint256 usdcAmount)
    external
    returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}
