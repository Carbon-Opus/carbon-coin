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
  FeeConfig internal defaultFeeConfig;
  AntiBotConfig internal defaultAntiBotConfig;
  CircuitBreakerConfig internal defaultCircuitBreakerConfig;
  WhaleLimitConfig internal defaultWhaleLimitConfig;
  address internal carbonCoinDex;

  constructor() Ownable(msg.sender) {
    defaultFeeConfig = FeeConfig({
      buyFee: 100,  // 1%
      sellFee: 100, // 1%
      maxFee: 500   // 5% max
    });

    defaultAntiBotConfig = AntiBotConfig({
      antiBotDuration: 120,               // 120 seconds
      maxBuyAmountEarly: 100 * (10 ** 6), // Max 100 USDC during launch
      maxWalletPercentage: 200,           // 2% of supply
      cooldownPeriod: 15,                 // 15 seconds between buys
      minBuyAmount: 1 * (10 ** 6)         // Prevent dust attacks
    });

    defaultCircuitBreakerConfig = CircuitBreakerConfig({
      maxPriceImpact: 500,                  // 5%
      volatilityWindow: 5 minutes,
      maxVolatilityMoves: 3,
      circuitBreakerDuration: 15 minutes
    });

    defaultWhaleLimitConfig = WhaleLimitConfig({
      whaleThreshold: 1000 * (10 ** 6), // 1000 USDC+ is whale
      whaleDelay: 5 minutes,            // 5 min delay
      maxTradeSize: 2500 * (10 ** 6),   // Max 2500 USDC per trade
      maxSellPercentage: 200            // Max 2% of supply per sell
    });
  }

  function getCarbonCoinDex() external view returns (address) {
    return carbonCoinDex;
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

  function updateDexAddress(address _dex) external onlyOwner {
    require(_dex != address(0), "Invalid DEX address");
    carbonCoinDex = _dex;
    emit DefaultConfigUpdated("Dex", block.timestamp);
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