# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Plan:** 015, Write and Edit Scripts — `plans/015-script-editor.md`
**Issue:** [#43](https://github.com/bowerhaus/Earwig/issues/43)
**Branch:** `script-editor` (from `main` at `ab9ea05`). Pushed only to `9380675`; later commits are local. Ask before every push.
**Mode:** autopilot (`/plan_autopilot`): carry on through every step below, stopping only for the device check or a real decision.
**Manual test:** device, on Andy's iPhone 14 Pro (the plan's Verification, 7 checks).

## Checklist

- [x] Set up: plan approved, progress.md
- [ ] 1. The Cutaway issues: drafted texts are in decision 9; file them in `bowerhaus/Cutaway` only with Andy's yes (still unasked since the device checks began; ask at the next pause)
- [x] 2. The parser
- [x] 3. The importer
- [x] 4. The editor
- [x] 5. The screens
- [x] Tests + lint
- [x] Review + fixes (review pass and outcome in the plan; issue comment posted)
- [x] Device-check fixes so far: Step, Cue, capitals (decision 2 amended on the phone); one set of buttons, Edit and More, title on the page, samples edited and reset, swipe Edit/Reset (decision 12, decision 7 amended); the title's gap; Title, Step and Cue in a glass capsule above the keyboard (decision 2 amended)
- [x] 6. Andy's next changes, agreed 2026-11-12 (below): done, 448 tests pass, lint clean, looked at in the simulator; decisions 2 and 5 amended, decision 13 added
- [x] Device-check fixes, 2026-11-12: styling, no capital in cues and the samples (Andy: "this all looks good"); Shift kept as capitals on a heading's whole line, so dictation keeps them (`b4a18ad`); Step leaves the cursor after its `##` with the line under the editor explaining (`61ec168`, Andy: "Works well")
- [ ] Manual test: device (check 1 passed; checks 2–7 still to report)
- [ ] Complete (commit + PR)

## Done: Andy's agreed changes (next: install on the phone and resume the device checks, including the Shift experiment's verdict)

1. **Shift lit after Title and Step: an experiment.** iOS has no API to set Shift. Try: while the cursor sits right after `# ` or `## ` (a title or step name's start, and the start of a step's first line), set the text view's `autocapitalizationType = .words` and `reloadInputViews()`; back to `.sentences` once the cursor leaves that spot. Only switch when `markedTextRange == nil` (not mid-dictation), and only when the mode actually changes. Keep `ScriptEditor.capitalised` as the backstop for titles and step names. On the phone, watch for keyboard flicker and dictation being cut off; Andy's verdict decides whether it stays. Andy noted the capital currently lands only once a line is finished (dictation).
2. **Cues are not capitalised.** Andy: "I don't think cues need to be capitalized." Drop the `[` case from `ScriptEditor.capitalised` and its tests (`theStartOfATitleAStepOrACueGetsACapital`, `otherTextIsLeft`), and the Shift experiment doesn't touch cues.
3. **Keep `##`, but quieter** (Andy chose this over "a blank line starts a step"). Colour the editor's text as it's typed, attributes only, the stored text unchanged: the `#`/`##` marks faint, a step name bold, the title bold and larger, `[cues]` in `EarwigTheme.cue`. All colours from `EarwigTheme` (add any new one there). Must not disturb the cursor, marked text or dictation (apply attributes to `textStorage` without replacing the text, skip while `markedTextRange != nil`). Andy found `##` then a new line "a little bit ugly".
4. **Convert the three Cutaway samples** (Harbour Walk, Weekend Loaf, Old Watermill in `Earwig/Services/SampleScript.swift`) to the documented format, as the Seaside Pier is: `# Title`, `## Step name` (drop the "1." numbering), `Shows:` as a cue line at the top of the step `[…]`, each `- ` line a plain line. Same steps in the same order, so the takes (keyed by step index) stay right; the seeder replaces unedited samples on the next launch. Update `SampleSeederTests.eachSampleParsesAsItsFormatWithWordsInEveryStep` (all `.plain` now), any test using `SampleScript.harbourWalk` as Cutaway (e.g. `ScriptEditorTests.editingASampleEditsTheSample` expects `.cutaway`), and keep Cutaway covered by `Fixtures`. Cutaway paste stays supported. Note for Completion: the README's screenshots and banner show "SHOWS" on the Harbour Walk and need retaking (`scripts/readme/make_readme_images.py` after new screenshots); plan 013's App Store screenshots too. Add a decision to the plan (decision 13) and amend decision 4/5 as needed.
5. Then: tests + lint, simulator look, commit, install on the phone with `devicectl` and launch with `--console` (the phone is often locked: ask Andy to unlock first), and resume the device checks with Andy.

## What Andy explained / settled (for the plan's decisions)

- A new line in a `##` step is a line of the script and always ends a phrase; a blank line in a step adds nothing; without any `##`, a blank line starts a step. Told to Andy; no change.
- Device check 1: Andy says the rest works (Title, Step, Cue placement, Save). Still to note in the Results: his exact verdict on "new line"/"new paragraph" and punctuation, which he didn't give separately.
- In Edit, the cursor now starts at the end of the title line (Andy: the end of a long script would scroll away, and the title shows it's the right script).
- Device check 1 passed (Andy, 2026-11-12): "new line", "new paragraph" and the punctuation all work fine. Write it into the Results at Completion.

## Notes

- 448 tests pass, SwiftLint clean.
- For Completion: README screenshots and banner (and plan 013's App Store screenshots) show "SHOWS" on the Harbour Walk and need retaking.
- The console launch's connection drops after a few minutes; relaunching closes the app, so only relaunch between checks.
- Plan 013 is in flight on `app-store-release` and touches the README, the PRD and CLAUDE.md; whichever merges second rebases those.
