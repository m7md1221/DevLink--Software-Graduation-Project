# Roadmap: 8 weeks to graduation (features first)

**Approved by the owner 2026-11-21.** About 8 weeks remain. The plan now puts the Clear Scope features first and moves the full redesign and the complete Arabic translation to week 7. Weeks run Monday to Sunday from 2026-11-23; the last week ends 2027-01-17.

**Source for M3:** the product spec ([`DevLink_Product_Spec/…/03`](../DevLink_Product_Spec/DevLink_Product_Spec/03_FUNCTIONAL_REQUIREMENTS_AND_USER_STORIES.md) FR-BRF, FR-APP, FR-ENG, FR-REV, FR-MSG; [`05`](../DevLink_Product_Spec/DevLink_Product_Spec/05_DATA_MODEL_AND_API_SPECIFICATION.md) §2.2–2.6 and the state machines in §4; [`07`](../DevLink_Product_Spec/DevLink_Product_Spec/07_DIFFERENTIATION_AND_FEATURE_CATALOG.md) F1, F3, F4), **simplified** as listed under each week. The spec folder is not tracked in Git.

| Week | Dates | Milestone | Outcome |
|---|---|---|---|
| W1 | 11-23 → 11-29 | **M2.12-lite** | The app works with authorization enforced (secure client, signed images), Blueprint theme app-wide, KI-60/13/56 ([plan](M2_12_PLAN.md)) |
| W2 | 11-30 → 12-06 | **M2.13 + M2.14** | Migration switch and development fallbacks removed; end-to-end checks per role, two-tab check (T-MT-07/08) |
| W3 | 12-07 → 12-13 | **M3.1 Clear Scope brief** | A customer creates a structured project with numbered acceptance criteria; admin moderation as today |
| W4 | 12-14 → 12-20 | **M3.2 Structured applications** | A programmer answers each criterion; the customer compares applicants side by side |
| W5 | 12-21 → 12-27 | **M3.3 Engagement** | Accept creates an engagement with an agreed-scope snapshot; delivery against criteria, revision, accept |
| W6 | 12-28 → 01-03 | **M3.4 Reviews + thread** | Reviews show "criteria met n/m"; one message thread per engagement |
| W7 | 01-04 → 01-10 | **Arabic for demo screens, demo data, polish** | Arabic and RTL for the key demo screens; a seeded demo dataset; visual polish where time allows |
| W8 | 01-11 → 01-17 | **Testing, report, presentation, buffer** | Final test runs, the graduation report and slides, rehearsal; buffer for slips |

## Working rules for every milestone

