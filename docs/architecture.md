# My Root — Architecture Document

> Version: 1.0.0 | Date: 2026-10-15 | Status: Baseline

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                             │
│  Flutter App (Windows / Web / Android / iOS / Linux / macOS)   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │  lib/app │ │lib/core  │ │lib/ui/   │ │lib/repositories/ │  │
│  │ (routing)│ │(l10n,DI) │ │card/,    │ │(data access)     │  │
│  └──────────┘ └──────────┘ │pages/    │ └──────────────────┘  │
│                             └──────────┘                        │
└─────────────────────────┬───────────────────────────────────────┘
                          │ HTTPS / REST / JSON
┌─────────────────────────▼───────────────────────────────────────┐
│                       BACKEND LAYER                             │
│         TypeScript + Node.js + Express (backend/)               │
│  ┌──────────┐ ┌───────────┐ ┌────────────┐ ┌──────────────┐   │
│  │  Routes  │ │Controllers│ │  Services  │ │ Repositories │   │
│  │          │ │(HTTP only)│ │(biz logic) │ │(DB queries)  │   │
│  └──────────┘ └───────────┘ └────────────┘ └──────────────┘   │
│  ┌──────────┐ ┌───────────┐ ┌────────────┐                     │
│  │Validation│ │Middleware │ │   Config   │                     │
│  │ (Zod)   │ │(auth,log) │ │(env-only)  │                     │
│  └──────────┘ └───────────┘ └────────────┘                     │
└─────────────────────────┬───────────────────────────────────────┘
                          │ Mongoose ODM
┌─────────────────────────▼───────────────────────────────────────┐
│                       DATA LAYER                                │
│                   MongoDB (Atlas or local)                      │
│  Collections: users, places, claims, evidence,                  │
│               reviews, auditLogs, translations, appeals         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Backend Module Structure

```
backend/
├── src/
│   ├── config/              # Environment config, DB connection
│   │   ├── env.ts           # Zod-validated env schema
│   │   └── database.ts      # MongoDB connection factory
│   ├── modules/
│   │   ├── auth/            # Authentication & identity
│   │   │   ├── routes.ts
│   │   │   ├── controller.ts
│   │   │   ├── service.ts
│   │   │   ├── repository.ts
│   │   │   └── validation.ts
│   │   ├── places/          # Geographic hierarchy
│   │   ├── claims/          # Core content claims
│   │   ├── evidence/        # Evidence attachments
│   │   ├── reviews/         # Review & moderation
│   │   ├── opinions/        # Public opinions & surveys
│   │   ├── translations/    # Multilingual content
│   │   └── appeals/         # Appeal workflow
│   ├── middleware/
│   │   ├── authenticate.ts  # JWT verification
│   │   ├── authorize.ts     # Role-based access
│   │   ├── validateRequest.ts
│   │   └── auditLogger.ts
│   ├── shared/
│   │   ├── types/           # Shared TypeScript types
│   │   ├── errors/          # Custom error classes
│   │   ├── utils/           # Shared utilities
│   │   └── constants.ts
│   ├── app.ts               # Express app factory
│   └── server.ts            # HTTP server entry point
├── tests/
│   ├── unit/
│   └── integration/
├── package.json
├── tsconfig.json
└── .env.example
```

---

## 3. Frontend Module Structure

