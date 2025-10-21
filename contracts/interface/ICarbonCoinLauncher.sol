// SPDX-License-Identifier: MIT

// ICarbonCoinLauncher.sol
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

import { ICarbonCoin } from "./ICarbonCoin.sol";

interface ICarbonCoinLauncher {
  struct TokenInfo {
    address tokenAddress;
    address creator;
    uint256 createdAt;
    bool graduated;
    string name;
    string symbol;
  }

  event TokenCreated(
    address indexed tokenAddress,
    address indexed creator,
    string name,
    string symbol,
    uint256 timestamp,
    uint256 creationFee
  );
  event TokenGraduated(
    address indexed tokenAddress,
    address indexed dexPair,
    uint256 timestamp
  );
  event CreationFeeUpdated(uint256 oldFee, uint256 newFee, uint256 timestamp);
  event MaxTokensPerCreatorUpdated(uint256 oldMax, uint256 newMax, uint256 timestamp);
  event LauncherPaused(uint256 timestamp);
  event LauncherUnpaused(uint256 timestamp);
  event FeesWithdrawn(address indexed to, uint256 amount, uint256 timestamp);

  error Unauthorized();
  error InsufficientFee();
  error TooManyTokens();
  error InvalidParameters();

  function createToken(
    string memory name,
    string memory symbol,
    ICarbonCoin.BondingCurveConfig memory curveConfig
  ) external payable returns (address);

  // function getAllTokens() external view returns (address[] memory);

  // function getTokensByCreator(address creator) external view returns (address[] memory);

  // function getTokenInfo(address tokenAddress) external view returns (TokenInfo memory);

  // function getTokenCount() external view returns (uint256);

  // function getRecentTokens(uint256 count) external view returns (address[] memory);

  function setCreationFee(uint256 _fee) external;

  function setMaxTokensPerCreator(uint256 _max) external;

  function withdraw() external;

  function markTokenGraduated(address tokenAddress) external;

  function getStats() external view returns (
    uint256 _totalTokensCreated,
    uint256 _totalFeesCollected,
    uint256 _creationFee
  );
}
