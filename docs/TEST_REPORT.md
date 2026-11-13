# DevLink API test report (M2.11, updated in M2.11b)

**Status:** audit of the backend tests against `docs/M2_AUTH_DESIGN.md` and `docs/M2_7_ENDPOINT_PLAN.md`, at commit `1e78c69` (M2.11) plus the M2.11b fixes and tests.
**Result of the last full runs (2026-11-11, M2.11b):** 3 consecutive runs, each 662 passed, 0 failed, 0 skipped (5 m 2 s, 5 m 20 s, 4 m 51 s). The M2.11 run before this: 645 passed in 4 m 37 s.

## Summary

- Every test ID in the two design documents was mapped to the tests that implement it. Of the 43 rows for the design's test section, 36 are implemented, 2 partly and 2 are missing because their feature isn't built yet; 3 are deferred to M2.12–M2.14, where they belong. All 5 test groups of the endpoint plan are implemented.
- The suite proves the M2 security rules at the HTTP level against a real SQL Server: who may call each route, that client-sent ids can't impersonate anyone, CSRF on cookie routes, refresh-token reuse detection, rate limits, signed image URLs and single-use download links.
- M2.11 added two small tests and found one product defect: a full email queue drops new mail while reporting it as queued (KI-67).
- M2.11b fixed KI-67 and added `POST /api/Auth/change-password`, which closes the T-PW-01 and T-PW-05…08 gaps and completes T-AU-04 (17 new test cases).
- The larger gaps are listed at the end. Each needs product code or a later milestone.

## How to run

Tests use a disposable SQL Server, never the `DevLink` database. Each test class creates a database named `DevLinkTest_<guid>` and drops it afterwards.

1. Start the test server once (README, section 7): the container `devlink-sql-test` on `127.0.0.1:14333`, with its password in `%USERPROFILE%\.devlink\sql-test.env`.
2. Stop a running API first if it was started from this checkout, because it locks the backend build output.
3. Run:

   ```powershell
   dotnet test tests/DevLink.Api.Tests
   ```

A full run takes 4–6 minutes on the development machine. At most 18 test databases exist at the same time (measured in M2.10). Each run adds about 150 MB to Docker's disk image; the owner decided not to limit parallelism for now.

## Tests per area

Counts are test cases as reported by the runner, so each row of a data-driven test counts once.

| Area | Test cases | Main classes |
|---|---|---|
| Authorization matrix (M2.7: admin, write, read and member routes, deny by default, suspended accounts) | 312 | `AdminRouteAuthorizationTests`, `WriteRouteAuthorizationTests`, `ReadRouteAuthorizationTests`, `MemberRouteAuthorizationTests`, `DenyByDefaultTests`, `SuspendedEverywhereTests` |
| Files and images (M2.8) | 75 | `DownloadLinkTests`, `SignedImageTests`, `UploadValidationTests`, `ImageFallbackTests` |
| CSRF, CORS, security headers, migration switch | 52 | `CsrfGuardTests`, `SecurityFoundationTests`, `AuthSwitchTests` |
| Tokens and start-up keys | 37 | `JwtValidationTests`, `JwtStartupValidationTests`, `CodeKeyStartupTests`, `MediaKeyStartupTests` |
| Refresh tokens, sessions, reuse, cleanup | 37 | `RefreshSessionTests`, `ConcurrentRefreshTests`, `SessionValidationTests`, `SessionCleanupTests`, `ReuseAlertTests`, `AuthSecuritySchemaTests` |
| Login, lockout, timing, response shape | 34 | `LoginTests`, `LoginLockoutTests`, `LoginTimingTests`, `LoginResponseShapeTests`, `PasswordHashingTests` |
| Google sign-in (M2.9) | 31 | `GoogleSignInTests`, `GoogleTokenValidatorTests` |
| One-time codes, password policy, change-password, rate limits, development fallback | 43 | `OneTimeCodeTests`, `PasswordPolicyTests`, `ChangePasswordTests`, `ChangePasswordRateLimitTests`, `RateLimitTests`, `DevFallbackTests` |
| Admin actions and provisioning | 21 | `AdminAccountActionsTests`, `AdminProvisioningTests` |
| Notifications (M2.10), email queue and wiring | 20 | `NotificationTests`, `WiringAndNotificationTests`, `EmailQueueAuditTests`, `EmailQueueFullTests` |
| **Total** | **662** | 35 test files |

## What the tests prove

