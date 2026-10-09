# Gamification dashboard

## Objective and problem

Make rewards visible promptly after recording actions, prevent duplicate/lost achievement rewards, and motivate financial habits with a personal dashboard showing level, streak, progress and a concrete next action. Current action rewards run in the background while Home and Achievements use one-time user reads. Budget creation does not invoke its reward. Achievement writes and points are separate.

## Authorized scope and design

User approved the personal dashboard and reward fixes on 2026-10-08. Extend existing Flutter/Firebase flows: reactive user/achievement data, confirmed reward feedback, transactional one-time achievement unlocks, monthly budget reward identity, and meaningful personal progress. User subsequently requested restoring the previous Home layout with a discreet level indicator, adding daily motivation/rewards, and levels that continue indefinitely with an animation on increases. User approved an automatic daily reward and reiterated with a screenshot that the large progress card must not appear on Home. Implement the presented design: +10 once per day on opening/resuming the app, compact level near greeting, existing thresholds through 1000 then +250 per level, animation for genuine subsequent increases. No global leaderboard or public user data. No remote Firebase execution, deployment, push, PR creation or merge is authorized.

## Constraints and configuration

- Branch: `feat/gamification-dashboard`, branched from `7b465be` on main.
- Implementation route: delegated direct for all tasks; exploration requires 4+ files and implementation touches 2+ non-trivial files. Parent maintains recovery document and commits.
- TDD: enabled for this feature; source: applicable test-driven-development skill and user's explicit request to verify functionality. Runner: `flutter test`. Observe RED before production changes, then GREEN and refactor; do not invent runtime evidence.
- Functional checks: focused tests, full `flutter test`, `flutter analyze`, `dart format`, `git diff --check`. Do not access authenticated remote services for verification.
- Engram mirror: pending; no Engram tools are available. Repository locator: `odd/tasks/gamification-dashboard.md`.
- RDD: disabled/unmanaged; no explicit enablement in this session, `gentle-ai` unavailable. No native review or approval is claimed.
- Initial forecast: about 900 authored changed lines, generated files excluded. Prior implementation/tests snapshot: 2359 authored changed lines. Revised implementation/tests total about 2900 authored changed lines, this recovery document excluded. Transactional/shared rules, reactive Logros, daily bonus, continuous levels, session animation and corresponding regression tests/local transactional fake explain the coherent scope. Delivery strategy: ask-on-risk. Chain choice was requested once and remains pending before the first commit. Publishing PRs remains unauthorized.
- Running authored lines: 0. Slice boundaries/commit identities: pending.

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

## Tasks

- [ ] GAM-1 — Correct reward confirmation and atomic achievement/budget reward logic; centralize shared level/progress rules and cover meaningful boundaries.
  - Route: delegated. Trigger: service/model/policy changes across non-trivial files and preparatory mapping.
  - RED observed: `flutter test test/gamification_service_test.dart --plain-name 'Confirmed action'` failed because existing action API returned void/no confirmed result. Added only Firestore/clock injection before this behavioral failure.
  - GREEN: `flutter test test/gamification_service_test.dart test/gamification_rules_test.dart` passed 12 tests. Tests use local transactional storage with staged commits/rollback and serialized conflicting writes, not an emulator or live security-rule evaluation. Focused analyzer (service/rules/tests/fake) passed with no issues; format and diff check passed.
  - Regression corrected with observed RED/GREEN: preserve inherited budget eligibility using existing `Budget.latestForMonth`, including exclusion of future limits.
  - Outcome implemented and verified; task closure/commit pending delivery choice.
  - Commit: pending.
- [ ] GAM-2 — Connect reactive dashboard and Home summary, display confirmed rewards across transaction/budget entry points, and verify the integrated feature.
  - Route: delegated. Trigger: Home, Logros and entry-point integration across non-trivial files.
  - RED observed: user serialization omitted currentStreak (expected 0, actual null); dashboard stream emitted 140 points but UI did not render `140 pts`, and max-level/expired-streak assertions failed against minimal widget skeleton. Additional RED: next action incorrectly recommended an unlocked streak; a recovered user stream retained an obsolete error.
  - GREEN: seven focused UI/helper tests passed; parent final `flutter test` passed all 73 tests. Stream recovery clears only the recovered source's error. Home/Logros points update live and subscriptions cancel on dispose; goal/reward and inherited previous-month budget guidance are connected. Timeout after four seconds reports points unconfirmed while preserving financial save success. QuickAdd rewards saved actions even when its sheet closes during persistence.
  - Functional checks: `dart format` applied; final `git diff --check` passed. Parent final `flutter analyze` exited 1 on 75 existing informational issues (baseline 82), no errors or warnings and no introduced findings. Core service/rules/widgets/fake have clean focused analysis.
  - Outcome implemented and verified locally; task closure/commit pending delivery choice. No Firebase emulator, live security-rule execution, authenticated-device flow or APK build was run; timeout and stream behavior were tested locally.
  - Revised UI acceptance verified by GAM-4: large Home card removed; one-line level indicator below greeting/name, original balance/actions hierarchy restored. Final integrated suite passes 81 tests.
  - Commit: pending.
