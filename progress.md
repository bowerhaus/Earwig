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
- [ ] 6. Device check on the iPhone 14 Pro, one check at a time (a pause)
- [ ] 7. Finish: PRD v0.9 and CLAUDE.md edits are drafted (uncommitted until the device check); Results and the progress stub remain
- [x] Tests + lint (266 tests pass in the simulator, no asset warnings, SwiftLint clean)
- [ ] Review + fixes
- [ ] Manual test: device
- [ ] Complete (commit + PR)

## Notes

- Chrome: `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`. Run the script with `uv run --with pillow scripts/app_icon/make_app_icon.py` from the repo root.
- PhysiMate's plan 010/012 are the pattern (icon script; splash overlay, cold launch only, `@State showsSplash`).
- Simulator (2026-11-08): the icon on the Home Screen; `assetutil` lists AppIcon light, dark and tinted and LaunchBackground in both appearances; the splash on a cold launch and none on a return from the background (same pid); `-EarwigDemo YES` opens the sample script.
