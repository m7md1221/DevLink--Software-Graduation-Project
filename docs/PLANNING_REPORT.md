# DevLink — Planning Report (pre-implementation)

**Date:** 26 Oct 2026 · **Status:** PROPOSAL — nothing here is approved or implemented yet.
**Inputs:** `DevLink_Product_Spec/DevLink_Product_Spec/*.md` (spec v1.0) and `CURRENT_STATE_INSPECTION.md` (25 Oct). Repository `main` @ `38fff54`, tracked files unchanged.
**Tracking files:** [decision-log.md](decision-log.md) · [task-checklist.md](task-checklist.md) · [known-issues.md](known-issues.md)

**Constraint applied throughout:** the social feed (posts, images, likes, comments) is **preserved unchanged** until you and your partner agree otherwise.

---

## 1. Open decisions (15)

**Approver key:** **You** = project owner · **Partner** = co-developer · **Supervisor** = academic supervisor. "You + Partner" means both must agree.

| # | Decision | Recommended default | Alternatives | Trade-offs | Approver |
|---|---|---|---|---|---|
| D1 | **Social feed** (spec D-05 says hide it) | **Keep the feed exactly as it is.** Projects become *enriched posts* (title, budget, deadline, criteria) shown in the same feed; likes/comments untouched. Revisit after the MVP demo. | (b) Separate "Community" tab + separate Projects list · (c) Hide feed (spec default) | (a) Zero conflict with partner's recent work, least rework; mixes social and job content. (b) Cleaner product, ~2× UI work. (c) Cleanest, but discards partner's newest work and needs consent. | **You + Partner** (Supervisor if the feed is in the original proposal) |
| D2 | **Supervisor constraints**: deadline, team capacity, mandatory features (Arabic/RTL, messaging, reviews, deployment, Android) | Assume **Web demo, English UI, ~8–10 weeks, 2 developers** until confirmed | Whatever the supervisor specifies | Every scope cut depends on this; without it the MVP can't be sized | **Supervisor** (input), You record it |
| D3 | **Reduced MVP** (§2) | Approve §2 as the graduation scope | Full spec MVP (~212 pts ≈ 14 dev-weeks) · an even smaller "security + core loop" MVP | Reduced MVP is demonstrable in time but omits messaging/reports/i18n | **You + Partner** (Supervisor informed) |
| D4 | **Exposed Gmail credential** (repo is **public**) | Partner **revokes the app password today**; replace with a project-owned mailbox or transactional provider stored in user-secrets; **no history rewrite** | Rewrite Git history (BFG/filter-repo + force-push) · keep the account and only change the password | Revocation is what actually stops misuse; history rewrite is destructive, breaks clones, and cannot un-publish forks/caches | **Partner** (owns the account) + **You** (history decision) |
| D5 | **Partner's unpushed work** (e.g. `Notifications` table exists in DB but not in code) | Partner pushes everything to a branch **before** M1 starts; we merge first | Proceed in parallel and resolve conflicts later | M1 touches `AppDbContext` and auth code that partner may also be editing → merge conflicts | **Partner** |
| D6 | **Schema strategy** | **EF Core migrations become the single source of truth.** Path chosen by data value: if no partner DB holds valuable data → *fresh baseline* (create DB from `InitialCreate`); otherwise → *alignment script + baseline* (see §5) | Stay script-first (SSMS scripts, no migrations) | Migrations give repeatable, reviewable changes and test DBs; script-first is simpler now but every later change (auth columns, projects) multiplies drift | **You + Partner** |
| D7 | **Post → Project data mapping** (only if real data exists) | `Pending→PendingReview`, `Approved & !IsClosed→Open`, `Approved & IsClosed→Closed`, `Rejected→ChangesRequested` (keep reason), `IsDeleted` kept; image-only posts get title "Untitled project" and stay as social posts | Map `Rejected→Removed`; drop legacy posts | Matters only if partner's DB has data worth keeping | **You + Partner** |
| D8 | **Programmer profile fields** (Specialty, University, LinkedInUrl, Phone) | **Keep all existing fields**; add new spec fields additively later (Specialty→Headline seed, University→Education) | Replace with spec fields now | Additive changes avoid breaking partner's screens | **Partner + You** |
| D9 | **Who may create projects** | **Customers only** for structured projects; leave social posting rules unchanged until D1 is revisited | Programmers too (current backend allows it) | Customers-only matches marketplace semantics and spec D-04 | **You + Partner** |
| D10 | **Token storage on web** (spec D-17: httpOnly refresh cookie) | Graduation default: **short-lived access token in memory + rotating refresh token**; web keeps refresh token in browser storage behind a Development flag; switch to httpOnly cookie when API and web are served from one origin for the demo | Cookie from day one (needs a same-origin dev proxy) · long-lived token only | Cookie is safest vs XSS but complicates local dev (different ports); storage-based is simple but XSS-exposed | **You** (technical), Partner informed |
| D11 | **API route style** (spec: `/api/v1/...`) | **Keep current `/api/{Controller}/…` routes**; secure them in place; new endpoints follow the same style | Move everything to `/api/v1` resource routes | Renaming breaks every Flutter call at once for no grading benefit | **You + Partner** |
| D12 | **Flutter foundations** (spec: go_router, dio, l10n, feature folders) | **Keep `Navigator` + `package:http`**; add one auth-aware HTTP helper (token header, 401 handling) and a role guard; add l10n only if D2 requires Arabic | Adopt go_router + dio now | Rewrite of ~26k lines' navigation vs. small additive wrapper | **Partner + You** |
| D13 | **File storage** | **Keep blobs in SQL for the MVP**, served only through authorised endpoints with magic-byte checks and safe headers | Move to disk/object storage + `StoredFiles` table (spec M-08) | DB blobs are simple and already work; storage migration is L-sized and not visible in a demo | **You + Partner** |
| D14 | **Planning/tracking docs location** | `docs/` (created now: this report + 3 tracking files) | Keep inside `DevLink_Product_Spec/progress/` | `docs/` matches doc 11 §1 | **You** |
| D15 | **Commit the spec package** (currently untracked, nested `DevLink_Product_Spec/DevLink_Product_Spec/`) | Flatten to `DevLink_Product_Spec/` and commit on a `docs/spec-v1` branch via PR, with `docs/` | Keep it local only | Shared, reviewable source of truth for both partners | **You + Partner** |

