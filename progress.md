# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

## Plan 003: Follow engine (`plans/003-follow-engine.md`)

Branch `follow-engine` from `main` at `25e2d53` (plan 002 merged as PR #4, closing #3; PRD v0.4). Not pushed. No issue yet.

**State:** the plan is written as a draft and waits for Andy's review. Nothing built.

**Next:**

1. Andy answers the four review questions at the end of the plan (the step as the lost search, the default lead with the delay added, one re-anchor rule, the slate in the engine now). Record his answers in a Review section of the plan and adjust the decisions.
2. `/plan_create_issue`; push the branch on his yes.
3. `/plan_autopilot` (pure, unit-testable, no device check), working through steps 1 to 7.

**Checklist (plan steps):**

- [ ] 1. Folding
- [ ] 2. Matcher
- [ ] 3. Presenter estimate
- [ ] 4. Pacer
- [ ] 5. Engine and the `PhraseList` adapter
- [ ] 6. Scenarios (simulated take)
- [ ] 7. Lint, warnings, tests; Results; PRD v0.5; this file to its stub

**Notes for building:**

- `Phrase` and `PhraseList` are outside `Engine/`; the adapter lives in `Models/`. The engine takes plain values only.
- Heard text goes through `ScriptWords.words(in:)` so heard number words group as script words do.
- The PRD's hybrid speed formula has the wrong sign (1 + k·e); the plan fixes it (1 − k·e) and the PRD gets the fix at completion.
- Plan 001's spike follower (`git show 7cb9880:Earwig/Spike/SpikeFollower.swift`) re-aligned from scratch on every result; the matcher does the same per interim block.

## Open follow-up issues (from plan 002)

- #5 "Paste or import a script.md copied as a file in Finder": goes with share-sheet and Files import, out of the MVP.
- #6 "Parser fixture shaped like a full Cutaway script.md": needs Andy's list of the kinds of section his real scripts have (kinds only, no content: the repo is public).
