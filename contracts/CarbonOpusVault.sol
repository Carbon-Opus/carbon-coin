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

  IUSDC public immutable usdcToken;
  address public carbonOpus;

  constructor(address opus, address usdcTokenAddress) Ownable(_msgSender()) {
    require(usdcTokenAddress != address(0), "Invalid token address");
    usdcToken = IUSDC(usdcTokenAddress);
    carbonOpus = opus;
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

  /**
   * @notice Administrative setter to update or authorize the active CarbonOpus contract.
   */
  function updateCarbonOpus(address newOpus) external onlyOwner {
    require(newOpus != address(0), "Invalid address");
    carbonOpus = newOpus;
  }

  modifier onlyOpus() {
    if (_msgSender() != carbonOpus) revert OnlyOpusAllowed();
    _;
  }
}
