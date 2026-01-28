# ChainEstate

A decentralized real estate tokenization platform built on the Stacks blockchain, enabling fractional property ownership, peer-to-peer trading, automated rental distribution, and decentralized governance.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Smart Contracts](#smart-contracts)
- [Technology Stack](#technology-stack)
- [Installation](#installation)
- [Development](#development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

## 🏗️ Overview

ChainEstate revolutionizes real estate investment by leveraging blockchain technology to enable:

- **Fractional Ownership**: Properties are tokenized into tradeable shares, making real estate investment accessible to everyone
- **Peer-to-Peer Trading**: A decentralized marketplace for buying and selling property shares
- **Automated Income Distribution**: Smart contracts automatically distribute rental income to shareholders proportionally
- **Decentralized Governance**: Shareholders vote on property management decisions through on-chain proposals
- **KYC Compliance**: Built-in whitelist system ensures regulatory compliance
- **Secure Escrow**: Multi-party escrow system for secure transactions

## ✨ Features

### Core Functionality

- **Property Registry**: Each property is represented as a unique NFT (SIP-009 compliant) with comprehensive metadata
- **Share Tokenization**: SIP-010 compliant fungible tokens represent fractional ownership
- **Marketplace**: Order book system for trading property shares with escrow protection
- **Rental Distribution**: Automated monthly distribution of rental income with fee management
- **Governance**: On-chain voting system for property management decisions
- **Access Control**: Role-based permission system (Admin, Property Manager, KYC Verifier, Arbiter)
- **Escrow Services**: Secure transaction handling for share purchases and property sales

### Key Benefits

- **Lower Barriers to Entry**: Invest in real estate with smaller amounts
- **Liquidity**: Trade property shares on the marketplace
- **Transparency**: All transactions and governance decisions are on-chain
- **Automation**: Rental income distribution happens automatically
- **Security**: Smart contracts ensure secure asset management

## 🏛️ Architecture

ChainEstate consists of multiple interconnected smart contracts:

```
┌─────────────────────────────────────────────────────────────┐
│                    ChainEstate Platform                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Property   │  │ Share Token  │  │  Marketplace │      │
│  │   Registry   │◄─┤   Contract   │◄─┤   Contract   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                   │            │
│         │                  │                   │            │
│  ┌──────▼──────────┐  ┌───▼──────────┐  ┌────▼──────────┐ │
│  │   Governance    │  │    Rental    │  │    Escrow     │ │
│  │   Contract     │  │ Distribution │  │   Contract    │ │
│  └─────────────────┘  └──────────────┘  └───────────────┘ │
│         │                                                    │
│         └────────────────────────────────────┐              │
│                                             │              │
│                                    ┌────────▼──────────┐   │
│                                    │  Access Control   │   │
│                                    │    Contract       │   │
│                                    └───────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 📜 Smart Contracts

### 1. Property Registry (`property-registry.clar`)

The master NFT contract that represents legal property ownership.

**Key Features:**
- Each property is a unique NFT (SIP-009 compliant)
- Stores property metadata (address, value, shares, manager, status)
- Tracks property status (Active, Maintenance, Foreclosure)
- Links to share token contracts
- Manages property transfers

**Main Functions:**
- `create-property`: Register a new property
- `set-share-token-contract`: Link a share token contract
- `update-property-status`: Change property status
- `transfer`: Transfer property ownership

### 2. Share Token (`share-token.clar`)

SIP-010 compliant fungible token representing fractional property ownership.

**Key Features:**
- KYC whitelist system for compliance
- Share locking mechanism for governance voting
- Minimum investment requirements
- Transfer restrictions (only whitelisted addresses)

**Main Functions:**
- `initialize`: Set up token for a property
- `transfer`: Transfer shares (with whitelist check)
- `add-to-whitelist`: Add KYC-verified addresses
- `lock-shares`/`unlock-shares`: For governance voting

### 3. Marketplace (`marketplace.clar`)

Peer-to-peer trading platform for property shares.

**Key Features:**
- Order book system (buy/sell orders)
- Escrow for shares and STX
- Platform fee (configurable, default 1%)
- Price history tracking
- Trading volume metrics
- Order expiration and cancellation

**Main Functions:**
- `create-sell-order`: List shares for sale
- `create-buy-order`: Place buy order
- `fill-sell-order`: Execute sell order
- `fill-buy-order`: Execute buy order
- `cancel-order`: Cancel pending orders

### 4. Governance (`governance.clar`)

Decentralized decision-making system for property management.

**Key Features:**
- Proposal creation (requires minimum share threshold)
- Weighted voting based on share ownership
- Quorum requirements (default 30%)
- Voting period (default ~14 days)
- Vote delegation
- Proposal execution

**Main Functions:**
- `create-proposal`: Submit governance proposal
- `cast-vote`: Vote on proposals (Yes/No/Abstain)
- `execute-proposal`: Execute passed proposals
- `delegate-vote`: Delegate voting power

### 5. Rental Distribution (`rental-distribution.clar`)

Automated rental income distribution to shareholders.

**Key Features:**
- Monthly income deposits by property managers
- Automatic fee calculation (management, platform, maintenance)
- Proportional distribution based on share ownership
- Claim-based withdrawal system
- Fee structure management

**Main Functions:**
- `deposit-rental-income`: Property manager deposits income
- `claim-rental-income`: Shareholders claim their portion
- `set-fee-structure`: Update fee percentages

### 6. Escrow (`escrow.clar`)

Secure transaction handling for high-value operations.

**Key Features:**
- Share purchase escrow
- Property sale escrow
- KYC verification requirement
- Dispute resolution with arbiters
- Automatic expiration and refund

**Main Functions:**
- `initiate-share-purchase`: Create share purchase escrow
- `initiate-property-sale`: Create property sale escrow
- `verify-escrow`: KYC verification
- `release-funds`: Complete escrow
- `dispute-escrow`: Initiate dispute
- `resolve-dispute`: Arbiter resolution

### 7. Access Control (`access-control.clar`)

Role-based permission system.

**Roles:**
- **Admin**: Full platform control
- **Property Manager**: Can deposit rental income
- **KYC Verifier**: Can verify escrows and whitelist addresses
- **Arbiter**: Can resolve disputes

**Main Functions:**
- `grant-role`: Assign roles
- `revoke-role`: Remove roles
- `transfer-ownership`: Transfer contract ownership

## 🛠️ Technology Stack

- **Blockchain**: Stacks (Bitcoin-secured smart contracts)
- **Smart Contract Language**: Clarity 4.0
- **Development Framework**: Clarinet
- **Testing Framework**: Vitest with Clarinet SDK
- **Package Manager**: npm
- **TypeScript**: For test files

## 📦 Installation

### Prerequisites

- Node.js (v18 or higher)
- npm or yarn
- [Clarinet](https://docs.hiro.so/clarinet/getting-started) (Stacks development tool)

### Setup Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ChainEstate
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Install Clarinet** (if not already installed)
   ```bash
   # macOS
   brew install clarinet
   
   # Linux
   curl -L https://github.com/hirosystems/clarinet/releases/latest/download/clarinet-linux-x64.tar.gz -o clarinet.tar.gz
   tar -xzf clarinet.tar.gz
   sudo mv clarinet /usr/local/bin/
   ```

4. **Verify installation**
   ```bash
   clarinet --version
   ```

## 🚀 Development

### Starting the Development Environment

1. **Start Clarinet console**
   ```bash
   clarinet console
   ```
   This starts a local Stacks blockchain simulator.

2. **In another terminal, run tests**
   ```bash
   npm test
   ```

3. **Watch mode for tests**
   ```bash
   npm run test:watch
   ```

### Project Structure

```
ChainEstate/
├── contracts/              # Clarity smart contracts
│   ├── access-control.clar
│   ├── chainestate.clar
│   ├── escrow.clar
│   ├── governance.clar
│   ├── marketplace.clar
│   ├── property-registry.clar
│   ├── rental-distribution.clar
│   ├── share-token.clar
│   ├── share-token-trait.clar
│   ├── sip-009-nft-trait.clar
│   └── sip-010-trait.clar
├── tests/                 # TypeScript test files
│   └── chainestate.test.ts
├── settings/              # Network configuration
│   ├── Devnet.toml
│   └── Mainnet.toml
├── deployments/          # Deployment plans
│   └── default.mainnet-plan.yaml
├── Clarinet.toml         # Project configuration
├── package.json          # npm dependencies
├── tsconfig.json         # TypeScript configuration
└── vitest.config.ts      # Vitest configuration
```

### Working with Contracts

**Reading contract state:**
```clarity
(contract-call? .property-registry get-property-details u1)
```

**Calling public functions:**
```clarity
(contract-call? .property-registry create-property 
  "123 Main St" 
  u1000000 
  u1000 
  tx-sender 
  "https://metadata.uri" 
  tx-sender
)
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
npm test

# Run with coverage
npm run test:report

# Watch mode
npm run test:watch
```

### Writing Tests

Tests are written in TypeScript using the Clarinet SDK:

```typescript
import { describe, expect, it } from "vitest";

describe("Property Registry", () => {
  it("should create a property", () => {
    const { result } = simnet.callPublicFn(
      "property-registry",
      "create-property",
      [
        types.ascii("123 Main St"),
        types.uint(1000000),
        types.uint(1000),
        types.principal(deployer),
        types.ascii("https://metadata.uri"),
        types.principal(deployer)
      ],
      deployer
    );
    expect(result).toBeOk(types.uint(1));
  });
});
```

## 🚢 Deployment

### Devnet Deployment

1. **Configure Devnet settings** in `settings/Devnet.toml`

2. **Deploy contracts**
   ```bash
   clarinet deploy --devnet
   ```

### Mainnet Deployment

⚠️ **Warning**: Mainnet deployment requires careful consideration and security audits.

1. **Configure Mainnet settings** in `settings/Mainnet.toml`
   - Update RPC address
   - Set deployment fee rate
   - Configure deployer mnemonic (keep secure!)

2. **Review deployment plan** in `deployments/default.mainnet-plan.yaml`

3. **Deploy contracts**
   ```bash
   clarinet deploy --mainnet
   ```

### Deployment Order

Contracts should be deployed in this order due to dependencies:

1. `sip-009-nft-trait` (trait)
2. `sip-010-trait` (trait)
3. `share-token-trait` (trait)
4. `access-control`
5. `property-registry`
6. `share-token` (one instance per property)
7. `marketplace`
8. `governance`
9. `rental-distribution`
10. `escrow`
11. `chainestate` (main orchestrator)

## 🔒 Security

### Security Considerations

- **Access Control**: Role-based permissions prevent unauthorized actions
- **KYC Compliance**: Whitelist system ensures only verified addresses can trade
- **Escrow Protection**: Funds are held in escrow until verification
- **Governance**: Critical changes require on-chain voting
- **Share Locking**: Shares are locked during voting to prevent double-voting

### Best Practices

- Always verify contract addresses before interacting
- Use multi-sig wallets for admin operations
- Regularly audit access control roles
- Monitor for suspicious activity
- Keep private keys secure (never commit to repository)

### Known Limitations

- Clarity 2.0+ limitations on custom function calls with principals
- Gas costs for complex operations
- Block time constraints for time-sensitive operations

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Write tests for new functionality
5. Ensure all tests pass (`npm test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Code Style

- Follow Clarity best practices
- Add comments for complex logic
- Use descriptive variable names
- Write comprehensive tests

## 📄 License

[Specify your license here]

## 📞 Contact & Support

- **Documentation**: [Link to docs]
- **Issues**: [GitHub Issues]
- **Discord/Telegram**: [Community links]

## 🙏 Acknowledgments

- Built on the Stacks blockchain
- Uses SIP-009 and SIP-010 standards
- Powered by Clarinet development framework

---

**⚠️ Disclaimer**: This software is provided as-is. Real estate tokenization involves legal and regulatory considerations. Consult with legal and financial advisors before deploying to mainnet or handling real assets.