```
frontend/
├── lib/
│   ├── app/
│   │   ├── app.dart                # MaterialApp root
│   │   ├── routes/                 # GoRouter route definitions
│   │   └── theme/                  # AppTheme, colors, text styles
│   ├── core/
│   │   ├── localization/           # l10n ARB files + generated code
│   │   │   ├── app_en.arb
│   │   │   ├── app_hi.arb
│   │   │   └── l10n.dart
│   │   ├── di/                     # Dependency injection (Riverpod)
│   │   ├── network/                # HTTP client, interceptors
│   │   ├── error/                  # Error types, failure models
│   │   └── constants.dart
│   ├── models/                     # Dart data models (freezed/json)
│   │   ├── claim.dart
│   │   ├── place.dart
│   │   ├── user.dart
│   │   └── review.dart
│   ├── repositories/               # Abstract + concrete data sources
│   │   ├── claim_repository.dart
│   │   ├── place_repository.dart
│   │   └── auth_repository.dart
│   ├── services/                   # Business logic / use cases
│   │   ├── claim_service.dart
│   │   └── auth_service.dart
│   └── ui/
│       ├── card/                   # ALL reusable Card widgets (one place only)
│       │   ├── claim_card.dart
│       │   ├── place_card.dart
│       │   └── review_card.dart
│       ├── pages/                  # Full-page screens (no local Card impls)
│       │   ├── home/
│       │   ├── claim_detail/
│       │   ├── submit_claim/
│       │   └── profile/
│       ├── widgets/                # Non-card reusable widgets
│       └── common/                 # Shared UI elements
├── test/
│   ├── unit/
│   └── widget/
├── pubspec.yaml
├── l10n.yaml
└── analysis_options.yaml
```

---

## 4. MongoDB Collections and Indexes

### 4.1 `users`
```json
{
  "_id": "ObjectId",
  "displayName": "string",
  "email": "string (hashed for lookup)",
  "passwordHash": "string",
  "role": "GUEST|CONTRIBUTOR|LOCAL_CONTRIBUTOR|REVIEWER|MODERATOR|ADMIN",
  "isIdentityVerified": "boolean",
  "verifiedLocationId": "ObjectId|null",
  "joinedAt": "Date",
  "isActive": "boolean"
}
```
**Indexes:** `email` (unique), `role`, `verifiedLocationId`

### 4.2 `places`
```json
{
  "_id": "ObjectId",
  "level": "COUNTRY|STATE|DISTRICT|TEHSIL|CITY_TOWN|VILLAGE",
  "names": [{"language": "hi|en", "name": "string"}],
  "parentId": "ObjectId|null",
  "canonicalName": "string",
  "geoCoordinates": {"lat": "number", "lng": "number"}
}
```
**Indexes:** `parentId`, `level`, `canonicalName` (unique), compound `(level, parentId)`

### 4.3 `claims`
```json
{
  "_id": "ObjectId",
  "title": {"original": "string", "language": "string"},
  "body": {"original": "string", "language": "string"},
  "category": "HISTORICAL_RECORD|CURRENT_FACT|FOLKLORE|PERSONAL_EXPERIENCE|PUBLIC_OPINION|SURVEY_DATA|DISPUTED_CLAIM",
  "status": "draft|submitted|under_review|verified|partially_verified|unverified|disputed|insufficient_evidence|rejected|archived",
  "locationId": "ObjectId",
  "locationPath": ["ObjectId"],
  "submittedBy": "ObjectId",
  "submittedAt": "Date",
  "updatedAt": "Date",
  "tags": ["string"],
  "evidenceIds": ["ObjectId"],
  "isPublic": "boolean"
}
```
**Location Hierarchy Rules for Claims:**
- `locationId` stores the `ObjectId` of the selected leaf Place entity.
- `locationPath` stores an ordered array of Place `ObjectId`s from Country down to the leaf Place (`Country → State → optional District → optional Tehsil → optional (City/Town or Village)`).
- `locationPath` is authoritative and strictly resolved by the backend server from the authoritative Places hierarchy; client-supplied path, ancestry, or place names are never accepted.
- Every claim must anchor to at least `Country` and `State` (leaf level cannot be bare `Country`).
- Skipping levels is prohibited (every ancestor in the path must exist and link via valid `parentId`).
- Hierarchy structure: `COUNTRY` (root) → `STATE` → `DISTRICT` → `TEHSIL` → (`CITY_TOWN` or `VILLAGE` as direct sibling alternatives under `TEHSIL`). Direct creation under `DISTRICT` for City/Town or Village is disallowed, and nesting Village under City/Town is disallowed.

**Indexes:** `status`, `category`, `locationId`, `locationPath`, `submittedBy`, `submittedAt`, compound `(locationId, category, status)`, text index on `(title.original, body.original)`

