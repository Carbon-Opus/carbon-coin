// SPDX-License-Identifier: MIT

// CarbonCoinDex.sol
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

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ICarbonCoinDex } from "./interface/ICarbonCoinDex.sol";
import { ICarbonCoinConfig } from "./interface/ICarbonCoinConfig.sol";
import { ISomniaExchangeRouter02 } from "./interface/ISomniaExchangeRouter02.sol";
import { ISomniaExchangeFactory } from "./interface/ISomniaExchangeFactory.sol";


contract CarbonCoinDex is ICarbonCoinDex, ReentrancyGuard, Ownable, Pausable {
  // USDC token integration
  IERC20 public immutable USDC;
  address public config;
  ISomniaExchangeRouter02 public dexRouter;

  /**
   * @notice Constructor for the CarbonCoinDex contract.
   * @param _usdc The address of the USDC token contract.
   * @param _router The address of the Somnia Exchange V2 router.
   * @param _config The address of the token configuration contract.
   */
  constructor(
    address _usdc,
    address _router,
    address _config
  ) Ownable(msg.sender) ReentrancyGuard() Pausable() {
    // Validate inputs
    require(_usdc != address(0), "Invalid USDC address");
    require(_router != address(0), "Invalid router");
    require(_config != address(0), "Invalid config");

    USDC = IERC20(_usdc);
    config = _config;
    dexRouter = ISomniaExchangeRouter02(_router);
  }

  /**
   * @notice Deploy Liquidity to Somnia Exchange with USDC/Token pair.
   * @dev Creates a USDC/Token liquidity pool.
   */
  function deployLiquidity(address creator, address token, uint256 tokensAmount, uint256 usdcAmount)
    external onlyAuthorized(token) nonReentrant whenNotPaused
    returns (uint256 amountA, uint256 amountB, uint256 liquidity)
  {
    // Ensure the caller has approved the DEX to spend their tokens and USDC
    // require(IERC20(token).allowance(msg.sender, address(this)) >= tokensAmount, "Insufficient token allowance");
    // require(USDC.allowance(msg.sender, address(this)) >= usdcAmount, "Insufficient USDC allowance");

    // Transfer tokens and USDC from the caller to this contract
    require(IERC20(token).transferFrom(msg.sender, address(this), tokensAmount), "Token transfer failed");
    require(USDC.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");

    // Approve router to spend tokens and USDC
    IERC20(token).approve(address(dexRouter), tokensAmount);
    USDC.approve(address(dexRouter), usdcAmount);

    // Add liquidity (auto-creates USDC/Token pair)
    try dexRouter.addLiquidity(
        address(USDC),
        token,
        usdcAmount,
        tokensAmount,
        (usdcAmount * 95) / 100, // 5% slippage tolerance
        (tokensAmount * 95) / 100,
        creator, // Send LP Tokens to Creator  OR   address(0), // Burn LP tokens
        block.timestamp + 60
    ) returns (uint amtA, uint amtB, uint amtC) {
      // Get the pair address after deployment
      address pair = ISomniaExchangeFactory(dexRouter.factory()).getPair(token, address(USDC));

      // Emit Liquidity event
      emit LiquidityDeployed(
        token,
        creator,
        pair,
        amountA,
        amountB,
        liquidity,
        block.timestamp
      );
      return (amtA, amtB, amtC);
    } catch {
      revert("Deploy Liquidity failed");
    }
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
    dexRouter = ISomniaExchangeRouter02(newRouter);
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
