// PermitAndTransfer.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20Permit {
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract PermitAndTransfer is Ownable {
  mapping(address => bool) public isWhitelisted;

  event PermitTransfer(bytes32 indexed senderId, address indexed token, address owner, address spender, uint256 value, bytes32 uuid);

  constructor() Ownable(msg.sender) {}

  function addToken(address token) external onlyOwner {
    isWhitelisted[token] = true;
  }

  function removeToken(address token) external onlyOwner {
    isWhitelisted[token] = false;
  }

  function permitAndTransfer(
    bytes32 senderId, // for filtering on Events
    bytes32 uuid,     // for matching to a specific order
    address token,    // usdc or other
    address owner,
    address to,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(isWhitelisted[token], "Token not whitelisted");
    IERC20Permit(token).permit(owner, address(this), amount, deadline, v, r, s);
    require(
      IERC20Permit(token).transferFrom(owner, to, amount),
      "Transfer failed"
    );
    emit PermitTransfer(senderId, token, owner, to, amount, uuid);
  }
}
