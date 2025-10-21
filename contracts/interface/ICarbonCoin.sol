// SPDX-License-Identifier: MIT

// ICarbonCoin.sol
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

interface ICarbonCoin {
  struct BondingCurveConfig {
    uint256 virtualEth;
    uint256 virtualTokens;
    uint256 maxSupply;
    uint256 graduationThreshold;
  }

  struct PriceSnapshot {
    uint256 price;
    uint256 timestamp;
  }

  struct WhaleIntent {
    uint256 amount;
    uint256 intentTime;
    bool isBuy;
    bool executed;
  }

  // Trading events
  event TokensPurchased(
    address indexed buyer,
    uint256 ethIn,
    uint256 tokensOut,
    uint256 newPrice,
    uint256 realEthReserves,
    uint256 realTokenSupply,
    uint256 timestamp
  );
  event TokensSold(
    address indexed seller,
    uint256 tokensIn,
    uint256 ethOut,
    uint256 newPrice,
    uint256 realEthReserves,
    uint256 realTokenSupply,
    uint256 timestamp
  );

  // Lifecycle events
  event TokenDeployed(
    address indexed token,
    address indexed creator,
    string name,
    string symbol,
    uint256 maxSupply,
    uint256 graduationThreshold,
    uint256 timestamp
  );
  event Graduated(
    address indexed token,
    address indexed pair,
    uint256 liquidityTokens,
    uint256 liquidityEth,
    uint256 finalPrice,
    uint256 timestamp
  );

  // Admin events
  event BotDetected(address indexed suspect, string reason, uint256 timestamp);
  event AddressBlacklisted(address indexed account, bool blacklisted, uint256 timestamp);
  event AddressWhitelisted(address indexed account, bool whitelisted, uint256 timestamp);
  event EmergencyWithdraw(address indexed to, uint256 amount, uint256 timestamp);
  event TradingPaused(uint256 timestamp);
  event TradingUnpaused(uint256 timestamp);

  // Circuit breaker events
  event CircuitBreakerTriggered(string reason, uint256 timestamp, uint256 duration);
  event CircuitBreakerReset(uint256 timestamp);
  event HighPriceImpact(address indexed trader, uint256 priceImpact, uint256 timestamp);
  event VolatilityWarning(uint256 moveCount, uint256 timestamp);

  // Whale protection events
  event WhaleIntentRegistered(address indexed trader, uint256 amount, bool isBuy, uint256 executeAfter, uint256 timestamp);
  event WhaleIntentCancelled(address indexed trader, uint256 timestamp);
  event WhaleTradeExecuted(address indexed trader, uint256 amount, bool isBuy, uint256 timestamp);

  // State tracking events
  event PriceUpdate(uint256 price, uint256 ethReserves, uint256 tokenSupply, uint256 timestamp);
  event LiquiditySnapshot(uint256 ethReserves, uint256 tokenSupply, uint256 timestamp);

  error Unauthorized();
  error InvalidAmount();
  error ExceedsMaxSupply();
  error SlippageTooHigh();
  error InsufficientLiquidity();
  error AlreadyGraduated();
  error NotGraduated();
  error CooldownActive();
  error ExceedsMaxWallet();
  error Blacklisted();
  error ContractCallNotAllowed();
  error BuyAmountTooHigh();
  error FeeExceedsMaximum();
  error GraduationCooldownActive();
  error CircuitBreakerActive();
  error PriceImpactTooHigh();
  error ExcessiveVolatility();
  error TradeSizeTooLarge();
  error WhaleDelayActive();
  error WhaleIntentRequired();
  error WhaleIntentNotReady();
  error NoWhaleIntentFound();
  error SellAmountTooLarge();

  function getCurrentPrice() external view returns (uint256);

  function calculateTokensOut(uint256 ethIn) external view returns (uint256);

  function calculateEthIn(uint256 tokensOut) external view returns (uint256);

  function calculateEthOut(uint256 tokensIn) external view returns (uint256);

  function buy(uint256 minTokensOut) external payable;

  function sell(uint256 tokensIn, uint256 minEthOut) external;

  function forceGraduate() external;

  function blacklistAddress(address account, bool blacklisted) external;

  function addToWhitelist(address account) external;

  function removeFromWhitelist(address account) external;

  function pause() external;

  function unpause() external;

  function emergencyWithdraw() external;

  function triggerCircuitBreaker(string memory reason) external;

  function resetCircuitBreaker() external;

  function getCircuitBreakerStatus() external view returns (
    bool isActive,
    uint256 triggeredAt,
    uint256 timeRemaining,
    uint256 volatilityMoves
  );

  function cancelWhaleIntent() external;

  function getWhaleIntent(address trader) external view returns (
    uint256 amount,
    uint256 intentTime,
    uint256 executeAfter,
    bool isBuy,
    bool executed,
    bool canExecute
  );

  function getWhaleCooldown(address trader) external view returns (
    uint256 lastTradeTime,
    uint256 nextTradeAvailable,
    bool canTradeNow
  );

  function getTradeLimits() external view returns (
    uint256 _maxTradeSize,
    uint256 _maxSellPercentage,
    uint256 _whaleThreshold,
    uint256 _whaleDelay,
    uint256 currentMaxSellTokens
  );

  function getAntiBotInfo() external view returns (
    uint256 _launchTime,
    uint256 _timeSinceLaunch,
    bool _antiBotActive,
    uint256 _maxBuyEarly,
    uint256 _cooldownPeriod,
    uint256 _maxWalletPercentage
  );

  function getUserCooldown(address user) external view returns (uint256);

  function getReserves() external view returns (
    uint256 ethReserves,
    uint256 tokenSupply,
    uint256 virtualEth,
    uint256 virtualTokens
  );
}
