# Redesign implementation plan (not executed)

Applies [DESIGN_SYSTEM.md](../DESIGN_SYSTEM.md) to the Flutter app. Nothing here has been started. No file under `frontend/` has changed, and no package has been added.

**Timing:** implemented together with M2.12, screen by screen, after M2.8–M2.11. The mockups show target screens, and some of their features are not built yet.

## Ground rules

- **No logic changes.** Layout, colour, type, strings and direction only. Services, models and navigation stay as they are, except where M2.12 already changes them.
- **Before and after screenshots** for every screen, in both languages and at both widths, stored in `docs/design/after/`.
- **Each batch is small enough to review.** Every Flutter file is a partner file, so each batch gets partner review (P-6) before merge.
- **Combined with M2.12.** M2.12 (`docs/M2_AUTH_DESIGN.md` §9, F1–F18) touches many of the same files, so the same file is reviewed once. In each batch, the M2.12 logic change is one commit and the visual change another, which keeps the review readable and either one revertible.
- **Order:** steps 1 and 2 start when M2.12 starts, after M2.8–M2.11. Screens from step 3 land with their F-numbered change.
- **Coordination rule (owner):** the partner does not edit the screens being redesigned during the Flutter implementation. Before each screen, check for new partner commits. If any touch the same files, stop and report.

## Step 0: Decisions

| Decision | Outcome |
|---|---|
| Direction A | Approved by the owner and partner, 2026-11-05 |
| Differences in `DESIGN_SYSTEM.md` §10 | Accepted by the owner, 2026-11-05 |
| `flutter_localizations` and `intl` | Approved, to be added only when implementation starts |
| `device_preview` | Left as it is for now |
| Arabic copy | Drafted during implementation; the owner and partner review it in one table before it ships |
| P-7: Add administrator screen | Decided (UI-9): hidden and replaced by a short message that administrators are created via the CLI, in batch 5 |
| UI language | Decided (UI-8): Arabic is the default. The language switch appears only when 100% of screens are translated |
| When the default becomes Arabic | **Open**, owner. Recommendation: at the end of step 3, because an earlier switch shows untranslated screens as English text in an RTL layout |

## Step 1: Foundation

No screen is restyled by hand here, but every screen picks up the new theme, so screenshots of all of them are compared afterwards.

| File | Change |
|---|---|
| `frontend/pubspec.yaml` | Fonts section, the two approved packages, `generate: true` |
| `frontend/pubspec.lock` | Updated by the approved packages |
| new `frontend/assets/fonts/` | IBM Plex Sans Arabic and IBM Plex Sans TTF (400, 500, 600, 700) with their OFL licence files |
| new `frontend/l10n.yaml`, `frontend/lib/l10n/app_en.arb`, `app_ar.arb` | Translation set-up with status glossary only |
| new `frontend/lib/theme/devlink_tokens.dart` | Colours, spacing, radius, type |
| `frontend/lib/theme/app_theme.dart` | Explicit `ColorScheme`, `DevLinkColors` extension, component themes, locale-aware text theme |
| `frontend/lib/main.dart` (partner, shared with F5) | Localization delegates, supported locales, remove `NoScrollbarBehavior`. The locale stays English during step 1; the default becomes Arabic as decided in step 0. |
| `frontend/web/index.html` | `lang` and `dir` |
| new `frontend/test/design/tokens_contrast_test.dart` | Fails if any token pair in `contrast-report.md` drops below its minimum |

**Done when:**

- The app runs in both themes and all existing tests pass.
- Network logs show no font requests. This also settles the open question of whether Flutter web fetches fallback fonts.
- An Arabic test string renders with correct joins, and the app bundle growth has been measured and reported. Only the mockup fonts were measured so far (WOFF2: Arabic about 44 KB and Latin about 24 KB per weight). TTF files are larger.

**Risk:** global changes can make screens with hard-coded colours look wrong until their batch arrives, for example dark text on a new surface. If the result is not acceptable, the new theme stays behind a build flag until batch 1 ends.

## Step 2: Shared widgets

New files only, under `frontend/lib/widgets/dl/`:

| File | Purpose |
|---|---|
| `dl_scaffold.dart` | Bars by width and role, max width, gutters |
| `dl_buttons.dart` | Standard and loading-state buttons |
| `dl_form_field.dart` | Label, helper, error text |
| `dl_status_chip.dart` | The one status mapping table |
| `dl_verified_badge.dart` | Takes a required `bool isVerified`; renders nothing when false; includes the tooltip |
| `dl_evidence_badge.dart` | L0–L3 with text |
| `dl_ledger_row.dart`, `dl_criterion_tile.dart` | The signature elements |
| `dl_money_text.dart`, `dl_date_text.dart` | LTR isolation and locale formatting |
| `dl_empty_state.dart`, `dl_error_state.dart`, `dl_skeleton_list.dart` | States |
| `dl_confirm_dialog.dart` | Confirmations |

Each gets a widget test and golden images at 360 px, in both locales and both themes. Existing `widgets/custom_toast.dart`, `notification_bell.dart` and `theme_toggle.dart` are restyled in batch 1.

## Step 3: Screens

Paths are under `frontend/lib/`. F-numbers refer to M2.12. Every screen in this table is a partner file.

