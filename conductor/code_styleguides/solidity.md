# Solidity Style Guide

This document outlines the best practices and style conventions for writing Solidity smart contracts within the CarbonOpus project. Consistency and clarity are the primary goals. This guide should be used in conjunction with the rules enforced by `.solhint.json`.

## 1. Code Layout & Structure

The recommended order for contract elements is as follows:

1.  **SPDX License Identifier & Pragma**
2.  **Import Statements**
3.  **Interfaces**
4.  **Libraries**
5.  **Contracts**

Inside each contract, library, or interface, the ordering should be:

1.  **Type declarations** (`struct`, `enum`, `error`)
2.  **State variables** (grouped by visibility: `public`, `internal`, `private`)
3.  **Events**
4.  **Modifiers**
5.  **Constructor**
6.  **Receive function** (if any)
7.  **Fallback function** (if any)
8.  **External functions**
9.  **Public functions**
10. **Internal functions**
11. **Private functions**

## 2. Naming Conventions

- **Contracts & Libraries:** `UpperCamelCase` (e.g., `CarbonCoin`, `MathLib`).
- **Interfaces:** `UpperCamelCase`, prefixed with `I` (e.g., `ICarbonCoin`).
- **Structs & Enums:** `UpperCamelCase` (e.g., `BondingCurveConfig`, `TradeDirection`).
- **Events:** `UpperCamelCase` (e.g., `TokenCreated`).
- **Functions:** `lowerCamelCase` (e.g., `createToken`).
  - **Internal/Private Functions:** Precede with a single underscore `_` (e.g., `_mintReserve`).
- **State Variables:** `lowerCamelCase`.
  - **Constants:** `ALL_CAPS_SNAKE_CASE` (e.g., `MAX_SUPPLY`).
  - **Immutable Variables:** `lowerCamelCase` (e.g., `usdcToken`).
- **Function Parameters:** `lowerCamelCase`.
- **Local Variables:** `lowerCamelCase`.
- **Modifiers:** `lowerCamelCase` (e.g., `onlyOwner`).
- **Errors:** `UpperCamelCase` (e.g., `InsufficientFunds`).

## 3. Comments & Documentation (NatSpec)

- **NatSpec:** All public and external functions, state variables, and events **must** be fully documented using NatSpec comments (`///` or `/** ... */`).
- **Clarity is Key:** Comments should explain *why* a piece of code is necessary, not just *what* it does.
- **Layout:**
  - `@title`: A top-level title for the contract.
  - `@author`: The author(s).
  - `@notice`: Explains to an end-user *what* the function does.
  - `@dev`: Explains to a developer any extra details about the function's implementation.
  - `@param`: Documents each function parameter.
  - `@return`: Documents each return value.
- **Implementation Comments:** Use `//` for single-line comments within function bodies.

## 4. Solidity Best Practices

- **Explicit Visibility:** All functions and state variables must have an explicit visibility specifier (`public`, `external`, `internal`, or `private`).
- **Custom Errors:** Prefer custom errors over `require()` with string messages for gas efficiency and clearer intent.
  - `if (caller != owner) revert Unauthorized();` is better than `require(caller == owner, "Not owner");`
- **Imports:** Use specific imports (`import {Symbol} from "path/to/File.sol";`) rather than importing whole files.
- **Checks-Effects-Interactions Pattern:** Structure functions that interact with external contracts to prevent reentrancy attacks.
  1.  **Checks:** Perform all necessary validation (`require`, `if/revert`).
  2.  **Effects:** Write to state variables.
  3.  **Interactions:** Call external contracts.
- **Gas Efficiency:** Be mindful of gas costs. Use `uint256` unless smaller types provide significant storage savings. Cache array lengths in `for` loops.

## 5. Solhint Rules

Our project enforces a specific set of rules via `.solhint.json`. Key rules to be aware of include:

- **Compiler Version:** Must be consistent with the versions specified in `hardhat.config.ts`.
- **Function Max Lines:** Functions should be kept concise.
- **No Console Logging:** `console.log` is disallowed in production contracts.
- **Explicit Visibility:** Required for all functions and state variables.
- **Reason Strings:** `require` and `revert` statements should use custom errors instead of reason strings.
- **Naming Conventions:** Enforces the naming conventions outlined in this guide.
