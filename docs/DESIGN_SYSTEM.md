# DevLink design system: Mukhatat / Blueprint

**Status:** approved by the owner and partner on 2026-11-05. Nothing here is implemented yet.
**For:** whoever builds the Flutter UI, and the project partner reviewing it.
**See it:** [design/mockups/index.html](design/mockups/index.html). **Why this direction:** [design/DIRECTIONS.md](design/DIRECTIONS.md). **How to build it:** [design/IMPLEMENTATION_PLAN.md](design/IMPLEMENTATION_PLAN.md).

> **The mockups show target screens, not the current app.** Some features they show are not built yet, including acceptance criteria, evidence levels and applicant comparison. Those belong to the MVP, and the redesign does not add them. Until then, current screens take this look with their current content.

## 1. Idea

The brief is the product. DevLink should feel like a clear, well-prepared agreement on good paper: calm ink, warm background, thin lines and numbered requirements that anyone can check.

Four principles decide most questions:

1. **Scope first.** Requirements and their count are visible wherever a project appears.
2. **Say only what is true.** No badge, word or colour may imply more than DevLink actually checked. DevLink does not process payments, so nothing may suggest that it does.
3. **Plain before clever.** A non-technical customer should understand every screen. One filled button per view.
4. **Both languages are first-class.** A layout is finished only when it works in Arabic RTL and English.

## 2. Colour tokens

Use tokens only. Never put a hex value or `Colors.white` in a screen.

| Token | Flutter role | Light | Dark | Use |
|---|---|---|---|---|
| `bg` | `colorScheme.surface`, scaffold | `#F7F6F2` | `#0F1B26` | Page |
| `surface` | `surfaceContainerLowest` | `#FFFFFF` | `#162533` | Cards, inputs, bars |
| `surface2` | `surfaceContainerHigh` | `#EFEDE6` | `#1E3040` | Notices, meter track, hover |
| `ink` | `onSurface` | `#14273A` | `#EAF0F4` | Main text |
| `muted` | `onSurfaceVariant` | `#4F5D6B` | `#A9B8C4` | Secondary text |
| `line` | `outlineVariant` | `#D9D6CC` | `#2C4052` | Decorative hairlines only |
| `control` | `outline` | `#7D8388` | `#6F8497` | Borders that identify a control |
| `primary` | `primary` | `#0E5A83` | `#7CC4EA` | Main action, links, focus |
| `onPrimary` | `onPrimary` | `#FFFFFF` | `#06283C` | Text on primary |
| `primaryC` | `primaryContainer` | `#DCECF5` | `#123F59` | Tonal button, info chip, verified badge |
| `onPrimaryC` | `onPrimaryContainer` | `#0A3E5B` | `#CFE8F6` | Text on `primaryC` |
| `accent` | `tertiary` | `#A0500A` | `#E6AC63` | One small highlight per view |
| `accentC` | `tertiaryContainer` | `#FAEBD9` | `#43300F` | Accent chip |
| `onAccentC` | `onTertiaryContainer` | `#6E3706` | `#F6DDBA` | Text on `accentC` |
| `danger` | `error` | `#B3261E` | `#F2A19B` | Field errors, destructive action |
| `onDanger` | `onError` | `#FFFFFF` | `#4A0F0B` | Text on danger |
| `dangerC` | `errorContainer` | `#FBE4E2` | `#4A1D1A` | Danger chip |
| `onDangerC` | `onErrorContainer` | `#7E1A15` | `#FAD7D3` | Text on `dangerC` |

These have no Material role, so they live in `ThemeExtension<DevLinkColors>`:

| Token | Light | Dark | Use |
|---|---|---|---|
| `success` | `#1A6B45` | `#6FCF9D` | Met-requirement mark |
| `successC` / `onSuccessC` | `#DDF0E6` / `#114A30` | `#123D2A` / `#C4EFD8` | Success chip |
| `warning` | `#855000` | `#E9B45C` | Attention bar on a row |
| `warningC` / `onWarningC` | `#FBEBCC` / `#5C3700` | `#43300C` / `#F7E0B5` | Warning chip, reviewer's note |
| `neutralC` / `onNeutralC` | `#E9E7E0` / `#3C4955` | `#263A4B` / `#CBD6DE` | Neutral chip |