| Batch | Files | M2.12 | Notes |
|---|---|---|---|
| **1. Shell and entry** | `pages/Common/welcome_page.dart`, `widgets/custom_toast.dart`, `widgets/notification_bell.dart`, `widgets/theme_toggle.dart`, `widgets/google_sign_in_button.dart`, `_web.dart` | F6 | First visible result. Bell icon change. Check the Google button against Google's branding rules. |
| **2. Account forms** | `pages/Common/login_page.dart`, `signup_page.dart`, `verify_code_page.dart`, `set_password_page.dart`, `forgot_password_page.dart`, `reset_verify_page.dart`, `reset_password_page.dart`, and new `account_suspended_page.dart` | F7, F8, F9, F11, F18 | Merge with M2.12. Inputs force LTR where needed; paste allowed. |
| **3. Customer** | `pages/Customer/customer_home_page.dart`, `widgets/post_card.dart`, `widgets/comments_sheet.dart`, `create_post_page.dart`, `apply_to_post_page.dart`, `post_applications_page.dart`, `search_users_page.dart`, `user_profile_page.dart`, `customer_profile_setup_page.dart`, `dashboard_placeholder_page.dart`, `contact_support_page.dart`, `customer_support_messages_page.dart` | F10, F15, F17 | Fix KI-60 here, see below. |
| **4. Programmer** | `pages/Programmer/programmer_dashboard_page.dart`, `programmer_profile_setup_page.dart` | F10, F16 | The largest file, at 1559 lines. |
| **5. Admin** | `pages/admin/admin_dashboard_page.dart`, `admin_users_page.dart`, `admin_user_form_page.dart`, `admin_add_admin_page.dart`, `admin_posts_page.dart`, `admin_verifications_page.dart`, `admin_verification_details_page.dart`, `admin_support_page.dart`, `admin_statistics_page.dart` | F10, F15, F16, F18 | Dense tables. Statistics keeps `fl_chart`, recoloured from tokens. Add administrator is hidden and replaced by the CLI message (UI-9). |

**For each screen:**

1. Check for new partner commits, and stop if any touch this screen's files.
2. Take before screenshots.
3. Replace literals with tokens, physical with directional layout, deprecated `withOpacity` with token colours, and spinners and blanks with the shared states.
4. Move strings to ARB in English and draft Arabic, and add them to the Arabic review table.
5. Isolate every number, range, date, email and code value as LTR in Arabic.
6. Take after screenshots in both locales, both widths and both themes.
7. Check at 200% text scale and with a keyboard.
8. Run all tests, and confirm the diff has no logic changes.

**KI-60 / P-13 (verified badge):**

- `post_card.dart:292` switches to `DLVerifiedBadge`.
- The feed has no verification field, so the immediate visual fix is no badge in the feed.
- Showing it for real verified programmers needs a backend change to the feed response. That is separate, in the partner's code (`backend/Services/PostService.cs`), and needs the partner's agreement. It should be done with M2.8 or the feed work.
- KI-56 (Apply ignores the owner's role) is logic, so it is not fixed by the redesign and stays on its own track.

**Not in these batches:** the mockups' project list, project details and customer dashboard do not exist as screens. Those belong to the MVP screens (S-20, S-22, S-23, S-30, S-33) and will be built from the shared widgets when the MVP arrives. Until then, the feed and post card take the new look with their current content.

## Step 4: Language switch

After 100% of screens are translated and the owner and partner have reviewed the Arabic table:

- Add the switch to the top bar and account screen, and store the choice with `shared_preferences`.
- Run golden tests at 360 px in both locales for all screens (spec §4.7).
- Do a final keyboard and screen reader pass.

## Package changes

| Change | Status | Reason |
|---|---|---|
| Add `flutter_localizations` (Flutter SDK) as a direct dependency | Approved, added at step 1 and not before | Arabic Material text, RTL direction and date pickers |
| Add `intl` as a direct dependency | Approved, added at step 1 and not before | Generated translations, plurals, number and date formats. Already in the lockfile indirectly; the version must match what `flutter_localizations` pins. |
| `device_preview` | Left as it is | No use found in `lib`; no effect on the redesign |

**Not proposed:** `google_fonts` (fonts are bundled so there is no runtime fetching), `data_table_2` (start with Flutter's own table), icon or skeleton packages.

The KI-24 and KI-30 Flutter SDK and lockfile concerns should be resolved before step 1 changes `pubspec.lock`.

## Size and risk

| Risk | Effect | Response |
|---|---|---|
| String extraction is most of the work: 432 `Text(` widgets, plus labels, hints and messages | Arabic takes far longer than the visual change | Do it within each batch, and keep the switch hidden until complete |
| 11 files exceed 900 lines, and literals appear everywhere | Large diffs that are hard to review | Small batches; split visual-only commits; extract widgets only where it reduces duplication and logic is untouched |
| Conflict with M2.12 and partner work | Rework | Agree order per batch; merge often |
| RTL bugs from physical positioning | Broken Arabic layouts | Search check for `left:`, `right:`, `EdgeInsets.only`, `topLeft` before each batch closes; golden tests |
| Theme change makes old screens look mixed | Temporary inconsistency | Build flag if needed; batch 1 shows the shell first |
| Bundle size from fonts | Slower first load on low bandwidth | Measure in step 1; consider subset weights |
| Audience reaction not tested | A may feel cold to customers | Show mockups to 3–5 real customers and programmers before batch 1, if the owner agrees |
