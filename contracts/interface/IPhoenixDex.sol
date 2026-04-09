// SPDX-License-Identifier: MIT

// IPhoenixDex.sol
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

interface IPhoenixDex {
  event LiquidityDeployed(
    address indexed creator,
    address indexed pair,
    uint256 tokenAmount,
    uint256 usdcAmount,
    uint256 liquidity,
    uint256 timestamp
  );
  event LiquidityRemoved(address indexed to, uint256 amountA, uint256 amountB, uint256 timestamp);
  event TokensSwapped(address indexed to, uint256 amountIn, uint256 amountOut, address[] path, uint256 timestamp);
  event RouterUpdated(address indexed newRouter, uint256 timestamp);

  error Unauthorized();

  function deployLiquidity(address creator, uint256 tokensAmount, uint256 usdcAmount)
    external
    returns (uint256 amountA, uint256 amountB, uint256 liquidity);

  function removeLiquidity(address to, uint256 liquidity)
    external
    returns (uint256 amountA, uint256 amountB);
}
