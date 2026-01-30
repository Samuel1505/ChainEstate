/**
 * Transaction Building Utilities using @stacks/transactions
 * 
 * This module provides utilities for building and broadcasting
 * Stacks transactions for ChainEstate smart contracts.
 */

import {
  makeContractCall,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode,
  StacksTransaction,
  SignedContractCallOptions,
  contractPrincipalCV,
  uintCV,
  stringAsciiCV,
  principalCV,
  standardPrincipalCV,
  trueCV,
  falseCV,
  noneCV,
  someCV,
  ClarityValue,
  getAddressFromPrivateKey,
  TransactionVersion,
  createAssetInfo,
  FungibleConditionCode,
  makeStandardSTXPostCondition,
  PostCondition,
} from '@stacks/transactions';
import { StacksMainnet, StacksTestnet, StacksNetwork } from '@stacks/network';
import { getNetwork } from './wallet-connect';

/**
 * Transaction configuration
 */
export interface TransactionConfig {
  network?: StacksNetwork;
  anchorMode?: AnchorMode;
  postConditionMode?: PostConditionMode;
  fee?: bigint;
  nonce?: number;
  senderKey?: string;
}

/**
 * Default transaction configuration
 */
const defaultConfig: Required<Omit<TransactionConfig, 'network' | 'senderKey'>> = {
  anchorMode: AnchorMode.Any,
  postConditionMode: PostConditionMode.Deny,
  fee: BigInt(0),
  nonce: 0,
};

/**
 * Build a contract call transaction
 */
export async function buildContractCall(
  contractAddress: string,
  contractName: string,
  functionName: string,
  functionArgs: ClarityValue[],
  config: TransactionConfig = {}
): Promise<StacksTransaction> {
  const network = config.network || getNetwork();
  const anchorMode = config.anchorMode || defaultConfig.anchorMode;
  const postConditionMode = config.postConditionMode || defaultConfig.postConditionMode;
  const fee = config.fee || defaultConfig.fee;
  const nonce = config.nonce ?? defaultConfig.nonce;

  const [address, name] = contractAddress.split('.');

  return makeContractCall({
    contractAddress: address,
    contractName: name || contractName,
    functionName,
    functionArgs,
    network,
    anchorMode,
    postConditionMode,
    fee,
    nonce,
    senderKey: config.senderKey,
  });
}

/**
 * Broadcast a transaction
 */
export async function broadcastTx(
  transaction: StacksTransaction,
  network?: StacksNetwork
): Promise<string> {
  const txNetwork = network || getNetwork();
  const response = await broadcastTransaction(transaction, txNetwork);
  return response.txid;
}

/**
 * Build and broadcast a contract call
 */
export async function executeContractCall(
  contractAddress: string,
  contractName: string,
  functionName: string,
  functionArgs: ClarityValue[],
  config: TransactionConfig = {}
): Promise<string> {
  const transaction = await buildContractCall(
    contractAddress,
    contractName,
    functionName,
    functionArgs,
    config
  );

  return broadcastTx(transaction, config.network);
}

/**
 * ChainEstate-specific transaction builders
 */

/**
 * Create a property in the property registry
 */
export async function createProperty(
  propertyRegistryAddress: string,
  address: string,
  value: number | bigint,
  totalShares: number | bigint,
  manager: string,
  metadataUri: string,
  owner: string,
  config: TransactionConfig = {}
): Promise<StacksTransaction> {
  return buildContractCall(
    propertyRegistryAddress,
    'property-registry',
    'create-property',
    [
      stringAsciiCV(address),
      uintCV(value),
      uintCV(totalShares),
      principalCV(manager),
      stringAsciiCV(metadataUri),
      principalCV(owner),
    ],
    config
  );
}

/**
 * Transfer property shares
 */
export async function transferShares(
  shareTokenAddress: string,
  amount: number | bigint,
  recipient: string,
  config: TransactionConfig = {}
): Promise<StacksTransaction> {
  return buildContractCall(
    shareTokenAddress,
    'share-token',
    'transfer',
    [
      uintCV(amount),
      principalCV(recipient),
      noneCV(),
    ],
    config
  );
}

/**
 * Create a sell order in the marketplace
 */
export async function createSellOrder(
  marketplaceAddress: string,
  shareTokenAddress: string,
  amount: number | bigint,
  pricePerShare: number | bigint,
  config: TransactionConfig = {}
): Promise<StacksTransaction> {
  return buildContractCall(
    marketplaceAddress,
    'marketplace',
    'create-sell-order',
    [
      contractPrincipalCV(shareTokenAddress),
      uintCV(amount),
      uintCV(pricePerShare),
    ],
    config
  );
}

/**
 * Fill a sell order
 */
export async function fillSellOrder(
  marketplaceAddress: string,
  orderId: number | bigint,
  config: TransactionConfig = {}
): Promise<StacksTransaction> {
  return buildContractCall(
    marketplaceAddress,
    'marketplace',
    'fill-sell-order',
    [uintCV(orderId)],
    config
  );
}

/**
 * Cast a governance vote
 */
export async function castVote(
  governanceAddress: string,
  proposalId: number | bigint,
  vote: 'yes' | 'no' | 'abstain',
  config: TransactionConfig = {}
): Promise<StacksTransaction> {
  const voteCV = vote === 'yes' ? trueCV() : vote === 'no' ? falseCV() : noneCV();
  
  return buildContractCall(
    governanceAddress,
    'governance',
    'cast-vote',
    [
      uintCV(proposalId),
      voteCV,
    ],
    config
  );
}

/**
 * Deposit rental income
 */
export async function depositRentalIncome(
  rentalDistributionAddress: string,
  propertyId: number | bigint,
  amount: number | bigint,
  config: TransactionConfig = {}
): Promise<StacksTransaction> {
  return buildContractCall(
    rentalDistributionAddress,
    'rental-distribution',
    'deposit-rental-income',
    [
      uintCV(propertyId),
      uintCV(amount),
    ],
    config
  );
}

/**
 * Claim rental income
 */
export async function claimRentalIncome(
  rentalDistributionAddress: string,
  propertyId: number | bigint,
  config: TransactionConfig = {}
): Promise<StacksTransaction> {
  return buildContractCall(
    rentalDistributionAddress,
    'rental-distribution',
    'claim-rental-income',
    [uintCV(propertyId)],
    config
  );
}

/**
 * Create a post condition for STX transfer
 */
export function createSTXPostCondition(
  address: string,
  conditionCode: FungibleConditionCode,
  amount: bigint
): PostCondition {
  return makeStandardSTXPostCondition(
    address,
    conditionCode,
    amount
  );
}

/**
 * Helper to get address from private key
 */
export function getAddressFromKey(privateKey: string, network?: StacksNetwork): string {
  const txNetwork = network || getNetwork();
  const version = txNetwork === new StacksMainnet() 
    ? TransactionVersion.Mainnet 
    : TransactionVersion.Testnet;
  
  return getAddressFromPrivateKey(privateKey, version);
}
