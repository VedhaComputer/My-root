# JWT RSA Keys Directory

This directory holds RSA key pairs for RS256 JWT signing and verification.

> **Security Notice**: All `*.pem` private and public key files in this directory are excluded from Git via `.gitignore` (`keys/*.pem`). Never commit private keys or sensitive credentials to version control.

## Local Development Key Pair Generation

To generate a fresh 2048-bit RSA key pair for local development or testing:

### Option 1: Using Node.js (cross-platform, recommended)
From the repository root or `backend/` directory:
```bash
node -e "const crypto=require('crypto'),fs=require('fs');fs.mkdirSync('backend/keys',{recursive:true});const {privateKey,publicKey}=crypto.generateKeyPairSync('rsa',{modulusLength:2048,publicKeyEncoding:{type:'spki',format:'pem'},privateKeyEncoding:{type:'pkcs8',format:'pem'}});fs.writeFileSync('backend/keys/private.pem',privateKey);fs.writeFileSync('backend/keys/public.pem',publicKey);console.log('✅ Generated backend/keys/private.pem and backend/keys/public.pem');"
```

### Option 2: Using OpenSSL
```bash
mkdir -p backend/keys
openssl genrsa -out backend/keys/private.pem 2048
openssl rsa -in backend/keys/private.pem -pubout -out backend/keys/public.pem
```

## Production Key Management
In production environments:
1. Provide the PEM-encoded private key file via a secure volume mount or secret manager.
2. Configure `JWT_PRIVATE_KEY_PATH` to point to the secure file path, OR set `JWT_PRIVATE_KEY` directly as an in-memory environment variable.
3. Keep `JWT_ALLOW_HS256_FALLBACK=false`. The application enforces RS256 in production and fails fast at startup if valid keys are missing.
