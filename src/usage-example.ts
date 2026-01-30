/**
 * Usage Examples for ChainEstate Integration
 * 
 * This file provides practical examples of how to use the integration
 * library in a real application.
 */

import {
  connectWallet,
  isAuthenticated,
  getCurrentUser,
  getUserAddress,
  createProperty,
  transferShares,
  createSellOrder,
  fillSellOrder,
  castVote,
  depositRentalIncome,
  claimRentalIncome,
} from './index';

/**
 * Example 1: Property Creation Flow
 * 
 * This example shows how to create a new property on ChainEstate
 */
export async function createPropertyExample() {
  // Step 1: Ensure user is authenticated
  if (!isAuthenticated()) {
    console.log('Please connect your wallet first');
    await connectWallet();
    return;
  }

  const userAddress = getUserAddress();
  if (!userAddress) {
    throw new Error('Could not get user address');
  }

  // Step 2: Build the transaction
  const propertyRegistryAddress = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.property-registry';
  
  const transaction = await createProperty(
    propertyRegistryAddress,
    '123 Main Street, New York, NY 10001', // Property address
    1000000, // Property value in micro-STX (1 STX = 1,000,000 micro-STX)
    1000, // Total shares
    userAddress, // Property manager
    'https://metadata.chainestate.com/property/1', // Metadata URI
    userAddress // Property owner
  );

  console.log('Property creation transaction:', transaction);
  return transaction;
}

/**
 * Example 2: Share Transfer Flow
 * 
 * Transfer shares from one address to another
 */
export async function transferSharesExample(
  shareTokenAddress: string,
  recipientAddress: string,
  amount: number
) {
  if (!isAuthenticated()) {
    throw new Error('User must be authenticated');
  }

  const transaction = await transferShares(
    shareTokenAddress,
    amount,
    recipientAddress
  );

  console.log('Share transfer transaction:', transaction);
  return transaction;
}

/**
 * Example 3: Marketplace Trading Flow
 * 
 * Create a sell order and fill it
 */
export async function marketplaceTradingExample(
  marketplaceAddress: string,
  shareTokenAddress: string
) {
  if (!isAuthenticated()) {
    throw new Error('User must be authenticated');
  }

  // Create a sell order
  const sellOrderTx = await createSellOrder(
    marketplaceAddress,
    shareTokenAddress,
    50, // Amount of shares to sell
    1000 // Price per share in micro-STX
  );

  console.log('Sell order created:', sellOrderTx);

  // Later, fill the order (this would be done by a buyer)
  // const fillOrderTx = await fillSellOrder(marketplaceAddress, orderId);
  // console.log('Order filled:', fillOrderTx);

  return sellOrderTx;
}

/**
 * Example 4: Governance Voting Flow
 * 
 * Cast a vote on a governance proposal
 */
export async function governanceVotingExample(
  governanceAddress: string,
  proposalId: number
) {
  if (!isAuthenticated()) {
    throw new Error('User must be authenticated');
  }

  // Cast a "yes" vote
  const voteTx = await castVote(
    governanceAddress,
    proposalId,
    'yes' // or 'no' or 'abstain'
  );

  console.log('Vote cast:', voteTx);
  return voteTx;
}

/**
 * Example 5: Rental Income Flow
 * 
 * Property manager deposits income, shareholder claims portion
 */
export async function rentalIncomeExample(
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

  // Property manager deposits rental income
  const depositTx = await depositRentalIncome(
    rentalDistributionAddress,
    propertyId,
    50000 // 0.05 STX in micro-STX
  );

  console.log('Rental income deposited:', depositTx);

  // Shareholder claims their portion
  const claimTx = await claimRentalIncome(
    rentalDistributionAddress,
    propertyId
  );

  console.log('Rental income claimed:', claimTx);

  return { depositTx, claimTx };
}

/**
 * Example 6: Complete User Journey
 * 
 * Demonstrates a complete flow from wallet connection to multiple operations
 */
export async function completeUserJourneyExample() {
  console.log('=== ChainEstate User Journey ===\n');

  // Step 1: Connect wallet
  console.log('Step 1: Connecting wallet...');
  if (!isAuthenticated()) {
    await connectWallet(
      () => {
        console.log('✓ Wallet connected');
        continueJourney();
      },
      () => {
        console.log('✗ Wallet connection cancelled');
      }
    );
  } else {
    console.log('✓ Already connected');
    await continueJourney();
  }
}

async function continueJourney() {
  const user = getCurrentUser();
  const address = getUserAddress();

  console.log('\nStep 2: User Information');
  console.log(`  Address: ${address}`);
  console.log(`  Username: ${user?.username || 'N/A'}`);

  console.log('\nStep 3: Available Operations');
  console.log('  - Create Property');
  console.log('  - Transfer Shares');
  console.log('  - Create Sell Order');
  console.log('  - Cast Governance Vote');
  console.log('  - Deposit/Claim Rental Income');

  console.log('\n=== Ready to interact with ChainEstate ===');
}

/**
 * Example 7: Error Handling
 * 
 * Shows proper error handling for transaction operations
 */
export async function errorHandlingExample() {
  try {
    if (!isAuthenticated()) {
      throw new Error('User must be authenticated');
    }

    const transaction = await createProperty(
      'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.property-registry',
      '123 Main St',
      1000000,
      1000,
      'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
      'https://metadata.uri',
      'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'
    );

    return transaction;
  } catch (error) {
    if (error instanceof Error) {
      console.error('Transaction error:', error.message);
      
      // Handle specific error types
      if (error.message.includes('authenticated')) {
        console.log('Please connect your wallet first');
        await connectWallet();
      } else if (error.message.includes('insufficient')) {
        console.log('Insufficient balance');
      } else {
        console.log('Unknown error occurred');
      }
    }
    throw error;
  }
}
