# ChainEstate Integration Library

This directory contains the integration utilities for using `@stacks/connect` and `@stacks/transactions` with the ChainEstate platform.

## Overview

The integration library provides:

- **Wallet Connection**: Utilities for connecting to Stacks wallets using `@stacks/connect`
- **Transaction Building**: Helpers for building and broadcasting transactions using `@stacks/transactions`
- **ChainEstate-Specific Functions**: Pre-built transaction builders for all ChainEstate contract operations

## Installation

The dependencies are already included in the project's `package.json`. Install them with:

```bash
npm install
```

## Usage

### Basic Wallet Connection

```typescript
import { connectWallet, isAuthenticated, getCurrentUser } from './src';

// Check if user is authenticated
if (!isAuthenticated()) {
  // Connect wallet
  await connectWallet(
    (data) => {
      console.log('User authenticated:', data);
    },
    () => {
      console.log('User cancelled');
    }
  );
}

// Get current user
const user = getCurrentUser();
console.log('User address:', user?.profile?.stxAddress);
```

### Building Transactions

```typescript
import { createProperty, transferShares, createSellOrder } from './src';

// Create a property
const tx = await createProperty(
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.property-registry',
  '123 Main Street',
  1000000,
  1000,
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
  'https://metadata.uri',
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'
);

// Transfer shares
const transferTx = await transferShares(
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.share-token',
  100,
  'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG'
);

// Create sell order
const sellOrderTx = await createSellOrder(
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.marketplace',
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.share-token',
  50,
  1000
);
```

### Complete Example

```typescript
import {
  connectWallet,
  isAuthenticated,
  createProperty,
  transferShares,
  exampleCreateProperty,
} from './src';

// Example: Complete workflow
async function main() {
  // 1. Connect wallet
  if (!isAuthenticated()) {
    await connectWallet();
  }

  // 2. Create a property
  const propertyTx = await createProperty(
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.property-registry',
    '123 Main Street, New York, NY 10001',
    1000000,
    1000,
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    'https://metadata.uri/property/1',
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'
  );

  // 3. Sign and broadcast (handled by wallet)
  console.log('Transaction ready:', propertyTx);
}
```

## Available Functions

### Wallet Connection (`wallet-connect.ts`)

- `connectWallet()` - Connect user's wallet
- `isAuthenticated()` - Check if user is authenticated
- `getCurrentUser()` - Get current user data
- `getUserAddress()` - Get user's STX address
- `signOut()` - Sign out user
- `getUserSession()` - Get user session instance

### Transaction Builders (`transaction-builder.ts`)

#### General Functions
- `buildContractCall()` - Build any contract call transaction
- `broadcastTx()` - Broadcast a transaction
- `executeContractCall()` - Build and broadcast in one call

#### ChainEstate-Specific Functions
- `createProperty()` - Create a new property
- `transferShares()` - Transfer property shares
- `createSellOrder()` - Create a marketplace sell order
- `fillSellOrder()` - Fill a sell order
- `castVote()` - Cast a governance vote
- `depositRentalIncome()` - Deposit rental income
- `claimRentalIncome()` - Claim rental income

### Integration Examples (`integration-example.ts`)

- `exampleCreateProperty()` - Complete property creation flow
- `exampleTransferShares()` - Share transfer example
- `exampleMarketplaceTrade()` - Marketplace trading example
- `exampleCastVote()` - Governance voting example
- `exampleRentalIncomeFlow()` - Rental income flow example
- `completeExampleWorkflow()` - Complete workflow demonstration

## Configuration

### Network Selection

The library automatically detects the network based on the `STX_NETWORK` environment variable:

```bash
# For testnet (default)
STX_NETWORK=testnet

# For mainnet
STX_NETWORK=mainnet
```

You can also specify the network in transaction config:

```typescript
import { StacksMainnet, StacksTestnet } from '@stacks/network';

const tx = await createProperty(
  contractAddress,
  // ... other args
  {
    network: new StacksMainnet(), // or new StacksTestnet()
  }
);
```

### Transaction Configuration

All transaction builder functions accept an optional `TransactionConfig`:

```typescript
interface TransactionConfig {
  network?: StacksNetwork;
  anchorMode?: AnchorMode;
  postConditionMode?: PostConditionMode;
  fee?: bigint;
  nonce?: number;
  senderKey?: string;
}
```

## Environment Setup

For browser environments, ensure you have the Stacks Wallet extension installed.

For Node.js environments (testing), you can use the transaction builders without wallet connection.

## TypeScript Support

All functions are fully typed with TypeScript. The library exports types from `@stacks/transactions` for convenience.

## Examples

See `integration-example.ts` for complete working examples of all ChainEstate operations.

## Notes

- Transactions built with these utilities still need to be signed by the user's wallet
- In browser environments, use `@stacks/connect` to handle signing
- In Node.js environments, you can sign programmatically if you have the private key
- Always verify contract addresses before building transactions
- Test all transactions on testnet before mainnet deployment
