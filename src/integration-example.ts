/**
 * Integration Example: Using @stacks/connect and @stacks/transactions together
 * 
 * This file demonstrates how to integrate wallet connection with transaction building
 * for the ChainEstate platform.
 */

import {
  connectWallet,
  getCurrentUser,
  isAuthenticated,
  getUserAddress,
  signOut,
  getUserSession,
} from './wallet-connect';

import {
  buildContractCall,
  executeContractCall,
  createProperty,
  transferShares,
  createSellOrder,
  fillSellOrder,
  castVote,
  depositRentalIncome,
  claimRentalIncome,
  broadcastTx,
  TransactionConfig,
} from './transaction-builder';

import { StacksTransaction } from '@stacks/transactions';
import { StacksTestnet, StacksMainnet } from '@stacks/network';

/**
 * Example: Complete flow for creating a property
 */
export async function exampleCreateProperty() {
  // Step 1: Check if user is authenticated
  if (!isAuthenticated()) {
    console.log('User not authenticated. Connecting wallet...');
    await connectWallet(
      (data) => {
        console.log('Authentication successful:', data);
        // Continue with property creation after authentication
        proceedWithPropertyCreation();
      },
      () => {
        console.log('User cancelled authentication');
      }
    );
    return;
  }

  // Step 2: User is authenticated, proceed with transaction
  await proceedWithPropertyCreation();
}

async function proceedWithPropertyCreation() {
  const user = getCurrentUser();
  if (!user) {
    console.error('User not found');
    return;
  }

  const userAddress = getUserAddress();
  console.log('User address:', userAddress);

  // Step 3: Build the transaction
  const propertyRegistryAddress = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.property-registry';
  
  try {
    const transaction = await createProperty(
      propertyRegistryAddress,
      '123 Main Street, New York, NY 10001',
      1000000, // Property value in micro-STX
      1000,    // Total shares
      userAddress!, // Manager address
      'https://metadata.uri/property/1',
      userAddress!, // Owner address
      {
        // Transaction will be signed by the connected wallet
        // The user session will handle signing
      }
    );

    // Step 4: Sign and broadcast (this would typically be done through the wallet)
    console.log('Transaction built:', transaction);
    console.log('Transaction needs to be signed by the wallet');
    
    // Note: In a real application, you would use the user session to sign
    // and broadcast the transaction through the wallet connection
  } catch (error) {
    console.error('Error creating property:', error);
  }
}

/**
 * Example: Transfer shares with wallet connection
 */
export async function exampleTransferShares(
  shareTokenAddress: string,
  amount: number,
  recipient: string
) {
  if (!isAuthenticated()) {
    throw new Error('User must be authenticated to transfer shares');
  }

  const user = getCurrentUser();
  if (!user) {
    throw new Error('User not found');
  }

  try {
    const transaction = await transferShares(
      shareTokenAddress,
      amount,
      recipient,
      {
        // Transaction configuration
      }
    );

    console.log('Transfer transaction built:', transaction);
    return transaction;
  } catch (error) {
    console.error('Error transferring shares:', error);
    throw error;
  }
}

/**
 * Example: Create and fill a marketplace order
 */
export async function exampleMarketplaceTrade(
  marketplaceAddress: string,
  shareTokenAddress: string,
  amount: number,
  pricePerShare: number
) {
  if (!isAuthenticated()) {
    await connectWallet();
    return;
  }

  try {
    // Create sell order
    const sellOrderTx = await createSellOrder(
      marketplaceAddress,
      shareTokenAddress,
      amount,
      pricePerShare
    );

    console.log('Sell order transaction:', sellOrderTx);
    return sellOrderTx;
  } catch (error) {
    console.error('Error creating sell order:', error);
    throw error;
  }
}

/**
 * Example: Cast a governance vote
 */
export async function exampleCastVote(
  governanceAddress: string,
  proposalId: number,
  vote: 'yes' | 'no' | 'abstain'
) {
  if (!isAuthenticated()) {
    throw new Error('User must be authenticated to vote');
  }

  try {
    const transaction = await castVote(
      governanceAddress,
      proposalId,
      vote
    );

    console.log('Vote transaction built:', transaction);
    return transaction;
  } catch (error) {
    console.error('Error casting vote:', error);
    throw error;
  }
}

/**
 * Example: Deposit and claim rental income
 */
export async function exampleRentalIncomeFlow(
  rentalDistributionAddress: string,
  propertyId: number
) {
  if (!isAuthenticated()) {
    throw new Error('User must be authenticated');
  }

  const user = getCurrentUser();
  if (!user) {
    throw new Error('User not found');
  }

  try {
    // Property manager deposits rental income
    const depositTx = await depositRentalIncome(
      rentalDistributionAddress,
      propertyId,
      10000 // Amount in micro-STX
    );

    console.log('Deposit transaction:', depositTx);

    // Shareholder claims their portion
    const claimTx = await claimRentalIncome(
      rentalDistributionAddress,
      propertyId
    );

    console.log('Claim transaction:', claimTx);

    return { depositTx, claimTx };
  } catch (error) {
    console.error('Error in rental income flow:', error);
    throw error;
  }
}

/**
 * Example: Sign transaction using user session
 */
export async function signAndBroadcastTransaction(
  transaction: StacksTransaction
): Promise<string> {
  const session = getUserSession();
  
  if (!session.isUserSignedIn()) {
    throw new Error('User must be signed in to broadcast transactions');
  }

  // The transaction needs to be signed by the user's wallet
  // This is typically handled by the wallet extension or connect library
  // For programmatic signing, you would use the user's private key from the session
  
  // Note: In production, you should use the wallet's signing mechanism
  // through @stacks/connect rather than accessing private keys directly
  
  console.log('Transaction ready for signing:', transaction);
  console.log('Use wallet signing mechanism to sign and broadcast');
  
  // This is a placeholder - actual implementation depends on your use case
  throw new Error('Transaction signing must be implemented with wallet integration');
}

/**
 * Complete example workflow
 */
export async function completeExampleWorkflow() {
  console.log('=== ChainEstate Integration Example ===\n');

  // 1. Check authentication
  console.log('1. Checking authentication...');
  if (!isAuthenticated()) {
    console.log('   Not authenticated. Connecting wallet...');
    await connectWallet(
      () => {
        console.log('   ✓ Wallet connected');
        continueWorkflow();
      },
      () => {
        console.log('   ✗ User cancelled');
      }
    );
  } else {
    console.log('   ✓ Already authenticated');
    await continueWorkflow();
  }
}

async function continueWorkflow() {
  const user = getCurrentUser();
  const address = getUserAddress();
  
  console.log('\n2. User Information:');
  console.log('   Address:', address);
  console.log('   Username:', user?.username || 'N/A');

  console.log('\n3. Example transactions ready to build:');
  console.log('   - createProperty()');
  console.log('   - transferShares()');
  console.log('   - createSellOrder()');
  console.log('   - castVote()');
  console.log('   - depositRentalIncome()');
  console.log('   - claimRentalIncome()');

  console.log('\n=== Integration Setup Complete ===');
  console.log('Use the exported functions to interact with ChainEstate contracts');
}
