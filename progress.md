# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Plan:** `plans/009-longer-phrases.md` (longer phrases, and a voice that stops for a fluff) · **Issue:** none yet (needs Andy's yes) · **Branch:** `longer-phrases`, from `screen-mode` at `04e37c3`. Plan 008's PR #26 is not part of this plan; `gh pr view 26 --json state` says whether `main` has it.

## Where things stand

- `PhraseSplitter.maxClauseWords = 20`: a clause is cut only past 20 words. `PhraseList.currentVersion` is 2. Tests and lint pass (323 tests).
- Folded in at Andy's word: the voice stops for a presenter who has stopped (`stopForAStoppedPresenter`, settings `stopSilence` 2 s, `stopSilenceOffScript` 1.2 s, `stopMargin` 3), with unit tests and simulated takes of both fluffs. 327 tests pass, lint clean.
- Next: the device check (step 1 for the long clause; a fluff and a stop on step 2). Then Results, the PRD version bump and Document History row (§5 for the stop, §3 for the phrase), CLAUDE.md's status (the line "After a fluff the voice waits and re-gives nothing by itself" changes), the issue and the PR.
