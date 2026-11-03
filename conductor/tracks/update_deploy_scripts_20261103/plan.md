# Implementation Plan: Update Deploy Scripts

## Phase 1: Refactor Deploy and Verification Scripts

- [ ] Task: Create a new deploy script `deploy/002_deploy_phoenix.js` for Phoenix Contracts.
    - [ ] Sub-task: Move the deployment logic for Phoenix Contracts from `deploy/000_deploy.js` to the new script.
    - [ ] Sub-task: Ensure the new script follows Hardhat best practices.
- [ ] Task: Create a new verification script `deploy/003_verify_carbon.js` for Carbon Contracts.
    - [ ] Sub-task: Move the verification logic for Carbon Contracts from `deploy/000_deploy.js` to the new script.
- [ ] Task: Create a new verification script `deploy/005_verify_phoenix.js` for Phoenix Contracts.
    - [ ] Sub-task: Move the verification logic for Phoenix Contracts from `deploy/000_deploy.js` to the new script.
- [ ] Task: Update the existing `deploy/000_deploy.js` script.
    - [ ] Sub-task: Remove the deployment logic for Phoenix Contracts.
    - [ ] Sub-task: Remove all contract verification logic.
- [ ] Task: Review and update all deployment scripts to adhere to Hardhat best practices.
    - [ ] Sub-task: Use named accounts where applicable.
    - [ ] Sub-task: Utilize `hre.deployments` for idempotent deployments.
- [ ] Task: Conductor - User Manual Verification 'Refactor Deploy and Verification Scripts' (Protocol in workflow.md)

## Phase 2: Verify Unit Test Integrity

- [ ] Task: Run the entire unit test suite.
    - [ ] Sub-task: Ensure all tests pass with the new deployment script structure.
- [ ] Task: Review and update test scaffolding if necessary.
    - [ ] Sub-task: Identify any tests that rely on the old deployment structure.
    - [ ] Sub-task: Update the test setup to work with the new deployment scripts.
- [ ] Task: Conductor - User Manual Verification 'Verify Unit Test Integrity' (Protocol in workflow.md)