**Authorization matrix.** Every route of the 79 is called by an anonymous caller, the rightful caller, another user, the wrong role and an admin, and must give the planned answer (T-7A…T-7D). A reflection test fails the build if any action lacks an explicit policy or `[AllowAnonymous]`. Another checks that the anonymous set is exactly the 8 sign-in routes plus the 3 routes with their own credential (T-7D-10).

**Spoofing.** Client-sent `userId`, `requesterId` and `isAdmin` values never change who acts: the action belongs to the token, and refused calls change nothing in the database (T-7B-10…13, T-7C-06, T-7D-06).

**CSRF and CORS.** Cookie-using routes refuse a missing or unlisted `Origin`, a missing client header, non-JSON bodies and cross-site fetch metadata; rejections are audited (T-CS-01…06). Tokens in cookies or the query string are ignored (T-CS-07). Only listed origins get CORS headers.

**Token theft and reuse.** Replaying a rotated refresh token revokes the whole session family, including newer tokens. Ten parallel refreshes with one token give exactly one success (T-RT-01…13, T-MT-06). Revoked sessions, changed security stamps and suspended accounts take effect on the next request, or within 30 seconds for changes made outside the API (T-SC-01…05).

**Rate limits and lockouts.** Login, code requests, code checks, sign-up, reset, change-password, Google sign-in and download links are limited, per IP, per email or per user (T-RL-01…04, T-CD-08…12, T-LG-06…08, T-DL-11, T-GG-14, T-PW-12). A wrong current password in change-password counts toward the same account lockout as a failed login (T-PW-09). Unknown emails behave like real ones, and failed logins take the same time whatever the reason (T-LG-03, T-LG-05, T-UL-01…04).

**File safety.** Uploads are checked by their first bytes, so SVG, HTML and mislabelled files are refused, and names are sanitised (T-UP-01…08). Images are served only through signed, expiring URLs or a token (T-IM-01…10). Documents use single-use, 60-second links bound to the session and browser, always as downloads with `no-store` (T-DL-01…11).

**Secrets stay out of logs.** Captured logs and security events are scanned for tokens, codes, passwords, cookies, signatures and emails (T-LOG-01, T-DL-10, T-IM-07b, T-GG-12, T-AU-02).

**Start-up refusals.** Missing, short or placeholder keys, unsafe switch settings, wildcard CORS and unsupported topologies stop the API at start-up (T-JWT-06, T-KEY-01/02, T-SW-01…05, T-SC-06).

## Flaky history

| Issue | What happened | Fix |
|---|---|---|
| KI-40 | `T_SW_03` failed in 5 of 15 isolated runs: the API stops itself on purpose, and the test read `factory.Services` after disposal, or the host was disposed while `CreateClient()` was finishing | Test only (`c10fed6`): a hosted-service probe records `ApplicationStopping`, and the test no longer touches the disposed host. No failures since. |
| KI-57 | `T_CS_06_invalid_origins_stop_startup` failed once in 6 full runs with "Cannot access a disposed object" instead of the validation message (same family as KI-40) | Test only (M2.7d): `HostOnlyApiFactory` treats that exception as the expected race and reads the reason from the host's start-up log. Covered by T-7D-30. No failures since. |
| Shared clock (M2.8, M2.9) | Test classes share one adjustable clock, so a test that moved it made later tokens look issued in the future | Tests reset the clock before each test (`MutableTimeProvider.Reset`). Caught before commit. |

Since M2.7d, each milestone's full suite passed 3 consecutive runs without a failure: M2.8 (602 tests), M2.9 (633) and M2.10 (642).

## Checks that are only done at runtime

Each milestone also ran scripted checks against the local `DevLink` database with synthetic accounts. These aren't part of `dotnet test`:

- The unchanged Flutter app on the logged development fallback: feed, avatars and post images, the notification bell.
- A real browser opening a download link in a new tab, which sends the `SameSite=Strict` cookie and saves the file (M2.8 spike).
- Google's real signing keys fetched over the internet (M2.9).
- Disk and test-database measurements (M2.10).
- change-password on `DevLink` after the `AddUserHasPassword` migration (M2.11b): the other session's old token gets 401, the current session keeps working, the new password signs in.
- `DBCC CHECKDB` and backup restore checks before schema changes or disk work.

## Mapping of design test IDs

Status: **Implemented**, **Partially** (some of the stated checks are missing), **Missing**, or **Deferred** (belongs to a later milestone by design).

### Design §10 (`M2_AUTH_DESIGN.md`)

