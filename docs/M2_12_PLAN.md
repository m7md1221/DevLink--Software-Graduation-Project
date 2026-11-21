# M2.12-lite plan: secure client, Blueprint theme, three owner-approved fixes

**Status:** approved by the owner 2026-11-21, replacing the full M2.12 plan of 2026-11-14 (features-first schedule, [ROADMAP_8_WEEKS.md](ROADMAP_8_WEEKS.md) week 1). Backend state: `d7d7db0` (M2.11b), 79 routes, 662 tests.

**Deferred to week 7, if time allows:** the per-screen Blueprint redesign (batches 1–5 of the old plan), the shared `dl_*` widget set, ARB files with the complete Arabic translation, RTL and the language switch (UI-2, UI-3, UI-8). Until then the app stays in English and left-to-right. UI-8 is unchanged: when Arabic arrives it becomes the default, and the switch appears only when every screen is translated.

**Sources:** [M2_AUTH_DESIGN.md](M2_AUTH_DESIGN.md) §3.5 (cross-tab refresh), §4.1 (web storage), §5.2 (images), §7.4 (suspension), §9 (F1–F18); [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) (tokens); decisions UI-1, UI-9, and the 2026-11-21 entries in the [decision log](decision-log.md).

## 1. Scope (Batch 0-lite)

| Part | What | Closes |
|---|---|---|
| A | **Auth client** (F1–F5, F7–F13): token in memory, Bearer on every API call, cookie refresh, Web Locks + single-flight, 401/403/suspension handling, logout and logout-everywhere; login, sign-up and reset use the new responses and proof tokens | KI-54 |
| B | **Signed image URLs** (F14–F15): every image comes from the URL the API returns | KI-54 (images) |
| C | **Blueprint theme app-wide:** `ThemeData` from `DESIGN_SYSTEM.md` tokens (colours, radii, typography), bundled IBM Plex fonts. No per-screen redesign | — |
| D | **KI-60:** hide the verified badge entirely (own commit) | KI-60 (until the real badge, with the partner) |
| E | **KI-13:** programmers reach the existing project feed (own commit) | KI-13 |
| F | **KI-56:** no apply button on programmer-owned posts (own commit) | KI-56 |

**Not in scope:** the settings page (change password, connect Google), the notification-page rework (KI-66), the KI-62 document-link screens, P-7's admin screen change, a suspend/unsuspend admin UI (out of scope, owner 2026-11-21). The suspended screen's "Sign out" is the only new screen.

## 2. Rules

- **No product-logic change beyond the auth client and D–F.** D, E and F are the owner-approved exceptions, each in its own commit so the partner can review or revert it alone.
- **Every existing Flutter file is a partner file** (P-6): the partner reviews before the branch is merged.
- **The development fallback stays in the API until M2.13**, but nothing here relies on it: all checks run with `Auth:EnforceAuthorization` on and the fallback off.
- **Dependencies:** none new. Web Locks through `package:web` and `BrowserClient` through `package:http`, both already direct dependencies. The fonts are a `pubspec.yaml` asset change (approved). **Any `pubspec.lock` change stops for the owner's approval.** Restore the generated plugin-registrant files after every `pub get` (KI-30); Flutter 3.47.9 at `C:\flutter-3.47.9`.
- **Commits:** local, one per part (A, B, C) plus one each for D, E and F, after build, tests and both scans pass. No push without the owner's approval.

## 3. Part A: auth client