Every pair used is computed in [design/contrast-report.md](design/contrast-report.md). The lowest text pair in either theme is `#A0500A` on `#F7F6F2` at 5.33:1. The lowest control pair is `#7D8388` on `#EFEDE6` at 3.27:1.

**Build the `ColorScheme` explicitly.** `ColorScheme.fromSeed` may not keep the seed colour and would produce untested pairs. Set `surfaceTint` to transparent, so Material does not tint raised surfaces.

```dart
const lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF0E5A83), onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFDCECF5), onPrimaryContainer: Color(0xFF0A3E5B),
  secondary: Color(0xFF4F5D6B), onSecondary: Color(0xFFFFFFFF),
  tertiary: Color(0xFFA0500A), onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFFAEBD9), onTertiaryContainer: Color(0xFF6E3706),
  error: Color(0xFFB3261E), onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFBE4E2), onErrorContainer: Color(0xFF7E1A15),
  surface: Color(0xFFF7F6F2), onSurface: Color(0xFF14273A),
  onSurfaceVariant: Color(0xFF4F5D6B),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerHigh: Color(0xFFEFEDE6),
  outline: Color(0xFF7D8388), outlineVariant: Color(0xFFD9D6CC),
  surfaceTint: Colors.transparent,
);
```

The remaining surface containers (`Low`, the default, `Highest`) must also be set when the theme is written, or Material derives them. The token test in step 1 of the plan covers this.

## 3. Typography

**Families (SIL Open Font License, bundled in the app):** IBM Plex Sans Arabic and IBM Plex Sans, weights 400, 500, 600, 700. No network font loading.

- In the Arabic locale, the family is Plex Arabic with Plex Sans as fallback.
- In the English locale, the family is Plex Sans with Plex Arabic as fallback, so Arabic names and text in English screens still render well.

| Style | Flutter role | Size | Latin line height | Arabic line height | Weight |
|---|---|---|---|---|---|
| Display large (welcome hero, wide only) | `displayMedium` | 44 | 53 | 60 | 600 |
| Display (page title) | `displaySmall` | 32 | 40 | 45 | 600 |
| Headline | `headlineSmall` | 24 | 32 | 36 | 600 |
| Title (card and section) | `titleMedium` | 18 | 26 | 30 | 600 |
| Body | `bodyLarge` | 16 | 24 | 28 | 400 |
| Body small | `bodyMedium` | 15 | 22 | 26 | 400 |
| Label (buttons, tabs, table text) | `labelLarge` | 14 | 20 | 24 | 500–600 |
| Caption (chips, meta) | `bodySmall` | 13 | 18 | 22 | 400–500 |

On phones, the page title is 26 and the hero is 32.

**Rules**

- Letter-spacing is 0 for all Arabic. Material's default `TextTheme` has non-zero spacing, so override every style. Spacing breaks the joins between Arabic letters.
- No italics, underlined headings or all-capitals, because Arabic has none of these and the two languages should match.
- Budget amounts and numbers use tabular figures with weight 600–700.
- Western digits in both languages for this version. Check what `intl` outputs for `ar`, and force Western digits if it produces Arabic-Indic ones. Arabic-Indic digits can be offered later after native review.

## 4. Spacing, layout, radius, elevation

| Spacing | `xs` | `sm` | `md` | `lg` | `xl` | `2xl` | `3xl` |
|---|---|---|---|---|---|---|---|
| dp | 4 | 8 | 12 | 16 | 24 | 32 | 48 |

| Width | Gutter | Navigation | Layout |
|---|---|---|---|
| Below 720 | 16 | Bottom bar | One column; side panels move below their content, and the summary card comes after the project title |
| 720–899 | 24 | Top bar | One column |
| 900 and up | 32 | Top bar (admin: rail) | Main column plus a 280–320 side panel |