| IDs | Status | Where | Notes |
|---|---|---|---|
| T-RT-01…05, 09…13 | Implemented | `RefreshSessionTests` | |
| T-RT-06, 07 | Implemented | `ConcurrentRefreshTests` | |
| T-RT-08 | Implemented | `AuthSecuritySchemaTests.T_MIG_04` | Under a schema test name |
| T-RT-10 | Implemented | `SessionCleanupTests` | Also covers the 90-day event retention of T-AU-05 |
| T-MT-06 | Implemented | `RefreshSessionTests` | Server side of two tabs sharing one cookie |
| T-MT-01…05 | Deferred | M2.12 | Flutter unit tests of the new HTTP client |
| T-MT-07, 08 | Deferred | M2.14 | Automated two-tab test in a real browser |
| T-SC-01…06 | Implemented | `SessionValidationTests`, `SecurityFoundationTests` | |
| T-SC-07 | Implemented | `SessionValidationTests.T_SC_05` | The 30-second staleness bound, under another number |
| T-DL-01…11 | Implemented | `DownloadLinkTests` | `revoke-sessions` doesn't exist; admin revocation is tested through suspension (KI-63) |
| T-AN-01 | Implemented | T-7A…T-7D `_01_` tests, `DenyByDefaultTests`, T-IM-01 | Spread across the route matrices rather than one test |
| T-LG-01…11 | Implemented | `LoginTests`, `LoginLockoutTests`, `LoginTimingTests`, `RefreshSessionTests` | |
| T-JWT-01…07 | Implemented | `JwtValidationTests`, `JwtStartupValidationTests` | |
| T-CS-01…07 | Implemented | `CsrfGuardTests`, `JwtValidationTests`, `SecurityFoundationTests` | T-CS-02 and 03 are one test |
| T-OW-01…11 | Implemented | `WriteRouteAuthorizationTests`, `ReadRouteAuthorizationTests` | Written as the M2.7 route matrices (T-7B, T-7C) |
| T-AD-01, 02 | Implemented | `AdminAccountActionsTests`, `AdminRouteAuthorizationTests` | |
| T-AD-03, 04 | Implemented | `AdminProvisioningTests` | Self-promotion and creating an admin through the API are refused |
| T-NT-01, 02 | Implemented | `NotificationTests.T_NR_07`, T-7B, T-7C | |
| T-NR-01…03 | Implemented | `NotificationTests` (T-NR-01…10) | Extended in M2.10 |
| T-PD-01, 02, 05 | Implemented | `ReadRouteAuthorizationTests` (T-7C-10…14) | |
| T-PD-03, 04 | **Missing** | — | Consent to share an applicant's email (Q16) has no route yet; product code needed. Today only the post owner sees an applicant's email (T-7C-15). |
| T-IM-01…07 | Implemented | `SignedImageTests` | Plus T-IM-08…10 |
| T-SP-01…03 | Implemented | `SessionValidationTests`, `RefreshSessionTests` | |
| T-SP-04 | Implemented (M2.11) | `SuspendedEverywhereTests` | Now checks every route, not a sample |
| T-SP-05 | **Partially** | `AdminAccountActionsTests.T_SU_03`, T-7B-25 | Support messages and "an admin can't be suspended" are tested; an appeal route doesn't exist |
| T-VF-01 | Implemented | `WriteRouteAuthorizationTests` | |
| T-GG-01…08 | Implemented | `GoogleSignInTests` (T-GG-01…17) | |
| T-PW-01 | Implemented (M2.11b) | `PasswordPolicyTests.T_PW_01`, `ChangePasswordTests.T_PW_01c` | Reset ends every session; change-password keeps the current session (new access token, refresh still works) and ends every other one |
| T-PW-02…04 | Implemented | `PasswordPolicyTests` | |
| T-PW-05…08 | Implemented (M2.11b) | `PasswordPolicyTests`, `LoginTests.T_LG_04`, `ChangePasswordTests.T_PW_05c…08c` | Sign-up, reset, admin and change-password paths |
| T-RC-01 | Implemented | `PasswordPolicyTests` | |
| T-CD-01…12 | Implemented | `OneTimeCodeTests`, `IpFailureBudgetTests` | |
| T-CD-13, 14 | Implemented | `OneTimeCodeTests.T_CD_09` | Both purposes share the budget; it resets after the rolling hour |
| T-AU-01, 02 | Implemented | `AdminAccountActionsTests` | |
| T-AU-03 | **Missing** | — | "A transactional event rolls back with its failed change" needs a way to make a save fail inside the transaction; larger |
| T-AU-04 | Implemented (M2.11b) | `EmailQueueAuditTests`, `EmailQueueFullTests` | Security events are written in the request's own transaction, not through a channel. The email queue never blocks, refuses mail when full and reports it (KI-67 fixed); each caller handles the refusal (T-AU-04b…d) |
| T-AU-05 | Implemented | `SessionCleanupTests.T_RT_10` | |
| T-AL-01…03 | Implemented | `ReuseAlertTests` | |
| T-SW-01…05 | Implemented | `AuthSwitchTests` | T-SW-05 ("missing key means enforced") is part of T-SW-04 |
| T-SW-06…10 | Implemented | `DevDefault*`, `*RemoteFallback*`, `*Fallback*` classes per case | Each fallback case: off by default, off for non-loopback clients, logged without personal data |
| T-SW-R | Deferred | M2.13 | Proves the fallback is gone once it is removed |
| T-LOG-01 | Implemented | `LoginTests`, `RefreshSessionTests`, `SecurityFoundationTests` (T-LOG-*) | |
| T-REG-* | **Partially** | `WiringAndNotificationTests`, `PasswordHashingTests`, T-7A | Feed, likes, comments, notifications, admin statistics and the legacy rehash are covered; weather is only tested to the point before the external call |

