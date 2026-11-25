// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPhoenixTraits} from "./interface/IPhoenixTraits.sol";

contract PhoenixTraits is IPhoenixTraits, Ownable {
    mapping(uint256 => uint256) private _traits;
    mapping(address => bool) private _managers;

    constructor() Ownable(_msgSender()) {}

    function getTraits(uint256 tokenId) external view override returns (uint256) {
        return _traits[tokenId];
    }

    function setTraits(uint256 tokenId, uint256 traits) external override onlyManager {
        _traits[tokenId] = traits;
    }

    function addManager(address manager) external onlyOwner {
        _managers[manager] = true;
    }

    function removeManager(address manager) external onlyOwner {
        _managers[manager] = false;
    }

    modifier onlyManager() {
        require(_managers[msg.sender], "Only manager can set traits");
        _;
    }
}
