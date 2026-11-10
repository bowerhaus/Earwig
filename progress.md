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
- [x] 2. The parser: PlainParser rules (decision 4), `Direction.Kind.cue`, the slate, parser version 3, the Seaside Pier, tests
- [x] 3. The importer: `create(_:)`, `editedInEarwig`, the paste outcome to confirm, tests
- [x] 4. The editor: `ScriptEditor` model with tests, the sheet and keyboard toolbar
- [x] 5. The screens: New, Edit, Edit a Copy, Share, labels gone, the hint, the paste warning, the cue on the card, Hear Cues As
- [x] Tests + lint
- [x] Review + fixes (review pass and outcome in the plan; issue comment posted)
- [ ] Manual test: device
- [ ] Complete (commit + PR)

## Notes

- Simulator: New, Edit a Copy, the Scripts and Script screens checked with `-EarwigNew YES` and `-EarwigDemo YES -EarwigEdit YES`. The keyboard toolbar didn't show in the sheet and `TextEditor` lost button edits; replaced by a bar of our own and `ScriptTextView` (decision 2, amended). Title, Step and Cue work straight after typing.
- The simulator's typing drops letters at speed; a stale-update race in the text view was fixed, and the device check watches typing and dictation.
- 432 tests pass, SwiftLint clean (after the screens).
- Review: C1, C2, C5–C8 (C7 part) and T1–T6 fixed; C3, C4 not done (reasons in the plan). 434 tests pass.
- Next: the device check on the iPhone 14 Pro, one check at a time (the plan's Verification), and Andy's yes for the two Cutaway issues (decision 9).

