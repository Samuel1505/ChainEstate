/**
 * Wallet Connection Utilities using @stacks/connect
 * 
 * This module provides utilities for connecting to Stacks wallets
 * and managing user authentication.
 */

import {
  UserSession,
  showConnect,
  AuthOptions,
  FinishedAuthData,
} from '@stacks/connect';
import { STACKS_MAINNET, STACKS_TESTNET, StacksNetwork } from '@stacks/network';

/**
 * Application details for wallet connection
 */
export const appDetails = {
  name: 'ChainEstate',
  icon: typeof window !== 'undefined' ? window.location.origin + '/logo.png' : '/logo.png',
};

/**
 * Get the appropriate network based on environment
 */
export function getNetwork(): StacksNetwork {
  const network = process.env.STX_NETWORK || 'testnet';
  return network === 'mainnet' ? STACKS_MAINNET : STACKS_TESTNET;
}

/**
 * Initialize user session
 */
export function getUserSession(): UserSession {
  return new UserSession();
}

/**
 * Connect user wallet
 * 
 * @param onFinish - Callback when authentication is complete
 * @param onCancel - Callback when user cancels authentication
 */
export async function connectWallet(
  onFinish?: (data: FinishedAuthData) => void,
  onCancel?: () => void
): Promise<void> {
  const authOptions: AuthOptions = {
    appDetails,
    redirectTo: '/',
    onFinish: (payload) => {
      const userData = payload.userSession.loadUserData();
      console.log('User authenticated:', userData);
      onFinish?.(payload);
    },
    onCancel: () => {
      console.log('User cancelled authentication');
      onCancel?.();
    },
    userSession: getUserSession(),
  };

  await showConnect(authOptions);
}

/**
 * Show connect modal (alternative method)
 */
export async function showConnectModal(): Promise<void> {
  await showConnect({
    appDetails,
    onFinish: (data) => {
      console.log('User authenticated:', data);
    },
    onCancel: () => {
      console.log('User cancelled');
    },
  });
}

/**
 * Check if user is authenticated
 */
export function isAuthenticated(): boolean {
  const session = getUserSession();
  return session.isUserSignedIn();
}

/**
 * Get current user data
 */
export function getCurrentUser() {
  const session = getUserSession();
  if (!session.isUserSignedIn()) {
    return null;
  }
  return session.loadUserData();
}

/**
 * Sign out user
 */
export function signOut(): void {
  const session = getUserSession();
  session.signUserOut();
}

/**
 * Get user's STX address
 */
export function getUserAddress(): string | null {
  const user = getCurrentUser();
  if (!user) return null;
  
  // UserData has profile with stxAddress
  // The address format depends on the network
  const network = getNetwork();
  const isMainnet = network === STACKS_MAINNET;
  
  // Try to get address from profile or use identity address
  return user.profile?.stxAddress?.[isMainnet ? 'mainnet' : 'testnet'] 
    || user.identityAddress 
    || null;
}