**Minor parameters to confirm with M1 (defaults in brackets):** server-side minimum password length for new/changed passwords [8 now, 10 later per spec]; first-admin email via environment variable [yes]; dev email sink logs subject + recipient only, never codes in production [yes].

---

## 2. Reduced graduation MVP

**Principle:** prove one secure, end-to-end marketplace loop and the flagship idea (acceptance criteria travel from project → delivery → review), reusing existing screens and tables, **without touching the social feed's behaviour**.

### 2.1 Included

| # | Capability | Reuses | Why it's in |
|---|---|---|---|
| 1 | **Security baseline**: secrets in config, hashed passwords, JWT, role + ownership checks on every endpoint, seeded admin, auth rate limits, ProblemDetails, CORS allowlist | all controllers | Critical findings; graders and any demo audience can trivially exploit the current API |
| 2 | **Structured projects inside the feed**: title, description, budget (amount or range + currency), deadline, category, skills (small seeded list), **acceptance-criteria list**; required-field check before submit | `create_post_page.dart`, `Posts`, `PostImages`, feed | Core marketplace data + flagship, no new listing UI needed |
| 3 | **Moderation with visible feedback**: approve / request changes (reason shown to owner) / remove; **My Projects** with status | `admin_posts_page.dart`, `RejectionReason` | Owners currently can't see rejected/pending posts |
| 4 | **Programmer access to projects**: programmers reach the existing feed, search/filter projects, open project detail | `customer_home_page.dart`, `post_card.dart` | Today the apply flow is unreachable |
| 5 | **Applications**: apply (amount, duration in days, approach), **My Applications**, withdraw; customer applicant list, reject, **accept** | `apply_to_post_page.dart`, `post_applications_page.dart`, `PostApplications` | Completes the core loop |
| 6 | **Minimal engagement**: on accept, snapshot the agreed criteria; one milestone = whole project; programmer submits delivery ticking each criterion; customer accepts or requests revision (max 2); completion | new (small) | The flagship demo moment |
| 7 | **Simple reviews** after completion; real rating replaces the always-0 `Rating` | `ProgrammerProfiles.Rating` | Trust; removes a fake number |
| 8 | **Profile editing** for both roles; CV/certificate visible only to owner, admins, and customers who received an application | existing PUT endpoints | Existing backend unused; privacy fix |
| 9 | **In-app notifications** for ~6 key events using the existing `Notifications` table (polling) | partner's table | Users must learn about approvals/acceptance |
| 10 | **Admin**: real statistics, suspend/deactivate (soft delete), existing verification and support — now authorised | existing admin pages | Replaces mock stats; fixes FK-blocked deletion |

