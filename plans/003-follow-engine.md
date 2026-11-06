# Plan 003: Follow Engine

**GitHub Issue:** [#7](https://github.com/bowerhaus/Earwig/issues/7) (PR must include "Closes #7")
**Branch:** `follow-engine` (from `main` at `25e2d53`, after plan 002 merged)
**Status:** Reviewed by Andy (2026-11-06); issue #7 open; not started
**Manual test:** none. The engine is pure Swift with no audio; the feel of following is judged on the phone in stage 5, when the listener and player drive it.
**Goal:** Build the engine that decides what the voice does. Given a step's phrases with word timings, the words the recogniser hears and the player's position, it says when to play, how fast, when to wait, when to step back or jump, and where the presenter is. It is pure Swift with time passed in, so every rule of PRD §5 is tested here against fixture word streams and a simulated take, before any of it reaches an earpiece.

**PRD references:** §3 Core Concepts (lead, position), §4.4 Following, §4.5 Starting a take, §4.8 Settings (start), §5 Follow Engine Specification, §11 (numbers, years and compounds), §12 stage 3, §14 Success Criteria.

---

## Scope

**In:** the matcher (window, runs, folding of spellings, compounds, contractions and numbers against what is heard, lost and found); the presenter estimate (measured recogniser delay and speaking rate); the pacer (hybrid and phrase-gated speed, gates, waiting, stepping back, jumping ahead); the engine's state machine with the three starts (slate with a reply, slate alone, tones only), manual controls (Hold, Back, Forward, Restart, Stop) and the end of the step; the engine's settings as a value; an adapter from a step's `PhraseList` to the engine's input; unit tests per rule and a simulated take (presenter, recogniser and player on a fake clock) for the scenarios of PRD §12 stage 3.

**Out:** rendering and real word timings (stage 4; tests use made-up timings); the player and its audio clock (stage 4); the `Listener` feeding the engine, the Slater's audio, the Prompt screen and route check (stage 5); Screen mode (stage 6); the settings screen and its `UserDefaults` wrapper (stage 7); fixed pace (P1). The slate's wording, the cue voice and the tones' sound are stages 4 and 5; the start setting's place on the Settings screen is stage 7. Issue #6 (a parser fixture shaped like a full Cutaway script) stays open: it needs Andy's list of the kinds of section his scripts have.

## Design decisions

1. **Time is passed in.** The engine is a value-type state machine in `Engine/` (Foundation only; `engine_purity` holds). Every input carries a time in seconds on one engine clock (the audio clock in stage 5); the host also calls `tick(at:)` about ten times a second so time-based rules (gates, speed, lost) run without input. Nothing reads the wall clock, so tests are deterministic. One entry point: `mutating func handle(_ event: FollowEvent, at time: TimeInterval) -> [FollowCommand]`, and a `snapshot` of the state for the screen and diagnostics.

2. **The engine's input is plain values, built outside it.** `FollowScript` is a list of `FollowPhrase` (kind spoken or cue, its script words, each word's start time in the rendering and the rendering's duration), with every spoken word given a flat index across the take. `PhraseList` and `Phrase` live outside `Engine/` (Models and Services), so the adapter `FollowScript(phraseList:timings:)` lives in `Models/` and the engine never sees a model or a `Phrase`. Cue phrases carry no script words and are never matched.

3. **A take follows one step, so "the whole script" is the step**. PRD §5.3 widens a lost search "to the current step, then the whole script", but a take is one step and ends at its end (§4.7, §8.3), so a match in another step has nowhere to go. The engine is given the take's step only, and a lost search widens to the whole of it. The input is a list of phrases, so the host could pass more than one step later without changing the engine.

4. **Heard words come as the recogniser gives them** (PRD §4.3, plan 001 findings 2 and 3). Two events: `.interim(text)`, the whole untimed block since the last final, rewritten on every result; and `.final(words)`, each word with its start time on the engine clock, which settles the block. The engine keeps the position as it stood before the block and re-aligns the whole block from there on every interim result, so a rewrite of the block's last words needs no bookkeeping (the spike's follower did the same). Heard text is read into words with `ScriptWords.words(in:)`, so heard number words group into one number as script words do. Each word's first appearance in an interim block is stamped with the time it arrived, which later gives the recogniser's delay against the final's start time.

