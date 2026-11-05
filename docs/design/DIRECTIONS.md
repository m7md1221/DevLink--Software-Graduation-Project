# Three visual directions and the choice

**Choice: A, Mukhatat / Blueprint, approved by the owner and partner on 2026-11-05.** It turns DevLink's real difference, a clear and checkable scope, into the look of the product. It also has the lowest Flutter cost and works with the existing logo. The reasoning is at the end of this file.

The mockups show target screens, not the current app. Acceptance criteria, evidence levels and applicant comparison are among the features not built yet.

All three share the same synthetic content, screens and accessibility checks, so differences come from the design. Open [mockups/index.html](mockups/index.html) to browse them. Every direction has 4 screens, in English and Arabic RTL, at desktop (1280 px) and phone (390 px) width.

Automated checks on the final build: 56 captures, no horizontal overflow, fonts loaded, no target below 24 px, no external requests. All 112 colour pairs pass ([contrast-report.md](contrast-report.md)). All mockup fonts are served locally. The bottom navigation is drawn at the end of the page in phone captures because a fixed bar would land mid-page in a full-page capture.

The brief's four screens do not include a full profile page. Profiles and badges appear as applicant cards on each project details mockup; the rest of each profile description below is design intent.

## A. Mukhatat / Blueprint (مخطط)

**Mood:** a well-prepared brief on good paper. Calm, exact, adult. It feels like a contract you can understand.

| | |
|---|---|
| **Fonts** | IBM Plex Sans Arabic + IBM Plex Sans (OFL). Already suggested by the spec. |
| **Shape** | 4 number chips, 6 controls and chips, 8 cards. Hairlines, no shadows. |
| **Density** | Comfortable, with ledger rows and dashed rules. |
| **Icons** | Outline, 1.7 stroke, rounded ends. |
| **Motif** | Numbered criteria, dashed rules. |
| **Project cards** | Ledger rows: title and problem on one side; budget, requirement count in words and hire history on the other. |
| **Profiles** | Delivery record first. Evidence level as an outlined chip that states its meaning. |
| **Trust badges** | Small tinted "Verified" badge for verified programmers only. Evidence levels are separate. |
| **Dashboard** | Status tabs with counts, rows needing action first with a warning bar and the reviewer's note, plus a next-steps panel. |

| Role | Light | Ratio | Dark | Ratio |
|---|---|---|---|---|
| Page / text | `#F7F6F2` / `#14273A` | 14.06 | `#0F1B26` / `#EAF0F4` | 15.16 |
| Card / secondary text | `#FFFFFF` / `#4F5D6B` | 6.75 | `#162533` / `#A9B8C4` | 7.68 |
| Primary / label | `#0E5A83` / `#FFFFFF` | 7.48 | `#7CC4EA` / `#06283C` | 7.95 |
| Accent on card | `#A0500A` | 5.76 | `#E6AC63` | 7.76 |
| Control outline on card | `#7D8388` | 3.84 | `#6F8497` | 4.03 |
| Success chip | `#114A30` on `#DDF0E6` | 8.64 | `#C4EFD8` on `#123D2A` | 9.66 |
| Warning chip | `#5C3700` on `#FBEBCC` | 8.92 | `#F7E0B5` on `#43300C` | 9.77 |
| Danger chip | `#7E1A15` on `#FBE4E2` | 8.46 | `#FAD7D3` on `#4A1D1A` | 10.61 |

Screenshots are in `mockups/screenshots/`:

- Welcome: `a-blueprint-en-welcome-desktop.png`, `a-blueprint-ar-welcome-desktop.png`
- Project list: `a-blueprint-en-projects-desktop.png`, `a-blueprint-ar-projects-desktop.png`
- Project details: `a-blueprint-en-project-desktop.png`, `a-blueprint-ar-project-phone.png`
- Customer dashboard: `a-blueprint-en-dashboard-desktop.png`, `a-blueprint-ar-dashboard-desktop.png`
- Dark: `a-blueprint-en-projects-dark-desktop.png`, `a-blueprint-ar-dashboard-dark-phone.png`

## B. Zaytoun / Olive and Clay (زيتون)

**Mood:** a conversation with someone local. Warm, human, rooted in the region.

| | |
|---|---|
| **Fonts** | Readex Pro for Arabic and Latin (OFL). One family, soft and friendly. |
| **Shape** | Pill buttons and chips, 24 px cards, soft bands. |
| **Density** | Airy, with big type. |
| **Icons** | Outline, rounded. |
| **Motif** | The customer's words as a quote; "What done means" as a checklist. |
| **Project cards** | People first: avatar and name, a quoted problem, then facts. |
| **Profiles** | Face and story first, evidence below. |
| **Trust badges** | Soft green "Verified" pill, verified programmers only. Evidence is an outlined pill. |
| **Dashboard** | Greeting and large friendly cards. |

