# My Root — Data Classification Policy

> Version: 1.0.0 | Date: 2026-10-15 | Status: Baseline

---

## 1. Purpose

This document defines how all data in the My Root platform is classified by sensitivity, who may access it, how it must be stored, and what may appear in API responses or logs. Every module and every API endpoint must comply with these classifications.

---

## 2. Classification Tiers

| Tier | Label | Summary |
|------|-------|---------|
| T1 | **Public** | Visible to anonymous users via public API |
| T2 | **Authenticated** | Visible only to logged-in users |
| T3 | **Owner / Contributor-Only** | Visible only to the data owner and roles above |
| T4 | **Reviewer / Moderator** | Visible to `REVIEWER`, `MODERATOR`, `ADMIN` only |
| T5 | **Admin-Only** | Visible only to `ADMIN`; never in API responses |
| T6 | **Never Stored / Ephemeral** | Must not be persisted in any form |

---

## 3. Field-Level Classifications

### 3.1 Users Collection

| Field | Tier | Notes |
|-------|------|-------|
| `displayName` | T1 | Public profile |
| `role` | T2 | Shown only to authenticated user or admin |
| `joinedAt` | T1 | Public |
| `isActive` | T4 | Moderator+ only |
| `email` (stored as hash) | T5 | Lookup only; never returned in API response |
| `passwordHash` | T6 | Never returned in any response or log |
| `verifiedLocationId` | T3 | Owner + moderator+ |
| `isIdentityVerified` (boolean flag only) | T3 | Owner + moderator+; actual document not stored |
| `selectedPlaceId` | T2 | Authenticated user profile context |
| `placeRelationships` (`indigenousClassification`: `Indigenous` | `Non-Indigenous`) | T2 | Authenticated; place-specific connection; residence type removed from product flow; never inferred from caste, religion, name, or role |
| Identity document numbers (Aadhaar, etc.) | T6 | Must **never** be stored in any form |
| Identity document scans/images | T6 | Must **never** be stored; only event hash stored |

### 3.2 Claims Collection

| Field | Tier | Notes |
|-------|------|-------|
| `title.original` | T1 | Public for non-draft claims |
| `body.original` | T1 | Public for non-draft claims |
| `category` | T1 | Public |
| `status` | T1 | Public |
| `locationId` / `locationPath` | T1 | Public |
| `tags` | T1 | Public |
| `submittedAt` | T1 | Public |
| `submittedBy` (user ID reference) | T3 | Owner sees own; moderator+ sees all |
| `isPublic = false` claims | T3 | Not returned in public listing; owner only |
| Draft claims (`status = draft`) | T3 | Owner only until submitted |

### 3.3 Evidence Collection

| Field | Tier | Notes |
|-------|------|-------|
| `sourceType`, `title`, `description`, `url` | T1 | Public |
| `dateOfEvidence`, `retrievedAt` | T1 | Public |
| `languageOfEvidence` | T1 | Public |
| `uploadedBy` (display name only) | T2 | Authenticated users |
| `uploadedBy` (user ID) | T4 | Reviewer+ only |
| `documentRef` (internal storage path) | T5 | Admin only; never in API response |
| Uploaded file content | T4 | Reviewer+ may view; not public |

### 3.4 Reviews Collection

| Field | Tier | Notes |
|-------|------|-------|
| `decisionStatus` | T1 | Public |
| `reviewerNote` | T1 | Public-facing summary |
| `timestamp` | T1 | Public |
| `sourcesConsidered` (evidence IDs) | T2 | Authenticated |
| `reviewerId` (display name) | T2 | Authenticated |
| `reviewerId` (user ID) | T4 | Reviewer+ only |
| `reason` | T4 | Reviewer+ only (internal justification) |
| `internalNote` | T4 | Reviewer+ only; **never** in public API |
| `previousStatus` | T4 | Reviewer+ only |

### 3.5 Audit Logs Collection

