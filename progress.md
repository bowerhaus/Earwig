# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Plan:** 015, Write and Edit Scripts — `plans/015-script-editor.md`
**Issue:** [#43](https://github.com/bowerhaus/Earwig/issues/43)
**Branch:** `script-editor` (from `main` at `ab9ea05`)
**Mode:** autopilot (`/plan_autopilot`): carry on through every step below, stopping only for the device check or a real decision.
**Manual test:** device, on Andy's iPhone 14 Pro (the plan's Verification).

## Checklist

- [x] Set up: plan approved, progress.md
- [ ] 1. The Cutaway issues: drafted texts are in decision 9; file them in `bowerhaus/Cutaway` with Andy's yes, asked at the device-check pause (moved there so the build isn't held up)
- [ ] 2. The parser: PlainParser rules (decision 4), `Direction.Kind.cue`, the slate, parser version 3, the Seaside Pier, tests
- [ ] 3. The importer: `create(_:)`, `editedInEarwig`, the paste outcome to confirm, tests
- [ ] 4. The editor: `ScriptEditor` model with tests, the sheet and keyboard toolbar
- [ ] 5. The screens: New, Edit, Edit a Copy, Share, labels gone, the hint, the paste warning, the cue on the card, Hear Cues As
- [ ] Tests + lint
- [ ] Review + fixes
- [ ] Manual test: device
- [ ] Complete (commit + PR)

## Notes

