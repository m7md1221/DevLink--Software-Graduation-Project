# DevLink UI inventory (before the redesign)

Read from `frontend/lib` on branch `feature/m1-foundation` at `58b7e40`. Nothing in `frontend/` was changed. Line counts come from `wc -l`; occurrence counts come from searches and are approximate where a pattern can match inside comments.

**Size:** 55 Dart files, 26,949 lines. Most of the pages were written by the project partner.

## Screens

| Area | Screen | File under `lib/pages/` | Lines | Before screenshot |
|---|---|---|---|---|
| Common | Welcome and role choice | `Common/welcome_page.dart` | 805 | `before/01_welcome.png` |
| Common | Login | `Common/login_page.dart` | 1139 | `before/02_login_customer.png` |
| Common | Sign-up | `Common/signup_page.dart` | 862 | |
| Common | Verify code | `Common/verify_code_page.dart` | 491 | |
| Common | Set password | `Common/set_password_page.dart` | 582 | |
| Common | Forgot password, reset code, new password | `Common/forgot_password_page.dart`, `reset_verify_page.dart`, `reset_password_page.dart` | 413, 454, 565 | |
| Customer | Home and feed (the same screen) | `Customer/customer_home_page.dart` | 1035 | `before/03_customer_home_feed.png` |
| Customer | Post card | `Customer/widgets/post_card.dart` | 640 | in 03 |
| Customer | Comments sheet | `Customer/widgets/comments_sheet.dart` | 435 | `before/04_post_comments_sheet.png` |
| Customer | Create post | `Customer/create_post_page.dart` | 555 | |
| Customer | Apply to post | `Customer/apply_to_post_page.dart` | 477 | |
| Customer | Post applications | `Customer/post_applications_page.dart` | 484 | |
| Customer | Search users | `Customer/search_users_page.dart` | 328 | `before/05_search.png` |
| Customer | User profile | `Customer/user_profile_page.dart` | 545 | |
| Customer | Contact support | `Customer/contact_support_page.dart` | 609 | `before/06_support_contact.png` |
| Customer | Support messages | `Customer/customer_support_messages_page.dart` | 423 | |
| Customer | Profile setup | `Customer/customer_profile_setup_page.dart` | 1083 | `before/07_profile.png` |
| Customer | Dashboard placeholder | `Customer/dashboard_placeholder_page.dart` | 860 | |
| Programmer | Dashboard | `Programmer/programmer_dashboard_page.dart` | 1559 | `before/08_programmer_dashboard.png` |
| Programmer | Profile setup | `Programmer/programmer_profile_setup_page.dart` | 1464 | |
| Admin | Dashboard (6 module cards) | `admin/admin_dashboard_page.dart` | 996 | `before/09_admin_dashboard.png` |
| Admin | Users, user form | `admin/admin_users_page.dart`, `admin_user_form_page.dart` | 924, 746 | |
| Admin | Add administrator | `admin/admin_add_admin_page.dart` | 1215 | |
| Admin | Posts | `admin/admin_posts_page.dart` | 561 | |
| Admin | Verifications, details | `admin/admin_verifications_page.dart`, `admin_verification_details_page.dart` | 828, 907 | |
| Admin | Support centre | `admin/admin_support_page.dart` | 1050 | |
| Admin | Statistics (fl_chart) | `admin/admin_statistics_page.dart` | 436 | |

The nine screenshots were taken from the running app with the logged development fallback and synthetic data. The API was then restored to enforced mode, and a tokenless Admin call returned 401. They show the dark theme because the app follows the system setting.

**Screens the brief names that do not exist yet:** there is no project details screen (the comments sheet is the nearest thing) and no customer "my projects" dashboard. The Clear Scope wizard, the owner project view and the programmer project list are also absent. These belong to the MVP (`04_UX` S-20, S-22, S-23, S-30, S-33), so the mockups are design targets for them, not restyles of current pages.

## Shared widgets and theme

| File | Purpose | Lines |
|---|---|---|
| `widgets/custom_toast.dart` | Toast messages | 128 |
| `widgets/notification_bell.dart` | Bell and notification list | 221 |
| `widgets/theme_toggle.dart` | Light/dark toggle | 109 |
| `widgets/google_sign_in_button.dart`, `_web.dart` | Google sign-in | 183, 76 |
| `theme/app_theme.dart` | `ThemeData` for light and dark | 198 |
| `theme/theme_manager.dart` | Theme mode; starts from `ThemeMode.system` | 68 |

**ThemeData today:** Material 3, primary `#3B82F6`, secondary `#10B981`, error `#EF4444`, light background `#F1F5F9`, dark background `#0F172A`, dark surface `#1E293B`, card radius 20, input radius 14. `main.dart` sets `home: WelcomePage` and a `NoScrollbarBehavior` that removes scrollbars and overscroll glow, which is an accessibility concern on desktop.

## What the screens do outside the theme

