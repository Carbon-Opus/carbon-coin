# Security Audit Specification

## 1. Overview

This document outlines the requirements for a security audit of the CarbonOpus smart contracts. The objective is to identify potential vulnerabilities, assess their severity, and provide recommendations for mitigation.

## 2. Scope

### 2.1. In-Scope Contracts

The following smart contracts are in scope for this audit:

- `contracts/CarbonOpus.sol`
- `contracts/CarbonOpusVault.sol`
- `contracts/CarbonTreasury.sol`

### 2.2. Audit Type

The audit will be a **General Security Audit**. It will cover a broad range of common and critical vulnerabilities for EVM-based smart contracts, including but not limited to:

- Reentrancy attacks
- Access control and authorization flaws
- Integer overflow and underflow
- Front-running and Miner Extractable Value (MEV) vulnerabilities
- Insecure randomness
- Gas limit and denial-of-service vectors
- Business logic vulnerabilities

## 3. Deliverables

The final deliverable will be a **Markdown Report (`AUDIT_REPORT.md`)**. The report will include:

- A summary of findings.
- A detailed breakdown of each vulnerability, including its location, severity (High, Medium, Low), potential impact, and recommended mitigation steps.

## 4. Focus Areas

The entire codebase of the in-scope contracts should be considered as a focus area. All functions and logic should be reviewed with equal attention.
