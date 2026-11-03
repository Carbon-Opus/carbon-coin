// SPDX-License-Identifier: MIT

// ICarbonTreasury.sol
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

interface ICarbonTreasury {
    error Unauthorized();
    event PurchaseCompleted(bytes32 indexed memberId, address indexed memberAddress, bytes32 orderId, bytes32 orderType, uint256 price);
    event Withdrawn(address indexed caller, address indexed to, uint256 amount, uint256 timestamp);
    event RewardsClaimed(address indexed vaultAddress, uint256 timestamp);
    event LpRewardsCollected(
        address indexed positionManager,
        uint256 indexed tokenId,
        uint256 amount0,
        uint256 amount1,
        uint256 timestamp
    );

    function purchase(bytes32 memberId, address memberAddress, bytes32 orderId, bytes32 orderType, uint256 price) external;
    function purchaseWithPermit(bytes32 memberId, address memberAddress, bytes32 orderId, bytes32 orderType, uint256 price, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function claimRewards(address vaultAddress) external;
    function withdraw(address to, uint256 amount) external;
    function collectLpRewards(address positionManager, uint256 tokenId) external returns (uint256 amount0, uint256 amount1);
    function collectLpRewardsWithLimits(address positionManager, uint256 tokenId, uint128 amount0Max, uint128 amount1Max) external returns (uint256 amount0, uint256 amount1);
}
