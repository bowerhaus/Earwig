# Plan 009: Longer Phrases, and a Voice That Stops for a Fluff

**GitHub Issue:** none yet (to open on Andy's yes; the PR then says "Closes #N")
**Branch:** `longer-phrases` (from `screen-mode` at `04e37c3`, so the phone keeps Screen mode; PR #26 carries plan 008 and is not yet merged)
**Status:** In progress.
**Manual test:** device, on Andy's iPhone 14 Pro with the SK18: a take of a script with a long clause that has no punctuation, and takes with a fluff and a stop.
**Goal:** The voice should not stop in the middle of a clause. On a take on 2026-11-08 the splitter cut a 14-word clause with no punctuation into two halves of seven, so the voice ended "…that ground flour for" with a sentence's fall and a pause, the presenter paused with it, and the recogniser heard a full stop there. After this plan a clause is never cut unless it is longer than 20 words.

On two takes of the next step the same day, a fluff left the voice far ahead (Andy folded the fix into this plan, 2026-11-08: "Fold into 009"). A phrase always played to its end, so after "…round the hillside" and a stop the voice read all of "The fall over that half mile is only about six feet," and then waited for him to say it from memory, though he had stopped before he could take it in. After "…which tells you about" and a stop, the gate had already opened on the estimate's coast through the recogniser's delay (the wrong word reached the engine a second after), and the voice read all of "by eye and by level, long before anyone had a laser." After this plan the voice stops once the presenter has plainly stopped, and gives the phrase again when they are heard.

**PRD references:** §3 Glossary ("Phrase").

---

## Scope

**In:** `PhraseSplitter`, the parser version (so stored scripts are split again), the splitter's tests, the PRD's definition of a phrase; the engine's stop for a stopped presenter, its unit tests and simulated takes of both fluffs; the device check.

**Out:**
- cutting at a natural word (before "for", "that", "and" and the like). Andy chose longer phrases instead; that stays the fallback for a clause past 20 words if it is ever needed.
- stopping the voice at a word boundary, and resuming a phrase from a word. The voice is cut where it is and the phrase is given again from its start, which needs no change to the player.
- counting any restart after a pause as a step back (proposed for the first fluff). The stop covers that fluff, and Andy has asked before for less resetting, not more.
- holding the gate's coast at the first off-script word (proposed for the second fluff). The wrong word arrived a second after the gate had opened, so it would not have helped.
- the diagnostics line ("lead error …"), which Andy asked about: hiding it unless Settings turns it on belongs to stage 7.

## Design decisions

1. **A clause up to 20 words is one phrase** (Andy, 2026-11-08: "Allow longer phrases"). `maxWords` stays 12 and is still the limit for packing clauses together into one phrase. A new `maxClauseWords` of 20 is the limit for a single clause. A clause past it is cut into near-equal pieces of at most 12, as before.
2. **Stored scripts are split again.** `PhraseList.currentVersion` goes from 1 to 2, so `ScriptImporter.refreshIfStale` rebuilds every step from its source text. Takes are kept: they belong to the script, not the step.
3. **The cost:** a long clause plays in one go, so the voice can get further ahead within it, and the pacer has a longer phrase to slow down in. There is no gate inside it. Decision 4 is what stops it running away.
4. **The voice stops for a presenter who has stopped.** On each tick, once the presenter has been heard since the start or the last move: if no new script word has been heard for `stopSilence` (2 s), or `stopSilenceOffScript` (1.2 s) once a word off the script has been heard since the last one, and what the voice has given is more than `lead + stopMargin` (3) words past the last word heard, the voice stops. If it is between phrases, it takes back the phrase it gave. Either way it queues the first phrase the presenter has not begun, as a re-anchor does. Less than 2 s stopped the voice in simulated slow reads; the margin keeps it out of an ordinary phrase-end pause.
5. **Nothing is given again by itself.** After the stop no gate opens until a script word is heard (`stoppedForPresenterAt`), so the voice waits however long the presenter does, then gives the phrase as they come to it. Automatic re-giving was tried and dropped in plan 005; this is not that.
6. **Cut, not faded.** The voice stops where it is, mid-word if need be. The presenter has stopped listening for it by then, and the phrase is given again whole.

## Verification

- `PhraseSplitterTests`: a 14-word clause after a comma stays whole; a 20-word sentence with no break is one phrase; a 24-word one is cut 12 and 12.
- The sample script has 26 phrases, not 27: "The path climbs about three hundred feet in less than half a mile." is no longer cut after "feet".
- `FollowEngineTests`: the voice stops after 2 s of quiet with the voice seven words past the last word heard, gives nothing however long it waits, and gives the phrase again on the next word; one wrong word stops it after 1.2 s.
- Simulated takes at lead 5 and the three paces (2.5 words a second; 4; 4 in bursts a second apart):
  - **The first fluff** (a wrong word in phrase 3, 14 s of quiet, back a word and on): phrase 4 is given twice, the voice is silent through the pause, and the presenter never waits. Before, phrase 4 was given once and the presenter was left to say it from memory.
  - **The second fluff** (a wrong word after word 46, 5 s of quiet, then straight on): the voice got to word 56, 58 and 60 at the three paces. Before, it got to 64, the end of the next phrase, at every pace.
  - **A ten-second stop** (an existing scenario): phrase 4, begun before the stop, is now stopped and given again; the presenter is back in step within a phrase, as before.
  - Every other scenario is unchanged.
- The full suite and SwiftLint.
- **Device:** a take of the script that showed the problem. The voice reads the long clause without a break, and the take follows through it. Then a take with a fluff and a stop: the voice stops soon after, and gives the phrase again when Andy carries on or goes back. Recorded only as Andy reports it.

## Results

(After the device check.)
