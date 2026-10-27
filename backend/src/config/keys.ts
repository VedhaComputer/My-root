import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import './env';

let cachedPrivateKey: string | null = null;
let cachedPublicKey: string | null = null;
let pairValidated = false;

/**
 * Canonical base directory for backend-relative file resolution.
 * Always resolves to the backend package root (two directories up from src/config),
 * ensuring deterministic behavior regardless of process.cwd().
 */
export const BACKEND_ROOT = path.resolve(__dirname, '../../');

/**
 * Resolves a configured key file path deterministically:
 * - If path is absolute, normalizes and returns it directly.
 * - If path is relative, resolves strictly against BACKEND_ROOT.
 * Does not probe multiple roots or silently choose whichever file happens to exist.
 */
export function resolveKeyPath(configuredPath: string): string {
  const cleanPath = configuredPath.trim().replace(/^["']|["']$/g, '');
  if (!cleanPath) return '';
  if (path.isAbsolute(cleanPath)) {
    return path.normalize(cleanPath);
  }
  return path.resolve(BACKEND_ROOT, cleanPath);
}

function parseAndValidatePrivateKey(pem: string): crypto.KeyObject {
  try {
    const key = crypto.createPrivateKey(pem);
    if (key.asymmetricKeyType !== 'rsa') {
      throw new Error(`Expected RSA key, but received ${key.asymmetricKeyType}`);
    }
    return key;
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to parse RSA private key: ${msg}`);
  }
}

function parseAndValidatePublicKey(pem: string): crypto.KeyObject {
  try {
    const key = crypto.createPublicKey(pem);
    if (key.asymmetricKeyType !== 'rsa') {
      throw new Error(`Expected RSA key, but received ${key.asymmetricKeyType}`);
    }
    return key;
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to parse RSA public key: ${msg}`);
  }
}

function validateKeyPair(privKey: crypto.KeyObject, pubKey: crypto.KeyObject): void {
  try {
    const testData = Buffer.from('baali-gateway-pair-validation-check');
    const signature = crypto.sign('sha256', testData, privKey);
    const isValid = crypto.verify('sha256', testData, pubKey, signature);
    if (!isValid) {
      throw new Error('Public key does not match private key signature');
    }
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    throw new Error(`RSA key-pair validation failed: ${msg}`);
  }
}

export function getJwtPrivateKey(): string {
  if (cachedPrivateKey) {
    return cachedPrivateKey;
  }

  // 1. Resolve in-memory PEM string before file path
  let rawPem = process.env.JWT_PRIVATE_KEY?.trim();
  const keyPathConfig = process.env.JWT_PRIVATE_KEY_PATH?.trim();

  if (!rawPem && keyPathConfig) {
    const resolvedPath = resolveKeyPath(keyPathConfig);
    if (!fs.existsSync(resolvedPath)) {
      throw new Error(
        `JWT private key file not found at "${resolvedPath}" (configured via JWT_PRIVATE_KEY_PATH="${keyPathConfig}"). ` +
        `Verify the file exists at this path, update JWT_PRIVATE_KEY_PATH in .env, or supply in-memory JWT_PRIVATE_KEY.`
      );
    }
    try {
      rawPem = fs.readFileSync(resolvedPath, 'utf8');
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to read private key from path "${resolvedPath}": ${msg}`);
    }
  }

  if (!rawPem || !rawPem.trim()) {
    throw new Error('No RSA private key configured. Set JWT_PRIVATE_KEY (in-memory) or JWT_PRIVATE_KEY_PATH.');
  }

  const privKeyObject = parseAndValidatePrivateKey(rawPem);
  cachedPrivateKey = rawPem;

  // Validate consistency if public key is already cached
  if (cachedPublicKey && !pairValidated) {
    const pubKeyObject = parseAndValidatePublicKey(cachedPublicKey);
    validateKeyPair(privKeyObject, pubKeyObject);
    pairValidated = true;
  }

  return cachedPrivateKey;
}

export function getJwtPublicKey(): string {
  if (cachedPublicKey) {
    return cachedPublicKey;
  }

  // 1. Resolve in-memory PEM string before file path
  let rawPem = process.env.JWT_PUBLIC_KEY?.trim();
  const keyPathConfig = process.env.JWT_PUBLIC_KEY_PATH?.trim();

  if (!rawPem && keyPathConfig) {
    const resolvedPath = resolveKeyPath(keyPathConfig);
    if (!fs.existsSync(resolvedPath)) {
      throw new Error(
        `JWT public key file not found at "${resolvedPath}" (configured via JWT_PUBLIC_KEY_PATH="${keyPathConfig}"). ` +
        `Verify the file exists at this path, update JWT_PUBLIC_KEY_PATH in .env, or supply in-memory JWT_PUBLIC_KEY.`
      );
    }
    try {
      rawPem = fs.readFileSync(resolvedPath, 'utf8');
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to read public key from path "${resolvedPath}": ${msg}`);
    }
  }

  if (!rawPem || !rawPem.trim()) {
    // If private key is available, derive public key from it
    const privConfigured = Boolean(
      cachedPrivateKey ||
      process.env.JWT_PRIVATE_KEY?.trim() ||
      process.env.JWT_PRIVATE_KEY_PATH?.trim()
    );

    if (privConfigured) {
      const privPem = getJwtPrivateKey();
      const privKeyObject = parseAndValidatePrivateKey(privPem);
      const derivedPubKey = crypto.createPublicKey(privKeyObject);
      cachedPublicKey = derivedPubKey.export({ type: 'spki', format: 'pem' }) as string;
      pairValidated = true;
      return cachedPublicKey;
    }
    throw new Error('No RSA public key configured. Set JWT_PUBLIC_KEY (in-memory) or JWT_PUBLIC_KEY_PATH.');
  }

  const pubKeyObject = parseAndValidatePublicKey(rawPem);
  cachedPublicKey = rawPem;

  // Validate consistency if private key is already cached
  if (cachedPrivateKey && !pairValidated) {
    const privKeyObject = parseAndValidatePrivateKey(cachedPrivateKey);
    validateKeyPair(privKeyObject, pubKeyObject);
    pairValidated = true;
  }

  return cachedPublicKey;
}

export function validateJwtKeysOnStartup(): void {
  const hasPrivateKey = Boolean(
    process.env.JWT_PRIVATE_KEY?.trim() ||
    process.env.JWT_PRIVATE_KEY_PATH?.trim()
  );

  const fallbackAllowed = process.env.JWT_ALLOW_HS256_FALLBACK === 'true';
  const nodeEnv = process.env.NODE_ENV || 'development';

  if (!hasPrivateKey) {
    if (fallbackAllowed && nodeEnv !== 'production') {
      return;
    }
    throw new Error(
      'JWT configuration error: No RSA private key configured. ' +
      'Set JWT_PRIVATE_KEY_PATH pointing to a valid PEM file, or provide in-memory JWT_PRIVATE_KEY.'
    );
  }

  // Eagerly resolve and validate keys at startup
  getJwtPrivateKey();
  getJwtPublicKey();
}

export function _resetKeysForTesting(): void {
  cachedPrivateKey = null;
  cachedPublicKey = null;
  pairValidated = false;
}
