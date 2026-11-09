# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Plan:** `plans/012-settings-testflight.md` (stage 7, Settings and TestFlight)
**Issue:** #38 (folds in #36 and #35, closes #14)
**Branch:** `settings-testflight`, from `main` at `af23220`
**Mode:** autopilot (`/plan_autopilot`): carry on through the steps below without stopping, except for the device checks (Manual test) and a real decision.
**Manual test:** device, on Andy's iPhone 14 Pro with the SK18 (the plan's Verification), and the first TestFlight upload, which needs Andy's Keychain items and App Store Connect record first.

## Checklist

- [x] 1. Cue voice in `VoiceCatalogue`, tests first
- [x] 2. The Voice group: Voice Speed moved in, Cue Voice, Preview with Stop
- [x] 3. Show Take Details and Title Case (#36)
- [x] 4. About
- [x] 5. Swipe to delete asks first (#35)
- [x] 6. Privacy manifest
- [x] 7. Release build, `MARKETING_VERSION` 0.2.0
- [x] 8. `testflight.sh` and `ExportOptions.plist`, refusals tried
- [ ] 9. Andy's part: Keychain items, App Store Connect record, internal group
- [ ] 10. The first upload (Andy's yes), install from TestFlight
- [x] Tests + lint
- [x] Review + fixes
- [ ] Manual test: device checks 1 to 7 (one at a time)
- [ ] Complete (commit + PR)

## Notes

- 372 tests pass, no warnings, SwiftLint clean; the Release configuration builds, with `PrivacyInfo.xcprivacy` in the bundle, version 0.2.0, and no `EarwigDemo` in the binary.
- The script's refusals tried: a dirty tree, the Keychain items missing (they are, on this Mac: Andy stores them, step 9), an existing tag. `--dry-run` archived 0.2.0 (2) for the device and put `project.yml` back to build 1.
- Simulator: Settings in seven groups, About shows 0.2.0 (1), Preview plays (log: "preview: Daniel (Compact) at 0.95x"). The simulator dropped and delayed taps, so the swipe's question is left to device check 4; the view model's tests cover it.
- The README's Settings screenshot (`docs/screenshots/settings.png`) shows the old Voice group: retake on the phone during the device checks (`xcrun devicectl device capture screenshot`).
- Review done: C1, C2, C3, C5, T1 (part), T2, T3 fixed; C4 (the Finish step) and T4 not done; recorded in the plan and on #38. 371 tests pass.
- Next: Andy's part (Keychain items, App Store Connect record) and the device checks, one at a time.