### 2.2 Deferred (and why)

| Deferred | Why |
|---|---|
| Hiding/redesigning the social feed | Needs partner agreement (D1) |
| Messaging threads | L-sized; contact after acceptance can be shown in the engagement instead (decide via D2) |
| Arabic/RTL and full l10n | ~26k lines of hard-coded English; only if supervisor requires (D2) |
| Brief templates, readiness score, comparison view, shortlist, application edit | Enhancements of the flagship, not needed to demonstrate it |
| Multi-milestone builder, scope acknowledgement, cancellation workflow, auto-accept, scope changes | Engagement complexity; admin-cancel covers the demo |
| Double-blind review publishing, review moderation | Simple reviews suffice for the demo |
| Evidence levels L0–L3, link checker (SSRF work) | High effort, low demo value |
| Reports queue, audit-log viewer, email outbox/retries, notification preferences | Operational features; keep basic audit rows only if time permits |
| `/api/v1` re-routing, go_router/dio migration, file-storage migration | Churn without user-visible value (D11–D13) |
| Payments, AI features | Out of scope per spec |

**Demo journeys covered:** register/login → customer posts structured project → admin requests changes → owner fixes and resubmits → admin approves → programmer finds and applies → customer accepts → programmer submits delivery against criteria → customer requests revision → accepts → both review.

---

## 3. First milestone — M1 "Secure, reproducible foundation"

**Goal:** both partners can recreate the environment from the README; no secret in code; passwords hashed; first admin seeded; consistent errors; test harness in place. **No new features and no change to feed/UI behaviour.** JWT + authorisation is **M2**, because it changes every Flutter call and must be coordinated with your partner.

