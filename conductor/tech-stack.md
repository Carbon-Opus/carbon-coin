# Technology Stack

This document outlines the technology stack for the CarbonOpus smart contract ecosystem.

## Programming Languages

*   **Solidity:** The primary language for writing the smart contracts. The project uses multiple versions of the Solidity compiler (`0.7.6`, `0.8.20`, and `0.8.28`) to maintain compatibility and leverage the latest features.
*   **TypeScript:** Used for all testing, deployment scripts, and tooling, providing type safety and a modern development experience.

## Core Framework

*   **Hardhat:** The core development environment for compiling, deploying, testing, and debugging the Ethereum-based software. It provides a flexible and extensible framework for managing the smart contract lifecycle.

## Smart Contract Libraries

*   **OpenZeppelin Contracts:** A library of secure and community-vetted smart contracts, used for standard implementations like ERC20 and for security primitives.
*   **Solady:** A library of gas-optimized Solidity snippets and utility contracts.

## Testing & Test Utilities

*   **Chai:** An assertion library used for writing expressive and readable tests.
*   **Ethers.js:** The primary library for interacting with the Ethereum blockchain. It is used for wallet interactions, contract calls, and transaction management in tests and deployment scripts.
*   **Hardhat Network Helpers:** A library for testing that provides utilities for manipulating the state of the Hardhat Network, such as impersonating accounts and manipulating time.
*   **Hardhat Chai Matchers:** A plugin that adds Ethereum-specific assertions to Chai, making tests more readable and robust.
*   **Solidity Coverage:** A tool to measure the test coverage of the Solidity code.
*   **Mocha:** The underlying test runner for Hardhat tests.

## Deployment & Tooling

*   **Hardhat Deploy:** A Hardhat plugin for managing and recording deployments, making the deployment process deterministic and repeatable.
*   **TypeChain:** Generates TypeScript typings for smart contracts, enabling strongly-typed contract interactions in the testing and deployment environment.
*   **Hardhat Gas Reporter:** A tool to track the gas consumption of contract functions during tests.
*   **Hardhat ABI Exporter:** A utility to export contract ABIs automatically on compilation.
*   **Hardhat Watcher:** A tool that automatically runs Hardhat tasks on file changes.
*   **dotenv:** A module to load environment variables from a `.env` file.

## Linting & Code Quality

*   **ESLint:** A pluggable linter for TypeScript and JavaScript code.
*   **Solhint:** A linter for Solidity code that helps enforce best practices and identify security vulnerabilities.
