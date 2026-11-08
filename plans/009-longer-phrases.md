# Plan 009: Longer Phrases

**GitHub Issue:** none yet (to open on Andy's yes; the PR then says "Closes #N")
**Branch:** `longer-phrases` (from `screen-mode` at `04e37c3`, so the phone keeps Screen mode; PR #26 carries plan 008 and is not yet merged)
**Status:** In progress.
**Manual test:** device, on Andy's iPhone 14 Pro with the SK18: a take of a script with a long clause that has no punctuation. (Fluff handling was tried on this branch and dropped; see "Tried and dropped".)
**Goal:** The voice should not stop in the middle of a clause. On a take on 2026-11-08 the splitter cut a 14-word clause with no punctuation into two halves of seven, so the voice ended "…that ground flour for" with a sentence's fall and a pause, the presenter paused with it, and the recogniser heard a full stop there. After this plan a clause is never cut unless it is longer than 20 words.

**PRD references:** §3 Glossary ("Phrase").

---

## Scope

**In:** `PhraseSplitter`, the parser version (so stored scripts are split again), the splitter's tests, the PRD's definition of a phrase, the device check.

**Out:**
- cutting at a natural word (before "for", "that", "and" and the like). Andy chose longer phrases instead; that stays the fallback for a clause past 20 words if it is ever needed.
- anything the voice or the screen does after a fluff. It was tried here and dropped (below); the ending after a fluff in the last phrase is a follow-up issue.

## Design decisions

1. **A clause up to 20 words is one phrase** (Andy, 2026-11-08: "Allow longer phrases"). `maxWords` stays 12 and is still the limit for packing clauses together into one phrase. A new `maxClauseWords` of 20 is the limit for a single clause. A clause past it is cut into near-equal pieces of at most 12, as before.
2. **Stored scripts are split again.** `PhraseList.currentVersion` goes from 1 to 2, so `ScriptImporter.refreshIfStale` rebuilds every step from its source text. Takes are kept: they belong to the script, not the step.
3. **The cost:** a long clause plays in one go, so the voice can get further ahead within it, and the pacer has a longer phrase to slow down in. There is no gate inside it.

## Verification

- `PhraseSplitterTests`: a 14-word clause after a comma stays whole; a 20-word sentence with no break is one phrase; a 24-word one is cut 12 and 12.
- The sample script has 26 phrases, not 27: "The path climbs about three hundred feet in less than half a mile." is no longer cut after "feet".
- The full suite and SwiftLint.
- **Device:** a take of the script that showed the problem. The voice reads the long clause without a break, and the take follows through it. Recorded only as Andy reports it.

## Tried and dropped: stopping for a fluff

On takes of the next step on 2026-11-08, a fluff left the voice far ahead. A phrase always plays to its end. After "…round the hillside" and a stop, the voice read all of "The fall over that half mile is only about six feet," and waited for Andy to say it from memory. After "…which tells you about" and a stop, the gate had already opened on the estimate's coast through the recogniser's delay (the wrong word reached the engine a second later), and the voice read all of "by eye and by level, long before anyone had a laser." Andy asked for the fix to be folded into this plan ("Fold into 009"), and for the text to go back to the start of the phrase after a fluff, as he had to scroll back by hand or start mid-phrase.

What was built, in two commits (`7caa5a7`, `efaac54`, reverted together):
- **The voice stopped for a stopped presenter:** heard, then nothing of the script for 2 s inside a phrase, or 1.2 s after a word off the script, with the voice more than the lead and 3 words past the last word heard. It queued the first phrase not begun, and no gate opened until the presenter was heard again.
- **The text went back after a fluff** to the start of the phrase, on a word off the script and 1.2 s, or 4 s stopped inside a phrase, until a script word was heard.
- In the simulated takes the second fluff's voice stopped at word 56–60 instead of 64, and the first fluff's phrase was given again.

On the phone:
- **First take:** "It's better", but wrong towards the end. A pause for a direction ("Point ahead") took back a phrase and the direction and played them again behind Andy, and a pause at a full stop cut the last phrase short, so it never finished. A clean phrase end was then excluded from the rule.
- **Second take:** "Nope its worse." The log shows why: the recogniser mishears some words every time ("leat" as "elite", "by eye" as "by iron"), each looked like a fluff, and the voice stopped, gave the phrase again, stopped again as it found Andy past it, and moved on: six stops in the first 30 s. The simulated recogniser does not mishear the same word every time, so the simulated takes could not show it.

Andy then tried the build from `main`, from before plan 008 ("I just have the feeling that before we made the changes to do with the screen prompter, that the audio prompter was better"): "It's okay. I'm not sure it's any better. … I'm not sure we have made anything worse." Its log agrees: within two words of the lead 30–41% of the time, against 23–52% on the later builds. It also showed the ending problem from before plan 008: a fluff in the last phrase, after the voice has given it, is never given again, and the take completes three seconds later, eight words short.

Dropped at Andy's word ("Yes, drop them"). Telling a fluff from a misheard word is what both rules rest on, and on the phone the recogniser blurs the two. For now, Back after a fluff plays the presenter's phrase again (with the voice a phrase ahead) and moves the text to its start.

## Results

**Device check, 2026-11-08, iPhone 14 Pro with the SK18.** Step 1 of a made-up-for-the-phone script, whose second sentence has a 14-word clause with no punctuation: rendered as one phrase ("at a watermill that ground flour for this village for nearly three hundred years.", 4.26 s). Andy: "the long clause sounded right."

The cost of decision 3 showed on the same take: a fluff early in that clause, and the voice read the clause to its end, about four seconds, where the old cut would have stopped it after "…flour for".
