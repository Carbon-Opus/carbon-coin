# Technology Stack

This document outlines the technology stack for the CarbonOpus smart contract ecosystem.

## Programming Languages

*   **Solidity:** The primary language for writing the smart contracts. The project uses multiple versions of the Solidity compiler (`0.7.6`, `0.8.20`, `0.8.28`) to maintain compatibility and leverage the latest features.
*   **TypeScript:** Used for all testing, deployment scripts, and tooling. This provides type safety and a modern development experience.

## Framework

*   **Hardhat:** The core development environment for compiling, deploying, testing, and debugging the Ethereum-based software. It provides a flexible and extensible framework for managing the smart contract lifecycle.

## Key Libraries & Tools

*   **Ethers.js:** The primary library for interacting with the Ethereum blockchain. It is used for wallet interactions, contract calls, and transaction management in tests and deployment scripts.
*   **OpenZeppelin Contracts:** A library of secure and community-vetted smart contracts. The project utilizes these for standard implementations like ERC20 and ERC1155, and for security primitives.
*   **TypeChain:** Generates TypeScript typings for smart contracts, enabling strongly-typed contract interactions in the testing and deployment environment. This significantly improves developer experience and reduces runtime errors.
*   **Waffle:** A testing library used alongside Hardhat and Ethers.js to provide smart contract-specific matchers and testing utilities.
*   **Hardhat Deploy:** A Hardhat plugin for managing and recording deployments, making the deployment process deterministic and repeatable.
