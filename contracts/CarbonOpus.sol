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
import { ICarbonOpus } from "./interface/ICarbonOpus.sol";

contract CarbonOpus is ICarbonOpus, ERC1155, Ownable {
    mapping(uint256 => Song) public songs;
    mapping(address => uint256) public rewards;
    mapping(address => uint256[]) private _userTokens;
    uint256 private _nextTokenId;
    uint256 public protocolFee;
    address internal _treasury;
    address internal _priceScaleManager;

    constructor(string memory uri) ERC1155(uri) Ownable(msg.sender) {
        _treasury = msg.sender;
        _priceScaleManager = msg.sender;
        protocolFee = 100; // 1% fee (100 basis points
    }

    function mintMusic(address receiver, uint256 price, uint256 referralPct) external {
        uint256 tokenId = _nextTokenId++;
        songs[tokenId] = Song(receiver, price, referralPct);
        _mint(receiver, tokenId, 1, "");
        emit SongMinted(tokenId, receiver, price, referralPct);
    }

    function purchaseMusic(address receiver, uint256 tokenId, address referrer) external payable {
        Song storage song = songs[tokenId];
        if (song.artist == address(0)) revert SongDoesNotExist(tokenId);
        if (msg.value != song.price) revert IncorrectPrice(song.price, msg.value);

        uint256 protocolAmount = (msg.value * protocolFee) / 10000;
        uint256 referralAmount = (msg.value * song.referralPct) / 10000;
        uint256 artistAmount = msg.value - referralAmount - protocolAmount;

        rewards[_treasury] += protocolAmount;
        if (referrer != address(0) && referrer != receiver) {
            rewards[referrer] += referralAmount;
        } else {
            // If no referrer or referrer is the buyer, artist gets the referral amount
            artistAmount += referralAmount;
            referralAmount = 0;
        }
        rewards[song.artist] += artistAmount;

        emit RewardsDistributed(song.artist, referrer, artistAmount, referralAmount, protocolAmount);
        emit SongPurchased(tokenId, receiver, referrer, msg.value);

        _mint(receiver, tokenId, 1, "");
    }

    function purchaseBatch(address receiver, uint256[] memory tokenIds, address[] memory referrers) external payable {
        if (tokenIds.length != referrers.length) revert InputArrayLengthMismatch();

        uint256 totalCost = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            Song storage song = songs[tokenIds[i]];
            if (song.artist == address(0)) revert SongDoesNotExist(tokenIds[i]);
            totalCost += song.price;
        }

        if (msg.value != totalCost) revert IncorrectPrice(totalCost, msg.value);

        uint256[] memory amounts = new uint256[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            address referrer = referrers[i];
            Song storage song = songs[tokenId];

            uint256 protocolAmount = (song.price * protocolFee) / 10000;
            uint256 referralAmount = (song.price * song.referralPct) / 10000;
            uint256 artistAmount = song.price - referralAmount - protocolAmount;

            rewards[_treasury] += protocolAmount;
            if (referrer != address(0) && referrer != receiver) {
                rewards[referrer] += referralAmount;
            } else {
                artistAmount += referralAmount;
                referralAmount = 0;
            }
            rewards[song.artist] += artistAmount;

            emit RewardsDistributed(song.artist, referrer, artistAmount, referralAmount, protocolAmount);
            emit SongPurchased(tokenId, receiver, referrer, song.price);

            amounts[i] = 1;
        }

        _mintBatch(receiver, tokenIds, amounts, "");
    }

    function claimRewards(address payable receiver) external {
        uint256 amount = rewards[receiver];
        if (amount == 0) revert NoRewardsToClaim(receiver);
        rewards[receiver] = 0;
        (bool success, ) = receiver.call{value: amount}("");
        if (!success) revert TransferFailed();
        emit RewardsClaimed(receiver, amount);
    }

    function musicBalance(address user) external view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory tokenIds = _userTokens[user];
        uint256[] memory balances = new uint256[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            balances[i] = balanceOf(user, tokenIds[i]);
        }
        return (tokenIds, balances);
    }

    function scaleSongPrice(uint256 tokenId, uint256 newPrice) external {
        if (msg.sender != _priceScaleManager) revert NotAuthorized(msg.sender);
        Song storage song = songs[tokenId];
        song.price = newPrice;
        emit SongPriceScaled(tokenId, newPrice);
    }

    function updateSongPrice(uint256 tokenId, uint256 newPrice) external {
        Song storage song = songs[tokenId];
        if (song.artist != msg.sender) revert NotArtist(msg.sender, tokenId);
        song.price = newPrice;
        emit SongPriceUpdated(tokenId, newPrice);
    }

    function updateSongReferralPct(uint256 tokenId, uint256 newPct) external {
        Song storage song = songs[tokenId];
        if (song.artist != msg.sender) revert NotArtist(msg.sender, tokenId);
        if (newPct > 5000) revert ReferralPercentTooHigh(newPct);
        song.referralPct = newPct;
        emit SongReferralPctUpdated(tokenId, newPct);
    }

    function updateProtocolFee(uint256 newFee) external onlyOwner {
        if (newFee < 30 || newFee > 1000) revert InvalidFee(newFee);
        protocolFee = newFee;
        emit ProtocolFeeUpdated(newFee);
    }

    function updateTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert InvalidAddress(newTreasury);
        _treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    function updatePriceScaleManager(address newManager) external onlyOwner {
        if (newManager == address(0)) revert InvalidAddress(newManager);
        _priceScaleManager = newManager;
        emit PriceScaleManagerUpdated(newManager);
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
                    _userTokens[to].push(ids[i]);
                }
            }
        }

        if (to == address(0)) { // Burn
            for (uint256 i = 0; i < ids.length; i++) {
                if (balanceOf(from, ids[i]) == values[i]) {
                    removeTokenFromUser(from, ids[i]);
                }
            }
        }

        super._update(from, to, ids, values);
    }

    function removeTokenFromUser(address user, uint256 tokenId) private {
        uint256[] storage tokenIds = _userTokens[user];
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == tokenId) {
                tokenIds[i] = tokenIds[tokenIds.length - 1];
                tokenIds.pop();
                break;
            }
        }
    }
}