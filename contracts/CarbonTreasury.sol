// SPDX-License-Identifier: MIT

// CarbonTreasury.sol
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

pragma solidity 0.8.27;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit, ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ICarbonTreasury } from "./interface/ICarbonTreasury.sol";
import { BlackholePrevention } from "./lib/BlackholePrevention.sol";

interface IUSDC is IERC20, IERC20Permit {}

contract CarbonTreasury is ICarbonTreasury, Ownable, BlackholePrevention {
  IUSDC public usdcToken;

  constructor(address usdcTokenAddress) Ownable(_msgSender()) {
    usdcToken = IUSDC(usdcTokenAddress);
  }

  function purchase(bytes32 memberId, address memberAddress, bytes32 orderId, bytes32 orderType, uint256 price) external {
    // Collect payment
    _collectPayment(memberAddress, price);

    // Emit event
    emit PurchaseCompleted(memberId, memberAddress, orderId, orderType, price);
  }

  function purchaseWithPermit(bytes32 memberId, address memberAddress, bytes32 orderId, bytes32 orderType, uint256 price, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
    // Collect payment
    _collectPaymentWithPermit(memberAddress, price, deadline, v, r, s);

    // Emit event
    emit PurchaseCompleted(memberId, memberAddress, orderId, orderType, price);
  }

  function withdraw(address to, uint256 amount) external onlyOwner {
    require(usdcToken.transfer(to, amount), "USDC transfer failed");
    emit Withdrawn(_msgSender(), to, amount, block.timestamp);
  }

  function withdrawEther(address payable receiver, uint256 amount) external onlyOwner {
    _withdrawEther(receiver, amount);
  }

  function withdrawErc20(address payable receiver, address tokenAddress, uint256 amount) external onlyOwner {
    _withdrawERC20(receiver, tokenAddress, amount);
  }

  function withdrawERC721(address payable receiver, address tokenAddress, uint256 tokenId) external onlyOwner {
    _withdrawERC721(receiver, tokenAddress, tokenId);
  }

  function withdrawERC1155(address payable receiver, address tokenAddress, uint256 tokenId, uint256 amount) external onlyOwner {
    _withdrawERC1155(receiver, tokenAddress, tokenId, amount);
  }

  function _collectPayment(address memberAddress, uint256 amount) internal {
    require(usdcToken.transferFrom(memberAddress, address(this), amount), "USDC transfer failed");
  }

  function _collectPaymentWithPermit(address memberAddress, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) internal {
    usdcToken.permit(memberAddress, address(this), amount, deadline, v, r, s);
    _collectPayment(memberAddress, amount);
  }
}
