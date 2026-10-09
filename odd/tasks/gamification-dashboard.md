# Gamification dashboard

## Objective and problem

Make rewards visible promptly after recording actions, prevent duplicate/lost achievement rewards, and motivate financial habits with a personal dashboard showing level, streak, progress and a concrete next action. Current action rewards run in the background while Home and Achievements use one-time user reads. Budget creation does not invoke its reward. Achievement writes and points are separate.

## Authorized scope and design

User approved the personal dashboard and reward fixes on 2026-10-08, then automatic daily +10, compact Home level, continuous levels and animation. User now explicitly requested implementation of a monthly percentage-saved leaderboard and more joyful mission/level/daily celebrations. Approved ranking design: Logros → Ahorradores, monthly podium/list/personal position, voluntary participation by alias, only savings percentage shared. Percentage = (monthly income − monthly expenses) / monthly income ×100; no starting balance, no position without income, negative percentages remain truthful. Existing Home hierarchy and compact level stay as requested. User subsequently explicitly approved deploying firestore.rules to financial-control-ls using the current Firebase CLI session. Authorization covers that operation and necessary rule corrections/republication; push, PR creation and merge remain unauthorized.

## Constraints and configuration

- Branch: `feat/gamification-dashboard`, branched from `7b465be` on main.
- Implementation route: delegated direct for all tasks; exploration requires 4+ files and implementation touches 2+ non-trivial files. Parent maintains recovery document and commits.
- TDD: enabled for this feature; source: applicable test-driven-development skill and user's explicit request to verify functionality. Runner: `flutter test`. Observe RED before production changes, then GREEN and refactor; do not invent runtime evidence.
- Functional checks: focused tests, full `flutter test`, `flutter analyze`, `dart format`, `git diff --check`. Do not access authenticated remote services for verification.
- Engram mirror: pending; no Engram tools are available. Repository locator: `odd/tasks/gamification-dashboard.md`.
- RDD: disabled/unmanaged; no explicit enablement in this session, `gentle-ai` unavailable. No native review or approval is claimed.
- Initial forecast: about 900 authored changed lines, generated files excluded. Prior implementation/tests snapshot: 2359 authored changed lines. Revised implementation/tests total about 2900 authored changed lines, this recovery document excluded. Transactional/shared rules, reactive Logros, daily bonus, continuous levels, session animation and corresponding regression tests/local transactional fake explain the coherent scope. Delivery strategy: ask-on-risk. Chain choice was requested once and remains pending before the first commit. Publishing PRs remains unauthorized.
- Running authored lines at external checkpoint `fc9b58e`: 2980 (CodeGraph metadata excluded). New work uncommitted; slice boundaries and delivery-chain choice pending.
- Resume reconciliation: repository is clean on `feat/gamification-dashboard`; external commit `fc9b58e` contains the previous implementation. Old pending task-document commit fields are historical and must be reconciled to that real checkpoint, not treated as uncommitted source. No user delivery-chain choice or remote deployment authorization has been received.
- New forecast: roughly 1200 authored changed lines for ranking, rules/tests and celebration pipeline. Reuse feature identity and existing once-requested delivery choice; no repeated chain question.
- New checks: existing `flutter test`/analyzer plus local Firestore rule validation where available. Firebase CLI/Java are installed but emulator cache is absent; CLI update-check failed on config-store permissions. Do not fix ambient configuration or access production sessions. New rules need explicit authorized deployment to `financial-control-ls` before live ranking works.

## Acceptance criteria

- Confirmed rewards update points/levels and streak without reopening screens.
- An unlocked achievement and its points commit atomically and only once, including concurrent checks.
- Budget setup earns 25 points once per user/month, not repeatedly on edits.
- Feedback distinguishes saved financial action from failed/pending reward; no false success or encouragement to repeat a saved transaction.
- Personal dashboard displays level progression, current streak, achievement progress and actionable guidance, with bounded meaningful progress and correct icons.
- Existing financial registration flows remain usable; screen subscriptions are disposed and errors surfaced appropriately.
- Home retains its original visual hierarchy; the large progress card is removed from between greeting and balance, replaced by a compact level indicator near the greeting.
- Daily rewards grant +10 once per local calendar day on first opening/resuming the app, atomically with their marker and points, independently of the financial-registration streak. No repeat rewards for multiple visits or concurrent devices on the same date.
- Preserve current level thresholds through 1000 points and extend progression beyond level 6, 250 points per subsequent level. Remove maximum-level presentation.
- Celebrate an actual level increase once with an animation; initial loaded points and decreases do not trigger it, and a visible form is not interrupted.
- Ahorradores uses only the authenticated user's explicitly shared alias/percentage; private user/transaction data stays owner-readable, public projections are readable by signed-in users only and writable only by their owner with validated schema/finite percentages.
- Ranking refreshes after real income/expense create/edit/delete/recurring changes and month rollover, handles ties deterministically, and distinguishes loading/error/empty/no-income states. Withdrawal removes shared entries and prevents pending work from republishing them.
- New mission results reach a single celebration pipeline; clear festive card, animated medal/confetti, reward count and level progress replace generic dark gamification toasts. Coincident mission+level events combine, duplicates/baseline snapshots do not replay; forms defer presentation and reduced motion is respected.

