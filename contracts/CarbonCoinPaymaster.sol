// SPDX-License-Identifier: MIT

// CarbonCoinPaymaster.sol
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
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ICarbonCoinPaymaster } from "./interface/ICarbonCoinPaymaster.sol";
import { ICarbonCoin } from "./interface/ICarbonCoin.sol";

interface IUSDC is IERC20, IERC20Permit {}

contract CarbonCoinPaymaster is ICarbonCoinPaymaster, ReentrancyGuard, Ownable {
  // State variables
  address internal controller;

  // USDC token integration
  IUSDC public usdcToken;

  constructor(address _usdc) Ownable(msg.sender) {
    // Validate inputs
    require(_usdc != address(0), "Invalid USDC address");

    usdcToken = IUSDC(_usdc);
    controller = msg.sender;
  }

  function buyOnBehalf(
    address receiver,
    address creatorCoin,
    uint256 usdcAmount,
    uint256 minTokensOut,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external nonReentrant onlyController {
    // Execute permit & transfer
    _collectPaymentWithPermit(receiver, usdcAmount, deadline, v, r, s);

    // Approve CarbonCoin to Take Payment
    usdcToken.approve(creatorCoin, usdcAmount);

    // Execute Purchase
    ICarbonCoin(creatorCoin).buyOnBehalf(
      receiver,
      usdcAmount,
      minTokensOut
    );

    // Emit event
    emit TokenBuy(creatorCoin, receiver, usdcAmount, minTokensOut);
  }

  function sellOnBehalf(
    address receiver,
    address creatorCoin,
    uint256 amount,
    uint256 minUsdcOut
  ) external nonReentrant onlyController {
    // Execute Sale
    ICarbonCoin(creatorCoin).buyOnBehalf(
      receiver,
      amount,
      minUsdcOut
    );

    // Emit event
    emit TokenBuy(creatorCoin, receiver, amount, minUsdcOut);
  }

  function updateController(address newController) external onlyOwner {
    require(newController != address(0), "Invalid controller");
    controller = newController;
    emit ControllerUpdated(newController);
  }

  function _collectPaymentWithPermit(address account, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) internal {
    usdcToken.permit(account, address(this), amount, deadline, v, r, s);
    require(usdcToken.transferFrom(account, address(this), amount), "USDC transfer failed");
  }

  modifier onlyController() {
    if (msg.sender != controller) revert Unauthorized();
    _;
  }
}
