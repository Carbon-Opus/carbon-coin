# Implementation Plan: Update Deploy Scripts

## Phase 1: Refactor Deploy and Verification Scripts [checkpoint: fb4f713]

- [x] Task: Create a new deploy script `deploy/002_deploy_phoenix.js` for Phoenix Contracts.
- [x] Task: Create a new verification script `deploy/003_verify_carbon.js` for Carbon Contracts.
- [x] Task: Create a new verification script `deploy/005_verify_phoenix.js` for Phoenix Contracts.
- [x] Task: Update the existing `deploy/000_deploy.js` script.
- [x] Task: Review and update all deployment scripts to adhere to Hardhat best practices.
- [~] Task: Conductor - User Manual Verification 'Refactor Deploy and Verification Scripts' (Protocol in workflow.md)

## Phase 2: Verify Unit Test Integrity

- [ ] Task: Run the entire unit test suite.
    - [ ] Sub-task: Ensure all tests pass with the new deployment script structure.
- [ ] Task: Review and update test scaffolding if necessary.
    - [ ] Sub-task: Identify any tests that rely on the old deployment structure.
    - [ ] Sub-task: Update the test setup to work with the new deployment scripts.
- [ ] Task: Conductor - User Manual Verification 'Verify Unit Test Integrity' (Protocol in workflow.md)
