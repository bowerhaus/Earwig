# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

## Plan 003: Follow engine (`plans/003-follow-engine.md`)

Mode: autopilot (/plan_autopilot), approved by Andy 2026-11-06. On resume, carry on through build, tests, review and completion without stopping, except for a CRITICAL finding or a product decision.

Branch `follow-engine` from `main` at `25e2d53` (plan 002 merged as PR #4, closing #3; PRD v0.4). Pushed to `origin/follow-engine`. Issue [#7](https://github.com/bowerhaus/Earwig/issues/7) (the PR must say "Closes #7").

**State:** the plan is reviewed (2026-11-06; its Review section has Andy's answers: decisions 3, 9 and 11 agreed; the start built now with a setting for whether the slate must be repeated, decision 12). Building.

**Next:**

1. Done: issue #7 created and the branch pushed (2026-11-06).
2. Autopilot: plan steps 1 to 6, then the checklist below.

**Checklist (plan steps):**

- [x] 1. Folding
- [x] 2. Matcher
- [x] 3. Presenter estimate
- [x] 4. Pacer
- [x] 5. Engine and the `PhraseList` adapter
- [x] 6. Scenarios (simulated take)
- [ ] Tests + lint
- [ ] Review + fixes
- [ ] Complete (commit + PR): Results, PRD v0.5, this file to its stub

**Decided while building (for Results):**

- The engine's heard word is `HeardScriptWord` (the Listener already has a `HeardWord`).
- After a final, the estimate takes the presenter to have begun a phrase the voice started a lead's worth of time ago, and no further: silence lets at most a phrase of `lead + 1` words through a gate (a short phrase after a pause and silence cannot be told apart without a speech signal).
- `maxCoast` 0.5 s, not 1.5: a longer coast ran the estimate several words past a presenter who had stopped.
- The window behind is 12 words, not 8, so a restart from the start of a long phrase is matched at once rather than through lost.
- Speed logic runs only once the presenter has been heard.
- Within a run one script word may be dropped or one heard word misheard; an inserted heard word breaks it.
- A step back is 3 or more words behind the last confident position.
- The gate is the phrase boundary: the next phrase plays when the estimate is at least (last word + 1 − lead). With the last word as the end, the simulated clean read ran 1.5 words over the lead (82% within ±2); with the boundary, 99% within ±2, none beyond 3, and the presenter never waits.
- Scenario results (simulation, lead 3, 2.5 words/s, 0.9 s delay): every scenario completes; no presenter wait in any; restart after the gate: one stop and the last phrase replayed (spike waited 5.4 s); skip ahead: one stop, the skipped phrase never played, speed within 1.2; year and compound: longest voice gap under 1.5 s (spike 2.8 s); wander: lost, gate held, picked up, no phrase repeated.
- The take completes when the last word is heard (not estimated), or 3 s after the voice finished with the presenter in the last phrase.

**Notes for building:**

- `Phrase` and `PhraseList` are outside `Engine/`; the adapter lives in `Models/`. The engine takes plain values only.
- Heard text goes through `ScriptWords.words(in:)` so heard number words group as script words do.
- The PRD's hybrid speed formula has the wrong sign (1 + k·e); the plan fixes it (1 − k·e) and the PRD gets the fix at completion.
- Plan 001's spike follower (`git show 7cb9880:Earwig/Spike/SpikeFollower.swift`) re-aligned from scratch on every result; the matcher does the same per interim block.

## Open follow-up issues (from plan 002)

- #5 "Paste or import a script.md copied as a file in Finder": goes with share-sheet and Files import, out of the MVP.
- #6 "Parser fixture shaped like a full Cutaway script.md": needs Andy's list of the kinds of section his real scripts have (kinds only, no content: the repo is public).
