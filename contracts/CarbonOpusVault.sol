// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
pragma abicoder v2;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { ICarbonOpusVault } from "./interface/ICarbonOpusVault.sol";

interface IUSDC is IERC20, IERC20Permit {}

contract CarbonOpusVault is ICarbonOpusVault, IERC721Receiver, Ownable {
  using SafeERC20 for IUSDC;

  bytes32 constant private TREASURY_ID = bytes32("treasury");

  mapping (bytes32 => uint256) public rewards;
  IUSDC public immutable usdcToken;
  address public carbonOpus;
  address public treasury;

  constructor(address opus, address usdcTokenAddress, address treasuryAddress) Ownable(_msgSender()) {
    require(usdcTokenAddress != address(0), "Invalid token address");
    usdcToken = IUSDC(usdcTokenAddress);
    require(opus != address(0), "Invalid opus");
    require(treasuryAddress != address(0), "Invalid treasury");
    carbonOpus = opus;
    treasury = treasuryAddress;
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
  }

  function updateTreasury(address newTreasury) external onlyOwner {
    require(newTreasury != address(0), "Invalid treasury");
    treasury = newTreasury;
  }

  modifier onlyOpus() {
    if (_msgSender() != carbonOpus) revert OnlyOpusAllowed();
    _;
  }
}