## Tasks

- [x] GAM-1 — Correct reward confirmation and atomic achievement/budget reward logic; centralize shared level/progress rules and cover meaningful boundaries.
  - Route: delegated. Trigger: service/model/policy changes across non-trivial files and preparatory mapping.
  - RED observed: `flutter test test/gamification_service_test.dart --plain-name 'Confirmed action'` failed because existing action API returned void/no confirmed result. Added only Firestore/clock injection before this behavioral failure.
  - GREEN: `flutter test test/gamification_service_test.dart test/gamification_rules_test.dart` passed 12 tests. Tests use local transactional storage with staged commits/rollback and serialized conflicting writes, not an emulator or live security-rule evaluation. Focused analyzer (service/rules/tests/fake) passed with no issues; format and diff check passed.
  - Regression corrected with observed RED/GREEN: preserve inherited budget eligibility using existing `Budget.latestForMonth`, including exclusion of future limits.
  - Outcome implemented and verified; consolidated externally in existing feature branch.
  - Commit: `fc9b58e` (external consolidated checkpoint; ordinary checks, RDD disabled/unmanaged).
- [x] GAM-2 — Connect reactive dashboard and Home summary, display confirmed rewards across transaction/budget entry points, and verify the integrated feature.
  - Route: delegated. Trigger: Home, Logros and entry-point integration across non-trivial files.
  - RED observed: user serialization omitted currentStreak (expected 0, actual null); dashboard stream emitted 140 points but UI did not render `140 pts`, and max-level/expired-streak assertions failed against minimal widget skeleton. Additional RED: next action incorrectly recommended an unlocked streak; a recovered user stream retained an obsolete error.
  - GREEN: seven focused UI/helper tests passed; parent final `flutter test` passed all 73 tests. Stream recovery clears only the recovered source's error. Home/Logros points update live and subscriptions cancel on dispose; goal/reward and inherited previous-month budget guidance are connected. Timeout after four seconds reports points unconfirmed while preserving financial save success. QuickAdd rewards saved actions even when its sheet closes during persistence.
  - Functional checks: `dart format` applied; final `git diff --check` passed. Parent final `flutter analyze` exited 1 on 75 existing informational issues (baseline 82), no errors or warnings and no introduced findings. Core service/rules/widgets/fake have clean focused analysis.
  - Outcome implemented and verified locally; consolidated externally in existing feature branch. No Firebase emulator, live security-rule execution, authenticated-device flow or APK build was run at that checkpoint; timeout and stream behavior were tested locally.
  - Revised UI acceptance verified by GAM-4: large Home card removed; one-line level indicator below greeting/name, original balance/actions hierarchy restored. Final integrated suite passes 81 tests.
  - Commit: `fc9b58e` (external consolidated checkpoint).
- [x] GAM-3 — Add atomic daily reward and extend level progression beyond level 6.
  - Route: delegated. Trigger: service/rules/model and regression tests across non-trivial files.
  - Approved design: automatic first app visit/resume; daily bonus 10 points, once per calendar date, without requiring spending or extending transaction streak.
  - Checks: daily duplicate/concurrent requests, next date, failed commit rollback and streak preservation; level boundaries 1000/1249/1250 and high levels; revised card progress tests.
  - RED observed: at 1200 points expected progress .8 but capped rules returned 1. Daily contract skeleton failed first confirmed visit, duplicate/concurrent and rollback-retry behavior (not just compilation). Implementation was completed after those behavioral failures.
  - GREEN: `flutter test test/gamification_rules_test.dart test/gamification_service_test.dart` passed 16 tests; focused analyzer passed without issues; format and diff check passed. Marker and points commit together, same-day/concurrent/backward-clock calls award zero, later date awards 10, financial streak remains unchanged. Level 7 starts at 1250 and future levels continue every 250 points.
  - Outcome verified locally; consolidated externally in existing feature branch.
  - Commit: `fc9b58e` (external consolidated checkpoint).
