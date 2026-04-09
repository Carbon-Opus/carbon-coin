// SPDX-License-Identifier: MIT

// PhoenixNftBase.sol
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

pragma solidity >=0.8.0;

import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

import {BlackholePrevention} from "./BlackholePrevention.sol";
import {IPhoenixNFT} from "../interface/IPhoenixNFT.sol";

abstract contract PhoenixNftBase is
  Ownable,
  ERC721Enumerable,
  IPhoenixNFT,
  BlackholePrevention
{
  using Strings for uint256;

  uint256 internal _tokenIdCounter;
  address internal _lastPhoenix;
  address internal _nextPhoenix;
  string internal _baseUri;

  constructor(string memory name, string memory symbol, string memory baseUri)
    Ownable(_msgSender())
    ERC721(name, symbol)
  {
    _baseUri = baseUri;
  }

  /***********************************|
  |            Only Owner             |
  |__________________________________*/

  /**
    * @dev Set Base URI for Metadata - Only Owner
    */
  function setBaseURI(string memory newBase) external onlyOwner {
    _baseUri = newBase;
  }

  /**
    * @dev Set the Last Phoenix Contract - Only Owner
    */
  function setLastPhoenix(address phoenixNft) external onlyOwner {
    _lastPhoenix = phoenixNft;
  }

  /**
    * @dev Set the Next Phoenix Contract - Only Owner
    */
  function setNextPhoenix(address phoenixNft) external onlyOwner {
    _nextPhoenix = phoenixNft;
  }


  /***********************************|
  |          Only Admin/DAO           |
  |      (blackhole prevention)       |
  |__________________________________*/

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


  /***********************************|
  |        Private Functions          |
  |__________________________________*/

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseUri;
  }

  function _spawnPhoenix(address receiver, uint256 customTraits) internal returns (uint256 tokenId) {
    // Mint NFT
    _tokenIdCounter += 1;
    tokenId = _tokenIdCounter;
    _safeMint(receiver, tokenId);

    // Spawn Event
    emit PhoenixSpawned(receiver, tokenId, customTraits);
  }

  function _burnPhoenix(address tokenOwner, uint256 tokenId, uint256 newTraits) internal virtual {
    require(_nextPhoenix != address(0), "phoenix not ready");

    // Burn old Phoenix
    _burn(tokenId);

    // Spawn New Phoenix
    uint256 newTokenId = IPhoenixNFT(_nextPhoenix).spawnFromAshes(tokenOwner, newTraits);

    // Burn Event
    emit PhoenixBurned(tokenOwner, tokenId, _nextPhoenix, newTokenId);
  }

  modifier onlyLastPhoenix(address sender) {
    require(sender == _lastPhoenix, "only last phoenix");
    _;
  }

  modifier onlyNextPhoenix(address sender) {
    require(sender == _nextPhoenix, "only next phoenix");
    _;
  }
}
