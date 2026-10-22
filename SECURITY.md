# Security Policy — My Root

This document outlines the security policies, vulnerability reporting procedures, supported versions, secret management practices, and current security posture for the **My Root** platform.

---

## 1. Reporting a Vulnerability

We take the security of My Root and the integrity of local community knowledge seriously. If you discover a potential security vulnerability, please report it responsibly so that it can be addressed before public disclosure.

### Responsible Disclosure Channel
- **Intended Channel — GitHub Private Vulnerability Reporting**: Please use the **Security** tab of the official My Root GitHub repository and click **"Report a vulnerability"** to submit an advisory privately.
  > [!NOTE]
  > *Verification Status*: Whether GitHub Private Vulnerability Reporting is actively toggled on in the remote GitHub repository settings is **unverified** from local workspace files. If the private reporting button is unavailable on the repository page, contact the project maintainers directly via repository issue without disclosing vulnerability details.
- **Do NOT create public GitHub issues or discussions** for unpatched security vulnerabilities.
- *Note on Contact Channels*: Do not send sensitive vulnerability disclosures to unverified or third-party email addresses. At this stage, private GitHub Security Advisories serve as the intended confidential intake mechanism.

### What to Include in a Report
To help us investigate and triage effectively, please include:
- A descriptive summary of the vulnerability.
- Step-by-step instructions or a minimal proof of concept (PoC) demonstrating how to reproduce the issue.
- The affected component(s): Backend API (`backend/`), Frontend Mobile/Web Client (`frontend/`), or CI/CD workflows (`.github/`).
- Any potential impact, such as data tampering, privilege escalation, or unauthorized access to community claims or user accounts.

---

## 2. Supported Versions & Remediation Policy

### Supported Versions
Only the latest commit on the `main` branch of the official repository is actively maintained and supported for security updates:

| Branch / Release | Supported | Description |
| :--- | :--- | :--- |
| `main` (Latest) | ✅ Yes | Actively receives bug fixes and security patches. |
| Any release tag / historic commit | ❌ No | Users and operators should update to `main` or the latest published release. |

### Remediation Policy
- **Triage**: Reported vulnerabilities are reviewed on a best-effort basis by the repository maintainers.
- **No Commercial SLA**: This project does not currently offer a commercial Service Level Agreement (SLA) or a guaranteed turnaround timeframe for vulnerability triage, remediation, or CVE issuance.
- **Coordinated Disclosure**: Fixes will be prepared, verified against the automated test suite, and merged into `main`. Once resolved, the advisory will be published and credit will be acknowledged in release notes.

---

## 3. Secret Management & Configuration Hygiene

