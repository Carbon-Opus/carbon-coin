// SPDX-License-Identifier: MIT

// CarbonCoin.sol
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
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ICarbonCoin } from "./interface/ICarbonCoin.sol";
import { ICarbonCoinConfig } from "./interface/ICarbonCoinConfig.sol";
import { ISomniaExchangeRouter02 } from "./interface/ISomniaExchangeRouter02.sol";


contract CarbonCoin is ICarbonCoin, ERC20, ReentrancyGuard, Pausable {
    // Bonding curve parameters (immutable after deployment)
    uint256 public immutable VIRTUAL_ETH;
    uint256 public immutable VIRTUAL_TOKENS;
    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable GRADUATION_THRESHOLD;

    // State variables
    uint256 public realEthReserves;
    uint256 public realTokenSupply;
    uint256 public immutable launchTime;
    address public immutable creator;
    address public immutable config;
    address public immutable launcher;
    bool public hasGraduated;

    PriceSnapshot[] public recentPrices;
    uint256 public circuitBreakerTriggeredAt;
    uint256 public volatilityMoveCount;
    uint256 public lastVolatilityReset;

    mapping(address => uint256) public lastBuyTime;
    mapping(address => uint256) public lastWhaleTradeTime;
    mapping(address => WhaleIntent) public pendingWhaleIntents;
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public whitelist;

    // Emergency withdrawal protection
    uint256 public lastGraduationAttempt;
    uint256 public constant GRADUATION_COOLDOWN = 1 hours;

    ISomniaExchangeRouter02 public immutable dexRouter;
    address public dexPair;

    /**
     * @notice Constructor for the CarbonCoin contract.
     * @dev Initializes the token with its name, symbol, creator, and Somnia Exchange router.
     * It also whitelists the creator and the launcher contract to bypass certain restrictions.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param _creator The address of the token creator.
     * @param _router The address of the Somnia Exchange V2 router.
     * @param _config The address of the token configuration contract.
     * @param bondingCurveConfig The bonding curve parameters.
     */
    constructor(
        string memory name,
        string memory symbol,
        address _creator,
        address _router,
        address _config,
        BondingCurveConfig memory bondingCurveConfig
    ) ERC20(name, symbol) {
        // Validate inputs
        require(_creator != address(0), "Invalid creator");
        require(_router != address(0), "Invalid router");
        require(_config != address(0), "Invalid config");

        creator = _creator;
        launcher = msg.sender;
        config = _config;
        dexRouter = ISomniaExchangeRouter02(_router);
        launchTime = block.timestamp;

        // Set bonding curve config (immutable)
        VIRTUAL_ETH = bondingCurveConfig.virtualEth;
        VIRTUAL_TOKENS = bondingCurveConfig.virtualTokens;
        MAX_SUPPLY = bondingCurveConfig.maxSupply;
        GRADUATION_THRESHOLD = bondingCurveConfig.graduationThreshold;

        // Whitelist creator and launcher from restrictions
        whitelist[_creator] = true;
        whitelist[msg.sender] = true;

        // Emit deployment event for indexing
        emit TokenDeployed(
            address(this),
            _creator,
            name,
            symbol,
            MAX_SUPPLY,
            GRADUATION_THRESHOLD,
            block.timestamp
        );
    }

    // Allow receiving ETH
    receive() external payable {
        revert("Use buy() function");
    }

    /**
     * @notice Get the current token price in ETH.
     * @dev Calculates the price based on the bonding curve's virtual and real reserves.
     * @return The current price of one token in ETH.
     */
    function getCurrentPrice() public view returns (uint256) {
        uint256 totalEth = VIRTUAL_ETH + realEthReserves;
        uint256 totalTokens = VIRTUAL_TOKENS - realTokenSupply;
        return (totalEth * 10**18) / totalTokens;
    }

    /**
     * @notice Calculate the amount of tokens received for a given ETH input.
     * @dev The calculation is based on the bonding curve formula and includes the buy fee.
     * @param ethIn The amount of ETH to be spent.
     * @return The amount of tokens that will be received.
     */
    function calculateTokensOut(uint256 ethIn) public view returns (uint256) {
        if (ethIn == 0) return 0;

        ICarbonCoinConfig.FeeConfig memory feeConfig = _getFeeConfig();

        uint256 ethAfterFee = (ethIn * (10000 - feeConfig.buyFee)) / 10000;

        uint256 k = (VIRTUAL_ETH + realEthReserves) * (VIRTUAL_TOKENS - realTokenSupply);
        uint256 newTotalEth = VIRTUAL_ETH + realEthReserves + ethAfterFee;
        uint256 newTotalTokens = k / newTotalEth;
        uint256 newRealSupply = VIRTUAL_TOKENS - newTotalTokens;

        return newRealSupply - realTokenSupply;
    }

    /**
     * @notice Calculate the amount of ETH needed to buy a specific amount of tokens.
     * @dev The calculation is based on the bonding curve formula and includes the buy fee.
     * @param tokensOut The desired amount of tokens.
     * @return The amount of ETH required to purchase the specified tokens.
     */
    function calculateEthIn(uint256 tokensOut) public view returns (uint256) {
        if (tokensOut == 0) return 0;

        ICarbonCoinConfig.FeeConfig memory feeConfig = _getFeeConfig();

        uint256 k = (VIRTUAL_ETH + realEthReserves) * (VIRTUAL_TOKENS - realTokenSupply);
        uint256 newRealSupply = realTokenSupply + tokensOut;
        uint256 newTotalTokens = VIRTUAL_TOKENS - newRealSupply;
        uint256 newTotalEth = k / newTotalTokens;
        uint256 newEthReserves = newTotalEth - VIRTUAL_ETH;
        uint256 ethNeeded = newEthReserves - realEthReserves;

        return (ethNeeded * 10000) / (10000 - feeConfig.buyFee);
    }

    /**
     * @notice Calculate the amount of ETH received when selling a specific amount of tokens.
     * @dev The calculation is based on the bonding curve formula and includes the sell fee.
     * @param tokensIn The amount of tokens to be sold.
     * @return The amount of ETH that will be received.
     */
    function calculateEthOut(uint256 tokensIn) public view returns (uint256) {
        if (tokensIn == 0) return 0;

        ICarbonCoinConfig.FeeConfig memory feeConfig = _getFeeConfig();

        uint256 k = (VIRTUAL_ETH + realEthReserves) * (VIRTUAL_TOKENS - realTokenSupply);
        uint256 newRealSupply = realTokenSupply - tokensIn;
        uint256 newTotalTokens = VIRTUAL_TOKENS - newRealSupply;
        uint256 newTotalEth = k / newTotalTokens;
        uint256 newEthReserves = newTotalEth - VIRTUAL_ETH;
        uint256 ethOut = realEthReserves - newEthReserves;

        return (ethOut * (10000 - feeConfig.sellFee)) / 10000;
    }

    /**
     * @notice Allows a user to buy tokens with ETH.
     * @dev This function is the main entry point for purchasing tokens. It includes anti-bot, circuit breaker, and trade size checks.
     * If the trade is identified as a whale trade, it is delegated to the _handleWhaleBuy function.
     * @param minTokensOut The minimum number of tokens the user is willing to accept for their ETH.
     */
    function buy(uint256 minTokensOut) external payable nonReentrant whenNotPaused {
        // Inlined antiBotProtection modifier
        require(msg.sender == tx.origin, "Contract call not allowed");
        require(!isBlacklisted[msg.sender], "Blacklisted");

        ICarbonCoinConfig.AntiBotConfig memory botConfig = _getAntiBotConfig();

        if (block.timestamp < launchTime + botConfig.antiBotDuration) {
            require(msg.value <= botConfig.maxBuyAmountEarly || whitelist[msg.sender], "Buy amount too high");
        }

        if (!whitelist[msg.sender]) {
            if (lastBuyTime[msg.sender] != 0) {
                require(block.timestamp >= lastBuyTime[msg.sender] + botConfig.cooldownPeriod, "Cooldown active");
            }
        }
        lastBuyTime[msg.sender] = block.timestamp;

        // Inlined circuitBreakerCheck modifier
        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();
        if (circuitBreakerTriggeredAt > 0) {
            if (block.timestamp < circuitBreakerTriggeredAt + cbConfig.circuitBreakerDuration) {
                revert CircuitBreakerActive();
            } else {
                circuitBreakerTriggeredAt = 0;
                emit CircuitBreakerReset(block.timestamp);
            }
        }

        // Inlined tradeSizeCheck modifier
        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();
        if (!whitelist[msg.sender]) {
            require(msg.value <= whaleConfig.maxTradeSize, "Trade size too large");
        }

        if (hasGraduated) revert AlreadyGraduated();

        if (msg.value < botConfig.minBuyAmount) revert InvalidAmount();

        // Check if this is a whale trade
        bool isWhaleTrade = msg.value >= whaleConfig.whaleThreshold && !whitelist[msg.sender];

        if (isWhaleTrade) {
            _handleWhaleBuy(msg.value, minTokensOut);
            return;
        }

        _executeBuy(msg.sender, msg.value, minTokensOut);
    }

    /**
     * @notice Internal function to execute a token purchase.
     * @dev This function handles the core logic of a buy transaction, including calculating tokens out, checking for slippage and max supply,
     * updating reserves, minting tokens, and handling fees.
     * @param buyer The address of the user purchasing tokens.
     * @param ethAmount The amount of ETH being spent.
     * @param minTokensOut The minimum number of tokens the user is willing to accept.
     */
    function _executeBuy(address buyer, uint256 ethAmount, uint256 minTokensOut) internal {
        uint256 priceBefore = getCurrentPrice();
        uint256 tokensOut = calculateTokensOut(ethAmount);
        if (tokensOut < minTokensOut) revert SlippageTooHigh();
        if (realTokenSupply + tokensOut > MAX_SUPPLY) revert ExceedsMaxSupply();

        ICarbonCoinConfig.FeeConfig memory feeConfig = _getFeeConfig();
        ICarbonCoinConfig.AntiBotConfig memory botConfig = _getAntiBotConfig();
        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();

        // Check max wallet before minting (skip for whitelisted)
        if (!whitelist[buyer]) {
            uint256 maxWallet = (MAX_SUPPLY * botConfig.maxWalletPercentage) / 10000;
            if (balanceOf(buyer) + tokensOut > maxWallet) revert ExceedsMaxWallet();
        }

        uint256 ethAfterFee = (ethAmount * (10000 - feeConfig.buyFee)) / 10000;
        uint256 fee = ethAmount - ethAfterFee;

        realEthReserves += ethAfterFee;
        realTokenSupply += tokensOut;

        uint256 priceAfter = getCurrentPrice();

        // Check price impact (skip for small buys and whitelisted)
        if (!whitelist[buyer] && ethAmount >= 1 ether) {
            uint256 priceImpact = ((priceAfter - priceBefore) * 10000) / priceBefore;

            if (priceImpact > cbConfig.maxPriceImpact) {
                emit HighPriceImpact(buyer, priceImpact, block.timestamp);

                // Trigger circuit breaker for extreme impact
                if (priceImpact > cbConfig.maxPriceImpact * 2) {
                    _triggerCircuitBreaker("Excessive price impact");
                    revert PriceImpactTooHigh();
                }
            }
        }

        // Track volatility
        _trackVolatility(priceAfter);

        _mint(buyer, tokensOut);

        // Send fee to launcher
        if (fee > 0) {
            (bool success, ) = payable(launcher).call{value: fee}("");
            require(success, "Fee transfer failed");
        }

        emit TokensPurchased(
            buyer,
            ethAmount,
            tokensOut,
            priceAfter,
            realEthReserves,
            realTokenSupply,
            block.timestamp
        );

        // Emit periodic price updates for charting
        emit PriceUpdate(priceAfter, realEthReserves, realTokenSupply, block.timestamp);

        // Check if graduation threshold reached
        if (realEthReserves >= GRADUATION_THRESHOLD) {
            _graduate();
        }
    }

    /**
     * @notice Internal function to handle whale buy transactions.
     * @dev This function enforces a cooldown period and an intent-to-trade mechanism for large buy orders to prevent manipulation.
     * @param ethAmount The amount of ETH being spent.
     * @param minTokensOut The minimum number of tokens the user is willing to accept.
     */
    function _handleWhaleBuy(uint256 ethAmount, uint256 minTokensOut) internal {
        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();

        // Check if whale has cooldown active
        if (lastWhaleTradeTime[msg.sender] > 0) {
            if (block.timestamp < lastWhaleTradeTime[msg.sender] + whaleConfig.whaleDelay) {
                revert WhaleDelayActive();
            }
        }

        // Check if there's a pending intent
        WhaleIntent storage intent = pendingWhaleIntents[msg.sender];

        if (intent.intentTime == 0) {
            // No intent exists, register one
            intent.amount = ethAmount;
            intent.intentTime = block.timestamp;
            intent.isBuy = true;
            intent.executed = false;

            emit WhaleIntentRegistered(
                msg.sender,
                ethAmount,
                true,
                block.timestamp + whaleConfig.whaleDelay,
                block.timestamp
            );

            revert WhaleIntentRequired();
        }

        // Intent exists, check if enough time has passed
        if (block.timestamp < intent.intentTime + whaleConfig.whaleDelay) {
            revert WhaleIntentNotReady();
        }

        // Verify intent matches current trade
        require(intent.isBuy, "Intent is for sell, not buy");
        require(!intent.executed, "Intent already executed");
        require(intent.amount == ethAmount, "Amount must match intent");

        // Execute the trade
        intent.executed = true;
        lastWhaleTradeTime[msg.sender] = block.timestamp;

        emit WhaleTradeExecuted(msg.sender, ethAmount, true, block.timestamp);

        _executeBuy(msg.sender, ethAmount, minTokensOut);

        // Clean up intent
        delete pendingWhaleIntents[msg.sender];
    }

    /**
     * @notice Allows a user to sell tokens for ETH.
     * @dev This function is the main entry point for selling tokens. It includes checks for graduation, amount, and balance.
     * It also enforces sell limits and delegates to _handleWhaleSell if the trade is large enough.
     * @param tokensIn The amount of tokens to sell.
     * @param minEthOut The minimum amount of ETH the user is willing to accept.
     */
    function sell(uint256 tokensIn, uint256 minEthOut) external nonReentrant whenNotPaused {
        // Inlined circuitBreakerCheck modifier
        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();
        if (circuitBreakerTriggeredAt > 0) {
            if (block.timestamp < circuitBreakerTriggeredAt + cbConfig.circuitBreakerDuration) {
                revert CircuitBreakerActive();
            } else {
                circuitBreakerTriggeredAt = 0;
                emit CircuitBreakerReset(block.timestamp);
            }
        }

        if (hasGraduated) revert AlreadyGraduated();
        if (tokensIn == 0) revert InvalidAmount();
        if (balanceOf(msg.sender) < tokensIn) revert InvalidAmount();

        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();

        // Check sell limits (skip for whitelisted)
        if (!whitelist[msg.sender]) {
            uint256 maxSellAmount = (realTokenSupply * whaleConfig.maxSellPercentage) / 10000;
            if (tokensIn > maxSellAmount) revert SellAmountTooLarge();
        }

        uint256 ethOut = calculateEthOut(tokensIn);

        // Check if this is a whale trade
        bool isWhaleTrade = ethOut >= whaleConfig.whaleThreshold && !whitelist[msg.sender];

        if (isWhaleTrade) {
            _handleWhaleSell(tokensIn, minEthOut, ethOut);
            return;
        }

        _executeSell(msg.sender, tokensIn, minEthOut, ethOut);
    }

    /**
     * @notice Internal function to execute a token sale.
     * @dev This function handles the core logic of a sell transaction, including checking for slippage and liquidity,
     * updating reserves, burning tokens, and transferring ETH to the seller and fees to the launcher.
     * It also checks for price impact and tracks volatility.
     * @param seller The address of the user selling tokens.
     * @param tokensIn The amount of tokens being sold.
     * @param minEthOut The minimum amount of ETH the user is willing to accept.
     * @param ethOut The calculated amount of ETH to be received.
     */
    function _executeSell(address seller, uint256 tokensIn, uint256 minEthOut, uint256 ethOut) internal {
        if (ethOut < minEthOut) revert SlippageTooHigh();
        if (ethOut > realEthReserves) revert InsufficientLiquidity();

        ICarbonCoinConfig.FeeConfig memory feeConfig = _getFeeConfig();
        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();

        uint256 priceBefore = getCurrentPrice();
        uint256 ethAfterFee = (ethOut * (10000 - feeConfig.sellFee)) / 10000;
        uint256 fee = ethOut - ethAfterFee;

        realEthReserves -= ethOut;
        realTokenSupply -= tokensIn;

        uint256 priceAfter = getCurrentPrice();

        // Check price impact for large sells
        if (!whitelist[seller]) {
            uint256 priceImpact = ((priceBefore - priceAfter) * 10000) / priceBefore;

            if (priceImpact > cbConfig.maxPriceImpact) {
                emit HighPriceImpact(seller, priceImpact, block.timestamp);

                // Trigger circuit breaker for extreme impact
                if (priceImpact > cbConfig.maxPriceImpact * 2) {
                    _triggerCircuitBreaker("Excessive negative price impact");
                    revert PriceImpactTooHigh();
                }
            }
        }

        // Track volatility
        _trackVolatility(priceAfter);

        _burn(seller, tokensIn);

        (bool success1, ) = payable(seller).call{value: ethAfterFee}("");
        require(success1, "ETH transfer failed");

        // Send fee to launcher
        if (fee > 0) {
            (bool success2, ) = payable(launcher).call{value: fee}("");
            require(success2, "Fee transfer failed");
        }

        emit TokensSold(
            seller,
            tokensIn,
            ethOut,
            priceAfter,
            realEthReserves,
            realTokenSupply,
            block.timestamp
        );

        // Emit periodic price updates for charting
        emit PriceUpdate(priceAfter, realEthReserves, realTokenSupply, block.timestamp);
    }

    function _handleWhaleSell(uint256 tokensIn, uint256 minEthOut, uint256 ethOut) internal {
        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();

        // Check if whale has cooldown active
        if (lastWhaleTradeTime[msg.sender] > 0) {
            if (block.timestamp < lastWhaleTradeTime[msg.sender] + whaleConfig.whaleDelay) {
                revert WhaleDelayActive();
            }
        }

        // Check if there's a pending intent
        WhaleIntent storage intent = pendingWhaleIntents[msg.sender];

        if (intent.intentTime == 0) {
            // No intent exists, register one
            intent.amount = tokensIn;
            intent.intentTime = block.timestamp;
            intent.isBuy = false;
            intent.executed = false;

            emit WhaleIntentRegistered(
                msg.sender,
                tokensIn,
                false,
                block.timestamp + whaleConfig.whaleDelay,
                block.timestamp
            );

            revert WhaleIntentRequired();
        }

        // Intent exists, check if enough time has passed
        if (block.timestamp < intent.intentTime + whaleConfig.whaleDelay) {
            revert WhaleIntentNotReady();
        }

        // Verify intent matches current trade
        require(!intent.isBuy, "Intent is for buy, not sell");
        require(!intent.executed, "Intent already executed");
        require(intent.amount == tokensIn, "Amount must match intent");

        // Execute the trade
        intent.executed = true;
        lastWhaleTradeTime[msg.sender] = block.timestamp;

        emit WhaleTradeExecuted(msg.sender, tokensIn, false, block.timestamp);

        _executeSell(msg.sender, tokensIn, minEthOut, ethOut);

        // Clean up intent
        delete pendingWhaleIntents[msg.sender];
    }

    // Graduate to Somnia Exchange with protection against griefing
    function _graduate() internal {
        if (hasGraduated) revert AlreadyGraduated();

        // Prevent rapid graduation attempts (griefing protection)
        if (block.timestamp < lastGraduationAttempt + GRADUATION_COOLDOWN) {
            revert GraduationCooldownActive();
        }
        lastGraduationAttempt = block.timestamp;

        hasGraduated = true;

        // Mint remaining tokens for liquidity
        uint256 remainingTokens = MAX_SUPPLY - realTokenSupply;
        _mint(address(this), remainingTokens);

        // Approve router to spend tokens
        _approve(address(this), address(dexRouter), remainingTokens);

        // Add liquidity (auto-creates pair)
        uint256 ethForLiquidity = realEthReserves;

        try dexRouter.addLiquidityETH{value: ethForLiquidity}(
            address(this),
            remainingTokens,
            (remainingTokens * 95) / 100, // 5% slippage tolerance
            (ethForLiquidity * 95) / 100,
            creator, // Send LP Tokens to Creator  OR   address(0), // Burn LP tokens
            block.timestamp + 60
        ) returns (uint amountToken, uint amountETH, uint) {
            emit Graduated(
                address(this),
                dexPair,
                amountToken,
                amountETH,
                getCurrentPrice(),
                block.timestamp
            );

            // Final liquidity snapshot
            emit LiquiditySnapshot(0, 0, block.timestamp);
        } catch {
            // If graduation fails, revert state
            hasGraduated = false;
            _burn(address(this), remainingTokens);
            revert("Graduation failed");
        }
    }

    // Manual graduation with cooldown (emergency only)
    function forceGraduate() external onlyAuthorized {
        if (realEthReserves < GRADUATION_THRESHOLD) revert InsufficientLiquidity();
        _graduate();
    }

    // Admin functions for anti-bot management
    function blacklistAddress(address account, bool blacklisted) external onlyAuthorized {
        isBlacklisted[account] = blacklisted;
        emit AddressBlacklisted(account, blacklisted, block.timestamp);
        if (blacklisted) {
            emit BotDetected(account, "Manually blacklisted", block.timestamp);
        }
    }

    function addToWhitelist(address account) external onlyAuthorized {
        whitelist[account] = true;
        emit AddressWhitelisted(account, true, block.timestamp);
    }

    function removeFromWhitelist(address account) external onlyAuthorized {
        require(account != creator && account != launcher, "Cannot remove core addresses");
        whitelist[account] = false;
        emit AddressWhitelisted(account, false, block.timestamp);
    }

    // Emergency pause (can only be called before graduation)
    function pause() external onlyAuthorized {
        if (hasGraduated) revert AlreadyGraduated();
        _pause();
        emit TradingPaused(block.timestamp);
    }

    function unpause() external onlyAuthorized {
        _unpause();
        emit TradingUnpaused(block.timestamp);
    }

    // Emergency withdrawal (only if something goes wrong before graduation)
    function emergencyWithdraw() external onlyAuthorized {
        if (hasGraduated) revert AlreadyGraduated();
        require(paused(), "Must be paused first");

        uint256 balance = address(this).balance;
        (bool success, ) = payable(launcher).call{value: balance}("");
        require(success, "Withdrawal failed");

        emit EmergencyWithdraw(launcher, balance, block.timestamp);
        emit LiquiditySnapshot(0, 0, block.timestamp);
    }

    // Circuit breaker internal functions
    function _triggerCircuitBreaker(string memory reason) internal {
        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();
        circuitBreakerTriggeredAt = block.timestamp;
        emit CircuitBreakerTriggered(reason, block.timestamp, cbConfig.circuitBreakerDuration);
    }

    function _trackVolatility(uint256 currentPrice) internal {
        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();

        // Reset counter if window expired
        if (block.timestamp > lastVolatilityReset + cbConfig.volatilityWindow) {
            volatilityMoveCount = 0;
            lastVolatilityReset = block.timestamp;
            // Clear old price snapshots
            delete recentPrices;
        }

        // Record price snapshot
        recentPrices.push(PriceSnapshot({
            price: currentPrice,
            timestamp: block.timestamp
        }));

        uint256 pricesLength = recentPrices.length;
        // Check for significant price moves
        if (pricesLength > 1) {
            uint256 lastPrice = recentPrices[pricesLength - 2].price;
            uint256 priceChange = currentPrice > lastPrice
                ? ((currentPrice - lastPrice) * 10000) / lastPrice
                : ((lastPrice - currentPrice) * 10000) / lastPrice;

            // Count moves greater than 5%
            if (priceChange > 500) {
                volatilityMoveCount++;

                if (volatilityMoveCount >= cbConfig.maxVolatilityMoves) {
                    emit VolatilityWarning(volatilityMoveCount, block.timestamp);
                    _triggerCircuitBreaker("Excessive volatility detected");
                }
            }
        }
    }

    // Manual circuit breaker control
    function triggerCircuitBreaker(string memory reason) external onlyAuthorized {
        _triggerCircuitBreaker(reason);
    }

    function resetCircuitBreaker() external onlyAuthorized {
        circuitBreakerTriggeredAt = 0;
        volatilityMoveCount = 0;
        lastVolatilityReset = block.timestamp;
        delete recentPrices;
        emit CircuitBreakerReset(block.timestamp);
    }

    function getCircuitBreakerStatus() external view returns (
        bool isActive,
        uint256 triggeredAt,
        uint256 timeRemaining,
        uint256 volatilityMoves
    ) {
        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();
        uint256 _circuitBreakerTriggeredAt = circuitBreakerTriggeredAt;

        isActive = _circuitBreakerTriggeredAt > 0 &&
                   block.timestamp < _circuitBreakerTriggeredAt + cbConfig.circuitBreakerDuration;
        triggeredAt = _circuitBreakerTriggeredAt;

        if (isActive) {
            timeRemaining = (_circuitBreakerTriggeredAt + cbConfig.circuitBreakerDuration) - block.timestamp;
        } else {
            timeRemaining = 0;
        }

        volatilityMoves = volatilityMoveCount;
    }

    // Whale trade management
    function cancelWhaleIntent() external {
        WhaleIntent storage intent = pendingWhaleIntents[msg.sender];
        if (intent.intentTime == 0) revert NoWhaleIntentFound();
        require(!intent.executed, "Intent already executed");

        delete pendingWhaleIntents[msg.sender];
        emit WhaleIntentCancelled(msg.sender, block.timestamp);
    }

    function getWhaleIntent(address trader) external view returns (
        uint256 amount,
        uint256 intentTime,
        uint256 executeAfter,
        bool isBuy,
        bool executed,
        bool canExecute
    ) {
        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();
        WhaleIntent memory intent = pendingWhaleIntents[trader];
        amount = intent.amount;
        intentTime = intent.intentTime;
        executeAfter = intent.intentTime + whaleConfig.whaleDelay;
        isBuy = intent.isBuy;
        executed = intent.executed;
        canExecute = !intent.executed &&
                     intent.intentTime > 0 &&
                     block.timestamp >= intent.intentTime + whaleConfig.whaleDelay;
    }

    function getWhaleCooldown(address trader) external view returns (
        uint256 lastTradeTime,
        uint256 nextTradeAvailable,
        bool canTradeNow
    ) {
        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();
        lastTradeTime = lastWhaleTradeTime[trader];

        if (lastTradeTime == 0) {
            canTradeNow = true;
            nextTradeAvailable = block.timestamp;
        } else {
            uint256 availableAt = lastTradeTime + whaleConfig.whaleDelay;
            canTradeNow = block.timestamp >= availableAt;
            nextTradeAvailable = canTradeNow ? block.timestamp : availableAt;
        }
    }

    function getTradeLimits() external view returns (
        uint256 _maxTradeSize,
        uint256 _maxSellPercentage,
        uint256 _whaleThreshold,
        uint256 _whaleDelay,
        uint256 currentMaxSellTokens
    ) {
        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();
        return (
            whaleConfig.maxTradeSize,
            whaleConfig.maxSellPercentage,
            whaleConfig.whaleThreshold,
            whaleConfig.whaleDelay,
            (realTokenSupply * whaleConfig.maxSellPercentage) / 10000
        );
    }

    function getAntiBotInfo() external view returns (
        uint256 _launchTime,
        uint256 _timeSinceLaunch,
        bool _antiBotActive,
        uint256 _maxBuyEarly,
        uint256 _cooldownPeriod,
        uint256 _maxWalletPercentage
    ) {
        ICarbonCoinConfig.AntiBotConfig memory botConfig = _getAntiBotConfig();
        return (
            launchTime,
            block.timestamp - launchTime,
            block.timestamp < launchTime + botConfig.antiBotDuration,
            botConfig.maxBuyAmountEarly,
            botConfig.cooldownPeriod,
            botConfig.maxWalletPercentage
        );
    }

    function getUserCooldown(address user) external view returns (uint256) {
        if (whitelist[user]) return 0;
        if (lastBuyTime[user] == 0) return 0;
        ICarbonCoinConfig.AntiBotConfig memory botConfig = _getAntiBotConfig();
        uint256 elapsed = block.timestamp - lastBuyTime[user];
        if (elapsed >= botConfig.cooldownPeriod) return 0;
        return botConfig.cooldownPeriod - elapsed;
    }

    function getReserves() external view returns (
        uint256 ethReserves,
        uint256 tokenSupply,
        uint256 virtualEth,
        uint256 virtualTokens
    ) {
        return (realEthReserves, realTokenSupply, VIRTUAL_ETH, VIRTUAL_TOKENS);
    }

    function _owner() internal view returns (address) {
      return Ownable(config).owner();
    }

    function _getFeeConfig() internal view returns (ICarbonCoinConfig.FeeConfig memory) {
      return ICarbonCoinConfig(config).getFeeConfig();
    }

    function _getAntiBotConfig() internal view returns (ICarbonCoinConfig.AntiBotConfig memory) {
      return ICarbonCoinConfig(config).getAntiBotConfig();
    }

    function _getCircuitBreakerConfig() internal view returns (ICarbonCoinConfig.CircuitBreakerConfig memory) {
      return ICarbonCoinConfig(config).getCircuitBreakerConfig();
    }

    function _getWhaleLimitConfig() internal view returns (ICarbonCoinConfig.WhaleLimitConfig memory) {
      return ICarbonCoinConfig(config).getWhaleLimitConfig();
    }

    modifier onlyAuthorized() {
        if (msg.sender != launcher && msg.sender != _owner() && msg.sender != creator) revert Unauthorized();
        _;
    }

    modifier circuitBreakerCheck() {
        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();

        // Check if circuit breaker is active
        if (circuitBreakerTriggeredAt > 0) {
            if (block.timestamp < circuitBreakerTriggeredAt + cbConfig.circuitBreakerDuration) {
                revert CircuitBreakerActive();
            } else {
                // Reset circuit breaker
                circuitBreakerTriggeredAt = 0;
                emit CircuitBreakerReset(block.timestamp);
            }
        }
        _;
    }

    modifier tradeSizeCheck(uint256 ethAmount, bool isBuy) {
        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();
        // Skip checks for whitelisted addresses
        if (!whitelist[msg.sender]) {
            // Check max trade size
            if (isBuy && ethAmount > whaleConfig.maxTradeSize) {
                revert TradeSizeTooLarge();
            }
        }
        _;
    }

    modifier antiBotProtection(uint256 ethAmount) {
        // Check if caller is a contract (basic check)
        if (msg.sender != tx.origin) revert ContractCallNotAllowed();

        // Check blacklist
        if (isBlacklisted[msg.sender]) revert Blacklisted();

        ICarbonCoinConfig.AntiBotConfig memory botConfig = _getAntiBotConfig();

        // Early launch restrictions (first 60 seconds)
        if (block.timestamp < launchTime + botConfig.antiBotDuration) {
            if (ethAmount > botConfig.maxBuyAmountEarly && !whitelist[msg.sender]) {
                revert BuyAmountTooHigh();
            }
        }

        // Cooldown between buys (skip for whitelisted)
        if (!whitelist[msg.sender]) {
            if (lastBuyTime[msg.sender] != 0 &&
                block.timestamp < lastBuyTime[msg.sender] + botConfig.cooldownPeriod) {
                revert CooldownActive();
            }
        }

        _;

        lastBuyTime[msg.sender] = block.timestamp;
    }
}
