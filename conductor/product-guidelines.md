# Product Guidelines

This document outlines the core principles that guide the design, development, and communication of the CarbonOpus platform. Adherence to these guidelines is mandatory for building user trust and ensuring legal and operational integrity.

## 1. Prose Style & Brand Identity

### Prose Style: Technical & Formal
All user-facing content, including documentation, UI copy, and error messages, must be technical and formal.

*   **Clarity and Precision:** Language must be unambiguous. Use clear, direct sentences. When technical terms (e.g., "bonding curve," "slippage") are necessary, they must be used correctly and accompanied by concise, accessible explanations.
*   **Accuracy:** All information must be factually correct. This is critical for building user trust, especially when dealing with financial transactions.

### Brand Identity: Secure, Transparent, & Financial
The CarbonOpus brand must project security, reliability, and financial trustworthiness.

*   **Security First:** Emphasize the platform's security features, such as on-chain anti-bot/whale protection and the use of audited OpenZeppelin contracts.
*   **Radical Transparency:** Be upfront about risks, fees, and the centralized aspects of the protocol. Trust is built on honesty, not just on technical safeguards.
*   **Financial Focus:** Acknowledge the financial nature of the platform. Avoid language that could be misinterpreted as providing financial advice.

## 2. User Experience (UX) Principles

The UX must be guided by clarity, transparency, and user safety.

*   **Simplicity & Clarity:** The UI must be intuitive, especially for users new to DeFi.
*   **Explicit Risk Disclosure:**
    *   **CarbonCoin:** The interface must clearly and repeatedly warn users about the high-risk nature of bonding curve tokens, including the potential for extreme price volatility and slippage.
    *   **CarbonOpus:** The interface must clearly state that the platform mints NFTs on behalf of artists and that ownership is subject to copyright law.
*   **Guided & Failsafe Journeys:** For complex interactions (e.g., the "intent-to-trade" process), the UI must actively guide the user with step-by-step instructions. All actions involving value transfer must have clear confirmation steps.
*   **No Hidden Information:** All fees (trading, protocol, creator royalties) must be clearly displayed *before* a user confirms a transaction.

## 3. Engineering & Legal Principles

### Security & System Integrity
*   **Security-First Development:** All contracts and services must follow a security-first mindset, including adherence to the Checks-Effects-Interactions pattern, use of reentrancy guards, and undergoing regular third-party audits.
*   **Rug-Pull Resistance:** The "graduation" mechanism, where LP tokens are locked in the `CarbonTreasury`, is a core security feature. This must be preserved and clearly communicated to users as a primary trust signal.
*   **Transparent Centralization:** The platform operates with privileged `owner` and `controller` roles. Public documentation must clearly define the powers of these roles (e.g., pausing contracts, updating fees, changing key addresses) and, if possible, disclose who controls them (e.g., a multisig wallet, a foundation).

### Legal & Copyright Compliance (DMCA)
*   **Centralized Minting Responsibility (`CarbonOpus`):** The platform's `controller` contract is responsible for minting all music NFTs. This is an active, not passive, role. Therefore, the platform must not knowingly mint content that infringes on copyright.
*   **DMCA Takedown Policy:** The platform must implement and publicly document a clear process for handling DMCA takedown notices. Given the on-chain nature of NFTs, this process should define:
    1.  How a copyright holder can submit a claim.
    2.  How the platform will verify the claim.
    3.  The on-chain and off-chain actions that will be taken in response (e.g., delisting from the official UI, calling `updateSongLockStatus(tokenId, true)` on-chain to prevent further sales).
*   **Artist Agreement:** Before an artist's work is minted, they must agree to terms of service that explicitly state they have the rights to the content they are submitting.

### Financial Regulation Compliance
*   **No "Investment" Language:** The platform and all associated communications must strictly avoid language that could be construed as offering investment advice, promising profits, or marketing tokens as securities.
*   **Focus on Utility:** Frame `CarbonCoin` as a tool for community-driven project launches and `CarbonOpus` NFTs as digital collectibles for music appreciation.
*   **Jurisdictional Awareness:** The platform must be prepared to restrict access to users from jurisdictions where these activities may be prohibited.
