// SPDX-License-Identifier: MIT

// PhoenixToken.sol
// Copyright (c) 2025 Firma Lux Labs, Inc. <https://carbonopus.com>
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

pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import {IPhoenixToken} from "./interface/IPhoenixToken.sol";

contract PhoenixToken is
  ERC20Burnable,
  Ownable,
  ERC20Permit,
  IPhoenixToken
{
  error Unauthorized();
  address internal _phoenixEggs;

  constructor()
    Ownable(_msgSender())
    ERC20("PhoenixToken", "PHX")
    ERC20Permit("PhoenixToken")
  {}

  // Total Supply cannot be changed after mint
  function mintAll(uint256 totalAmount) external override onlyPhoenixEggs {
    require(super.totalSupply() == 0, "already minted");
    _mint(_phoenixEggs, totalAmount);
    emit TokenSupplyMinted(totalAmount);
  }

  /**
    * @dev Set the Phoenix Eggs Contract - Only Owner
    */
  function setPhoenixEggs(address phoenixEggs) external onlyOwner {
    _phoenixEggs = phoenixEggs;
  }

  modifier onlyPhoenixEggs() {
    if (_msgSender() != _phoenixEggs) revert Unauthorized();
    _;
  }
}
