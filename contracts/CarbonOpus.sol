// SPDX-License-Identifier: MIT

// CarbonOpus.sol
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

pragma solidity 0.8.28;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Permit, ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { BlackholePrevention } from "./lib/BlackholePrevention.sol";
import { ICarbonOpus } from "./interface/ICarbonOpus.sol";
import { ICarbonTreasury } from "./interface/ICarbonTreasury.sol";
import { ICarbonOpusVault } from "./interface/ICarbonOpusVault.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IUSDC is IERC20, IERC20Permit {}

contract CarbonOpus is ICarbonOpus, ERC1155, Ownable, BlackholePrevention, ReentrancyGuard {
  using SafeERC20 for IUSDC;

  bytes32 constant private TREASURY_ID = bytes32("treasury");

  mapping (address => uint256[]) internal _memberSongsOwned;    // stored by memberAddress
  mapping (bytes32 => uint256[]) internal _memberSongsCreated;  // stored by memberId

  mapping (uint256 => Song) public songs;  // stored by tokenId

  IUSDC public immutable usdcToken;
  address public treasury;
  address public opusVault;
  address internal controller;
  uint256 public protocolFee; // e.g., 100 = 1%
  uint256 private nextTokenId;

  string public name = "Carbon Opus Music";
  string public symbol = "OPUS-M";

  constructor(string memory uri_, address usdcTokenAddress, address treasuryAddress, address opusVaultAddress) ERC1155(uri_) Ownable(_msgSender()) {
    require(usdcTokenAddress != address(0), "Invalid token");
    require(treasuryAddress != address(0), "Invalid treasury");
    nextTokenId = 1;
    protocolFee = 100;
    controller = _msgSender();
    usdcToken = IUSDC(usdcTokenAddress);
    treasury = treasuryAddress;
    opusVault = opusVaultAddress;
  }

  function createMusic(bytes32 memberId, address memberAddress, uint256 price, uint256 referralPct) external {
    if (_msgSender() != controller) revert NotAuthorized(_msgSender());
    if (referralPct > 9999) revert ReferralPercentTooHigh(referralPct);

    // Create new song
    uint256 tokenId = nextTokenId++;
    _memberSongsCreated[memberId].push(tokenId);
    songs[tokenId] = Song(memberId, price, referralPct, false);

    // Mint the song to the artist
    _mint(memberAddress, tokenId, 1, "");
    emit SongCreated(tokenId, memberId, price, referralPct);
  }

  function purchaseMusic(bytes32 memberId, address memberAddress, uint256 tokenId, bytes32 referrer) external nonReentrant {
    // if (_msgSender() != controller) revert NotAuthorized(_msgSender());

    // Check if song exists
    Song storage song = songs[tokenId];
    if (song.memberId == bytes32(0)) revert SongDoesNotExist(tokenId);
    if (song.locked) revert SongLocked(tokenId);

    // Securely pull funds using the isolated Treasury interface
    ICarbonOpusVault(opusVault).collectPaymentFromOpus(_msgSender(), song.price);

    // Finalize purchase & instantly distribute accounting fractions
    _purchaseMusic(memberId, memberAddress, tokenId, referrer);
  }

  function purchaseMusicWithPermit(bytes32 memberId, address memberAddress, uint256 tokenId, bytes32 referrer, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external nonReentrant {
    // if (_msgSender() != controller) revert NotAuthorized(_msgSender());

    // Check if song exists
    Song storage song = songs[tokenId];
    if (song.memberId == bytes32(0)) revert SongDoesNotExist(tokenId);
    if (song.locked) revert SongLocked(tokenId);

    // Securely pull permit signatures inside the isolated money vault
    ICarbonOpusVault(opusVault).collectPaymentWithPermitFromOpus(_msgSender(), song.price, deadline, v, r, s);

    // Finalize purchase & instantly distribute accounting fractions
    _purchaseMusic(memberId, memberAddress, tokenId, referrer);
  }

  function purchaseBatch(bytes32 memberId, address memberAddress, uint256[] memory tokenIds, bytes32[] memory referrers) external nonReentrant {
    // if (_msgSender() != controller) revert NotAuthorized(_msgSender());
    if (tokenIds.length != referrers.length) revert InputArrayLengthMismatch();

    // Collect payment
    uint256 totalCost = _getTotalCostOfBatch(tokenIds);

    // Securely charge via Treasury
    ICarbonOpusVault(opusVault).collectPaymentFromOpus(_msgSender(), totalCost);

    // Process accounting and mint entries
    _purchaseBatch(memberId, memberAddress, tokenIds, referrers);
  }

  function purchaseBatchWithPermit(bytes32 memberId, address memberAddress, uint256[] memory tokenIds, bytes32[] memory referrers, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external nonReentrant {
    // if (_msgSender() != controller) revert NotAuthorized(_msgSender());
    if (tokenIds.length != referrers.length) revert InputArrayLengthMismatch();

    // Collect payment
    uint256 totalCost = _getTotalCostOfBatch(tokenIds);

    // Securely process permit signatures and pull tokens via Treasury
    ICarbonOpusVault(opusVault).collectPaymentWithPermitFromOpus(_msgSender(), totalCost, deadline, v, r, s);

    // Process accounting and mint entries
    _purchaseBatch(memberId, memberAddress, tokenIds, referrers);
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
    if (_msgSender() != controller) revert NotAuthorized(_msgSender());
    Song storage song = songs[tokenId];
    song.price = newPrice;
    emit SongPriceScaled(tokenId, newPrice);
  }

  function updateSongReferralPct(uint256 tokenId, uint256 newPct) external {
    if (_msgSender() != controller) revert NotAuthorized(_msgSender());
    if (newPct > 9999) revert ReferralPercentTooHigh(newPct);
    Song storage song = songs[tokenId];
    song.referralPct = newPct;
    emit SongReferralPctUpdated(tokenId, newPct);
  }

  function updateSongLockStatus(uint256 tokenId, bool locked) external {
    if (_msgSender() != controller && _msgSender() != owner()) revert NotAuthorized(_msgSender());
    Song storage song = songs[tokenId];
    if (song.memberId == bytes32(0)) revert SongDoesNotExist(tokenId);

    song.locked = locked;
    emit SongLockStatusUpdated(tokenId, locked);
  }

  function reassignSong(uint256 tokenId, bytes32 newMemberId, address oldMemberAddress, address newMemberAddress) external {
    if (_msgSender() != controller && _msgSender() != owner()) revert NotAuthorized(_msgSender());
    Song storage song = songs[tokenId];
    if (song.memberId == bytes32(0)) revert SongDoesNotExist(tokenId);

    bytes32 oldMemberId = song.memberId;
    if (oldMemberId == newMemberId) return;

    // Update song creator
    song.memberId = newMemberId;

    // Move tokenId in _memberSongsCreated
    _removeSongFromMemberCreated(oldMemberId, tokenId);
    _memberSongsCreated[newMemberId].push(tokenId);

    // Transfer the minted NFT to the new owner if they have a balance
    uint256 oldBalance = balanceOf(oldMemberAddress, tokenId);
    if (oldBalance > 0) {
      uint256[] memory ids = new uint256[](1);
      ids[0] = tokenId;
      uint256[] memory values = new uint256[](1);
      values[0] = oldBalance;
      _update(oldMemberAddress, newMemberAddress, ids, values);
    }

    emit SongReassigned(tokenId, oldMemberId, newMemberId, newMemberAddress);
  }

  function _removeSongFromMemberCreated(bytes32 memberId, uint256 tokenId) internal {
    uint256[] storage createdSongs = _memberSongsCreated[memberId];
    for (uint256 i = 0; i < createdSongs.length; i++) {
      if (createdSongs[i] == tokenId) {
        createdSongs[i] = createdSongs[createdSongs.length - 1];
        createdSongs.pop();
        break;
      }
    }
  }

  function updateOpusVault(address newVault) external onlyOwner {
    require(newVault != address(0), "Invalid vault");
    opusVault = newVault;
    emit OpusVaultUpdated(newVault, block.timestamp);
  }

  function updateTreasury(address newTreasury) external onlyOwner {
    require(newTreasury != address(0), "Invalid treasury");
    treasury = newTreasury;
    emit TreasuryUpdated(newTreasury, block.timestamp);
  }

  function updateProtocolFee(uint256 newFee) external onlyOwner {
    if (newFee < 30 || newFee > 1000) revert InvalidFee(newFee);
    protocolFee = newFee;
    emit ProtocolFeeUpdated(newFee);
  }

  function updateController(address newController) external onlyOwner {
    if (newController == address(0)) revert InvalidAddress(newController);
    controller = newController;
    emit ControllerUpdated(newController);
  }

  function setURI(string memory newUri) external onlyOwner {
    _setURI(newUri);
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

  function _purchaseMusic(bytes32 memberId, address memberAddress, uint256 tokenId, bytes32 referrer) internal {
    Song memory song = songs[tokenId];

    _mint(memberAddress, tokenId, 1, "");
    _memberSongsOwned[memberAddress].push(tokenId);

    // Instantly calculate and log fractions on-buy to completely bypass historical loops
    ICarbonOpusVault(opusVault).recordRewards(song.price, protocolFee, song.referralPct, song.memberId, referrer);

    emit SongPurchased(tokenId, memberId, referrer, song.price, false);
  }

  function _purchaseBatch(bytes32 memberId, address memberAddress, uint256[] memory tokenIds, bytes32[] memory referrers) internal {
    uint256[] memory amounts = new uint256[](tokenIds.length);

    for (uint256 i = 0; i < tokenIds.length; i++) {
      uint256 tokenId = tokenIds[i];
      Song storage song = songs[tokenId];
      if (song.memberId == bytes32(0)) revert SongDoesNotExist(tokenId);
      if (song.locked) revert SongLocked(tokenId);

      amounts[i] = 1;
      _memberSongsOwned[memberAddress].push(tokenId);
      emit SongPurchased(tokenId, memberId, referrers[i], song.price, true);
    }

    _mintBatch(memberAddress, tokenIds, amounts, "");

    for (uint256 i = 0; i < tokenIds.length; i++) {
      Song storage song = songs[tokenIds[i]];
      ICarbonOpusVault(opusVault).recordRewards(song.price, protocolFee, song.referralPct, song.memberId, referrers[i]);
    }
    emit BatchPurchased(memberAddress, memberId);
  }

  function _getTotalCostOfBatch(uint256[] memory tokenIds) internal view returns (uint256) {
    uint256 totalCost = 0;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      uint256 tokenId = tokenIds[i];
      if (songs[tokenId].memberId == bytes32(0)) revert SongDoesNotExist(tokenId);
      if (songs[tokenId].locked) revert SongLocked(tokenId);
      totalCost += songs[tokenId].price;
    }
    return totalCost;
  }



  function _update(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory values
  ) internal override {
    // If it's a transfer between non-zero addresses, update the ownership mappings
    if (from != address(0) && to != address(0)) {
      for (uint256 i = 0; i < ids.length; i++) {
        uint256 tokenId = ids[i];
        uint256 value = values[i];

        if (balanceOf(from, tokenId) == value) {
          _removeTokenFromUser(from, tokenId);
        }

        if (balanceOf(to, tokenId) == 0) {
          _memberSongsOwned[to].push(tokenId);
        }
      }
    } else if (from == address(0)) { // Mint
      for (uint256 i = 0; i < ids.length; i++) {
        if (balanceOf(to, ids[i]) == 0) {
          _memberSongsOwned[to].push(ids[i]);
        }
      }
    } else if (to == address(0)) { // Burn
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