- [ ] GAM-3 — Add atomic daily reward and extend level progression beyond level 6.
  - Route: delegated. Trigger: service/rules/model and regression tests across non-trivial files.
  - Approved design: automatic first app visit/resume; daily bonus 10 points, once per calendar date, without requiring spending or extending transaction streak.
  - Checks: daily duplicate/concurrent requests, next date, failed commit rollback and streak preservation; level boundaries 1000/1249/1250 and high levels; revised card progress tests.
  - RED observed: at 1200 points expected progress .8 but capped rules returned 1. Daily contract skeleton failed first confirmed visit, duplicate/concurrent and rollback-retry behavior (not just compilation). Implementation was completed after those behavioral failures.
  - GREEN: `flutter test test/gamification_rules_test.dart test/gamification_service_test.dart` passed 16 tests; focused analyzer passed without issues; format and diff check passed. Marker and points commit together, same-day/concurrent/backward-clock calls award zero, later date awards 10, financial streak remains unchanged. Level 7 starts at 1250 and future levels continue every 250 points.
  - Outcome verified locally; work-unit commit pending delivery choice.
  - Commit: pending.
- [ ] GAM-4 — Integrate compact Home level indicator and a single animation on confirmed level increases, with daily reward feedback.
  - Route: delegated. Trigger: Home, progress/celebration widgets and UI tests across non-trivial files.
  - Checks: original Home hierarchy, narrow layout, initial snapshot silence, subsequent increase celebration, decreases silence, grouped multiple-level jumps and disposal.
  - RED observed: capped card omitted next-level progress; initial session skeleton failed subsequent celebration and daily-call assertions; compact indicator initially exceeded narrow-layout height. GREEN: seven focused UI tests passed, then final full `flutter test` passed 81/81.
  - Animation uses native scale/fade once per increase, baseline silent, highest observed level prevents repeats, multiple jumps grouped; a pushed form defers celebration until returning. Daily visit runs on first loaded user/resume with in-flight guard and confirmed reward feedback. Full progress card stays in Logros; Home uses a single compact line.
  - Mechanical integration correction: once Home receives a user stream snapshot, a late `getUser` fallback cannot overwrite newer points. No direct Firebase interleaving test was added; stream/widget tests and final 81-test suite pass, with this limit disclosed.
  - Final parent full analyzer: exit 1, 75 existing infos, no errors/warnings. New widgets/tests focused analyzer clean; Home retains five existing infos. Format/diff checks pass. A backend full-suite run canceled during parallel UI work produced shutdown/parser finalization failures; that interrupted run is not used as proof and was superseded by the final successful suite.
  - Outcome verified locally; work-unit commit pending delivery choice. No authenticated device, Firebase emulator/live security rules or APK build was run.
  - Commit: pending.

## Exploration evidence

- `quick_add_sheet.dart:287` and full registration forms launch unawaited rewards; Home can reload user data before rewards finish.
- `achievements_page.dart:33` uses single reads despite existing user and achievement streams.
- `gamification_service.dart:131` writes achievement then separately adds points; deterministic document IDs alone do not prevent concurrent double credit.
- `add_budget_page.dart:80` saves without invoking the existing `budget_set` reward.
- Current Firestore rules restrict user documents to their owners; personal dashboard fits existing permissions.

## Progress and next step

Revised requested behavior is implemented and verified locally: no large Home card, compact level indicator, automatic daily +10 once/date, continuous levels and single level-up animation. Final suite after Home fallback guard: 81/81 pass. Full analyzer reports 75 existing infos, no warnings/errors; focused final Home analyzer retains five existing infos; diff/format pass. The remaining runtime checks are authenticated-device/live Firebase behavior, security-rule evaluation and APK build; these were not run. All checkboxes remain open solely because required work-unit commits await the once-requested delivery-chain choice; no push/PR/merge is authorized. Engram mirror remains pending because tools are unavailable. Next step: after delivery choice, preserve current changes and close bounded work-unit commits with recorded identities; do not reopen verified scope or repeat unchanged passing checks.
