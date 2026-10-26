# My Root — API Contract

> Version: 1.0.0 | Date: 2026-10-15 | Base URL: `/api/v1`

---

## Conventions

- All requests/responses: `Content-Type: application/json`
- Auth: `Authorization: Bearer <jwt_access_token>`
- Dates: ISO 8601 UTC strings
- Errors: `{ "error": { "code": "ERROR_CODE", "message": "...", "details": {} } }`
- Pagination: `?page=1&limit=20` → `{ "data": [...], "pagination": { "page": 1, "limit": 20, "total": 100, "pages": 5 } }`

---

## 1. Health & System

### `GET /health`
No auth required.
```json
Response 200:
{
  "status": "ok",
  "timestamp": "2026-10-15T12:00:00.000Z",
  "version": "1.0.0",
  "services": {
    "database": "connected" | "disconnected"
  }
}
```

---

## 2. Authentication (`/auth`)

### `POST /auth/register`
```json
Request:
{ "displayName": "string", "email": "string", "password": "string (min 8 chars)" }

Response 201:
{ "message": "Registration successful. Please verify your email." }

Errors: 409 (email exists), 400 (validation)
```

### `POST /auth/login`
```json
Request:
{ "email": "string", "password": "string" }

Response 200:
{
  "accessToken": "string (JWT, 15min expiry)",
  "refreshToken": "string (JWT, 7d expiry)",
  "user": { "id": "string", "displayName": "string", "role": "string" }
}

Errors: 401 (invalid credentials), 403 (account disabled)
```

### `POST /auth/refresh`
```json
Request: { "refreshToken": "string" }
Response 200: { "accessToken": "string" }
Errors: 401 (invalid/expired refresh token)
```

### `POST /auth/logout`
Auth required.
```json
Response 200: { "message": "Logged out successfully" }
```

### `GET /auth/me`
Auth required.
```json
Response 200:
{
  "user": {
    "id": "string",
    "displayName": "string",
    "role": "GUEST|CONTRIBUTOR|LOCAL_CONTRIBUTOR|REVIEWER|MODERATOR|ADMIN",
    "selectedPlaceId": "string|null",
    "indigenousClassification": "Indigenous|Non-Indigenous|null",
    "joinedAt": "string (ISO 8601)",
    "currentPlaceRelationship": {
      "placeId": "string",
      "residenceType": "string (optional/legacy)",
      "indigenousClassification": "Indigenous|Non-Indigenous|null",
      "createdAt": "string (ISO 8601)"
    } | null,
    "placeRelationships": [
      {
        "placeId": "string",
        "residenceType": "string (optional/legacy)",
        "indigenousClassification": "Indigenous|Non-Indigenous",
        "createdAt": "string (ISO 8601)"
      }
    ]
  }
}
```

### `PATCH /auth/me`
Auth required.
```json
Request:
{
  "displayName": "string (optional)",
  "selectedPlaceId": "string|null (optional)",
  "placeRelationship": {
    "placeId": "string",
    "residenceType": "string (optional/legacy)",
    "indigenousClassification": "Indigenous|Non-Indigenous"
  } (optional)
}
Response 200:
{
  "user": { ... }
}
```
**Place Relationship & Selection Rules:**
- Setting `selectedPlaceId` directly requires an existing established relationship with explicit `Indigenous` or `Non-Indigenous` classification; otherwise returns `422 UNPROCESSABLE_ENTITY`.
- Submitting `placeRelationship` establishes or updates the user's place-scoped classification (`indigenousClassification`: `Indigenous` or `Non-Indigenous`). A place is considered selected ONLY after explicit classification is successfully persisted.
- Residence type (`Permanent` / `Temporary`) is removed from the product requirement and authorization flow.
- Indigenous / Non-Indigenous classification is **strictly place-specific** and never inferred from caste, name, religion, authorization role, or location alone.
- Users with no selected place (`selectedPlaceId === null`) may read content and submit feedback/reactions (Like, Dislike, Wrong reporting via `POST /claims/:id/feedback`), but are blocked from creating/updating claims, evidence, or attributes (`403 UNAUTHORIZED` / `403 FORBIDDEN`).

---

## 3. Places (`/places`)

### `GET /places`
```json
Query: ?level=STATE&parentId=<id>&page=1&limit=20
Response 200: { "data": [Place], "pagination": {...} }
```

### `GET /places/:id`
```json
Response 200:
{
  "id": "string",
  "level": "COUNTRY|STATE|DISTRICT|TEHSIL|CITY_TOWN|VILLAGE",
  "names": [{ "language": "hi|en", "name": "string" }],
  "canonicalName": "string",
  "parentId": "string|null",
  "parentPath": [{ "id": "string", "level": "string", "canonicalName": "string" }]
}
```

### `GET /places/:id/children`
```json
Response 200: { "data": [Place] }
```