5. **Matching, as PRD §5.3, with the folds plan 002 left to this stage.** A heard word is matched within a window around the expected position (8 behind to 12 ahead). It matches a script word when:
   - the normalised forms are equal;
   - both are numbers of the same value, or the heard word is digits still building up to the script's number ("18" or "189" on the way to "1890") — the prefix counts only for the last word of an interim block, as a later result will finish it;
   - the forms are within an edit distance (with transpositions) of 1 for words of five to seven letters and 2 for eight or more. This also covers most British and American spellings ("colour" and "color", "realise" and "realize", "centre" and "center");
   - they are a pair in a short spelling table for the rest ("grey" and "gray", "tyre" and "tire", "kerb" and "curb", "plough" and "plow", "aluminium" and "aluminum"), as Cutaway's `pipeline/script.py` folds them.
   
   Compounds and contractions match across a word boundary, both ways: one heard word against two script words joined ("seawall" for "sea wall") or two heard words against one script word ("sea wall" for "seawall", "there is" for "there's"). Contractions come from a table (`theres` is "there is", `its` is "it is" or "it has", `dont` is "do not", `im` is "I am", `youre`, `were` as "we are" beside the word "were", `wont`, `cant`, `isnt`, `ive`, `well` as "we will" beside "well", and so on), since "theres" and "there is" are not near in spelling. A match across two words counts as both words of a run.

6. **Runs decide confidence; finals decide permanence.** PRD §5.3 says a run of two "commits" the position and §5.1 says finals commit it. Here they are two things: a run of two consecutive matches (three when lost) makes the position **confident**, and a single match leaves it **tentative**; a final makes the block **settled**, the base for the next block, where an interim block may still be rewritten. Within a run, one script word may be skipped (the recogniser dropped "to" in plan 001) but a heard word may not. A tentative match moves the expected position but no gate, step back or jump acts on it. Among several candidates, a word that continues the current run wins, then an exact or number match over a near one, then the one nearest the expected position, ahead before behind.

7. **Lost and found.** The presenter is lost when `lostWords` (6) heard words in a row match nothing, or `lostSeconds` (4) pass from the first unmatched word with words still arriving. Silence is never lost: a presenter who stops talking is waiting, and so is the voice. When lost the window is the whole step and a run of three is needed. Unmatched words are dropped; the engine never guesses a position.

8. **The presenter estimate** (PRD §5.4, plan 001 findings 5 and 6). The position used for gates and speed is the last confident word, advanced by the presenter's speaking rate over the time since it first appeared, plus the recogniser's delay. Both are measured: the delay as the median, over the last 20 words, of first appearance minus the final's start time (default 0.9 s until measured, kept within 0.3 to 2 s); the rate in words a second over the last 10 s of finals, with pauses over a second taken out (default 2.5, within 1 to 4). The estimate stops advancing `maxCoast` (1.5 s) after the last interim result, so a presenter who has stopped does not drift on through a gate, and it never runs past the end of the phrase the voice is in. It does not advance after a final until the next interim result unless the voice has just started a phrase, which is the case plan 001 saw stall: a short phrase after a pause, its first interim result 1.5 s late.

9. **The lead now means the head start the presenter feels**. With the delay added in the estimate, a lead of 5 would be about 5 words of felt head start plus nothing for the recogniser, where in plan 001 it was about 2 plus 3 of delay. The engine's default lead is 3 words, roughly what lead 5 felt like in the spike, and stage 5 tries 3 against 5 by ear on the phone. The setting stays in words.

10. **Pacing** (PRD §5.4). The error `e` is (voice position − presenter estimate) − lead, in words. Hybrid speed is clamp(1 − k·e, minSpeed, maxSpeed) with k = 0.05 and bounds 0.85 to 1.2, changing by no more than 0.1x a second and sent only when it moves by 0.02 or more. **The PRD writes 1 + k·e, which speeds the voice up when it is already too far ahead; the sign is fixed here and in the PRD.** Phrase-gated mode keeps 1.0x. A gate is the end of each spoken phrase: the next phrase plays only when the estimate is at least (last word of the phrase − lead). While waiting the speed logic is off; a released phrase starts at 1.0x. A cue phrase is gated with the spoken phrase before it and the next spoken phrase follows it straight away.

