# My Root — Requirements Document

> Version: 1.0.0 | Date: 2026-10-15 | Status: Baseline

---

## 1. Project Overview

**My Root** is a multilingual, community-driven platform for preserving and verifying local knowledge — history, folklore, proverbs, personal experiences, surveys, and opinions — organized by geographic hierarchy across India.

### 1.1 Core Mission

- Preserve original-language content (Hindi, regional languages, English)
- Distinguish verified historical records from folklore, opinions, and disputed claims
- Enable community contribution with rigorous, transparent verification
- Protect contributor privacy while maintaining public auditability of claim decisions

---

## 2. Geographic Hierarchy

All content is anchored to a strict geographic hierarchy:

```
Country → State → District → Tehsil → (City/Town OR Village)
```

| Level | Level Key | Example | Parent Rule |
|-------|-----------|---------|-------------|
| 1 | `COUNTRY` | India | No parent permitted |
| 2 | `STATE` | Rajasthan | Requires `COUNTRY` |
| 3 | `DISTRICT` | Jodhpur | Requires `STATE` |
| 4 | `TEHSIL` | Luni / Jodhpur | Requires `DISTRICT` |
| 5a | `CITY_TOWN` | Jodhpur City | Requires `TEHSIL` |
| 5b | `VILLAGE` | Mandore | Requires `TEHSIL` |

**Rules:**
- Every claim MUST be associated with at least `country` + `state`.
- Finer levels (`district → tehsil → cityOrTown | village`) are optional but encouraged.
- `CITY_TOWN` and `VILLAGE` are direct sibling alternative child types under `TEHSIL`.
- Neither `CITY_TOWN` nor `VILLAGE` may be created directly under `DISTRICT`.
- `VILLAGE` may not be nested under `CITY_TOWN`.
- Location data is normalized; a canonical ID is assigned to each place entity.
- Location names are stored in multiple languages (original + translations).
- No claim may skip levels (e.g., a claim at `village` or `cityOrTown` must have all parent levels: Country, State, District, and Tehsil populated in its locationPath).

---

## 3. Content Categories

Each piece of content (a "claim" or "entry") MUST be assigned exactly one primary category:

| Category Key | Display Name (EN) | Display Name (HI) | Description |
|---|---|---|---|
| `HISTORICAL_RECORD` | Historical Record | ऐतिहासिक अभिलेख | Documented events with archival evidence |
| `CURRENT_FACT` | Current Fact | वर्तमान तथ्य | Verifiable present-day information |
| `FOLKLORE` | Folklore / Proverb | लोककथा / कहावत | Oral traditions, legends, proverbs |
| `PERSONAL_EXPERIENCE` | Personal Experience | व्यक्तिगत अनुभव | First-person accounts |
| `PUBLIC_OPINION` | Public Opinion | जनमत | Community perspectives, not claimed as fact |
| `SURVEY_DATA` | Survey / Research Data | सर्वेक्षण डेटा | Structured survey results with methodology |
| `DISPUTED_CLAIM` | Disputed Claim | विवादित दावा | Claims with conflicting evidence |

**Key Rule:** A `FOLKLORE` entry **cannot** be promoted to `HISTORICAL_RECORD` without independent archival evidence reviewed by a qualified reviewer. Popularity or vote count is **never** sufficient.

---

## 4. User Roles and Identity

### 4.1 Roles

| Role | Key | Permissions |
|------|-----|-------------|
| Guest | `GUEST` | Read public content only |
| Contributor | `CONTRIBUTOR` | Submit claims, evidence; cannot self-approve |
| Local Contributor | `LOCAL_CONTRIBUTOR` | Same as Contributor + verified location association |
| Reviewer | `REVIEWER` | Review, verify, partially verify, or reject claims |
| Moderator | `MODERATOR` | Moderate content, handle disputes |
| Admin | `ADMIN` | Full system access |

### 4.2 Verified Identity vs. Verified Claim

> **Critical Distinction:**
> - A user's identity being **verified** (e.g., Aadhaar-linked, government ID confirmed) means we trust **who they are**.
> - It does **NOT** mean their claims are automatically verified.
> - Claim verification requires **independent evidence review** regardless of contributor identity.

### 4.3 Local Contributor Verification

- Must provide proof of local association (residence document, community letter, etc.)
- Verification confirms geographic association, not factual accuracy of submissions
- Verified local contributors get priority review queue access, not auto-approval

### 4.4 Privacy Rules

- Identity documents (Aadhaar, voter ID, etc.) are **never** stored in plaintext
- Document references are hashed and stored in a separate, access-controlled collection
- Public profile shows only: display name, location (city/district level), join date, contribution count
- No personal contact information is exposed via any API

