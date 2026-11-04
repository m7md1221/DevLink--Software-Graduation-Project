# M2.7 Endpoint Authorization Plan

**Status:** planned 2026-11-04; **owner decisions D-1…D-9 recorded 2026-11-04 (§5)**; M2.7a implemented (uncommitted); 7b–7d not started. Baseline: `feature/m1-foundation` @ `d63d793`; partner `main` unchanged at `2910d88`.
**Target rules** come from the approved design ([M2_AUTH_DESIGN.md §8](M2_AUTH_DESIGN.md), rows #1–#67). Where this plan needs a choice the design does not settle, it is listed in [§4 Decisions needed](#4-decisions-needed).

**Legend**
- **Now:** today's behaviour. *Anon* = no sign-in needed. *Trusts* = identity taken from a client-supplied value (`userId`, `requesterId`, `ProgrammerId`, `isAdmin`, form `UserId`).
- **Target:** *Public* = anonymous by design · *Auth* = signed-in member (any role) · *Owner* = the caller owns the resource · *Self* = route `{userId}` must be the caller · *Role X* · *Admin* · *Signed* = signed image URL (M2.8) · **(S)** = also for suspended users.
- **Owner check:** how the server decides; "token" = `sub` claim via `ICurrentUser`, never a client value.
- **Risk now:** **CRITICAL** = account takeover, destructive action or admin power without sign-in · **HIGH** = personal data or moderation bypass · MEDIUM · LOW.
- **Phase:** the M2.7 sub-phase that fixes it (§2), or the milestone that already did / will.

## 1. Endpoint table (73 routes, 7 controllers)

### AuthController — `/api/Auth` (all `[AllowSuspended]`)
| # | Method | Route | Now | Target | Owner check | Flutter caller | Risk now | Phase |
|---|---|---|---|---|---|---|---|---|
| 1 | POST | `login` | Anon; rate limit, lockout | Public | own credentials | `login_page` | — | done (M2.4a) |
| 2 | POST | `google-login` | Anon; **auto-links by email** (KI-08) | Public | Google subject | `login_page` | HIGH (KI-08) | M2.9 |
| 3 | POST | `send-code` | Anon; generic, limits | Public | — | sign-up screens | — | done (M2.5a) |
| 4 | POST | `verify-code` | Anon; 5 attempts | Public | email + code | sign-up screens | — | done |
| 5 | POST | `signup` | Anon; proof token (fallback case 2) | Public | proof token | `set_password_page` | — | done |
| 6 | POST | `send-reset-code` | Anon; generic | Public | — | forgot-password screens | — | done |
| 7 | POST | `verify-reset-code` | Anon; 5 attempts | Public | email + code | forgot-password screens | — | done |
| 8 | POST | `reset-password` | Anon; proof token | Public | proof token | reset screen | — | done |
| 9 | POST | `session/refresh` | cookie / body token + CSRF guard | Holder of a refresh token (S) | token row | — (M2.12) | — | done (M2.4b) |
| 10 | POST | `session/logout` | same | same (S) | token row / `sid` | — (M2.12) | — | done |
| 11 | POST | `logout-all` | Bearer | Auth (S), Self | token | — (M2.12) | — | done |
| 12 | GET | `me` | Bearer | Auth (S), Self | token | — (M2.12) | — | done |

### AdminController — `/api/Admin`
| # | Method | Route | Now | Target | Owner check | Flutter caller | Risk now | Phase |
|---|---|---|---|---|---|---|---|---|
| 13 | GET | `users` | **Anon** — every non-admin user with email, phone, city | Admin | role from token | `admin_users_page` | **CRITICAL** (all personal data) | **7a** |
| 14 | GET | `users/{id}` | **Anon** — email, role | Admin | role | — (unused) | HIGH | **7a** |
| 15 | POST | `users` | **Anon** — creates Customer/Programmer accounts without email verification (Admin type → 403) | Admin | role | `admin_user_form_page`, `admin_add_admin_page` (gets 403, KI-34) | **CRITICAL** (account creation) | **7a** |
| 16 | PUT | `users/{id}` | **Anon** — change any non-admin's **password / email / role** | Admin; target not an admin | role | `admin_user_form_page` | **CRITICAL** (account takeover) | **7a** |
| 17 | DELETE | `users/{id}` | **Anon** — delete any non-admin (sessions removed since M2.5b) | Admin; target not an admin | role | `admin_users_page` | **CRITICAL** (destructive) | **7a** |
| 18 | POST | `users/{id}/suspend` | Admin token (M2.5b) | Admin; target not an admin, not self | role | — (M2.12) | — | done |
| 19 | POST | `users/{id}/unsuspend` | Admin token (M2.5b) | Admin | role | — (M2.12) | — | done |
| 20 | GET | `programmers` | **Anon** — emails, phones, LinkedIn, document names | Admin | role | `admin_verifications_page` | HIGH | **7a** |
| 21 | POST | `programmers/{userId}/verify` | **Anon** — anyone can verify anyone (+ email) | Admin | role | `admin_verification_details_page` | HIGH (trust badge) | **7a** |
| 22 | POST | `programmers/{userId}/unverify` | **Anon** | Admin | role | `admin_verification_details_page` | HIGH | **7a** |
| 23 | GET | `statistics` | **Anon** — aggregate counts | Admin | role | `admin_statistics_page` | LOW | **7a** |

### CustomerProfileController — `/api/CustomerProfile`
| # | Method | Route | Now | Target | Owner check | Flutter caller | Risk now | Phase |
|---|---|---|---|---|---|---|---|---|
| 24 | GET | `{userId}` | **Anon** — phone, country, city | Self or Admin | route `{userId}` = `sub`, or role Admin | `dashboard_placeholder_page` | HIGH (phone) | **7c** |
| 25 | POST | (create) | **Anon, trusts form `UserId`** | Role Customer, Self | `UserId` → from token | `customer_profile_setup_page` | HIGH (write someone else's profile) | **7b** |
| 26 | PUT | `{userId}` | **Anon** — edit anyone's profile/photo | Role Customer, Self | `{userId}` = `sub` | — (unused today) | HIGH | **7b** |
| 27 | GET | `{userId}/image` | Anon | Signed (members) | signature | `dashboard_placeholder_page` (URL) | MEDIUM (photo enumeration) | M2.8 |

### ProgrammerProfileController — `/api/ProgrammerProfile`
| # | Method | Route | Now | Target | Owner check | Flutter caller | Risk now | Phase |
|---|---|---|---|---|---|---|---|---|
| 28 | GET | `{userId}` | **Anon** — phone, city, file names | Auth; Self/Admin → full, others → member projection | `{userId}` = `sub` or Admin | `programmer_dashboard_page` | HIGH (phone) | **7c** |
| 29 | GET | `all` | Anon — member fields | **Admin** (D-4) | role | — (unused) | MEDIUM | **7d** |
| 30 | POST | (create) | **Anon, trusts form `UserId`** | Role Programmer, Self | from token | `programmer_profile_setup_page` | HIGH | **7b** |
| 31 | PUT | `{userId}` | **Anon** — edit anyone's profile | Role Programmer, Self | `{userId}` = `sub` | — (unused today) | HIGH | **7b** |
| 32 | GET | `{userId}/image` | Anon | Signed | signature | dashboard, admin verification pages (URL) | MEDIUM | M2.8 |
| 33 | GET | `{userId}/cv` | **Anon** — the CV file | P self, Admin, Customer with an application from this programmer | as listed | dashboard, `admin_verification_details_page` (`launchUrl`) | **HIGH** (private document) | M2.8 (link tokens); fallback case 3 |
| 34 | GET | `{userId}/certificate` | **Anon** | same as #33 | same | same | **HIGH** | M2.8 |
| 35 | POST | `{userId}/cv` | **Anon** — replace anyone's CV | Role Programmer, Self | `{userId}` = `sub` | `programmer_dashboard_page` | HIGH | **7b** |
| 36 | DELETE | `{userId}/cv` | **Anon** | Role Programmer, Self | same | `programmer_dashboard_page` | HIGH | **7b** |
| 37 | POST | `{userId}/certificate` | **Anon** (resets verification) | Role Programmer, Self | same | `programmer_dashboard_page` | HIGH | **7b** |
| 38 | DELETE | `{userId}/certificate` | **Anon** | Role Programmer, Self | same | `programmer_dashboard_page` | HIGH | **7b** |
| 39 | POST | `{userId}/verify` | **Anon — self-verification** (KI-05) | Admin (kept, D-3) | role | — (unused) | **CRITICAL** (KI-05) | **7a** |
| 40 | POST | `{userId}/unverify` | **Anon** | Admin (kept, D-3) | role | — (unused) | HIGH | **7a** |

### NotificationsController — `/api/Notifications`
| # | Method | Route | Now | Target | Owner check | Flutter caller | Risk now | Phase |
|---|---|---|---|---|---|---|---|---|
| 41 | GET | `{userId}` | **Anon** — anyone's notifications (KI-27) | Auth, Self | `{userId}` = `sub` | `notification_bell` | HIGH | **7c** |
| 42 | POST | `{id}/read` | **Anon** — mark anyone's as read | Auth, Owner | notification `UserId` = `sub` | `notification_bell` | MEDIUM | **7b** |

### PostsController — `/api/Posts`
| # | Method | Route | Now | Target | Owner check | Flutter caller | Risk now | Phase |
|---|---|---|---|---|---|---|---|---|
| 43 | GET | `feed` | Anon, **trusts `userId`** (like state) | Auth | `userId` → from token | `customer_home_page` | MEDIUM | **7d** |
| 44 | GET | `user/{userId}` | Anon, trusts `currentUserId` | Auth | `currentUserId` → from token | `user_profile_page` | MEDIUM | **7d** |
| 45 | POST | (create) | **Anon, trusts form `UserId`** — post as anyone | Role C/P | from token | `create_post_page` | HIGH (impersonation) | **7b** |
| 46 | DELETE | `{id}` | **Anon, trusts `userId` + `isAdmin`** — `isAdmin=true` deletes any post | Auth; Owner or Admin; `isAdmin` ignored | post `UserId` = `sub`, or role Admin | `post_card` (never sends `isAdmin=true`) | **CRITICAL** (destructive) | **7b** |
| 47 | POST | `{id}/like` | Anon, trusts body `UserId` | Auth | from token | `post_card` | MEDIUM | **7b** |
| 48 | GET | `{id}/comments` | Anon | Auth (approved posts; owner/Admin for others) | post status + owner | `comments_sheet` | LOW | **7d** |
| 49 | POST | `{id}/comments` | Anon, trusts body `UserId` — comment as anyone | Auth | from token | `comments_sheet` | MEDIUM-HIGH (impersonation) | **7b** |
| 50 | DELETE | `comments/{commentId}` | **Anon, trusts `userId` + `isAdmin`** | Auth; Owner or Admin | comment `UserId` = `sub`, or Admin | `comments_sheet` | **CRITICAL** (destructive) | **7b** |
| 51 | GET | `image/{imageId}` | Anon | Signed | signature | `post_card`, `admin_posts_page` (URL) | MEDIUM | M2.8 |
| 52 | GET | `user/{userId}/avatar` | Anon | Signed | signature | 8 screens (URL) | MEDIUM | M2.8 |
| 53 | GET | `search` | **Anon — returns emails**, searchable by email | Auth; email only for Admin (Q3), `null` for others (D-5) | role | `customer_home_page`, `search_users_page`, `user_profile_page` | HIGH (email harvesting) | **7c** (shape: D-5) |
| 54 | GET | `profile/{userId}` | **Anon — email + phone** | Auth; email/phone only Self or Admin (Q3), `null` for others (D-5) | `{userId}` = `sub` or Admin | `user_profile_page` | HIGH | **7c** (shape: D-5) |
| 55 | POST | `{id}/apply` | Anon, trusts body `ProgrammerId` | Role Programmer | from token | `apply_to_post_page` | MEDIUM-HIGH (apply as someone) | **7b** |
| 56 | GET | `{id}/applications` | Anon, trusts `requesterId` — applicants' emails | Post owner (C) or Admin; applicant email visible **only to the post owner** until M2.12 (D-6, KI-53) | post `UserId` = `sub` | `post_applications_page` | HIGH | **7b** (owner); projection **7c** (D-6) |
| 57 | POST | `{id}/applications/{applicationId}/accept` | **Anon, trusts `requesterId`** | Role C, post owner | post `UserId` = `sub` | `post_applications_page` | **HIGH** (accept for someone else) | **7b** |
| 58 | GET | `{id}/applications/count` | Anon | Auth | — | — (unused) | LOW | **7d** |
| 59 | GET | `{id}/has-applied` | Anon, trusts `userId` | Auth; answers for the caller | from token | `post_card` | LOW | **7d** |
| 60 | GET | `pending` | **Anon** — moderation queue | Admin | role | `admin_posts_page` | HIGH | **7a** |
| 61 | POST | `{id}/approve` | **Anon** — anyone publishes | Admin | role | `admin_posts_page` | **CRITICAL** (moderation bypass) | **7a** |
| 62 | POST | `{id}/reject` | **Anon** (+ email to author) | Admin | role | `admin_posts_page` | **CRITICAL** | **7a** |
| 63 | GET | `weather/{userId}` | **Anon** — reveals a user's city (KI-29) | Auth; Self or Admin | `{userId}` = `sub` | `customer_home_page` | MEDIUM | **7c** |
| 64 | GET | `weather-location` | Anon — open proxy to Open-Meteo/Nominatim | Auth | — | `customer_home_page` | LOW-MEDIUM (abuse) | **7d** |

### SupportController — `/api/Support`
| # | Method | Route | Now | Target | Owner check | Flutter caller | Risk now | Phase |
|---|---|---|---|---|---|---|---|---|
| 65 | POST | (send) | Anon, trusts body `UserId`, `Name`, `Email` | Role C/P (S); identity from the account; Admin → 403 | from token | `contact_support_page` | MEDIUM (spoofed sender) | **7b** |
| 66 | GET | `all` | **Anon** — every ticket with names, emails, messages | Admin | role | `admin_support_page` | **CRITICAL** (personal data) | **7a** |
| 67 | GET | `{id}` | **Anon** | Owner or Admin (S) | message `UserId` = `sub` | — (unused) | HIGH | **7c** |
| 68 | POST | `{id}/reply` | **Anon** — reply as "admin" | Admin | role | `admin_support_page` | HIGH | **7a** |
| 69 | POST | `{id}/read` | **Anon** | Admin | role | `admin_support_page` | LOW | **7a** |
| 70 | DELETE | `{id}` | **Anon** — delete any ticket | Admin | role | `admin_support_page` | HIGH | **7a** |
| 71 | GET | `my/{userId}` | **Anon** — anyone's tickets and replies | Role C/P (S), Self | `{userId}` = `sub` | `customer_support_messages_page` | HIGH | **7c** |
| 72 | GET | `my/{userId}/unread-count` | Anon | Role C/P (S), Self | `{userId}` = `sub` | `contact_support_page` | LOW | **7c** |
| 73 | POST | `{id}/mark-reply-read` | Anon | Role C/P (S), Owner | message `UserId` = `sub` | `customer_support_messages_page` | LOW | **7b** |

**Critical until their sub-phase ships:** #46 and #50 (`isAdmin=true` deletes anything) → M2.7b. **Closed by M2.7a:** #13, #15, #16, #17 (admin user management), #39 (self-verification), #61 and #62 (moderation), #66 (support inbox). Mitigation until M2.7 is complete: the API listens on `localhost` only (README warning).

**Counts:** 8 public (#1–#8) + 4 already token-protected (#9–#12) + 2 admin routes done in M2.5b (#18, #19) + 4 signed-image routes and 2 document routes (#33, #34) in M2.8 + **53 routes to change in M2.7** (7a: 18, 7b: 19, 7c: 9, 7d: 7).

## 2. Proposed sub-phases (most dangerous first)

Shared rules for every sub-phase:
- **Identity** always from the token (`sub`, `role`) through a new `ICurrentUser`; client ids are read **only** by `ICurrentUser.ResolveUserId(clientId)`, and only on the fallback path. `isAdmin` is ignored everywhere (no screen sends `true`).
- **Errors:** missing/invalid token → 401 (`UNAUTHENTICATED` / `SESSION_REVOKED`); wrong role or not the owner → 403 `FORBIDDEN`; unknown resource → 404 as today; suspended → 403 `ACCOUNT_SUSPENDED` except (S) routes. Success bodies unchanged.
- **The unchanged Flutter app** sends no token until M2.12. In the **default (enforced) mode** every route changed in a sub-phase returns 401 to it — expected, and the same for the existing tests that call these routes anonymously (they are updated to sign in). With **`Auth:EnforceAuthorization=false` (Development + loopback, C1)**, a request **without** a token takes the fallback (`LegacyFallback`, case `IdentityFromClient`, logged as `Auth.DevFallbackUsed` with case + route template only); a request **with** a token is always fully enforced. Which tokenless requests the fallback may serve is decision **D-1**.
- **Implementation shape:** policies `Authenticated`, `AdminOnly` (exists), `CustomerOnly`, `ProgrammerOnly`, `NonAdmin` from design §7.1, each with an extra requirement that the fallback handler can satisfy for tokenless requests. The M2.5b routes (`suspend`, `unsuspend`) keep a **strict** admin policy with no fallback, as decided.
- **Per sub-phase verification:** `dotnet build` 0 errors; full suite (3 consecutive runs); runtime on `DevLink` with the synthetic admin, one customer and one programmer: anonymous → 401, wrong role → 403, wrong owner → 403, right caller → 2xx with the same body as before; then one API run with the switch off: the unchanged Flutter screens listed below still work, and every fallback use is logged; secret and attribution scans.

### M2.7a — Admin and moderation power (CRITICAL)
- **Routes:** #13–#17, #20–#23 (whole `AdminController` except the done #18/#19), #39/#40, #60–#62, #66, #68–#70.
- **Files:** new `backend/Services/Auth/CurrentUser.cs` (`ICurrentUser`), `backend/Services/Auth/AuthorizationSetup.cs` (policies + fallback handler); `LegacyFallback.cs` (case `IdentityFromClient`); `AdminController.cs` (class-level `AdminOnly`), `ProgrammerProfileController.cs` (#39/#40), `PostsController.cs` (#60–#62), `SupportController.cs` (#66, #68–#70). Partner files → `git ls-remote` check first.
- **Tests:** T-AD-01…04 data-driven over every admin route (anonymous 401, Customer 403, Programmer 403, Admin 2xx); KI-05 test (programmer can't verify self); T-SW-06 (fallback off by default / off outside Development / off for non-loopback), T-SW-10 (fallback log has no personal data); existing `AdminProvisioningTests`, `PasswordPolicyTests` T-PW-04, `PasswordHashingTests` admin cases updated to send an admin token.
- **Runtime:** the checks above for all 18 routes; with the switch off, the unchanged admin screens (users, user form, verifications, statistics, posts moderation, support inbox) still load and act — **only if D-1 allows tokenless admin calls in the fallback**.

### M2.7b — Writes that trust a client id (impersonation, destruction)
- **Routes:** #25, #26, #30, #31, #35–#38 (profiles and documents), #42, #45–#47, #49, #50, #55, #56 (owner check), #57, #65, #73.
- **Files:** `PostsController.cs`, `PostService.cs` (owner checks take the caller id), `CustomerProfileController.cs`, `ProgrammerProfileController.cs`, `NotificationsController.cs`, `SupportController.cs` (name/email from the account), `CurrentUser.cs`.
- **Tests:** T-OW-* per route: owner 2xx, other member 403, Admin allowed where the design says (#46, #50, #56), client `UserId`/`ProgrammerId`/`requesterId` that differs from the token is **ignored** (action recorded for the token's user), `isAdmin=true` has no effect; support message takes name/email from the account; fallback T-SW-06 for `IdentityFromClient`.
- **Runtime:** customer creates/likes/comments/deletes own post, cannot delete another's (403); programmer applies; customer owner accepts, a second customer gets 403; programmer uploads/deletes own CV, not another's. With the switch off: profile setup (customer and programmer), create post, like, comment, delete own post/comment, apply, accept, programmer dashboard uploads, contact support, notification bell — all through the fallback with client ids.

### M2.7c — Personal-data reads
- **Routes:** #24, #28 (projection), #41, #53, #54 (Q3 projections), #56 (Q16 projection, D-6), #63, #67, #71, #72.
- **Files:** `CustomerProfileController.cs`, `ProgrammerProfileController.cs`, `NotificationsController.cs`, `PostService.cs` (search/profile/applications projections), `PostsController.cs` (weather), `SupportController.cs`.
- **Tests:** Self/Admin see phone/email, other members don't (shape per D-5); notifications and support tickets of another user → 403; weather of another user → 403; the 5-notification bell response stays a JSON array.
- **Runtime:** as above; with the switch off: customer dashboard, programmer dashboard, notification bell, search, user profile, my support messages, weather card.

### M2.7d — Members-only content and fail-closed default
- **Routes:** #29, #43, #44, #48, #58, #59, #64; plus the **fallback (default) policy** = authenticated + active session + `Status = Active`, `[AllowAnonymous]` on #1–#8, `[AllowSuspended]` re-checked against design §7.4.
- **Files:** `Program.cs` / `AuthorizationSetup.cs` (fallback policy), `Controllers.cs` (`[AllowAnonymous]` on the 8 public routes), `PostsController.cs`, `ProgrammerProfileController.cs`.
- **Tests:** a reflection test that every action is either `[AllowAnonymous]` (exactly #1–#8 + the session routes' own guard) or covered by a policy — a forgotten attribute fails closed; T-SP-01…05 (suspended: allowlisted routes work, everything else 403); G18 error shapes.
- **Runtime:** anonymous request to every non-public route → 401 (scripted over the route list); with the switch off: feed, user posts, comments, has-applied, weather-by-location still work in the unchanged app.

**Order rationale:** 7a removes unauthenticated admin power (takeover, deletion, moderation, inbox); 7b stops acting as someone else and destroying others' data; 7c stops personal-data reads; 7d closes the remaining member-only reads and makes "forgot an attribute" fail closed. Each sub-phase is independently shippable and testable.

## 3. How the unchanged Flutter app keeps working
- Default runs (switch **on**, the safe default): after each sub-phase, the app's calls to that sub-phase's routes get 401. This is the intended M2 state until M2.12 sends tokens.
- Demo/development runs that need the old app: start the API with `Auth__EnforceAuthorization=false` (Development, loopback only, as in the M2.5a UI check). Tokenless requests then follow the fallback (scope per D-1); each use is logged. Requests with a token are always enforced.
- M2.12 (Flutter sends tokens) makes the fallback unnecessary; M2.13 deletes it.

## 4. Decisions needed
| ID | Endpoint(s) | Question | Options | Recommendation |
|---|---|---|---|---|
| **D-1** | All Admin routes (#13–#23), moderation (#60–#62), support inbox (#66, #68–#70), and member-only routes with no client id (#29, #48, #53, #54, #58, #64, #67) | Design §7.3 limits fallback case 1 to "identity from client-supplied ids". These routes carry **no** client id, so with the switch off the unchanged app's admin screens and several member screens would get 401. | (a) Fallback also lets **tokenless** requests through these routes with today's behaviour (logged, Development + loopback only); (b) no fallback for them — admin and those screens break until M2.12 | (a), limited to Development + loopback, so the old admin UI stays usable for demos until M2.12 |
| **D-2** | #46, #50 (`isAdmin` query) | Design says `isAdmin` is always ignored, even on the fallback. No screen sends `true`. | (a) ignore always (design); (b) honour on the fallback | (a) |
| **D-3** | #39, #40 `ProgrammerProfile/{userId}/verify`, `/unverify` | Duplicates of #21/#22; no screen calls them. | (a) keep as Admin-only (design #33/#34); (b) remove the routes | (b) — less surface; partner file, so with the partner's agreement, else (a) |
| **D-4** | #29 `ProgrammerProfile/all` | No screen calls it. Design: any member. | (a) Auth (design); (b) Admin only; (c) remove | (a) unless the partner confirms it is unused for good, then (c) |
| **D-5** | #53 `search`, #54 `profile/{userId}` | Q3 hides email (and phone) from other members. `search_users_page.dart:277` shows `email` when there is no specialty and `user_profile_page.dart:474` shows the profile email. | (a) keep the key with an **empty string** for non-Self/non-Admin (shape unchanged, nothing crashes); (b) `null` (may break typed Dart models); (c) remove the key; (d) defer the projection to M2.12 together with the UI | (a) in 7c; UI wording in M2.12 |
| **D-6** | #56 applications, new consent route (design Q16) | The applicant email is shown to the post owner only if accepted **and** the programmer consented — but the consent route and UI don't exist yet. Applying 7c now hides every applicant email from customers. | (a) build the consent route in 7c and hide emails until consent (customers lose emails until M2.12 UI); (b) keep today's email for the post owner until M2.12, then switch | (b) — owner check in 7b, projection with the M2.12 UI |
| **D-7** | #65 `POST Support` | Admins → 403 (design). Programmers allowed by the API but have no entry point (partner decision R5). | confirm (a) design as is; (b) also allow Admin | (a) |
| **D-8** | #43 `feed`, #44 `user/{userId}` | Members-only per design (no public feed). Confirm no signed-out landing page is planned that shows posts. | (a) Auth (design); (b) a public read-only feed | (a) |
| **D-9** | #17 `DELETE Admin/users/{id}` | Deleting a user with posts, likes, comments, applications or support messages still fails (KI-10). | (a) keep (soft delete later); (b) add more cleanup now | (a) — out of M2.7 scope |

## 5. Owner decisions (2026-11-04)
| ID | Decision |
|---|---|
| D-1 | **Allowed:** tokenless calls to the admin, moderation, support-inbox and member-read routes take the dev fallback **only** when Environment = Development, `Auth:EnforceAuthorization=false` and the request comes from loopback. Every use is logged (`Auth.DevFallbackUsed`, case + route template). Never applied when a token is present. Removed in M2.13. The M2.5b routes `suspend`/`unsuspend` keep the strict rule (no fallback). |
| D-2 | Client-sent `isAdmin` is ignored everywhere. |
| D-3 | `ProgrammerProfile/{userId}/verify` and `/unverify` become Admin-only and stay (removal is a partner decision later: design §13 P-12). |
| D-4 | `ProgrammerProfile/all` is Admin-only. |
| D-5 | Email/phone hidden from other members as `null`. `search_users_page` and `user_profile_page` are checked at runtime in M2.7c; if either breaks, an empty string is used instead and reported. |
| D-6 | The applicant's email stays visible **only to the post owner** (and Admin) until M2.12 — known issue KI-53. |
| D-7 | Support form: Admin → 403; Customers and Programmers allowed. |
| D-8 | Feed and user posts are members-only; no public feed. |
| D-9 | Deletion of users with other records (KI-10) is out of M2.7. |
