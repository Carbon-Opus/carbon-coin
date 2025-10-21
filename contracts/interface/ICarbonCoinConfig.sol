// SPDX-License-Identifier: MIT

// ICarbonCoinConfig.sol
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

interface ICarbonCoinConfig {
  struct FeeConfig {
    uint256 buyFee;
    uint256 sellFee;
    uint256 maxFee;
  }

  struct AntiBotConfig {
    uint256 antiBotDuration;
    uint256 maxBuyAmountEarly;
    uint256 maxWalletPercentage;
    uint256 cooldownPeriod;
    uint256 minBuyAmount;
  }

  struct CircuitBreakerConfig {
    uint256 maxPriceImpact;
    uint256 volatilityWindow;
    uint256 maxVolatilityMoves;
    uint256 circuitBreakerDuration;
  }

  struct WhaleLimitConfig {
    uint256 whaleThreshold;
    uint256 whaleDelay;
    uint256 maxTradeSize;
    uint256 maxSellPercentage;
  }

  event DefaultConfigUpdated(string configType, uint256 timestamp);

  function updateDefaultFeeConfig(FeeConfig memory newConfig) external;

  function updateDefaultAntiBotConfig(AntiBotConfig memory newConfig) external;

  function updateDefaultCircuitBreakerConfig(CircuitBreakerConfig memory newConfig) external;

  function updateDefaultWhaleLimitConfig(WhaleLimitConfig memory newConfig) external;

  function getFeeConfig() external view returns (FeeConfig memory);
  function getAntiBotConfig() external view returns (AntiBotConfig memory);
  function getCircuitBreakerConfig() external view returns (CircuitBreakerConfig memory);
  function getWhaleLimitConfig() external view returns (WhaleLimitConfig memory);

}
