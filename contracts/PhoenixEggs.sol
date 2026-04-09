// SPDX-License-Identifier: MIT

// PhoenixEggs.sol
// Copyright (c) 2025 Firma Lux Labs, Inc. <https://carbonopus.com>
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

pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./lib/PhoenixSig.sol";
import "./interface/IPhoenixNFT.sol";
import "./interface/IPhoenixDex.sol";
import "./PhoenixToken.sol";

/**
 * @dev Implementation of Phoenix Eggs - Soul-bound tokens owned by every possible ETH address (except address zero).
 *  - Cannot be Transferred, can only be Burned.
 *  - Requires 3 Valid Signatures to Burn NFT
 *  - Valid Signatures must come from existing Phoenix NFT holders (_burned[owner] == true)
 */
/// @custom:security-contact info@charged.fi
contract PhoenixEggs is
  Ownable,
  PhoenixSig,
  ERC721,
  ReentrancyGuard
{
  using Strings for uint256;
  using SafeERC20 for IERC20;
  using Address for address payable;

  error SoulBoundToken();

  event PhoenixBurned(address indexed owner, uint256 newTokenId);
  event PhxClaimed(address indexed owner, uint256 totalPhx);
  event LiquidityCreated(address indexed caller, uint256 amountToken, uint256 amountUSDC, uint256 liquidity);

  struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  uint256 public constant BASIS_POINTS = 10000;
  uint256 public constant POOL_USDC_BP = 7000;
  uint256 public constant RESERVE_USDC_BP = 500;
  uint256 public constant PHX_PER_BURN = 100;
  uint256 public constant PHX_PER_VOTE = 100;
  uint256 public constant PHX_PER_REFERRAL = 250;

  IPhoenixNFT public phoenixNft;
  IPhoenixDex public phoenixDex;
  address public phoenixToken;
  address public usdcToken;
  address public phoenixTreasury;

  uint256 internal _maxNfts;
  uint256 internal _maxTeamEggs;
  uint256 internal _totalReferrals;
  uint256 internal _totalTeamBurns;
  uint256 internal _liquidityCreatedTimestamp;
  uint256 internal _price;
  string internal _baseUri;
  mapping (address => bool) internal _burned;
  mapping (address => uint256) internal _ownerPhxEarnings;

  constructor()
    Ownable(_msgSender())
    PhoenixSig("PhoenixEggs")
    ERC721("Phoenix Egg", "PHXE")
  {
    _price = 200 * 1e6; // Default to 200 USDC
  }

  /**
    * @dev See {IERC721Metadata-name}.
    */
  function name() public pure override returns (string memory) {
    return "PhoenixEggs";
  }

  /**
    * @dev See {IERC721Metadata-symbol}.
    */
  function symbol() public pure override returns (string memory) {
    return "PHXE";
  }

  /**
    * @dev See {IERC721-balanceOf}.
    */
  function balanceOf(address owner) public view override returns (uint256) {
    require(owner != address(0), "invalid address");
    return _burned[owner] ? 0 : 1;
  }

  /**
    * @dev See {IERC721-ownerOf}.
    */
  function ownerOf(uint256 tokenId) public view override returns (address) {
    if (tokenId > 2**160) { return address(0); }
    address owner = address(uint160(tokenId));
    if (_burned[owner]) { return address(0); }
    return owner;
  }

  function tokenOf(address owner) public view returns (uint256) {
    if (_burned[owner]) { return 0; }
    return uint256(uint160(owner));
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    if (tokenId > 2**160) { return ""; }
    return string.concat(_baseUri, tokenId.toString());
  }

  function isMaxReached() public view returns (bool) {
    return _maxNfts > 0 && phoenixNft.totalSupply() == _maxNfts;
  }

  function isEggBurned(uint256 tokenId) external view returns (bool) {
    address owner = address(uint160(tokenId));
    return _burned[owner];
  }

  function getBurnPrice() external view returns (uint256) {
    return _price;
  }

  function getNumBurnedEggs() external view returns (uint256) {
    return phoenixNft.totalSupply();
  }

  function getMaxNfts() external view returns (uint256) {
    return _maxNfts;
  }

  function usdcBalance() external view returns (uint256) {
    if (usdcToken == address(0)) return 0;
    return IERC20(usdcToken).balanceOf(address(this));
  }

  function phxTokenAddress() external view returns (address) {
    return phoenixToken;
  }

  function usdcTokenAddress() external view returns (address) {
    return usdcToken;
  }

  function phoenixDexAddress() external view returns (address) {
    return address(phoenixDex);
  }

  function phxBalanceOf(address owner) external view returns (uint256) {
    return _getOwnerTotalPHX(owner);
  }

  function phxTotalSupply() external view returns (uint256) {
    return _getAccumulatedPHX();
  }

  function claimPhx() external {
    _claimPhx(_msgSender());
  }

  function phxInitialPriceEstimate() external view returns (uint256) {
    if (usdcToken == address(0)) return 0;
    uint256 totalUSDC = IERC20(usdcToken).balanceOf(address(this));
    uint256 poolUSDC = (totalUSDC * POOL_USDC_BP) / BASIS_POINTS;
    uint256 accPHX = _getAccumulatedPHX();
    return accPHX > 0 ? poolUSDC / accPHX : 0;
  }

  function getLiquidityCreationTimestamp() external view returns (uint256) {
    return _liquidityCreatedTimestamp;
  }

  /**
    * @dev Burn the Phoenix Egg to Release the Phoenix
    */
  function burn(
    address referrer,
    uint256 deadline,
    Signature memory sig1,
    Signature memory sig2,
    Signature memory sig3
  ) external nonReentrant {
    address payable owner = payable(_msgSender());
    uint256 tokenId = tokenOf(owner);

    // Validate 3 Signatures
    address signer1 = _validateSig(tokenId, deadline, sig1);
    address signer2 = _validateSig(tokenId, deadline, sig2);
    address signer3 = _validateSig(tokenId, deadline, sig3);
    require(signer1 != signer2 && signer1 != signer3 && signer2 != signer3, "duplicate signers");

    // Reward Owner
    _ownerPhxEarnings[owner] += PHX_PER_BURN;

    // Reward Signers
    _ownerPhxEarnings[signer1] += PHX_PER_VOTE;
    _ownerPhxEarnings[signer2] += PHX_PER_VOTE;
    _ownerPhxEarnings[signer3] += PHX_PER_VOTE;

    // Validate & Reward Referrer
    bool hasReferrer = (referrer != address(0) && referrer != owner);
    if (hasReferrer) {
      _ownerPhxEarnings[referrer] += PHX_PER_REFERRAL;
      _totalReferrals += 1;
    }

    // Burn the Egg! Release the Magical Beast!
    _burnEgg(owner, tokenId, false);
  }

  /**
    * @dev Disable Approvals
    */
  function approve(address to, uint256 tokenId) public override {}
  function getApproved(uint256 tokenId) public pure override returns (address) {}
  function setApprovalForAll(address operator, bool approved) public override {}
  function isApprovedForAll(address owner, address operator) public pure override returns (bool) {}

  /**
    * @dev Disable Transfers
    */
  function transferFrom(address from, address to, uint256 tokenId) public override {}
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {}


  /***********************************|
  |            Only Owner             |
  |__________________________________*/

  /**
    * @dev First Dozen Eggs is Team Pre-mint in order to Kick-Start Voting - Only Owner
    */
  function teamBurn(address payable owner) external onlyOwner {
    require(address(phoenixNft) != address(0), "no phoenix");
    require(phoenixNft.totalSupply() < _maxTeamEggs, "team-burn ended");

    // Reward Owner
    _ownerPhxEarnings[owner] += PHX_PER_BURN;
    _totalTeamBurns++;

    // Burn the Egg!  Release the Magical Beast!
    _burnEgg(owner, tokenOf(owner), true);
  }

  function createLiquidity() external onlyOwner {
    _createLiquidity();
  }

  /**
    * @dev Set Base URI for Metadata - Only Owner
    */
  function setBaseURI(string memory newBase) external onlyOwner {
    _baseUri = newBase;
  }

  /**
    * @dev Set the Minimum Price to Burn - Only Owner
    */
  function setPrice(uint256 newPrice) external onlyOwner {
    _price = newPrice;
  }

  /**
    * @dev Set the Max Amount of NFTs that can be Minted - Only Owner
    */
  function setMaxNfts(uint256 maxNfts) external onlyOwner {
    require(address(phoenixNft) != address(0), "no phoenix");
    _maxNfts = maxNfts;
  }

  /**
    * @dev Set the Max Amount of Team Eggs that can be Burned - Only Owner
    */
  function setMaxTeamEggs(uint256 maxTeamEggs) external onlyOwner {
    _maxTeamEggs = maxTeamEggs;
  }

  /**
    * @dev Set Phoenix NFT Contract - Only Owner
    */
  function setPhoenixNFT(address _phoenixNft) external onlyOwner {
    if (address(_phoenixNft) != address(0)) {
      require(phoenixNft.totalSupply() == 0, "already started");
    }
    phoenixNft = IPhoenixNFT(_phoenixNft);
  }

  /**
    * @dev Set Phoenix Token Contract - Only Owner
    */
  function setPhoenixToken(address _phoenixToken) external onlyOwner {
    phoenixToken = _phoenixToken;
  }

  /**
    * @dev Set USDC Token Contract - Only Owner
    */
  function setUsdcToken(address _usdcToken) external onlyOwner {
    usdcToken = _usdcToken;
  }

  /**
    * @dev Set Phoenix DEX Contract - Only Owner
    */
  function setPhoenixDex(address _phoenixDex) external onlyOwner {
    phoenixDex = IPhoenixDex(_phoenixDex);
  }

  /**
    * @dev Set Phoenix Treasury Contract - Only Owner
    */
  function setPhoenixTreasury(address treasury) external onlyOwner {
    phoenixTreasury = treasury;
  }


  /***********************************|
  |        Private Functions          |
  |__________________________________*/

  function _getOwnerTotalPHX(address owner) internal view returns (uint256 totalPhx) {
    totalPhx = _ownerPhxEarnings[owner] * 1e18;
  }

  function _getAccumulatedPHX() internal view returns (uint256 totalPhx) {
    uint256 normalBurns = phoenixNft.totalSupply() - _totalTeamBurns;
    uint256 fromBurns = (PHX_PER_BURN * phoenixNft.totalSupply()) + (PHX_PER_VOTE * 3 * normalBurns);
    uint256 fromReferrals = PHX_PER_REFERRAL * _totalReferrals;
    totalPhx = (fromBurns + fromReferrals) * 1e18;
  }

  /**
    * @dev Validates an Ethereum Signature
    */
  function _validateSig(uint256 tokenId, uint256 deadline, Signature memory sig) internal view returns (address) {
    address signer = recoverSigner(tokenId, deadline, sig.v, sig.r, sig.s);
    require(phoenixNft.balanceOf(signer) > 0, "Signer is not a Phoenix");
    return signer;
  }

  function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
    // Soul-bound: only burning (to == address(0)) is permitted
    if (to != address(0)) {
      revert SoulBoundToken();
    }
    return super._update(to, tokenId, auth);
  }

  /**
    * @dev Burn the Phoenix Egg to Release the Phoenix
    */
  function _burnEgg(
    address payable owner,
    uint256 tokenId,
    bool isTeamBurn
  ) internal {
    require(address(phoenixNft) != address(0), "no phoenix");
    require(!_burned[owner], "already burned");
    require(phoenixNft.totalSupply() != _maxNfts, "end reached");
    require(_liquidityCreatedTimestamp == 0, "liquidity event started");
    require(usdcToken != address(0), "no usdc");

    if (!isTeamBurn) {
      IERC20(usdcToken).safeTransferFrom(owner, address(this), _price);
    }

    // Spawn new Phoenix
    _burned[owner] = true;
    uint256 newTokenId = phoenixNft.spawnFromAshes(owner, 0);

    // Burn Events
    emit Transfer(owner, address(0), tokenId);
    emit PhoenixBurned(owner, newTokenId);
  }

  function _claimPhx(address owner) internal {
    require(_liquidityCreatedTimestamp > 0, "insufficient liquidity");

    uint256 totalPhx = _getOwnerTotalPHX(owner);
    require(totalPhx > 0, "no PHX to claim");

    // Clear Earnings for Owner
    _ownerPhxEarnings[owner] = 0;

    // Transfer PHX to Owner
    IERC20(phoenixToken).safeTransfer(owner, totalPhx);

    // Emit Event
    emit PhxClaimed(owner, totalPhx);
  }

  /**
    * @dev Creates the DEX Liquidity Pair (USDC/PHX)
    * Note: Can only be called after Max-NFTs are Burned or Expiry Time reached
    */
  function _createLiquidity() internal {
    require(phoenixTreasury != address(0), "no treasury");
    require(address(phoenixDex) != address(0), "no dex");
    require(usdcToken != address(0), "no usdc");
    require(_liquidityCreatedTimestamp == 0, "already created");

    // All USDC from NFT Minting
    uint256 totalUSDC = IERC20(usdcToken).balanceOf(address(this));

    // Portion of Funds go to the Dex Pool
    uint256 poolUSDC = (totalUSDC * POOL_USDC_BP) / BASIS_POINTS;

    // Portion of Funds for Purchasing PHX Tokens to be Burned (stays in contract)
    uint256 reserveUSDC = (totalUSDC * RESERVE_USDC_BP) / BASIS_POINTS;

    // Portion of Funds for Team Treasury (sent to Treasury)
    uint256 treasuryUSDC = totalUSDC - poolUSDC - reserveUSDC;

    // Calculate Required PHX to Mint
    uint256 accumulatedPHX = _getAccumulatedPHX();
    uint256 totalSupply = (accumulatedPHX * 2);

    // Mint PHX to this contract (half goes to Dex Pool, half remains claimable by NFT Holders)
    PhoenixToken(phoenixToken).mintAll(totalSupply);
    require(PhoenixToken(phoenixToken).balanceOf(address(this)) == totalSupply, "mint failed");

    // Approve PhoenixDex to spend USDC and PHX
    IERC20(phoenixToken).approve(address(phoenixDex), accumulatedPHX);
    IERC20(usdcToken).approve(address(phoenixDex), poolUSDC);

    // Create Liquidity using PhoenixDex
    (uint256 amountToken, uint256 amountUSDC, uint256 liquidityTokens) = phoenixDex.deployLiquidity(
      phoenixTreasury, // LP Tokens Receiver
      accumulatedPHX,
      poolUSDC
    );

    // Track Liquidity Event Time
    _liquidityCreatedTimestamp = block.timestamp;

    // Send Treasury USDC to Treasury
    if (treasuryUSDC > 0) {
      IERC20(usdcToken).safeTransfer(phoenixTreasury, treasuryUSDC);
    }

    // Emit Liquidity Event
    emit LiquidityCreated(_msgSender(), amountToken, amountUSDC, liquidityTokens);
  }
}