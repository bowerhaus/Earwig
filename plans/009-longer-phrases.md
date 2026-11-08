# Plan 009: Longer Phrases, and Fluffs: the Voice Stops and the Text Goes Back

**GitHub Issue:** none yet (to open on Andy's yes; the PR then says "Closes #N")
**Branch:** `longer-phrases` (from `screen-mode` at `04e37c3`, so the phone keeps Screen mode; PR #26 carries plan 008 and is not yet merged)
**Status:** In progress.
**Manual test:** device, on Andy's iPhone 14 Pro with the SK18: a take of a script with a long clause that has no punctuation, and takes with a fluff and a stop.
**Goal:** The voice should not stop in the middle of a clause. On a take on 2026-11-08 the splitter cut a 14-word clause with no punctuation into two halves of seven, so the voice ended "…that ground flour for" with a sentence's fall and a pause, the presenter paused with it, and the recogniser heard a full stop there. After this plan a clause is never cut unless it is longer than 20 words.

On two takes of the next step the same day, a fluff left the voice far ahead (Andy folded the fix into this plan, 2026-11-08: "Fold into 009"). A phrase always played to its end, so after "…round the hillside" and a stop the voice read all of "The fall over that half mile is only about six feet," and then waited for him to say it from memory, though he had stopped before he could take it in. After "…which tells you about" and a stop, the gate had already opened on the estimate's coast through the recogniser's delay (the wrong word reached the engine a second after), and the voice read all of "by eye and by level, long before anyone had a laser." After this plan the voice stops once the presenter has plainly stopped, and gives the phrase again when they are heard.

On the first take with the stop, it was better, but it went wrong towards the end: a pause at the end of a phrase, while Andy pointed for a direction, took back the phrase and the direction, and a pause at a full stop cut the last phrase short. Andy also found the text no harder to read but harder to restart from: after a fluff it stays where he stopped, so he has to scroll back by hand or start mid-phrase. Plan 008 made the text go back only when a step back is heard; before it, the screen showed the voice's whole phrase while it waited.

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
- the voice's phrase lit on the screen while it waits (off by default since plan 008). The text going back to the phrase's start does the job it did.

## Design decisions

1. **A clause up to 20 words is one phrase** (Andy, 2026-11-08: "Allow longer phrases"). `maxWords` stays 12 and is still the limit for packing clauses together into one phrase. A new `maxClauseWords` of 20 is the limit for a single clause. A clause past it is cut into near-equal pieces of at most 12, as before.
2. **Stored scripts are split again.** `PhraseList.currentVersion` goes from 1 to 2, so `ScriptImporter.refreshIfStale` rebuilds every step from its source text. Takes are kept: they belong to the script, not the step.
3. **The cost:** a long clause plays in one go, so the voice can get further ahead within it, and the pacer has a longer phrase to slow down in. There is no gate inside it. Decision 4 is what stops it running away.
4. **The voice stops for a presenter who has stopped.** On each tick, once the presenter has been heard since the start or the last move: if they stopped inside a phrase and no new script word has been heard for `stopSilence` (2 s), or a word off the script has been heard since the last one and nothing of the script for `stopSilenceOffScript` (1.2 s), and what the voice has given is more than `lead + stopMargin` (3) words past the last word heard, the voice stops. A stop at the end of a phrase with nothing wrong heard is a pause, not a fluff (the first device take: a pause for a direction, and one at a full stop). If it is between phrases, it takes back the phrase it gave. Either way it queues the first phrase the presenter has not begun, as a re-anchor does. Less than 2 s stopped the voice in simulated slow reads; the margin keeps it out of an ordinary phrase-end pause.
5. **Nothing is given again by itself.** After the stop no gate opens until a script word is heard (`stoppedForPresenterAt`), so the voice waits however long the presenter does, then gives the phrase as they come to it. Automatic re-giving was tried and dropped in plan 005; this is not that.
7. **After a fluff the text goes back to the start of the phrase** the presenter stopped in, gliding as it does for Back, until a script word is heard; then it follows them from wherever they take it up. It goes back on a word off the script and `stopSilenceOffScript`, or after `screenBackSilence` (4 s) stopped inside a phrase: a pause inside a phrase can be meant (device check 1 of plan 008 paused 3 s after "The plan is simple:"), and the text stays on the next word for that. The same with no voice. The engine counts these moves in the snapshot (`placeMoves`) so the screen glides.
6. **Cut, not faded.** The voice stops where it is, mid-word if need be. The presenter has stopped listening for it by then, and the phrase is given again whole.

## Verification

- `PhraseSplitterTests`: a 14-word clause after a comma stays whole; a 20-word sentence with no break is one phrase; a 24-word one is cut 12 and 12.
- The sample script has 26 phrases, not 27: "The path climbs about three hundred feet in less than half a mile." is no longer cut after "feet".
- `FollowEngineTests`: the voice stops after 2 s of quiet with the voice seven words past the last word heard, gives nothing however long it waits, and gives the phrase again on the next word; one wrong word stops it after 1.2 s.
- Simulated takes at lead 5 and the three paces (2.5 words a second; 4; 4 in bursts a second apart):
  - **The first fluff** (a wrong word in phrase 3, 14 s of quiet, back a word and on): phrase 4 is given twice, the voice is silent through the pause, and the presenter never waits. Before, phrase 4 was given once and the presenter was left to say it from memory.
  - **The second fluff** (a wrong word after word 46, 5 s of quiet, then straight on): the voice got to word 56, 58 and 60 at the three paces. Before, it got to 64, the end of the next phrase, at every pace.
  - **A ten-second stop** (an existing scenario): phrase 4, begun before the stop, is now stopped and given again; the presenter is back in step within a phrase, as before.
  - **A pause at a phrase end** (2.5 s after word 33, with phrase 4 ten words): nothing is stopped or played again. It failed before decision 4 was narrowed, as on the phone.
  - **The text after a fluff**, with a voice and without, at all three paces: after "gravy" and a 4 s stop it rests on the phrase's first word until the presenter takes it up, and moves back no other time; after three off-script words and back two, it goes back to the phrase's start and then follows.
  - The pauses of plan 008's device check 1 (3 s at a phrase end, after a colon, after "village") still leave the text on the next word.
  - Every other scenario is unchanged.
- The full suite and SwiftLint.
- **Device:** a take of the script that showed the problem. The voice reads the long clause without a break, and the take follows through it. Then a take with a fluff and a stop: the voice stops soon after, and gives the phrase again when Andy carries on or goes back. Recorded only as Andy reports it.

## Results

(After the device check.)