| File | Change |
|---|---|
| new `lib/services/auth_http.dart` | Drop-in replacement for `package:http`'s top-level `get/post/put/delete` and `send(MultipartRequest)`. Adds `Authorization: Bearer` (token in memory only) and `X-DevLink-Client: web` to every API request, through one `BrowserClient` with `withCredentials = true` so the HttpOnly `devlink_rt` cookie is set by login and sent to `session/refresh` and `session/logout` (its path limits it to those). On 401 `TOKEN_EXPIRED`: one shared refresh (single-flight within the tab, Web Locks across tabs), then the request is retried once. Refresh failure or another 401 code: the session ends and the app returns to the welcome screen with a message. 403 `ACCOUNT_SUSPENDED`: the suspended screen. Any other 403: the caller's normal error, session kept |
| new `lib/services/http/refresh_lock*.dart` (web + io) | `navigator.locks.request('devlink-refresh')`, at most 15 s to get the lock, 10 s for the refresh call. Inside the lock, a tab first checks whether another tab already rotated the token (by comparing generations) so a waiting tab refreshes again rather than reusing a spent cookie |
| new `lib/services/http/browser_client*.dart` (web + io) | `BrowserClient()..withCredentials = true` on web; a plain client elsewhere |
| `lib/services/session_manager.dart` | Holds the access token and expiry **in memory only**. SharedPreferences keeps only non-secret UI values (as today) and never a token |
| `lib/main.dart` | Start-up: `session/refresh` → home for the **server's** role, or the suspended screen, or the welcome page. A global navigator key so `auth_http` can navigate |
| `lib/services/api_service.dart` | `login` / `googleLogin` save the session from the response; `verifyCode` / `verifyResetCode` return `signupToken` / `resetToken`; `signUp` / `resetPassword` send them; new `logout`, `logoutAll`, `me` |
| `post_service`, `support_service`, `notification_service`, `weather_service` | Import swap: `package:http` → `auth_http.dart` (same call signatures) |
| `pages/Common/login_page.dart` | The direct `http.post` to `login` goes through `ApiService.login`, so a token is stored |
| sign-up and reset pages | Carry `signupToken` / `resetToken` from the verify page to the password page |
| logout call sites (4) | `await ApiService.logout()` before the existing navigation; "Sign out everywhere" next to it where a menu exists |
| new `pages/Common/account_suspended_page.dart` | Reason from `Auth/me`, "Contact support" (existing support page), "Sign out" |

**Tests (Flutter, `package:http/testing.dart`, no new package):** T-MT-01 two tabs + lock → two sequential rotations, no reuse; T-MT-02 the same without the lock → the fake server sees reuse; T-MT-03 20 parallel 401s → one refresh; T-MT-04 no Web Locks → refresh refused, no session call; T-MT-05 lock not granted in time → signed out, no refresh sent; suspended, revoked and other-403 handling; no token in SharedPreferences.

## 4. Part B: signed image URLs

Models read `avatarUrl` / `authorImage` / `images[].url` (relative signed paths) and every `Image.network` call site uses them through one helper, `MediaUrl.resolve(path)`. The client never builds an image URL itself. Call sites that have no URL in their data (the four profile-image screens) read it from the profile response's `avatarUrl`.

## 5. Part C: theme

- `lib/theme/devlink_tokens.dart`: the Blueprint light and dark colour tokens, radii and type scale from `DESIGN_SYSTEM.md`.
- `lib/theme/app_theme.dart`: `ThemeData` built from the tokens (explicit `ColorScheme`, component themes for buttons, inputs, cards, chips, dialogs, app bars), IBM Plex Sans + IBM Plex Sans Arabic as the font family.
- `assets/fonts/`: IBM Plex Sans and IBM Plex Sans Arabic, 400–700, with their OFL licences (from `docs/design/mockups/fonts/plex/`, converted to TTF if Flutter can't load WOFF2). `pubspec.yaml` declares them.
- The report counts the hard-coded colours (`Color(0x…)`, `Colors.*`) that remain in screens and clash with the theme. Those are fixed in the week-7 redesign, not now.

## 6. Verification (enforced mode, fallback off)

Synthetic `@example.test` accounts on `DevLink`, after a verified backup:

1. Customer sign-up with the emailed code (console sink), then login.
2. The customer creates a post; the admin approves it.
3. A programmer sees it in the feed (KI-13) and applies; no apply button on a programmer's own post (KI-56); no verified badge anywhere (KI-60).
4. The customer accepts the application.
5. **T-MT-07 (manual):** two tabs open across an access-token expiry; neither is signed out.
6. A suspended account sees the suspended screen and can sign out.

**Screenshots:** 6 key screens in `docs/design/after/b0/` (welcome, login, customer feed, programmer feed, applications, suspended).

## 7. Effort and risks

About 5 working days (week 1). Risks: (1) Flutter web can't load WOFF2 fonts, so they need conversion; (2) the `Secure` refresh cookie on `http://localhost` works in Chromium only because localhost counts as a secure context, so the check must use `localhost`, not `127.0.0.1` (KI-33); (3) partner files change under us: check for partner commits before each part (UI-4).
