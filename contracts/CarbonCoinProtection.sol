// SPDX-License-Identifier: MIT

// CarbonCoinProtection.sol
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
import { ICarbonCoinProtection } from "./interface/ICarbonCoinProtection.sol";

/**
 * @title CarbonCoinProtection
 * @notice Centralized protection mechanism for all CarbonCoin tokens
 * @dev Handles anti-bot, whale limits, circuit breakers for multiple tokens
 */
contract CarbonCoinProtection is ICarbonCoinProtection, Ownable {
    // Token address => Protection state
    mapping(address => TokenProtectionState) public tokenStates;

    // Token => User => Last buy time
    mapping(address => mapping(address => uint256)) public lastBuyTime;

    // Token => User => Last whale trade time
    mapping(address => mapping(address => uint256)) public lastWhaleTradeTime;

    // Token => User => Whale intent
    mapping(address => mapping(address => WhaleIntent)) public pendingWhaleIntents;

    // Token => User => Blacklisted
    mapping(address => mapping(address => bool)) public isBlacklisted;

    // Token => User => Whitelisted
    mapping(address => mapping(address => bool)) public whitelist;

    address public config;
    address public launcher;

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Initialize protection for a new token
     */
    function initializeToken(address token, address creator) external {
        require(msg.sender == launcher, "Only launcher can call");

        TokenProtectionState storage state = tokenStates[token];
        state.launchTime = block.timestamp;

        // Whitelist creator and launcher
        whitelist[token][creator] = true;
        whitelist[token][launcher] = true;
    }

    /**
     * @notice Check if anti-bot protection should be applied
     */
    function checkAntiBotProtection(
        address token,
        address user,
        uint256 amount,
        bool isBuy
    ) external {
        require(msg.sender == token, "Only token can call");
        require(tx.origin == user, "Contract call not allowed");
        require(!isBlacklisted[token][user], "Blacklisted");

        if (!isBuy) return; // Only apply to buys

        ICarbonCoinConfig.AntiBotConfig memory botConfig = _getAntiBotConfig();
        TokenProtectionState storage state = tokenStates[token];

        // Check early buy limits
        if (block.timestamp < state.launchTime + botConfig.antiBotDuration) {
            require(amount <= botConfig.maxBuyAmountEarly || whitelist[token][user], "Buy amount too high");
        }

        // Check cooldown
        if (!whitelist[token][user]) {
            if (lastBuyTime[token][user] != 0) {
                require(block.timestamp >= lastBuyTime[token][user] + botConfig.cooldownPeriod, "Cooldown active");
            }
        }

        lastBuyTime[token][user] = block.timestamp;
    }

    /**
     * @notice Check circuit breaker status
     */
    function checkCircuitBreaker(address token) external view {
        require(msg.sender == token, "Only token can call");

        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();
        TokenProtectionState storage state = tokenStates[token];

        if (state.circuitBreakerTriggeredAt > 0) {
            if (block.timestamp < state.circuitBreakerTriggeredAt + cbConfig.circuitBreakerDuration) {
                revert CircuitBreakerActive();
            }
        }
    }

    /**
     * @notice Reset circuit breaker if expired
     */
    function resetCircuitBreakerIfExpired(address token) external {
        require(msg.sender == token, "Only token can call");

        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();
        TokenProtectionState storage state = tokenStates[token];

        if (state.circuitBreakerTriggeredAt > 0) {
            if (block.timestamp >= state.circuitBreakerTriggeredAt + cbConfig.circuitBreakerDuration) {
                state.circuitBreakerTriggeredAt = 0;
                emit CircuitBreakerReset(token, block.timestamp);
            }
        }
    }

    /**
     * @notice Check trade size limits
     */
    function checkTradeSizeLimit(address token, address user, uint256 amount) external view {
        require(msg.sender == token, "Only token can call");

        if (whitelist[token][user]) return;

        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();
        require(amount <= whaleConfig.maxTradeSize, "Trade size too large");
    }

    /**
     * @notice Check if whale intent is required and handle it
     * @return requiresIntent Whether a whale intent is required
     * @return canProceed Whether the trade can proceed
     */
    function checkWhaleIntent(
        address token,
        address user,
        uint256 amount,
        bool isBuy
    ) external returns (bool requiresIntent, bool canProceed) {
        require(msg.sender == token, "Only token can call");

        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();

        // Not a whale trade if whitelisted or below threshold
        if (whitelist[token][user] || amount < whaleConfig.whaleThreshold) {
            return (false, true);
        }

        // Check cooldown
        if (lastWhaleTradeTime[token][user] > 0) {
            if (block.timestamp < lastWhaleTradeTime[token][user] + whaleConfig.whaleDelay) {
                revert WhaleDelayActive();
            }
        }

        WhaleIntent storage intent = pendingWhaleIntents[token][user];

        // No intent exists
        if (intent.intentTime == 0) {
            intent.amount = amount;
            intent.intentTime = block.timestamp;
            intent.isBuy = isBuy;
            intent.executed = false;

            emit WhaleIntentRegistered(
                token,
                user,
                amount,
                isBuy,
                block.timestamp + whaleConfig.whaleDelay,
                block.timestamp
            );

            return (true, false);
        }

        // Intent exists but not ready
        if (block.timestamp < intent.intentTime + whaleConfig.whaleDelay) {
            revert WhaleIntentNotReady();
        }

        // Verify intent
        require(intent.isBuy == isBuy, "Intent type mismatch");
        require(!intent.executed, "Intent already executed");
        require(intent.amount == amount, "Amount must match intent");

        // Mark as executed
        intent.executed = true;
        lastWhaleTradeTime[token][user] = block.timestamp;

        emit WhaleTradeExecuted(token, user, amount, isBuy, block.timestamp);

        // Clean up
        delete pendingWhaleIntents[token][user];

        return (true, true);
    }

    /**
     * @notice Track price volatility and trigger circuit breaker if needed
     */
    function trackVolatility(
        address token,
        uint256 currentPrice,
        uint256 /* priceBefore */
    ) external {
        require(msg.sender == token, "Only token can call");

        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();
        TokenProtectionState storage state = tokenStates[token];

        // Reset counter if window expired
        if (block.timestamp > state.lastVolatilityReset + cbConfig.volatilityWindow) {
            state.volatilityMoveCount = 0;
            state.lastVolatilityReset = block.timestamp;
            delete state.recentPrices;
        }

        // Record price snapshot
        state.recentPrices.push(PriceSnapshot({
            price: currentPrice,
            timestamp: block.timestamp
        }));

        uint256 pricesLength = state.recentPrices.length;

        // Check for significant price moves
        if (pricesLength > 1) {
            uint256 lastPrice = state.recentPrices[pricesLength - 2].price;
            uint256 priceChange = currentPrice > lastPrice
                ? ((currentPrice - lastPrice) * 10000) / lastPrice
                : ((lastPrice - currentPrice) * 10000) / lastPrice;

            // Count moves greater than 5%
            if (priceChange > 500) {
                state.volatilityMoveCount++;

                if (state.volatilityMoveCount >= cbConfig.maxVolatilityMoves) {
                    emit VolatilityWarning(token, state.volatilityMoveCount, block.timestamp);
                    _triggerCircuitBreaker(token, "Excessive volatility detected");
                }
            }
        }
    }

    /**
     * @notice Check price impact and trigger circuit breaker if excessive
     */
    function checkPriceImpact(
        address token,
        address user,
        uint256 priceBefore,
        uint256 priceAfter,
        uint256 tradeSize,
        bool isBuy
    ) external {
        require(msg.sender == token, "Only token can call");

        if (whitelist[token][user]) return;

        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();

        // Only check for significant trades (1000+ USDC)
        if (tradeSize < 1000 * 10**6) return;

        uint256 priceImpact;
        if (isBuy) {
            priceImpact = ((priceAfter - priceBefore) * 10000) / priceBefore;
        } else {
            priceImpact = ((priceBefore - priceAfter) * 10000) / priceBefore;
        }

        if (priceImpact > cbConfig.maxPriceImpact) {
            emit HighPriceImpact(token, user, priceImpact, block.timestamp);

            // Trigger circuit breaker for extreme impact
            if (priceImpact > cbConfig.maxPriceImpact * 2) {
                _triggerCircuitBreaker(token, "Excessive price impact");
                revert PriceImpactTooHigh();
            }
        }
    }

    /**
     * @notice Internal function to trigger circuit breaker
     */
    function _triggerCircuitBreaker(address token, string memory reason) internal {
        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();
        TokenProtectionState storage state = tokenStates[token];

        state.circuitBreakerTriggeredAt = block.timestamp;
        emit CircuitBreakerTriggered(token, reason, block.timestamp, cbConfig.circuitBreakerDuration);
    }

    function cancelWhaleIntent(address token, address user) external {
        require(msg.sender == user || msg.sender == owner(), "Unauthorized");

        WhaleIntent storage intent = pendingWhaleIntents[token][user];
        if (intent.intentTime == 0) revert NoWhaleIntentFound();
        require(!intent.executed, "Intent already executed");

        delete pendingWhaleIntents[token][user];
        emit WhaleIntentCancelled(token, user, block.timestamp);
    }

    // View functions
    function getCircuitBreakerStatus(address token) external view returns (
        bool isActive,
        uint256 triggeredAt,
        uint256 timeRemaining,
        uint256 volatilityMoves
    ) {
        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();
        TokenProtectionState storage state = tokenStates[token];

        isActive = state.circuitBreakerTriggeredAt > 0 &&
                   block.timestamp < state.circuitBreakerTriggeredAt + cbConfig.circuitBreakerDuration;
        triggeredAt = state.circuitBreakerTriggeredAt;

        if (isActive) {
            timeRemaining = (state.circuitBreakerTriggeredAt + cbConfig.circuitBreakerDuration) - block.timestamp;
        } else {
            timeRemaining = 0;
        }

        volatilityMoves = state.volatilityMoveCount;
    }

    function getWhaleIntent(address token, address trader) external view returns (
        uint256 amount,
        uint256 intentTime,
        uint256 executeAfter,
        bool isBuy,
        bool executed,
        bool canExecute
    ) {
        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();
        WhaleIntent memory intent = pendingWhaleIntents[token][trader];

        amount = intent.amount;
        intentTime = intent.intentTime;
        executeAfter = intent.intentTime + whaleConfig.whaleDelay;
        isBuy = intent.isBuy;
        executed = intent.executed;
        canExecute = !intent.executed &&
                     intent.intentTime > 0 &&
                     block.timestamp >= intent.intentTime + whaleConfig.whaleDelay;
    }

    function getWhaleCooldown(address token, address trader) external view returns (
        uint256 lastTradeTime,
        uint256 nextTradeAvailable,
        bool canTradeNow
    ) {
        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();
        lastTradeTime = lastWhaleTradeTime[token][trader];

        if (lastTradeTime == 0) {
            canTradeNow = true;
            nextTradeAvailable = block.timestamp;
        } else {
            uint256 availableAt = lastTradeTime + whaleConfig.whaleDelay;
            canTradeNow = block.timestamp >= availableAt;
            nextTradeAvailable = canTradeNow ? block.timestamp : availableAt;
        }
    }

    function getUserCooldown(address token, address user) external view returns (uint256) {
        if (whitelist[token][user]) return 0;
        if (lastBuyTime[token][user] == 0) return 0;

        ICarbonCoinConfig.AntiBotConfig memory botConfig = _getAntiBotConfig();
        uint256 elapsed = block.timestamp - lastBuyTime[token][user];

        if (elapsed >= botConfig.cooldownPeriod) return 0;
        return botConfig.cooldownPeriod - elapsed;
    }

    // Admin functions
    function blacklistAddress(address token, address user, bool blacklisted) external onlyOwner {
        isBlacklisted[token][user] = blacklisted;
        emit AddressBlacklisted(token, user, blacklisted, block.timestamp);
        if (blacklisted) {
            emit BotDetected(token, user, "Manually blacklisted", block.timestamp);
        }
    }

    function addToWhitelist(address token, address user) external onlyOwner {
        whitelist[token][user] = true;
        emit AddressWhitelisted(token, user, true, block.timestamp);
    }

    function removeFromWhitelist(address token, address user) external onlyOwner {
        whitelist[token][user] = false;
        emit AddressWhitelisted(token, user, false, block.timestamp);
    }

    function triggerCircuitBreaker(address token, string memory reason) external onlyOwner {
        _triggerCircuitBreaker(token, reason);
    }

    function resetCircuitBreaker(address token) external onlyOwner {
        TokenProtectionState storage state = tokenStates[token];
        state.circuitBreakerTriggeredAt = 0;
        state.volatilityMoveCount = 0;
        state.lastVolatilityReset = block.timestamp;
        delete state.recentPrices;
        emit CircuitBreakerReset(token, block.timestamp);
    }

    function updateConfig(address newConfig) external onlyOwner {
        require(newConfig != address(0), "Invalid config");
        config = newConfig;
        emit ConfigUpdated(newConfig, block.timestamp);
    }

    function updateLauncher(address newLauncher) external onlyOwner {
        require(newLauncher != address(0), "Invalid launcher");
        launcher = newLauncher;
        emit LauncherUpdated(newLauncher, block.timestamp);
    }

    // Internal helper functions
    function _getAntiBotConfig() internal view returns (ICarbonCoinConfig.AntiBotConfig memory) {
        return ICarbonCoinConfig(config).getAntiBotConfig();
    }

    function _getCircuitBreakerConfig() internal view returns (ICarbonCoinConfig.CircuitBreakerConfig memory) {
        return ICarbonCoinConfig(config).getCircuitBreakerConfig();
    }

    function _getWhaleLimitConfig() internal view returns (ICarbonCoinConfig.WhaleLimitConfig memory) {
        return ICarbonCoinConfig(config).getWhaleLimitConfig();
    }
}
