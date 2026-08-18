import * as forge from 'node-forge';
import { cacheGet, cacheSet } from '../cache';

export interface KeyPair {
  kid: string;
  privateKeyPem: string;
  publicKeyPem: string;
  createdAt: number;
}

const KEYS_CACHE_KEY = 'auth:jwks:keys';
const KEY_TTL = 7 * 24 * 3600; // 7 days cache
let currentKeyPair: KeyPair | null = null;

function generateKid(): string {
  return `key_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
}

function generateRsaKeyPair(): KeyPair {
  const keypair = forge.pki.rsa.generateKeyPair({ bits: 2048, e: 0x10001 });
  return {
    kid: generateKid(),
    privateKeyPem: forge.pki.privateKeyToPem(keypair.privateKey),
    publicKeyPem: forge.pki.publicKeyToPem(keypair.publicKey),
    createdAt: Date.now(),
  };
}

export function validateJwtKeysAtStartup(): void {
  const isProduction = process.env.NODE_ENV === 'production';
  const hasPrivateKey = !!process.env.JWT_PRIVATE_KEY;
  const hasPublicKey = !!process.env.JWT_PUBLIC_KEY;

  if (isProduction) {
    if (!hasPrivateKey || !hasPublicKey) {
      throw new Error(
        'FATAL: JWT_PRIVATE_KEY and JWT_PUBLIC_KEY environment variables must be provided in production. ' +
          'Insecure default key generation is disabled in production to prevent serious auth vulnerabilities. ' +
          'Please generate an RS256 key pair and set these variables.',
      );
    }
  }

  if (hasPrivateKey || hasPublicKey) {
    if (!hasPrivateKey || !hasPublicKey) {
      throw new Error('FATAL: Both JWT_PRIVATE_KEY and JWT_PUBLIC_KEY must be provided together.');
    }

    try {
      const privatePem = process.env.JWT_PRIVATE_KEY!.replace(/\\n/g, '\n');
      const publicPem = process.env.JWT_PUBLIC_KEY!.replace(/\\n/g, '\n');

      // Attempt to parse to ensure they are valid RSA keys
      forge.pki.privateKeyFromPem(privatePem);
      forge.pki.publicKeyFromPem(publicPem);
    } catch (err) {
      throw new Error(
        `FATAL: Failed to parse provided JWT keys. Ensure they are valid RS256 PEM keys. Error: ${err}`,
      );
    }
  }
}

export async function getOrCreateKeyPair(): Promise<KeyPair> {
  if (currentKeyPair) return currentKeyPair;

  const cached = await cacheGet<KeyPair>(KEYS_CACHE_KEY);
  if (cached) {
    currentKeyPair = cached;
    return cached;
  }

  const isProduction = process.env.NODE_ENV === 'production';

  // Check env for pre-generated keys (production / HSM path)
  if (process.env.JWT_PRIVATE_KEY && process.env.JWT_PUBLIC_KEY) {
    currentKeyPair = {
      kid: process.env.JWT_KEY_ID ?? 'env_key',
      privateKeyPem: process.env.JWT_PRIVATE_KEY.replace(/\\n/g, '\n'),
      publicKeyPem: process.env.JWT_PUBLIC_KEY.replace(/\\n/g, '\n'),
      createdAt: Date.now(),
    };
    await cacheSet(KEYS_CACHE_KEY, currentKeyPair, KEY_TTL);
    return currentKeyPair;
  }

  if (isProduction) {
    throw new Error(
      'FATAL: JWT keys missing in production. Validation should have caught this at startup.',
    );
  }

  currentKeyPair = generateRsaKeyPair();
  await cacheSet(KEYS_CACHE_KEY, currentKeyPair, KEY_TTL);
  return currentKeyPair;
}

export async function rotateKeys(): Promise<KeyPair> {
  currentKeyPair = generateRsaKeyPair();
  await cacheSet(KEYS_CACHE_KEY, currentKeyPair, KEY_TTL);
  return currentKeyPair;
}

/** Convert PEM public key to JWKS JWK format */
function pemToJwk(publicKeyPem: string, kid: string): object {
  const pubKey = forge.pki.publicKeyFromPem(publicKeyPem);
  const n = forge.util.encode64(forge.util.hexToBytes(pubKey.n.toString(16).padStart(2, '0')));
  const e = forge.util.encode64(forge.util.hexToBytes(pubKey.e.toString(16).padStart(2, '0')));
  // Convert to URL-safe base64
  const toB64Url = (b64: string) => b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  return {
    kty: 'RSA',
    use: 'sig',
    alg: 'RS256',
    kid,
    n: toB64Url(n),
    e: toB64Url(e),
  };
}

export async function getJwks(): Promise<{ keys: object[] }> {
  const kp = await getOrCreateKeyPair();
  return { keys: [pemToJwk(kp.publicKeyPem, kp.kid)] };
}
