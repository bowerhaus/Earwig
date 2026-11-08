# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Plan:** `plans/009-longer-phrases.md` · **Issue:** none yet (needs Andy's yes) · **Branch:** `longer-phrases`, from `screen-mode` at `04e37c3`. Plan 008's PR #26 is not part of this plan; `gh pr view 26 --json state` says whether `main` has it.

## Where things stand

- `PhraseSplitter.maxClauseWords = 20`: a clause is cut only past 20 words. `PhraseList.currentVersion` is 2. Tests and lint pass (323 tests).
- Fluff handling (the voice stopping, the text going back) was tried and dropped at Andy's word; recorded in the plan under "Tried and dropped". The code is as it was at `100c784`.
- Next: Andy's verdict on step 1's long clause read as one phrase (the take completed on 2026-11-08, but no verdict was given on it yet). Then Results, the PRD version bump and Document History row (§3), CLAUDE.md's status, the issue and the PR.
- Follow-up issue draft, not opened: after a fluff in the last phrase the voice never gives it again, and the take completes `endGrace` (3 s) later, short of the end (seen on `main` too).