- [x] GAM-4 — Integrate compact Home level indicator and a single animation on confirmed level increases, with daily reward feedback.
  - Route: delegated. Trigger: Home, progress/celebration widgets and UI tests across non-trivial files.
  - Checks: original Home hierarchy, narrow layout, initial snapshot silence, subsequent increase celebration, decreases silence, grouped multiple-level jumps and disposal.
  - RED observed: capped card omitted next-level progress; initial session skeleton failed subsequent celebration and daily-call assertions; compact indicator initially exceeded narrow-layout height. GREEN: seven focused UI tests passed, then final full `flutter test` passed 81/81.
  - Animation uses native scale/fade once per increase, baseline silent, highest observed level prevents repeats, multiple jumps grouped; a pushed form defers celebration until returning. Daily visit runs on first loaded user/resume with in-flight guard and confirmed reward feedback. Full progress card stays in Logros; Home uses a single compact line.
  - Mechanical integration correction: once Home receives a user stream snapshot, a late `getUser` fallback cannot overwrite newer points. No direct Firebase interleaving test was added; stream/widget tests and final 81-test suite pass, with this limit disclosed.
  - Final parent full analyzer: exit 1, 75 existing infos, no errors/warnings. New widgets/tests focused analyzer clean; Home retains five existing infos. Format/diff checks pass. A backend full-suite run canceled during parallel UI work produced shutdown/parser finalization failures; that interrupted run is not used as proof and was superseded by the final successful suite.
  - Outcome verified locally; consolidated externally in existing feature branch. No authenticated device, Firebase emulator/live security rules or APK build was run at that checkpoint.
  - Commit: `fc9b58e` (external consolidated checkpoint).
- [ ] GAM-5 — Implement percentage-saved leaderboard model, privacy-preserving projection/synchronization, voluntary alias participation and Logros ranking UI with schema rules.
  - Route: delegated. Trigger: new model/service/sync/panel, Logros page, rules and tests across non-trivial files; prior mapping covered CRUD and recurring sources.
  - TDD: enabled; runner `flutter test`, observe behavioral RED/GREEN. Checks: percentage/no-income/negative/tie boundaries; participation/withdrawal vs in-flight publish; stream errors and month rollover; empty/loading/podium/personal rank and narrow UI; rules owner/private/schema cases with local emulator if available.
  - No backend functions folder exists despite firebase.json source declaration; use aggregate projection based on registered movements, with that fact visible in ranking.
  - Behavioral RED observed: percentage/publication/order contract failed before implementation; later precision expected 33.33 but returned 33.333333, cancelled generation still published, month header stayed stale, and pending participation refreshed a new account. GREEN: 19 focused tests covering calculation/order, transactional participation/withdrawal and rollback, delete-income removal, stream recovery, month rollover, pending opt-out, account isolation and 320px layout. Scoped analyzer: no issues. Parent final suite: 110/110 pass.
  - Outcome: implemented and Flutter-verified locally. Initial security checks were blocked; GAM-8 subsequently verified all 12 REST security checks and deployed corrected rules. Work-unit commit pending delivery-chain choice.
- [ ] GAM-6 — Connect confirmed mission rewards to joyful combined celebrations and replace daily dark toast with a compact colorful reward banner.
  - Route: delegated. Trigger: reward helper, event/controller, session, animated card/banner and widget tests across non-trivial files.
  - TDD: enabled; runner `flutter test`. Checks: mission name/points/progress, combined level event, deduplication, daily confirmation-only, disposal/user-session isolation, form deferral and reduced motion.
  - Behavioral RED observed: mission presentation lacked title/points/progress; daily feedback emitted the old dark SnackBar; five missions on 320x568 with enlarged text overflowed; a late daily result replaced newer progress; queued missions displayed before points loaded. Each failed behavior was corrected. Confirmed unlocks now feed a UID-filtered deduplicated event hub; session coalesces mission/level/daily events into one light gold animated scrollable card or a mint daily banner. GREEN: 16 focused session/mission/helper tests; six-file focused analyzer clean. Parent final suite: 110/110 pass.
  - Outcome: implemented and verified locally; work-unit commit pending delivery-chain choice.
