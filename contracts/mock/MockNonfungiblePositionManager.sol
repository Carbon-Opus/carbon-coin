// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { INonfungiblePositionManager } from "../interface/INonfungiblePositionManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockNonfungiblePositionManager is INonfungiblePositionManager {
    struct MintRecord {
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        address recipient;
    }

    MintRecord public lastMint;
    bool public poolCreated;
    address public lastPoolToken0;
    address public lastPoolToken1;
    uint160 public lastSqrtPriceX96;

    uint24 public lastFee;

    function createAndInitializePoolIfNecessary(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
        external
        payable
        returns (address pool)
    {
        require(token0 < token1, "token0 must be < token1");
        poolCreated = true;
        lastPoolToken0 = token0;
        lastPoolToken1 = token1;
        lastSqrtPriceX96 = sqrtPriceX96;
        lastFee = fee;
        return address(this);
    }

    function mint(MintParams memory params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        require(params.token0 < params.token1, "token0 must be < token1");
        require(params.tickLower < params.tickUpper, "tickLower must be < tickUpper");

        require(IERC20(params.token0).transferFrom(msg.sender, address(this), params.amount0Desired));
        require(IERC20(params.token1).transferFrom(msg.sender, address(this), params.amount1Desired));

        lastMint = MintRecord({
            token0: params.token0,
            token1: params.token1,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            amount0Desired: params.amount0Desired,
            amount1Desired: params.amount1Desired,
            recipient: params.recipient
        });
        return (42, 1000000, params.amount0Desired, params.amount1Desired);
    }

    struct CollectRecord {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    CollectRecord public lastCollect;

    function collect(INonfungiblePositionManager.CollectParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1)
    {
        lastCollect = CollectRecord({
            tokenId: params.tokenId,
            recipient: params.recipient,
            amount0Max: params.amount0Max,
            amount1Max: params.amount1Max
        });

        amount0 = params.amount0Max > 1000 ? 1000 : params.amount0Max;
        amount1 = params.amount1Max > 2000 ? 2000 : params.amount1Max;
        return (amount0, amount1);
    }

    function burn(uint256) external payable {}

    function decreaseLiquidity(DecreaseLiquidityParams calldata)
        external
        payable
        returns (uint256, uint256)
    {
        return (0, 0);
    }

    function increaseLiquidity(IncreaseLiquidityParams calldata)
        external
        payable
        returns (uint128, uint256, uint256)
    {
        return (0, 0, 0);
    }

    function positions(uint256)
        external
        view
        returns (
            uint96,
            address,
            address,
            address,
            uint24,
            int24,
            int24,
            uint128,
            uint256,
            uint256,
            uint128,
            uint128
        )
    {
        return (0, address(0), address(0), address(0), 0, 0, 0, 0, 0, 0, 0, 0);
    }
}
