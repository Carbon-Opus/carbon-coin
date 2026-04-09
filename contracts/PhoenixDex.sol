// SPDX-License-Identifier: MIT

// PhoenixDex.sol
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
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IPhoenixDex } from "./interface/IPhoenixDex.sol";
import { ISomniaExchangeRouter02 } from "./interface/ISomniaExchangeRouter02.sol";
import { ISomniaExchangeFactory } from "./interface/ISomniaExchangeFactory.sol";
import { ISomniaExchangePair } from "./interface/ISomniaExchangePair.sol";

contract PhoenixDex is IPhoenixDex, ReentrancyGuard, Ownable {
    IERC20 public immutable USDC;
    IERC20 public immutable PHX;
    address public immutable phoenixEggs;
    ISomniaExchangeRouter02 public dexRouter;
    address public pair;
    ISomniaExchangeFactory public factory;

    /**
     * @notice Constructor for the PhoenixDex contract.
     * @param _usdc The address of the USDC token contract.
     * @param _router The address of the Somnia Exchange V2 router.
     */
    constructor(
        address _usdc,
        address _phx,
        address _eggs,
        address _router
    ) Ownable(_msgSender()) ReentrancyGuard() {
        require(_usdc != address(0), "Invalid USDC address");
        require(_phx != address(0), "Invalid PHX address");
        require(_eggs != address(0), "Invalid Eggs address");
        require(_router != address(0), "Invalid router");

        USDC = IERC20(_usdc);
        PHX = IERC20(_phx);
        phoenixEggs = _eggs;
        dexRouter = ISomniaExchangeRouter02(_router);
        factory = ISomniaExchangeFactory(dexRouter.factory());
        pair = factory.getPair(address(USDC), address(PHX));
    }

    /**
     * @notice Deploy Liquidity to Somnia Exchange with USDC/Token pair.
     * @dev Creates a USDC/Token liquidity pool.
     */
    function deployLiquidity(address creator, uint256 phxAmount, uint256 usdcAmount)
        external
        onlyAuthorized
        nonReentrant
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        require(PHX.transferFrom(_msgSender(), address(this), phxAmount), "PHX transfer failed");
        require(USDC.transferFrom(_msgSender(), address(this), usdcAmount), "USDC transfer failed");

        PHX.approve(address(dexRouter), phxAmount);
        USDC.approve(address(dexRouter), usdcAmount);

        (amountA, amountB, liquidity) = dexRouter.addLiquidity(
            address(USDC),
            address(PHX),
            usdcAmount,
            phxAmount,
            (usdcAmount * 95) / 100, // 5% slippage
            (phxAmount * 95) / 100, // 5% slippage
            address(0x0),
            block.timestamp
        );

        emit LiquidityDeployed(creator, pair, amountA, amountB, liquidity, block.timestamp);
    }

    function removeLiquidity(address to, uint256 liquidity)
        external
        onlyAuthorized
        nonReentrant
        returns (uint256 amountA, uint256 amountB)
    {
        require(to != address(0), "Invalid address");
        require(liquidity > 0, "Liquidity must be greater than 0");

        ISomniaExchangePair(pair).approve(address(dexRouter), liquidity);

        (amountA, amountB) = dexRouter.removeLiquidity(
            address(USDC),
            address(PHX),
            liquidity,
            0,
            0,
            to,
            block.timestamp
        );
        emit LiquidityRemoved(to, amountA, amountB, block.timestamp);
    }

    function updateRouter(address newRouter) external onlyOwner {
        dexRouter = ISomniaExchangeRouter02(newRouter);
        emit RouterUpdated(newRouter, block.timestamp);
    }

    modifier onlyAuthorized() {
        if (_msgSender() != owner() && _msgSender() != phoenixEggs) revert Unauthorized();
        _;
    }
}
