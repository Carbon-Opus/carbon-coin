// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPhoenixTraits {
    function getTraits(uint256 tokenId) external view returns (uint256);
    function setTraits(uint256 tokenId, uint256 traits) external;
}