Content width is at most 1200.

| Radius | dp | Use |
|---|---|---|
| `xs` | 4 | Number chip, meter |
| `sm` | 6 | Buttons, inputs, chips, notices |
| `md` | 8 | Cards, ledgers |
| `lg` | 12 | Dialogs, bottom sheets |
| Full | | Avatars only |

| Elevation | Use | How |
|---|---|---|
| 0 | Cards, rows, panels, bars | Flat, with a 1 dp `line` border. This is the default. |
| Menu | Menus, dropdowns | Material default, with `surfaceTint` transparent |
| Dialog | Dialogs, sheets | Material default, with a scrim |

Never use a shadow to separate a card. Use a line.

## 5. Signature elements

**Numbered criterion** (`DLCriterionTile`). A 28 dp square with a 1 dp `control` border and a 4 dp radius holds the number in `primary`. Text sits beside it, and items are separated by dashed `line` rules. A met requirement has a filled `primary` chip, and the text never relies on colour alone. This is one component with the modes the spec lists: edit, respond, claim, review.

**Requirement count.** Plain text on every project row: "6 requirements" / "6 متطلبات واضحة". Use no squares, dots or other marks for the count. Marks beside a price read as a rating or a progress meter, and a legend would only repeat the number the text already gives.

**Ledger** (`DLLedgerRow`). Rows in one outlined card, separated by 1 dp lines. The main side holds title, meta and excerpt. The end side holds budget or status. On phones the sides stack. A row needing action has a 4 dp `warning` bar on its start edge, with a warning chip and a plain message.

**Summary card.** Label and value rows separated by dashed lines, then the one filled button, the owner, and the payment notice.

**Payment notice.** Wherever money is discussed: "DevLink does not process payments. You agree the amount and pay each other directly." It uses `surface2` with an info icon. Never use "secured", "protected" or "guaranteed" about payment.

## 6. Components

Widgets live in `lib/widgets/dl/`, with the names from spec §4.2.

### Buttons

Minimum height 48, radius 6, label 600.

| Type | Look | Use |
|---|---|---|
| Filled | `primary` on `onPrimary` | The one main action of the view |
| Tonal | `primaryC` on `onPrimaryC` | Secondary action |
| Outlined | `primary` text, `control` border | Alternative action |
| Text | `primary` text | Tertiary action, with at least 48 tall hit area |
| Danger outlined | `danger` text and border | Destructive action on a normal screen |
| Danger filled | `danger` on `onDanger` | Only inside a confirmation dialog |

When loading, a spinner replaces the label, the width stays the same and the button is disabled. Labels name the action ("Apply with your plan", not "Submit"). Disabled buttons need a reason nearby.

### Inputs

- Label above the field, never placeholder-only. Helper text states limits ("10–120 characters").
- Height at least 48, `surface` fill, 1 dp `control` border, 6 radius.
- Focus: 2 dp `primary` border. Error: 2 dp `danger` border plus message with an icon below, using `Semantics(liveRegion: true)`.
- Validate on blur and on submit. Server errors map to fields. A general error is a banner at the top of the form, and focus moves there.
- Force LTR in email, password, URL, code and phone fields, while the label stays in the page's direction.
- Allow paste and password managers in sign-in and verification code fields (WCAG 3.3.8).
- Keep what the person typed after an error (WCAG 3.3.7).

### Cards and rows

`surface` fill, 1 dp `line` border, 8 radius, no shadow, 16–20 padding. A whole row is one tap target; do not nest a second tappable element without its own 48 dp target. Hover uses `surface2`. Keyboard focus shows the ring.

### Status chips (`DLStatusChip`)

Always icon + label + colour, from one mapping table. Caption size, 6 radius, not tappable.

