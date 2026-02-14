// PermitAndTransfer.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

contract PermitAndTransfer {
  event PermitTransfer(bytes32 indexed senderId, address indexed token, address owner, address spender, uint256 value, bytes32 uuid);

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
    IERC20Permit(token).permit(owner, address(this), amount, deadline, v, r, s);
    require(
      IERC20Permit(token).transferFrom(owner, to, amount),
      "Transfer failed"
    );
    emit PermitTransfer(senderId, token, owner, to, amount, uuid);
  }
}