| ID | Task | P | Size | Depends on | Areas | Acceptance criteria | Tests |
|---|---|---|---|---|---|---|---|
| M1-01 | Partner revokes Gmail app password; record date (no value) | P0 | S | D4 | Ops | Old credential rejected by Gmail; noted in decision log | manual confirmation |
| M1-02 | Merge partner's pending work; create `chore/m1-foundation` branch; commit spec + `docs/` | P0 | S | D5, D14, D15 | Git | `main` contains partner's latest code; branch created; no force-push | `git log` review |
| M1-03 | Back up any partner DB with data (outside repo) | P0 | S | M1-02 | DB | `.bak` stored off-repo; restore tested on a copy | restore smoke |
| M1-04 | **Schema alignment + EF baseline** (§5): model `Notifications`, align lengths/precision, deterministic constraint names, CHECKs; `InitialCreate` | P0 | M | D6, M1-03 | Backend `DataBase/`, DB | `has-pending-model-changes` = false; migration applies to empty container DB; live DB baselined without data loss | `SchemaBaselineTests` |
| M1-05 | **Secrets → configuration**: `SmtpOptions`, `GoogleOptions`; user-secrets for dev; dev email sink; fail fast in Production if missing; delete hard-coded values | P0 | S | M1-01 | `EmailService`, `Program.cs` | `git grep` finds no mailbox/app-password; app runs with user-secrets | `EmailSenderTests` (sink, no network) |
| M1-06 | **Test harness**: xUnit + `WebApplicationFactory` + disposable SQL Server container DB; characterization tests of current auth endpoints | P0 | M | M1-04 | new `tests/` project | `dotnet test` green; never touches dev DB | 5+ characterization tests |
| M1-07 | **Password hashing**: `PasswordHasher<User>` in signup, reset, admin create/update; verify + **rehash legacy plaintext on successful login**; server-side min length | P0 | M | M1-06 | `AuthController`, `AdminService` | No plaintext stored after any write path; legacy account logs in once then is hashed | `PasswordHashingTests`, `PasswordPolicyTests` |
| M1-08 | **Admin seed command** from env vars (`DEVLINK_ADMIN_EMAIL/PASSWORD`), idempotent | P0 | S | M1-07 | `Program.cs` | Fresh DB has no admin until seeded; seeding twice creates one | `AdminSeedTests` |
| M1-09 | **Global exception handler → ProblemDetails** with `traceId`; no stack traces outside Development | P1 | S | — | `Program.cs` | Forced exception returns sanitized 500 | `ProblemDetailsTests` |
| M1-10 | **README setup**: Docker SQL, `127.0.0.1,1433`, user-secrets, Flutter ≥3.44, Developer Mode, migrations, admin seed | P1 | S | M1-04..08 | docs | Partner sets up from README in ≤ 30 min | timed walkthrough |
| M1-11 *(stretch)* | CI: build, test, `flutter analyze`, secret scan | P2 | S | M1-06 | `.github/workflows` | PR shows green checks | CI run |

**M1 exit criteria:** M1-01…M1-10 done; `dotnet build` 0 errors; `dotnet test` green; `flutter analyze` 0 errors; existing widget test passes; manual smoke on a disposable DB (signup → profile → post → admin approve → feed shows post) unchanged.

---

## 4. Safest order of security/data work

| Step | Action | Why this position |
|---|---|---|
| 1 | **Revoke the Gmail app password** (partner) | Public exposure is ongoing; no code needed; nothing depends on it |
| 2 | **Sync with partner** (push/merge pending work, agree branches) | Every later step edits shared files (`AppDbContext`, controllers) |
| 3 | **Back up any DB holding data** | Before schema or password changes touch rows |
| 4 | **Schema alignment + EF baseline** | Later steps (auth columns, tests, projects) need a reproducible schema; constraint-name drift makes future migrations fail |
| 5 | **Move secrets to configuration** | Code must stop carrying credentials before new secrets (JWT key) are introduced |
| 6 | **Automated test harness** | Hashing and auth change behaviour; tests prove nothing else broke |
| 7 | **Password hashing (+ legacy rehash)** | Must precede tokens: issuing JWTs on plaintext storage is pointless |
| 8 | **Admin provisioning (seed)** | Needed before admin endpoints are locked, so an admin can still log in |
| 9 | **ProblemDetails** | Gives consistent 401/403/400 shapes before auth starts returning them |
| 10 | **Authentication (JWT)** + Flutter token handling — *M2* | Needs 5, 7, 8; coordinated client/server change |
| 11 | **Authorisation** (roles, ownership; remove self-verify; lock admin creation; protect CV/support) + matrix tests — *M2* | Needs identity from tokens |
| 12 | **Rate limits, CORS allowlist, security headers** — *M2* | Cheap once auth exists; CORS matters once tokens are sent |

---

## 5. SQL Server schema vs EF Core model — exact differences