| Status | English | Arabic | Kind | Icon |
|---|---|---|---|---|
| Draft | Draft | مسودة | Neutral | Document |
| Under review | Under review | قيد المراجعة | Info | Clock |
| Changes requested | Changes requested | مطلوب تعديلات | Warning | Alert |
| Open | Open | مفتوح | Success | Check |
| In progress | In progress | قيد التنفيذ | Info | Clock |
| Completed | Completed | مكتمل | Success | Check |
| Cancelled | Cancelled | ملغى | Neutral | Cross |
| Closed | Closed | مغلق | Neutral | Lock |
| Removed, suspended | Removed / Suspended | To confirm in the Arabic review table | Danger | Alert |

### Verification badge (`DLVerifiedBadge`)

**Show the badge only when the server says this programmer is verified.**

| Rule | Detail |
|---|---|
| **Data** | Show only for a true server field: `isVerified` on the profile, `programmerIsVerified` on applications. |
| **Never derive it** | Never from `authorType`, role, level, profile completeness or a cached guess. This is the defect in KI-60 (`post_card.dart:292`). |
| **Missing field** | No field means no badge. The feed returns no verification field today, so the feed shows no badge until the field exists (P-13). |
| **Who** | Programmers only, never customers or admins. |
| **Not verified** | Show nothing in public views. No grey badge or "Not verified" label; an early-career programmer's card must look complete. Admin screens show the verification state as a normal status chip. |
| **Look** | `primaryC` fill, `onPrimaryC` text, badge icon plus the word "Verified" / "موثّق". The icon never appears alone. |
| **Explains itself** | Tooltip or tap, reachable by keyboard: "Identity and selected evidence reviewed by DevLink admins — not a skills guarantee". The accessible label includes the full text. |
| **Icon reserved** | The verified icon means only this. `widgets/notification_bell.dart:57` uses `Icons.verified_rounded` for approvals, and that should change to a plain check. |
| **Wrong copy** | Never "Top rated", "Guaranteed" or "Trusted". |

### Evidence level (`DLEvidenceBadge`)

An outlined chip, always with its meaning: "L0 · Self-declared", "L1 · Link provided", "L2 · Admin-reviewed", "L3 · DevLink-verified". Evidence belongs to one item of proof, and the verified badge belongs to the person, so they appear separately and are never merged. The same definition text is used everywhere (S-32).

### Tables (admin, compare)

Sticky header on `surface2`, 1 dp row lines, rows at least 48 tall, status as chips, numbers aligned to the end. A row tap opens details. Sorting is announced to screen readers. Horizontal scrolling stays inside the table's container, never the page. Below 720, use ledger rows if the table has few important columns.

### Dialogs (`DLConfirmDialog`)

Radius 12, maximum width 480. The title is the question ("Withdraw this application?"). The body gives the consequence. Buttons use verbs ("Withdraw", "Keep it"). Focus stays inside, and Esc closes unless a submit is in progress. Destructive dialogs use a filled danger button and may need a reason. Use dialogs for confirmations in spec §4.6, not for messages.

### Navigation

| Role | Wide bar | Phone bottom bar |
|---|---|---|
| Customer | My projects, Find programmers, Messages, Help | My projects, Programmers, Messages, Account |
| Programmer | Find projects, My applications, Evidence, Messages | Projects, Applications, Messages, Account |
| Admin | Rail: Users, Posts, Verifications, Support, Statistics | Drawer |

- The target bars above include MVP screens. Until a screen exists, its item stays hidden, with no "Coming soon" tabs.
- Language, notifications and account sit at the end of the top bar.
- The active item uses colour, weight and a marker, so colour is not the only signal.
- Help stays in the same place on every screen (WCAG 3.2.6).
- `AppBar`: `surface`, 1 dp `line` at the bottom, no tint when scrolled.

### Empty, loading and error states

