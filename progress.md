# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Mode:** autopilot (`/plan_autopilot`): carry on through every step below without stopping, except for the device check and a real decision.

## Plan

**Plan 014, Earwig Visits** ([#40](https://github.com/bowerhaus/Earwig/issues/40)): `plans/014-earwig-visits.md`. Read it in full before resuming; its decisions and steps are the authority, this file only tracks where we are.

- **Branch:** `earwig-visits`, from `main` at `2294bc0`, pushed. Plan 013 (App Store release) is in flight on `app-store-release`; whichever merges second rebases the PRD version, CLAUDE.md's status and this file.
- **Approved** by Andy on 2026-11-09 by `/plan_autopilot`, which also allows the commits and the PR. Merging stays Andy's.
- **Manual test:** device, on the iPhone 14 Pro (the plan's Verification).

## Steps

1. [x] Geometry: the icon script writes `EarwigGeometry.swift`.
2. [x] The figure and the gait (`EarwigFigure`, `Gait`), with a first look from the simulator.
3. [x] Paths and running away (`VisitPath`, `Walk`), with tests.
4. [x] Schedule and keep-away (`VisitSchedule`, `EarwigVisits`), with tests.
5. [x] On the screens: the modifier on Scripts, Script and Settings, checked in the simulator with `-EarwigVisits YES`.
6. [x] The slider: Earwig Visits in Diagnostics.
7. [x] Tests + lint: 372 tests pass, SwiftLint clean (commit `2401a34`).
8. [ ] Review + fixes.
9. [ ] Manual test: device.
10. [ ] Complete (commit + PR).

## To resume

"Resume from progress.md": read this file and the plan, run `git status` on `earwig-visits`, then carry on with the first unchecked step.