**Evidence:** live catalog of the `DevLink` database (`sys.columns`, `sys.indexes`, `sys.foreign_keys`, `sys.check_constraints`, read-only) vs DDL generated by `dotnet ef dbcontext script` (EF 9.0.0, tool installed only in a scratch folder; no DB connection used).
**Already identical:** all column types/nullability except those listed in 5.1; all FK delete behaviours (CASCADE / NO ACTION / SET NULL); `PostApplications.Price` is `decimal(18,2)` on both sides.

### 5.1 Tables and columns

| # | Object | SQL Server (actual) | EF model | Resolution before migrations |
|---|---|---|---|---|
| S1 | `Notifications` table (8 columns, FK cascade, 3 indexes) | exists | **absent** | Add `Notification` entity mapped exactly (or exclude it explicitly) — otherwise a baseline migration would try to create it or a later diff would ignore it |
| S2 | `Users.Email` | `nvarchar(256)` | `nvarchar(450)` | `HasMaxLength(256)` |
| S3 | `Users.UserType` | `nvarchar(50)` | `nvarchar(max)` | `HasMaxLength(50)` |
| S4 | `Posts.Status` | `nvarchar(20)` | `nvarchar(max)` | `HasMaxLength(20)` |
| S5 | `PostApplications.Price` | `decimal(18,2)` | `decimal(18,2)` by default, **warning** | `HasPrecision(18,2)` (removes runtime warning) |
| S6 | Column order | `CustomerProfiles.Country` is last | after Nickname | Irrelevant (no action) |

### 5.2 Defaults

