# My Root Backend 🛡️

Secure, enterprise-grade REST API backend for the **My Root** community knowledge platform. Built with Node.js 20+, TypeScript, Express, Mongoose, Zod, and Pino.

---

## 🏛️ Architecture Overview

The backend employs a modular layered architecture with strict separation of concerns, request validation, defensive security controls, and replica-set transaction support.

```
backend/
├── src/
│   ├── config/              # Zod-validated environment, database, and RS256/HS256 keys
│   ├── middleware/          # Correlation ID, Pino HTTP logger, authentication, authorization,
│   │                        # rate limiting, payload size limits, request validators, error handler
│   ├── modules/
│   │   ├── auth/            # Registration (enumeration-safe), Login (constant-time), JWT RS256, Refresh
│   │   ├── claims/          # Claims lifecycle, consent gating for living persons, dispute authorization
│   │   ├── evidence/        # Evidence upload, URL scheme validation (http/https only)
│   │   ├── places/          # Geographic hierarchy, ACID transactions, attribute sanitization & gating
│   │   ├── placeProxy/      # India Place API Gateway integration with sanitized queries & secret checks
│   │   └── health/          # Live readiness & database state check
│   └── shared/              # Structured logger (Pino), constants, AppError hierarchy, types
├── tests/                   # 25 test suites, 400+ unit & integration tests
├── Dockerfile               # Multi-stage production build (Node 20 Alpine, dumb-init, non-root user)
└── .env.example             # Complete environment configuration template
```

---

## 🔒 Security Hardening & Defenses

1. **Confidential Biography Consent Enforcement**: Living-person biographies require explicit consent verification before public indexing or search inclusion.
2. **Fail-Closed DB Connectivity Verification**: Authentication and refresh token routes strictly fail-closed with HTTP 503 (`SERVICE_UNAVAILABLE`) if MongoDB is disconnected or in an unhealthy state.
3. **NoSQL Injection Defense**: Place attributes and query parameters are deeply sanitized to strip MongoDB operator keys (`$where`, `$gt`, `$ne`, etc.) and enforce strict key/value length constraints.
4. **URL Scheme Whitelisting**: Evidence URLs strictly permit only `http:` and `https:` schemes, preventing SSRF and protocol smuggling (`file:`, `javascript:`, `data:`).
5. **Role-Based Dispute Authorization**: Claim dispute endpoints enforce contributor status, local presence rules, and prohibit unauthorized self-disputes.
6. **Unreviewed Place Attribute Gating**: Only reviewer-verified or approved place attributes are exposed to unauthenticated public queries.
7. **Uniform Registration Timing & Account Enumeration Prevention**: Registration yields identical HTTP 201 responses without exposing whether an email or username exists.
8. **Constant-Time Password Verification**: When an email is unrecognized during login, a cost-12 bcrypt dummy hash comparison runs to prevent timing attacks.
9. **RS256 Primary JWT with Fallback Gating**: Tokens are signed using RSA-256 asymmetric keys. HS256 fallback is strictly prohibited in production mode.
10. **Route-Specific Body Limits**: Strict payload limits prevent Denial of Service (100KB for auth, 500KB for claims, 10MB for evidence binaries).
11. **Gateway Secret Hardening**: Place API gateway forbids default placeholder secrets in production and strips unexpected query parameters.
12. **Structured Logging & Correlation IDs**: Pino logger records structured JSON logs tagged with `X-Correlation-ID` header for distributed tracing.

---

## ⚙️ Environment Variables Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `NODE_ENV` | String | `development` | Environment mode (`development`, `test`, `production`) |
| `PORT` | Number | `3001` | HTTP listening port |
| `TRUST_PROXY` | String | `false` | Reverse proxy trust configuration (`loopback`, `1`, etc.) |
| `MONGODB_URI` | String | *Required* | MongoDB connection URI (must support replica sets) |
| `JWT_ISSUER` | String | `myroot-backend` | Expected JWT issuer claim (`iss`) |
| `JWT_AUDIENCE` | String | `myroot-platform` | Expected JWT audience claim (`aud`) |
| `JWT_ALLOW_HS256_FALLBACK` | Boolean | `false` | Allow HS256 HMAC fallback if RS256 keys missing (dev only) |
| `JWT_PRIVATE_KEY_PATH` | String | `keys/private.pem` | Path to RSA private key file |
| `JWT_PUBLIC_KEY_PATH` | String | `keys/public.pem` | Path to RSA public key file |
| `JWT_ACCESS_SECRET` | String | *Required* | Fallback access secret (min 32 chars) |
| `JWT_REFRESH_SECRET` | String | *Required* | Fallback refresh secret (min 32 chars) |
| `RATE_LIMIT_WINDOW_MS` | Number | `900000` | Global rate limit window in milliseconds (15 min) |
| `RATE_LIMIT_MAX` | Number | `100` | Maximum requests per global window |
| `AUTH_RATE_LIMIT_WINDOW_MS` | Number | `900000` | Auth rate limit window (15 min) |
| `AUTH_RATE_LIMIT_MAX` | Number | `20` | Max auth requests per window |
| `CORS_ORIGINS` | String | `http://localhost:3000` | Comma-separated allowed origins |
| `PLACE_API_PROXY_ENABLED` | Boolean | `true` | Enable India Place API Gateway proxy |
| `PLACE_API_BASE_URL` | String | `http://localhost:4001` | Upstream Place API Gateway URL |
| `PLACE_API_APP_GATE_SECRET` | String | *Optional* | Gateway secret (min 32 chars, cannot be placeholder in prod) |
| `PLACE_API_TIMEOUT_MS` | Number | `5000` | Gateway upstream request timeout |

---

## 🧪 Verification & Testing Commands

Execute commands inside `backend/`:

```bash
# Typecheck TypeScript source
npm run build

# Run ESLint linter
npm run lint

# Run full Jest test suite (400 tests, 25 suites)
npm test

# Run tests with code coverage report
npm run test:coverage
```

---

## 🐳 Docker Deployment

Build and run the production container:

```bash
# Build multi-stage Docker image
docker build -t my-root-backend -f Dockerfile .

# Run container with environment configuration
docker run -d \
  --name my-root-backend \
  -p 3001:3001 \
  --env-file .env \
  my-root-backend
```

The container runs as non-root user `node`, handles Unix signals with `dumb-init`, and executes periodic healthchecks at `/health`.
