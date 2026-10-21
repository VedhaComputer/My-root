# My Root — Verification Policy

> Version: 1.0.0 | Date: 2026-10-15 | Status: Baseline

---

## 1. Core Principles

These principles are **non-negotiable** and must be enforced at every layer (API middleware, service layer, UI policy labels, and reviewer training).

### P1 — Identity ≠ Truth

A contributor's verified identity confirms **who they are**, not **what they claim**.
- A Aadhaar-verified local resident's claim about a local event is still unverified until evidence is reviewed.
- A government official's claim requires the same evidence standard as any other contributor.
- Verified identity earns priority queue access, not auto-approval.

### P2 — Folklore ≠ History

No folklore, proverb, or oral tradition may be reclassified as `HISTORICAL_RECORD` without:
1. Independent archival documentary evidence (physical document, dated publication, government record)
2. Review by a qualified `REVIEWER` or `MODERATOR`
3. Written justification referencing the specific evidence

**The following are explicitly insufficient for historical classification:**
- Popular belief or community consensus
- High vote counts or user endorsements
- Age of the tradition alone
- The narrator's reputation or status

### P3 — Popularity ≠ Validity

Vote counts, likes, shares, or endorsement numbers are **display metrics only**. They carry **zero weight** in verification decisions. Reviewers must not cite "community consensus" or "widely believed" as a basis for verification.

### P4 — No Self-Approval

A contributor cannot approve, verify, or promote their own claims. This applies to:
- All roles including `REVIEWER` (if they submitted the claim)
- `MODERATOR` role for their own submissions (can moderate others')
- `ADMIN` role — even admins must have a second `ADMIN` review their own submissions

Technical enforcement: `claim.submittedBy !== reviewer._id` checked in both middleware and service layer.

### P5 — Audit Immutability

No review decision, status change, or moderation action may be silently deleted or overwritten. Every change is:
- Recorded in `auditLogs` collection before the change takes effect
- Attributed to an actor with a timestamp
- Accessible to `MODERATOR` and `ADMIN` roles via audit query API
- Preserved indefinitely (archival, not deletion)

### P6 — No Illegal Labeling Without Sufficient Evidence

A claim, person, institution, or action must not be labeled as **illegal**, **criminal**, or **fraudulent** based on:
- Unverified community reports
- Single-source allegations
- Personal opinions or testimonies alone

Such claims must carry status `DISPUTED_CLAIM` or `UNVERIFIED` until reviewed by a `REVIEWER` with documentary evidence (court orders, government records, official notifications).

### P7 — Privacy Protection

- No claim may be published that identifies a private individual by full name + identifiable location + sensitive personal details without their documented consent.
- Identity document details (ID numbers, biometric data) are **never stored, displayed, or logged** in any human-readable form.
- Only hashed references to identity verification events are stored.

---

## 2. Claim Status Decision Matrix

| Evidence Level | Category | Appropriate Status |
|---|---|---|
| Strong archival evidence, multiple independent sources | `HISTORICAL_RECORD` | `verified` |
| Good evidence, minor gaps | Any | `partially_verified` |
| Oral tradition, no archival backup | `FOLKLORE` | `unverified` (correct category preserved) |
| Conflicting evidence from reliable sources | Any | `disputed` |
| Only personal testimony, no corroboration | `PERSONAL_EXPERIENCE` | `unverified` |
| No evidence submitted | Any | `insufficient_evidence` |
| Violates content policy / demonstrably false | Any | `rejected` |
| Folklore submitted as Historical Record | — | Recategorize to `FOLKLORE` + `insufficient_evidence` |

---

## 3. Reviewer Obligations

Every reviewer must:

1. **Record sources examined** — list all `evidenceId` items reviewed
2. **Write a justification** — minimum 50 characters explaining the decision
3. **Be different from the submitter** — enforced technically
4. **Not cite votes/popularity** — system will flag reviews that reference community consensus as sole justification
5. **Distinguish category from status** — a verified `FOLKLORE` entry means "this is a confirmed known piece of folklore," not "this historical claim is verified"
6. **Document counter-evidence** — if contradicting evidence exists, link it; do not ignore it

### 3.1 Evidence Review on Archived Claims (Option B: Independent Evidence Provenance)

- **Independent Evidence Evaluation:** Authorized reviewers (`REVIEWER` role or higher) may review or update the verification decision on an existing Evidence record even if its parent Claim is `archived`. This preserves evidence provenance and scholarly accuracy for historical research.
- **Claim Status Invariance:** Reviewing an Evidence record attached to an archived Claim MUST NOT change the parent Claim's status, reactivate the Claim, or mark it verified. The Claim remains strictly `archived`.
- **Governing Constraints Preserved:** All existing reviewer authorization checks, self-review prohibitions (uploader cannot review their own evidence), review-note length validation (minimum 10 characters), immutable audit logging (`evidence.reviewed`), and atomic transaction guarantees remain fully in force.
- **New Submissions Blocked:** Archiving a Claim continues strictly to block all **new Evidence submissions** (enforced with `422 BUSINESS_RULE_VIOLATION`). Archiving retires the Claim from accepting new contributions; only previously attached Evidence records may have their review evaluation recorded. No other mutations to archived Claims are permitted.

---

## 4. Appeal Policy

| Condition | Appeal Allowed? |
|-----------|----------------|
| `rejected` decision | Yes, once |
| `insufficient_evidence` decision | Yes, with new evidence only |
| `verified` decision | No direct appeal; open correction via moderator |
| `disputed` decision | No; dispute is a status, not a decision |

Appeal requirements:
- Must state specific grounds for appeal
- Must reference the specific review decision being appealed
- Appeal is assigned to a **different reviewer** than the original
- Appeal decision is final for `CONTRIBUTOR` role; `MODERATOR` may re-open

---

## 5. Content Policy Violations

Claims must be `rejected` (with reason) if they:
- Contain incitement to violence or hate speech
- Expose private individuals' PII without consent
- Make unsubstantiated criminal allegations against named individuals
- Constitute defamation (factual claim known to be false, damaging to reputation)
- Are exact duplicates of existing claims

---

## 6. Moderation and Correction Workflow

```
Any actor notices error in verified claim
  → Correction request submitted (with reason + evidence)
  → Assigned to MODERATOR
  → MODERATOR reviews correction evidence
  → If valid: status updated to "under_review" + original review preserved in audit
  → New review conducted by different reviewer
  → Decision recorded; correction event added to audit trail
```

**Silent correction is prohibited.** Every correction must:
1. Reference the prior verified/approved review
2. Create a new `auditLog` entry
3. Notify the original submitter (if not anonymous)

---

## 7. Technical Enforcement Summary

| Rule | Enforced At |
|------|-------------|
| Self-approval block | Auth middleware + Service layer |
| Audit log on every status change | Service layer (pre-write hook) |
| Evidence required for status promotion | Service layer validation |
| Reviewer justification minimum length | Zod validation schema |
| Folklore → Historical requires reviewer + evidence | Service layer business rule |
| No PII in public API responses | DTO transform layer |
| No secrets in source | CI lint rule + `.gitignore` |
| Appeal to different reviewer | Service layer assignment logic |
