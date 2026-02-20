// SPDX-License-Identifier: MIT

// CarbonCoinLauncher.sol
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

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ICarbonCoinLauncher } from "./interface/ICarbonCoinLauncher.sol";
import { ICarbonCoinProtection } from "./interface/ICarbonCoinProtection.sol";
import { ICarbonCoinConfig } from "./interface/ICarbonCoinConfig.sol";
import { ICarbonCoin } from "./interface/ICarbonCoin.sol";
import { CarbonCoin } from "./CarbonCoin.sol";


/**
 * @title CarbonCoinLauncher
 * @author CarbonOpus
 * @notice This contract is responsible for creating and managing CarbonCoin tokens.
 * It allows users to create their own tokens for a fee, and it keeps track of all the tokens created.
 * The owner of the contract can manage the creation fee, the maximum number of tokens per creator, and can pause or unpause the contract.
 * The contract also includes functions for withdrawing fees and transferring ownership.
 */
contract CarbonCoinLauncher is ICarbonCoinLauncher, ReentrancyGuard, Pausable, Ownable {
  /// @notice The address of the CarbonCoinConfig contract, which provides default configurations for new tokens.
  address public configAddress;
  /// @notice The address of the USDC token for payments.
  address public usdcAddress;
  /// @notice The address of the CarbonCoinProtection contract for initializing new tokens with protection features.
  address public protectionAddress;
  /// @notice The address of the controller of the contract.
  address internal _controller;
  /// @notice The maximum number of tokens that a single address can create.
  uint256 public maxTokensPerCreator = 1;

  /// @notice A mapping from a token address to its TokenInfo struct.
  mapping(address => TokenInfo) public tokens;
  /// @notice A mapping from a creator's address to the number of tokens they have created.
  mapping(address => uint256) public tokensCreatedByAddress;
  /// @notice A mapping from a creator's address to an array of token addresses they have created.
  // mapping(address => address[]) public tokensByCreator;
  /// @notice An array of all the token addresses that have been created.
  // address[] public allTokens;

  /// @notice The total number of tokens that have been created.
  uint256 public totalTokensCreated;

  /**
   * @notice The constructor for the CarbonCoinLauncher contract.
   * @param _configAddress The address of the CarbonCoinConfig contract.
   * @param _usdcAddress The address of the USDC token.
   * @param _protectionAddress The address of the CarbonCoinProtection contract.
   */
  constructor(
    address _configAddress,
    address _usdcAddress,
    address _protectionAddress
  ) Ownable(msg.sender) ReentrancyGuard() Pausable() {
    if (_configAddress == address(0) || _usdcAddress == address(0) || _protectionAddress == address(0))
      revert InvalidParameters();

    configAddress = _configAddress;
    usdcAddress = _usdcAddress;
    protectionAddress = _protectionAddress;
    _controller = msg.sender;
  }

  receive() external payable {
    emit NativeFeeReceived(msg.sender, msg.value, block.timestamp);
  }

  function getFeeBalance() public view returns (uint256) {
    return address(this).balance;
  }

  /**
   * @notice Creates a new CarbonCoin token.
   * @param name The name of the token.
   * @param symbol The symbol of the token.
   * @param creatorAddress The address of the creator of the token.
   * @param curveConfig The bonding curve configuration for the token.
   * @return The address of the newly created token.
   */
  function createToken(
    string memory name,
    string memory symbol,
    address creatorAddress,
    ICarbonCoin.BondingCurveConfig memory curveConfig
  ) public nonReentrant whenNotPaused returns (address) {
    if (msg.sender != _controller) revert Unauthorized();
    if (tokensCreatedByAddress[creatorAddress] >= maxTokensPerCreator) revert TooManyTokens();

    CarbonCoin token = new CarbonCoin(
      name,
      symbol,
      creatorAddress,
      usdcAddress,
      configAddress,
      protectionAddress,
      curveConfig
    );

    address tokenAddress = address(token);

    // Initialize protection for this token
    ICarbonCoinProtection(protectionAddress).initializeToken(tokenAddress, creatorAddress);

    tokens[tokenAddress] = TokenInfo({
      tokenAddress: tokenAddress,
      creator: creatorAddress,
      createdAt: block.timestamp,
      graduated: false,
      name: name,
      symbol: symbol
    });

    // allTokens.push(tokenAddress);
    // tokensByCreator[creatorAddress].push(tokenAddress);
    tokensCreatedByAddress[creatorAddress]++;
    totalTokensCreated++;

    emit TokenCreated(
      tokenAddress,
      creatorAddress,
      name,
      symbol,
      block.timestamp
    );
    return tokenAddress;
  }

  /**
   * @notice Marks a token as graduated. This can be called by the token contract itself or by the owner of the launcher contract.
   * @param tokenAddress The address of the token to mark as graduated.
   */
  function markTokenGraduated(address tokenAddress) external {
    require(
      msg.sender == tokenAddress || msg.sender == owner(),
      "Only token or owner can mark graduated"
    );
    if (tokens[tokenAddress].tokenAddress != address(0)) {
      tokens[tokenAddress].graduated = true;
      emit TokenGraduated(tokenAddress, block.timestamp);
    }
  }

  function trackCoinBuy(address coinAddress, address buyer, uint256 usdcAmount, uint256 fee, uint256 tokensOut) external {
    emit TokenBuy(coinAddress, buyer, usdcAmount, fee, tokensOut);
  }

  function trackCoinSell(address coinAddress, address seller, uint256 tokensAmount, uint256 fee, uint256 usdcOut) external {
    emit TokenSell(coinAddress, seller, tokensAmount, fee, usdcOut);
  }

  /**
   * @notice Gets an array of all the token addresses that have been created.
   * @return An array of token addresses.
   */
  // function getAllTokens() external view returns (address[] memory) {
  //   return allTokens;
  // }

  /**
   * @notice Gets an array of all the token addresses that have been created by a specific creator.
   * @param creator The address of the creator.
   * @return An array of token addresses.
   */
  // function getTokensByCreator(address creator) external view returns (address[] memory) {
  //   return tokensByCreator[creator];
  // }

  /**
   * @notice Gets the TokenInfo struct for a specific token.
   * @param tokenAddress The address of the token.
   * @return The TokenInfo struct for the token.
   */
  // function getTokenInfo(address tokenAddress) external view returns (TokenInfo memory) {
  //   return tokens[tokenAddress];
  // }

  /**
   * @notice Gets the total number of tokens that have been created.
   * @return The total number of tokens.
   */
  // function getTokenCount() external view returns (uint256) {
  //   return allTokens.length;
  // }

  /**
   * @notice Gets an array of the most recently created tokens.
   * @param count The number of recent tokens to get.
   * @return An array of token addresses.
   */
  // function getRecentTokens(uint256 count) external view returns (address[] memory) {
  //   uint256 total = allTokens.length;
  //   uint256 returnCount = count > total ? total : count;
  //   address[] memory recent = new address[](returnCount);

  //   for (uint256 i = 0; i < returnCount; i++) {
  //     recent[i] = allTokens[total - 1 - i];
  //   }

  //   return recent;
  // }

  /**
   * @notice Sets the maximum number of tokens that a single address can create.
   * @param _max The new maximum number of tokens.
   */
  function setMaxTokensPerCreator(uint256 _max) external onlyOwner {
    require(_max > 0 && _max <= 100, "Invalid max");
    uint256 oldMax = maxTokensPerCreator;
    maxTokensPerCreator = _max;
    emit MaxTokensPerCreatorUpdated(oldMax, _max, block.timestamp);
  }

  function updateController(address newController) external onlyOwner {
    if (newController == address(0)) revert InvalidAddress(newController);
    _controller = newController;
    emit ControllerUpdated(newController);
  }

  function updateProtectionAddress(address newProtection) external onlyOwner {
    if (newProtection == address(0)) revert InvalidAddress(newProtection);
    protectionAddress = newProtection;
  }

  /**
   * @notice Pauses the contract, which prevents new tokens from being created.
   */
  function pause() external onlyOwner {
    _pause();
    emit LauncherPaused(block.timestamp);
  }

  /**
   * @notice Unpauses the contract, which allows new tokens to be created again.
   */
  function unpause() external onlyOwner {
    _unpause();
    emit LauncherUnpaused(block.timestamp);
  }

  /**
   * @notice Withdraws the fees that have been collected from token creations.
   */
  function withdrawUsdcFees() external onlyOwner {
    IERC20 usdc = IERC20(usdcAddress);
    uint256 balance = usdc.balanceOf(address(this));
    if (balance > 0) {
      require(usdc.transfer(owner(), balance), "Fee transfer failed");
      emit UsdcFeesWithdrawn(owner(), balance, block.timestamp);
    }
  }

  function withdrawNativeFees() external onlyOwner {
    uint256 balance = address(this).balance;
    if (balance > 0) {
      (bool success, ) = payable(owner()).call{value: balance}("");
      require(success, "Fee transfer failed");
      emit NativeFeesWithdrawn(owner(), balance, block.timestamp);
    }
  }
}