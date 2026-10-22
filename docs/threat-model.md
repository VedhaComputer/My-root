# Threat Model — My Root Platform

This threat model outlines the security architecture, critical assets, trust boundaries, threat scenarios, existing defensive controls, known implementation gaps, and residual risks for the **My Root** community knowledge platform.

---

## 1. System Overview & Critical Assets

My Root preserves and verifies grassroots local knowledge, folklore, and historical records categorized across India's administrative geography. Protecting both the authenticity of community records and user privacy is central to platform trust.

### Primary Assets
1. **User Authentication & Session Data**:
   - bcryptjs password hashes (cost factor 12) stored in MongoDB.
   - JWT Access tokens (ephemeral, 15m default lifetime).
   - Refresh tokens stored in MongoDB with family linkage, rotation tracking, and 7-day default lifetime.
   - Single-use, SHA-256 hashed email verification (24h) and password-reset (1h) tokens.
2. **Community Knowledge & Evidence Repository**:
   - Contributed claims, categorized as `HISTORICAL_RECORD`, `CURRENT_FACT`, `FOLKLORE`, `PERSONAL_EXPERIENCE`, `PUBLIC_OPINION`, `SURVEY_DATA`, or `DISPUTED_CLAIM`.
   - Verification reviews, consensus records, and moderation decisions.
   - Evidence records and citations.
3. **Platform Trust & Geographic Integrity**:
   - Administrative place hierarchy data (`COUNTRY` -> `STATE` -> `DISTRICT` -> `TEHSIL` -> `CITY_TOWN` / `VILLAGE`).
   - Anti-collusion controls (prohibition of contributor self-reviews).
   - Upstream India Place API integration credentials.
4. **Audit Logs & Telemetry**:
   - Structured Pino logs containing sanitized operational events and correlation IDs.
   - In-database audit collections for claim state transitions.

---

## 2. Trust Boundaries

```
[ Unstrusted Client: Flutter App / Web / Mobile ]
                     │  (Boundary 1: Public Internet / Client-to-API)
                     ▼
[ Reverse Proxy / Ingress Gateway (Nginx / ALB) ]
                     │  (Boundary 2: Ingress to Backend Process)
                     ▼
[ Express API Server (Node.js runtime) ]
        │                             │
        │ (Boundary 3: Internal DB)   │ (Boundary 4: Upstream HTTP Proxy)
        ▼                             ▼
[ MongoDB Replica Set ]       [ Upstream India Place API Gateway ]
```

- **Trust Boundary 1 (Client ↔ Gateway / API)**: All requests originating from Flutter mobile or web apps are untrusted. Any client-controlled data—including HTTP request headers (`X-Correlation-ID`, `Authorization`), JSON payloads, and URL parameters (`parentId`, `page`, `limit`)—must be validated and sanitized before execution.
- **Trust Boundary 2 (Gateway ↔ Express Application)**: Reverse proxies (if deployed) forward client IP headers. The Express backend defaults `TRUST_PROXY=false` to prevent spoofing of client addresses in rate limiters unless explicitly configured.
- **Trust Boundary 3 (Express Application ↔ MongoDB)**: Internal network boundary. Communications use Mongoose ODM with parameterized queries to prevent NoSQL operator injection (`$gt`, `$where`). Replica sets enforce distributed ACID transactions for concurrent state transitions.
- **Trust Boundary 4 (Express Application ↔ India Place API Gateway)**: Upstream REST integration for geography resolution. Handled via timeout-guarded proxy requests with shared gate secret authentication (`PLACE_API_APP_GATE_SECRET`).

---

## 3. Threat Analysis & Existing Mitigations

### 3.1 Authentication & Session Management
| Threat Scenario | STRIDE Category | Existing Mitigation (Verified from Source) |
| :--- | :--- | :--- |
| **Token Hijacking & Replay** | Spoofing / Information Disclosure | Ephemeral 15m access tokens verified via asymmetric RS256 in production or algorithm-pinned HS256 (`algorithms: ['HS256']`) with strict `iss` and `aud` claim validation. Every request verifies active `user.tokenVersion` against MongoDB. Refresh tokens are single-use with rotation; presenting an already-revoked refresh token triggers multi-token revocation (`revokeTokenFamily`, `revokeAllUserRefreshTokens`, and increments `user.tokenVersion`). |
| **Credential Brute-Force & Stuffing** | Elevation of Privilege | Dedicated in-memory authentication rate limiter (`authRateLimiter` via `MemoryStore`) capping sensitive endpoints (`/register`, `/login`, `/refresh`, `/password-reset/*`, `/verify-email`) to 20 attempts per 15-minute window (`AUTH_RATE_LIMIT_MAX=20`). General endpoints are capped to 100 requests per 15-minute window (`RATE_LIMIT_MAX=100`). |
| **Password Reset Token Interception** | Spoofing / Tampering | Reset tokens are 64-char cryptographically secure hex strings (`crypto.randomBytes(32)`). Only the SHA-256 hash is persisted in MongoDB. Resetting a password invalidates all existing user refresh tokens and increments the user's `tokenVersion`. |