| # | Column(s) | SQL default | EF | Resolution |
|---|---|---|---|---|
| S7 | `Posts.Status` | `'Approved'` | none (C# initializer `"Pending"`) | **Decide**: drop the DB default (recommended) or model `HasDefaultValue("Pending")`. A DB default of Approved lets direct inserts bypass moderation |
| S8 | `CreatedAt` on CustomerProfiles, ProgrammerProfiles, Posts, PostImages, PostLikes, PostComments, PostApplications, SupportMessages, Notifications | `getutcdate()` | none | Model with `HasDefaultValueSql("getutcdate()")` or accept as DB-only (EF always sends a value) |
| S9 | `IsDeleted`, `IsClosed`, `IsVerified`, `Rating`, `SortOrder`, `IsRead` | `0` | none | Same choice as S8 |
| S10 | `PostApplications.Status` `'Pending'`, `SupportMessages.Status` `'New'` | defaults | none | Same choice as S8 |
| S11 | `CustomerProfiles.Country` | `''` | none | Same choice as S8 (likely a leftover from adding the column) |

### 5.3 Keys, indexes and constraint names

| # | Object | SQL Server | EF expects | Resolution |
|---|---|---|---|---|
| S12 | PK names on `Users`, `CustomerProfiles`, `ProgrammerProfiles` | **system-generated** (`PK__Users__3214EC07…`; different on every machine) | `PK_Users`, `PK_CustomerProfiles`, `PK_ProgrammerProfiles` | Rename to deterministic names on every DB (alignment script) — EF cannot map random names |
| S13 | All 12 FK names | `FK_{Child}_{Parent}` (e.g. `FK_Posts_Users`) | `FK_{Child}_{Parent}_{Column}` (e.g. `FK_Posts_Users_UserId`) | Rename in DB **or** `HasConstraintName(...)` in EF |
| S14 | `Users.Email` uniqueness | **UNIQUE constraint**, system-generated name | unique **index** `IX_Users_Email` | Replace constraint with index (or map) |
| S15 | Profile `UserId` uniqueness (both profile tables) | **two** objects: UNIQUE constraint (system name) **and** unique index `IX_*_UserId` | one unique index | Drop the redundant UNIQUE constraint |
| S16 | `PostApplications (PostId, ProgrammerId)` | UNIQUE constraint `UQ_PostApplications_Post_Programmer` | unique index `IX_PostApplications_PostId_ProgrammerId` | Rename/convert or `HasDatabaseName` |
| S17 | `PostLikes (PostId, UserId)` | UNIQUE constraint `UQ_PostLikes_Post_User` | unique index `IX_PostLikes_PostId_UserId` | Same as S16 |
| S18 | `Posts.CreatedAt` index | `IX_Posts_CreatedAt` **DESC** | ascending | Model `IsDescending()` or accept |
| S19 | DB-only indexes | `IX_PostApplications_Status`, `IX_PostLikes_PostId`, `IX_SupportMessages_Created` (DESC), 3 on `Notifications` | not modelled | Model them (keep) or drop `IX_PostLikes_PostId` (covered by the unique index) |
| S20 | CHECK constraints | `CK_PostApplications_Status` (Pending/Accepted/Rejected), `CK_SupportMessages_Status` (New/Read/Replied/Closed) | not modelled | Model with `HasCheckConstraint` — **required** because the MVP's new application statuses (Withdrawn, Submitted…) must change this constraint in a migration |
| S21 | `__EFMigrationsHistory` | absent | — | Created by the baseline step |

### 5.4 Why this matters and the two safe paths

EF migrations drop and alter objects **by name**. With system-generated or differently named PKs/FKs/unique constraints, the first real migration (e.g. changing a delete rule or a status CHECK) would fail on one machine and behave differently on another.

| Path | When | Steps |
|---|---|---|
| **A — Fresh baseline** (recommended if no DB holds valuable data) | Your container DB is empty; confirm partner's | Fix S1–S5, S7, S20 in the EF model → generate `InitialCreate` → create new DBs from migrations on both machines → retire the SSMS script |
| **B — Alignment + baseline** (if partner's DB has data) | Partner has real/test data to keep | Backup → one reviewed, idempotent alignment script (rename S12–S17 to EF names, drop S15 duplicates, decide S7–S11) run on a copy, then on each DB → fix the EF model → `InitialCreate` → insert its row into `__EFMigrationsHistory` (no DDL executed) → `has-pending-model-changes` must report none |

---

## 6. Prerequisites checklist

### With your partner
- [ ] Gmail app password revoked; replacement mailbox/provider chosen (D4)
- [ ] All local work pushed; any branch with `Notifications` code identified (D5)
- [ ] Does any partner database contain data worth keeping? If yes, backup taken (D6/D7)
- [ ] Agreement on the social-feed approach for the MVP (D1) and who may post projects (D9)
- [ ] Agreement on reduced MVP (D3), profile fields (D8), file storage (D13), routes (D11), Flutter foundations (D12)
- [ ] Same Flutter version (≥ 3.44) on both machines; lockfile is never committed after an SDK downgrade
- [ ] Branch/PR workflow: feature branches, PR review by the other partner, no force-push on `main`
- [ ] Division of work for M1/M2 (e.g. you: backend security; partner: Flutter auth client in M2)
- [ ] Commit the spec package and `docs/` (D15)

### With your supervisor
- [ ] Deadline and expected team effort (D2)
- [ ] Mandatory features: Arabic/RTL, messaging, reviews, payments (expected absent), Android vs Web demo
- [ ] Acceptance of a marketplace **without payments** (spec D-03)
- [ ] Required documentation format (SRS/UML/test report) and whether the spec package can serve as it
- [ ] Whether a deployed (hosted) demo is required, and available hosting
- [ ] Whether usability tests with external participants are allowed/expected
- [ ] Whether the original proposal included the social feed (affects D1)

---

## 7. Approval order

1. **Today (no code):** D4 credential revocation (partner), D5 unpushed work (partner).
2. **Before M1 starts:** D6 schema strategy (+ answer "is there valuable data?"), D3 reduced MVP, D14/D15 docs, minor M1 parameters.
3. **Before M2:** D10, D11, D12, D9, D8.
4. **Before Phase 2 project work:** D1, D2 (supervisor), D7, D13.
