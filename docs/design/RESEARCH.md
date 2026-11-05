# Research notes for the DevLink redesign

Sources are split by how much they can be trusted here. **Read** means the page itself was fetched and read. **Snippet** means only a search result excerpt was seen, so the claim is a starting point and not an established fact. No logo, colour or asset was taken from any product named below.

## What the research changed

| Finding | Design consequence |
|---|---|
| A verified badge usually proves identity, not quality, and Contra's badge means a linked bank account. | DevLink's badge says exactly what was reviewed. Evidence levels are shown separately. |
| Mostaql's project page leads with status, budget, duration and skills, and its offer list carries "هوية موثقة". Arab customers and freelancers already know this pattern. | Keep the budget, duration and badge vocabulary familiar. Compete on the visible scope. |
| Mostaql's project rows in the fetched text show title, excerpt, poster, time and offer count, with little about what "done" means. | The acceptance criteria become the identity: numbered rows, a requirement count on every project row. This is DevLink's real difference. |
| Linear reduced chrome colour, kept neutrals calm and raised hierarchy through density and structure. | Use one primary colour and hairlines, with almost no shadows. |
| `ColorScheme.fromSeed` may not keep the seed colour. | Define an explicit `ColorScheme`, so the checked contrast ratios are the ones that ship. |
| Empty and loading states mislead when they are bare. | Each empty state says what will appear and offers the next step. Loading never shows "No records". |
| Arabic text needs zero letter-spacing and more line height than Latin. | Letter-spacing 0 in Arabic, with a line height of about 1.75 for body text. Native reviewer confirms it. |
| Numbers, code, URLs, media controls and checkmarks are not mirrored. | Directional icons are mirrored by an explicit list. Money stays LTR inside RTL text. |

## Read directly

**Accessibility (W3C)**

- [Contrast (Minimum), 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html): AA is 4.5:1, or 3:1 for large text (18pt, or 14pt bold).
- [Non-text Contrast, 1.4.11](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html): AA is 3:1 for control boundaries and meaningful graphics. Disabled controls are exempt.
- [Target Size (Minimum), 2.5.8](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html): AA is 24×24 CSS px, with exceptions.
- [What's new in WCAG 2.2](https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/): new AA criteria are 2.4.11, 2.5.7, 2.5.8 and 3.3.8. New A criteria are 3.2.6 and 3.3.7.

**Flutter**

- [`ThemeExtension`](https://api.flutter.dev/flutter/material/ThemeExtension-class.html): custom theme values, implementing `copyWith` and `lerp`.
- [`ColorScheme.fromSeed`](https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html): tonal palettes; "the seedColor may not wind up as one of the ColorScheme colors"; explicit parameters override.

**Product and UX**

- [Nielsen Norman Group, empty states](https://www.nngroup.com/articles/empty-state-interface-design/) (Kaplan, 2021): do not default to totally empty. Say what could appear and how, offer direct pathways, show progress while loading.
- [Linear, how we redesigned the UI](https://linear.app/now/how-we-redesigned-the-linear-ui): less visual noise, hierarchy and density, neutral and timeless, limited chrome colour.
- [Contra, identity verified badge](https://contra.com/blog/what-is-contra-s-identity-verified-badge): the badge means a bank account is linked, and it is applied automatically.
- [Mostaql project list](https://mostaql.com/projects) and [a Mostaql project](https://mostaql.com/project/345204): row and project card structure, owner hiring rate, offers with an identity badge.

**Fonts**

- `ofl/ibmplexsansarabic`, `ofl/readexpro` and `ofl/alexandria` exist in the google/fonts repository.
- The `LICENSE` file in each `docs/design/mockups/fonts/` folder reads "SIL Open Font License, Version 1.1". Those files come from the @fontsource 5.3.0 packages.

## Snippets only (lower confidence)

**Bidirectional layout**

- [Material bidirectionality (M1)](https://m1.material.io/usability/bidirectionality.html): back and forward mirror; media controls and keyboards do not.
- [Mozilla RTL guidelines](https://firefox-source-docs.mozilla.org/code-quality/coding-style/rtl_guidelines.html): symmetric icons, checkmarks, media controls and logos are not flipped.
- [Wikimedia T300053](https://phabricator.wikimedia.org/T300053): text and numbers are never mirrored.

**Arabic typography** (informal sources; treat line height of about 1.8 as a starting point)

- [Dubai design system typography](https://designsystem.dubai.ae/foundations/typography)
- [Design system notes on typography](https://design-system-ew5.pages.dev/typography)
- [Freezil Arabic typography guide](https://freezil-website-wjfnk.kinsta.page/blog/arabic-typography-guide.html)
- [HackerNoon on Arabic websites](https://hackernoon.com/design-arabic-websites-with-consistent-fonts-optimal-sizes-and-culturally-aligned-images)

**Trust in marketplaces**

- [What a verified badge means](https://www.makeinfluence.com/en/academy/what-does-a-verified-creator-badge-on-a-marketplace-actually-mean): identity, not quality; show them separately.
- [Building trust in the gig economy](https://vidhi-mishra.squarespace.com/projects/building-trust-in-the-gig-economy): payment verification, responsiveness, project clarity. This is a portfolio piece, so use with caution.
- [Provider profile optimisation](https://directorism.vercel.app/resources/provider-profile-optimization): trust signals above the fold.

**Empty states and theming**

- [SAP Fiori empty states](https://www.sap.com/design-system/fiori-design-web/v1-120/foundations/best-practices/global-patterns/designing-for-empty-states): headline, description, action; translated text grows.
- [Carbon empty states](https://carbondesignsystem.com/patterns/empty-states-pattern/)
- [Custom design tokens with ThemeExtension](https://startdebugging.net/2026/10/how-to-define-custom-design-tokens-with-themeextension-in-flutter/)
- [IBM Plex Sans Arabic on Fontsource](https://fontsource.org/fonts/ibm-plex-sans-arabic/about)

## Gaps

- **Upwork was not inspected.** Its page returned 403. Upwork and Contra list layouts were not seen, so nothing here rests on them.
- **Material 3 pages did not load** (m3.material.io colour pages, m2.material.io bidirectionality). The M3 mapping relies on the Flutter API docs and the project spec.
- **Google Fonts licence pages returned no body.** The licence was checked from the LICENSE files instead.
- **No user testing.** No customer or programmer has seen these mockups, and the audience reasoning in [DIRECTIONS.md](DIRECTIONS.md) is judgement.
- **Arabic copy has had no native review.** The product spec requires it before release.
- **Flutter font behaviour on web is unverified.** Whether the web engine still fetches fallback fonts at runtime when glyphs are missing has to be checked in step 1 of the plan.
