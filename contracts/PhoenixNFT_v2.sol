// SPDX-License-Identifier: MIT

// PhoenixNFT_v2.sol
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

import {PhoenixNftBase} from "./lib/PhoenixNftBase.sol";

/// @custom:security-contact info@charged.fi
contract PhoenixNFT_v2 is PhoenixNftBase {

  // In V2, this is actually the Initial Payment Amount in ETH
  mapping (uint256 => uint256) internal _customTraits;

  constructor() PhoenixNftBase("PhoenixNFT_v2", "PHX_V2", "https://us-central1-phoenix-guild-nft.cloudfunctions.net/api/nftmeta_v2/") {}

  function getCustomTraits(uint256 tokenId) external view override returns (uint256) {
    return _customTraits[tokenId];
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
    // Spawn New Phoenix!
    tokenId = _spawnPhoenix(receiver, customTraits);

    // Tracking for Metadata
    _customTraits[tokenId] = customTraits;
  }

  function burn(uint256 tokenId) external override {
    address tokenOwner = ownerOf(tokenId);
    require(_msgSender() == tokenOwner, "must be token owner");

    // TODO: Determine New Unique Traits
    uint256 traits = _customTraits[tokenId];

    // Burn the Phoenix!  Release a New Magical Beast!
    _burnPhoenix(tokenOwner, tokenId, traits);
  }
}