| Role | Light | Ratio |
|---|---|---|
| Page / text | `#F6F1E6` / `#2A2A1E` | 12.87 |
| Card / secondary text | `#FFFDF8` / `#5E5A48` | 6.81 |
| Primary / label | `#3F5B2B` / `#FFFFFF` | 7.66 |
| Accent on card | `#A8431F` | 5.92 |
| Control outline on card | `#8C8468` | 3.68 |
| Success chip | `#1E4A27` on `#DDEEDD` | 8.41 |
| Warning chip | `#5C3A00` on `#F6E6C2` | 8.26 |
| Danger chip | `#761E15` on `#F8DEDA` | 8.36 |

Light only in this mockup; a dark palette would still have to be designed. Screenshots: `b-zaytoun-{en,ar}-{welcome,projects,project,dashboard}-{desktop,phone}.png`.

## C. Nabd / Signal (نبض)

**Mood:** a builder's tool. Dark, fast, confident, a little loud.

| | |
|---|---|
| **Fonts** | Alexandria for Arabic and Latin (OFL). Strong geometric headlines. |
| **Shape** | 2 px corners, tables with 1 px rules. |
| **Density** | High. |
| **Icons** | Outline, 2 stroke, square ends. |
| **Motif** | Huge headline, numbered table of criteria, one lime accent. |
| **Project cards** | Table rows with budget, deadline, scope and applicants as columns. |
| **Profiles** | Stat blocks and evidence. |
| **Trust badges** | Lime tinted badge, verified programmers only. Evidence is an outlined tag. |
| **Dashboard** | KPI strip over a dense table. |

| Role | Dark-first | Ratio |
|---|---|---|
| Page / text | `#12101F` / `#F2F0FA` | 16.63 |
| Card / secondary text | `#1C1930` / `#B3AECB` | 7.99 |
| Primary / label | `#C6F04D` / `#171A05` | 13.46 |
| Accent on card | `#FF8A5C` | 7.34 |
| Control outline on card | `#7A7499` | 3.89 |
| Success chip | `#C6F3D9` on `#123B28` | 10.24 |
| Warning chip | `#FFE7B3` on `#3F2F08` | 10.69 |
| Danger chip | `#FFD6D2` on `#4A1B1B` | 10.79 |

No light theme in this mockup. Screenshots: `c-signal-{en,ar}-{welcome,projects,project,dashboard}-{desktop,phone}.png`.

## Comparison

These scores are design judgement on the mockups, not test results (5 is best).

| Criterion | A Blueprint | B Zaytoun | C Signal |
|---|---|---|---|
| Non-technical Arab customers | 4: clear, a little formal | **5**: warmest | 2: reads as a developer tool |
| Early-career programmers | **4**: scope tells them what to build | 3: friendly, less serious | **4**: appealing, but tables can intimidate |
| Trust | **5**: looks like a clear agreement | 4: personal, less rigorous | 3: energetic, less reassuring |
| Readability | **5** | 4: big type uses more scrolling | 3: small muted text on dark for long reading |
| RTL quality | **5**: Plex Arabic sits well with Plex Sans | 4: good, one family | 4: heavy Arabic headlines lose some refinement |
| Distinctiveness | **4**: the criteria ledger belongs to DevLink | 4: palette is distinctive, structure is familiar | 4: lime is striking, but common in developer tools |
| Fit with existing logo (blue) | **5** | 2: olive clashes | 2: lime clashes |
| Flutter cost | **5**: outlines, standard shapes | 4: pills and large radii are easy, needs a new dark theme | 3: needs dense responsive tables and a new light theme |
| **Total of 40** | **37** | **30** | **25** |

## Why A

1. **The look explains the product.** A customer who cannot judge code can judge a numbered list of things they will be able to check. That list is the Clear Scope flagship, and in A it is the visual signature on the welcome page, project rows, project details and dashboard.
2. **Trust without false promises.** Ink, paper and plain rows feel like a clear agreement. The design makes no claim about payment protection or skills, in line with "DevLink does not process payments" and the spec's tooltip wording.
3. **Readable in both languages.** IBM Plex Sans Arabic and IBM Plex Sans were designed as a family, so mixed text such as "مطوّر Laravel" sits evenly. It is also the pairing already in the spec.
4. **Cheapest to build.** Hairlines and no shadows map directly to Material 3 outlined cards. The blue primary works with the current logo, so the logo can stay as it is. Light and dark have both been designed and checked.
5. **Early-career programmers get what they need.** They see what "done" means before applying, and an unverified programmer's card is complete without a badge.

**Its weakness is warmth.** A is less friendly than B, and a non-technical customer could find it cold. To compensate, A keeps a warm paper background and plain-language copy ("One project needs you today", "Say what you will look at"). From B it also borrows the first-person problem statement. From C it borrows dense tables for admin screens only. Testing with a few real customers would show whether this is enough.

## Decisions (2026-11-05)

| Decision | Outcome |
|---|---|
| Direction A | Approved by the owner and partner |
| Primary `#0E5A83`, radii 6/8/12, outlined evidence levels and the other differences in `DESIGN_SYSTEM.md` §10 | Accepted by the owner |
| Requirement count | Text only, with no squares and no legend. Squares beside a price read as a rating or progress, and a legend would only repeat the number. |
| Current logo | Unchanged. The mockups use a text wordmark with a `{ }` mark as a stand-in; a logo refresh would be a separate decision. |