### Endpoint plan (`M2_7_ENDPOINT_PLAN.md`)

| IDs | Status | Where |
|---|---|---|
| T-7A-01…04 | Implemented | `AdminRouteAuthorizationTests` and its fallback classes |
| T-7B-01…05, 1x, 2x | Implemented | `WriteRouteAuthorizationTests` and its fallback classes |
| T-7C-01…18 | Implemented | `ReadRouteAuthorizationTests` and its fallback classes |
| T-7D-01…30 | Implemented | `MemberRouteAuthorizationTests`, `DenyByDefaultTests` |
| T-SU, T-DEL, T-MIG, T-UL, T-RL, T-SE | Implemented | `AdminAccountActionsTests`, `AuthSecuritySchemaTests`, `UnknownEmailLockoutsTests`, `RateLimitTests`, `LoginTests` |

Some older tests have descriptive names without an ID: `AuthFlowTests`, `PasswordHashingTests`, `ErrorHandlingTests`, `AdminProvisioningTests` and parts of `WiringAndNotificationTests`. They are counted under their areas above.

## Gaps

### Added in M2.11 (small, tests only)

| Test | What it adds |
|---|---|
| T-SP-04, T-SP-04a | Every route except the reviewed allowlist refuses a suspended account with 403 `ACCOUNT_SUSPENDED`. The allowlist itself is fixed by a test. |
| T-AU-04 | A full email queue never blocks a request and never grows past 1,000 mails |

### Product defect found

**KI-67 (fixed in M2.11b):** `EmailQueue.Enqueue` used a bounded channel in `DropWrite` mode, and there `TryWrite` returns `true` even for the mail it drops. Callers couldn't tell that an email was lost, and the refresh-token reuse alert recorded "Success" from this value. The queue now uses `Wait` mode, where `TryWrite` returns `false` at once when full, and logs the drop with the subject only.

### Closed in M2.11b

| Test | What it adds |
|---|---|
| T-PW-01c, T-PW-05c…08c | The change-password parts of T-PW-01 and T-PW-05…08 |
| T-PW-09 | A wrong current password counts toward the login lockout; the 5th failure locks change-password and login |
| T-PW-10 | A Google-only account gets 400 `PASSWORD_NOT_SET` and builds no lockout; after a reset it can change its password |
| T-PW-11 | Anonymous callers and ended sessions get 401; missing fields get 400 |
| T-PW-12 | change-password is rate-limited per IP (429 `RATE_LIMITED`) |
| T-AU-04 (updated), T-AU-04b…d | A full queue reports the refusal; code requests keep the generic response and log without the address; the reuse alert records Failure/QueueFull; a password change still completes |

### Larger gaps (not written)

| Gap | Why it is larger |
|---|---|
| T-PD-03, 04: applicant email only with consent (Q16) | Needs the consent route and data first |
| T-SP-05: appeal | No appeal route exists |
| T-AU-03: an event rolls back with its failed change | Needs a test seam to force a save to fail inside the transaction |
| `revoke-sessions` (KI-63) | The route doesn't exist; its link test waits for it |
| T-MT-01…05 | Flutter tests, M2.12 |
| T-MT-07, 08 | Real-browser two-tab test, M2.14 |
| T-SW-R | M2.13, when the fallback is removed |
| Weather success path | Needs a fake for the external weather service |
