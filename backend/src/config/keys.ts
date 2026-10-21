import fs from 'fs';
import crypto from 'crypto';
import { env } from './env';

let cachedPrivateKey: string | null = null;
let cachedPublicKey: string | null = null;
let pairValidated = false;

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
  let rawPem = process.env.JWT_PRIVATE_KEY || env.JWT_PRIVATE_KEY;
  if (!rawPem && env.JWT_PRIVATE_KEY_PATH) {
    try {
      rawPem = fs.readFileSync(env.JWT_PRIVATE_KEY_PATH, 'utf8');
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to read private key from path "${env.JWT_PRIVATE_KEY_PATH}": ${msg}`);
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
  let rawPem = process.env.JWT_PUBLIC_KEY || env.JWT_PUBLIC_KEY;
  if (!rawPem && env.JWT_PUBLIC_KEY_PATH) {
    try {
      rawPem = fs.readFileSync(env.JWT_PUBLIC_KEY_PATH, 'utf8');
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to read public key from path "${env.JWT_PUBLIC_KEY_PATH}": ${msg}`);
    }
  }

  if (!rawPem || !rawPem.trim()) {
    // If private key is available, derive public key from it
    if (cachedPrivateKey || process.env.JWT_PRIVATE_KEY || env.JWT_PRIVATE_KEY || env.JWT_PRIVATE_KEY_PATH) {
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

export function _resetKeysForTesting(): void {
  cachedPrivateKey = null;
  cachedPublicKey = null;
  pairValidated = false;
}
