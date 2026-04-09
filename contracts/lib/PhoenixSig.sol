// SPDX-License-Identifier: MIT

// PhoenixSig.sol
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

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../interface/IPhoenixSig.sol";

abstract contract PhoenixSig is IPhoenixSig, EIP712 {
  bytes32 private constant _SIG_TYPEHASH =
    keccak256("PhoenixSig(uint256 tokenId,uint256 deadline)");

  constructor(string memory name) EIP712(name, "1") {}

  function recoverSigner(
    uint256 tokenId,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public virtual view override returns (address signer) {
    require(block.timestamp <= deadline, "PhoenixSig: expired deadline");

    bytes32 structHash = keccak256(abi.encode(_SIG_TYPEHASH, tokenId, deadline));
    bytes32 hash = _hashTypedDataV4(structHash);
    signer = ECDSA.recover(hash, v, r, s);
  }

  // solhint-disable-next-line func-name-mixedcase
  function DOMAIN_SEPARATOR() external view override returns (bytes32) {
    return _domainSeparatorV4();
  }
}