11. **One rule for stepping back, jumping ahead and picking up**. PRD §4.4 and §5.4 give three slightly different targets (the phrase the presenter is in; the phrase containing presenter + lead; the next phrase start at or after presenter + lead), and the last can skip a whole phrase: a presenter two words from the end of a phrase, with lead 5, would never hear the next one. One rule, **re-anchor**: the voice stops and queues the first phrase that starts after the presenter's confident position, released by the usual gate. It applies when:
    - the presenter steps back: a confident position more than two words behind the last confident one while the voice is past the start of the phrase the presenter is now in (the restart-after-the-gate case from plan 001's third fluff); a step back that the voice has not passed needs nothing, as the gate already holds;
    - the presenter is ahead: the confident position is past the last word the voice has played (e < −lead), in place of speeding up beyond maxSpeed;
    - the presenter is found again after being lost.
    
    So the voice never repeats a word the presenter has just said, and never skips one they have not.

12. **The start, with a setting for the reply** (PRD §4.5, §5.5; Andy at review). Built now because it is small, pure and tested like the rest, and easy to drop if the phone says otherwise (the slate flow is still open question 1). A start mode in the settings chooses one of three:
    - **Slate with a reply** (the default): the engine emits the slate cue (its text built by the host), and once the cue has ended it matches what is heard against the slate's words (the step number or shot ID, "take", the take number, numbers by value) with the same matcher. Two of the three heard, or a tap, emits the tones and then phrase 1 after the tones' duration. Repeating the slate also gives the engine its first measure of the recogniser's delay.
    - **Slate alone**: the slate cue, then a pause (`slateGap`, default 3 s) for the presenter to say it to the camera if they want, then the tones and phrase 1. Nothing is listened for; a tap skips the pause.
    - **Tones only**: the tones, then phrase 1.
    
    The audio of the cue and the tones is stages 4 and 5's; the engine only orders them. A shot ID said as letters and numbers ("W three one") is matched only as far as the matcher already can; better handling waits for real scripts in stage 5.

13. **Manual controls and the end.** Hold stops the voice at once and freezes it; matching goes on, and releasing Hold re-anchors. Back and Forward stop the voice and play the previous or next phrase now, and the presenter's position follows the voice until the next confident match. Restart returns to the step's first phrase, through the tones, not the slate. Stop ends the take as `stopped`. The take completes when the voice has finished the last phrase and the presenter's estimate reaches the last word, or 3 s after the voice finished with the presenter in the last phrase.

14. **Commands and the snapshot** (PRD §5.2). Commands: `playCue(.slate)`, `playTones`, `play(phrase:speed:)`, `setSpeed(_)`, `stopVoice`, `finished(outcome)`. The player reports `.voiceProgress(phrase:offset:)` (time into the rendering) and `.phraseEnded(phrase)`; the engine maps an offset to a word with the phrase's word start times. Queuing the next phrase gaplessly is the player's concern in stage 4. The snapshot holds the status (slate, speaking, waiting, lost, held, finished), voice position, presenter position (confident and estimated), confidence, speed, error, and the measured delay and rate, for the Prompt screen, Screen mode and the Listening check.

15. **A simulated take for the scenario tests.** A test harness (not shipped) runs a fake clock in 50 ms steps with: a presenter who speaks a script of their own (words at a rate, pauses, repeats, off-script words, numbers said as words); a recogniser that turns it into interim blocks about 0.9 s late and a final after each pause, writing numbers as digits that build up ("18", "189", "1890") and compounds joined ("seawall"); and a player that plays the commanded phrase at the commanded speed from made-up word timings and reports progress and phrase ends. Each scenario asserts the commands and measures that matter: the lead error, waits at gates, words repeated or skipped by the voice. The fixtures are made-up text (the repo is public), with the sample harbour walk as the main one.

## Files

| File | Purpose |
|------|---------|
| `Engine/FollowScript.swift` | `FollowPhrase`, `FollowScript`: phrases, kinds, script words with flat indices, word start times, durations |
| `Engine/FollowSettings.swift` | Lead, pacing mode, speed bounds, k, window, run lengths, lost thresholds, coast, start mode and slate gap; defaults (lead 3, slate with a reply) |
| `Engine/FollowEvent.swift` | Events (start, interim, final, voice progress, cue ended, tones ended, phrase ended, tap, Hold, Back, Forward, Restart, Stop) and commands |
| `Engine/WordFolding.swift` | Edit distance, the spelling table, contractions, compound joins, number value and digit prefix |
| `Engine/Matcher.swift` | Block alignment from a base position: window, candidates, runs, confidence, lost and found |
| `Engine/PresenterEstimate.swift` | Measured delay and rate; the estimate with its coast limit |
| `Engine/Pacer.swift` | Error, hybrid speed with its rate limit, gates, re-anchor targets |
| `Engine/FollowEngine.swift` | The state machine: slate, tones, speaking, waiting, lost, held, finished; manual controls; snapshot |
| `Models/FollowScript+PhraseList.swift` | The adapter from a step's `PhraseList` and a rendering's timings |
| `EarwigTests/WordFoldingTests.swift`, `MatcherTests.swift`, `PresenterEstimateTests.swift`, `PacerTests.swift`, `FollowEngineTests.swift` | One test or more per rule |
| `EarwigTests/Simulation/` | `SimulatedPresenter`, `SimulatedRecogniser`, `SimulatedPlayer`, `TakeSimulation` and `FollowScenarioTests` |

## Steps

1. **Folding.** `WordFolding` with tests: equal forms; numbers by value ("1890", "eighteen ninety" and a heard "1890"; "300" and "three hundred"); a digit prefix matching only as the last word of an interim block; edit distance by length ("harbour" and "harbor", "centre" and "center"; nothing under five letters, so "boat" and "coat" never match; an exact candidate in the window beats a near one, since "boats" and "coats" are one apart); the spelling table; "seawall" and "sea wall" both ways; "there is" and "there's" both ways; "were" as itself and as "we are".
2. **Matcher.** `Matcher` with tests from fixture word streams: a clean read is all confident; a common word alone ("the") moves nothing; one dropped script word inside a run; an inserted heard word breaks a run; a block rewritten mid-word re-aligns; six unmatched words make it lost; four seconds of unmatched speech make it lost; silence does not; a lost search finds a run of three elsewhere in the step and not a run of two; candidates prefer the run, then nearness, ahead before behind.
3. **Presenter estimate.** Tests: the delay and rate measured from finals paired with first appearances; defaults before any; the clamps; the coast limit; no advance after a final until the next interim result, except just after the voice starts a phrase; never past the voice's phrase end.
4. **Pacer.** Tests: speed from the error with the corrected sign; the bounds; the rate limit; the 0.02 threshold; phrase-gated at 1.0x; the gate opens at (end − lead) and not before; a released phrase starts at 1.0x; a cue phrase follows its gate and the next spoken phrase follows it; re-anchor targets for a step back, ahead and found.
5. **Engine.** `FollowEngine` with tests: slate with a reply (slate, the reply matched by two of three words with the step number said as a word or digits, then tones, then phrase 1; a tap in place of the reply; nothing heard before the cue ends counts); slate alone (the gap, then tones, and a tap skipping it); tones only; Hold, Back, Forward, Restart and Stop; completion at the end of the step both ways; the snapshot's status through a take. The adapter from `PhraseList`, tested on the sample script.
6. **Scenarios.** The simulated take and `FollowScenarioTests`, from PRD §12 stage 3 and §14:
   - a clean read at presenting pace: lead error within two words throughout once under way (§14), no wait longer than half a second, no word repeated or skipped;
   - a slow read: the voice slows within the bounds and waits at gates, never runs more than a phrase ahead;
   - the three fluffs of plan 001: a break-off and resume mid-line, a stumble and restart of a line from its start, a restart after the gate has opened (the voice re-anchors to the next phrase and does not wait 5.4 s as the spike did);
   - a stop of ten seconds, then a restart from the last phrase: back in step within one phrase (§14);
   - a wander off script and back: the voice waits at its gate throughout, the presenter is lost, then found, and the voice re-anchors;
   - the presenter skipping a phrase ahead: the voice jumps, not races;
   - the 1890 phrase and "sea wall": no gate held by a year or a compound (plan 001's 2.8 s wait gone);
   - a short phrase after a pause with its first interim result 1.5 s late: the gate does not stall.
7. `swiftlint lint` clean (including `engine_purity` on every new file), no build warnings, all tests pass; Results filled; PRD §4.4, §4.5, §4.8, §5.3, §5.4 and §5.5 updated where the decisions above pin them (the step as the search, finals and confidence, the estimate, the speed sign, re-anchoring, the lead's meaning, the start modes), as v0.5 with a Document History row; `progress.md` emptied to its stub.

## Verification

- `xcodebuild test` passes in the simulator; no warnings; SwiftLint clean.
- The scenario tests' measures (lead error, waits, repeated or skipped words) recorded in Results.
- No device check in this stage. Whether following feels right is Andy's verdict in stage 5, on the phone.

## Review (2026-11-06)

Andy agreed decisions 3 (a lost search widens to the take's step only), 9 (the default lead comes down to 3 now the engine adds the recogniser's delay, tried against 5 by ear in stage 5) and 11 (one re-anchor rule for stepping back, jumping ahead and picking up again). On decision 12 he first chose to leave the start to stage 5, then decided to build it now, since it can be dropped later, with a setting for whether the presenter has to repeat the slate to start the take: decision 12's three start modes.

Process: `/plan_create_issue`, push on Andy's yes, then `/plan_autopilot` (a pure, unit-testable stage with no device check).

## Results

To be filled in when the plan completes.

## Review pass — 2026-11-06

Findings from `/review-branch` on branch `follow-engine`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact, and each verdict under *Assessment* is a
recommendation, not a decision. Work through them and annotate each with what was done — fixed,
or rejected and why. A finding that turns out to be wrong should say so here rather than be
deleted.

### Code

Review of branch `follow-engine` against `main`, for plan 003 and issue #7. I read the code and did not build or run tests. The branch covers the plan's scope: folding, matcher, estimate, pacer, engine with three start modes, controls, the adapter, unit tests and the simulated scenarios. `engine_purity` holds: every new `Engine/` file imports only Foundation. I found no American spellings in new names or text. Changes from the plan made during the build (window 12, `maxCoast` 0.5, gate at the phrase boundary, completion on the last word heard) are recorded in progress.md for Results. The findings below are the gaps.

**C1. WARNING: re-anchoring does nothing when the presenter is in the last phrase, so the voice repeats words they have already said** (`Earwig/Engine/FollowEngine.swift` lines 274–276, plus `toggleHold` lines 419–421 and `afterHearing` lines 242–245)
- `reanchor` returns `[]` whenever `script.firstPhrase(after: current.confident)` is nil, which is true once the presenter's confident position is in the last phrase.
- **Ahead:** a presenter who skips to the last phrase from memory leaves the voice playing the earlier phrases. Each gate opens because the estimate is past it, so the voice plays phrases they skipped at up to 1.2x. The take cannot complete until that finishes, because `isComplete` is only checked in `.done`.
- **Found:** a presenter found again in the last phrase gets the same result.
- **Hold:** pressing Hold mid-way through the last phrase sets `voice = .waiting(last)`. On release the target is nil, the gate for the last phrase is already open, and the whole last phrase replays from its start.
- The code comment says "the voice finishes or stays finished", and decision 11 says the voice never repeats a word the presenter has just said. Neither holds here.
- Fix: when the target is nil and the presenter is in the last phrase, stop the voice if needed and set `voice = .done(now)`.

**C2. WARNING: Back and Forward don't do what decision 13 says, and the change isn't recorded** (`Earwig/Engine/FollowEngine.swift` lines 432–459)
- The plan says that after Back or Forward, "the presenter's position follows the voice until the next confident match".
- The code instead puts the presenter at `firstWord[target] - 1`, with no `confidentAt`. The after-final branch of the estimate stops at the phrase's first word. So after a manual move with nothing heard, the voice plays that one phrase and then waits at the next gate.
- That may be the better behaviour, but it is not among the decisions in progress.md, and no test covers what happens after the moved phrase ends.
- Either implement the plan's rule or record the change for Results and the PRD.

**C3. SUGGESTION: after the voice jumps ahead or is re-anchored ahead, the estimate stays capped at the old phrase** (`Earwig/Engine/FollowEngine.swift` lines 252–258 and 276–282; `Earwig/Engine/PresenterEstimate.swift` line 91)
- `presenterNow()` caps the estimate at the last word of `voicePhrase`. `reanchor` changes only `voice`, not `voicePhrase`, so the cap is still the phrase that was stopped, which is behind the presenter.
- `min(estimate, cap)` then `max(estimate, base)` leaves the estimate at the raw confident word, with no allowance for the recogniser's delay.
- As a result, the first phrase after a jump opens its gate about one recogniser delay late (about 2 words), so the presenter's lead on that phrase is close to zero.
- The skip scenario (`FollowScenarioTests.aPresenterWhoSkipsAPhraseIsJumpedToNotRacedAfter`) uses `.recite`, which never waits, so it cannot catch this.
- Fix: base the cap on the phrase that gates the queued target, or set `voicePhrase` when re-anchoring.

**C4. SUGGESTION: a rewritten recogniser result can look like a step back** (`Earwig/Engine/FollowEngine.swift` lines 203–205, 233–236 and 244)
- `afterHearing` compares the new confident position with the previous one. Both are re-aligned from `settled`, so the comparison also fires when the recogniser rewrites words, not only when the presenter goes back.
- If an interim block is rewritten, or a final reads differently from its last interim, a confident run can break and the position drop by 3 or more. That counts as a step back and stops the voice.
- The interim and final filters also differ: the interim filters on `heardAt >= ignoreHeardBefore`, the final on `start >= ignoreSpokenBefore`. Around tones, Back and Forward, the same block can therefore align differently.
- Consider only treating new words that match further back as a step back, or comparing against the highest confident position in this block.

**C5. SUGGESTION: the code that starts a phrase is written twice** (`Earwig/Engine/FollowEngine.swift` lines 320–326 and 452–457)
- `advance()` and `move(by:)` both set `voice = .playing`, `voicePhrase`, `voiceStartedAt` and `voiceWord`, call `pacer.reset` and emit `.play(phrase:speed: 1)`.
- One `startPhrase(_:)` helper would keep the two in step, which also matters for C3.

**C6. SUGGESTION: plan completion items are still open** (`plans/003-follow-engine.md`, `progress.md`)
- Results is not filled in, the PRD is not at v0.5 (§4.4, §4.5, §4.8, §5.3–5.5, including the speed-sign fix), and progress.md is not yet back to its stub.
- The plan's Status line still says "not started".
- The adapter's signature is `FollowScript(phraseList:secondsPerWord:timing:)`, where decision 2 names `FollowScript(phraseList:timings:)`. Note this in Results.
- These are expected at completion, but the PR should not go up without them.

### Tests

Review of the test changes on `follow-engine` against `main`: 8 new test files and about 1,180 lines. There are no unstaged, staged or untracked test files. Overall the suite is well shaped. Each rule has a unit test, and the scenarios on a simulated take measure behaviour against PRD §14. The findings below are mostly gaps in how the engine wires the parts together. The pure parts themselves are tested well.

**T1. WARNING: No test checks that the engine measures the recogniser's delay and the presenter's rate.**
`heardFinal` lines up interim first-appearance stamps with the final's word starts by index, then feeds `estimate.recordDelay` and `recordFinalStarts`. Nothing asserts the result.
- `snapshot.delay` and `snapshot.rate` are asserted nowhere.
- The simulated recogniser's defaults (0.9 s delay, 2.5 words a second) equal `FollowSettings.defaultDelay` and `defaultRate`. A broken pairing (off-by-one stamps, a wrong group index) would leave every scenario passing on the defaults.
- Plan step 3 lists "the delay and rate measured from finals paired with first appearances".
- Fix: one scenario with, say, `recogniser.delay = 1.4`, asserting `take.engine.snapshot.delay` is close to 1.4. Or one engine unit test with an interim block and then its final.
- Code: `Earwig/Engine/FollowEngine.swift:208-225`, `EarwigTests/Simulation/TakeSimulation.swift:191`, `EarwigTests/Simulation/FollowScenarioTests.swift`

**T2. WARNING: Hold, Back and Forward are tested only from the "voice playing, nothing heard" state.**
- The release case is a no-op: `holdStopsTheVoiceAndReleaseReAnchors` releases with nothing heard, so the target is phrase 0, which is already queued. The branch that moves the voice to where the presenter got to while held is never exercised. That branch is `moves(waiting:to:.release)` (`target != next`), and it is what Hold is for. Also untested:
  - words heard during Hold not re-anchoring (`afterHearing`'s `guard !held`)
  - Hold while the voice is waiting (it should return `[]`)
- Back and Forward are never tested from `.waiting` or `.done`. Neither is the rule that words heard before a manual move are ignored (`ignoreHeardBefore` / `ignoreSpokenBefore` in `move`).
- The `.done` branch of `reanchor` is never hit: a step back after the voice has finished the last phrase.
- Fix: one test for "hold, presenter carries on into phrase 1, release gives `.play(phrase: 2)`", and one for "Back while waiting". Those cover most of this.
- Code: `Earwig/Engine/FollowEngine.swift:241, 283-287, 304-309, 417-458`; `EarwigTests/FollowEngineTests.swift:200-215`

**T3. WARNING: The slate filter for finals is untested.**
- `theSlateIsNotFollowedAsScript` covers only the interim path (`ignoreHeardBefore`).
- The final that settles "step 3 take 2 morning all" goes through a different filter (`start >= ignoreSpokenBefore`), and that filter has no test.
- The scenarios always force `.tonesOnly` (`TakeSimulation.init` overrides `settings.start`), so no slate mode reaches a final anywhere.
- Fix: add a `.final(...)` call to the existing test, asserting `presenterWord == 1` and not lost.
- Code: `Earwig/Engine/FollowEngine.swift:221`; `EarwigTests/FollowEngineTests.swift:95-105`; `EarwigTests/Simulation/TakeSimulation.swift:280`

**T4. WARNING: The clean-read threshold is looser than the requirement its comment cites.**
- The comment says "PRD §14 … 99% of samples", and `progress.md` records 99% measured. The assertion is `share(errors, within: 2) >= 0.95`.
- A regression from 99% to 95% would pass silently.
- Fix: assert `>= 0.99`, or change the comment to state the margin chosen.
- Code: `EarwigTests/Simulation/FollowScenarioTests.swift:38-40`

**T5. SUGGESTION: Dead code in the simulation harness.**
- Never used: `TakeSimulation.longestPresenterWait`, `worstLeadError`, the `stopWhenPresenterIsDone` parameter of `run`, and the recorded `commands` array.
- Removing them shrinks the harness the maintainer has to understand.
- Code: `EarwigTests/Simulation/TakeSimulation.swift:273, 289, 300, 324-325`

**T6. SUGGESTION: Two matcher tie-breaks the plan names have no test.**
- Plan step 1: "an exact candidate in the window beats a near one ('boats'/'coats')".
- Plan step 2: "ahead before behind".
- Neither `Candidate.isBetter` branch (strength, then ahead) is exercised. `theNearestCandidateWins` covers only distance and confirmation.
- Fix: one assertion each in `theNearestCandidateWins`.
- Code: `Earwig/Engine/Matcher.swift:55-57`; `EarwigTests/MatcherTests.swift:119-126`

**T7. SUGGESTION: The adapter's fallback for mismatched timings is untested.**
- `FollowScript(phraseList:timing:)` falls back to even spacing when a rendering's word count differs from the phrase's. That guards against a rendering out of step with its text.
- The test passes only matching timings.
- Fix: one extra `#expect` with a wrong-length `wordStarts`.
- Code: `Earwig/Models/FollowScript+PhraseList.swift:25`; `EarwigTests/FollowScriptTests.swift:54-56`

**T8. SUGGESTION: The Pacer's "send on reaching a bound or 1.0x" rule is never asserted.**
- In `theSpeedChangesNoFasterThanItsLimit`, the update that reaches 0.85 discards its return value (`_ = pacer.update(error: 10, at: 2)`).
- Fix: assert it returns 0.85. That covers the `atBound` branch at no extra cost.
- Code: `Earwig/Engine/Pacer.swift:48-49`; `EarwigTests/PacerTests.swift:35-36`

**T9. SUGGESTION: A small overlap and a stale fixture comment.**
- Overlap: `theSlateAloneWaitsItsGapThenTheTones` taps in `.slateGap`, and `aTapStartsTheTakeFromTheSlate` taps in `.slateReply`. Both go through the same `case .slateReply, .slateGap` branch, so one of the two tap checks can go.
  - `EarwigTests/FollowEngineTests.swift:76-79, 89-92`
- Stale comment: the `FollowScriptTests` fixture's doc comment describes "one two three" / "four five" / "six". The words are actually alpha…foxtrot.
  - `EarwigTests/FollowScriptTests.swift:6`

On proportion, the size of the suite is about right for an engine of about 1,200 lines. The overlap between the re-anchoring unit tests and the scenarios (restart after the gate, skip ahead, lost then found) is deliberate in the plan. Each side pins something different: exact commands in the unit tests, measures in the scenarios. Neither should be cut.

### Assessment

- C1 — FIX: real (`FollowEngine.swift` `reanchor` returns `[]` when `firstPhrase(after:)` is nil). For ahead, found and release with the presenter in the last phrase, stop the voice if it is playing and set it `.done`; a step back inside the last phrase leaves the voice playing (it is still ahead).
- C2 — FIX (part): keep the behaviour (the voice plays the chosen phrase, then waits at the next gate until the presenter is heard, which is the gate rule; following the voice blindly would let it run away in silence). Record it in Results and the PRD, and add a test that the voice waits after a moved phrase with nothing heard.
- C3 — FIX: real (`presenterNow` caps at `voicePhrase`, which re-anchoring leaves at the stopped phrase). Take the cap from the voice's state: the end of the playing phrase, or the word before the queued phrase when waiting.
- C4 — FIX (part): real in principle. Count a step back only when the latest match is itself confident and 3 or more words behind the last confident position, so a rewrite that breaks a run (the latest match still near the front) does not stop the voice; add a test. The interim and final filters differing around manual moves: skip (a final reaches back over words said before the move only when the move came mid-block; small and self-correcting).
- C5 — FIX: one `startPhrase(_:)` used by `advance()` and `move(by:)`.
- C6 — FIX (part): the completion items are the completion step, not a defect; record the adapter's signature in Results then.
- T1 — FIX: a scenario with a 1.4 s recogniser delay and a presenter at 2 words a second, asserting the engine's measured delay and rate.
- T2 — FIX: tests for Hold released after the presenter carried on, and Back while waiting (with C2's wait after a move).
- T3 — FIX: add the final to `theSlateIsNotFollowedAsScript`.
- T4 — FIX: assert 0.98 and say in the comment that 99% was measured.
- T5 — FIX: remove the unused measures and parameter; keep `commands` (useful when a scenario fails) — no, remove it too, nothing reads it.
- T6 — FIX: one assertion each for exact over near and ahead over behind.
- T7 — FIX: one expectation for a wrong-length timing.
- T8 — FIX: assert the bound is sent.
- T9 — FIX (part): fix the stale comment; keep both tap checks (they cover the two slate modes).

### Outcome — 2026-11-06

- C1 — fixed: with the presenter in the last phrase, ahead, found or Hold released, the voice stops and is finished (`finishVoice`); a step back inside the last phrase leaves it playing. Test `aPresenterInTheLastPhraseFinishesTheVoice`.
- C2 — fixed (part): behaviour kept (after Back or Forward with nothing heard the voice plays the phrase and then waits at the next gate); recorded in Results and the PRD; test `backWhileWaitingReplaysThePhraseThenWaitsForThePresenter`.
- C3 — fixed: the estimate's cap comes from the voice's state (the playing phrase's end, or the word before the queued phrase). The ahead test now expects the next phrase at once, two words in.
- C4 — fixed (part): a step back needs the confident word to have been heard later than the last one, so a rewrite that breaks a run does not stop the voice; test `aRewriteOfWordsAlreadyHeardIsNotAStepBack`. The interim/final filter difference around manual moves: not done (small, self-correcting).
- C5 — fixed: `startPhrase(_:)` used by `advance()` and `move(by:)`.
- C6 — fixed (part): Results records the adapter's signature; the rest is the completion step.
- T1 — fixed: `theEngineMeasuresTheRecognisersDelayAndThePresentersRate` (1.4 s delay, 2 words a second).
- T2 — fixed: `releasingHoldPicksUpWhereThePresenterGotTo`, `holdWhileWaitingStopsNothing`, `backWhileWaitingReplaysThePhraseThenWaitsForThePresenter`.
- T3 — fixed: the slate test sends the final too.
- T4 — fixed: threshold 0.98, the comment says 99% was measured.
- T5 — fixed: `longestPresenterWait`, `worstLeadError`, `stopWhenPresenterIsDone` and the `commands` record removed.
- T6 — fixed: `exactBeatsNearAndAheadBeatsBehind`.
- T7 — fixed: a wrong-length timing keeps even spacing.
- T8 — fixed: reaching 0.85 is asserted as sent.
- T9 — fixed (part): the stale fixture comment; both tap checks kept (two slate modes).

Tests: 143 pass; SwiftLint clean; no build warnings.
