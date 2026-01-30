/**
 * ChainEstate Integration Library
 * 
 * Main entry point for @stacks/connect and @stacks/transactions integration
 */

// Wallet connection exports
export {
  appConfig,
  getNetwork,
  getUserSession,
  connectWallet,
  showConnectModal,
  isAuthenticated,
  getCurrentUser,
  signOut,
  getUserAddress,
} from './wallet-connect';

// Transaction builder exports
export {
  buildContractCall,
  broadcastTx,
  executeContractCall,
  createProperty,
  transferShares,
  createSellOrder,
  fillSellOrder,
  castVote,
  depositRentalIncome,
  claimRentalIncome,
  createSTXPostCondition,
  getAddressFromKey,
  type TransactionConfig,
} from './transaction-builder';

// Integration examples
export {
  exampleCreateProperty,
  exampleTransferShares,
  exampleMarketplaceTrade,
  exampleCastVote,
  exampleRentalIncomeFlow,
  signAndBroadcastTransaction,
  completeExampleWorkflow,
} from './integration-example';

// Re-export commonly used types from @stacks/transactions
export type {
  StacksTransaction,
  ClarityValue,
  SignedContractCallOptions,
} from '@stacks/transactions';

export {
  AnchorMode,
  PostConditionMode,
  FungibleConditionCode,
  TransactionVersion,
} from '@stacks/transactions';
