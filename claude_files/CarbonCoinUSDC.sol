// SPDX-License-Identifier: MIT

// CarbonCoinUSDC.sol
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
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ICarbonCoin } from "./interface/ICarbonCoin.sol";
import { ICarbonCoinConfig } from "./interface/ICarbonCoinConfig.sol";
import { ISomniaExchangeRouter02 } from "./interface/ISomniaExchangeRouter02.sol";

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
}

contract CarbonCoinUSDC is ICarbonCoin, ERC20, ERC20Permit, ReentrancyGuard, Pausable {
    // Bonding curve parameters (immutable after deployment)
    uint256 public immutable VIRTUAL_USDC;
    uint256 public immutable VIRTUAL_TOKENS;
    uint256 public immutable CREATOR_RESERVE_SUPPLY;
    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable GRADUATION_THRESHOLD;

    // State variables
    uint256 public realUsdcReserves;
    uint256 public realTokenSupply;
    uint256 public immutable launchTime;
    address public immutable creator;
    address public immutable config;
    address public immutable launcher;
    bool public hasGraduated;

    // USDC token and PermitAndTransfer integration
    IERC20 public immutable USDC;
    // address public immutable permitAndTransferContract;

    PriceSnapshot[] public recentPrices;
    uint256 public circuitBreakerTriggeredAt;
    uint256 public volatilityMoveCount;
    uint256 public lastVolatilityReset;
    // uint256 public creatorReserveTokens;

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

    // Events specific to USDC and sponsored transactions
    event SponsoredBuy(
        address indexed buyer,
        uint256 usdcAmount,
        uint256 tokensOut,
        bytes32 indexed uuid,
        uint256 timestamp
    );
    event SponsoredSell(
        address indexed seller,
        uint256 tokensIn,
        uint256 usdcOut,
        bytes32 indexed uuid,
        uint256 timestamp
    );

    /**
     * @notice Constructor for the CarbonCoinUSDC contract.
     * @dev Initializes the token with its name, symbol, creator, USDC address, and Somnia Exchange router.
     * It also whitelists the creator and the launcher contract to bypass certain restrictions.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param _creator The address of the token creator.
     * @param _usdc The address of the USDC token contract.
    //  * @param _permitAndTransfer The address of the PermitAndTransfer contract for gasless transactions.
     * @param _router The address of the Somnia Exchange V2 router.
     * @param _config The address of the token configuration contract.
     * @param bondingCurveConfig The bonding curve parameters.
     */
    constructor(
        string memory name,
        string memory symbol,
        address _creator,
        address _usdc,
        // address _permitAndTransfer,
        address _router,
        address _config,
        BondingCurveConfig memory bondingCurveConfig
    ) ERC20(name, symbol) ERC20Permit(name) {
        // Validate inputs
        require(_creator != address(0), "Invalid creator");
        require(_usdc != address(0), "Invalid USDC address");
        // require(_permitAndTransfer != address(0), "Invalid PermitAndTransfer address");
        require(_router != address(0), "Invalid router");
        require(_config != address(0), "Invalid config");

        creator = _creator;
        launcher = msg.sender;
        config = _config;
        USDC = IERC20(_usdc);
        // permitAndTransferContract = _permitAndTransfer;
        dexRouter = ISomniaExchangeRouter02(_router);
        launchTime = block.timestamp;

        // Set bonding curve config (immutable)
        VIRTUAL_USDC = bondingCurveConfig.virtualEth; // Renamed but same concept
        VIRTUAL_TOKENS = bondingCurveConfig.virtualTokens;
        CREATOR_RESERVE_SUPPLY = bondingCurveConfig.creatorReserve;
        MAX_SUPPLY = bondingCurveConfig.maxSupply;
        GRADUATION_THRESHOLD = bondingCurveConfig.graduationThreshold;

        // Mint creator reserve
        if (CREATOR_RESERVE_SUPPLY > 0) {
            _mint(_creator, CREATOR_RESERVE_SUPPLY);
            emit CreatorReserveMinted(_creator, CREATOR_RESERVE_SUPPLY, block.timestamp);
        }

        // Whitelist creator and launcher from restrictions
        whitelist[_creator] = true;
        whitelist[msg.sender] = true;
        whitelist[_permitAndTransfer] = true; // Whitelist PermitAndTransfer contract

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

    /**
     * @notice Get total supply including creator reserve
     */
    function getTotalMaxSupply() external view returns (uint256) {
        return MAX_SUPPLY + CREATOR_RESERVE_SUPPLY;
    }

    /**
     * @notice Get bonding curve supply (excludes creator reserve)
     */
    function getBondingCurveMaxSupply() external view returns (uint256) {
        return MAX_SUPPLY;
    }

    /**
     * @notice Get the current token price in USDC.
     * @dev Calculates the price based on the bonding curve's virtual and real reserves.
     * @return The current price of one token in USDC (with 6 decimals for USDC).
     */
    function getCurrentPrice() public view returns (uint256) {
        uint256 totalUsdc = VIRTUAL_USDC + realUsdcReserves;
        uint256 totalTokens = VIRTUAL_TOKENS - realTokenSupply;
        // USDC has 6 decimals, so we use 10**6 instead of 10**18
        return (totalUsdc * 10**6) / totalTokens;
    }

    /**
     * @notice Calculate the amount of tokens received for a given USDC input.
     * @dev The calculation is based on the bonding curve formula and includes the buy fee.
     * @param usdcIn The amount of USDC to be spent.
     * @return The amount of tokens that will be received.
     */
    function calculateTokensOut(uint256 usdcIn) public view returns (uint256) {
        if (usdcIn == 0) return 0;

        ICarbonCoinConfig.FeeConfig memory feeConfig = _getFeeConfig();

        uint256 usdcAfterFee = (usdcIn * (10000 - feeConfig.buyFee)) / 10000;

        uint256 k = (VIRTUAL_USDC + realUsdcReserves) * (VIRTUAL_TOKENS - realTokenSupply);
        uint256 newTotalUsdc = VIRTUAL_USDC + realUsdcReserves + usdcAfterFee;
        uint256 newTotalTokens = k / newTotalUsdc;
        uint256 newRealSupply = VIRTUAL_TOKENS - newTotalTokens;

        return newRealSupply - realTokenSupply;
    }

    /**
     * @notice Calculate the amount of USDC needed to buy a specific amount of tokens.
     * @dev The calculation is based on the bonding curve formula and includes the buy fee.
     * @param tokensOut The desired amount of tokens.
     * @return The amount of USDC required to purchase the specified tokens.
     */
    function calculateUsdcIn(uint256 tokensOut) public view returns (uint256) {
        if (tokensOut == 0) return 0;

        ICarbonCoinConfig.FeeConfig memory feeConfig = _getFeeConfig();

        uint256 k = (VIRTUAL_USDC + realUsdcReserves) * (VIRTUAL_TOKENS - realTokenSupply);
        uint256 newRealSupply = realTokenSupply + tokensOut;
        uint256 newTotalTokens = VIRTUAL_TOKENS - newRealSupply;
        uint256 newTotalUsdc = k / newTotalTokens;
        uint256 newUsdcReserves = newTotalUsdc - VIRTUAL_USDC;
        uint256 usdcNeeded = newUsdcReserves - realUsdcReserves;

        return (usdcNeeded * 10000) / (10000 - feeConfig.buyFee);
    }

    /**
     * @notice Calculate the amount of USDC received when selling a specific amount of tokens.
     * @dev The calculation is based on the bonding curve formula and includes the sell fee.
     * @param tokensIn The amount of tokens to be sold.
     * @return The amount of USDC that will be received.
     */
    function calculateUsdcOut(uint256 tokensIn) public view returns (uint256) {
        if (tokensIn == 0) return 0;
        if (tokensIn > realTokenSupply) return 0;

        ICarbonCoinConfig.FeeConfig memory feeConfig = _getFeeConfig();

        uint256 k = (VIRTUAL_USDC + realUsdcReserves) * (VIRTUAL_TOKENS - realTokenSupply);
        uint256 newRealSupply = realTokenSupply - tokensIn;
        uint256 newTotalTokens = VIRTUAL_TOKENS - newRealSupply;
        uint256 newTotalUsdc = k / newTotalTokens;
        uint256 newUsdcReserves = newTotalUsdc - VIRTUAL_USDC;
        uint256 usdcOut = realUsdcReserves - newUsdcReserves;

        return (usdcOut * (10000 - feeConfig.sellFee)) / 10000;
    }

    /**
     * @notice Allows a user to buy tokens with USDC using permit (gasless signature).
     * @dev This is the standard buy function where users pay their own gas.
     * Uses EIP-2612 permit to avoid separate approval transaction.
     * @param usdcAmount The amount of USDC to spend.
     * @param minTokensOut The minimum number of tokens the user is willing to accept.
     * @param deadline The permit signature deadline.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     */
    function buyWithPermit(
        uint256 usdcAmount,
        uint256 minTokensOut,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant whenNotPaused {
        // Inlined antiBotProtection modifier
        require(msg.sender == tx.origin, "Contract call not allowed");
        require(!isBlacklisted[msg.sender], "Blacklisted");

        ICarbonCoinConfig.AntiBotConfig memory botConfig = _getAntiBotConfig();

        if (block.timestamp < launchTime + botConfig.antiBotDuration) {
            require(usdcAmount <= botConfig.maxBuyAmountEarly || whitelist[msg.sender], "Buy amount too high");
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
            require(usdcAmount <= whaleConfig.maxTradeSize, "Trade size too large");
        }

        if (hasGraduated) revert AlreadyGraduated();
        if (usdcAmount < botConfig.minBuyAmount) revert InvalidAmount();

        // Execute permit
        IERC20Permit(address(USDC)).permit(msg.sender, address(this), usdcAmount, deadline, v, r, s);

        // Transfer USDC from user to contract
        require(USDC.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");

        // Check if this is a whale trade
        bool isWhaleTrade = usdcAmount >= whaleConfig.whaleThreshold && !whitelist[msg.sender];

        if (isWhaleTrade) {
            _handleWhaleBuy(msg.sender, usdcAmount, minTokensOut);
            return;
        }

        _executeBuy(msg.sender, usdcAmount, minTokensOut);
    }

    /**
     * @notice Allows a user to buy tokens with USDC (standard approval required).
     * @dev Alternative to buyWithPermit for wallets that don't support permit or for pre-approved USDC.
     * @param usdcAmount The amount of USDC to spend.
     * @param minTokensOut The minimum number of tokens the user is willing to accept.
     */
    function buy(uint256 usdcAmount, uint256 minTokensOut) external nonReentrant whenNotPaused {
        // Inlined antiBotProtection modifier
        require(msg.sender == tx.origin, "Contract call not allowed");
        require(!isBlacklisted[msg.sender], "Blacklisted");

        ICarbonCoinConfig.AntiBotConfig memory botConfig = _getAntiBotConfig();

        if (block.timestamp < launchTime + botConfig.antiBotDuration) {
            require(usdcAmount <= botConfig.maxBuyAmountEarly || whitelist[msg.sender], "Buy amount too high");
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
            require(usdcAmount <= whaleConfig.maxTradeSize, "Trade size too large");
        }

        if (hasGraduated) revert AlreadyGraduated();
        if (usdcAmount < botConfig.minBuyAmount) revert InvalidAmount();

        // Transfer USDC from user to contract (requires prior approval)
        require(USDC.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");

        // Check if this is a whale trade
        bool isWhaleTrade = usdcAmount >= whaleConfig.whaleThreshold && !whitelist[msg.sender];

        if (isWhaleTrade) {
            _handleWhaleBuy(msg.sender, usdcAmount, minTokensOut);
            return;
        }

        _executeBuy(msg.sender, usdcAmount, minTokensOut);
    }

    // /**
    //  * @notice Executes a sponsored buy on behalf of a user (gas paid by backend).
    //  * @dev This function is called by the backend after PermitAndTransfer has moved USDC.
    //  * Only callable by permitAndTransferContract or authorized addresses.
    //  * @param buyer The address receiving the tokens.
    //  * @param usdcAmount The amount of USDC being spent.
    //  * @param minTokensOut The minimum number of tokens to receive.
    //  * @param uuid The unique order identifier for tracking.
    //  */
    // function executeSponsoredBuy(
    //     address buyer,
    //     uint256 usdcAmount,
    //     uint256 minTokensOut,
    //     bytes32 uuid
    // ) external nonReentrant whenNotPaused {
    //     require(
    //         msg.sender == permitAndTransferContract ||
    //         msg.sender == launcher ||
    //         msg.sender == _owner(),
    //         "Unauthorized"
    //     );

    //     // Inlined circuitBreakerCheck
    //     ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();
    //     if (circuitBreakerTriggeredAt > 0) {
    //         if (block.timestamp < circuitBreakerTriggeredAt + cbConfig.circuitBreakerDuration) {
    //             revert CircuitBreakerActive();
    //         } else {
    //             circuitBreakerTriggeredAt = 0;
    //             emit CircuitBreakerReset(block.timestamp);
    //         }
    //     }

    //     if (hasGraduated) revert AlreadyGraduated();

    //     ICarbonCoinConfig.AntiBotConfig memory botConfig = _getAntiBotConfig();
    //     if (usdcAmount < botConfig.minBuyAmount) revert InvalidAmount();

    //     // Note: USDC should already be in this contract from PermitAndTransfer
    //     // We verify the balance increased
    //     uint256 contractBalance = USDC.balanceOf(address(this));
    //     require(contractBalance >= realUsdcReserves + usdcAmount, "Insufficient USDC received");

    //     // Check if whale trade
    //     ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();
    //     bool isWhaleTrade = usdcAmount >= whaleConfig.whaleThreshold && !whitelist[buyer];

    //     if (isWhaleTrade) {
    //         _handleWhaleBuy(buyer, usdcAmount, minTokensOut);
    //     } else {
    //         _executeBuy(buyer, usdcAmount, minTokensOut);
    //     }

    //     uint256 tokensOut = calculateTokensOut(usdcAmount);
    //     emit SponsoredBuy(buyer, usdcAmount, tokensOut, uuid, block.timestamp);
    // }

    /**
     * @notice Internal function to execute a token purchase.
     * @dev This function handles the core logic of a buy transaction.
     * @param buyer The address of the user purchasing tokens.
     * @param usdcAmount The amount of USDC being spent.
     * @param minTokensOut The minimum number of tokens the user is willing to accept.
     */
    function _executeBuy(address buyer, uint256 usdcAmount, uint256 minTokensOut) internal {
        uint256 priceBefore = getCurrentPrice();
        uint256 tokensOut = calculateTokensOut(usdcAmount);
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

        uint256 usdcAfterFee = (usdcAmount * (10000 - feeConfig.buyFee)) / 10000;
        uint256 fee = usdcAmount - usdcAfterFee;

        realUsdcReserves += usdcAfterFee;
        realTokenSupply += tokensOut;

        uint256 priceAfter = getCurrentPrice();

        // Check price impact (skip for small buys and whitelisted)
        if (!whitelist[buyer] && usdcAmount >= 1000 * 10**6) { // 1000 USDC (6 decimals)
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
            require(USDC.transfer(launcher, fee), "Fee transfer failed");
        }

        emit TokensPurchased(
            buyer,
            usdcAmount,
            tokensOut,
            priceAfter,
            realUsdcReserves,
            realTokenSupply,
            block.timestamp
        );

        // Emit periodic price updates for charting
        emit PriceUpdate(priceAfter, realUsdcReserves, realTokenSupply, block.timestamp);

        // Check if graduation threshold reached
        if (realUsdcReserves >= GRADUATION_THRESHOLD) {
            _graduate();
        }
    }

    /**
     * @notice Internal function to handle whale buy transactions.
     * @dev This function enforces a cooldown period and an intent-to-trade mechanism for large buy orders.
     * @param buyer The address of the buyer.
     * @param usdcAmount The amount of USDC being spent.
     * @param minTokensOut The minimum number of tokens the user is willing to accept.
     */
    function _handleWhaleBuy(address buyer, uint256 usdcAmount, uint256 minTokensOut) internal {
        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();

        // Check if whale has cooldown active
        if (lastWhaleTradeTime[buyer] > 0) {
            if (block.timestamp < lastWhaleTradeTime[buyer] + whaleConfig.whaleDelay) {
                revert WhaleDelayActive();
            }
        }

        // Check if there's a pending intent
        WhaleIntent storage intent = pendingWhaleIntents[buyer];

        if (intent.intentTime == 0) {
            // No intent exists, register one
            intent.amount = usdcAmount;
            intent.intentTime = block.timestamp;
            intent.isBuy = true;
            intent.executed = false;

            emit WhaleIntentRegistered(
                buyer,
                usdcAmount,
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
        require(intent.amount == usdcAmount, "Amount must match intent");

        // Execute the trade
        intent.executed = true;
        lastWhaleTradeTime[buyer] = block.timestamp;

        emit WhaleTradeExecuted(buyer, usdcAmount, true, block.timestamp);

        _executeBuy(buyer, usdcAmount, minTokensOut);

        // Clean up intent
        delete pendingWhaleIntents[buyer];
    }

    /**
     * @notice Allows a user to sell tokens for USDC.
     * @dev This function is the main entry point for selling tokens.
     * @param tokensIn The amount of tokens to sell.
     * @param minUsdcOut The minimum amount of USDC the user is willing to accept.
     */
    function sell(uint256 tokensIn, uint256 minUsdcOut) external nonReentrant whenNotPaused {
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

        uint256 usdcOut = calculateUsdcOut(tokensIn);

        // Check if this is a whale trade
        bool isWhaleTrade = usdcOut >= whaleConfig.whaleThreshold && !whitelist[msg.sender];

        if (isWhaleTrade) {
            _handleWhaleSell(msg.sender, tokensIn, minUsdcOut, usdcOut);
            return;
        }

        _executeSell(msg.sender, tokensIn, minUsdcOut, usdcOut);
    }

    // /**
    //  * @notice Executes a sponsored sell on behalf of a user (gas paid by backend).
    //  * @dev This function is called by the backend to execute a sell with sponsored gas.
    //  * @param seller The address selling the tokens.
    //  * @param tokensIn The amount of tokens to sell.
    //  * @param minUsdcOut The minimum amount of USDC to receive.
    //  * @param uuid The unique order identifier for tracking.
    //  */
    // function executeSponsoredSell(
    //     address seller,
    //     uint256 tokensIn,
    //     uint256 minUsdcOut,
    //     bytes32 uuid
    // ) external nonReentrant whenNotPaused {
    //     require(
    //         msg.sender == permitAndTransferContract ||
    //         msg.sender == launcher ||
    //         msg.sender == _owner(),
    //         "Unauthorized"
    //     );

    //     // Inlined circuitBreakerCheck
    //     ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();
    //     if (circuitBreakerTriggeredAt > 0) {
    //         if (block.timestamp < circuitBreakerTriggeredAt + cbConfig.circuitBreakerDuration) {
    //             revert CircuitBreakerActive();
    //         } else {
    //             circuitBreakerTriggeredAt = 0;
    //             emit CircuitBreakerReset(block.timestamp);
    //         }
    //     }

    //     if (hasGraduated) revert AlreadyGraduated();
    //     if (tokensIn == 0) revert InvalidAmount();
    //     if (balanceOf(seller) < tokensIn) revert InvalidAmount();

    //     ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();

    //     // Check sell limits (skip for whitelisted)
    //     if (!whitelist[seller]) {
    //         uint256 maxSellAmount = (realTokenSupply * whaleConfig.maxSellPercentage) / 10000;
    //         if (tokensIn > maxSellAmount) revert SellAmountTooLarge();
    //     }

    //     uint256 usdcOut = calculateUsdcOut(tokensIn);

    //     // Check if whale trade
    //     bool isWhaleTrade = usdcOut >= whaleConfig.whaleThreshold && !whitelist[seller];

    //     if (isWhaleTrade) {
    //         _handleWhaleSell(seller, tokensIn, minUsdcOut, usdcOut);
    //     } else {
    //         _executeSell(seller, tokensIn, minUsdcOut, usdcOut);
    //     }

    //     emit SponsoredSell(seller, tokensIn, usdcOut, uuid, block.timestamp);
    // }

    /**
     * @notice Internal function to execute a token sale.
     * @dev This function handles the core logic of a sell transaction.
     * @param seller The address of the user selling tokens.
     * @param tokensIn The amount of tokens being sold.
     * @param minUsdcOut The minimum amount of USDC the user is willing to accept.
     * @param usdcOut The calculated amount of USDC to be received.
     */
    function _executeSell(address seller, uint256 tokensIn, uint256 minUsdcOut, uint256 usdcOut) internal {
        if (usdcOut < minUsdcOut) revert SlippageTooHigh();
        if (usdcOut > realUsdcReserves) revert InsufficientLiquidity();

        ICarbonCoinConfig.FeeConfig memory feeConfig = _getFeeConfig();
        ICarbonCoinConfig.CircuitBreakerConfig memory cbConfig = _getCircuitBreakerConfig();

        uint256 priceBefore = getCurrentPrice();
        uint256 usdcAfterFee = (usdcOut * (10000 - feeConfig.sellFee)) / 10000;
        uint256 fee = usdcOut - usdcAfterFee;

        realUsdcReserves -= usdcOut;
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

        require(USDC.transfer(seller, usdcAfterFee), "USDC transfer failed");

        // Send fee to launcher
        if (fee > 0) {
            require(USDC.transfer(launcher, fee), "Fee transfer failed");
        }

        emit TokensSold(
            seller,
            tokensIn,
            usdcOut,
            priceAfter,
            realUsdcReserves,
            realTokenSupply,
            block.timestamp
        );

        // Emit periodic price updates for charting
        emit PriceUpdate(priceAfter, realUsdcReserves, realTokenSupply, block.timestamp);
    }

    /**
     * @notice Internal function to handle whale sell transactions.
     */
    function _handleWhaleSell(address seller, uint256 tokensIn, uint256 minUsdcOut, uint256 usdcOut) internal {
        ICarbonCoinConfig.WhaleLimitConfig memory whaleConfig = _getWhaleLimitConfig();

        // Check if whale has cooldown active
        if (lastWhaleTradeTime[seller] > 0) {
            if (block.timestamp < lastWhaleTradeTime[seller] + whaleConfig.whaleDelay) {
                revert WhaleDelayActive();
            }
        }

        // Check if there's a pending intent
        WhaleIntent storage intent = pendingWhaleIntents[seller];

        if (intent.intentTime == 0) {
            // No intent exists, register one
            intent.amount = tokensIn;
            intent.intentTime = block.timestamp;
            intent.isBuy = false;
            intent.executed = false;

            emit WhaleIntentRegistered(
                seller,
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
        lastWhaleTradeTime[seller] = block.timestamp;

        emit WhaleTradeExecuted(seller, tokensIn, false, block.timestamp);

        _executeSell(seller, tokensIn, minUsdcOut, usdcOut);

        // Clean up intent
        delete pendingWhaleIntents[seller];
    }

    /**
     * @notice Graduate to Somnia Exchange with USDC/Token pair.
     * @dev Creates a USDC/Token liquidity pool instead of ETH/Token.
     */
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

        // Approve router to spend tokens and USDC
        _approve(address(this), address(dexRouter), remainingTokens);
        USDC.approve(address(dexRouter), realUsdcReserves);

        // Add liquidity (auto-creates USDC/Token pair)
        uint256 usdcForLiquidity = realUsdcReserves;

        try dexRouter.addLiquidity(
            address(USDC),
            address(this),
            usdcForLiquidity,
            remainingTokens,
            (usdcForLiquidity * 95) / 100, // 5% slippage tolerance
            (remainingTokens * 95) / 100,
            creator, // Send LP Tokens to Creator  OR   address(0), // Burn LP tokens
            block.timestamp + 60
        ) returns (uint amountA, uint amountB, uint) {
            emit Graduated(
                address(this),
                dexPair,
                amountB, // tokens
                amountA, // USDC
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
        if (realUsdcReserves < GRADUATION_THRESHOLD) revert InsufficientLiquidity();
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

        uint256 balance = USDC.balanceOf(address(this));
        require(USDC.transfer(launcher, balance), "Withdrawal failed");

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
        uint256 usdcReserves,
        uint256 tokenSupply,
        uint256 virtualUsdc,
        uint256 virtualTokens
    ) {
        return (realUsdcReserves, realTokenSupply, VIRTUAL_USDC, VIRTUAL_TOKENS);
    }

    function _owner() internal view returns (address) {
      return Ownable(config).owner();
    }

    function _getCreatorReservePct() internal view returns (uint256) {
      return ICarbonCoinConfig(config).getCreatorReservePct();
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

    /**
     * @notice Override _update to prevent creator from selling before graduation
     * @dev This hook is called before any token transfer
     */
    function _update(address from, address to, uint256 amount) internal virtual override {
        // Prevent creator from selling/transferring before graduation
        // Allow minting (from == address(0)) and burning (to == address(0))
        if (from == creator && to != address(0) && !hasGraduated) {
            revert CreatorCannotSellBeforeGraduation();
        }

        super._update(from, to, amount);
    }
}
