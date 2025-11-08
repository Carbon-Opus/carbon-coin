// SPDX-License-Identifier: MIT

// ICarbonOpus.sol
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

interface ICarbonOpus {
    struct Song {
        address artist;
        uint256 price;
        uint256 referralPct;
    }

    error SongDoesNotExist(uint256 tokenId);
    error IncorrectPrice(uint256 expected, uint256 actual);
    error NoRewardsToClaim(address account);
    error TransferFailed();
    error NotArtist(address sender, uint256 tokenId);
    error ReferralPercentTooHigh(uint256 newPct);
    error NotAuthorized(address sender);
    error InvalidFee(uint256 newFee);
    error InvalidAddress(address addr);
    error InputArrayLengthMismatch();

    event RewardsClaimed(address indexed account, uint256 amount);
    event RewardsDistributed(address indexed artist, address indexed referrer, uint256 artistAmount, uint256 referrerAmount, uint256 protocolFee);
    event SongMinted(uint256 indexed tokenId, address indexed artist, uint256 price, uint256 referralPct);
    event SongPurchased(uint256 indexed tokenId, address indexed buyer, address indexed referrer, uint256 price);
    event SongPriceUpdated(uint256 indexed tokenId, uint256 newPrice);
    event SongReferralPctUpdated(uint256 indexed tokenId, uint256 newPct);
    event SongPriceScaled(uint256 indexed tokenId, uint256 newPrice);
    event ProtocolFeeUpdated(uint256 newFee);
    event TreasuryUpdated(address indexed newTreasury);
    event PriceScaleManagerUpdated(address indexed newManager);

    function mintMusic(address receiver, uint256 price, uint256 referralPct) external;
    function purchaseMusic(address receiver, uint256 tokenId, address referrer) external payable;
    function purchaseBatch(address receiver, uint256[] memory tokenIds, address[] memory referrers) external payable;
    function claimRewards(address payable receiver) external;
    function musicBalance(address user) external view returns (uint256[] memory, uint256[] memory);

    function updateSongPrice(uint256 tokenId, uint256 newPrice) external;
    function updateSongReferralPct(uint256 tokenId, uint256 newPct) external;
    function updateProtocolFee(uint256 newFee) external;
    function updateTreasury(address newTreasury) external;
    function updatePriceScaleManager(address newManager) external;
    function scaleSongPrice(uint256 tokenId, uint256 newPrice) external;
    function setURI(string memory newUri) external;
}