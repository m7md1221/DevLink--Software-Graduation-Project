# M2 — Authentication & Authorization: Design (revision 3)

**Status:** **Approved by the owner on 2026-11-03** together with sequencing fixes 1 and 2 (§11), R1, R2 and R3 (14-day retention for truncated IP ranges). The `Microsoft.AspNetCore.Authentication.JwtBearer` package is approved for M2.2. No code, schema, data, configuration, dependency or Git-staging change has been made; implementation starts with M2.2 in a later session.
**Branch:** `feature/m1-foundation` @ `2910d88` + uncommitted M1 work. `origin` has no newer commits.
**Inputs:** the current code (every controller read in full), spec `05` (Users, RefreshTokens, §6.1), `03` (FR-AUTH-01…10, BR-02), `10` (D-17, D-18), [decision-log.md](decision-log.md), [known-issues.md](known-issues.md).
**Fixed constraints:** keep the `/api/{Controller}` routes (D11) · Flutter keeps `Navigator` + `http` (D12) · existing navigation, social feed, weather and notification UI kept · partner's code preserved · no `/api/v1`.

**Changes from revision 2:**
- §0: final architecture summary and the table of approved provisional decisions (13 product decisions added).
- §3.4: refresh-token records: every token is kept as its own row; family revocation spelled out (clarification **A**).
- §3.5: cross-tab Web Locks strategy; unsupported browsers can't sign in (clarification **B**).
- §3.7: what the session cache really does with one instance and with several (clarification **C**).
- §5.1: download links gain a binding cookie and a separate consumption route (clarification **D**).
- §5.2: avatars and post images are **no longer anonymous** (Q15) → the public set drops from 12 to **8**.
- §6.2: verification codes stored in the database as keyed hashes (Q7).
- §6.4: minimal `SecurityEvents` audit table (Q8).
- §6.5: refresh-token reuse alert email (Q12).
- §7.4: restricted mode for suspended accounts (Q5).
- §8: matrix updated for Q4, Q5, Q15, Q16 and N1.
- §9: partner-review list completed.
- §10: tests for A–D and the new decisions.
- §11: final sequence with test evidence.
- §12: remaining blockers and partner approvals.

---

## 0. Final architecture summary

| Area | Final design | Section |
|---|---|---|
| Identity | The server derives identity and role from the token; client-sent ids and `isAdmin` are ignored | §7 |
| Access token | HS256 JWT, 15 min, in Dart memory only, `Authorization: Bearer` — the only way protected endpoints authenticate | §3.1–3.2 |
| Refresh token | 256-bit opaque value; only its SHA-256 hash is stored. **Every rotated token stays as its own row** until its session has been over for 30 days | §3.4 |
| Session | One `AuthSessions` row (`sid`) per sign-in per browser or device; several per user | §3.4 |
| Rotation | Strict single use, row lock + conditional update, no grace period | §3.4 |
| Reuse | Presenting a rotated token revokes that whole session (all of its tokens and its access tokens) — other devices are unaffected. Audit event, plus a generic alert email (rate-limited) | §3.4, §6.5 |
| Cross-tab | One refresh at a time per browser through the Web Locks API; browsers without it can't sign in and see a clear message | §3.5 |
| Revocation | Security stamp + session status checked on every request through a per-process cache invalidated synchronously. **Supported topology: one API instance.** A multi-instance configuration refuses to start | §3.6–3.7 |
| Web storage | Refresh token in an `HttpOnly; Secure; SameSite=Strict` cookie scoped to `/api/Auth/session`; nothing secret in SharedPreferences | §4.1 |
| CSRF | Exact Origin/Referer allowlist + `X-DevLink-Client` header + JSON content type + SameSite=Strict + strict CORS | §4.2 |
| Private files | CV and certificate: 60-second single-use links, bound to recipient, session and file content, with a binding cookie; never logged | §5.1 |
| Images | Avatars and post images served through signed member URLs; nothing anonymous | §5.2 |
| Codes | Database-stored HMACs, 10 min, 5 attempts, single use, proof tokens, rate limits, generic wording | §6.2 |
| Audit | `SecurityEvents` table plus structured logs; secrets never recorded | §6.4 |
| Suspension | Restricted mode: suspension notice, support/appeal, logout only | §7.4 |
| Authorization | Fallback policy (deny unless `[AllowAnonymous]`), role policies, ownership checks; **8 anonymous endpoints** out of 67 | §7–§8 |
| Mobile | Deferred (Q2): refresh token in memory only; no new package | §4.4 |
| Migration switch | `Auth:EnforceAuthorization`: Development + loopback only; deleted in M2.13 | §7.3 |

### 0.1 Approved decisions

| ID | Decision | Approved | Section |
|---|---|---|---|
| **D10** | Token architecture as summarized above | Provisional, 2026-11-03 | §3–§4 |
| **P1** | Minimum length 8 for new, changed and reset passwords; never checked at login; M1 hashing and legacy upgrade kept | 2026-11-03 | §6.1 |
| **Q1** | Migration switch with safeguards (Development only, startup refusal elsewhere, never exposed, tested, removed before M2 completes) | 2026-11-03 | §7.3 |
| **Q3** | Emails and phone numbers hidden from public profiles, search and application lists; visible to the owner and explicitly authorized admins/workflows | 2026-11-03 | §8 |
| **Q6** | Generic verification/reset responses with clear wording | 2026-11-03 | §6.2 |
| **Q11** | Pre-M2 Google accounts recovered by password reset + explicit linking; never auto-link by email | 2026-11-03 | §6.3 |

### 0.2 Approved provisional product decisions (owner, 2026-11-03)

| ID | Decision | How this design implements it | Section |
|---|---|---|---|
| **Q2** Android | Web is the M2 target. Persistent Android token storage is deferred until Android is confirmed as a graduation deliverable | Mobile mode keeps the refresh token in memory only; no package added | §4.4 |
| **Q4** Support form | Signed-in Customers and Programmers can submit; anonymous visitors never reach support tickets | `POST /api/Support` requires C or P; no anonymous route | §8 #59, §8.2 |
| **Q5** Suspended accounts | Restricted access: see the suspension notice, contact support/appeal where supported, log out; no normal marketplace actions | `[AllowSuspended]` allowlist; everything else 403 `ACCOUNT_SUSPENDED` | §7.4 |
| **Q7** Verification codes | Only keyed hashes in the database, with expiry, attempts, single use and rate limits | `OneTimeCodes` table | §6.2 |
| **Q8** Audit log | Minimal security-event audit; never passwords, raw tokens, codes or secrets | `SecurityEvents` table + logs | §6.4 |
| **Q9** Devices | Device-management UI deferred; current-session logout and logout-everywhere/revocation implemented | `session/logout`, `logout-all`, admin `revoke-sessions`; no device list | §3.6 |
| **Q10** Admin provisioning | CLI `seed-admin` only; no public admin-creation endpoint | M1 rule kept: creating/promoting admins via the API → 403 | §8 #11–13 |
| **Q12** Reuse alert | Generic security alert to the account owner, asynchronous, rate-limited, no sensitive details | Background email, max 1 per session and 3 per user per day | §6.5 |
| **Q13** Admin Google sign-in | Disabled in M2 unless a separately reviewed policy is approved | Google login and linking → 403 for Admin | §6.3 |
| **Q14** Certificate replacement | Resets verification to Pending | Already the partner's behaviour (`IsVerified = false` on upload, replace and delete; the admin UI shows it as Pending) — kept and covered by tests | §8 #31–32 |
| **Q15** Avatars | Only avatars of profiles explicitly intended to be public are exposed; private images stay protected | No profile is public to signed-out visitors today → no anonymous image route; members get signed URLs | §5.2, §8.2 |
| **Q16** Applicant email | Shown to the project owner only after acceptance **and** with the programmer's explicit consent | Consent column + route; email hidden otherwise | §8 #50, new route |
| **N1** Notifications | Remove the automatic deletion of all but the newest five; keep history with pagination; document cleanup separately | Delete removed; `limit`/`before` paging; bell unchanged (default 5) | §8 #35, §12 |

### 0.3 Binding conditions for M2 (owner, 2026-11-03)

These conditions are **binding**: an M2 task isn't done until the conditions that apply to it are met and their tests pass.

| ID | Condition (summary) | Where specified | Proven by | Task |
|---|---|---|---|---|
| **C1** | The development fallback (all 4 cases) is active only if Environment = Development **and** explicitly enabled **and** the request comes from loopback. The app fails to start if it is enabled outside Development. Each use logs a warning (no personal data or tokens). Each case has a test proving it is off by default. M2.13 adds a test proving the paths are removed | §7.3 | T-SW-01…10, T-SW-R | M2.2 (switch), M2.5/M2.8 (cases 2–4), M2.13 (removal) |
| **C2** | Document exactly what is checked per authenticated request and where (database or in-process cache), the maximum staleness in seconds, that it's single-instance only, and what's required before scaling out | §3.7 | T-SC-01…07 | M2.4 |
| **C3** | Besides Web Locks, the Flutter client keeps one in-flight refresh per tab. T-MT-07 must prove that two simultaneous tabs cause no false reuse detection | §3.5, §10.2 | T-MT-01, T-MT-03, **T-MT-07 (automated)** | M2.12, M2.14 |
| **C4** | Web Locks needs a secure context: HTTPS or `localhost`. A LAN IP over HTTP blocks sign-in — a demo/deployment constraint | §3.5, §4.2, [KI-33](known-issues.md) | T-MT-04 | M2.12, deployment |
| **C5** | Signed image URLs use **10-minute** bucketed expiry windows, so URLs are stable within a window and browser caching works. Signatures are never logged | §5.2 | T-IM-01…07 | M2.8 |
| **C6** | Besides 5 attempts per code, an aggregate limit per email and per IP across all codes in a rolling hour | §6.2 | T-CD-11…14 | M2.5 |
| **C7** | Minimum 8 characters for new/changed passwords **plus** a bundled common-password blocklist. Legacy accounts can still sign in | §6.1 | T-PW-05…08, T-LG-04 | M2.5 |
| **C8** | JwtBearer: **latest stable 9.0.x = 9.0.22** (owner override 2026-11-03 of "same patch as the other packages"), exact version recorded; no other package changes in M2.2 | §11 (M2.2), [decision-log](decision-log.md) | `git diff` of `DotnetAPI.csproj` = 1 line | M2.2 |
| **C9** | A partner-coordination section: migration on their DB after a backup, CORS origin/port, removal of the "newest 5" deletion, Flutter review list including `admin_user_form_page.dart` and F18 | §13 | Partner sign-off recorded in the decision log | M2.3/M2.6, M2.2, M2.10, M2.12 |

---

## 1. Current authentication architecture (unchanged)