### 4.4 `evidence`
```json
{
  "_id": "ObjectId",
  "claimId": "ObjectId",
  "sourceType": "DOCUMENT|URL|PHOTOGRAPH|ORAL_TESTIMONY|GOVERNMENT_RECORD|ACADEMIC_PAPER|NEWS_ARTICLE|OTHER",
  "title": "string",
  "description": "string",
  "url": "string|null",
  "documentRef": "string|null",
  "dateOfEvidence": "Date|null",
  "retrievedAt": "Date|null",
  "languageOfEvidence": "string",
  "uploadedBy": "ObjectId",
  "uploadedAt": "Date",
  "counterEvidenceIds": ["ObjectId"]
}
```
**Indexes:** `claimId`, `uploadedBy`, `sourceType`

### 4.5 `reviews`
```json
{
  "_id": "ObjectId",
  "claimId": "ObjectId",
  "reviewerId": "ObjectId",
  "previousStatus": "string",
  "decisionStatus": "string",
  "reason": "string (min 50 chars)",
  "sourcesConsidered": ["ObjectId"],
  "timestamp": "Date",
  "reviewerNote": "string",
  "internalNote": "string",
  "isAppealReview": "boolean",
  "appealsOriginalReviewId": "ObjectId|null"
}
```
**Indexes:** `claimId`, `reviewerId`, `timestamp`, `decisionStatus`

### 4.6 `auditLogs`
```json
{
  "_id": "ObjectId",
  "entityType": "claim|review|user|place|evidence",
  "entityId": "ObjectId",
  "actorId": "ObjectId",
  "action": "string",
  "before": "object|null",
  "after": "object|null",
  "timestamp": "Date",
  "ipAddress": "string (hashed)",
  "metadata": "object"
}
```
**Indexes:** `entityId`, `actorId`, `timestamp`, `entityType`

**Phase 4 Internal Audit Writer Specification:**
- Reuses the existing `auditLogs` schema above without modification.
- In Phase 4, an internal audit writer helper is introduced strictly for claim lifecycle events (`claim.submitted`, `claim.archived`).
- **Atomic MongoDB Transaction Requirement:** Any claim status transition (`draft → submitted` via `PATCH /claims/:id/submit`) or soft-archive (`DELETE /claims/:id`) must execute within a native MongoDB transaction alongside its corresponding `auditLogs` document creation.
- If the audit log write fails or the transaction aborts, the claim mutation will NOT commit (full rollback). Partial success is prohibited.
- Full public/moderator audit query endpoints, audit search UI, and the complete standalone Audit module remain deferred to Phase 7.

### 4.7 `translations`
```json
{
  "_id": "ObjectId",
  "claimId": "ObjectId",
  "field": "title|body",
  "language": "string (BCP-47)",
  "content": "string",
  "translatedBy": "ObjectId",
  "translatedAt": "Date",
  "isHumanTranslated": "boolean",
  "reviewedBy": "ObjectId|null"
}
```
**Indexes:** compound `(claimId, language, field)` unique, `translatedBy`

### 4.8 `appeals`
```json
{
  "_id": "ObjectId",
  "claimId": "ObjectId",
  "originalReviewId": "ObjectId",
  "appellantId": "ObjectId",
  "reason": "string",
  "submittedAt": "Date",
  "status": "pending|assigned|resolved|rejected",
  "assignedReviewerId": "ObjectId|null",
  "resolvedAt": "Date|null"
}
```
**Indexes:** `claimId`, `appellantId`, `status`

---

## 5. API Boundaries and Responsibilities

See `docs/api-contract.md` for full endpoint specifications.

### Module Responsibility Matrix