### 4.5 Place-Based User Classification & Guest View-Only Mode

- **Removal of Residence Type:** Permanent/Temporary residence type is removed from the product and authorization flows. It is never prompted for or required to establish an active place or make contributions.
- **Active Place Selection Gate:** A place is considered selected ONLY after the authenticated user explicitly chooses one of: `Indigenous` or `Non-Indigenous`. Merely searching for, tapping, or viewing a place does not establish an active selected place (`selectedPlaceId` remains `null`).
- **Place-Specific Association:** Classification (`indigenousClassification`: `Indigenous` or `Non-Indigenous`) belongs strictly to each individual user-place relationship and is never a global identity field.
- **Prohibition on Inference:** Indigenous/Non-Indigenous classification is never inferred from name, caste, religion, geographic location, or authorization roles, and is never copied across places.
- **Repeat Selection Invariance:** Selecting an already-classified place restores the active selected place immediately without re-prompting.
- **Guest / View-Only Mode:** Users with no actively selected/classified place:
  - May view information where existing authentication permits (authenticated GETs preserved).
  - May Like (`agree`), Dislike (`disagree`), and report `Wrong` (feedback/dispute reporting).
  - Must NOT create or submit new place information, claims, evidence, attributes, or other contribution/write content (blocked in UI and server-side with `403 UNAUTHORIZED` / `403 Forbidden`).
  - Receive a clear, contextual prompt to select a place and choose Indigenous or Non-Indigenous when attempting a blocked contribution.
- **Equal Contribution Rights:** Once selected through explicit classification, contribution access is governed by existing authorization/verification rules. Indigenous and Non-Indigenous users possess identical contribution rights.

---

## 5. Claim Lifecycle and Statuses

### 5.1 Status Definitions

| Status | Key | Description |
|--------|-----|-------------|
| Draft | `draft` | Saved by contributor, not submitted |
| Submitted | `submitted` | Submitted for review, awaiting assignment |
| Under Review | `under_review` | Assigned to a reviewer |
| Verified | `verified` | Fully verified with sufficient evidence |
| Partially Verified | `partially_verified` | Some aspects verified, others uncertain |
| Unverified | `unverified` | No evidence found either way |
| Disputed | `disputed` | Conflicting evidence or counter-claims exist |
| Insufficient Evidence | `insufficient_evidence` | Reviewer determined evidence is inadequate |
| Rejected | `rejected` | Does not meet content policy or is false |
| Archived | `archived` | Retired content, preserved for historical record |

### 5.2 Status Transition Rules

```
draft → submitted → under_review → [verified | partially_verified | unverified |
                                     disputed | insufficient_evidence | rejected]
any_status → archived (moderator/admin only)
rejected → submitted (via appeal)
disputed → under_review (via reassignment)
```

### 5.3 Self-Approval Prohibition

A contributor **cannot** review or approve their own claims. This is enforced at:
- API middleware level (claim `submittedBy` !== reviewer `userId`)
- Service layer assertion
- Audit log flags any attempt

---

## 6. Evidence and Provenance

Each claim may have multiple evidence items. Each evidence item contains:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `sourceType` | enum | Yes | `DOCUMENT`, `URL`, `PHOTOGRAPH`, `ORAL_TESTIMONY`, `GOVERNMENT_RECORD`, `ACADEMIC_PAPER`, `NEWS_ARTICLE`, `OTHER` |
| `title` | string | Yes | Title of the source |
| `description` | string | No | What this evidence proves |
| `url` | string | No | Web link (validated) |
| `documentRef` | string | No | Internal document storage reference |
| `dateOfEvidence` | date | No | When the evidence was created/published |
| `retrievedAt` | date | Conditional | Required for URLs |
| `languageOfEvidence` | string | No | BCP-47 language code |
| `uploadedBy` | userId | Yes | Who attached this evidence |
| `uploadedAt` | timestamp | Yes | When it was attached |
| `counterEvidence` | array | No | References to contradicting evidence |

### 6.1 Evidence Review on Archived Claims (Option B Policy)

- **Permitted Review on Existing Evidence:** Authorized reviewers (`REVIEWER`+) may review or update decisions on existing Evidence records even if the parent Claim is `archived`.
- **Claim Invariance:** Reviewing an Evidence record attached to an archived Claim does not change the parent Claim's status, reactivate the Claim, or mark it verified. The Claim remains strictly `archived`.
- **Strict Prohibition on New Evidence:** Submitting **new** Evidence against an archived Claim remains strictly blocked (`422 BUSINESS_RULE_VIOLATION`).
- **Standard Protections Enforced:** Reviewer role check, self-review prohibition, minimum justification length, audit logging (`evidence.reviewed`), and transaction boundaries remain fully in effect. No other archived-Claim mutations are permitted.