| Measure | Count |
|---|---|
| `Text(` widgets, nearly all with hard-coded English | 432 |
| `Scaffold(` / `AppBar(` | 30 / 10 |
| `showDialog` or `AlertDialog(` | 22 |
| `CircularProgressIndicator` | 39 |
| `DataTable(` | 0 |
| `Colors.white` | 282 |
| `withOpacity` (deprecated) | 383 |
| `#0F172A` / `#10B981` / `#EF4444` / `#8B5CF6` / `#3B82F6` as literals | 122 / 108 / 101 / 97 / 95 |
| `#F1F5F9` / `#1E293B` / `#64748B` / `#334155` / `#94A3B8` / `#F59E0B` as literals | 84 / 82 / 69 / 66 / 61 / 41 |
| Different corner radii | 12 (14 ×114, 12 ×67, 16 ×49, 20 ×41, 18 ×29, 10 ×24, 24 ×23, also 8, 22, 26, 28, 30) |
| Physical `left:` / `right:` | 23 / 43 |
| `EdgeInsets.only(left` / `(right` | 10 / 7 |
| `Alignment.topLeft` / `centerLeft` / `centerRight` | 24 / 9 / 7 |

## Fonts, language and RTL

- There is no `fontFamily` or Google Fonts use, so text falls back to the Flutter default with no bundled Arabic font. The browser console warns "Could not find a set of Noto fonts", and an hourglass emoji shows as an empty box.
- There are no locales, translation files, `Directionality` or `TextDirection`. `web/index.html` has no `lang` or `dir`.
- `flutter_localizations` and `intl` appear in `pubspec.lock` only as indirect dependencies. They are not direct dependencies.
- **Consequence:** Arabic RTL is not a theme change. It needs string extraction and layout changes, screen by screen.

## Packages in `pubspec.yaml`

`cupertino_icons`, `http`, `http_parser`, `image_picker`, `shared_preferences`, `intl_phone_field_v2`, `file_selector`, `url_launcher`, `google_sign_in`, `device_preview` (no use found in `lib`), `fl_chart` (statistics), `pdf`, `printing`, `file_saver`, `geolocator`, `geolocator_web`, `web`.

Assets: `assets/images/background.jpg`, `devlink_logo.png` (blue to cyan), `google_logo.png`.

## Navigation per role

```
Welcome ─ role cards (Admin / Customer / Programmer)
   ├─ LoginPage(userType)
   └─ SignUpPage → VerifyCode → SetPassword → role profile setup

Customer    CustomerHomePage with BottomNavigationBar: Home (feed), Search, Support, Profile
            FAB: Create post. App bar: bell, theme toggle, logout.

Programmer  No profile → ProgrammerProfileSetup, otherwise ProgrammerDashboardPage
            No feed (KI-13); "Coming Soon" areas.

Admin       AdminDashboardPage, 6 module cards opened with Navigator.push:
            Users, Posts, Verifications, Support, Statistics, Add Administrator.
```

Navigation is plain `Navigator` with `http` services. Every route into the feed passes `authorType: 'Customer'`.

## Contrast failures in the current colours

Computed with the WCAG formula.

| Pair | Ratio | Needs |
|---|---|---|
| White on `#F59E0B` | 2.15:1 | 4.5:1 |
| `#94A3B8` on `#F8FAFC` | 2.45:1 | 4.5:1 |
| White on `#10B981` | 2.54:1 | 4.5:1 |
| White on `#3B82F6` | 3.68:1 | 4.5:1 |
| `#64748B` on `#0F172A` | 3.75:1 | 4.5:1 |
| White on `#EF4444` | 3.76:1 | 4.5:1 |
| `#3B82F6` on `#1E293B` | 3.98:1 | 4.5:1 |
| White on `#8B5CF6` | 4.23:1 | 4.5:1 |
| `#64748B` on `#F1F5F9` | 4.34:1 | 4.5:1 |
| Light input border `#E2E8F0` on white | 1.23:1 | 3:1 |
| Dark input border `#334155` on `#0F172A` | 1.72:1 | 3:1 |

## Known issues that touch the UI

| Issue | Location | Effect on the redesign |
|---|---|---|
| KI-60 / P-13 | `Customer/widgets/post_card.dart:292` | The verified badge shows for every programmer author. The feed returns no verification field. `GET` profile returns `isVerified`, applications return `programmerIsVerified`. |
| KI-56 | `Customer/widgets/post_card.dart:231` | The Apply button ignores the post owner's role. |
| KI-46 | Back arrow | Can land on a blank page. |
| KI-59 | Member views | A null email leaves gaps, and the search hint still mentions email. |
| KI-13 | Programmer dashboard | No feed for programmers. |
| KI-34 / P-7 | Add administrator | The screen cannot succeed (API returns 403). Decided after this inventory (UI-9): hidden and replaced by a CLI message. Originally: do not spend redesign effort on it until P-7 is decided. |
