# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Plan:** `plans/012-settings-testflight.md` (stage 7, Settings and TestFlight)
**Issue:** #38 (folds in #36 and #35, closes #14)
**Branch:** `settings-testflight`, from `main` at `af23220`
**Mode:** autopilot (`/plan_autopilot`): carry on through the steps below without stopping, except for the device checks (Manual test) and a real decision.
**Manual test:** device, on Andy's iPhone 14 Pro with the SK18 (the plan's Verification), and the first TestFlight upload, which needs Andy's Keychain items and App Store Connect record first.

## Checklist

- [ ] 1. Cue voice in `VoiceCatalogue`, tests first
- [ ] 2. The Voice group: Voice Speed moved in, Cue Voice, Preview with Stop
- [ ] 3. Show Take Details and Title Case (#36)
- [ ] 4. About
- [ ] 5. Swipe to delete asks first (#35)
- [ ] 6. Privacy manifest
- [ ] 7. Release build, `MARKETING_VERSION` 0.2.0
- [ ] 8. `testflight.sh` and `ExportOptions.plist`, refusals tried
- [ ] 9. Andy's part: Keychain items, App Store Connect record, internal group
- [ ] 10. The first upload (Andy's yes), install from TestFlight
- [ ] Tests + lint
- [ ] Review + fixes
- [ ] Manual test: device checks 1 to 7 (one at a time)
- [ ] Complete (commit + PR)

## Notes

