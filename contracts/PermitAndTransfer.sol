// PermitAndTransfer.sol

// PermitAndTransfer.sol
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20Permit {
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract PermitAndTransfer is Ownable {
  mapping(address => bool) public isWhitelisted;

  event PermitTransfer(bytes32 indexed senderId, address indexed token, address accountOwner, address spender, uint256 value, bytes32 uuid);

  constructor() Ownable(msg.sender) {}

  function addToken(address token) external onlyOwner {
    isWhitelisted[token] = true;
  }

  function removeToken(address token) external onlyOwner {
    isWhitelisted[token] = false;
  }

  function permitAndTransfer(
    bytes32 senderId, // for filtering on Events
    bytes32 uuid,     // for matching to a specific order
    address token,    // usdc or other
    address accountOwner,
    address to,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(isWhitelisted[token], "Token not whitelisted");
    IERC20Permit(token).permit(accountOwner, address(this), amount, deadline, v, r, s);
    require(
      IERC20Permit(token).transferFrom(accountOwner, to, amount),
      "Transfer failed"
    );
    emit PermitTransfer(senderId, token, accountOwner, to, amount, uuid);
  }
}
