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
    uint256 virtualUsdc;
    uint256 virtualTokens;
    uint256 creatorReserve;
    uint256 liquiditySupply;
    uint256 curveSupply;
    uint256 maxSupply;
    uint256 graduationThreshold;
  }

  // Trading events
  event TokensPurchased(
    address indexed buyer,
    uint256 usdcAmount,
    uint256 tokensOut,
    uint256 newPrice,
    uint256 realUsdcReserves,
    uint256 realTokenSupply,
    uint256 timestamp
  );
  event TokensSold(
    address indexed seller,
    uint256 tokensIn,
    uint256 usdcOut,
    uint256 newPrice,
    uint256 realUsdcReserves,
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
    uint256 liquidityTokens,
    uint256 liquidityUsdc,
    uint256 finalPrice,
    uint256 timestamp
  );

  // Admin events
  event EmergencyWithdraw(address indexed to, uint256 amount, uint256 timestamp);
  event TradingPaused(uint256 timestamp);
  event TradingUnpaused(uint256 timestamp);

  // State tracking events
  event PriceUpdate(uint256 price, uint256 usdcReserves, uint256 tokenSupply, uint256 timestamp);
  event LiquiditySnapshot(uint256 usdcSupply, uint256 tokenSupply, uint256 liquidity, uint256 timestamp);
  event CreatorReserveMinted(address indexed creator, uint256 amount, uint256 timestamp);

  error Unauthorized();
  error InvalidAmount();
  error ExceedsMaxSupply();
  error SlippageTooHigh();
  error InsufficientLiquidity();
  error AlreadyGraduated();
  error NotGraduated();
  error GraduationCooldownActive();
  error WhaleIntentRequired();
  error CreatorCannotSellBeforeGraduation();

  /**
   * @notice Get total supply including creator reserve
   */
  function getTotalMaxSupply() external view returns (uint256);
  /**
   * @notice Get bonding curve supply (excludes creator reserve)
   */
  function getBondingCurveMaxSupply() external view returns (uint256);

  /**
   * @notice Get the current token price in USDC.
   * @dev Calculates the price based on the bonding curve's virtual and real reserves.
   * @return The current price of one token in USDC (with 6 decimals for USDC).
   */
  function getCurrentPrice() external view returns (uint256);

  /**
   * @notice Calculate the amount of tokens received for a given USDC input.
   * @dev The calculation is based on the bonding curve formula and includes the buy fee.
   * @param usdcIn The amount of USDC to be spent.
   * @return The amount of tokens that will be received.
   */
  function calculateTokensOut(uint256 usdcIn) external view returns (uint256);

  /**
   * @notice Calculate the amount of USDC needed to buy a specific amount of tokens.
   * @dev The calculation is based on the bonding curve formula and includes the buy fee.
   * @param tokensOut The desired amount of tokens.
   * @return The amount of USDC required to purchase the specified tokens.
   */
  function calculateUsdcIn(uint256 tokensOut) external view returns (uint256);

  /**
   * @notice Calculate the amount of USDC received when selling a specific amount of tokens.
   * @dev The calculation is based on the bonding curve formula and includes the sell fee.
   * @param tokensIn The amount of tokens to be sold.
   * @return The amount of USDC that will be received.
   */
  function calculateUsdcOut(uint256 tokensIn) external view returns (uint256);

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
  ) external;

  /**
   * @notice Allows a user to buy tokens with USDC (standard approval required).
   * @dev Alternative to buyWithPermit for wallets that don't support permit or for pre-approved USDC.
   * @param usdcAmount The amount of USDC to spend.
   * @param minTokensOut The minimum number of tokens the user is willing to accept.
   */
  function buy(uint256 usdcAmount, uint256 minTokensOut) external;

  /**
   * @notice Allows a user to sell tokens for USDC.
   * @dev This function is the main entry point for selling tokens.
   * @param tokensIn The amount of tokens to sell.
   * @param minUsdcOut The minimum amount of USDC the user is willing to accept.
   */
  function sell(uint256 tokensIn, uint256 minUsdcOut) external;

  function getReserves() external view returns (
    uint256 usdcReserves,
    uint256 tokenSupply,
    uint256 virtualUsdc,
    uint256 virtualTokens
  );
}
