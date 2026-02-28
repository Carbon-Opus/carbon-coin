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
    uint256 public lastGraduationAttempt;
    uint256 public constant GRADUATION_COOLDOWN = 1 hours;
    uint256 public realUsdcReserves;
    uint256 public realTokenSupply;
    uint256 public immutable launchTime;
    address public immutable creator;
    address public immutable config;
    address public immutable launcher;
    address public immutable protection;
    address public immutable paymaster;
    IERC20 public immutable USDC;
    bool public hasGraduated;

    /**
     * @notice Constructor for the CarbonCoinUSDC contract.
     * @dev Initializes the token with its name, symbol, creator, USDC address, and Somnia Exchange router.
     * It also whitelists the creator and the launcher contract to bypass certain restrictions.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param _creator The address of the token creator.
     * @param _usdc The address of the USDC token contract.
     * @param _paymaster The address of the paymaster contract.
     * @param _config The address of the token configuration contract.
     * @param _protection The address of the token protection contract.
     * @param bondingCurveConfig The bonding curve parameters.
     */
    constructor(
        string memory name,
        string memory symbol,
        address _creator,
        address _usdc,
        address _paymaster,
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
        paymaster = _paymaster;

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
     * @notice Get the current token price in USDC.
     * @dev Calculates the price based on the bonding curve's virtual and real reserves.
     * @return The current price of one token in USDC (with 6 decimals for USDC).
     */
    function getCurrentPrice() public view returns (uint256) {
        uint256 totalUsdc = VIRTUAL_USDC + realUsdcReserves;
        uint256 totalTokens = VIRTUAL_TOKENS - realTokenSupply;
        // totalUsdc is 6 decimals, totalTokens is 18 decimals
        // To get price in USDC (6 decimals) per token, scale up by 10**18
        return (totalUsdc * 10**18) / totalTokens;
    }

    /**
     *
     * @return _maxTradeSize
     * @return _maxSellPercentage
     * @return _whaleThreshold
     * @return _whaleDelay
     * @return currentMaxSellTokens
     */
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
        (uint256 usdcOut, ) = calculateUsdcOutWithFee(tokensIn);
        return usdcOut;
    }

    /**
     * @notice Calculate the amount of USDC received when selling a specific amount of tokens.
     * @dev The calculation is based on the bonding curve formula and includes the sell fee.
     * @param tokensIn The amount of tokens to be sold.
     * @return The amount of USDC that will be received.
     * @return The amount of fee that will be taken.
     */
    function calculateUsdcOutWithFee(uint256 tokensIn) public view returns (uint256, uint256) {
        if (tokensIn == 0) return (0, 0);
        if (tokensIn > realTokenSupply) return (0, 0);

        ICarbonCoinConfig.FeeConfig memory feeConfig = _getFeeConfig();

        uint256 k = (VIRTUAL_USDC + realUsdcReserves) * (VIRTUAL_TOKENS - realTokenSupply);
        uint256 newRealSupply = realTokenSupply - tokensIn;
        uint256 newTotalTokens = VIRTUAL_TOKENS - newRealSupply;
        uint256 newTotalUsdc = k / newTotalTokens;
        uint256 newUsdcReserves = newTotalUsdc - VIRTUAL_USDC;
        uint256 usdcOut = realUsdcReserves - newUsdcReserves;
        uint256 usdcAmount = (usdcOut * (10000 - feeConfig.sellFee)) / 10000;
        uint256 feeAmount = usdcOut - usdcAmount;
        return (usdcAmount, feeAmount);
    }

    /**
     * @notice Allows a user to buy tokens with USDC (standard approval required).
     * @dev Alternative to buyWithPermit for wallets that don't support permit or for pre-approved USDC.
     * @param usdcAmount The amount of USDC to spend.
     * @param minTokensOut The minimum number of tokens the user is willing to accept.
     */
    function buy(uint256 usdcAmount, uint256 minTokensOut) external nonReentrant whenNotPaused {
        // Execute payment
        require(USDC.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");

        // Execute purchase
        _executeBuy(msg.sender, usdcAmount, minTokensOut);
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
        // Execute payment
        IERC20Permit(address(USDC)).permit(msg.sender, address(this), usdcAmount, deadline, v, r, s);
        require(USDC.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");

        // Execute purchase
        _executeBuy(msg.sender, usdcAmount, minTokensOut);
    }

    /**
     * @notice Allows a user to buy tokens with USDC using the Paymaster (Managed Wallets Only).
     * @param receiver The address of the user receiving the tokens.
     * @param usdcAmount The amount of USDC to spend.
     * @ param minTokensOut The minimum number of tokens the user is willing to accept.
     */
    function buyOnBehalf(
        address receiver,
        uint256 usdcAmount,
        uint256 minTokensOut
    ) external nonReentrant whenNotPaused onlyPaymaster {
        // Execute payment
        require(USDC.transferFrom(paymaster, address(this), usdcAmount), "USDC transfer failed");

        // Execute purchase
        _executeBuy(receiver, usdcAmount, minTokensOut);
    }

    /**
     * @notice Allows a user to sell tokens for USDC.
     * @dev No token approval/transfer required as this is the token contract, and we just burn the tokens.
     * @dev This function is the main entry point for selling tokens.
     * @param tokensIn The amount of tokens to sell.
     * @param minUsdcOut The minimum amount of USDC the user is willing to accept.
     */
    function sell(uint256 tokensIn, uint256 minUsdcOut) external nonReentrant whenNotPaused {
        ICarbonCoinProtection(protection).checkCircuitBreaker(address(this));

        if (hasGraduated) revert AlreadyGraduated();
        if (tokensIn == 0) revert InvalidAmount();
        if (balanceOf(msg.sender) < tokensIn) revert InvalidAmount();

        (uint256 usdcOut, uint256 feeAmount) = calculateUsdcOutWithFee(tokensIn);

        // Check whale intent
        (bool requiresIntent, bool canProceed) = ICarbonCoinProtection(protection).checkWhaleIntent(
            address(this),
            msg.sender,
            usdcOut + feeAmount,
            false
        );

        if (requiresIntent && !canProceed) {
            revert WhaleIntentRequired();
        }

        _executeSell(msg.sender, tokensIn, minUsdcOut, usdcOut, feeAmount);
    }

    /**
     * @notice Allows a user to sell tokens for USDC.
     * @dev No token approval/transfer required as this is the token contract, and we just burn the tokens.
     * @dev This function is the main entry point for selling tokens.
     * @param receiver The address of the user receiving the tokens.
     * @param tokensIn The amount of tokens to sell.
     * @param minUsdcOut The minimum amount of USDC the user is willing to accept.
     */
    function sellOnBehalf(address receiver, uint256 tokensIn, uint256 minUsdcOut) external nonReentrant whenNotPaused onlyPaymaster {
        ICarbonCoinProtection(protection).checkCircuitBreaker(address(this));

        if (hasGraduated) revert AlreadyGraduated();
        if (tokensIn == 0) revert InvalidAmount();
        if (balanceOf(receiver) < tokensIn) revert InvalidAmount();

        (uint256 usdcOut, uint256 feeAmount) = calculateUsdcOutWithFee(tokensIn);

        // Check whale intent
        (bool requiresIntent, bool canProceed) = ICarbonCoinProtection(protection).checkWhaleIntent(
            address(this),
            receiver,
            usdcOut + feeAmount,
            false
        );

        if (requiresIntent && !canProceed) {
            revert WhaleIntentRequired();
        }

        _executeSell(receiver, tokensIn, minUsdcOut, usdcOut, feeAmount);
    }

    /**
     * @notice Internal function to execute a token purchase.
     * @dev This function handles the core logic of a buy transaction.
     * @param buyer The address of the user purchasing tokens.
     * @param usdcAmount The amount of USDC being spent.
     * @param minTokensOut The minimum number of tokens the user is willing to accept.
     */
    function _executeBuy(address buyer, uint256 usdcAmount, uint256 minTokensOut) internal {
        // Protection checks
        ICarbonCoinProtection(protection).checkAntiBotProtection(address(this), buyer, usdcAmount, true);
        ICarbonCoinProtection(protection).checkCircuitBreaker(address(this));
        ICarbonCoinProtection(protection).checkTradeSizeLimit(address(this), buyer, usdcAmount);

        ICarbonCoinConfig.AntiBotConfig memory botConfig = _getAntiBotConfig();
        if (hasGraduated) revert AlreadyGraduated();
        if (usdcAmount < botConfig.minBuyAmount) revert InvalidAmount();

        // Check whale intent
        (bool requiresIntent, bool canProceed) = ICarbonCoinProtection(protection).checkWhaleIntent(
            address(this),
            buyer,
            usdcAmount,
            true
        );

        if (requiresIntent && !canProceed) {
            revert WhaleIntentRequired();
        }

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
     * @notice Internal function to execute a token sale.
     * @dev This function handles the core logic of a sell transaction.
     * @param seller The address of the user selling tokens.
     * @param tokensIn The amount of tokens being sold.
     * @param minUsdcOut The minimum amount of USDC the user is willing to accept.
     * @param usdcOut The calculated amount of USDC to be received.
     */
    function _executeSell(address seller, uint256 tokensIn, uint256 minUsdcOut, uint256 usdcOut, uint256 fee) internal {
        if (usdcOut < minUsdcOut) revert SlippageTooHigh();
        if (usdcOut + fee > realUsdcReserves) revert InsufficientLiquidity();

        uint256 priceBefore = getCurrentPrice();
        realUsdcReserves -= usdcOut + fee;
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

        require(USDC.transfer(seller, usdcOut), "USDC transfer failed");

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

        (uint256 amountA, uint256 amountB, uint256 liquidity, uint256 lpTokenId) = ICarbonCoinDex(dexAddress)
            .deployLiquidity(creator, address(this), LIQUIDITY_SUPPLY, realUsdcReserves);

        ICarbonCoinLauncher(launcher).markTokenGraduated(address(this));

        emit Graduated(
            address(this),
            lpTokenId,
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
    function emergencyWithdraw() external onlyOwner {
        if (hasGraduated) revert AlreadyGraduated();
        require(paused(), "Must be paused first");

        uint256 balance = USDC.balanceOf(address(this));
        require(USDC.transfer(msg.sender, balance), "Withdrawal failed");

        emit EmergencyWithdraw(msg.sender, balance, block.timestamp);
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

    function _getWhaleLimitConfig() internal view returns (ICarbonCoinConfig.WhaleLimitConfig memory) {
      return ICarbonCoinConfig(config).getWhaleLimitConfig();
    }

    modifier onlyOwner() {
        if (msg.sender != _owner()) revert Unauthorized();
        _;
    }

    modifier onlyAuthorized() {
        if (msg.sender != launcher && msg.sender != _owner() && msg.sender != creator) revert Unauthorized();
        _;
    }

    modifier onlyPaymaster() {
        if (msg.sender != paymaster) revert Unauthorized();
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
