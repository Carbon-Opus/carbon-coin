// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CarbonCoin } from "../CarbonCoin.sol";
import { ICarbonCoin } from "../interface/ICarbonCoin.sol";

contract MockLauncher {
    address public lastGraduated;

    function markTokenGraduated(address token) external {
        lastGraduated = token;
    }

    function createToken(
        string memory name,
        string memory symbol,
        address creator,
        address usdc,
        address paymaster,
        address config,
        address protection,
        ICarbonCoin.BondingCurveConfig memory bondingCurveConfig
    ) external returns (address) {
        CarbonCoin coin = new CarbonCoin(
            name,
            symbol,
            creator,
            usdc,
            paymaster,
            config,
            protection,
            bondingCurveConfig
        );
        return address(coin);
    }
}
