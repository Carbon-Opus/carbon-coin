// SPDX-License-Identifier: MIT

// CarbonOpusVault.sol
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

pragma solidity 0.8.28;
pragma abicoder v2;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { ICarbonOpusVault } from "./interface/ICarbonOpusVault.sol";
import { BlackholePrevention } from "./lib/BlackholePrevention.sol";

interface IUSDC is IERC20, IERC20Permit {}

contract CarbonOpusVault is ICarbonOpusVault, IERC721Receiver, Ownable, BlackholePrevention {
  using SafeERC20 for IUSDC;

  bytes32 constant private TREASURY_ID = bytes32("treasury");

  mapping (bytes32 => uint256) public rewards;
  IUSDC public immutable usdcToken;
  address public carbonOpus;
  address public treasury;

  constructor(address usdcTokenAddress, address treasuryAddress) Ownable(_msgSender()) {
    require(usdcTokenAddress != address(0), "Invalid token address");
    require(treasuryAddress != address(0), "Invalid treasury");

    usdcToken = IUSDC(usdcTokenAddress);
    treasury = treasuryAddress;
    carbonOpus = 0x000000000000000000000000000000000000dEaD; // Initialize to dead, will be set immediately after deployment
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external pure override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  /**
   * @notice Securely pulls payment from a buyer to the Treasury on behalf of CarbonOpus.
   * @dev Restricted to the authorized CarbonOpus contract.
   */
  function collectPaymentFromOpus(address buyer, uint256 amount) external onlyOpus {
    usdcToken.safeTransferFrom(buyer, address(this), amount);
  }

  /**
   * @notice Executes an ERC20 permit signature and pulls funds to the Treasury on behalf of CarbonOpus.
   * @dev try/catch block safely bypasses signature front-running mutations in public mempools.
   */
  function collectPaymentWithPermitFromOpus(
    address buyer,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external onlyOpus {
    try usdcToken.permit(buyer, address(this), amount, deadline, v, r, s) {} catch {}
    usdcToken.safeTransferFrom(buyer, address(this), amount);
  }

  function recordRewards(uint256 songPrice, uint256 protocolFee, uint256 referralPct, bytes32 artistMemberId, bytes32 referrerMemberId) external onlyOpus {
    uint256 platformShare = (songPrice * protocolFee) / 10000;
    uint256 remaining = songPrice - platformShare;
    rewards[TREASURY_ID] += platformShare;

    if (referrerMemberId != bytes32(0) && referralPct > 0) {
      uint256 referralShare = (remaining * referralPct) / 10000;
      rewards[referrerMemberId] += referralShare;
      remaining -= referralShare;
    }

    rewards[artistMemberId] += remaining;
  }

  function claimRewards(bytes32 memberId, address memberAddress) external {
    require(_msgSender() == memberAddress, "Unauthorized");

    uint256 amount = rewards[memberId];
    if (amount == 0) revert ICarbonOpusVault.NoRewardsToClaim(memberId);

    rewards[memberId] = 0;
    usdcToken.safeTransfer(memberAddress, amount);

    emit ICarbonOpusVault.RewardsClaimed(memberId, memberAddress, amount);
  }

  function claimTreasuryRewards(address treasuryAddress) external {
    require(_msgSender() == treasury, "Only treasury can claim");
    uint256 amount = rewards[TREASURY_ID];
    if (amount == 0) revert ICarbonOpusVault.NoRewardsToClaim(TREASURY_ID);

    rewards[TREASURY_ID] = 0;
    usdcToken.safeTransfer(treasuryAddress, amount);

    emit ICarbonOpusVault.RewardsClaimed(TREASURY_ID, treasuryAddress, amount);
  }

  /**
   * @notice Administrative setter to update or authorize the active CarbonOpus contract.
   */
  function updateCarbonOpus(address newOpus) external onlyOwner {
    require(newOpus != address(0), "Invalid address");
    carbonOpus = newOpus;
    emit CarbonOpusUpdated(newOpus, block.timestamp);
  }

  function updateTreasury(address newTreasury) external onlyOwner {
    require(newTreasury != address(0), "Invalid treasury");
    treasury = newTreasury;
    emit CarbonTreasuryUpdated(newTreasury, block.timestamp);
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

  modifier onlyOpus() {
    if (_msgSender() != carbonOpus) revert OnlyOpusAllowed();
    _;
  }
}