### `POST /places` _(MODERATOR+)_
```json
Request:
{
  "level": "COUNTRY|STATE|DISTRICT|TEHSIL|CITY_TOWN|VILLAGE",
  "names": [{ "language": "string", "name": "string" }],
  "canonicalName": "string",
  "parentId": "string|null"
}
Response 201: { "data": Place }
Errors: 400 (validation / invalid hierarchy), 409 (duplicate canonicalName at level)
```
**Strict Hierarchy Rules:**
- `COUNTRY` has no parent (`parentId` must be null).
- `STATE` requires `COUNTRY`.
- `DISTRICT` requires `STATE`.
- `TEHSIL` requires `DISTRICT`.
- `CITY_TOWN` requires `TEHSIL`.
- `VILLAGE` requires `TEHSIL`.
- `CITY_TOWN` and `VILLAGE` are direct alternative child types under `TEHSIL`; neither may be created directly under `DISTRICT`, and `VILLAGE` may not be nested under `CITY_TOWN`.

---

## 4. Claims (`/claims`)

### `GET /claims`
```json
Query: ?status=verified&category=FOLKLORE&locationId=<id>&page=1&limit=20
Response 200: { "data": [ClaimSummary], "pagination": {...} }
```

### `GET /claims/:id`
```json
Response 200:
{
  "id": "string",
  "title": { "original": "string", "language": "string" },
  "body": { "original": "string", "language": "string" },
  "category": "string",
  "status": "string",
  "location": { Place },
  "submittedAt": "string",
  "evidenceCount": "number",
  "latestReview": { ReviewSummary } | null,
  "translations": [TranslationSummary]
}
Note: submittedBy.email and PII fields are NEVER returned in public API.
Note on Location Representation: Internally, the database stores authoritative `locationId` (leaf Place ObjectId) and `locationPath` (ancestor ObjectIds from Country down to leaf). In the API response, `location` returns the populated Place entity (including ancestor details/names as resolved by the server).
```

### `POST /claims` _(CONTRIBUTOR+)_
```json
Request:
{
  "title": { "original": "string", "language": "hi|en" },
  "body": { "original": "string", "language": "hi|en" },
  "category": "HISTORICAL_RECORD|CURRENT_FACT|FOLKLORE|PERSONAL_EXPERIENCE|PUBLIC_OPINION|SURVEY_DATA|DISPUTED_CLAIM",
  "locationId": "string",
  "tags": ["string"]
}
Response 201: { "data": Claim }
Errors: 400 (validation / invalid location hierarchy), 401 (unauthenticated), 403 (role)
```
**Lifecycle & Path Rules on Creation:**
- Every new claim is created strictly with `status: "draft"`.
- The client cannot supply or override `status` or `locationPath`.
- `locationPath` (`ObjectId[]`) is resolved authoritatively by the server from the Place hierarchy (`Country → State → optional District → optional City/Town → optional Village`).
- The chosen `locationId` must be at least level `STATE` (anchoring to `Country + State` minimum; bare `COUNTRY` is rejected with 400).
- **Server-Side Selected-Place Authorization:** Non-admin contributors must have a currently selected place (`selectedPlaceId`). If no place is selected (`selectedPlaceId === null`), contribution is blocked with `403 UNAUTHORIZED` (Guest / View-only mode). The target claim `locationId` must match the server-authoritative `selectedPlaceId`; submitting against mismatched places is rejected with `403 UNAUTHORIZED`. Both Indigenous and Non-Indigenous users possess equal contribution rights.

### `PATCH /claims/:id/submit` _(owner only, status: draft → submitted)_
```json
Response 200: { "data": { "status": "submitted" } }
Errors: 400 (not in draft), 401 (unauthenticated), 403 (not owner)
```
**Submission Rules:**
- This is the exclusive endpoint for submitting a claim for review (`draft → submitted`).
- Requires owner authorization (`submittedBy === req.user.userId`).
- Draft-only precondition: claim must be in `draft` status; attempting to submit an already-submitted, reviewed, or archived claim returns 400.
- Upon successful submission, original language content (`title.original`, `body.original`, and language) becomes strictly **IMMUTABLE**.
- **Atomic Audit Transaction Requirement:** Claim status mutation to `submitted` and the creation of its immutable audit log entry (`auditLogs`) must commit atomically in the same MongoDB transaction session. If audit log creation fails or the transaction encounters an error, the operation rolls back completely with no partial persistence.

### `PATCH /claims/:id` _(owner only, draft status only)_
```json
Request: { "title": {...}, "body": {...}, "tags": [...] }
Response 200: { "data": Claim }
Errors: 400 (claim not in draft), 401 (unauthenticated), 403 (not owner)
```
**Draft Edit Rules:**
- Edits to title, body, and tags are permitted **only while the claim remains in `draft` status**.
- Attempting to edit after submission returns 400 (content is immutable post-submission).

