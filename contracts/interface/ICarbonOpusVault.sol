// SPDX-License-Identifier: MIT

// ICarbonOpusVault.sol
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

interface ICarbonOpusVault {
  error OnlyOpusAllowed();
  error NoRewardsToClaim(bytes32 memberId);

  event RewardsClaimed(bytes32 indexed memberId, address indexed receiverAddress, uint256 amount);

  function collectPaymentFromOpus(address buyer, uint256 amount) external;
  function collectPaymentWithPermitFromOpus(address buyer, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
  function recordRewards(uint256 songPrice, uint256 protocolFee, uint256 referralPct, bytes32 artistMemberId, bytes32 referrerMemberId) external;
  function claimRewards(bytes32 memberId, address memberAddress) external;
  function claimTreasuryRewards(address treasuryAddress) external;
}
