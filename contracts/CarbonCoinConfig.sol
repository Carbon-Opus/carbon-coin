// SPDX-License-Identifier: MIT

// CarbonCoinConfig.sol
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

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ICarbonCoinConfig } from "./interface/ICarbonCoinConfig.sol";


contract CarbonCoinConfig is ICarbonCoinConfig, Ownable {
  // Default configurations
  FeeConfig public defaultFeeConfig;
  AntiBotConfig public defaultAntiBotConfig;
  CircuitBreakerConfig public defaultCircuitBreakerConfig;
  WhaleLimitConfig public defaultWhaleLimitConfig;

  constructor() Ownable() {
    defaultFeeConfig = FeeConfig({
      buyFee: 30,  // 0.3%
      sellFee: 30, // 0.3%
      maxFee: 300  // 3% max
    });

    defaultAntiBotConfig = AntiBotConfig({
      antiBotDuration: 60,        // 60 seconds
      maxBuyAmountEarly: 1 ether, // Max 1 ETH during launch
      maxWalletPercentage: 300,   // 3% of supply
      cooldownPeriod: 10,         // 10 seconds between buys
      minBuyAmount: 0.001 ether   // Prevent dust attacks
    });

    defaultCircuitBreakerConfig = CircuitBreakerConfig({
      maxPriceImpact: 1000,           // 10%
      volatilityWindow: 5 minutes,
      maxVolatilityMoves: 5,
      circuitBreakerDuration: 10 minutes
    });

    defaultWhaleLimitConfig = WhaleLimitConfig({
      whaleThreshold: 10 ether,   // 10 ETH+ is whale
      whaleDelay: 2 minutes,      // 2 min delay
      maxTradeSize: 30 ether,     // Max 30 ETH per trade
      maxSellPercentage: 300      // Max 3% of supply per sell
    });
  }

  function getFeeConfig() public view returns (FeeConfig memory) {
    return defaultFeeConfig;
  }

  function getAntiBotConfig() public view returns (AntiBotConfig memory) {
    return defaultAntiBotConfig;
  }

  function getCircuitBreakerConfig() public view returns (CircuitBreakerConfig memory) {
    return defaultCircuitBreakerConfig;
  }

  function getWhaleLimitConfig() public view returns (WhaleLimitConfig memory) {
    return defaultWhaleLimitConfig;
  }

  function updateDefaultFeeConfig(FeeConfig memory newConfig) external onlyOwner {
    require(newConfig.maxFee <= 2000, "Max fee too high");
    require(newConfig.buyFee <= newConfig.maxFee, "Buy fee exceeds max");
    require(newConfig.sellFee <= newConfig.maxFee, "Sell fee exceeds max");

    defaultFeeConfig = newConfig;
    emit DefaultConfigUpdated("Fee", block.timestamp);
  }

  function updateDefaultAntiBotConfig(AntiBotConfig memory newConfig) external onlyOwner {
    require(newConfig.antiBotDuration > 0, "Invalid duration");
    require(newConfig.maxWalletPercentage <= 10000, "Invalid wallet percentage");
    require(newConfig.cooldownPeriod <= 300, "Cooldown too long");
    require(newConfig.minBuyAmount > 0, "Invalid min buy");

    defaultAntiBotConfig = newConfig;
    emit DefaultConfigUpdated("AntiBot", block.timestamp);
  }

  function updateDefaultCircuitBreakerConfig(CircuitBreakerConfig memory newConfig) external onlyOwner {
    require(newConfig.maxPriceImpact > 0 && newConfig.maxPriceImpact <= 5000, "Invalid price impact");
    require(newConfig.volatilityWindow > 0, "Invalid window");
    require(newConfig.maxVolatilityMoves > 0, "Invalid moves");
    require(newConfig.circuitBreakerDuration > 0, "Invalid duration");

    defaultCircuitBreakerConfig = newConfig;
    emit DefaultConfigUpdated("CircuitBreaker", block.timestamp);
  }

  function updateDefaultWhaleLimitConfig(WhaleLimitConfig memory newConfig) external onlyOwner {
    require(newConfig.whaleThreshold > 0, "Invalid threshold");
    require(newConfig.whaleDelay > 0, "Invalid delay");
    require(newConfig.maxTradeSize > 0, "Invalid trade size");
    require(newConfig.maxSellPercentage <= 10000, "Invalid sell percentage");

    defaultWhaleLimitConfig = newConfig;
    emit DefaultConfigUpdated("WhaleLimit", block.timestamp);
  }
}