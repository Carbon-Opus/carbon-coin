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
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit, ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ICarbonCoin } from "./interface/ICarbonCoin.sol";
import { ICarbonCoinLauncher } from "./interface/ICarbonCoinLauncher.sol";
import { ICarbonCoinConfig } from "./interface/ICarbonCoinConfig.sol";
import { ICarbonCoinDex } from "./interface/ICarbonCoinDex.sol";
import { ICarbonCoinProtection } from "./interface/ICarbonCoinProtection.sol";

contract CarbonCoin is ICarbonCoin, ERC20, ERC20Permit, ReentrancyGuard, Pausable {
    // Bonding curve parameters (immutable after deployment)
    uint256 public immutable VIRTUAL_USDC;
    uint256 public immutable VIRTUAL_TOKENS;
    uint256 public immutable CREATOR_RESERVE_SUPPLY;
    uint256 public immutable LIQUIDITY_SUPPLY;
    uint256 public immutable CURVE_SUPPLY;
    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable GRADUATION_THRESHOLD;

    // State variables
    uint256 public realUsdcReserves;
    uint256 public realTokenSupply;
    uint256 public immutable launchTime;
    address public immutable creator;
    address public immutable config;
    address public immutable launcher;
    address public immutable protection;
    bool public hasGraduated;

    // USDC token integration
    IERC20 public immutable USDC;

    // Emergency withdrawal protection
    uint256 public lastGraduationAttempt;
    uint256 public constant GRADUATION_COOLDOWN = 1 hours;

    /**
     * @notice Constructor for the CarbonCoinUSDC contract.
     * @dev Initializes the token with its name, symbol, creator, USDC address, and Somnia Exchange router.
     * It also whitelists the creator and the launcher contract to bypass certain restrictions.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param _creator The address of the token creator.
     * @param _usdc The address of the USDC token contract.
     * @param _config The address of the token configuration contract.
     * @param _protection The address of the token protection contract.
     * @param bondingCurveConfig The bonding curve parameters.
     */
    constructor(
        string memory name,
        string memory symbol,
        address _creator,
        address _usdc,
        address _config,
        address _protection,
        BondingCurveConfig memory bondingCurveConfig
    ) ERC20(name, symbol) ERC20Permit(name) {
        // Validate inputs
        require(_creator != address(0), "Invalid creator");
        require(_usdc != address(0), "Invalid USDC address");
        require(_config != address(0), "Invalid config");
        require(_protection != address(0), "Invalid protection");

        creator = _creator;
        launcher = msg.sender;
        config = _config;
        protection = _protection;
        USDC = IERC20(_usdc);
        launchTime = block.timestamp;

        // Set bonding curve config (immutable)
        VIRTUAL_USDC = bondingCurveConfig.virtualUsdc;
        VIRTUAL_TOKENS = bondingCurveConfig.virtualTokens;
        CREATOR_RESERVE_SUPPLY = bondingCurveConfig.creatorReserve;
        LIQUIDITY_SUPPLY = bondingCurveConfig.liquiditySupply;
        CURVE_SUPPLY = bondingCurveConfig.curveSupply;
        MAX_SUPPLY = bondingCurveConfig.maxSupply;
        GRADUATION_THRESHOLD = bondingCurveConfig.graduationThreshold;

        // Mint creator reserve
        if (CREATOR_RESERVE_SUPPLY > 0) {
            _mint(_creator, CREATOR_RESERVE_SUPPLY);
            emit CreatorReserveMinted(_creator, CREATOR_RESERVE_SUPPLY, block.timestamp);
        }

        // Emit deployment event for indexing
        emit TokenDeployed(
            address(this),
            creator,
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
        return MAX_SUPPLY;
    }

    /**
     * @notice Get bonding curve supply (excludes creator reserve)
     */
    function getBondingCurveMaxSupply() external view returns (uint256) {
        return CURVE_SUPPLY;
    }

    /**
     * @notice Get the liquidity supply for the bonding curve.
     * @dev This determines how much of the total supply is allocated to liquidity vs creator reserve.
     * @return The liquidity supply amount.
     */
    function getLiquiditySupply() external view returns (uint256) {
        return LIQUIDITY_SUPPLY;
    }

    /**
     * @notice Get the current token price in USDC.
     * @dev Calculates the price based on the bonding curve's virtual and real reserves.
     * @return The current price of one token in USDC (with 6 decimals for USDC).
     */
    function getCurrentPrice() public view returns (uint256) {
        uint256 totalUsdc = VIRTUAL_USDC + realUsdcReserves;
        uint256 totalTokens = VIRTUAL_TOKENS - realTokenSupply;
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
        // Protection checks
        ICarbonCoinProtection(protection).checkAntiBotProtection(address(this), msg.sender, usdcAmount, true);
        ICarbonCoinProtection(protection).checkCircuitBreaker(address(this));
        ICarbonCoinProtection(protection).checkTradeSizeLimit(address(this), msg.sender, usdcAmount);

        ICarbonCoinConfig.AntiBotConfig memory botConfig = _getAntiBotConfig();
        if (hasGraduated) revert AlreadyGraduated();
        if (usdcAmount < botConfig.minBuyAmount) revert InvalidAmount();

        // Execute permit
        IERC20Permit(address(USDC)).permit(msg.sender, address(this), usdcAmount, deadline, v, r, s);
        require(USDC.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");

        // Check whale intent
        (bool requiresIntent, bool canProceed) = ICarbonCoinProtection(protection).checkWhaleIntent(
            address(this),
            msg.sender,
            usdcAmount,
            true
        );

        if (requiresIntent && !canProceed) {
            revert WhaleIntentRequired();
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
        // Protection checks
        ICarbonCoinProtection(protection).checkAntiBotProtection(address(this), msg.sender, usdcAmount, true);
        ICarbonCoinProtection(protection).checkCircuitBreaker(address(this));
        ICarbonCoinProtection(protection).checkTradeSizeLimit(address(this), msg.sender, usdcAmount);

        ICarbonCoinConfig.AntiBotConfig memory botConfig = _getAntiBotConfig();
        if (hasGraduated) revert AlreadyGraduated();
        if (usdcAmount < botConfig.minBuyAmount) revert InvalidAmount();

        require(USDC.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");

        // Check whale intent
        (bool requiresIntent, bool canProceed) = ICarbonCoinProtection(protection).checkWhaleIntent(
            address(this),
            msg.sender,
            usdcAmount,
            true
        );

        if (requiresIntent && !canProceed) {
            revert WhaleIntentRequired();
        }

        _executeBuy(msg.sender, usdcAmount, minTokensOut);
    }

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
        if (realTokenSupply + tokensOut > CURVE_SUPPLY) revert ExceedsMaxSupply();

        ICarbonCoinConfig.FeeConfig memory feeConfig = _getFeeConfig();

        uint256 usdcAfterFee = (usdcAmount * (10000 - feeConfig.buyFee)) / 10000;
        uint256 fee = usdcAmount - usdcAfterFee;

        realUsdcReserves += usdcAfterFee;
        realTokenSupply += tokensOut;

        uint256 priceAfter = getCurrentPrice();

        // Check price impact through protection contract
        ICarbonCoinProtection(protection).checkPriceImpact(
            address(this),
            buyer,
            priceBefore,
            priceAfter,
            usdcAmount,
            true
        );

        // Track volatility
        ICarbonCoinProtection(protection).trackVolatility(address(this), priceAfter, priceBefore);

        _mint(buyer, tokensOut);

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

        emit PriceUpdate(priceAfter, realUsdcReserves, realTokenSupply, block.timestamp);

        if (realUsdcReserves >= GRADUATION_THRESHOLD) {
            _graduate();
        }
    }

    /**
     * @notice Allows a user to sell tokens for USDC.
     * @dev This function is the main entry point for selling tokens.
     * @param tokensIn The amount of tokens to sell.
     * @param minUsdcOut The minimum amount of USDC the user is willing to accept.
     */
    function sell(uint256 tokensIn, uint256 minUsdcOut) external nonReentrant whenNotPaused {
        ICarbonCoinProtection(protection).checkCircuitBreaker(address(this));

        if (hasGraduated) revert AlreadyGraduated();
        if (tokensIn == 0) revert InvalidAmount();
        if (balanceOf(msg.sender) < tokensIn) revert InvalidAmount();

        uint256 usdcOut = calculateUsdcOut(tokensIn);

        // Check whale intent
        (bool requiresIntent, bool canProceed) = ICarbonCoinProtection(protection).checkWhaleIntent(
            address(this),
            msg.sender,
            usdcOut,
            false
        );

        if (requiresIntent && !canProceed) {
            revert WhaleIntentRequired();
        }

        _executeSell(msg.sender, tokensIn, minUsdcOut, usdcOut);
    }

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

        uint256 priceBefore = getCurrentPrice();
        uint256 usdcAfterFee = (usdcOut * (10000 - feeConfig.sellFee)) / 10000;
        uint256 fee = usdcOut - usdcAfterFee;

        realUsdcReserves -= usdcOut;
        realTokenSupply -= tokensIn;

        uint256 priceAfter = getCurrentPrice();

        // Check price impact
        ICarbonCoinProtection(protection).checkPriceImpact(
            address(this),
            seller,
            priceBefore,
            priceAfter,
            usdcOut,
            false
        );

        // Track volatility
        ICarbonCoinProtection(protection).trackVolatility(address(this), priceAfter, priceBefore);

        _burn(seller, tokensIn);

        require(USDC.transfer(seller, usdcAfterFee), "USDC transfer failed");

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

        emit PriceUpdate(priceAfter, realUsdcReserves, realTokenSupply, block.timestamp);
    }

    /**
     * @notice Graduate to Somnia Exchange with USDC/Token pair.
     * @dev Creates a USDC/Token liquidity pool instead of ETH/Token.
     */
    function _graduate() internal {
        if (hasGraduated) revert AlreadyGraduated();

        if (block.timestamp < lastGraduationAttempt + GRADUATION_COOLDOWN) {
            revert GraduationCooldownActive();
        }
        lastGraduationAttempt = block.timestamp;

        hasGraduated = true;

        _mint(address(this), LIQUIDITY_SUPPLY);

        address dexAddress = ICarbonCoinConfig(config).getCarbonCoinDex();

        _approve(address(this), dexAddress, LIQUIDITY_SUPPLY);
        USDC.approve(dexAddress, realUsdcReserves);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = ICarbonCoinDex(dexAddress)
            .deployLiquidity(creator, address(this), LIQUIDITY_SUPPLY, realUsdcReserves);

        ICarbonCoinLauncher(launcher).markTokenGraduated(address(this));

        emit Graduated(
            address(this),
            amountB,
            amountA,
            getCurrentPrice(),
            block.timestamp
        );

        emit LiquiditySnapshot(amountA, amountB, liquidity, block.timestamp);
    }

    // Manual graduation with cooldown (emergency only)
    function forceGraduate() external onlyAuthorized {
        if (realUsdcReserves < GRADUATION_THRESHOLD) revert InsufficientLiquidity();
        _graduate();
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
        emit LiquiditySnapshot(0, 0, 0, block.timestamp);
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

    function _getFeeConfig() internal view returns (ICarbonCoinConfig.FeeConfig memory) {
      return ICarbonCoinConfig(config).getFeeConfig();
    }

    function _getAntiBotConfig() internal view returns (ICarbonCoinConfig.AntiBotConfig memory) {
      return ICarbonCoinConfig(config).getAntiBotConfig();
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