| State | Rule | Example |
|---|---|---|
| **Empty** (`DLEmptyState`) | Title says what is absent, body says what appears here and how, plus one action. Dashed `line` border. | "No past projects yet. Finished projects and their reviews appear here." |
| **Loading** (`DLSkeletonList`) | Skeleton rows the shape of the real content. Never "No records" during loading. A small spinner is for buttons and short waits. No pulsing when `MediaQuery.disableAnimations` is on. | |
| **Error** (`DLErrorState`) | What happened, what to do, a Retry button. Show a trace id if the server gives one, and never raw exception text. Do not blame the person. | "We couldn't load your projects. Check your connection and try again." |
| **No permission** | Say what this account can't do and where to go. | |
| **Toast** | Only for confirming something finished. Errors stay on screen. Announce with a live region. | |

## 7. RTL rules

**Layout**

- Use only directional APIs: `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `BorderRadiusDirectional`, `BorderDirectional`, `TextAlign.start` / `end`. Physical `left` or `right` fails review.
- Lists, tabs, steppers, progress bars and the attention bar all mirror.
- The app's direction comes from the locale. Do not wrap screens in `Directionality` except for the LTR cases below.

**Icons**

| Mirror | Do not mirror |
|---|---|
| Back and forward arrows, chevrons, Send, "next" arrows, list-with-text icons | Checkmarks, clock, search, bell, plus, media playback, logos, the `{ }` mark |

Material's back and forward icons mirror by themselves. For custom icons, use `Transform.flip` based on `Directionality.of(context)`.

**Mixed content**

**Rule: money, numbers, ranges, dates, emails and code are always isolated as LTR inside RTL text.** The same applies to URLs, phone numbers, file names and version strings. A value must never rely on the surrounding text for its order, because without isolation the bidirectional algorithm can show `$300–500` as `500–$300`.

| Value | Arabic text | Must display |
|---|---|---|
| Money range | الميزانية: `$300–500` | `$300–500`, with `$` on the left |
| Count of total | المتطلبات المنجزة: `3/8` | `3/8` |
| Date | التسليم: `2026-11-05` | `2026-11-05` |
| Email | البريد: `name@example.test` | `name@example.test` |

In Flutter, prefer Unicode isolates for a value inside a sentence, because it wraps and selects as normal text. `DLMoneyText` and `DLDateText` apply this, and translated strings use them through placeholders.

```dart
// Inline: LRI (U+2066) before the value, PDI (U+2069) after it.
String ltr(String value) => '\u2066$value\u2069';
Text('الميزانية: ${ltr(r'$300–500')}');

// A value on its own, such as an amount on a summary card.
Text(r'$300–500', textDirection: TextDirection.ltr);