- [ ] GAM-7 — Integrate ranking synchronizer in authenticated Home shell and validate the complete requested feature/rules; record deployment limitations.
  - Route: inline for mechanical Home wrapper only (known 1-file integration), delegated for any broader verification/research trigger. Forecast/checks: full Flutter suite, analyzer, format/diff and local rule tests. No deployment or ambient credential probing.
  - Parent mechanical Home integration completed: authenticated UID passed to reward session, invisible ranking synchronizer wraps existing shell, daily callback captures UID safely. Home layout unchanged; format and diff checks pass.
  - Actual local Firestore emulator started on 127.0.0.1:8185 with project demo-chiroless, using Java directly; REST harness uses synthetic local JWTs, no ambient Firebase login/session inspected. Reusable harness under test/firestore_rules. Sandbox Node requests failed before behavioral checks. Escalated Node runner approval remained pending for 382 seconds; interrupted to recover status, no runner execution and no security RED/GREEN claimed. Do not duplicate the approval or bypass network restrictions. Emulator cleanup recorded below when observed.
  - Final parent `flutter test`: 110/110 pass (exit 0). Earlier concurrent run: 109 passed/1 failed on the new behavioral RED for queued missions before points loaded; fixed and superseded by final stable suite. Final `flutter analyze`: exit 1, 75 pre-existing informational findings, no errors/warnings; focused new-source checks clean. Format and `git diff --check` pass. Actual Firestore security run skipped/pending runtime approval; no authenticated-device flow or APK build run.
  - Security harness syntax `node --check` and diff check pass; README documents local demo startup/run/stop and client-calculated-score limitation. Every fetch has a 15-second timeout. Emulator stopped with Ctrl+C, exit 130 and gRPC shutdown observed. No background verification process remains.
- [ ] GAM-8 — Deploy authorized Firestore rules and resolve compiler compatibility warning.
  - Authorization: explicit user yes to financial-control-ls, firestore.rules deployment, current Firebase CLI session. Parent owns deployment; delegate has local-only rule correction/check scope.
  - Route: delegated narrow rule/debugging/check task; preparation trigger, existing test harness and compiler mismatch require investigation. Parent publishes corrected verified file.
  - First deployment: `firebase deploy --only firestore:rules --project financial-control-ls --non-interactive`, exit 0; compilation/upload/release confirmed. Warning at 47:18: Invalid function name math.isInfinite. Outcome not accepted until compatible finite-score guard validated and rules republished.
  - TDD/checks: existing local REST security harness, node --test test/firestore_rules/leaderboard_rules.test.mjs; behavioral RED/GREEN when available, compiler output must contain no introduced warning. Engram pending; commit awaits existing delivery choice.
  - Behavioral RED observed after runtime approval: `node --test --test-isolation=none test/firestore_rules/leaderboard_rules.test.mjs` exited 1, 7 passed/5 failed; valid owner writes expected 200 but returned 403 with Function not found math.isInfinite. Replaced unsupported math calls with `(percentage - percentage) == 0`, preserving every finite value and rejecting NaN/both infinities.
  - GREEN observed: same local REST runner exited 0, 12/12 passed; checks include finite negative/zero/100, non-finite and >100 rejection, owner/signed/private access, schema, timestamp and getAfter participation/withdrawal. No production data read/write used for tests.
  - Final redeployment: same explicit command, exit 0; Firestore compilation/upload/release all successful with no warnings. Deployment outcome achieved. Delegate confirmed local emulator stopped and README updated with actual security proof/reproducible command; diff check passes. Work-unit commit remains pending delivery choice, RDD disabled/unmanaged.

## Exploration evidence

- `quick_add_sheet.dart:287` and full registration forms launch unawaited rewards; Home can reload user data before rewards finish.
- `achievements_page.dart:33` uses single reads despite existing user and achievement streams.
- `gamification_service.dart:131` writes achievement then separately adds points; deterministic document IDs alone do not prevent concurrent double credit.
- `add_budget_page.dart:80` saves without invoking the existing `budget_set` reward.
- Current Firestore rules restrict user documents to their owners; personal dashboard fits existing permissions.

## Progress and next step

GAM-5/GAM-6 and mechanical GAM-7 integration are implemented; stable Flutter suite passes 110/110, analyzer retains 75 pre-existing infos with no errors/warnings, focused new-source analysis and diff/format pass. GAM-8 recovered actual security verification: 12/12 local REST checks pass after replacing the unsupported math.isInfinite guard. User-authorized deployment to financial-control-ls via current Firebase CLI session completed with warning-free compilation/upload/release, exit 0. External `fc9b58e` remains the prior committed checkpoint; new work-unit commits await the once-requested delivery-chain choice. Parent read current document; Engram context/search/full observation remain unavailable, mirror pending. Device checks and APK build unrun; no push/PR/merge authorized.
