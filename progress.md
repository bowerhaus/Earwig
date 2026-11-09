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
- [x] 9. Andy's part: Keychain items, App Store Connect record, internal group
- [ ] 10. The first upload (Andy's yes), install from TestFlight
- [x] Tests + lint
- [x] Review + fixes
- [ ] Manual test: device checks 1 to 7 (one at a time); 1 to 4 passed
- [ ] Complete (commit + PR)

## Notes

- 372 tests pass, no warnings, SwiftLint clean; the Release configuration builds, with `PrivacyInfo.xcprivacy` in the bundle, version 0.2.0, and no `EarwigDemo` in the binary.
- The script's refusals tried: a dirty tree, the Keychain items missing (they are, on this Mac: Andy stores them, step 9), an existing tag. `--dry-run` archived 0.2.0 (2) for the device and put `project.yml` back to build 1.
- Simulator: Settings in seven groups, About shows 0.2.0 (1), Preview plays (log: "preview: Daniel (Compact) at 0.95x"). The simulator dropped and delayed taps, so the swipe's question is left to device check 4; the view model's tests cover it.
- The README's Settings screenshot (`docs/screenshots/settings.png`) shows the old Voice group: retake on the phone during the device checks (`xcrun devicectl device capture screenshot`).
- Review done: C1, C2, C3, C5, T1 (part), T2, T3 fixed; C4 (the Finish step) and T4 not done; recorded in the plan and on #38. 371 tests pass.
- Device check 1, first try: Preview read only "Morning!", the sample's first phrase. Fixed: Preview reads the sample's whole first line (`VoicePreview.text`, tested); 372 tests pass. Reinstalled and launched with `--console` (log in the session scratchpad). Check 1, second try: Andy says Preview sounds fine now. **Check 1 passed.**
- Andy: no Source Code or Licence links in About (a bought app should not look like a hobby project); About is the version alone, plan decision 7 and the README updated. Reinstalled. **Check 2 (Cue Voice) passed** (Andy). Check 3, first try (Andy): the take details went when the take ended, and Cue Voice offered female voices beside Stephanie. Fixed: the details line stays once the take is over (`PromptViewModel.diagnostics`), and Cue Voice offers only voices not of the presenter's gender, never the presenter's own; a pick that stops being offered is Automatic again (`VoiceCatalogue.cueOptions(from:presenter:)`). 374 tests pass. Plan decisions 2 and 5, check 3 and the README updated. Then Andy asked whether the details line was needed at all: it is a diagnostic, and the console's take summary has more. **Removed** at his yes: no line, no Show Take Details switch (plan decision 5, check 3, the README and PRD §8.3 updated). **Check 3 passed** (Andy: the rest of it, the Cue Voice list, passes). **Check 4 (swipe to delete) passed** (Andy). Andy's part done (step 9): the record (store name Earwig Ear Prompter, Earwig being taken), the explicit App ID, the internal group, the Keychain items (present, checked without reading them; the team's key, shared with PhysiMate). Next: the first upload with his yes (step 10), then checks 5 to 7. Retake `docs/screenshots/settings.png` on the phone before the Finish step.
- Andy, during check 4: the Scripts screen's paste hint no longer says "on your Mac": "Copy a script in Markdown or plain text, then paste it here." (PRD §8.1 too.) Record it in the Results. Then checks 2 to 4, then Andy's part (Keychain items, App Store Connect record, internal group), the first upload with his yes, and checks 5 to 7.

