import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import {
  BACKEND_ROOT,
  resolveKeyPath,
  getJwtPrivateKey,
  getJwtPublicKey,
  validateJwtKeysOnStartup,
  _resetKeysForTesting,
} from '../../../src/config/keys';
import { TEST_RSA_PRIVATE_KEY, TEST_RSA_PUBLIC_KEY } from '../../fixtures/testKeys';

describe('JWT Keys Configuration & Resolution (Unit Tests)', () => {
  const originalEnv = { ...process.env };
  const tempDir = path.join(__dirname, 'temp-keys-test');

  beforeAll(() => {
    if (!fs.existsSync(tempDir)) {
      fs.mkdirSync(tempDir, { recursive: true });
    }
  });

  afterAll(() => {
    if (fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true, force: true });
    }
  });

  beforeEach(() => {
    _resetKeysForTesting();
    // Clear relevant process.env overrides
    delete process.env.JWT_PRIVATE_KEY;
    delete process.env.JWT_PUBLIC_KEY;
    delete process.env.JWT_PRIVATE_KEY_PATH;
    delete process.env.JWT_PUBLIC_KEY_PATH;
    delete process.env.JWT_ALLOW_HS256_FALLBACK;
  });

  afterEach(() => {
    _resetKeysForTesting();
    process.env = { ...originalEnv };
  });

  describe('1. Path Resolution (resolveKeyPath)', () => {
    it('returns empty string when configured path is empty or whitespace', () => {
      expect(resolveKeyPath('')).toBe('');
      expect(resolveKeyPath('   ')).toBe('');
    });

    it('normalizes and returns absolute paths directly', () => {
      const absPath = path.resolve(tempDir, 'some-key.pem');
      expect(resolveKeyPath(absPath)).toBe(path.normalize(absPath));
    });

    it('strips surrounding quotes from configured path string', () => {
      const absPath = path.resolve(tempDir, 'quoted-key.pem');
      expect(resolveKeyPath(`"${absPath}"`)).toBe(path.normalize(absPath));
      expect(resolveKeyPath(`'${absPath}'`)).toBe(path.normalize(absPath));
    });

    it('resolves relative path deterministically against backend application root', () => {
      const resolved = resolveKeyPath('keys/private.pem');
      const expected = path.resolve(BACKEND_ROOT, 'keys/private.pem');
      expect(resolved).toBe(expected);
    });
  });

  describe('2. Missing Key File Actionable Error Reporting', () => {
    it('throws clear actionable error when configured JWT_PRIVATE_KEY_PATH does not exist', () => {
      const missingPath = path.join(tempDir, 'non-existent-private-key.pem');
      process.env.JWT_PRIVATE_KEY_PATH = missingPath;

      expect(() => getJwtPrivateKey()).toThrowError(
        /JWT private key file not found at.*configured via JWT_PRIVATE_KEY_PATH/
      );
    });

    it('throws clear actionable error when configured JWT_PUBLIC_KEY_PATH does not exist', () => {
      // Provide valid private key so public key resolution is reached
      process.env.JWT_PRIVATE_KEY = TEST_RSA_PRIVATE_KEY;
      const missingPath = path.join(tempDir, 'non-existent-public-key.pem');
      process.env.JWT_PUBLIC_KEY_PATH = missingPath;

      expect(() => getJwtPublicKey()).toThrowError(
        /JWT public key file not found at.*configured via JWT_PUBLIC_KEY_PATH/
      );
    });

    it('throws clear error when neither in-memory key nor key path is configured', () => {
      expect(() => getJwtPrivateKey()).toThrowError(
        'No RSA private key configured. Set JWT_PRIVATE_KEY (in-memory) or JWT_PRIVATE_KEY_PATH.'
      );
    });
  });

  describe('3. In-Memory Key Precedence & Derivation', () => {
    it('prioritizes in-memory JWT_PRIVATE_KEY over missing JWT_PRIVATE_KEY_PATH', () => {
      process.env.JWT_PRIVATE_KEY = TEST_RSA_PRIVATE_KEY;
      process.env.JWT_PRIVATE_KEY_PATH = 'C:/invalid/path/that/does/not/exist.pem';

      const key = getJwtPrivateKey();
      expect(key).toBe(TEST_RSA_PRIVATE_KEY);
    });

    it('prioritizes in-memory JWT_PUBLIC_KEY over missing JWT_PUBLIC_KEY_PATH', () => {
      process.env.JWT_PRIVATE_KEY = TEST_RSA_PRIVATE_KEY;
      process.env.JWT_PUBLIC_KEY = TEST_RSA_PUBLIC_KEY;
      process.env.JWT_PUBLIC_KEY_PATH = 'C:/invalid/path/that/does/not/exist.pem';

      const key = getJwtPublicKey();
      expect(key).toBe(TEST_RSA_PUBLIC_KEY);
    });

    it('automatically derives public key from private key when public key is not explicitly provided', () => {
      process.env.JWT_PRIVATE_KEY = TEST_RSA_PRIVATE_KEY;

      const derivedPublicKey = getJwtPublicKey();
      expect(derivedPublicKey).toBeDefined();
      expect(derivedPublicKey).toContain('BEGIN PUBLIC KEY');

      // Verify that signatures made with private key verify with derived public key
      const data = Buffer.from('test-payload');
      const signature = crypto.sign('sha256', data, TEST_RSA_PRIVATE_KEY);
      const isVerified = crypto.verify('sha256', data, derivedPublicKey, signature);
      expect(isVerified).toBe(true);
    });
  });

  describe('4. Key Pair Validation & Fail-Closed Behavior', () => {
    it('successfully loads and caches valid RSA keypair from disk', () => {
      const privPath = path.join(tempDir, 'valid-priv.pem');
      const pubPath = path.join(tempDir, 'valid-pub.pem');
      fs.writeFileSync(privPath, TEST_RSA_PRIVATE_KEY);
      fs.writeFileSync(pubPath, TEST_RSA_PUBLIC_KEY);

      process.env.JWT_PRIVATE_KEY_PATH = privPath;
      process.env.JWT_PUBLIC_KEY_PATH = pubPath;

      expect(getJwtPrivateKey()).toBe(TEST_RSA_PRIVATE_KEY);
      expect(getJwtPublicKey()).toBe(TEST_RSA_PUBLIC_KEY);
    });

    it('fails closed when public key does not match private key', () => {
      // Generate a mismatched keypair
      const mismatchedPair = crypto.generateKeyPairSync('rsa', {
        modulusLength: 2048,
        publicKeyEncoding: { type: 'spki', format: 'pem' },
        privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
      });

      process.env.JWT_PRIVATE_KEY = TEST_RSA_PRIVATE_KEY;
      process.env.JWT_PUBLIC_KEY = mismatchedPair.publicKey;

      expect(() => {
        getJwtPrivateKey();
        getJwtPublicKey();
      }).toThrowError(/RSA key-pair validation failed/);
    });
  });

  describe('5. Startup Validation (validateJwtKeysOnStartup)', () => {
    it('throws configuration error when no keys are configured in production', () => {
      (process.env as any).NODE_ENV = 'production';
      expect(() => validateJwtKeysOnStartup()).toThrowError(/JWT configuration error: No RSA private key configured/);
    });

    it('allows startup when HS256 fallback is explicitly enabled in development', () => {
      process.env.NODE_ENV = 'development';
      process.env.JWT_ALLOW_HS256_FALLBACK = 'true';

      expect(() => validateJwtKeysOnStartup()).not.toThrow();
    });

    it('passes startup validation when valid RSA keys are configured', () => {
      process.env.JWT_PRIVATE_KEY = TEST_RSA_PRIVATE_KEY;

      expect(() => validateJwtKeysOnStartup()).not.toThrow();
    });
  });
});
