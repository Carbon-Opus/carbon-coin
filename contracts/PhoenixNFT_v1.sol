// SPDX-License-Identifier: MIT

// PhoenixNFT_v1.sol
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

pragma solidity ^0.8.28;

import {PhoenixNftBase} from "./lib/PhoenixNftBase.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @custom:security-contact info@charged.fi
contract PhoenixNFT_v1 is PhoenixNftBase, ReentrancyGuard {

  constructor() PhoenixNftBase("PhoenixNFT_v1", "PHX_V1") {}

  function getCustomTraits(uint256 tokenId) external view override returns (uint256) {
    if (address(phoenixTraits) == address(0)) { return 0; }
    return phoenixTraits.getTraits(tokenId);
  }

  function spawnFromAshes(
    address receiver,
    uint256 customTraits
  )
    external
    override
    onlyLastPhoenix(_msgSender())
    returns (uint256 tokenId)
  {
    // A new Phoenix is born from the ashes of a previous version.
    tokenId = _spawnPhoenix(receiver, customTraits);
  }
}