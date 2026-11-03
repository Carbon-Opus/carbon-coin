// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
pragma abicoder v2;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { ICarbonOpusVault } from "./interface/ICarbonOpusVault.sol";
import { ICarbonTreasury } from "./interface/ICarbonTreasury.sol";
import { INonfungiblePositionManager } from "./interface/INonfungiblePositionManager.sol";
import { BlackholePrevention } from "./lib/BlackholePrevention.sol";

interface IUSDC is IERC20, IERC20Permit {}

contract CarbonTreasury is ICarbonTreasury, IERC721Receiver, Ownable, BlackholePrevention {
  using SafeERC20 for IUSDC;

  IUSDC public immutable usdcToken;

  constructor(address usdcTokenAddress) Ownable(_msgSender()) {
    require(usdcTokenAddress != address(0), "Invalid token address");
    usdcToken = IUSDC(usdcTokenAddress);
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external pure override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  function purchase(bytes32 memberId, address memberAddress, bytes32 orderId, bytes32 orderType, uint256 price) external {
    if (msg.sender != memberAddress) revert Unauthorized();
    usdcToken.safeTransferFrom(memberAddress, address(this), price);
    emit PurchaseCompleted(memberId, memberAddress, orderId, orderType, price);
  }

  function purchaseWithPermit(bytes32 memberId, address memberAddress, bytes32 orderId, bytes32 orderType, uint256 price, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
    _collectPaymentWithPermit(memberAddress, price, deadline, v, r, s);
    emit PurchaseCompleted(memberId, memberAddress, orderId, orderType, price);
  }

  function claimRewards(address vaultAddress) external onlyOwner {
    ICarbonOpusVault(vaultAddress).claimTreasuryRewards(address(this));
    emit RewardsClaimed(vaultAddress, block.timestamp);
  }

  function withdraw(address to, uint256 amount) external onlyOwner {
    require(to != address(0), "Invalid recipient");
    usdcToken.safeTransfer(to, amount);
    emit Withdrawn(_msgSender(), to, amount, block.timestamp);
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

  function collectLpRewards(
    address positionManager,
    uint256 tokenId
  ) external onlyOwner returns (uint256 amount0, uint256 amount1) {
    return _collectLpRewards(positionManager, tokenId, type(uint128).max, type(uint128).max);
  }

  function collectLpRewardsWithLimits(
    address positionManager,
    uint256 tokenId,
    uint128 amount0Max,
    uint128 amount1Max
  ) external onlyOwner returns (uint256 amount0, uint256 amount1) {
    return _collectLpRewards(positionManager, tokenId, amount0Max, amount1Max);
  }

  function _collectLpRewards(
    address positionManager,
    uint256 tokenId,
    uint128 amount0Max,
    uint128 amount1Max
  ) internal returns (uint256 amount0, uint256 amount1) {
    require(positionManager != address(0), "Invalid position manager");

    // Enforce that fees flow strictly into the treasury to preserve custody invariants
    INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
      tokenId: tokenId,
      recipient: address(this),
      amount0Max: amount0Max,
      amount1Max: amount1Max
    });

    (amount0, amount1) = INonfungiblePositionManager(positionManager).collect(params);

    emit LpRewardsCollected(positionManager, tokenId, amount0, amount1, block.timestamp);
  }

  function _collectPaymentWithPermit(address memberAddress, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) internal {
    // The permit call is intentionally not wrapped in a try/catch block.
    // A failed permit, due to an invalid signature or any other reason,
    // must cause the transaction to revert. This prevents a potential attack
    // where a malicious actor could bypass the permit check and use a pre-existing
    // allowance by providing a garbage signature. This function must only
    // succeed if the provided permit is valid.
    usdcToken.permit(memberAddress, address(this), amount, deadline, v, r, s);
    usdcToken.safeTransferFrom(memberAddress, address(this), amount);
  }
}