| Field | Tier | Notes |
|-------|------|-------|
| All audit log fields | T4 | Moderator+ only |
| `actorId` | T4 | Moderator+ (user reference, not PII) |
| `ipAddress` | T5 | Stored as hash only; admin-only access |
| Raw IP address | T6 | Must **never** be stored in plaintext |

### 3.6 Translations Collection

| Field | Tier | Notes |
|-------|------|-------|
| `language`, `content` | T1 | Public |
| `translatedBy` (display name) | T2 | Authenticated |
| `isHumanTranslated` | T1 | Public (transparency) |
| `reviewedBy` (display name) | T2 | Authenticated |

### 3.7 Appeals Collection

| Field | Tier | Notes |
|-------|------|-------|
| `status` | T3 | Owner + moderator+ |
| `reason` | T3 | Owner + moderator+ |
| `appellantId` | T4 | Moderator+ only |
| All other fields | T4 | Moderator+ only |

---

## 4. API Response Rules

| Rule | Enforcement Point |
|------|-------------------|
| `passwordHash` is never serialized to JSON | DTO transform / Mongoose `toJSON` projection |
| `email` (raw or hashed) is never in response body | DTO transform |
| `internalNote` is never in public review response | DTO transform |
| T5/T6 fields must be excluded from Mongoose projections by default | Repository layer (explicit `select` with exclusions) |
| `ipAddress` stored only as SHA-256 hash | Audit logger middleware |
| Identity document data rejected at ingestion point | Validation middleware (never persisted) |

---

## 5. Log Sanitization Rules

The following must **never** appear in any application log (stdout, stderr, log files, audit trail):

- Passwords or password hashes
- Raw IP addresses (use hash)
- JWT tokens (access or refresh)
- Identity document numbers
- Email addresses in plaintext (use user ID in logs)
- File upload content

---

## 6. Content by Category — Public Exposure Rules

| Category | Draft | Submitted/Under Review | Verified/Unverified/Partial | Disputed | Rejected | Archived |
|----------|-------|----------------------|----------------------------|----------|----------|----------|
| `HISTORICAL_RECORD` | T3 | T2 | T1 | T1 | T4 | T1 |
| `CURRENT_FACT` | T3 | T2 | T1 | T1 | T4 | T1 |
| `FOLKLORE` | T3 | T2 | T1 | T1 | T4 | T1 |
| `PERSONAL_EXPERIENCE` | T3 | T2 | T1 | T1 | T4 | T1 |
| `PUBLIC_OPINION` | T3 | T2 | T1 | T1 | T4 | T1 |
| `SURVEY_DATA` | T3 | T2 | T1 | T1 | T4 | T1 |
| `DISPUTED_CLAIM` | T3 | T2 | T1 | T1 | T4 | T1 |

> [!NOTE]
> `Rejected` claims are only visible to `REVIEWER+`. The existence of a rejection is surfaced as a status count aggregate (e.g., on a place page) without exposing rejected content publicly.

---

## 7. Data Retention

| Data Type | Retention Rule |
|-----------|----------------|
| Published claims | Indefinite (archival on removal) |
| Draft claims (inactive > 1 year) | Flag for owner review; not auto-deleted |
| Audit logs | Indefinite (append-only, never deleted) |
| Review records | Indefinite (corrections additive, not destructive) |
| Rejected claims | Retained for appeal window (90 days post-rejection); then archived, not deleted |
| Identity verification events | Retain boolean flag indefinitely; document hash for 3 years |
| Raw uploaded files | Per moderation decision; deleted only with moderator action + audit entry |
| Session tokens | Invalidated on logout; refresh tokens expire per `JWT_REFRESH_EXPIRES_IN` |

---

## 8. Cross-Reference with Other Docs

- **Who can change claim status:** see [`verification-policy.md`](./verification-policy.md)
- **API field shapes:** see [`api-contract.md`](./api-contract.md)
- **MongoDB field definitions:** see [`architecture.md`](./architecture.md)
- **User roles and permissions:** see [`requirements.md`](./requirements.md)