### `DELETE /claims/:id` _(MODERATOR+)_
```json
Response: Archives the claim (status → archived); does NOT delete from DB
Response 200: { "message": "Claim archived" }
Errors: 401 (unauthenticated), 403 (requires MODERATOR or ADMIN role), 404 (not found)
```
**Archival Rules:**
- Does NOT perform a physical delete; performs a soft-archive by updating `status` to `archived`.
- **Atomic Audit Transaction Requirement:** Status transition to `archived` and the creation of the corresponding `auditLogs` record must commit atomically in the same MongoDB transaction session. If the audit write fails, the archive mutation rolls back entirely.

---

## 5. Evidence (`/claims/:claimId/evidence`)

### `GET /claims/:claimId/evidence`
```json
Response 200: { "data": [Evidence] }
```

### `POST /claims/:claimId/evidence` _(CONTRIBUTOR+)_
```json
Request:
{
  "sourceType": "DOCUMENT|URL|PHOTOGRAPH|ORAL_TESTIMONY|GOVERNMENT_RECORD|ACADEMIC_PAPER|NEWS_ARTICLE|OTHER",
  "title": "string",
  "description": "string",
  "url": "string|null",
  "dateOfEvidence": "string|null",
  "retrievedAt": "string|null (required if url provided)",
  "languageOfEvidence": "string"
}
Response 201: { "data": Evidence }
Errors: 400, 403
```

---

## 6. Reviews (`/claims/:claimId/reviews`)

### `GET /claims/:claimId/reviews`
```json
Response 200: { "data": [ReviewPublic] }
Note: internalNote field is NEVER returned in public API
```

### `POST /claims/:claimId/reviews` _(REVIEWER+; NOT the claim submitter)_
```json
Request:
{
  "decisionStatus": "verified|partially_verified|unverified|disputed|insufficient_evidence|rejected",
  "reason": "string (min 50 chars)",
  "sourcesConsidered": ["evidenceId"],
  "reviewerNote": "string",
  "internalNote": "string (never public)"
}
Response 201: { "data": ReviewPublic }
Errors:
  403 — reviewer is the claim submitter (SELF_REVIEW_PROHIBITED)
  403 — claim not in 'submitted' or 'under_review' status
  400 — reason too short
  400 — invalid decisionStatus
```

---

## 7. Opinions (`/opinions`)

### `GET /opinions`
```json
Query: ?locationId=<id>&page=1&limit=20
Response 200: { "data": [Opinion], "pagination": {...} }
```

### `POST /opinions` _(CONTRIBUTOR+)_
```json
Request:
{
  "body": { "original": "string", "language": "string" },
  "locationId": "string",
  "tags": ["string"]
}
Response 201: { "data": Opinion }
Note: Opinions are categorized PUBLIC_OPINION; never promoted to verified fact
```

---

## 8. Translations (`/claims/:claimId/translations`)

### `GET /claims/:claimId/translations`
```json
Response 200: { "data": [Translation] }
```

### `POST /claims/:claimId/translations` _(CONTRIBUTOR+)_
```json
Request:
{
  "field": "title|body",
  "language": "string (BCP-47)",
  "content": "string",
  "isHumanTranslated": "boolean"
}
Response 201: { "data": Translation }
Note: Original content is NEVER modified by translation endpoint
Errors: 409 (translation for this language+field already exists)
```

---

## 9. Appeals (`/appeals`)

### `POST /appeals` _(CONTRIBUTOR, own rejected/insufficient_evidence claim)_
```json
Request:
{
  "claimId": "string",
  "originalReviewId": "string",
  "reason": "string (min 100 chars)"
}
Response 201: { "data": Appeal }
Errors:
  400 — claim not in 'rejected' or 'insufficient_evidence' status
  403 — not the claim owner
  409 — appeal already exists for this review
```

### `GET /appeals/:id` _(owner or MODERATOR+)_
```json
Response 200: { "data": Appeal }
```

### `PATCH /appeals/:id/assign` _(MODERATOR+)_
```json
Request: { "reviewerId": "string" }
Note: reviewerId MUST be different from original reviewer AND claim submitter
Response 200: { "data": Appeal }
```

---

## 10. Audit (`/audit`) _(MODERATOR+ only)_

### `GET /audit`
```json
Query: ?entityType=claim&entityId=<id>&actorId=<id>&from=<date>&to=<date>&page=1&limit=50
Response 200: { "data": [AuditLog], "pagination": {...} }
Note: ipAddress is hashed; actorId is user reference, not PII
```

---

## Error Codes Reference

| HTTP | Code | Meaning |
|------|------|---------|
| 400 | `VALIDATION_ERROR` | Request body/params failed validation |
| 401 | `UNAUTHENTICATED` | Missing or invalid JWT |
| 403 | `UNAUTHORIZED` | Valid JWT but insufficient role/ownership |
| 403 | `SELF_REVIEW_PROHIBITED` | Reviewer is the claim submitter |
| 404 | `NOT_FOUND` | Resource does not exist |
| 409 | `CONFLICT` | Duplicate resource or state conflict |
| 422 | `BUSINESS_RULE_VIOLATION` | Valid request but violates business logic |
| 429 | `RATE_LIMITED` | Too many requests |
| 500 | `INTERNAL_ERROR` | Server error (details never exposed) |