### Environment Configuration
- Application secrets (such as `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `PLACE_API_APP_GATE_SECRET`, and database connection strings) are loaded strictly via environment variables parsed and validated at process startup by Zod in `backend/src/config/env.ts`.
- **Zero Hardcoded Secrets**: Secrets and cryptographic keys must never be committed to source control. `.env`, `.env.local`, and key files (`*.pem`, `*.key`) are excluded via `.gitignore`.
- **Production Guardrails**: In production (`NODE_ENV=production`), `env.ts` enforces non-placeholder secrets (`PLACE_API_APP_GATE_SECRET` cannot match development placeholder literals, and `MAIL_TRANSPORT` permits only `smtp` with required host/credentials).

### Cryptographic Keys & Tokens
- **Access Tokens**: Ephemeral 15-minute expiration (`JWT_ACCESS_EXPIRES_IN`, default `15m`). Verified via asymmetric RS256 in production (`JWT_PUBLIC_KEY`), with strict issuer (`myroot-backend`) and audience (`myroot-platform`) validation. Development environments may use an explicit HS256 fallback with matching claims only when `JWT_ALLOW_HS256_FALLBACK=true`. Every request checks `user.tokenVersion` against the active database user record, failing closed if disconnected.
- **Refresh Tokens**: 7-day expiration (`JWT_REFRESH_EXPIRES_IN`, default `7d`). Verified using HS256 with strict algorithm pinning (`algorithms: ['HS256']`). Persisted as SHA-256 hashes in MongoDB with rotation and token family tracking. Presenting an already-revoked refresh token triggers automated multi-token reuse revocation: revoking the token family (`revokeTokenFamily`), revoking all user refresh tokens (`revokeAllUserRefreshTokens`), and incrementing `user.tokenVersion` to immediately invalidate active access tokens.
- **Verification & Reset Tokens**: Password reset (1-hour expiration) and email verification (24-hour expiration) tokens use 64-character cryptographically secure hex strings (`crypto.randomBytes(32)`), stored as SHA-256 hashes in MongoDB with single-use clearing. Password resets also increment `tokenVersion` and revoke active refresh tokens.

---

## 4. Dependency Updates & Supply Chain Security

- **Automated Dependency Auditing**: Dependencies in `backend/` and `frontend/` are audited via `npm audit` (enforced with `--audit-level=high --omit=dev` in CI) and `flutter pub outdated`.
- **GitHub Actions Pinning**: Workflows in `.github/workflows/` (`ci.yml` and `codeql.yml`) pin all third-party GitHub Actions to verified full 40-character commit SHAs with semantic version tags documented in comments (`actions/checkout`, `actions/setup-node`, `actions/upload-artifact`, `subosito/flutter-action`, `gitleaks/gitleaks-action`, `semgrep/semgrep-action`, `aquasecurity/trivy-action`, `github/codeql-action`).
- **Docker Image Digest Pinning**: Both `Dockerfile` and `backend/Dockerfile` pin base images to immutable SHA-256 digests (`node:20-alpine@sha256:fb4cd12c85ee03686f6af5362a0b0d56d50c58a04632e6c0fb8363f609372293`) across builder and runner stages.
- **Security Scanners in CI**: Workflow configurations exist for CodeQL static analysis (`.github/workflows/codeql.yml`) and Gitleaks, Semgrep, and Trivy container/filesystem scanning (within `.github/workflows/ci.yml`). *Verification status*: Their actual execution on hosted GitHub Actions runners and any scanner findings in a remote environment are **unverified** from local repository files.

---

## 5. Architectural Security Posture & Documented Gaps

To maintain documentation integrity, the following implementation realities must be noted:

| Security Domain | Current Implementation Status | Important Operational Notes |
| :--- | :--- | :--- |
| **Rate Limiting** | **In-Memory Store (`MemoryStore`)** | Rate limiting is implemented using `express-rate-limit`'s in-memory storage per Node process. **Redis or distributed shared-cache rate limiting is NOT implemented.** Multi-instance or clustered deployments will maintain independent per-process bucket counts unless a shared store is introduced in a future phase. |
| **Client Transport Security** | **Release Mode HTTPS Check** | The Flutter client enforces HTTPS in release builds (`AppConstants.sanitizeApiUrl`). **SSL / TLS Certificate Pinning is NOT implemented** in the client app. |
| **Mobile Binary Hardening** | **Unconfigured / Open** | Mobile code obfuscation (e.g. ProGuard, R8, `--obfuscate --split-debug-info`) and anti-tamper / jailbreak detection are currently unconfigured in the Flutter build. |
| **Email Delivery** | **Unverified Production SMTP** | The codebase provides a Nodemailer service supporting SMTP configuration, but live production SMTP delivery, SPF/DKIM/DMARC records, and delivery monitoring remain unverified on external infrastructure. |
| **Cloud Deployment** | **Unverified / Local Docker** | Remote cloud deployment manifests (Kubernetes, AWS ECS/EKS, WAF, Cloudflare DDoS rules) are unconfigured in this repository. Verified deployment currently covers local containerized execution. |
| **Place Data Integrity** | **Self-Review Guard & Hierarchy Rules** | Authors cannot approve their own submissions (`SelfReviewError`). Verified claims require `REVIEWER` or higher role. Indian geographic hierarchy is strictly validated (`COUNTRY` -> `STATE` -> `DISTRICT` -> `TEHSIL` -> `CITY_TOWN` / `VILLAGE`). |

For a comprehensive breakdown of platform trust boundaries, threat vectors, and residual risks, refer to [docs/threat-model.md](docs/threat-model.md).
