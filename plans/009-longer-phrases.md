# Plan 009: Longer Phrases

**GitHub Issue:** none yet (to open on Andy's yes; the PR then says "Closes #N")
**Branch:** `longer-phrases` (from `screen-mode` at `04e37c3`, so the phone keeps Screen mode; PR #26 carries plan 008 and is not yet merged)
**Status:** In progress.
**Manual test:** device, on Andy's iPhone 14 Pro with the SK18: a take of a script with a long clause that has no punctuation.
**Goal:** The voice should not stop in the middle of a clause. On a take on 2026-11-08 the splitter cut a 14-word clause with no punctuation into two halves of seven, so the voice ended "…that ground flour for" with a sentence's fall and a pause, the presenter paused with it, and the recogniser heard a full stop there. After this plan a clause is never cut unless it is longer than 20 words.

**PRD references:** §3 Glossary ("Phrase").

---

## Scope

**In:** `PhraseSplitter`, the parser version (so stored scripts are split again), the splitter's tests, the PRD's definition of a phrase, the device check.

**Out:** cutting at a natural word (before "for", "that", "and" and the like). Andy chose longer phrases instead; that stays the fallback for a clause past 20 words if it is ever needed.

## Design decisions

1. **A clause up to 20 words is one phrase** (Andy, 2026-11-08: "Allow longer phrases"). `maxWords` stays 12 and is still the limit for packing clauses together into one phrase. A new `maxClauseWords` of 20 is the limit for a single clause. A clause past it is cut into near-equal pieces of at most 12, as before.
2. **Stored scripts are split again.** `PhraseList.currentVersion` goes from 1 to 2, so `ScriptImporter.refreshIfStale` rebuilds every step from its source text. Takes are kept: they belong to the script, not the step.
3. **The cost:** a long clause plays in one go, so the voice can get further ahead within it, and the pacer has a longer phrase to slow down in. There is no gate inside it.

## Verification

- `PhraseSplitterTests`: a 14-word clause after a comma stays whole; a 20-word sentence with no break is one phrase; a 24-word one is cut 12 and 12.
- The sample script has 26 phrases, not 27: "The path climbs about three hundred feet in less than half a mile." is no longer cut after "feet".
- The full suite and SwiftLint.
- **Device:** a take of the script that showed the problem. The voice reads the long clause without a break, and the take follows through it. Recorded only as Andy reports it.

## Results

(After the device check.)
