# Specification: Update Deploy Scripts

## Overview

This track involves refactoring the deployment and verification scripts to improve modularity and clarity, adhering to Hardhat best practices. The existing `deploy/000_deploy.js` script will be updated to separate the deployment of Phoenix contracts and the contract verification logic into their own dedicated scripts.

## Functional Requirements

1.  **Create Phoenix Deploy Script:**
    -   A new deploy script named `002_deploy_phoenix.js` will be created in the `deploy/` directory.
    -   This script will contain the deployment logic for the Phoenix Contracts.
    -   The Phoenix Contracts deployment logic will be removed from `deploy/000_deploy.js`.

2.  **Create Verification Scripts:**
    -   Two new verification scripts will be created in the `deploy/` directory:
        -   `003_verify_carbon.js` for Carbon contracts.
        -   `005_verify_phoenix.js` for Phoenix contracts.
    -   Phoenix contracts are identified by their names starting with "Phoenix". All other contracts are considered Carbon contracts.
    -   The contract verification logic will be removed from `deploy/000_deploy.js`.

3.  **Update Existing Deploy Script:**
    -   The `deploy/000_deploy.js` script will be modified to remove the deployment logic for Phoenix Contracts and the contract verification logic.
    -   The script should continue to deploy the remaining contracts (Carbon contracts).

4.  **Adherence to Best Practices:**
    -   All deployment scripts will be reviewed and updated to follow the latest Hardhat deployment best practices.
    -   This includes using named accounts, `hre.deployments`, and idempotent deployment logic.

## Non-Functional Requirements

1.  **Unit Test Integrity:**
    -   The existing unit test suite must continue to pass after the deployment script refactoring.
    -   The test setup and scaffolding will be reviewed and updated if necessary to ensure they are still working correctly with the new deployment structure.

## Out of Scope

-   No changes will be made to the smart contract code itself.
-   This track does not cover adding new deployment or verification steps, only refactoring existing ones.
