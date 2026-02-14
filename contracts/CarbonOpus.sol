// SPDX-License-Identifier: MIT

// CarbonOpus.sol
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

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICarbonOpus } from "./interface/ICarbonOpus.sol";

contract CarbonOpus is ICarbonOpus, ERC1155, Ownable {
  bytes32 constant private TREASURY_ID = bytes32("treasury");

  mapping (address => uint256[]) internal _memberSongsOwned;    // stored by memberAddress
  mapping (bytes32 => uint256[]) internal _memberSongsCreated;  // stored by memberId

  mapping (uint256 => Song) public songs;  // stored by tokenId
  mapping (bytes32 => uint256) public rewards; // stored by memberId

  IERC20 public usdcToken;
  uint256 public protocolFee;
  uint256 private _nextTokenId;
  address internal _controller;

  string public name = "Carbon Opus Music";
  string public symbol = "OPUS-M";

  constructor(string memory uri, address usdcTokenAddress) ERC1155(uri) Ownable(_msgSender()) {
    _nextTokenId = 1;
    protocolFee = 100; // 1% fee (100 basis points)
    _controller = _msgSender();
    usdcToken = IERC20(usdcTokenAddress);
  }

  function createMusic(bytes32 memberId, address memberAddress, uint256 price, uint256 referralPct) external {
    if (_msgSender() != _controller) revert NotAuthorized(_msgSender());

    // Create new song
    uint256 tokenId = _nextTokenId++;
    _memberSongsCreated[memberId].push(tokenId);
    _memberSongsOwned[memberAddress].push(tokenId);
    songs[tokenId] = Song(memberId, price, referralPct);

    // Mint the song to the artist
    _mint(memberAddress, tokenId, 1, "");

    // Emit event
    emit SongCreated(tokenId, memberId, price, referralPct);
  }

  function purchaseMusic(bytes32 memberId, address memberAddress, uint256 tokenId, bytes32 referrer) external {
    if (_msgSender() != _controller) revert NotAuthorized(_msgSender());

    Song storage song = songs[tokenId];
    if (song.memberId == bytes32(0)) revert SongDoesNotExist(tokenId);

    uint256 price = song.price;
    usdcToken.transferFrom(_msgSender(), address(this), price);

    uint256 protocolAmount = (price * protocolFee) / 10000;
    uint256 referralAmount = (price * song.referralPct) / 10000;
    uint256 artistAmount = price - referralAmount - protocolAmount;

    rewards[TREASURY_ID] += protocolAmount;
    if (referrer != bytes32(0) && referrer != memberId) {
      rewards[referrer] += referralAmount;
    } else {
      // If no referrer or referrer is the buyer, artist gets the referral amount
      artistAmount += referralAmount;
      referralAmount = 0;
    }
    rewards[song.memberId] += artistAmount;

    emit RewardsDistributed(song.memberId, referrer, artistAmount, referralAmount, protocolAmount);
    emit SongPurchased(tokenId, memberId, referrer, price);

    _mint(memberAddress, tokenId, 1, "");
  }

  function purchaseBatch(bytes32 memberId, address memberAddress, uint256[] memory tokenIds, bytes32[] memory referrers) external {
    if (_msgSender() != _controller) revert NotAuthorized(_msgSender());
    if (tokenIds.length != referrers.length) revert InputArrayLengthMismatch();

    uint256 totalCost = 0;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      Song storage song = songs[tokenIds[i]];
      if (song.memberId == bytes32(0)) revert SongDoesNotExist(tokenIds[i]);
      totalCost += song.price;
    }

    usdcToken.transferFrom(_msgSender(), address(this), totalCost);

    uint256[] memory amounts = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      uint256 tokenId = tokenIds[i];
      bytes32 referrer = referrers[i];
      Song storage song = songs[tokenId];

      uint256 protocolAmount = (song.price * protocolFee) / 10000;
      uint256 referralAmount = (song.price * song.referralPct) / 10000;
      uint256 artistAmount = song.price - referralAmount - protocolAmount;

      rewards[TREASURY_ID] += protocolAmount;
      if (referrer != bytes32(0) && referrer != memberId) {
        rewards[referrer] += referralAmount;
      } else {
        artistAmount += referralAmount;
        referralAmount = 0;
      }
      rewards[song.memberId] += artistAmount;

      emit RewardsDistributed(song.memberId, referrer, artistAmount, referralAmount, protocolAmount);
      emit SongPurchased(tokenId, memberId, referrer, song.price);

      amounts[i] = 1;
    }

    _mintBatch(memberAddress, tokenIds, amounts, "");
  }

  function claimRewards(bytes32 memberId, address memberAddress) external {
    if (memberId == TREASURY_ID && (_msgSender() != _controller || _msgSender() != owner())) revert NotAuthorized(_msgSender());
    if (memberId != TREASURY_ID && _msgSender() != _controller) revert NotAuthorized(_msgSender());

    uint256 amount = rewards[memberId];
    if (amount == 0) revert NoRewardsToClaim(memberId);
    rewards[memberId] = 0;
    usdcToken.transfer(memberAddress, amount);
    emit RewardsClaimed(memberId, memberAddress, amount);
  }

  function musicBalance(address memberAddress) external view returns (uint256[] memory, uint256[] memory) {
    uint256[] memory tokenIds = _memberSongsOwned[memberAddress];
    uint256[] memory balances = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      balances[i] = balanceOf(memberAddress, tokenIds[i]);
    }
    return (tokenIds, balances);
  }

  function updateSongPrice(uint256 tokenId, uint256 newPrice) external {
    if (_msgSender() != _controller) revert NotAuthorized(_msgSender());
    Song storage song = songs[tokenId];
    song.price = newPrice;
    emit SongPriceScaled(tokenId, newPrice);
  }

  function updateSongReferralPct(uint256 tokenId, uint256 newPct) external {
    if (_msgSender() != _controller) revert NotAuthorized(_msgSender());
    Song storage song = songs[tokenId];
    if (newPct > 9999) revert ReferralPercentTooHigh(newPct);
    song.referralPct = newPct;
    emit SongReferralPctUpdated(tokenId, newPct);
  }

  function updateProtocolFee(uint256 newFee) external onlyOwner {
    if (newFee < 30 || newFee > 1000) revert InvalidFee(newFee);
    protocolFee = newFee;
    emit ProtocolFeeUpdated(newFee);
  }

  function updateController(address newController) external onlyOwner {
    if (newController == address(0)) revert InvalidAddress(newController);
    _controller = newController;
    emit ControllerUpdated(newController);
  }

  function setURI(string memory newUri) external onlyOwner {
    _setURI(newUri);
  }

  function _update(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory values
  ) internal override {
    // Restrict transfers to only minting and burning
    // if (from != address(0) && to != address(0)) {
    //     revert("Tokens are non-transferable");
    // }

    if (from == address(0)) { // Mint
      for (uint256 i = 0; i < ids.length; i++) {
        if (balanceOf(to, ids[i]) == 0) {
          _memberSongsOwned[to].push(ids[i]);
        }
      }
    }

    if (to == address(0)) { // Burn
      for (uint256 i = 0; i < ids.length; i++) {
        if (balanceOf(from, ids[i]) == values[i]) {
          _removeTokenFromUser(from, ids[i]);
        }
      }
    }

    super._update(from, to, ids, values);
  }

  function _removeTokenFromUser(address user, uint256 tokenId) private {
    uint256[] storage tokenIds = _memberSongsOwned[user];
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (tokenIds[i] == tokenId) {
        tokenIds[i] = tokenIds[tokenIds.length - 1];
        tokenIds.pop();
        break;
      }
    }
  }
}
