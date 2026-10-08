# Double back to exit

## Objective

On Android, require two consecutive system Back actions at the app's root route to exit Chiroless, with brief feedback after the first action. Preserve normal Back behavior for pushed routes.

## Problem and rationale

After startup, `SplashScreen` replaces itself with either `HomePage` or `LoginPage`. Root-only behavior must cover both destinations while allowing feature pages and registration to pop normally. This is presentation and navigation behavior, so it belongs in a small shared widget connected at the app boundary, not a generic utility/service.

## Authorized scope

- Implement on the existing `main` branch; do not create or switch branches.
- Add a shared presentation widget and connect it from `lib/main.dart`.
- Keep the behavior Android-specific; do not alter page navigation or add dependencies.
- Close the task with its required work-unit commit directly on the existing `main` branch; the user explicitly ruled out creating another branch.

## Constraints and configuration

- User approved the design on 2026-10-08.
- Route: delegated direct. Trigger evidence: implementation spans a new shared widget and `lib/main.dart` integration, two non-trivial files.
- Forecast: about 120 authored changed lines, generated files excluded.
- TDD mode: off for this run, source: higher-priority developer instruction says not to add or run tests unless the user asks to test/verify. Test runner, if later authorized: `flutter test`.
- Engram mirror: pending; no Engram/memory tool is available in this session.
- RDD: unavailable; `gentle-ai review mode status` could not run because `gentle-ai` is not installed. No RDD review was started and no approval is claimed.

## Acceptance criteria

- A Back action on a pushed route pops that route normally.
- At the root on Android, the first Back action is consumed and shows a brief Spanish exit hint.
- A second Back action within the timeout requests app exit; a later action after timeout starts a fresh first press.
- The timer and observer are disposed safely.
- No new package dependency is added.

## Tasks

- [x] DBE-1 — Add the root-only double-back presentation behavior and connect it to the app navigator.
  - Route: delegated direct.
  - Outcome: added `lib/shared/widgets/double_back_to_exit.dart` and connected it to the app navigator in `lib/main.dart`. Android root Back is consumed, a second press within two seconds exits, and nested route Back is passed through.
  - Verification: `dart format lib/main.dart lib/shared/widgets/double_back_to_exit.dart` reported no changes. `git diff --check` passed. `flutter analyze lib/main.dart lib/shared/widgets/double_back_to_exit.dart` exited 1 on two existing `avoid_print` infos in `lib/main.dart` lines 45 and 53; the new widget had no analyzer findings. Tests were not added or run under the higher-priority instruction.
  - Review/delivery: native RDD unavailable because `gentle-ai` is not installed; no review or approval is claimed. Work-unit commit pending.

## Verification evidence

- Exploration: CodeGraph confirmed `lib/main.dart` starts at `SplashScreen`; `SplashScreen._checkAuthAndNavigate` replaces it with `HomePage` or `LoginPage`. Feature and registration screens use pushed routes.
- No existing system Back handler or app routing shell was found.
- Current branch is `main`; working tree initially contained only untracked `.codegraph/`, left untouched.

## Next step

Record the work-unit commit identity, then synchronize the Engram mirror if a memory tool becomes available.
