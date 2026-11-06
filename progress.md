# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Mode: autopilot (/plan_autopilot)**: on "resume", carry on through the checklist to the PR without stopping, except at the palette pick and the manual test.

- **Plan:** `plans/002-skeleton-models-parser.md` (approved 2026-11-05)
- **Branch:** `skeleton-models-parser` (from `main` at `6d2b848`), pushed
- **Issue:** [#3](https://github.com/bowerhaus/Earwig/issues/3); the PR must include "Closes #3"
- **Manual test:** device: paste a real Cutaway script on the iPhone 14 Pro by Universal Clipboard (plan step 7)

## Checklist

- [x] 1. Script words (`Engine/ScriptWords.swift`, `WordNormaliser` change) with tests
- [x] 2. Parsers (`ScriptParser`: detection, Cutaway, plain) with tests
- [x] 3. Phrase list (Codable, cue phrases, parser version, re-derive)
- [x] 4. Models and container (Script, Step, Rendering, Take, `ModelJSON`, factory)
- [x] 5. Import (`ScriptImporter`, hash, replace by title) with tests
- [ ] 6. Theme and screens; palette candidates shown to Andy (pause for his pick) — **screens built; WAITING for Andy's palette pick** (Paper, Copper, Harbour, Sky or Violet, in `EarwigPalette` in `App/EarwigTheme.swift`). Then: fix `current` to his pick, delete the other candidates and the `-EarwigPalette` argument, finish the screenshots (empty state, plain paste, landscape)
- [ ] 7. Device check (see Manual test)
- [ ] 8. PRD v0.4, Results
- [ ] Tests + lint
- [ ] Review + fixes
- [ ] Manual test: device
- [ ] Complete (commit + PR)

## Notes

- Simulator: launch with `-EarwigPalette <name> -EarwigDemo YES` (DEBUG) to add the sample and open it without taps. A stale microphone alert from earlier test-host runs stuck on SpringBoard until the simulator was rebooted; the app itself requests nothing at launch.

- Review decisions: 4, 5, 8 agreed; 11 is one distinctive theme, not necessarily dark, no light and dark variants.
- Cutaway's parser for reference: `../Cutaway/pipeline/script.py` (`parse`), contract in `../Cutaway/docs/file-contracts.md`.

## Reminders

- The repo is public: fixtures and examples are made-up scripts, never Andy's unpublished ones. The harbour walk is in commit `7cb9880`, `Earwig/Spike/SpikeSampleScript.swift`.
- Commit locally at sensible points. Merging is Andy's.
- Install on the iPhone with `devicectl` (CLAUDE.md, Build Commands), never via Xcode.
