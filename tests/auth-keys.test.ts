import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import * as forge from 'node-forge';
import { validateJwtKeysAtStartup, getOrCreateKeyPair } from '../src/auth/keys';
import { issueTokens, verifyToken } from '../src/auth/tokens';

vi.mock('../src/cache', () => ({
  cacheGet: vi.fn().mockResolvedValue(null),
  cacheSet: vi.fn().mockResolvedValue(true),
}));

describe('Auth Keys', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
    process.env.NODE_ENV = 'production';
    delete process.env.JWT_PRIVATE_KEY;
    delete process.env.JWT_PUBLIC_KEY;
    delete process.env.JWT_KEY_ID;
  });

  afterEach(() => {
    process.env = originalEnv;
    vi.clearAllMocks();
  });

  it('startup validation rejects missing keys in production', () => {
    expect(() => validateJwtKeysAtStartup()).toThrow(
      /JWT_PRIVATE_KEY and JWT_PUBLIC_KEY environment variables must be provided in production/,
    );
  });

  it('startup validation rejects malformed keys', () => {
    process.env.JWT_PRIVATE_KEY = 'invalid_key';
    process.env.JWT_PUBLIC_KEY = 'invalid_key';
    expect(() => validateJwtKeysAtStartup()).toThrow(/Failed to parse provided JWT keys/);
  });

  it('startup validation succeeds with valid keys', () => {
    const keypair = forge.pki.rsa.generateKeyPair({ bits: 2048, e: 0x10001 });
    process.env.JWT_PRIVATE_KEY = forge.pki.privateKeyToPem(keypair.privateKey);
    process.env.JWT_PUBLIC_KEY = forge.pki.publicKeyToPem(keypair.publicKey);
    process.env.JWT_KEY_ID = 'test_kid';

    expect(() => validateJwtKeysAtStartup()).not.toThrow();
  });

  it('token signed with configured key verifies against configured public key', async () => {
    const keypair = forge.pki.rsa.generateKeyPair({ bits: 2048, e: 0x10001 });
    process.env.JWT_PRIVATE_KEY = forge.pki.privateKeyToPem(keypair.privateKey);
    process.env.JWT_PUBLIC_KEY = forge.pki.publicKeyToPem(keypair.publicKey);
    process.env.JWT_KEY_ID = 'test_kid';

    // Must validate properly
    validateJwtKeysAtStartup();

    // In our implementation currentKeyPair is a module variable in keys.ts.
    // getOrCreateKeyPair should load it from env.
    const kp = await getOrCreateKeyPair();
    expect(kp.kid).toBe('test_kid');

    const payload = {
      sub: 'test_sub',
      userId: 'test_user',
      role: 'user',
      tier: 'free',
      appId: 'test_app',
      sessionId: 'sess_123',
    };

    const { token } = await issueTokens(payload);

    const verified = await verifyToken(token);
    expect(verified).not.toBeNull();
    expect(verified?.sub).toBe('test_sub');
    expect(verified?.userId).toBe('test_user');
  });
});