**Password login, from the Flutter screen to the database:**
1. `WelcomePage` → the user picks a role → `LoginPage(userType)`.
2. `LoginPage` calls `POST /api/Auth/login` directly with `http.post` ([login_page.dart:192](../frontend/lib/pages/Common/login_page.dart#L192)).
3. `AuthController.Login` ([Controllers.cs:33](../backend/Controllers/Controllers.cs#L33)) finds the user by `Email` + `UserType` and calls `PasswordService.Verify`: PBKDF2, or legacy plaintext → rehash.
4. The API returns `{userId, userType, email, hasProfile, hasProgrammerProfile}` — **no credential**.
5. `SessionManager.saveUser` stores these values in SharedPreferences.
6. Later calls send the user id in the URL or body. There is no `AddAuthentication`, and no `[Authorize]` anywhere.
7. Logout only clears SharedPreferences, in 4 pages.
8. There is no session restore (`MaterialApp(home: WelcomePage())`).

**Google sign-in:** `GoogleAuthService.VerifyIdToken` checks the token's signature, issuer, expiry and audience. Any existing account with the same email is then logged in — any role, and `email_verified` is not checked.

**Sign-up and reset:** codes are kept in memory (`VerificationService`) and created with `Random.Shared`, with unlimited attempts. Verification marks the **email** as verified for 30 minutes, for anyone who then calls `signup` or `reset-password`.

**CORS:** `AllowAnyOrigin`. The API is bound to localhost only.

**Frontend HTTP calls:**
- Raw `http` calls in `api_service.dart` (27), `post_service.dart` (19), `support_service.dart` (8), `notification_service.dart` (2), `weather_service.dart` (2) and `login_page.dart` (1).
- Images loaded by URL that the client builds itself: `PostService.getUserAvatarUrl` (12 call sites), `getPostImageUrl` (2), `ApiService.getProfileImageUrl` (1), `getProgrammerImageUrl` (3).
- CV and certificate opened with `launchUrl` in `admin_verification_details_page.dart:45` and `programmer_dashboard_page.dart:117`. `file_saver` is a dependency but is not used in `lib/`.

## 2. Security gaps (G1–G19, unchanged)

| Gap | Severity | Problem |
|---|---|---|
| G1 | Critical | No authentication |
| G2 | Critical | Identity taken from client ids (about 20 places) |
| G3 | Critical | `isAdmin=true` query flag |
| G4 | Critical | Admin, moderation and support-admin endpoints are anonymous |
| G5 | High | Notifications (KI-27) |
| G6 | High | CV and certificate readable by anyone |
| G7 | High | Phone numbers, emails and support tickets readable by id |
| G8 | High | `ProgrammerProfile/{id}/verify` and `/unverify` are anonymous |
| G9 | High | Google takeover by matching email; `email_verified` not checked |
| G10 | High | Password reset and sign-up bound only to the email |
| G11 | High | Verification codes can be brute-forced |
| G12 | Medium | No rate limiting or lockout |
| G13 | Medium | User enumeration through code requests |
| G14 | Medium | Other users' profiles, files and flags can be modified |
| G15 | Medium | No server sessions, revocation or suspension |
| G16 | Medium | Client-side session never revalidated |
| G17 | Low | CORS wildcard |
| G18 | Low | `ex.Message` returned in weather 500 responses; console logging |
| G19 | Low | Images and comments of unapproved posts are public; actions allowed on unapproved posts |

---

## 3. Token architecture

### 3.1 Summary

| Element | Design |
|---|---|
| **Access token** | JWT signed with HS256; **15 minutes**; sent as `Authorization: Bearer`. It is the *only* way protected endpoints authenticate. The server never authenticates a request from a cookie or a query-string token (the two exceptions are the session endpoints, §4.2, and the file-download consumption route, §5.1, which have their own checks) |
| **Refresh token** | Opaque: 32 bytes from `RandomNumberGenerator` (256 bits), base64url. **Only the SHA-256 hash is stored**, one row per token |
| **Session** | One `AuthSessions` row (`Id` = the `sid` claim) per sign-in per browser or device. Several per user |
| **Rotation** | Strict single use: every successful refresh atomically marks the presented token `Rotated` and creates exactly one successor. **No grace period** |
| **Concurrency** | Client side: one refresh per tab (shared `Future`) and per browser (Web Locks) — §3.5. Server side: row lock — §3.4 |
| **Reuse** | Presenting a `Rotated` token revokes its session and every token in it, invalidates the session's access tokens immediately, writes an audit event, queues a generic alert email, returns 401 and clears the cookie |
| **Per-request check** | After signature validation: user exists; `Status` allowed for the endpoint (§7.4); `sstamp` = current `SecurityStamp`; session `sid` still active. Served from the session-state cache — §3.7 |

### 3.2 JWT signing and validation (unchanged from revision 2)

**Why HS256:**
- This API is both the only issuer and the only validator; no other service verifies DevLink tokens.
- With a symmetric key there is one secret to protect. RS256/ES256 would add a public key that only other validators need — and there are none.
- If a separate service ever needs to validate tokens, switch to ES256 with a published JWKS.

**Key generation:**
- 64 bytes (512 bits) from a CSPRNG, base64-encoded — **64 bytes is also the enforced minimum** (owner decision at M2.2; HS256 itself needs 32). Generated locally and piped into user-secrets as JSON on stdin, so the value never appears on screen, in shell history or in a process command line (exact command: README "JWT signing key"; Git Bash, because Windows PowerShell 5.1 adds a byte-order mark when piping — KI-36).
  `Jwt:SigningKeys:0:Id` is a non-secret key id (`kid`), for example `local-2026-11-a`.
- The same procedure provisions the two other secrets introduced by this design: `Security:CodeHmacKey` (§6.2) and `Security:MediaUrlKey` (§5.2). Each key is separate; none is derived from another.
- Startup **fails fast** if, for any of these keys: no active key exists (JWT: exactly one `Active`); a key is not valid base64; a decoded key is shorter than 64 bytes (JWT) / 32 bytes (code and media keys, validated from M2.5 / M2.8 when they are introduced); a key equals the placeholder in `appsettings.example.json`; two JWT keys share an `Id`.

**Provisioning:**
- **Local:** `dotnet user-secrets` only. Each developer generates their own keys; they are never shared in chat, Git or `appsettings*.json`.
- **Tests:** the test factory generates random keys per run in memory.
- **Deployment:** environment variables (`Jwt__SigningKeys__0__Key`, `Security__CodeHmacKey`, `Security__MediaUrlKey`) set from the host's secret store. Never baked into images or files; the pipeline must not echo them.

**Validation parameters:**

| Parameter | Value |
|---|---|
| `ValidateIssuer` / `ValidIssuer` | `true` / `"DevLink.Api"` (configurable) |
| `ValidateAudience` / `ValidAudience` | `true` / `"DevLink.Clients"` |
| `ValidateLifetime`, `RequireExpirationTime` | `true` |
| `ValidateIssuerSigningKey`, `RequireSignedTokens` | `true`; `IssuerSigningKeys` = every configured key, matched by `kid` |
| `ValidAlgorithms` | `["HS256"]` — rejects `alg: none`, algorithm confusion and anything unexpected |
| `ClockSkew` | 30 s |
| `MapInboundClaims` | `false`; `NameClaimType = "sub"`, `RoleClaimType = "role"` |
| Token type | `typ = "at+jwt"` issued and required |
| Maximum lifetime | Tokens with `exp − iat` > 15 min + skew are rejected |

**Claims:** `sub` (user id), `role` (from the database), `sstamp`, `sid`, `jti`, `iat`, `exp`, `iss`, `aud`. **No email, phone or other personal data.**

**Key rotation:** `Jwt:SigningKeys` is a list of `{Id, Key, Status: Active|ValidateOnly}`.
- **Planned:** (1) add the new key as `ValidateOnly`, deploy; (2) make it `Active`, old one `ValidateOnly`, deploy; (3) after more than 15 min + skew, remove the old key. Refresh tokens are not JWTs, so nobody is logged out.
- **Emergency (key leaked):** replace every key at once; clients refresh silently. If database compromise is also suspected, rotate every `SecurityStamp` and revoke all sessions (documented admin script).
- `Security:CodeHmacKey` rotation invalidates outstanding codes (≤ 10 min, acceptable). `Security:MediaUrlKey` rotation invalidates signed image URLs (≤ 2 h; the app reloads them).

**Logging prohibition:**
- Never logged or stored in `SecurityEvents`: the `Authorization` header, cookies, access or refresh tokens, token hashes, download-link tokens, binding-cookie values, media signatures, verification codes, proof tokens, keys, passwords, connection strings.
- Concretely:
  - `IdentityModelEventSource.ShowPII` stays `false`;
  - `JwtBearerEvents` log only the failure *type*;
  - no `UseHttpLogging`;
  - `Microsoft.AspNetCore.Hosting.Diagnostics` and `Microsoft.AspNetCore.Routing` at `Warning` in every environment (at `Information` they log full request URLs);
  - a startup test asserts these log levels.

### 3.3 Lifetimes

| Item | Value | Rationale |
|---|---|---|
| Access token | 15 min (spec §6.1) | Bounds offline misuse of a copied token; revocation itself is per request |
| Refresh — Customer/Programmer | 7 days idle (sliding), 30 days absolute per session | Occasional marketplace use; monthly re-authentication |
| Refresh — Admin | 8 h idle, 24 h absolute | Admin powers justify a daily re-login |
| Session-state cache | ≤ 30 s TTL, cleared synchronously on every change | §3.7 |
| Verification / reset code | 10 min, 5 attempts | §6.2 |
| Proof token (sign-up / reset) | 15 min, single use | §6.2 |
| Download link | 60 s, single use | §5.1 |
| Signed image URL | 10-minute buckets: valid 10–20 min, identical within a bucket (C5) | §5.2 |
| Token and session rows | Kept until the session has ended (revoked or absolute expiry) **plus 30 days**, then deleted per session | §3.4 |
| `OneTimeCodes` rows | Deleted 24 h after expiry | §6.2 |
| `SecurityEvents` rows | 90 days; the truncated `IpPrefix` is nulled after 14 days (R3) | §6.4 |

### 3.4 Refresh-token records, rotation and replay detection (clarification A)

**Confirmation:** every refresh token ever issued is stored as **its own row**. Rotation never overwrites or deletes a hash. It changes the old row's `Status` from `Active` to `Rotated` and inserts a new row. A replayed old token therefore always finds its row and is detected as reuse for as long as its session can still be active, plus 30 days.

**Table `AuthSessions`** (one row per session, i.e. per refresh-token family):

| Column | Type | Notes |
|---|---|---|
| `Id` | `uniqueidentifier` PK | The `sid` claim. Random (`Guid.NewGuid()`), not secret |
| `UserId` | `int` FK → `Users`, **NO ACTION** (`FK_AuthSessions_Users`; owner rule at M2.3: security records are never cascade-deleted) | |
| `ClientType` | `varchar(16)` CHECK `web`/`mobile` | |
| `Status` | `varchar(16)` CHECK `Active`/`Revoked`/`Expired` | |
| `CreatedAt` | `datetime2` | |
| `LastRefreshedAt` | `datetime2` | |
| `AbsoluteExpiresAt` | `datetime2` | 30 days (Admin 24 h) after sign-in |
| `RevokedAt` | `datetime2` null | |
| `RevokeReason` | `varchar(32)` null | `Logout`, `LogoutAll`, `PasswordChanged`, `PasswordReset`, `RoleChanged`, `AdminChanged`, `AdminRevoked`, `ReuseDetected`, `GoogleLinked` |
| `DownloadBindingHash` | `binary(32)` null | SHA-256 of the binding cookie (web only, §5.1) |

Index: `(UserId, Status)`.

**Table `RefreshTokens`** (one row per token):

| Column | Type | Notes |
|---|---|---|
| `Id` | `bigint` identity PK | |
| `SessionId` | `uniqueidentifier` FK → `AuthSessions`, **NO ACTION** (`FK_RefreshTokens_AuthSessions`) | The family. The cleanup service deletes a session's tokens first, then the session |
| `TokenHash` | `binary(32)` **unique** | SHA-256 of the raw token. The raw token is never stored |
| `Status` | `varchar(16)` CHECK `Active`/`Rotated`/`Revoked` | |
| `CreatedAt` | `datetime2` | |
| `ExpiresAt` | `datetime2` | `min(CreatedAt + idle, session.AbsoluteExpiresAt)` |
| `ConsumedAt` | `datetime2` null | Set when it was rotated (used) |
| `RevokedAt` | `datetime2` null | Set when revoked without being used |
| `ParentTokenId` | `bigint` null, FK → `RefreshTokens` (no cascade) | The token it replaced; null for the first token of a session |
| `ReplacedByTokenId` | `bigint` null, FK → `RefreshTokens` (no cascade) | Set together with `Status = Rotated` |

Indexes: unique `TokenHash`; `(SessionId, Status)`. A filtered unique index on `SessionId WHERE Status = 'Active'` makes it **impossible at the database level** for a session to hold two active tokens.

**Rotation** (`POST /api/Auth/session/refresh`), one transaction:
```
hash = SHA256(presented)
tok  = SELECT ... FROM RefreshTokens WITH (UPDLOCK, ROWLOCK) WHERE TokenHash = @hash
if tok is null                                → 401 SESSION_EXPIRED            (unknown token, no detail)
ses  = SELECT ... FROM AuthSessions WITH (UPDLOCK, ROWLOCK) WHERE Id = tok.SessionId
if ses.Status != 'Active'                     → 401 SESSION_REVOKED            (already ended; event Auth.EndedSessionTokenPresented, no alert)
if tok.Status == 'Rotated'                    → REUSE (below)
if tok.Status == 'Revoked'                    → 401 SESSION_REVOKED
if tok.ExpiresAt <= now or ses.AbsoluteExpiresAt <= now
                                              → end session (Status = Expired); 401 SESSION_EXPIRED
UPDATE RefreshTokens SET Status = 'Rotated', ConsumedAt = now, ReplacedByTokenId = @newId
       WHERE Id = @tok.Id AND Status = 'Active'          -- must affect exactly 1 row, else REUSE
INSERT RefreshTokens (SessionId, TokenHash = SHA256(new), Status = 'Active', ParentTokenId = @tok.Id, ExpiresAt = ...)
UPDATE AuthSessions SET LastRefreshedAt = now WHERE Id = @ses.Id
COMMIT → new access token (current SecurityStamp, sid = ses.Id) + Set-Cookie (web) or body token (mobile)
```
- The row locks and the conditional `UPDATE` guarantee that two requests carrying the same token can never both rotate it. The second waits for the first, then finds `Status = Rotated` and is handled as reuse.
- The filtered unique index is a second, independent guard.
- **Suspended users** can refresh (restricted mode, §7.4); the status is enforced per request, not at refresh.
- **Lost response:** if the server rotated but the client never received the new cookie (network drop, tab closed mid-request), the next refresh presents the old token → reuse → the user signs in again. Accepted: safe, rare and visible.

**Reuse handling** (same transaction):
1. `UPDATE AuthSessions SET Status = 'Revoked', RevokedAt = now, RevokeReason = 'ReuseDetected' WHERE Id = @ses.Id`.
2. `UPDATE RefreshTokens SET Status = 'Revoked', RevokedAt = now WHERE SessionId = @ses.Id AND Status = 'Active'` — the active successor dies too, whoever holds it. Rotated rows keep their status for forensics.
3. Insert a `SecurityEvents` row `Auth.RefreshTokenReuse` (Warning): `UserId`, `SessionId`, the reused token's `Id`, seconds since it was rotated, client type, IP, trace id. Never the token or its hash.
4. Commit, then invalidate the user's session-state cache (§3.7). Access tokens with that `sid` get `401 SESSION_REVOKED` on their next request.
5. Respond `401 SESSION_REVOKED` with `Set-Cookie` deleting `devlink_rt` and the binding cookie.
6. Queue the alert email (§6.5).

**Other devices are unaffected:** only rows with this `SessionId` change. The user's `SecurityStamp` is **not** rotated by reuse (rotating it would sign out every device). Each other session has its own `AuthSessions` row and stays `Active`.

**Cleanup** (hosted service, hourly): deletes an `AuthSessions` row and its tokens only when the session is no longer `Active` **and** it ended (`RevokedAt`, or `AbsoluteExpiresAt`) more than 30 days ago. Rows of a live session are never deleted, so no old hash of a live session can disappear.

### 3.5 Cross-tab refresh coordination (clarification B)

**Problem:** all tabs of one browser share the `devlink_rt` cookie. If two tabs send the same refresh token at the same time, the server sees reuse and ends the session (§3.4). That would be a false alarm, so it must not happen in a supported browser.

**Strategy (web):**
1. **Within a tab:** `AuthHttp` holds one in-flight `Future<bool>`. Every request that receives `401 TOKEN_EXPIRED`, and the proactive timer (about 60 s before expiry), await that same future.
2. **Across tabs:** the refresh HTTP call runs inside
   `navigator.locks.request('devlink-refresh', {mode: 'exclusive', signal: AbortSignal.timeout(15 s)}, callback)`, through the existing `package:web` dependency. Lock names are scoped to the origin, so only DevLink tabs share it.
   - The browser stores the response's `Set-Cookie` **before** the `fetch` promise resolves, so when Tab A releases the lock, the cookie jar already holds the new token.
   - Tab B then acquires the lock and sends the *new* token: a normal rotation. Each tab ends with its own access token; exactly one refresh token is active.
   - The HTTP call inside the lock has a 10 s timeout, so a stuck request can't hold the lock forever. If the tab closes, the browser releases the lock automatically.
   - If the lock isn't granted within 15 s, the tab shows "Your session could not be refreshed. Please sign in again." and goes to `WelcomePage` — it never refreshes without the lock.
3. **Supported browsers:** Chrome and Edge 69+, Firefox 96+, Safari 15.4+, in a **secure context** (condition C4).
   - The Web Locks API (and the `Secure` refresh cookie) exists only on `https://` pages, or on `http://localhost` / `http://127.0.0.1`.
   - Opening the app by a LAN address over plain HTTP (e.g. `http://192.168.1.20:5200` from a phone or another laptop during a demo) is **not** a secure context. `navigator.locks` is undefined there, so sign-in is blocked by the message in point 4.
   - For demos on another device, serve the app over HTTPS (a trusted certificate, or an HTTPS tunnel) or present from the machine itself on `localhost` — [KI-33](known-issues.md).
   - Chrome/Edge are the supported development browsers (§4.2).
   - **The in-tab single-flight (point 1) is always active**, with or without Web Locks (C3). Web Locks coordinates *between* tabs; the shared `Future` coordinates *within* a tab.
4. **When Web Locks is unavailable** (`navigator.locks` undefined: an old browser, or a page not in a secure context): **required browser, graceful failure** (decision R2):
   - The bootstrap detects it before any session call. Login, sign-up and Google buttons are disabled, and the welcome screen shows: "DevLink needs a current version of Chrome, Edge, Firefox or Safari. Please update your browser to sign in."
   - No refresh token is ever issued to such a browser, so no false reuse can happen.
   - Rejected alternatives: a `localStorage` mutex has a check-then-set race and isn't safe; keeping a per-tab refresh token in JavaScript memory would expose it to XSS; BroadcastChannel leader election is missing in the same old browsers.
5. **If a reuse logout happens anyway** (lost response, §3.4): the app shows "For your security, you were signed out. Please sign in again." and navigates to `WelcomePage`.
6. **Mobile:** one app instance, so the in-tab single-flight is enough.

### 3.6 Revocation and security stamp

**Security stamp:**
- `Users.SecurityStamp` is a 32-character random hex string, rotated by `SessionService.RotateStampAsync(userId, reason)`.
- Access tokens carry it as `sstamp`. A token whose `sstamp` differs from the current one is rejected.

| Event | Stamp | Sessions revoked | Current device | Other devices |
|---|---|---|---|---|
| Logout (`session/logout`) | – | current | signed out | unaffected |
| Logout everywhere (`logout-all`) | rotated | all (`LogoutAll`) | signed out | signed out on their next request |
| Password change (current password required) | rotated | all **except current** (`PasswordChanged`); the current session gets a new token | stays signed in | signed out on their next request |
| Password reset (code + proof token) | rotated | all (`PasswordReset`) | signs in with the new password | signed out |
| Suspension (admin) | rotated | all (`Suspended`) | signed out; a new sign-in is restricted (§7.4) | signed out *(owner change 2026-11-04, M2.5b: was "none, restricted on the next request")* |
| Unsuspension | – | none | sessions opened while suspended get full access on their next request (cache cleared) | same |
| Admin "sign out everywhere" (`revoke-sessions`) | rotated | all (`AdminRevoked`) | signed out | signed out |
| Role change / admin password or email change | rotated | all (`RoleChanged`/`AdminChanged`) | signs in again → new role | signed out |
| Refresh-token reuse | – | that session (`ReuseDetected`) | that device signed out | unaffected |
| Account deleted | – | **not cascaded** (NO ACTION FKs): the delete path must first revoke and delete the user's `RefreshTokens` and `AuthSessions` explicitly (M2.5/M2.7), otherwise the database refuses the delete. `SecurityEvents` rows stay (no FK). Soft delete (KI-10) remains the long-term answer | 401 | 401 |
| Google identity linked | rotated | all except current (`GoogleLinked`) | stays | signed out |

Suspension and unsuspension take effect through `Users.Status` and the synchronous cache invalidation (§3.7). The admin can combine suspension with `revoke-sessions` if a device must also be signed out.

**Device management (Q9):** no device list or per-device UI in M2. Users have current-session logout and logout-everywhere; admins have `revoke-sessions`. No IP address or user agent is stored on sessions (IPs appear only in `SecurityEvents`, §6.4).

### 3.7 Session-state cache and multiple instances (clarification C, condition C2)

**Exactly what is checked on every authenticated (Bearer) request, in this order:**

| # | Check | Source | Failure |
|---|---|---|---|
| 1 | JWT signature, `alg`, `typ`, `iss`, `aud`, `exp`/`iat`, maximum lifetime | In-process, stateless (configured keys) | 401 `UNAUTHENTICATED` / `TOKEN_EXPIRED` |
| 2 | The user `sub` exists | **In-process cache** (`sess:{userId}`), loaded from the DB on a miss | 401 `SESSION_REVOKED` |
| 3 | `sstamp` claim == `Users.SecurityStamp` | Same cache entry | 401 `SESSION_REVOKED` |
| 4 | Session `sid` is in the user's `Active` sessions (`AuthSessions.Status = 'Active'`) | Same cache entry | 401 `SESSION_REVOKED` |
| 5 | `Users.Status` allows the endpoint (`Active`; `Suspended` only on `[AllowSuspended]` routes) | Same cache entry | 403 `ACCOUNT_SUSPENDED` |
| 6 | Role policy and ownership for the endpoint | Role from the token (role changes rotate the stamp, so check 3 catches a stale role); ownership from the DB inside the endpoint | 403 `FORBIDDEN` |

**Not served from the cache — always read directly from the database:**
- `session/refresh` and `session/logout` (refresh-token and session rows, under row locks, §3.4);
- download-link consumption (session and user status, §5.1);
- login, code verification and every write path.

**Maximum staleness:**
- **0 s** for any change made through this API process — logout, logout-all, password change or reset, suspension, unsuspension, role change, revoke-sessions, reuse revocation. The cache entry is invalidated synchronously after the transaction commits, so the next request reloads it. A request that had already passed the check before the commit may still complete.
- **≤ 30 s** for changes made **outside** the API process: direct SQL, the `seed-admin` CLI (a separate process), the emergency "revoke all sessions" script, a migration. The entry expires after its 30 s TTL. Procedures that need immediate effect (the emergency script) restart the API, or wait 30 s, as their last step.
- **Upper bound in every case: 30 s.**

**What the per-request check reads:** `{Status, SecurityStamp, ActiveSessionIds}` for the token's user. One indexed query: the user row plus the `Id`s of the user's `Active` sessions.

**Single instance — the supported topology for local development and the graduation deployment:**
- **Mechanism:** `SessionStateCache` wraps the in-process `IMemoryCache`, key `sess:{userId}`, 30 s absolute TTL.
- **Synchronous invalidation:** every write path in §3.6, plus suspension, unsuspension and reuse, calls `SessionStateCache.Invalidate(userId)` in the same request, **after** the database transaction commits and before the response is sent. Because all requests are served by this one process, the next request — from any device — reloads from the database. Revocation is therefore immediate.
- **Stale-reload race:** a request that started loading *before* an invalidation could otherwise write old data back *after* it. Each user has a generation counter. `Invalidate` increments it, and a loader stores its result only if the generation is unchanged since the load began.
- **Fail-secure:**
  - A cache miss always goes to the database.
  - If the database is unavailable on a miss, the request fails with 503 — never "assume valid".
  - A cached entry is never used beyond its TTL.
  - The in-memory cache cannot be unavailable on its own; a process restart simply empties it.

**Several instances — not supported in M2:**
- A local memory cache in instance 1 is **not** cleared by a write handled by instance 2. That instance could keep accepting a revoked session for up to 30 s. This design therefore **does not claim** immediate revocation across instances.
- **Configuration guard:** `Deployment:Topology` = `SingleInstance` (default) or `MultiInstance`. Startup refuses `MultiInstance` in M2, because three in-memory components are single-instance only: the session cache, the download-link store (§5.1) and the per-IP rate limiters (§6.2).
  - The guard can't detect someone starting two copies with `SingleInstance`. The README's deployment checklist states "exactly one API instance", and the graduation hosting plan must respect it.
- **What a future multi-instance version must add** (recorded future item, not M2):
  1. Either no cache (every request reads the database — correct and immediate, one indexed query), or a distributed cache (e.g. Redis via `IDistributedCache`) with a shared invalidation channel.
  2. On any distributed-cache or invalidation error: bypass the cache and read the database; never fall back to a possibly stale entry.
  3. A `DownloadLinks` table or a distributed store for §5.1.
  4. Distributed rate limiting.

---

## 4. Client storage, cookies and CSRF

### 4.1 Web (the M2 deliverable)
- **Access token:** Dart memory only. It is gone after a page reload; the bootstrap restores it through the refresh endpoint.
- **Refresh token:** cookie `devlink_rt`:
  - `HttpOnly; Secure; SameSite=Strict`;
  - `Path=/api/Auth/session`;
  - `Max-Age` = the remaining idle lifetime;
  - no `Domain` attribute (host-only).
- **Download binding cookie** `devlink_fb`: `HttpOnly; Secure; SameSite=Strict; Path=/api/Files`, `Max-Age` = the session's absolute lifetime (§5.1).
- **Non-secret UI data:** `userId`, `userType`, `email`, `hasProfile` stay in SharedPreferences as a UI cache. They are overwritten from server responses, and the API never trusts them.
- **SharedPreferences never holds any token.**

### 4.2 CSRF protection (unchanged from revision 2)

**Which endpoints receive which cookie:**
- `devlink_rt` (path `/api/Auth/session`) goes only to `POST /api/Auth/session/refresh` and `POST /api/Auth/session/logout`.
- `devlink_fb` (path `/api/Files`) goes only to `GET /api/Files/download` (§5.1).
- No existing endpoint reads any cookie.

**Endpoints that set cookies:** `login`, `google-login`, `signup`, `change-password`, `google-link`, `session/refresh` (and `session/logout`, which deletes them).

**Bearer endpoints** are not CSRF-relevant: browsers never attach an `Authorization` header automatically, and JwtBearer reads *only* that header.

**`[CookieSessionGuard]` checks** on every request that reads or sets the refresh cookie in web mode:
1. **Exact Origin match:** `Origin` must equal an entry in `Cors:AllowedOrigins` after normalization (lowercase scheme and host, explicit port). If absent, the origin of `Referer` must match. Both absent or `Origin: null` → `403 CSRF_FAILED`. `localhost` and `127.0.0.1` are different origins.
2. **Custom header** `X-DevLink-Client: web`, which forces a CORS preflight that fails for unlisted origins. HTML forms can't set it.
3. **`Content-Type: application/json`** (also non-simple). A body of `{}` is enough.
4. **`SameSite=Strict`** cookies.
5. **Fetch metadata:** if `Sec-Fetch-Site` is present, it must be `same-origin` or `same-site`.

The download consumption route is a `GET` that changes nothing except consuming a single-use link; it relies on SameSite=Strict, the link token and the binding cookie (§5.1).

**Why there is no synchronizer token:** checks 1–3 are the OWASP-recommended defence for JSON APIs called by fetch/XHR; a double-submit token would need a script-readable cookie. If a deployment can't guarantee the Origin header, add a double-submit token then.

**Mobile mode** (`X-DevLink-Client: mobile`): no cookies are read or set; the refresh token travels in the JSON body.

**CORS policy `Frontend`:**
- `WithOrigins(Cors:AllowedOrigins)` — exact origins. Startup **refuses** `*`, empty entries, origins without a scheme and, outside Development, non-`https` origins.
- `AllowCredentials()`, `WithHeaders("Authorization", "Content-Type", "X-DevLink-Client")`, `WithMethods("GET", "POST", "PUT", "DELETE")`, `SetPreflightMaxAge(10 min)`.
- No `SetIsOriginAllowed(_ => true)` and no wildcard subdomains. The Origin check is enforced server-side as well.

**Locally (HTTP):**
- Page `http://localhost:5200`, API `http://localhost:5133`: different origins, same site, so `SameSite=Strict` cookies flow. Chrome, Edge and Firefox accept `Secure` cookies on `http://localhost`.
- Requirements: fixed web port 5200; `ApiConfig.baseUrl` stays `localhost`; `Cors:AllowedOrigins = ["http://localhost:5200"]` in Development. Chrome or Edge is the supported development browser.

**Production (HTTPS):** the web app and API must be same-site:
- one origin behind a reverse proxy (strongest; CORS not needed), or
- sibling subdomains of one registrable domain.

Not two hosts under a public-suffix domain such as `*.azurewebsites.net`. HSTS and HTTPS redirection on.

### 4.3 Response hardening
- `X-Content-Type-Options: nosniff` and `Referrer-Policy: no-referrer` on all API responses.
- `Cache-Control: no-store` on all `/api/Auth/*` responses, on download-link issuance and download responses, and on responses with private data.
- `X-Frame-Options: DENY`.
- A Content-Security-Policy for the Flutter host page is a deployment item, since `flutter run` serves its own page.

### 4.4 Mobile (deferred — Q2)
- Web is the M2 target. **No mobile storage package is added.** A mobile build keeps the refresh token **in memory only**; the user signs in again after each app restart.
- **SharedPreferences is never used for refresh tokens.**
- Mobile uses `X-DevLink-Client: mobile`, receives `refreshToken` in the body, and downloads private files with its Bearer token (§5.1).
- If Android becomes a graduation deliverable, `flutter_secure_storage` (Keystore-backed) is the recommendation, recorded in the decision log with its reason before it is added.

---

## 5. Private files and images

### 5.1 CV and certificate download links (clarification D)

**Routes:**
- **Issue:** `POST /api/ProgrammerProfile/{userId}/cv/link` and `/certificate/link` — Bearer, same authorization as #27 (§8).
- **Consume:** `GET /api/Files/download?t=<token>` — a new, separate route, so the binding cookie's path covers nothing else.
- **Direct:** `GET /api/ProgrammerProfile/{userId}/cv` and `/certificate` (#27, #28) — Bearer only. Used by mobile and tests. A web fallback is noted below.

**Issue flow:**
1. The signed-in client calls the issue route with its Bearer token.
2. The server checks authorization: Self, Admin, or a Customer whose post this programmer applied to. User and session must be `Active` (suspended users can't).
3. The server loads the file, computes `SHA-256(file bytes)` as its version, and creates the link record.
4. Response: `{ "url": "http://localhost:5133/api/Files/download?t=<token>", "expiresInSeconds": 60 }` with `Cache-Control: no-store`.
5. The client opens it with `launchUrl`, as today.

**Link token and record:**
- **Entropy:** 32 bytes from `RandomNumberGenerator` (256 bits), base64url. Unguessable and meaningless.
- **Storage:** in-memory `DownloadLinkStore` keyed by `SHA-256(token)` — the raw token is not kept. Single-instance only (§3.7).
- **Record:** `{programmerUserId, kind (cv|certificate), contentSha256, recipientUserId, recipientSessionId, issuedAt, expiresAt}`.

**Checks at consumption, all of which must pass** (any failure → the same `410 LINK_EXPIRED` response):
1. **Exists and not used:** the record is removed atomically (`TryRemove`) *before* any other check, so it can be used at most once, even by two parallel requests.
2. **Not expired:** `now < expiresAt`, using the injected `TimeProvider`. Explicitly checked — the code never relies on cache eviction, and the expiry is never taken from the URL.
3. **Bound to the session (family):** `recipientSessionId` is `Active` in `AuthSessions` — a direct database read, not the cache. A link issued before logout, logout-all, reuse revocation, admin revocation or password reset is dead.
4. **Bound to the user:** the recipient user is still `Active` (not suspended or deleted), and the authorization rule from step 2 is re-evaluated *now* (for example, the admin is still an admin).
5. **Bound to the browser:** the request must carry the `devlink_fb` cookie, and its SHA-256 must equal `AuthSessions.DownloadBindingHash` of `recipientSessionId`.
   - The cookie is a random 32-byte value created when a web session starts (login/sign-up/Google login); only its hash is stored. It is `HttpOnly; Secure; SameSite=Strict; Path=/api/Files`.
   - A link copied to another person, browser or device therefore fails even within its 60 seconds.
   - Mobile sessions have no binding cookie and can't consume links; mobile uses the direct Bearer route.
6. **Bound to the resource version:** the current file's `SHA-256` equals `contentSha256`. Replacing or deleting the file kills outstanding links.

**Response:**
- `Cache-Control: no-store, private`, `Pragma: no-cache`, `Expires: 0`;
- `Content-Disposition: attachment; filename="…"` (sanitized ASCII + RFC 5987) — never `inline`, so a stored HTML/SVG "certificate" can't run script;
- `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`;
- `Content-Type`: CV → `application/pdf`; certificate → the stored type only if it is `application/pdf`, `image/png` or `image/jpeg`, else `application/octet-stream`.

**Failure message** for every case (used, expired, revoked, wrong cookie, unknown): "This download link has expired. Please open the file again from DevLink." Identical responses reveal nothing; the app simply requests a new link.

**Abuse limits:** link issuance limited to 20 per user per 10 min and 100 per day (`429`). Each successful download writes `Files.Downloaded` (ids and kind only).

**Keeping tokens out of logs, referrers and analytics:**
- **Application logs:** hosting/routing log levels at `Warning` (§3.2); no HTTP logging middleware; the link token is never logged, not even in `SecurityEvents`.
- **Proxy logs** (deployment): any reverse proxy or host access log must not record the query string of `/api/Files/download` (e.g. nginx logs `$uri` instead of `$request_uri` for that location; host-level HTTP logging off or query-stripped). This is in the deployment checklist. Even if a URL were logged, the token is single-use, expires in 60 s and needs the binding cookie.
- **Referrers:** `Referrer-Policy: no-referrer` on API responses; the attachment response renders no page, so there is no onward request.
- **Analytics:** the token appears only in the API URL, never in a Flutter route or page URL. DevLink has no third-party analytics; any added later must exclude `/api/**`.
- **Browser history:** a single-use, 60-second link in history is harmless.

**Verified in M2.8 (2026-11-05):** `window.open` from the app origin in Chromium sent the cookie and the file downloaded, so the fallback below is not needed.

**To verify early in M2.8:** that `launchUrl` on web (`window.open` in a new tab) sends the `SameSite=Strict` binding cookie. If a browser doesn't send it, the web client switches to the direct Bearer route and saves the bytes with the **existing** `file_saver` dependency (no new package). That fallback needs no URL token at all.

### 5.2 Images (Q15)

**Principle:** only profiles explicitly intended to be public may have anonymously reachable avatars. DevLink has no public (signed-out) profile, feed or search page today, so **no image route stays anonymous**.

| Route | Access in M2 |
|---|---|
| `CustomerProfile/{id}/image` (#21) | Bearer, or a signed member URL |
| `ProgrammerProfile/{id}/image` (#26) | Bearer, or a signed member URL |
| `Posts/user/{id}/avatar` (#46) | Bearer, or a signed member URL |
| `Posts/image/{imageId}` (#45) | Approved posts: signed member URL; pending/rejected: signed 10-minute URL in admin responses only; deleted: 404 |

**Signed member URLs:**
- The API returns ready-made URLs (`avatarUrl`, `images[].url`) in the responses that show the image: feed, comments, profile, search, applications, programmer list, `Auth/me` and the admin pages.
  - Format: `…/avatar?exp=<unix>&sig=<base64url>`, where `sig = HMAC-SHA256(Security:MediaUrlKey, "avatar|{userId}|{exp}")` (or `"postimage|{imageId}|{exp}"`). Verified with a fixed-time comparison.
  - **Who gets them:** only authenticated callers allowed to see the containing record. Owners always get their own.
  - **Lifetime — 10-minute buckets (C5):** `exp = floor(now / 10 min) × 10 min + 20 min`.
    - Every URL issued for the same image within the same 10-minute window is **byte-identical**, so the browser cache and Flutter's `ImageCache` (keyed by URL) are hit. A URL stays valid for 10 to 20 minutes.
    - The same buckets apply to pending post images (admin and owner only).
    - Trade-off: a page left open longer than 20 minutes whose images were evicted from memory shows the existing fallback avatar or placeholder until the data is reloaded (navigating back, or pull to refresh). Accepted.
  - **Never logged:** the `sig` and `exp` query values are covered by the URL-logging prohibition (§3.2). Image requests aren't written to `SecurityEvents`; proxy access logs must drop query strings for `/api/*/image*` and `/api/Posts/user/*/avatar`, as for downloads (§5.1).
  - **Scope:** one image, read-only, multi-use within its validity (`Image.network` may refetch). Not bound to a session — an acceptable trade-off for avatars and approved post images (at most 20 minutes), **not** for private documents (§5.1).
- **Always:** served only if the account is `Active`; content type limited to `image/jpeg|png|webp`; `nosniff`; avatars `Cache-Control: private, max-age=3600`.
- **Future public profiles:** if the product adds an explicit "public profile" setting, an anonymous route may serve only those avatars. That needs a new decision.

**Effect on Flutter:** the 18 call sites that build image URLs themselves (§1) switch to the URL from the API response. The widgets, layout and navigation don't change (partner review, §9). An alternative evaluated in M2.8 is `Image.network(url, headers: {Authorization})` on the existing URLs. The signed-URL approach is preferred because it doesn't depend on the web renderer's header support and keeps tokens out of image requests.

---

## 6. Server-side authentication

### 6.1 Endpoints (existing routes kept; new routes additive)

| Route | Behaviour |
|---|---|
| `POST /api/Auth/login` | Request unchanged. `userType` remains a portal check (mismatch → the same generic 401). The role in the token comes from the database. Order: rate limit → lockout → verify (legacy upgrade kept) → issue session. A **suspended** user signs in normally and gets a restricted session; the response carries `status: "Suspended"`. Response: existing fields + `accessToken`, `accessTokenExpiresAt`, `role`, `status`. **No password policy check at login** (P1) |
| `POST /api/Auth/google-login` | §6.3 |
| `POST /api/Auth/send-code`, `verify-code`, `signup` | §6.2. `signup` issues a session |
| `POST /api/Auth/send-reset-code`, `verify-reset-code`, `reset-password` | §6.2. Reset issues no session |
| `POST /api/Auth/session/refresh` *(new)* | §3.4 |
| `POST /api/Auth/session/logout` *(new)* | Revokes the current session (from the cookie or body token, or `sid` if only a Bearer token is sent). Always 204; deletes the cookies |
| `POST /api/Auth/logout-all` *(new, Auth)* | §3.6 |
| `POST /api/Auth/change-password` *(new, Auth)* | Current password required, P1 policy, §3.6, confirmation email |
| `GET /api/Auth/me` *(new, Auth)* | `{userId, role, email, status, suspendedReason?, hasProfile, hasProgrammerProfile, avatarUrl}` — the trusted source for the Flutter role and status |
| `POST /api/Auth/google-link` *(new, Auth)* | §6.3 |
| `POST /api/Admin/users/{id}/suspend` (body `{reason}`), `/unsuspend`, `/revoke-sessions` *(new, Admin)* | §3.6, §7.4. Not allowed against admin accounts |

**Passwords (P1 + condition C7):**
- `PasswordService.MinLength` default becomes **8** (`Auth:MinPasswordLength`, maximum 128).
- **Common-password blocklist:**
  - A bundled text file (embedded resource `backend/Resources/common-passwords.txt`) — **data, not a package**.
  - Proposed source: SecLists `Passwords/Common-Credentials/10k-most-common.txt` (MIT licence). Its licence text is kept beside it; the exact file, entry count and SHA-256 are recorded in the decision log in M2.5.
  - Loaded once into a case-insensitive `HashSet<string>`.
  - A new password is rejected if it is in the list (case-insensitive, trimmed), or if it equals the account email or its local part.
  - Message: "This password is too common or too easy to guess. Please choose a different one."
- `ValidatePolicy` (length + blocklist) runs on sign-up, reset, change-password and admin create/update — **never at login**.
- `PasswordService.Verify` and the legacy plaintext → PBKDF2 upgrade are unchanged. A legacy account whose password is short or on the blocklist still signs in (T-LG-04, T-PW-07). It is asked to change the password only when it next changes it voluntarily — no forced change in M2.

### 6.2 Verification and reset codes (Q7)

**Table `OneTimeCodes`:**

| Column | Type | Notes |
|---|---|---|
| `Id` | `bigint` identity PK | |
| `Purpose` | `varchar(16)` CHECK `Signup`/`Reset` | |
| `EmailKey` | `binary(32)` | `HMAC-SHA256(CodeHmacKey, "email|" + normalizedEmail)`. The email itself is **not stored** in this table |
| `CodeHash` | `binary(32)` | `HMAC-SHA256(CodeHmacKey, "code|{Purpose}|{EmailKey}|{code}")`. A keyed hash, because a plain SHA-256 of a 6-digit code could be reversed by trying all 10⁶ values |
| `CreatedAt`, `ExpiresAt` | `datetime2` | 10 minutes |
| `FailedAttempts` | `int` | Max 5 |
| `ConsumedAt` | `datetime2` null | Single use |
| `InvalidatedAt` | `datetime2` null | Set when a newer code is requested |
| `ProofTokenHash` | `binary(32)` null | HMAC of the proof token issued on success |
| `ProofExpiresAt`, `ProofConsumedAt` | `datetime2` null | 15 minutes, single use |

Index `(EmailKey, Purpose, CreatedAt)`.

| Control | Design |
|---|---|
| Generation | `RandomNumberGenerator.GetInt32(0, 1_000_000)`, formatted as 6 digits |
| Key | `Security:CodeHmacKey`, ≥ 32 bytes, user-secrets/environment (§3.2) |
| New request | Marks earlier rows for the same email and purpose `InvalidatedAt = now`, which also kills their proof tokens |
| Attempts | Atomic: `UPDATE … SET FailedAttempts = FailedAttempts + 1 WHERE Id = @id AND ConsumedAt IS NULL AND InvalidatedAt IS NULL AND FailedAttempts < 5 AND ExpiresAt > @now`. The 5th failure destroys the code. HMACs compared with `CryptographicOperations.FixedTimeEquals` |
| Success | `UPDATE … SET ConsumedAt = @now, ProofTokenHash = @h, ProofExpiresAt = @now + 15 min WHERE Id = @id AND ConsumedAt IS NULL` must affect exactly 1 row. Returns `signupToken` or `resetToken` (32 random bytes). `signup` and `reset-password` require it and consume it the same way (closes G10) |
| Unknown emails | A reset request for an unknown email (or a sign-up request for a registered one) stores a row with the hash of a random code that is never sent. Wrong-code and attempt behaviour is therefore identical for every email |
| Aggregate verification limit (C6) | Applies to **all codes together**, across both purposes:<br>• **Per normalized email:** at most **10 failed verification attempts per rolling hour**. Counted as `SUM(FailedAttempts)` over the email's `OneTimeCodes` rows created in the last 70 minutes. A code is only verifiable for 10 minutes after creation, so every failure in the last hour belongs to such a row. The count is conservative (it may include failures up to 70 minutes old), never lenient.<br>• **Per IP:** at most **20 failed verification attempts per rolling hour** (sliding-window limiter, 6 × 10-minute segments, in memory, single instance §3.7), in addition to the 30 verify requests per 15 minutes.<br>• Exceeding either → 429 `RATE_LIMITED`, "Too many attempts. Please wait N minutes and try again." The same behaviour applies to unknown emails (their decoy rows count the same way).<br>• Accepted trade-off: someone who knows an email can block verification for that email for up to an hour. They can't take over the account, and login with an existing password is unaffected |
| Rate limits | Per normalized email, counted from `OneTimeCodes` rows: 1 request per 60 s, 5 per hour. Per IP (ASP.NET Core `RateLimiter`, no new package, in memory): `send-*` 10/hour; `verify-*` 30/15 min; `login` 10/min; `signup` + `reset-password` 10/hour; `google-login` 20/min. Exceeding → 429 `RATE_LIMITED` + `Retry-After` |
| Login lockout | 5 failed logins per email in 15 min → locked 15 min (`Users.FailedLoginCount`/`LockoutEndAt`; an in-memory counter for unknown emails, so the behaviour is identical) |
| Timing | Emails go through an in-process background queue, so response time doesn't reveal whether an email was sent |
| After a reset | New hash, stamp rotated, all sessions revoked, lockout cleared, "Your password was changed" email |
| Cleanup | Rows deleted 24 h after expiry |
| Proxy note | Behind a reverse proxy, the IP partition needs `ForwardedHeaders` with explicit `KnownProxies`; disabled locally |

**User-facing wording (Q6):**

| Step | Message shown in the app | What actually happens |
|---|---|---|
| Sign-up: request code | "If this email can be used for a new DevLink account, we've sent a 6-digit code to it. Check your inbox and spam folder — the code expires in 10 minutes." | New email → code sent. Registered → no code; that inbox gets "Someone tried to create a DevLink account with this email. If it was you, sign in or reset your password." |
| Reset: request code | "If an account exists for this email, we've sent a 6-digit reset code. It expires in 10 minutes." | Registered → code sent. Unknown → nothing sent |
| Wrong or expired code | "That code is incorrect or has expired. Check the latest email or request a new code." | Same for every case |
| 5 wrong attempts | "Too many incorrect attempts. Please request a new code." | Same for every email |
| Too many requests | "Too many requests. Please wait N minutes and try again." | 429 |
| Login failure | "Email or password is incorrect." | Same for unknown email, wrong password and wrong portal |
| Locked | "Too many failed sign-in attempts. Try again in 15 minutes or reset your password." | Same for any email |

The current messages "This email is already registered" / "This email is not registered" disappear — a partner-visible text change (§9).

### 6.3 Google Sign-In and account linking (Q11, Q13)
- **Implemented in M2.9 (2026-11-10)** with Microsoft.IdentityModel and Google's OpenID metadata instead of `GoogleJsonWebSignature`, so the same checks run against keys the tests control. Linking also requires the current password (see the decision log).
- **Validation:** `GoogleJsonWebSignature.ValidateAsync` checks signature, `iss`, `exp`, and `Audience` = `Google:ClientIds`. The server also requires `email_verified == true` and a non-empty `sub`. Failures → 401, logged without the token. `IGoogleTokenValidator` allows a test fake.
- **Matching is by `GoogleSubject` only:**
  1. Subject known → sign in as that user (normal lockout checks; suspended → restricted session).
  2. Subject unknown, email belongs to an existing account → **409 `ACCOUNT_LINK_REQUIRED`**, no session. Message: "An account with this email already exists. Sign in with your password, then connect Google from your account. Forgot your password? Reset it first."
  3. Subject unknown, new email, `mode = signup` → create a Customer or Programmer account (Admin never), store the subject, issue a session.
  4. Subject unknown, new email, `mode = login` → 400 `requiresSignUp` (as today).
- **Explicit linking** `POST /api/Auth/google-link {idToken, currentPassword}` requires all of: a password-based current session; a correct `currentPassword`; a valid token with `email_verified`; token email = account email; subject not linked elsewhere. Then: store the subject, rotate the stamp, revoke other sessions, send a "Google sign-in was connected" email.
- **Pre-M2 Google-created accounts:** reset password → sign in → `google-link`.
- **Admin (Q13):** Google sign-in and linking are disabled for Admin in M2 (`403 FORBIDDEN`, "Admins sign in with email and password"). Changing this needs a separately reviewed policy.

### 6.4 Security audit log (Q8)

**Table `SecurityEvents`** (append-only from the application):

| Column | Type | Notes |
|---|---|---|
| `Id` | `bigint` identity PK | |
| `OccurredAt` | `datetime2` | Indexed |
| `EventType` | `varchar(64)` | From a fixed list (below) |
| `Outcome` | `varchar(16)` | `Success`/`Failure`/`Blocked` |
| `UserId` | `int` null | Subject account; no FK, so events survive account deletion |
| `ActorUserId` | `int` null | The admin, for admin actions |
| `SessionId` | `uniqueidentifier` null | |
| `TargetType`, `TargetId` | `varchar(32)`, `varchar(64)` null | e.g. `ProgrammerProfile`, `42` |
| `EmailKey` | `char(12)` null | First 12 hex characters of `SHA-256(logSalt + normalizedEmail)` for unknown-email correlation; never the email |
| `IpPrefix` | `varchar(49)` null | **Truncated** network prefix only (IPv4 /24, IPv6 /48), recorded **only** for abuse-relevant events: `Auth.LoginFailed`, `Auth.LockedOut`, `Auth.RateLimited`, `Auth.CsrfRejected`, `Auth.CodeAttemptsExceeded`, `Auth.RefreshTokenReuse`. Null for every other event. Set to null after **14 days** (`Security:IpRetentionDays`, R3) |
| `ClientType` | `varchar(16)` null | |
| `TraceId` | `varchar(64)` null | |
| `Details` | `nvarchar(1000)` null | JSON built only from a typed allowlist of fields (e.g. `reason`, `route`, `kind`, `rotatedAgoSeconds`) — never free text from requests |

**Events:**
- `Auth.LoginSucceeded`, `Auth.LoginFailed{reason}`, `Auth.LockedOut`;
- `Auth.RefreshTokenReuse`, `Auth.EndedSessionTokenPresented`, `Auth.Logout`, `Auth.LogoutAll`;
- `Auth.PasswordChanged`, `Auth.PasswordReset`;
- `Auth.CodeRequested`, `Auth.CodeAttemptsExceeded`, `Auth.RateLimited`;
- `Auth.GoogleLogin`, `Auth.GoogleLinkRequired`, `Auth.GoogleLinked`;
- `Auth.CsrfRejected`, `Authz.Forbidden{route, policy}`, `Authz.SuspendedBlocked{route}`;
- `Files.LinkIssued`, `Files.Downloaded`, `Files.LinkRejected`;
- `Admin.UserSuspended`, `Admin.UserUnsuspended`, `Admin.SessionsRevoked`, `Admin.UserUpdated`, `Admin.UserDeleted`, `Admin.ProgrammerVerified`, `Admin.ProgrammerUnverified`.

**How it's written:**
- **Transactional** for events that accompany a security state change (reuse, suspension, unsuspension, password change/reset, role change, revoke-sessions, Google linking, verification decisions). The event is inserted in the same transaction, so the change and its record commit or fail together.
- **Asynchronous** for high-volume events (login failures, rate-limit hits, CSRF rejections, `Authz.Forbidden`, downloads). A bounded in-process channel (10 000 entries) feeds a background writer. If the channel is full or the database write fails, the event is dropped, counted and logged as a structured Warning; the request is never blocked or failed.
- Every event is also written to the structured log (`DevLink.Security`).
- `SecurityEventWriter` exposes typed methods only, so no caller can pass a token, code or password.

**Never recorded:** passwords, raw or hashed tokens, verification codes, proof tokens, link tokens, binding-cookie values, keys, connection strings, full emails, request bodies.

**IP minimization (R3, owner 2026-11-03):**
- Full IP addresses are **never persisted**. The per-IP rate limiter holds them in memory only, for the length of its window.
- Structured logs don't include the IP. Only `SecurityEvents.IpPrefix` does, for the six events listed, and the prefix is nulled after 14 days.
- No session row stores an IP (Q9).

**Access and retention:**
- No API or UI in M2; the table is never exposed through any endpoint. Only maintainers with direct database access can read it.
- Any future admin view of `IpPrefix` needs a new decision.
- Event rows without IP data are deleted after 90 days by the cleanup service.

### 6.5 Refresh-token reuse alert (Q12)
- After a reuse revocation commits, an alert is queued on the background email queue. It never delays or affects the revocation.
- **Rate limit:** at most one alert per session family per hour (owner rule 2026-11-04), and at most 3 per user per 24 h (counted from `SecurityEvents`, event `Auth.ReuseAlertQueued`). Extra detections are still audited, just not emailed.
- **Content (generic, no sensitive details):**
  > Subject: Security notice for your DevLink account
  > We signed you out of one DevLink session because of unusual activity with your sign-in. If you recently signed in on another device or had a connection problem, you can ignore this message. Otherwise, sign in and change your password.
  - No IP, location, device, time detail, token or link.
- Development: the M1 console email sink. A failed send is logged and audited as `Outcome = Failure`; it isn't retried more than 3 times.

---

## 7. Authorization model

### 7.1 Policies
- The **fallback policy** requires an authenticated user with an active session **and** `Status = Active`. Every endpoint is protected unless it is explicitly `[AllowAnonymous]`, and suspended users are blocked unless it is `[AllowSuspended]` (§7.4). A forgotten attribute fails closed.
- Named policies: `AdminOnly`, `CustomerOnly`, `ProgrammerOnly`, `NonAdmin` (Customer or Programmer).
- **Ownership** is checked in code through `ICurrentUser` (`UserId`, `Role`, `IsAdmin`, `Status`, `RequireSelfOrAdmin(routeUserId)`). A wrong owner gets **403 `FORBIDDEN`**; a non-existent resource still gets 404.

### 7.2 Client-supplied identity fields
- `UserId`, `ProgrammerId`, `currentUserId`, `requesterId` and the `userId` query stay in DTOs for compatibility but are **ignored when enforcement is on**; the server uses `sub`.
- `isAdmin` is always ignored.
- Route `{userId}` segments are authorization targets, checked against the caller (§8).

### 7.3 `Auth:EnforceAuthorization` migration switch (Q1)
- **Default:** `true`; a missing setting means `true`.
- **When `false`:** requests *without* a token fall back to today's behaviour so the unmodified Flutter app keeps working until M2.12. Requests *with* a valid token are fully enforced. **Fallback scope (sequencing fix 2, approved 2026-11-03)** — exactly these, nothing else:
  1. Identity from client-supplied ids — centralized in `ICurrentUser.ResolveUserId(clientSuppliedId)`.
  2. `signup` and `reset-password` accepted **without** a proof token if the email passed `verify-code`/`verify-reset-code` within the last 15 minutes (today's flow), so the current sign-up and reset screens keep working after M2.5. Codes are still hardened (DB-stored hashes, 5 attempts, rate limits).
  3. `GET ProgrammerProfile/{userId}/cv` and `/certificate` without a Bearer token (today's direct `launchUrl` URLs), since M2.7d.
  4. Image routes without a signature (today's client-built URLs) after M2.8.
  5. *(owner decision D-1, 2026-11-04)* Tokenless requests to role-protected routes that carry no client id (admin, moderation, support inbox, and the member reads of M2.7d), so the unchanged screens keep working until M2.12. Case `TokenlessRequest`. Same safeguards; never when an `Authorization` header is present, and never on routes with a strict policy (`suspend`, `unsuspend`).

  Each fallback path is behind one `LegacyFallback` check. Each is covered by a T-SW test proving it is **unreachable** when the switch is on or the environment isn't Development. All of them are deleted in M2.13.
- **Safeguards (binding condition C1).** A fallback path runs only when **all three** hold, evaluated per request:
  - (a) `IHostEnvironment.EnvironmentName == "Development"`;
  - (b) **explicitly enabled** — `Auth:EnforceAuthorization` is present and exactly `false`. A missing, empty or unparsable value means enforced, so the fallback is **off by default**;
  - (c) the request's `HttpContext.Connection.RemoteIpAddress` is loopback (`127.0.0.1`, `::1`). Forwarded headers are never consulted in this check.

  Otherwise the request is fully enforced.
  1. **Startup refusal:** the host throws during startup if the switch is explicitly `false` and the environment isn't Development (Production, Staging, Testing or any custom name).
  2. **Binding check:** if enabled, every bound address must be loopback; otherwise the application stops itself with a critical log.
  3. **Per-request loopback check** (c): a non-loopback request while enabled is enforced normally, plus a Warning.
  4. **Warning on every fallback use:** event `Auth.DevFallbackUsed` (Warning) with **only** the fallback case (`IdentityFromClient`, `TokenlessRequest`, `SignupResetWithoutProof`, `FileWithoutToken`, `ImageWithoutSignature`) and the route *template* (e.g. `api/Posts/{id}/like`). No user ids, emails, IPs, tokens or query strings. Also a startup Warning, a reminder every 10 minutes, and `X-DevLink-Auth: NOT-ENFORCED` on every response.
  5. **Tests:**
     - T-SW-01…05 (startup refusal per environment; binding check; missing key = enforced);
     - **T-SW-06…09**: one per fallback case, proving it is **off by default** (no key → 401/400/403), off with the key on a non-Development host (startup fails), and off for a non-loopback remote address;
     - **T-SW-10**: each case logs `Auth.DevFallbackUsed` with no personal data or token value (captured-log scan).
  6. **Removal:** the switch, all four fallback paths, `Auth.DevFallbackUsed` and the header are **deleted in M2.13**. **T-SW-R** then proves the paths are gone:
     - with `Auth:EnforceAuthorization=false` in Development on loopback, all four cases are enforced;
     - a source-level test asserts that the `LegacyFallback` type no longer exists.

### 7.4 Suspended accounts — restricted mode (Q5)
- `Users.Status` = `Active` or `Suspended`; `SuspendedReason nvarchar(500)` (written by the admin, shown to the user); `SuspendedAt`.
- A suspended user can sign in (password or Google) and refresh. Every endpoint not marked `[AllowSuspended]` returns **403 `ACCOUNT_SUSPENDED`** with the message "Your account is suspended. You can contact support or sign out." and writes `Authz.SuspendedBlocked`.
- **`[AllowSuspended]` allowlist:**
  - `Auth/me` (status and reason for the notice), `Auth/session/refresh`, `Auth/session/logout`, `Auth/logout-all`, `Auth/change-password`;
  - `POST Support` (#59), `GET Support/{id}` own (#61), `GET Support/my/{userId}` (#65), `GET Support/my/{userId}/unread-count` (#66), `POST Support/{id}/mark-reply-read` (#67).
- Not allowed: feed, posts, likes, comments, applications, profiles, files, notifications, weather, search, download links.
- **Flutter:** after sign-in or on any `403 ACCOUNT_SUSPENDED`, the app shows a new suspension notice screen with the reason, a "Contact support" button (the existing `ContactSupportPage`, subject prefilled "Account suspension appeal"), the user's support conversations and "Sign out". Programmers reach support through this screen (decision R5 covers a regular entry point).
- Admins can't be suspended (M1 rule). Suspension is audited transactionally.
- This replaces the revision 2 "full block" and deliberately differs from spec BR-02's "read-only" wording (recorded in the decision log).

---

## 8. Complete endpoint authorization matrix (67 endpoints)

**Legend:**
- **Access:** Anon = no sign-in; Auth = signed-in user with an active session; **Signed** = a signed member URL or Bearer (§5.2); **(S)** = also allowed for suspended users (§7.4).
- **Roles:** C = Customer, P = Programmer, A = Admin.
- **Ownership:** Self = route user is the caller; Owner = the caller owns the resource.
- **Personal data:** R = reads it, W = modifies it, — = none.
- "From token" means client-sent ids are ignored.

### 8.1 Matrix

**AuthController — `/api/Auth`**
| # | Method & route | Access | Roles | Ownership | Personal data | Reason |
|---|---|---|---|---|---|---|
| 1 | POST `login` | Anon | — | own credentials | R/W own (lockout, rehash) | Entry point; rate limit, lockout, generic errors |
| 2 | POST `google-login` | Anon | — | Google subject | R/W own | Entry point; §6.3 |
| 3 | POST `send-code` | Anon | — | — | W (code row, no email stored) | Sign-up starts signed out; generic response, limits |
| 4 | POST `verify-code` | Anon | — | email + code | — | 5 attempts |
| 5 | POST `signup` | Anon | C/P created | proof token | W (new account) | Requires `signupToken` |
| 6 | POST `send-reset-code` | Anon | — | — | W (code row) | Recovery is for signed-out users; generic response |
| 7 | POST `verify-reset-code` | Anon | — | email + code | — | 5 attempts |
| 8 | POST `reset-password` | Anon | — | proof token | W own | Requires `resetToken`; revokes all sessions |

**AdminController — `/api/Admin`** (whole controller `AdminOnly`)
| # | Method & route | Access | Roles | Ownership | Personal data | Reason |
|---|---|---|---|---|---|---|
| 9 | GET `users` | Auth | A | — | R (all emails) | User management |
| 10 | GET `users/{id}` | Auth | A | — | R | Same |
| 11 | POST `users` | Auth | A | — | W | `UserType=Admin` → 403 (seed-admin only, Q10); P1 policy |
| 12 | PUT `users/{id}` | Auth | A | target not an admin (M1) | W | Revokes the target's sessions on role/password/email change |
| 13 | DELETE `users/{id}` | Auth | A | target not an admin (M1) | W | Same |
| 14 | GET `programmers` | Auth | A | — | R (emails, document metadata) | Verification queue |
| 15 | POST `programmers/{userId}/verify` | Auth | A | — | W | Verification decision (audited) |
| 16 | POST `programmers/{userId}/unverify` | Auth | A | — | W | Same |
| 17 | GET `statistics` | Auth | A | — | — (aggregates) | Admin dashboard |

**CustomerProfileController — `/api/CustomerProfile`**
| # | Method & route | Access | Roles | Ownership | Personal data | Reason |
|---|---|---|---|---|---|---|
| 18 | GET `{userId}` | Auth | C (self), A | Self or Admin | R (phone, city) | Only the customer's own dashboard calls it |
| 19 | POST (create) | Auth | C | Self (from token) | W | Profile setup |
| 20 | PUT `{userId}` | Auth | C | Self | W | Own profile only |
| 21 | GET `{userId}/image` | **Signed** | any member shown the record | — | R (photo) | Q15: not public; §5.2 |

**ProgrammerProfileController — `/api/ProgrammerProfile`**
| # | Method & route | Access | Roles | Ownership | Personal data | Reason |
|---|---|---|---|---|---|---|
| 22 | GET `{userId}` | Auth | any | Self/Admin → full; others → member projection (no phone, no file names) | R | Own dashboard; others get the member view |
| 23 | GET `all` | Auth | any | — | R member fields only | Programmer discovery among members |
| 24 | POST (create) | Auth | P | Self (from token) | W | Profile setup |
| 25 | PUT `{userId}` | Auth | P | Self | W | Own profile; a certificate in the form resets verification (Q14) |
| 26 | GET `{userId}/image` | **Signed** | any member shown the record | — | R (photo) | Q15; §5.2 |
| 27 | GET `{userId}/cv` | Auth (Bearer only) | P self, A, C with a post this programmer applied to | as listed | R (CV) | Private document; web uses links (§5.1) |
| 28 | GET `{userId}/certificate` | Same as 27 | Same | Same | R | Same |
| 29 | POST `{userId}/cv` | Auth | P | Self | W | Own documents; kills outstanding links |
| 30 | DELETE `{userId}/cv` | Auth | P | Self | W | Same |
| 31 | POST `{userId}/certificate` | Auth | P | Self | W | Q14: resets verification to Pending (existing behaviour, tested) |
| 32 | DELETE `{userId}/certificate` | Auth | P | Self | W | Same |
| 33 | POST `{userId}/verify` | Auth | **A** | — | W | Closes self-verification (G8); kept for route compatibility |
| 34 | POST `{userId}/unverify` | Auth | **A** | — | W | Same |

**NotificationsController — `/api/Notifications`**
| # | Method & route | Access | Roles | Ownership | Personal data | Reason |
|---|---|---|---|---|---|---|
| 35 | GET `{userId}` | Auth | any | Self | R | KI-27. N1: new optional `limit` (default 5, max 50) and `before` (id cursor); the response stays a JSON array, so the bell is unchanged **M2.10:** also `page` + `pageSize` (owner decision 2026-11-10; mixing styles → 400), and `GET {userId}/unread-count` (Self). |
| 36 | POST `{id}/read` | Auth | any | Owner of the notification | W | KI-27 |

**PostsController — `/api/Posts`** (feed behaviour unchanged; only the identity source and image URLs change)
| # | Method & route | Access | Roles | Ownership | Personal data | Reason |
|---|---|---|---|---|---|---|
| 37 | GET `feed` | Auth | any | `userId` → from token | R (author names, signed avatar URLs) | Feed is for members |
| 38 | GET `user/{userId}` | Auth | any | `currentUserId` → from token | R (public post data) | Same |
| 39 | POST (create) | Auth | C, P (admins can't post, as today) | from token | W | Posting |
| 40 | DELETE `{id}` | Auth | any | Owner, or A | W | G3 fixed: `isAdmin` ignored |
| 41 | POST `{id}/like` | Auth | any | from token | W | Social action (approved posts only) |
| 42 | GET `{id}/comments` | Auth | any | — (approved posts; A/owner for others) | R (names) | Members only |
| 43 | POST `{id}/comments` | Auth | any | from token | W | Social action (approved posts only) |
| 44 | DELETE `comments/{commentId}` | Auth | any | Comment author, post owner, or A *(owner rule 2026-11-04, M2.7b)* | W | G3 fixed |
| 45 | GET `image/{imageId}` | **Signed** | members (approved posts); A and post owner (others, 10-minute URL) | — | — (post content) | Q15 consistency; §5.2 |
| 46 | GET `user/{userId}/avatar` | **Signed** | any member shown the record | — | R (photo) | Q15; §5.2 |
| 47 | GET `search` | Auth | any | — | R; email returned and searchable **only for A** (Q3) | Discovery without exposing emails |
| 48 | GET `profile/{userId}` | Auth | any | email + phone only for Self or A (Q3) | R | Member profile |
| 49 | POST `{id}/apply` | Auth | P | `ProgrammerId` → from token | W | Applying; approved customer-owned posts only (D-11) |
| 50 | GET `{id}/applications` | Auth | C (post owner), A | Post owner or A | R; applicant email shown to the owner **only** if the application is accepted **and** the programmer consented (Q16); A sees it. *D-10: until M2.12 Admin gets 403 on this route* | Owner reviews applicants |
| 51 | POST `{id}/applications/{applicationId}/accept` | Auth | C | Post owner | W | Owner decision |
| 52 | GET `{id}/applications/count` | Auth | any | — | — | Counter |
| 53 | GET `{id}/has-applied` | Auth | any | answers for the caller | — | `userId` → from token |
| 54 | GET `pending` | Auth | A | — | R | Moderation queue (G4); returns 10-minute image URLs |
| 55 | POST `{id}/approve` | Auth | A | — | W | Moderation |
| 56 | POST `{id}/reject` | Auth | A | — | W | Moderation |
| 57 | GET `weather/{userId}` | Auth | any | Self only *(owner rule 2026-11-04, M2.7c; was Self or A)* | R (city) | The city is personal (KI-29); no `ex.Message` in errors |
| 58 | GET `weather-location` | Auth | any | — | — (coordinates from the caller) | No anonymous proxy to Open-Meteo/Nominatim |

**SupportController — `/api/Support`**
| # | Method & route | Access | Roles | Ownership | Personal data | Reason |
|---|---|---|---|---|---|---|
| 59 | POST (send) | Auth **(S)** | C, P (A → 403) | `UserId`, name and email from the account | W | Q4; suspension appeals; rate limit 5/hour, 20/day |
| 60 | GET `all` | Auth | A | — | R (names, emails, messages) | Support inbox |
| 61 | GET `{id}` | Auth **(S)** | A, or the message owner | Owner or A | R | Conversation |
| 62 | POST `{id}/reply` | Auth | A | — | W | Admin reply |
| 63 | POST `{id}/read` | Auth | A | — | W | Admin status |
| 64 | DELETE `{id}` | Auth | A | — | W | Admin action |
| 65 | GET `my/{userId}` | Auth **(S)** | C, P | Self | R | Own conversations |
| 66 | GET `my/{userId}/unread-count` | Auth **(S)** | C, P | Self | — | Own counter |
| 67 | POST `{id}/mark-reply-read` | Auth **(S)** | C, P | Owner of the message | W | Own read state |

**New routes (additive):**

| Route | Access | Roles / rule |
|---|---|---|
| `POST Auth/session/refresh`, `POST Auth/session/logout` | Refresh cookie (web) or body token (mobile) + `[CookieSessionGuard]`; **(S)** | Holder of a valid refresh token |
| `POST Auth/logout-all`, `POST Auth/change-password`, `GET Auth/me` | Auth **(S)** | Self |
| `POST Auth/google-link` | Auth | C, P (self) |
| `POST ProgrammerProfile/{userId}/cv/link`, `/certificate/link` | Auth | Rule of #27 |
| `GET Files/download?t=` | Link token + binding cookie (§5.1); no Bearer | The recorded recipient |
| `PUT Posts/{id}/applications/{applicationId}/contact-consent` `{consent: bool}` | Auth | P, owner of the application (Q16) |
| `POST Admin/users/{id}/suspend`, `/unsuspend`, `/revoke-sessions` | Auth | A; target not an admin |

**Totals:** of the 67 existing endpoints, **8 anonymous** (the sign-in, sign-up and reset flows #1–#8), **4 signed-URL image routes** (#21, #26, #45, #46), and **55 Bearer-authenticated**. CVs, certificates, phone numbers, emails, support conversations and notifications are **never anonymous**.

### 8.2 Review of the previously proposed public endpoints

| # | Endpoint | Decision | Justification and controls |
|---|---|---|---|
| 1 | `login` | Anonymous | Must be, to sign in. Rate limit 10/min/IP, lockout, generic errors |
| 2 | `google-login` | Anonymous | Must be. Server-side token validation, `email_verified`, no auto-link, Admin excluded, rate limit |
| 3 | `send-code` | Anonymous | Sign-up happens before an account exists. Generic response, per-IP and per-email limits, queued email |
| 4 | `verify-code` | Anonymous | Same. 5 attempts per code, keyed hash + fixed-time compare, IP limit |
| 5 | `signup` | Anonymous | Same. Single-use proof token; P1 policy |
| 6 | `send-reset-code` | Anonymous | A user who forgot their password is signed out. Generic response, limits |
| 7 | `verify-reset-code` | Anonymous | Same controls as #4 |
| 8 | `reset-password` | Anonymous | Single-use proof token bound to the email; revokes all sessions |
| 21 | `CustomerProfile/{userId}/image` | **No longer anonymous** (Q15) | No profile is intended to be public to signed-out visitors; user ids are sequential, so an anonymous route would let anyone enumerate photos. Signed member URLs |
| 26 | `ProgrammerProfile/{userId}/image` | **No longer anonymous** (Q15) | Programmer profiles are discoverable to members only (#23 is Auth). Same |
| 45 | `Posts/image/{imageId}` | **No longer anonymous** | The feed is members-only (#37), so approved post images are member content; sequential ids are enumerable. Signed member URLs; pending posts 10-minute URLs for admins and the owner |
| 46 | `Posts/user/{userId}/avatar` | **No longer anonymous** (Q15) | Same data as #21/#26 through a third route |
| 59 | `POST /api/Support` | **Auth (C, P), allowed while suspended** (Q4, Q5) | No signed-out entry point exists. Name and email come from the account. 5 per hour, 20 per day; subject ≤ 200 and message ≤ 5 000 characters; admins can delete |

**Consistency with the UI and roles (Q4):**
- The support form is reachable today only from the signed-in customer home (`customer_home_page.dart:222`).
- Programmers are allowed by the API; they reach the form through the suspension notice screen (§7.4). A regular programmer entry point is partner decision **R5**.
- Admins answer tickets (#60–#64) and can't submit them.

---

## 9. Flutter integration — files requiring partner review

The architecture stays: `Navigator` + `http` + `SessionManager`. Existing routes, the feed, weather and notification UI keep their layout and behaviour. **No Flutter file has been changed, and none will be merged without your partner's review.** Changes are implemented on the branch only in M2.12, after the backend is ready.

| # | File (screen) | Change | Why the partner must review |
|---|---|---|---|
| F1 | **new** `lib/services/auth_http.dart` | `AuthHttp.get/post/put/delete/send` with `package:http` signatures; Bearer header; single-flight refresh; retry once on `TOKEN_EXPIRED`; `endSession` on other 401s; navigates to the suspension screen on `ACCOUNT_SUSPENDED` | Central behaviour |
| F2 | **new** `lib/services/http/credentialed_client_web.dart` + `_io.dart` (conditional import) | `BrowserClient()..withCredentials = true` for the session endpoints only | No new dependency |
| F3 | **new** `lib/services/http/refresh_lock_web.dart` + `_io.dart` | Web Locks wrapper (`package:web`); feature detection; 15 s timeout | Cross-tab behaviour (§3.5) |
| F4 | `lib/services/session_manager.dart` | Access token in memory; `saveSession(...)` from server responses; `endSession(reason)`; existing getters keep their names | Login state |
| F5 | `lib/main.dart` | `navigatorKey`; `home:` → a small bootstrap widget: browser check → spinner → `session/refresh` → existing home page for the **server** role, the suspension screen, or `WelcomePage` | **App start / navigation** |
| F6 | `lib/pages/Common/welcome_page.dart` | Unsupported-browser message and disabled sign-in buttons (§3.5) — only shown when Web Locks is missing | **Welcome screen** (text only) |
| F7 | `lib/pages/Common/login_page.dart` | Replace the direct `http.post` (line 192) with `ApiService.login`; navigate by the server role; new messages (generic login, 429, locked, suspended, Google 409) | **Login screen** |
| F8 | `lib/pages/Common/signup_page.dart`, `verify_code_page.dart`, `set_password_page.dart` | Generic "code sent" text; carry `signupToken`; save the session from the sign-up response; 8-character hint | **Sign-up flow** |
| F9 | `lib/pages/Common/forgot_password_page.dart`, `reset_verify_page.dart`, `reset_password_page.dart` | Generic texts; carry `resetToken`; 8-character minimum | **Reset flow** |
| F10 | `admin/admin_dashboard_page.dart:75`, `Customer/customer_home_page.dart:174`, `Customer/dashboard_placeholder_page.dart:84`, `Programmer/programmer_dashboard_page.dart:104` | `_logout` → `await ApiService.logout()` before the existing navigation | **Logout buttons** |
| F11 | **new** `lib/pages/Common/account_suspended_page.dart` | Suspension notice: reason, "Contact support" (existing `ContactSupportPage`, prefilled subject), own conversations (existing `CustomerSupportMessagesPage`), "Sign out" | **New screen** (Q5) |
| F12 | `lib/services/api_service.dart` | `http.` → `AuthHttp.`; new `login/refresh/logout/logoutAll/me/changePassword/getCvLink/getCertificateLink`; proof tokens; `getProfileImageUrl`/`getProgrammerImageUrl` replaced by server URLs | Services |
| F13 | `lib/services/post_service.dart`, `support_service.dart`, `notification_service.dart`, `weather_service.dart` | Mechanical `http.` → `AuthHttp.`; ids still sent (ignored); `isAdmin` no longer sent; `getUserAvatarUrl`/`getPostImageUrl` replaced by server URLs. Notifications: same call, default 5 | Services (feed, weather, notification UI unchanged) |
| F14 | `lib/models/post_model.dart` (+ comment/notification/profile models as needed) | Read `avatarUrl` and `images[].url` from the API | Data models |
| F15 | Image call sites: `widgets/post_card.dart:543, 633`, `widgets/comments_sheet.dart:358`, `customer_home_page.dart:441, 586, 962`, `create_post_page.dart:340`, `user_profile_page.dart:354, 438`, `post_applications_page.dart:286`, `search_users_page.dart:245`, `admin/admin_posts_page.dart:436, 485`, `admin/admin_verification_details_page.dart:382`, `admin/admin_verifications_page.dart:587`, `Programmer/programmer_dashboard_page.dart:748`, `Customer/dashboard_placeholder_page.dart:402` | Use the URL from the model instead of building one. **Same widgets and layout** | **Feed, comments, profiles, admin pages** — the URL source only |
| F16 | `admin/admin_verification_details_page.dart:45`, `Programmer/programmer_dashboard_page.dart:117` | Request a download link, then `launchUrl` (fallback: Bearer download + existing `file_saver`) | Document opening |
| F17 | `Customer/user_profile_page.dart:474`, `search_users_page.dart:277`, `post_applications_page.dart` | Handle a missing `email`/phone (Q3, Q16). The models already read `email` null-safely (`?? ''`), so nothing crashes before this change | Profile, search and applicants UI |
| F18 | `Common/set_password_page.dart:405`, `Common/reset_password_page.dart:362`, `admin/admin_user_form_page.dart:472, 480` | Client-side minimum 6 → 8 (P1). Until then, a 6–7-character password gets the server's 400 message (no crash) | Password validators |

**Not changed:** `widgets/notification_bell.dart`, `services/location_service*.dart`, the theme, the weather widgets, routes and page structure. `post_card.dart`, `comments_sheet.dart` and `create_post_page.dart` change only at the image-URL lines listed in F15.

---

## 10. Security and acceptance tests

**Infrastructure:**
- Data-changing tests run only on `devlink-sql-test` (`DevLinkTest_<guid>` databases, built by migrations and dropped). Never on `DevLink`.
- The test factory generates random keys, uses environment `Testing` with enforcement on, and injects `TimeProvider`.
- Helpers:
  - `CreateUserAsync(role, status)`;
  - `SignInAsync` returns an authenticated `HttpClient`, the refresh cookie and the binding cookie;
  - `TokenMinter` creates expired, forged, wrong-audience, wrong-algorithm and wrong-`typ` tokens;
  - `FakeGoogleTokenValidator`;
  - `CapturingLoggerProvider` and a `SecurityEvents` reader (for "no secrets" assertions);
  - `FakeEmailSender`.
- The existing 32 tests are migrated to authenticated clients.

### 10.1 Clarification A — refresh-token records, replay, concurrency

| ID | Test |
|---|---|
| T-RT-01 | Unknown, idle-expired or absolute-expired refresh token → 401 `SESSION_EXPIRED` |
| T-RT-02 | Rotation RT0 → RT1: the DB holds **two rows**; RT0 has `Status = Rotated`, `ConsumedAt` set, `ReplacedByTokenId` = RT1's id; RT1 has `ParentTokenId` = RT0's id; RT0's `TokenHash` unchanged |
| T-RT-03 | Replay: RT0 → RT1, then RT0 again → 401 `SESSION_REVOKED`; session `Revoked/ReuseDetected`; RT1 `Revoked`; the session's access token → 401 on its next request; `Auth.RefreshTokenReuse` row written; cookies deleted |
| T-RT-04 | Chain replay: RT0 → RT1 → RT2, present RT0 → session revoked and RT2 dead |
| T-RT-05 | Isolation: user signed in on sessions S1 and S2; reuse in S1 → S2's refresh and access token keep working; stamp unchanged |
| T-RT-06 | Concurrent refresh with the same token: 10 parallel requests, started together (barrier), repeated 20 times. Each run: exactly one 200; never two `Active` rows in a session (DB assertion); the old row is never overwritten |
| T-RT-07 | Service-level lock test: two `DbContext`s; the first holds the row lock mid-transaction; the second blocks, then sees `Rotated` → reuse path |
| T-RT-08 | The filtered unique index rejects a second `Active` token in one session (direct insert) |
| T-RT-09 | A token of a session already ended by logout → 401 `SESSION_REVOKED`; no alert email; only `Auth.EndedSessionTokenPresented` |
| T-RT-10 | Cleanup: rows of an `Active` session are never deleted, even if very old; an ended session's rows go after 30 days (`TimeProvider`) |
| T-RT-11 | Logout: refresh fails afterwards; the access token is rejected on the next request; cookies deleted |
| T-RT-12 | Logout-all: every session's refresh and access tokens fail |

### 10.2 Clarification B — cross-tab concurrency

| ID | Test | Kind |
|---|---|---|
| T-MT-01 | Two `AuthHttp` "tabs" share a fake cookie jar and a fake lock and run against a fake server with strict rotation; both get `TOKEN_EXPIRED` at the same moment → two sequential rotations, no reuse, both tabs continue | Flutter unit |
| T-MT-02 | The same scenario **without** the lock → the fake server detects reuse (documents why the lock is required) | Flutter unit |
| T-MT-03 | 20 parallel 401s in one tab → exactly one refresh call | Flutter unit |
| T-MT-04 | `navigator.locks` missing → sign-in buttons disabled, message shown, no session call made | Flutter unit (bootstrap with a fake feature detector) |
| T-MT-05 | Lock not granted within 15 s → "please sign in again", navigation to `WelcomePage`, no refresh sent | Flutter unit (fake clock) |
| T-MT-06 | Server: two clients sharing one cookie container refresh one after the other → both 200, one `Active` token | Backend integration |
| T-MT-07 | **Automated two-tab test (C3)** — a script in `tests/e2e/` (Node's built-in WebSocket; no package) drives Chrome through the DevTools Protocol against the local API + `localhost:5200`:<br>1. Sign in once.<br>2. Open a second tab.<br>3. **Reload both tabs in the same instant**, 20 times. Each reload makes the bootstrap call `session/refresh`, so both tabs race for the same cookie.<br>4. Repeat with a Development-only access-token lifetime of 1 minute, letting both tabs' proactive timers fire together.<br>Pass criteria: both tabs signed in after every round; **zero** `Auth.RefreshTokenReuse` rows and zero `SESSION_REVOKED` responses; exactly one `Active` refresh token in the session. Run once in Chrome and once in Edge. **M2 can't be marked complete unless it passes** | Automated E2E (M2.14) |
| T-MT-08 | Server-side counter-check: the same race with Web Locks disabled in the test page shows reuse detection firing, proving T-MT-07 tests the right thing | Automated E2E (M2.14) |

### 10.3 Clarification C — revocation and cache

| ID | Test |
|---|---|
| T-SC-01 | Suspension → the very next request (no 30 s wait) is 403 `ACCOUNT_SUSPENDED`; unsuspension → the next request is allowed |
| T-SC-02 | Password change, logout-all and `revoke-sessions` → other sessions get 401 on their next request |
| T-SC-03 | Stale-reload race: a load is paused, an invalidation happens, the load resumes → its result is not stored, and the next request reads fresh data |
| T-SC-04 | Database unavailable on a cache miss → 503, never 200 |
| T-SC-05 | An entry is never used after 30 s (`TimeProvider`) |
| T-SC-06 | `Deployment:Topology = MultiInstance` → startup fails with a clear message |

### 10.4 Clarification D — download links

| ID | Test |
|---|---|
| T-DL-01 | The owner, an admin and a post owner the programmer applied to can get a link; another customer → 403; another programmer → 403; a suspended user → 403 |
| T-DL-02 | Replay: first use 200, second use 410 |
| T-DL-03 | Two parallel uses → exactly one 200 |
| T-DL-04 | Expiry: at 59 s → 200; at 61 s → 410 (`TimeProvider`) |
| T-DL-05 | Revoked session: after logout, logout-all, `revoke-sessions`, password reset and reuse revocation → 410 |
| T-DL-06 | Unauthorized recipient: without the binding cookie → 410; with another user's binding cookie → 410; with the same user's cookie from a different session → 410 |
| T-DL-07 | Lost authorization: recipient suspended, or (for the admin case) role changed between issue and use → 410 |
| T-DL-08 | Resource version: the file is replaced or deleted after issue → 410 |
| T-DL-09 | Headers: `Cache-Control: no-store, private`, `Referrer-Policy: no-referrer`, `nosniff`, `Content-Disposition: attachment`, allowlisted content type; the issuance response is `no-store` |
| T-DL-10 | Logs: captured application logs and `SecurityEvents` rows contain neither the link token nor the cookie value; hosting/routing log levels are `Warning` |
| T-DL-11 | Issuance rate limit → 429 |

### 10.5 Other security tests (from revision 2, updated)

| ID | Requirement | Test(s) |
|---|---|---|
| T-AN-01 | Anonymous users can't reach protected endpoints | Data-driven over §8.1: every non-Anon route → 401 without a token; the 8 Anon routes → not 401; image routes without signature or token → 401 |
| T-LG-01/02 | Valid login | Web: access token + `devlink_rt` (`HttpOnly; Secure; SameSite=Strict; Path=/api/Auth/session`) + `devlink_fb` (`Path=/api/Files`), no refresh token in the body. Mobile: `refreshToken` in the body, no cookies. Claims `sub`, `role`, `sid`, `sstamp`, `typ=at+jwt`, no email |
| T-LG-03 | Wrong password | Generic 401; 6th attempt → 429 `ACCOUNT_LOCKED`; unknown email the same; IP limit → 429 |
| T-LG-04 | Legacy short password still logs in and is rehashed (P1) | |
| T-JWT-01…05 | Token validation | Expired → 401 `TOKEN_EXPIRED`; bad signature; wrong `iss`/`aud`; `alg=none` or HS384; wrong `typ`; lifetime > 15 min → all 401 |
| T-JWT-06 | Startup rejects missing, short, placeholder or duplicate keys (JWT, code and media keys) | |
| T-JWT-07 | Key rotation: a `ValidateOnly` key validates; a removed key fails | |
| T-CS-01…06 | CSRF on `session/refresh` and `session/logout` | Missing `Origin` + `Referer` → 403; `Origin: http://evil.example` → 403; `http://127.0.0.1:5200` (unlisted) → 403; missing `X-DevLink-Client` → 403; `text/plain` → 415/403; preflight from an unlisted origin gets no `Access-Control-Allow-Origin`; CORS `*` → startup fails |
| T-CS-07 | Bearer endpoints ignore cookies: cookies without a Bearer token → 401 | |
| T-OW-01…11 | Ownership | As in revision 2: customers vs other customers (profile, `Support/my`, weather, notifications → 403); programmer impersonation; foreign post acceptance; `isAdmin=true` ignored |
| T-AD-01…04 | Admin routes | Customer → 403, Programmer → 403, Admin → 2xx for every `AdminOnly` route; self-promotion → 403; `POST Admin/users` with `UserType=Admin` → 403 (Q10) |
| T-NT-01/02 | Read or mark another user's notification → 403; DB unchanged | |
| T-NR-01…03 (N1) | Notifications | Creating 7 notifications keeps all 7 (replaces the old 5-retention characterization test); `GET` without parameters returns the newest 5 as an array (bell unchanged); `limit`/`before` page through all, `limit` capped at 50 |
| T-PD-01…05 | Private data | `Posts/profile/{id}` from another user has no email/phone; `search` has no email for non-admins; applications: no email unless accepted **and** consented (Q16), consent route only by the applicant, withdrawing consent hides it again; `Support/{id}` of another user → 403 |
| T-IM-01…07 (Q15, C5) | Images | Avatar/post image without signature or token → 401; valid signature → 200; expired → 403; tampered → 403; suspended/deleted account → 404; pending post image only through the admin/owner URL; **two URLs issued in the same 10-minute bucket are identical, and different in the next bucket; a URL is accepted up to 20 min and rejected after** (`TimeProvider`); captured logs contain no `sig` value |
| T-SP-01…05 (Q5) | Suspended accounts | Suspended login succeeds with `status: Suspended`; every allowlisted route works; every other route → 403 `ACCOUNT_SUSPENDED` (data-driven over §8); support message and appeal can be sent; an admin can't be suspended |
| T-VF-01 (Q14) | Uploading, replacing or deleting a certificate sets `IsVerified = false` (Pending); uploading a CV doesn't | |
| T-GG-01…08 | Google | Invalid token, `email_verified=false`, wrong audience → 401; existing email without subject → 409, no session; known subject → session; new email + signup → account with subject; Admin → 403 (Q13); `google-link` rules |
| T-PW-01…04 | Passwords | Change-password keeps the current session and kills others; reset kills all; P1: a 7-character new password → 400; admin create/update apply the policy |
| T-PW-05…08 (C7) | Blocklist | A listed password (any case) → 400 on sign-up, reset, change-password and admin create/update; the email or its local part as the password → 400; an 8+-character unlisted password → accepted; **a legacy account whose stored password is on the blocklist still signs in** (and is rehashed if plaintext) |
| T-RC-01 | Role change revokes the target's sessions; a new login carries the new role | |
| T-CD-01…10 (Q7) | Codes | 6th wrong attempt → destroyed; expiry 10 min; single use; a new code invalidates the old one and its proof token; `signup`/`reset-password` without, with an expired or a reused proof token → 400; registered email in `send-code` → same response + "account exists" email, no code; per-email 60 s and 5/hour → 429; per-IP limits → 429; **the DB contains no plaintext code or email** (scan of `OneTimeCodes`); parallel wrong attempts can't exceed 5 |
| T-CD-11…14 (C6) | Aggregate limits | 10 failed attempts for one email spread over 3 successive codes → the 11th → 429, even with a fresh code; the limit applies across both purposes; 20 failed attempts from one IP across different emails → 429; an unknown email hits the same limits with the same responses; after the window (`TimeProvider`) verification works again |
| T-AU-01…05 (Q8) | Audit | Each listed security action writes its event; a transactional event rolls back with its failed change; a full async channel never blocks a request; **no row contains a token, code, password, cookie value or full email** (scan with the test's known secret values); rows older than 90 days are removed |
| T-AL-01…03 (Q12) | Reuse alert | One generic email queued per reuse; at most 3 per user per 24 h; the body contains no IP, token or device data; an email failure doesn't affect the revocation |
| T-SW-01…05 | Migration switch | `false` with `Production`, `Staging`, `Testing` → host fails to start; `Development` + false → starts, warns, adds `X-DevLink-Auth`; non-loopback binding + false → stops; missing key → enforced |
| T-SW-06…10 (C1) | Fallback cases | Per case: off by default; off outside Development; off for a non-loopback remote address; each use logs `Auth.DevFallbackUsed` without personal data or tokens (§7.3) |
| T-SW-R (C1) | Removal (M2.13) | With the key `false` in Development on loopback, all four cases are enforced; `LegacyFallback` no longer exists |
| T-SC-07 (C2) | Staleness bound | A change written directly to the DB (outside the API) takes effect within 30 s and never later (`TimeProvider`); a change through the API takes effect on the next request |
| T-LOG-01 | Captured logs during login, refresh, reuse, download and code tests contain no token, hash, code, password or key value | |
| T-REG-* | Regression | Feed, like → notification, comments, weather wiring, admin statistics, legacy rehash — all with authenticated clients |

**Flutter tests** (no new packages; `http/testing.dart` `MockClient`): T-MT-01…05, plus `AuthHttp` adds the header; a failed refresh ends the session; non-`TOKEN_EXPIRED` 401s don't refresh; the bootstrap navigates by the server role; `ACCOUNT_SUSPENDED` opens the suspension screen.

---

## 11. Final M2 implementation sequence

Each task is implemented alone. Then the diff is shown, the tests are run, and a report with the evidence below is given before the next task starts. Nothing is committed or pushed unless you ask. Risk: H high · M medium · L low.

**Sequencing fix 1 (approved 2026-11-03):** **M2.6 runs immediately after M2.3 is reviewed**, before M2.4 — still with its own approval, backup and restore check. Otherwise the local API would fail against `DevLink` as soon as the EF model has the new `Users` columns. Execution order: M2.1 → M2.2 → M2.3 → **M2.6** → M2.4 → M2.5 → M2.7 → M2.8 → M2.9 → M2.10 → M2.11 → M2.12 → M2.13 → M2.14. Your partner's database needs the same migration (after their backup) before they run this branch.

**Standing checks before tasks:**
- Before M2.7, M2.8 and M2.10, which change partner-owned backend files, run `git ls-remote origin`. If there are new partner commits, stop and report.
- Before every build: stop the running API (it locks `bin/`) and restart it afterwards.
- In M2.2, the Development CORS allowlist comes from configuration (`Cors:AllowedOrigins`, default `http://localhost:5200`); your partner adds their own origin in user-secrets if they don't use port 5200.

| ID | Task | Main files | Depends | Risk | Done when (acceptance) | Test evidence in the report |
|---|---|---|---|---|---|---|
| M2.1 | Owner approval of revision 3; partner informed | `docs/*` | — | L | Decision log updated | Log entry |
| M2.2 | Foundation: options + key validation (JWT, code, media keys), `TokenService`, JwtBearer, 401/403 ProblemDetails, CORS allowlist + validation, security headers, log-level guard, `Deployment:Topology` guard, **switch with safeguards** (default enforced, nothing protected yet) | `Program.cs`, `DotnetAPI.csproj` (+`Microsoft.AspNetCore.Authentication.JwtBearer` **9.0.22** — C8 as overridden by the owner on 2026-11-03: latest stable 9.0.x, so the token-validation package carries security patches; the only package change in M2.2; `dotnet list package --vulnerable --include-transitive` output in the report), `Services/Auth/*`, `appsettings.example.json` (placeholders only), README | M2.1 | M | Existing 32 tests pass; keys created via user-secrets without being displayed | T-JWT-*, T-SW-*, T-CS-07, T-SC-06, T-LOG-01 (partial); full test output |
| M2.3 | Migration `AddAuthSecurity` (`AuthSessions`, `RefreshTokens`, `OneTimeCodes`, `SecurityEvents`, Users columns `SecurityStamp`/`Status`/`SuspendedReason`/`SuspendedAt`/`FailedLoginCount`/`LockoutEndAt`/`GoogleSubject`/`LastLoginAt`, `PostApplications.ContactShareConsentAt`) — validated **only on disposable DBs** | `DataBase/*`, `AppDbContext.cs`, `Migrations/*` | M2.2 | **H** | Both validation paths identical; existing rows keep their values; idempotent script; no pending model changes | Reviewed SQL script; catalog comparison; `has-pending-model-changes` output |
| M2.4 | Sessions: login/sign-up/Google login issue sessions; strict rotation; reuse handling; logout; logout-all; `me`; cookie mode + `[CookieSessionGuard]`; binding cookie; session-state cache with generation counter; cleanup service | `Services/Auth/*`, `Controllers.cs`, `Program.cs` | M2.3 | **H** | Clarifications A–C verified on the server | T-LG-*, T-RT-01…12, T-MT-06, T-SC-01…05, T-CS-01…06 |
| M2.5 | Account security: P1 + common-password blocklist (C7, embedded data file); DB-backed codes + proof tokens + aggregate limits (C6); fallback case 2 (C1); generic responses; rate limits; lockout; background email queue; change-password; suspend/unsuspend/revoke-sessions; restricted mode; stamp rotation on admin changes; `SecurityEventWriter`; reuse alert email | `VerificationService`, `PasswordService`, `Controllers.cs`, `AdminController/Service`, `EmailService`, `Services/Security/*`, `Program.cs` | M2.4 | M | Q5, Q7, Q8, Q12 implemented | T-CD-* (incl. 11–14), T-PW-* (incl. 05–08), T-SP-*, T-RC-01, T-AU-*, T-AL-*, T-SW-07 |
| M2.6 | Apply `AddAuthSecurity` to local `DevLink`: backup → restore-verify → update → verify. **Separate approval. Runs right after M2.3 (fix 1)** | — | M2.3 reviewed | M | EF up to date; row counts unchanged | Same evidence format as 2026-11-03 (backup path, checksums, catalog diff) |
| M2.7 | Authorization: fallback policy, role policies, `[AllowAnonymous]` (8), `[AllowSuspended]`, `ICurrentUser`, ownership, identity from claims, Q3/Q16 projections and consent route, support rules (Q4), G18 error leaks | All controllers, `PostService`, `AdminService` | M2.5 | **H** | §8 matrix enforced with the switch on | T-AN-01, T-OW-*, T-AD-*, T-NT-*, T-PD-*, T-SP-* (data-driven), T-VF-01 |
| M2.8 | Private files and images: link issue/consume, binding-cookie check, signed member URLs, 10-minute pending-image URLs, image hardening. **Early spike:** does `launchUrl` send the binding cookie? (else Bearer + `file_saver`) | `ProgrammerProfileController`, `PostsController`, `PostService`, new `FilesController`, `Services/Files/*` | M2.7 | M | Clarification D verified | T-DL-01…11, T-IM-*; spike result in the report |
| M2.9 | Google: `IGoogleTokenValidator`, `email_verified`, subject matching, 409, `google-link`, Admin excluded | `GoogleAuthService`, `Controllers.cs` | M2.4, M2.5 | M | Q11, Q13 | T-GG-* |
| M2.10 | Notification retention (N1): remove the delete-all-but-5 code; add `limit`/`before`; default response unchanged. **Partner-owned code — partner informed before the change** | `PostService.CreateNotification`, `NotificationsController` | M2.7 | L | Bell behaviour unchanged; history preserved | T-NR-*; old characterization test replaced (shown in the diff) |
| M2.11 | Backend security + regression suite complete; old tests migrated | `tests/**` | M2.4–M2.10 | L | All green | Full test report (counts per area) |
| M2.12 | Flutter integration — files F1–F17, **after partner review** | §9 files | M2.11 + partner approval | **H** | `flutter analyze` 0 errors; `build web` OK; screens unchanged apart from listed texts and the new suspension screen | Flutter unit tests (T-MT-01…05 etc.); screenshots per role |
| M2.13 | **Remove the migration switch** and fallbacks; enforcement unconditional | `Program.cs`, `ICurrentUser`, image routes, tests | M2.12 | M | Switch key has no effect | T-SW-R (C1); full suite |
| M2.14 | E2E in Chrome and Edge on `localhost:5200` against the local API + `DevLink`: Customer, Programmer, Admin, a suspended user, two-tab check (T-MT-07). Needs `seed-admin` with your email (you enter the password locally) | — | M2.13 | L | Checklist complete; **automated T-MT-07 passes in Chrome and Edge** (C3) | Report, screenshots, T-MT-07/08 script output, `SecurityEvents` excerpt (no secrets) |

M2 is complete only after M2.13 and M2.14. No marketplace or Clear Scope work before then.

---

## 12. Remaining blockers, decisions and partner approvals

### 12.1 Blockers

| ID | Blocker | Blocks | Owner |
|---|---|---|---|
| B1 | ~~Your explicit approval of this revision~~ — **resolved 2026-11-03** (revision 3 + fixes 1–2 + JwtBearer package approved) | — | You |
| B2 | Partner review and approval of Flutter files F1–F17 | M2.12 (backend tasks can proceed) | Partner |
| B3 | Partner informed/agreeing before changes to their backend code: notification retention (M2.10), image URLs in feed responses (M2.8), support authentication (M2.7) | Those tasks | Partner |
| B4 | Separate approval to apply the migration to local `DevLink` (M2.6), and later to the partner's database after their own backup | M2.6 | You; partner for their DB |
| B5 | Admin email for `seed-admin` (you enter the password locally) | M2.14 | You |
| B6 | Gmail App Password revocation (M1-01). The old credential must never be reused. Doesn't block M2 code (Development uses the console email sink), but blocks real email delivery and any deployment | Real email | Account owner |
| B7 | Google web client id in `Google:ClientIds` (user-secrets) for manual Google E2E | Google part of M2.14 | You/partner |

### 12.2 Decisions still needed (small; recommendations given)

| ID | Decision | Recommendation | Who |
|---|---|---|---|
| R1 | Signed, time-limited image URLs for authenticated users (public set 12 → 8) | **Approved 2026-11-03** | You (partner reviews F14/F15) |
| R2 | Web Locks required; clear browser-compatibility message | **Approved 2026-11-03** | You |
| R3 | IP minimization: truncated prefix for 6 abuse events only, nulled after 14 days; no IP in logs; no access path (§6.4) | **Approved with changes 2026-11-03** — confirm 14 days (non-blocking, configurable) | You |
| R4 | Notification cleanup policy (separate document after M2), e.g. read notifications deleted after 180 days, unread after 365 | Decide after M2; M2 only stops the deletion | You + partner |
| R5 | A regular "Contact support" entry point for programmers (today only the customer home has one) | Add one icon in the programmer dashboard app bar in the MVP; in M2 only via the suspension screen | Partner |
| R6 | Where programmers give contact-email consent (Q16) | A checkbox in the apply flow once programmers can apply (KI-13, MVP); until then email stays hidden | Partner |
| D2 | Supervisor constraints, including whether Android is a deliverable (affects Q2 later) | — | Supervisor |

### 12.3 Exact items needing your partner's approval
1. **Flutter files F1–F17** (§9), in particular:
   - login, sign-up and reset screens and their new texts (F7–F9);
   - logout buttons (F10);
   - app start/bootstrap (F5);
   - the welcome-screen browser message (F6);
   - the new suspension screen (F11);
   - feed, comments and admin image-URL lines (F15).
2. **Backend changes in their code:** removing the 5-notification deletion and adding paging (N1); feed/comment responses gaining `avatarUrl`/`images[].url`; feed and weather endpoints requiring sign-in; `POST /api/Support` requiring sign-in.
3. **Product decisions involving their features:**
   - R1 (images);
   - R4 (notification cleanup);
   - R5 (programmer support entry);
   - R6 (consent UI);
   - confirmation that Q14 matches their intent — their code already resets verification.
4. **Environment:** web app on fixed port 5200; their own keys in user-secrets; the migration on their database after a backup; Chrome/Edge for development.

§13 gives the full, actionable partner-coordination list (C9).

### 12.4 Carried items
- KI-27 notifications (fixed by M2.7).
- Admin, support and personal-data exposure (M2.7, M2.8).
- **The Gmail App Password is still in public Git history. It must never be reused; the account owner must revoke it (M1-01, KI-01).**
- No secrets, database backups or `appsettings.json` in the public repository; keys only in user-secrets or the environment.

---

## 13. Partner coordination (condition C9)

Everything your partner needs to know or approve for M2, in the order it will matter. Nothing on this list has been done to their code or database yet. Each item's outcome is recorded in the decision log when it is settled.

| # | Item | What your partner does | When | Blocks |
|---|---|---|---|---|
| P-1 | **Their database: backup → M1 baseline scripts → `AddAuthSecurity`, in this order** | 1. **Backup first**: COPY_ONLY backup + restore check + CHECKDB, the same procedure used for `DevLink` on 2026-11-03.<br>2. **M1 baseline scripts** (only if their DB has no `__EFMigrationsHistory` yet, KI-16): `database/align_schema_for_ef_baseline.sql`, then `database/baseline_ef_history.sql`. Both are idempotent.<br>3. **This migration**: **prefer `dotnet ef database update`** against their own connection string — EF applies each migration in its own transaction and sets the required session options itself. If the SQL script from `dotnet ef migrations script --idempotent` is used instead (e.g. through SSMS or sqlcmd), it **must** run with **`sqlcmd -I`** (QUOTED_IDENTIFIER ON is required for the filtered indexes — KI-37; without it the run fails and, as rehearsed at M2.6, leaves the database unchanged; SSMS has it on by default).<br>This exact sequence was rehearsed on a restored copy of our backup seeded with legacy-style rows (M2.3). Existing rows are unchanged; every user gets its own random `SecurityStamp` and `Status = Active`. **Until step 3 is done, the API from this branch fails on their DB** (new `Users` columns) | Before they run the branch after M2.3 | Their local testing |
| P-2 | **CORS origin / fixed port** | From M2.2 the API accepts browser calls only from exact origins. Default: `http://localhost:5200`. Either run `flutter run -d chrome --web-port 5200 --web-hostname localhost`, or add their origin locally with `dotnet user-secrets set "Cors:AllowedOrigins:1" "http://localhost:<port>" --project backend`. Use `localhost`, not `127.0.0.1` or a LAN IP (C4, KI-33) | Before they run the branch after M2.2 | Their local testing |
| P-3 | **Their own secrets** | Generate their own `Jwt:SigningKeys`, `Security:CodeHmacKey` and `Security:MediaUrlKey` with the commands in §3.2 (never shared) | Same as P-2 | Their local API startup |
| P-4 | **Removal of the "newest 5" notification deletion** (N1) | Agree before M2.10 changes `PostService.CreateNotification` and `NotificationsController` — their code. The bell keeps showing 5 (default `limit`); older notifications are kept instead of deleted; paging via `limit`/`before`. The old test `Current_behaviour_only_the_newest_five_notifications_are_kept` is replaced. Cleanup policy R4 decided later with them | Before M2.10 | M2.10 **Done 2026-11-10:** the partner was told (reported by the owner) and M2.10 removed the deletion. |
| P-5 | **Other backend changes in their code** | Agree: feed/comment/profile responses gain `avatarUrl` / `images[].url` (M2.8); feed, weather and support endpoints require sign-in (M2.7); weather errors no longer return `ex.Message` | Before M2.7/M2.8 | M2.7, M2.8 |
| P-6 | **Flutter review — F1–F18 (§9)**, including **`admin/admin_user_form_page.dart`** (lines 472, 480: password minimum 6 → 8) and the rest of **F18** (`set_password_page.dart:405`, `reset_password_page.dart:362`) | Review and approve each file's change before M2.12 is merged; especially login/sign-up/reset texts (F7–F9), logout (F10), app start (F5), the browser message (F6), the new suspension screen (F11) and the image-URL lines in feed/comments/admin pages (F14–F15) | Before M2.12 | M2.12 |
| P-7 | **"Add admin" screen** (`admin/admin_add_admin_page.dart` → `ApiService.createAdmin`) | **Decided by the owner 2026-11-05 (UI-9):** the screen is hidden and replaced by a short message that administrators are created via the CLI, in the M2.12/redesign track. Since M1 the API returns **403** for creating admins (Q10, seed-admin only), so the screen can't succeed today (KI-34) | Be aware; changed in M2.12/redesign | — |
| P-8 | **Product decisions** | R5 (programmer support entry point), R6 (consent checkbox location), confirm Q14 matches their intent (their code already resets verification) | Before the MVP | — |
| P-9 | **Google client id** | `Google:ClientIds` in user-secrets for Google sign-in tests | Before M2.14 | Google part of M2.14 |
| P-10 | **Gmail App Password** | The account owner revokes the leaked password (M1-01); it must never be reused | As soon as possible | Real email delivery |
| P-11 | **Admin user deletion fails while the user has sessions** (KI-39) | Since `AddAuthSecurity`, `AuthSessions`/`RefreshTokens` reference `Users` with NO ACTION (security records are never cascade-deleted). Deleting a user who has ever signed in after M2.4 is refused by the database (FK `FK_AuthSessions_Users`) — in the admin UI this shows as a failed delete. Fixed when the delete path revokes and removes the sessions first (M2.5/M2.7); no workaround by editing the database | Information now; until M2.5/M2.7 | Admin delete of signed-in users |
| P-12 | **Duplicate programmer-verification routes** | `POST ProgrammerProfile/{userId}/verify` and `/unverify` (their file) duplicate `POST Admin/programmers/{userId}/verify` / `unverify` and no screen calls them. Since M2.7a they are Admin-only (closes KI-05); decide whether to remove them | Any time after M2.7a | — |
| P-13 | **Verified badge on every programmer's posts** (KI-60) | `post_card.dart:292` shows the blue verified badge whenever `authorType == 'Programmer'`, verified or not, and the feed response has no verification field. Fix the badge together with the feed data | Redesign / M2.12 | — |