| Module | Routes | Controller | Service | Repository |
|--------|--------|------------|---------|------------|
| auth | /auth/* | HTTP parse/response | JWT, bcrypt, session | user DB ops |
| places | /places/* | HTTP parse/response | hierarchy validation | place DB ops |
| claims | /claims/* | HTTP parse/response | status machine, self-approval block | claim DB ops |
| evidence | /evidence/* | HTTP parse/response | file validation, provenance | evidence DB ops |
| reviews | /reviews/* | HTTP parse/response | reviewer != submitter, audit log | review DB ops |
| opinions | /opinions/* | HTTP parse/response | vote aggregation | opinion DB ops |
| translations | /translations/* | HTTP parse/response | language validation, source preservation | translation DB ops |
| appeals | /appeals/* | HTTP parse/response | different reviewer assignment | appeal DB ops |

---

## 6. Cross-Cutting Concerns

### 6.1 Authentication Flow
```
Client → POST /auth/login → JWT (access + refresh tokens)
Client → Authorization: Bearer <token> → authenticate middleware
authenticate → authorize(role) → route handler
```

### 6.2 Audit Log Flow
Every mutating operation:
```
Controller → Service → Repository → [write DB] → auditLogger.log(...)
```
For general non-critical mutations, the audit logger runs in a `finally` block where failures are logged to stderr but do not roll back the primary operation.

**Critical Status Transition, Archival & Consent Atomicity Rule (Phase 4+):**
For high-integrity lifecycle changes (specifically Claim submission `draft → submitted`, soft-archive `any → archived`, and living-person biography consent verification/revocation `verifyClaimConsent`), the audit record creation and the entity status/consent mutation MUST execute within the **same atomic MongoDB transaction session** under exclusive write locking (`touch`). If the audit write fails or the transaction encounters an error, the entire operation is aborted and rolled back. An un-audited lifecycle mutation must never commit.

### 6.3 Error Handling
- Custom error classes: `ValidationError`, `AuthorizationError`, `NotFoundError`, `ConflictError`, `BusinessRuleError`
- All errors mapped to HTTP status codes in global error middleware
- Stack traces never exposed in production responses

### 6.4 Configuration
- ALL secrets via environment variables only (never in source)
- Validated at startup with Zod; app fails fast on invalid config
- `.env.example` documents all required variables (no actual values)

---

## 7. Security Architecture

| Concern | Mitigation |
|---------|-----------|
| Authentication | JWT with short expiry; refresh token rotation |
| Authorization | Role-based middleware; resource ownership check in service layer |
| Self-approval | `claim.submittedBy !== reviewer.userId` checked in service |
| PII protection | Identity docs never stored plaintext; only hashed reference |
| Input validation | Zod schemas on all incoming data; parameterized queries via Mongoose |
| File uploads | Type validation; size limits; stored outside web root |
| Audit trail | Immutable append-only audit log; admin access only |
| Secrets | Env vars only; `.env` in `.gitignore`; `.env.example` committed |

---

## 8. Localization Architecture (Flutter)

- Uses Flutter's official `flutter_localizations` + `intl` package
- ARB files per language: `app_en.arb`, `app_hi.arb`
- Generated Dart code via `flutter gen-l10n`
- `l10n.yaml` configured for synthetic package generation
- UI strings accessed via `AppLocalizations.of(context)!.stringKey`
- No hard-coded strings in UI layer
- Language preference stored locally; API locale header sent on requests

---

## 9. Platform Targets

| Platform | Build Command | Notes |
|----------|---------------|-------|
| Windows | `flutter build windows` | Primary dev target |
| Web | `flutter build web` | PWA-capable |
| Android | `flutter build apk` | Min SDK 21 |
| iOS | `flutter build ios` | Requires macOS + Xcode |
| Linux | `flutter build linux` | Ubuntu 20.04+ |
| macOS | `flutter build macos` | Requires macOS |

---

## 10. Development Phases

| Phase | Scope |
|-------|-------|
| Phase 0 | Architecture docs, project scaffold |
| Phase 1 | Health endpoint, MongoDB connectivity, Flutter starter, basic tests |
| Phase 2 | Auth module (register, login, JWT) |
| Phase 3 | Places module (CRUD, hierarchy) |
| Phase 4 | Claims module (submit, status machine) |
| Phase 5 | Evidence module |
| Phase 6 | Reviews module (with self-approval block) |
| Phase 7 | Opinions module |
| Phase 8 | Translations module |
| Phase 9 | Appeals module |
| Phase 10 | Full Flutter UI for each module |
