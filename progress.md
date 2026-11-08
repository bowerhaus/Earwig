# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Plan 007: app icon, logo and splash (#21)**, branch `app-icon-splash` from `main` at `5b1849e`.
Mode: autopilot (`/plan_autopilot`), approved 2026-11-08. Manual test: device (the plan's Verification list, on the iPhone 14 Pro). Issue #21 exists.
Plan file: `plans/007-app-icon-splash.md`. Concepts page (the chosen mark's geometry under "Chosen"): https://claude.ai/artifact/8hvAFycZj6MXAquw53z5cL.

## Checklist

- [x] 1. Script: `scripts/app_icon/make_app_icon.py`, SVGs, the three icon PNGs, the mark PNGs; run twice, identical; committed on its own
- [x] 2. Review: Final section published on the concepts page (version 7) with the real renders. Andy's approval is taken together with the device check (step 6), where the tile is best judged; a change means re-running the script
- [x] 3. Asset catalogue: AppIcon Contents.json with three appearances, EarwigMark.imageset; xcodegen; test; simulator Home Screen; assetutil for dark
- [x] 4. Launch colour: LaunchBackground.colorset, UILaunchScreen in project.yml, LaunchSplashTests
- [x] 5. Splash: SplashView, SplashTiming, showsSplash in EarwigApp; simulator cold launch, background return, Debug flags
- [ ] 6. Device check on the iPhone 14 Pro: the build (commit after review fixes, app target unchanged since `0435a70`) is installed; checklist given to Andy 2026-11-08; awaiting his verdicts on items 1 to 5 of the plan's Verification, plus his approval of the Final section on the concepts page
- [ ] 7. Finish: the PRD v0.9 and CLAUDE.md edits are committed (`0435a70`); Results (device verdicts, decision 8), the plan's Status and the progress stub remain for completion
- [x] Tests + lint (266 tests pass in the simulator, no asset warnings, SwiftLint clean)
- [x] Review + fixes (review pass and Outcome in the plan; C1 part, C2, T1 fixed; 267 tests pass, SwiftLint clean)
- [ ] Manual test: device (in progress: checklist given, waiting for Andy)
- [ ] Complete (commit + PR)

## Notes

- Chrome: `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`. Run the script with `uv run --with pillow scripts/app_icon/make_app_icon.py` from the repo root.
- PhysiMate's plan 010/012 are the pattern (icon script; splash overlay, cold launch only, `@State showsSplash`).
- Simulator (2026-11-08): the icon on the Home Screen; `assetutil` lists AppIcon light, dark and tinted and LaunchBackground in both appearances; the splash on a cold launch and none on a return from the background (same pid); `-EarwigDemo YES` opens the sample script.
- **Next:** record Andy's verdicts in the plan's Results (and decision 8's verdict on the visual refresh), set the plan's Status to Complete, empty this file to its stub, then `/plan_completed` as the autopilot's step 5 (commit, PR to `main` with `Closes #21`).