### 6.2 Evidence Submission on Revoked-Consent Biographies (Option 1: Dispute Resolution Model)

- **Consent Revocation Effects:** When an authorized reviewer revokes consent for a living-person biography (`consentState = 'consent_revoked'`), the biography is immediately retracted from public display (`isPublic = false`), moved from `verified` to `disputed`, and strictly blocked from claim verification until valid consent is independently re-established.
- **Permitted Evidence for Dispute Resolution:** Evidence submission against a `disputed` Claim with revoked consent remains permitted under standard eligibility rules (authentication, authorization, schema validation, and ownership). This enables the subject, legal representatives, or contributors to submit identity proof, withdrawal notices, or amended consent agreements to resolve the dispute.
- **No Automatic Publication or Verification:** Permitting Evidence submission does NOT grant consent, make the biography public, restore verified status, or reactivate the Claim into a publishable state.
- **Verification Gate Invariance:** Claim verification remains strictly blocked while consent is `pending_verification` or `consent_revoked` (`422 BUSINESS_RULE_VIOLATION`). It may proceed only after consent has been validly re-established through the authorized independent verification process.
- **Atomicity and Transaction Guarantees:**
  - Evidence submission (`evidence` creation, `claim.evidenceIds` append, and `evidence.created` audit log) commits atomically within a MongoDB transaction session.
  - Consent revocation (`claim.consentState = 'consent_revoked'`, `isPublic = false`, status update, and `claim.consent_revoked` audit log) commits atomically within a MongoDB transaction session under WiredTiger document write locks (`touch`). Failure to write the audit record aborts and rolls back the revocation entirely.
  - Submissions to `rejected` or `archived` Claims remain strictly prohibited.

---

## 7. Review Process

### 7.1 Review Record Fields

Every review action is permanently recorded with:

| Field | Description |
|-------|-------------|
| `reviewId` | Unique ID |
| `claimId` | The claim reviewed |
| `reviewerId` | Reviewer's user ID (never the submitter) |
| `decisionStatus` | New status assigned |
| `reason` | Written justification (minimum 50 chars) |
| `sourcesConsidered` | Evidence IDs examined |
| `timestamp` | When the review was completed |
| `reviewerNote` | Public-facing summary |
| `internalNote` | Internal-only note (not exposed via public API) |

### 7.2 Corrections and Audit Trail

- Previous decisions are **never deleted or silently overwritten**
- Each status change creates a new `ReviewAuditEntry`
- Corrections reference the prior review record
- Full audit history is queryable by moderators/admins

### 7.3 Appeals

- A contributor may appeal a `rejected` or `insufficient_evidence` decision
- Appeals are assigned to a **different** reviewer than the original
- Appeal decisions are also fully audited

---

## 8. Multilingual Content

### 8.1 Content Storage Strategy

- Original-language content is stored in a dedicated `originalLanguage` field and is **immutable after submission**
- Translations are stored as separate `Translation` documents linked to the original claim
- Translations do **not** modify the original; they are additive
- Each translation records: `language`, `translatedBy`, `translatedAt`, `isHumanTranslated` (vs. machine-generated), `reviewedBy`

### 8.2 Supported Languages (Initial)

| Code | Language | Script |
|------|----------|--------|
| `hi` | Hindi | Devanagari |
| `en` | English | Latin |

### 8.3 Planned Future Languages

Rajasthani, Bhojpuri, Maithili, Marathi, Tamil, Telugu, Kannada, Bengali, Gujarati, Punjabi — and others via community contribution.

---

## 9. Non-Functional Requirements

| Area | Requirement |
|------|-------------|
| Security | JWT authentication; role-based access control; secrets via environment variables only |
| Privacy | PII never in public APIs; document IDs hashed; audit logs access-controlled |
| Auditability | Every status change, review, appeal, correction logged with actor + timestamp |
| Scalability | MongoDB with appropriate indexes; stateless backend for horizontal scaling |
| Accessibility | Flutter app with localization from day one; screen-reader friendly |
| Offline support | Planned for future; architecture must not preclude it |
| Source preservation | Original language content is immutable once submitted |

---

## 10. Out of Scope (v1.0)

- Real-time collaborative editing
- Automated AI-based fact-checking (may assist, not decide)
- Payment or monetization features
- Federated identity across organizations
- Offline-first sync engine (architecture must allow future addition)