- Local commits once the build, tests, the secret scan and the attribution scan pass and the change is within the approved scope; **push only with the owner's approval**.
- One full test run per task; **three consecutive full runs at the end of each milestone**.
- No reset, rebase or force push; no database change without a verified backup (`C:\Users\dell\DevLink-backups\`) and the owner's approval; no new dependency without approval; every `pubspec.lock` change approved.
- Schema changes are EF Core migrations, applied to `DevLink` only after a backup and approval, and listed for the partner (design §13).

## W2: M2.13 + M2.14

- **M2.13:** remove `Auth:EnforceAuthorization` and the five `LegacyFallbackCase`s, the tokenless image and document routes, and the legacy no-header login path; tests that covered the fallback become "refused" tests.
- **M2.14:** an end-to-end script per role (customer, programmer, admin) and the real two-tab browser check (T-MT-07, T-MT-08); the synthetic admin is removed at the end (kept until M2.14).

## W3: M3.1 Clear Scope project brief (F1, FR-BRF-01/02/04/06/07)

**Built (simplified):**
- A project is the existing `Post`, extended (spec D-12: keep the `Posts` table, map the new fields onto it). New fields: `Title`, `ProjectType` (Website, MobileApp, WebApp, Automation, ExistingSystemChange, Other), `Problem`, `TargetUsers`, `BudgetMin`/`BudgetMax`, `DeadlineDate`, `Status`.
- New `ProjectFeatures` (1–10) and `AcceptanceCriteria` (3–20 per project, **numbered** AC-1, AC-2 … in display order, each optionally under a feature).
- One form with 3 sections instead of the 5-step wizard: basics, features and criteria, budget and deadline.
- **Readiness check**, blocking rules only: B1 title, B2 problem ≥ 50 characters, B4 ≥ 1 feature, B5 ≥ 3 criteria, B6 each feature has a criterion, B7 budget, B8 deadline. Plus warning W1 (vague words, en + ar list).
- Status: Draft → PendingReview → Open (admin approves, existing moderation) / ChangesRequested (admin message). The owner sees their projects by status.
- The existing feed shows projects with their criteria count (UI-6: "6 requirements").

**Left out:** templates (FR-BRF-03), attachments, clarifications, autosave and the 409 two-tab edit check, auto-close, readiness score.

**Tests:** each blocking rule; create → submit → approve; a non-owner can't edit; criteria numbering is stable.

## W4: M3.2 Applications per criterion + comparison (F3, FR-APP-01/02/05/08)

**Built:**
- The application form lists the project's criteria; for each: **Will meet / Needs clarification / Propose change**, with a note required for the last two. Plus the proposed amount, duration in days and approach (100–1500 characters).
- New `ApplicationCriterionResponses`; every criterion must be answered (400 names the missing one).
- **Comparison view** for the owner: one row per applicant; columns amount, duration, criteria coverage (Will-meet count / total), and clarifications. Default sort by submission time, sortable by coverage. No AI score.
- Accept keeps today's rule (one accepted; the others become not selected).

**Left out:** shortlist, edit and withdraw, evidence attachments, duplicate-text detection, the active-application cap.

**Tests:** answers required for every criterion; coverage sort with ties by time; only the owner sees applications; a race between two accepts gives one engagement (preparing W5).

## W5: M3.3 Engagement (F4, FR-ENG-01/05/06/07/09)

**Built:**
- Accepting an application creates an **Engagement** in one transaction, with `ScopeSnapshotJson`: title, problem, features, numbered criteria, agreed amount and deadline. The snapshot never changes afterwards.
- **One milestone per engagement** (the spec allows 1–5; simplified). Its criteria are copied from the snapshot.
- The programmer submits a delivery: for each criterion **Met / Not met** + an evidence note or link.
- The customer either **requests a revision** (selects ≥ 1 criterion, note ≥ 20 characters; at most 2 revisions) or **accepts**. Accepting with "Not met" criteria needs an explicit waiver checkbox.
- Accept completes the engagement and the project.
- A timeline of these events with actor and time.

**Left out:** scope acknowledgement, multiple milestones, auto-accept, cancellation flow, scope change requests, disputes.

**Tests:** the snapshot equals the brief at acceptance and stays the same; every criterion must be claimed; the revision limit; the waiver; only the two parties can act.

## W6: M3.4 Reviews + message thread (FR-REV-01/03, FR-MSG-02)

**Built:**
- After completion, each party reviews once: rating 1–5 and a comment of up to 1000 characters. The system computes **"criteria met n/m"** from the accepted criteria and shows it with the review.
- Profiles show the average and count, or "New on DevLink" with fewer than 3 reviews.
- **One message thread per engagement** for its two parties; polling every 10 s while open; an unread count.

**Left out:** double-blind publication, review moderation, application threads, attachments in messages, the contact-information warning.

**Tests:** one review per party; non-parties get 404; n/m is computed, not typed; only the parties read and write the thread.

## W7: Arabic, demo data, polish

- Arabic (ARB files, RTL, LTR isolation for money, numbers, dates and codes, UI-5) for the **key demo screens**: welcome, login, feed or project list, project detail, application form, comparison, engagement, review. The switch stays hidden until every screen is translated (UI-8); the demo runs with a build-time locale override if the translation is incomplete.
- A seeded demo dataset of synthetic accounts and projects, a script, and a reset procedure.
- Visual polish where time allows: the per-screen redesign from the old M2.12 plan, starting with the demo screens.

## W8: testing, report, presentation, buffer

- Three consecutive full runs; the end-to-end script per role; the test report updated.
- The graduation report: architecture, security design (M2), the Clear Scope features, test evidence.
- Slides and demo rehearsal; the remaining time is buffer.

## Risks

1. **Partner coordination:** M3 changes `PostService`, `PostsController` and Flutter files owned by the partner. Each milestone lists the partner-owned files it touches, and the partner reviews them before merge.
2. **Schema migrations on the partner's database:** they must first catch up on design §13 P-1 and P-14.
3. **Scope creep:** anything beyond the "built" lists waits for W8's buffer.
4. **Disk space on C:** each phase starts with at least 10 GB free (KI-48).
