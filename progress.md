# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Plan:** `plans/009-longer-phrases.md` · **Issue:** none yet (needs Andy's yes) · **Branch:** `longer-phrases`, from `screen-mode` at `04e37c3`. Plan 008's PR #26 is not part of this plan; `gh pr view 26 --json state` says whether `main` has it.

## Where things stand

- `PhraseSplitter.maxClauseWords = 20`: a clause is cut only past 20 words. `PhraseList.currentVersion` is 2. Tests and lint pass (323 tests).
- Next: the device check, a take of the script with "…that ground flour for this village…". Then Results, the PRD version bump and Document History row, the issue and the PR.