// A value in rich text. TextSpan has no direction of its own, so use an isolate or a WidgetSpan.
Text.rich(TextSpan(children: [
  const TextSpan(text: 'الميزانية: '),
  WidgetSpan(child: Directionality(
    textDirection: TextDirection.ltr,
    child: Text(r'$300–500'),
  )),
]));
```

Every isolated value gets a golden or widget test in the Arabic locale. The web mockups apply the same rule with `<bdi dir="ltr">`, and the screenshot script fails if an isolated value is reordered or a number is left unisolated.

- User-written text can be in either language, so detect its direction from the content (`Bidi`), not from the app locale.

**Language**

- Translations live in ARB files, one key per string, with no building sentences from fragments. Arabic plural forms (zero, one, two, few, many, other) use ICU messages: "4 متقدمين", "رسالتان".
- Arabic text often runs longer or shorter than English, so use flexible widths, wrapping and `start` alignment. Do not fix a width to fit one language.
- Status names come only from the glossary above. Arabic copy must be written or reviewed by a native speaker before release (spec §4.8). The Arabic in the mockups is a draft. The owner and partner review all Arabic copy in one table before it ships.

## 8. Accessibility rules

Target: WCAG 2.2 AA.

| Criterion | Rule here |
|---|---|
| 1.4.3 Contrast | Text at least 4.5:1, using the tokens. A test checks every pair in both themes. |
| 1.4.11 Non-text contrast | Control borders, focus rings and meaningful icons at least 3:1. `line` is for decoration only, because it does not reach 3:1. |
| 1.4.1 Use of colour | Status always has icon and words. |
| 1.4.4 / 1.4.10 Resize and reflow | Works at 200% text scale and 360 px wide. Use minimum heights, not fixed ones. No page-level horizontal scroll. |
| 2.1.1 Keyboard | Everything works by keyboard. Tooltips open on focus. |
| 2.4.7 / 2.4.11 Focus | Visible ring on every control, not hidden under sticky bars. |
| 2.5.7 Dragging | Every drag has a tap alternative, for example reordering requirements. |
| 2.5.8 Target size | The WCAG minimum is 24×24. DevLink's rule is at least 48×48 dp, including icon buttons. |
| 3.2.6 Consistent help | Help is in the same place on every screen. |
| 3.3.7 / 3.3.8 Forms and sign-in | Do not ask twice for the same information. Allow paste and password managers. |
| 4.1.2 Name, role, value | Icon-only controls have labels. Headings use `Semantics(header: true)`. Live regions announce errors. |

**Also**

- Remove `NoScrollbarBehavior` from `main.dart`, so desktop users can see where they are.
- Set `lang` and `dir` on the web page to follow the locale.
- Respect `MediaQuery.disableAnimations`.
- Test each screen with a keyboard and with a screen reader (NVDA on web, TalkBack on Android) in both languages.

## 9. Do and don't

| Do | Don't |
|---|---|
| Show "6 requirements" as text on a project row | Show a project with a budget and no sign of its scope |
| Show the badge from `programmerIsVerified == true` | Show the badge because `authorType == 'Programmer'` |
| Leave an unverified programmer's card without a badge | Add a grey "Not verified" label |
| Write "Verified" with a tooltip saying what was reviewed | Write "Trusted expert" or "Guaranteed" |
| Write "You agree the amount and pay each other directly" | Write "Secure payment" or "Protected" |
| Use one filled button per view | Put Apply, Save and Share all in filled blue |
| Separate cards with a 1 dp line | Add shadows or gradients to cards |
| Use `theme.colorScheme.primary` | Use `Color(0xFF0E5A83)` or `Colors.blue` in a screen |
| Use `EdgeInsetsDirectional.only(start: 16)` | Use `EdgeInsets.only(left: 16)` |
| Isolate `$300–500` as LTR inside Arabic | Put a bare range into an RTL sentence, where it can show as `500–$300` |
| Write the requirement count in words | Use squares or dots for the count beside a price |
| Write "Use 10–120 characters" | Write "You entered an invalid title" |
| Say "No past projects yet" with an explanation | Show a blank area, or "No records" while loading |
| Use accent for one highlight in a view | Use accent as a status colour |
| Set letter-spacing 0 for Arabic | Inherit Material's letter-spacing in Arabic |

## 10. Differences from the product spec (`04_UX` §4)

Accepted by the owner on 2026-11-05.

| Item | Spec | Here | Reason |
|---|---|---|---|
| Primary colour | Suggested seed `#1F5FBF`; "final choice is the team's" | `#0E5A83`, explicit scheme, no seed | Calmer with the paper background; the exact ratios are the ones checked |
| Radius | 8, 12, 16 | 6, 8, 12, plus 4 for number chips | Part of the precise look |
| Evidence levels | L0 outline, L1 info, L2 secondary, L3 success | All outlined, with the same text | Coloured chips would compete with status chips, and L1 blue would look like the verified badge |
| Caption | 12/16 | 13/18 | 12 is small for Arabic |
| Arabic line height | +10% | About +15–17% for body (28 on 16) | Starting point from research and the mockups, for native review |
| "All" tab | Not listed for S-20 | Added before Drafts | Gives the mixed attention-first view shown in the mockup |
| Tables | Mentions `DataTable2`-style | Flutter's own table first | No new package unless a screen proves it necessary |
| Everything else | | Same | Tokens for spacing, gutters, max width, forms, buttons, glossary, widgets, RTL rules follow the spec |