### 3.2 Authorization & Platform Integrity
| Threat Scenario | STRIDE Category | Existing Mitigation (Verified from Source) |
| :--- | :--- | :--- |
| **Self-Approval / Review Collusion** | Tampering / Repudiation | The backend explicitly enforces `SelfReviewError` (`SELF_REVIEW_PROHIBITED`, HTTP 403). A contributor is barred from reviewing, verifying, or rejecting their own submission. |
| **Privilege Escalation** | Elevation of Privilege | Role hierarchy (`ROLE_HIERARCHY`) middleware enforces minimum permissions (`GUEST` < `CONTRIBUTOR` < `LOCAL_CONTRIBUTOR` < `REVIEWER` < `MODERATOR` < `ADMIN`). Role assignments cannot be self-updated via `/me` endpoints. |
| **Misinformation Masquerading as Fact** | Tampering | Claims categorized as `FOLKLORE` automatically mandate non-factual display indicators. State transitions (`draft` -> `submitted` -> `under_review` -> `verified`) require verified consensus from reviewers. |

### 3.3 Network, Input, & Infrastructure Attacks
| Threat Scenario | STRIDE Category | Existing Mitigation (Verified from Source) |
| :--- | :--- | :--- |
| **Log Injection / CRLF Splitting** | Tampering / Information Disclosure | Client-supplied `X-Correlation-ID` headers are validated against exact ASCII pattern `/^[a-zA-Z0-9_-]{1,64}$/`. Any value containing whitespace, newlines, dots, or invalid punctuation fails closed and is replaced with a fresh UUIDv4 (`randomUUID()`). |
| **Query Parameter Pollution & DoS** | Denial of Service | Strict query validation on `page` and `limit` enforcing positive integers (`/^[1-9]\d*$/`) with bounded upper limits (`limit <= 100`, `page <= 10000`). `parentId` query parameters are bounded to `/^[a-zA-Z0-9_-]{2,100}$/`. Canonical API endpoints are served under `/api/v1` with `/health` isolated at root. |
| **Sensitive Data Exposure in Logs** | Information Disclosure | Pino logger configures explicit redaction serializers for passwords, access tokens, refresh tokens, and authentication headers. |

---

## 4. Known Implementation Gaps & Unverified Controls

To avoid false security claims, the following architectural gaps are explicitly acknowledged:

1. **Process-Local In-Memory Rate Limiting**:
   - **Current State**: Rate limiting (`rateLimit` in `backend/src/app.ts` and `authRateLimiter` in `backend/src/modules/auth/routes.ts`) uses process memory (`MemoryStore`).
   - **Gap**: If backend instances are scaled horizontally behind a round-robin load balancer, rate limits are not shared across nodes. An attacker can distribute brute-force attempts across instances.
   - **Unimplemented**: Distributed storage (e.g. Redis Store) is not implemented.
2. **Absence of Client-Side Certificate Pinning**:
   - **Current State**: The Flutter client validates HTTPS in release builds (`AppConstants.sanitizeApiUrl`).
   - **Gap**: The client relies solely on the underlying operating system's root certificate store. If a device has compromised or malicious enterprise root CAs installed, TLS traffic can be inspected.
   - **Unimplemented**: SSL/TLS certificate or public key pinning is not configured.
3. **Unconfigured Mobile Binary Obfuscation**:
   - **Current State**: Flutter build defaults without custom ProGuard/R8 configurations or `--obfuscate --split-debug-info` flags.
   - **Gap**: Mobile application binaries can be decompiled to extract API paths, error strings, and client-side validation logic.
4. **Unverified Production SMTP Delivery**:
   - **Current State**: The backend provides a Nodemailer transport that falls back to console/test logging when SMTP credentials are not present. In production mode, environment schema requires `MAIL_TRANSPORT=smtp` with host, port, user, and password.
   - **Gap**: Live delivery rates, bounce handling, reputation tracking, and SPF/DKIM/DMARC configurations on external production mail exchangers are unverified in this repository.
5. **Unconfigured Remote Deployment & Cloud Infrastructure**:
   - **Current State**: Verified containerization covers local Docker execution (`Dockerfile` and `backend/Dockerfile` using `node:20-alpine@sha256:fb4cd12c85ee03686f6af5362a0b0d56d50c58a04632e6c0fb8363f609372293`).
   - **Gap**: Production ingress configurations (AWS WAF, Cloudflare Magic Transit, Kubernetes NetworkPolicies, VPC security groups) do not exist in this codebase and must be verified separately when deployed.
6. **Hosted CI Execution**:
   - **Current State**: Static definitions for CodeQL (`.github/workflows/codeql.yml`) and Gitleaks, Semgrep, and Trivy (`.github/workflows/ci.yml`) are present in source control.
   - **Gap**: Live scanning in remote GitHub runners requires active repository enablement and secret configuration; actual execution and results are **unverified** from local files.

---

## 5. Residual Risk Assessment

| Risk Description | Likelihood | Impact | Residual Risk Level | Planned / Recommended Remediation |
| :--- | :--- | :--- | :--- | :--- |
| **Distributed Brute-Force against Horizontally Scaled API** | Medium | Medium | **Medium** | Introduce a Redis-backed rate limit store (`rate-limit-redis`) when multi-node production deployment is provisioned. |
| **Client TLS Interception on Rooted/Compromised Devices** | Low | High | **Medium** | Implement HTTP client certificate pinning using security context pinning for mobile release builds. |
| **Reverse Engineering of Mobile Client Logic** | Medium | Low | **Low** | Enable Flutter `--obfuscate --split-debug-info` during release compilation (Phase 2.5B). |
| **Password Reset Email Delivery Failure in Production** | Medium | Medium | **Medium** | Complete end-to-end SMTP integration and deliverability testing against an active production mail provider. |
| **Supply-Chain Dependency Vulnerability in Upstream Packages** | Medium | Medium | **Medium** | Maintain regular automated `npm audit` and `flutter pub outdated` scans, keeping actions and images pinned to immutable digests. |
