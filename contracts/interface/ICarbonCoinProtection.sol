// SPDX-License-Identifier: MIT

// ICarbonCoinProtection.sol
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

interface ICarbonCoinProtection {
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

    struct TokenProtectionState {
        uint256 launchTime;
        uint256 circuitBreakerTriggeredAt;
        uint256 volatilityMoveCount;
        uint256 lastVolatilityReset;
        PriceSnapshot[] recentPrices;
    }

    // Events
    event BotDetected(address indexed token, address indexed user, string reason, uint256 timestamp);
    event AddressBlacklisted(address indexed token, address indexed user, bool blacklisted, uint256 timestamp);
    event AddressWhitelisted(address indexed token, address indexed user, bool whitelisted, uint256 timestamp);
    event CircuitBreakerTriggered(address indexed token, string reason, uint256 timestamp, uint256 duration);
    event CircuitBreakerReset(address indexed token, uint256 timestamp);
    event VolatilityWarning(address indexed token, uint256 moveCount, uint256 timestamp);
    event HighPriceImpact(address indexed token, address indexed trader, uint256 impact, uint256 timestamp);
    event WhaleIntentRegistered(address indexed token, address indexed trader, uint256 amount, bool isBuy, uint256 executeAfter, uint256 timestamp);
    event WhaleTradeExecuted(address indexed token, address indexed trader, uint256 amount, bool isBuy, uint256 timestamp);
    event WhaleIntentCancelled(address indexed token, address indexed trader, uint256 timestamp);
    event ConfigUpdated(address indexed newConfig, uint256 timestamp);
    event LauncherUpdated(address indexed newLauncher, uint256 timestamp);

    // Custom errors
    error WhaleDelayActive();
    error WhaleIntentRequired();
    error WhaleIntentNotReady();
    error NoWhaleIntentFound();
    error CircuitBreakerActive();
    error PriceImpactTooHigh();
    error Unauthorized();

    /**
     * @notice Initialize protection for a new token
     */
    function initializeToken(address token, address creator) external;

    /**
     * @notice Check if anti-bot protection should be applied
     */
    function checkAntiBotProtection(
        address token,
        address user,
        uint256 amount,
        bool isBuy
    ) external;

    /**
     * @notice Check circuit breaker status
     */
    function checkCircuitBreaker(address token) external view;

    /**
     * @notice Reset circuit breaker if expired
     */
    function resetCircuitBreakerIfExpired(address token) external;

    /**
     * @notice Check trade size limits
     */
    function checkTradeSizeLimit(address token, address user, uint256 amount) external view;

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
    ) external returns (bool requiresIntent, bool canProceed);

    /**
     * @notice Track price volatility and trigger circuit breaker if needed
     */
    function trackVolatility(
        address token,
        uint256 currentPrice,
        uint256 priceBefore
    ) external;

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
    ) external;

    function cancelWhaleIntent(address token, address user) external;

    // View functions
    function getCircuitBreakerStatus(address token) external view returns (
        bool isActive,
        uint256 triggeredAt,
        uint256 timeRemaining,
        uint256 volatilityMoves
    );

    function getWhaleIntent(address token, address trader) external view returns (
        uint256 amount,
        uint256 intentTime,
        uint256 executeAfter,
        bool isBuy,
        bool executed,
        bool canExecute
    );

    function getWhaleCooldown(address token, address trader) external view returns (
        uint256 lastTradeTime,
        uint256 nextTradeAvailable,
        bool canTradeNow
    );

    function getUserCooldown(address token, address user) external view returns (uint256);
}
