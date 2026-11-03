# Task Checklist

**Status values:** todo · in-progress · done (evidence) · blocked (reason)
Task details, acceptance criteria and tests: [PLANNING_REPORT.md §3](PLANNING_REPORT.md#3-first-milestone--m1-secure-reproducible-foundation).
Working branch: `feature/m1-foundation` (local; fast-forwarded on 2026-11-02 to partner's `origin/main` @ `2910d88`; M1 changes uncommitted on top; nothing committed or pushed).

**2026-11-02 sync check:** after integrating the partner's notifications/weather commits — backend build 0 errors; **32/32 tests pass** (27 M1 + 5 wiring/notification tests); migration re-validated on disposable DBs (partner script + alignment == EF migration, 134/134; idempotent; EF "up to date"); read-only runtime checks of posts, notifications and weather endpoints pass. `DevLink` database unchanged.

## Phase 0 — done so far

| ID | Task | Status | Evidence |
|---|---|---|---|
| T-0.2 | Repository inspection & current-state reclassification | done | `DevLink_Product_Spec/.../CURRENT_STATE_INSPECTION.md` |
| — | Local environment: .NET 9 SDK, SQL Server 2022 container `devlink-sql`, schema loaded, local `backend/appsettings.json` (gitignored) | done (local only) | Read-only GETs return 200/404 as designed |
| — | Planning report + tracking files | done | `docs/PLANNING_REPORT.md`, this file |

## M1 — Secure, reproducible foundation

| ID | Task | Depends on | Status | Evidence (2026-10-28) |
|---|---|---|---|---|
| M1-01 | Revoke Gmail app password (partner) | D4 | **blocked (awaiting partner)** | Credential removed from code (M1-05) but still in public Git history — revocation is the only real fix |
| M1-02 | Work on partner's latest code | D5 | done (local) | Branch `feature/m1-foundation` from `origin/main` (partner's 7 commits, 23–27 Oct); commit/push not requested |
| M1-03 | Back up any DB holding data | — | done (n/a locally) | Local `DevLink`: all 10 tables have 0 rows. Partner's DB: unknown → back up before running baseline scripts there |
| M1-04 | Schema alignment + EF baseline | D6 | **done; applied to local `DevLink` on 2026-11-03** (owner-approved; COPY_ONLY backup `C:\Users\dell\DevLink-backups\devlink-db-2026-11-03\`, restore-verified + CHECKDB; afterwards catalog == EF migration 134/134, EF lists `InitialCreate` as applied). Partner's DB: not touched | EF model aligned (`Notifications`, lengths, precision, CHECKs, constraint/index names); migration `20261028125753_InitialCreate`; `database/align_schema_for_ef_baseline.sql` + `database/baseline_ef_history.sql`. Validation: partner script + alignment (run twice, idempotent) catalog **== EF migration catalog (134/134 lines)**; EF reports baselined DB up to date; `has-pending-model-changes` = none. Applying to `DevLink` awaits D6 approval |
| M1-05 | Secrets → configuration; dev email sink | — | done | `EmailService` reads `Smtp` options (user-secrets); hard-coded sender/password removed; no SMTP config → Development logs email to console, other envs fail safely; verification-code console logging removed; `UserSecretsId` added; `git grep` finds no credential |
| M1-06 | Test harness | — | done | `tests/DevLink.Api.Tests` (xUnit + WebApplicationFactory); disposable container `devlink-sql-test` (127.0.0.1:14333, no volume); per-class `DevLinkTest_<guid>` DB built via EF migrations and dropped; guards refuse non-prefixed DBs and port 1433. **27/27 passing** |
| M1-07 | Password hashing + legacy rehash | P1 | done | `PasswordService` (Identity PBKDF2); signup, reset, Google sign-up, admin create/update hash; login verifies hash or legacy plaintext (constant-time) and rehashes on success; min length configurable `Auth:MinPasswordLength` (default 6 = current UI). Tests: `PasswordHashingTests`, `PasswordServiceTests` |
| M1-08 | Admin provisioning | — | done | `dotnet run -- seed-admin` (env vars, idempotent, refuses non-admin takeover); API returns 403 for creating/promoting/changing/deleting admins. Tests: `AdminProvisioningTests`. **Not run against `DevLink`** (needs owner authorisation) |
| M1-09 | Global ProblemDetails handler | — | done | `AddProblemDetails` + `UseExceptionHandler` (non-Development); test asserts `application/problem+json`, `traceId`, no stack/SQL text |
| M1-10 | README setup update | — | done | README rewritten: .NET 9, Docker SQL, `127.0.0.1` note, template location, user-secrets, seed-admin, Flutter 3.47.x, tests |
| M1-11 | CI skeleton (stretch) | — | todo | |
| M1-12 | Ignore test build output (contains copied appsettings.json) | — | done | `.gitignore`: `tests/**/bin/`, `tests/**/obj/`, `tests/**/appsettings*.json`, `TestResults/` |
| M1-CP | **M1 checkpoint commit (local, not pushed)** | owner approval 2026-11-03 | **done** | Commit **`9b8e7aa`** on `feature/m1-foundation` (parent `2910d88`): 34 files, +4794/−96, includes `docs/` (D14); `DevLink_Product_Spec/` excluded (D15, separate commit later). Masked secret scan of the staged content: no secret values, leaked Gmail value absent. After the commit: `dotnet build` 0 errors, `dotnet test` 32/32. Stash `m1-foundation-wip-2026-11-02` kept. Not pushed |

## M2 — Authentication & authorisation

Design: [M2_AUTH_DESIGN.md](M2_AUTH_DESIGN.md) revision 3, **approved 2026-11-03** (with sequencing fixes 1–2, R1–R3; JwtBearer package approved for M2.2). Files, DB changes and tests per task: design §11. The old IDs M2-01…M2-07 are superseded (mapping in the last column).

**Execution order (fix 1):** M2.1 → M2.2 → M2.3 → **M2.6** → M2.4a → M2.4b → M2.5 → M2.7 → M2.8 → M2.9 → M2.10 → M2.11 → M2.12 → M2.13 → M2.14.

| ID | Task | Gate | Status | Replaces |
|---|---|---|---|---|
| M2.1 | Record approvals; update docs | — | **done 2026-11-03** (docs only) | — |
| M2.2 | Foundation: keys, `TokenService`, JwtBearer, CORS allowlist, headers, log guard, topology guard, migration switch + safeguards | Owner go-ahead given 2026-11-03 | **done — awaiting commit approval** (2026-11-03): JwtBearer **9.0.22** (C8 override, only package change); 64-byte signing key in user-secrets (`Jwt:SigningKeys:0:Key`, never displayed); `dotnet build` 0 errors; **100/100 tests** (32 existing + 68 new: T-JWT-01…07, T-SW-01…05, T-CS-06/07, T-SC-06, T-LOG-01, headers); runtime: Swagger + 4 existing GETs unchanged, web app on :5200 shows Welcome with no CORS errors. No endpoint behaviour change. Deferred by design: `Security:CodeHmacKey` → M2.5, `Security:MediaUrlKey` → M2.8 | M2-01 (part), M2-06 (part) |
| M2.3 | Migration `AddAuthSecurity` on disposable DBs only | — | **done — awaiting commit approval** (2026-11-04): migration `20261103225031_AddAuthSecurity` (4 tables, 8 `Users` columns, `PostApplications.ContactShareConsentAt`; all FKs NO ACTION); `has-pending-model-changes`: none; throwaway validation on `devlink-sql-test`: (1) fresh DB from all migrations, idempotent re-run no-op; (2) restored 2026-11-03 backup + legacy rows → M1 scripts → migration: 6/6 distinct 32-hex SecurityStamps, row counts and data fingerprints unchanged, 8/8 constraint checks pass; (3) Down → InitialCreate (catalog identical to pre-migration) → Up (identical to fresh). All throwaway DBs dropped. `dotnet test` **106/106**. `DevLink` untouched; running API still M2.2 | — |
| M2.6 | Apply migration to local `DevLink` (backup + restore check) — **right after M2.3** | Owner approval 2026-11-04 | **done** (2026-11-04, `devlink-sql` only): pre-check history = InitialCreate only, all 10 app tables 0 rows; API stopped; COPY_ONLY backup `C:\Users\dell\DevLink-backups\devlink-db-2026-11-04\DevLink_pre_M2_6.bak` (3,723,264 bytes, sha256 `2520f587308371fae12a20bbd604924da21cebc60f3dccbb12c91d96598b0d52`, VERIFYONLY valid; restored copy on `devlink-sql-test` identical in rows/fingerprints/catalog, rehearsed: run without `-I` fails and leaves the DB unchanged, run with `-I` succeeds; copy dropped); applied the reviewed `addauthsecurity_up_idempotent.sql` (sha256 `DBBBA26A…596ED`, identical to a regeneration from HEAD) with `sqlcmd -I` → exit 0. Verified: history = InitialCreate + AddAuthSecurity; `has-pending-model-changes` none; catalog identical to the rehearsal (256 lines) and equal to a migrations-only DB except the 19 KI-38 defaults; row counts unchanged (0 users, so no stamps yet; per-row default in place). Debug rebuild, API restarted on :5133: Swagger 200, `Posts/feed`, `ProgrammerProfile/all`, `Admin/statistics`, `Notifications/1` unchanged; web app Welcome screen, no CORS errors. `dotnet test` 105/106 — **T_SW_03 flaky** (KI-40, test-only race, not a migration effect); fixed in `10760b7` → 106/106 (20 consecutive full runs) | — |
| M2.4a | Password login creates an `AuthSession` + 15-min access token, `LastLoginAt`; lockout (5 consecutive failures → 15 min, `FailedLoginCount`/`LockoutEndAt`; same in-memory rule for unknown emails); generic, timing-equalized failures; suspended restricted mode (`[AllowSuspended]` gate); per-request session check (C2: user, `SecurityStamp`, active session, status; 30 s cache, 503 when unavailable); `SecurityEvents` for login success/failure/lockout (IP prefix only on failures/lockouts); `GET /api/Auth/me`; Swagger Bearer button | Owner approval 2026-11-04 (split of M2.4) | **done — awaiting commit approval** (2026-11-04): 126/126 tests (10 consecutive full runs); login response shape unchanged (T-LG-BC, green before and after); runtime on `DevLink` with one synthetic customer registered through the normal flow: login → old fields + token, `/api/Auth/me` 200, wrong password = unknown email (401, ~310 ms both), lockout 429 + Retry-After 900; unchanged Flutter app signs in and reaches the Customer home screen | M2-01 (part) |
| M2.4b | Refresh tokens: cookie (`devlink_rt`) + body token (mobile), strict rotation, reuse detection + session-family revocation, `[CookieSessionGuard]` (CSRF), `session/refresh`, `session/logout`, `logout-all`, cleanup service (incl. R3 14-day IP-prefix nulling, KI-42) | — | todo | M2-01 (part) |
| M2.5 | Codes in DB, proof tokens, limits, lockout, P1, suspension (restricted), audit log, reuse alert | — | todo | M2-06 (part) |
| M2.7 | Authorization: policies, ownership, projections, `[AllowSuspended]`, support rules | `git ls-remote` check (partner files) | todo | M2-03, M2-04, M2-05 (KI-27) |
| M2.8 | Download links, signed image URLs | `git ls-remote` check | todo | M2-05 (part) |
| M2.9 | Google: subject matching, `google-link`, admin excluded | — | todo | — |
| M2.10 | Notification retention (N1) + paging | Partner informed; `git ls-remote` check | todo | — |
| M2.11 | Full backend security + regression suite | — | todo | M2-07 |
| M2.12 | Flutter integration (F1–F18) | **Partner review** | todo (Flutter 3.47.9 ready) | M2-02 |
| M2.13 | Remove the migration switch and fallbacks | — | todo | — |
| M2.14 | E2E per role, two-tab check | Admin email for `seed-admin` | todo | — |

## Stage 4 — MVP slice (after M2)
Structured project fields in posts → moderation with visible feedback → programmer access/apply → accept → delivery against criteria → reviews. **Not started**: protected write workflows require M2 first.
