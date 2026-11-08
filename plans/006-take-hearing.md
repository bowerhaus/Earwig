# Plan 006: When the Take Can't Hear the Script

**GitHub Issues:** [#18](https://github.com/bowerhaus/Earwig/issues/18) and [#19](https://github.com/bowerhaus/Earwig/issues/19) (PR must include "Closes #18" and "Closes #19"; no issue of its own, as these are plan 005 follow-ups, not a PRD §12 stage)
**Branch:** `take-hearing` (from `main` at `253d080`, after plan 005 merged)
**Status:** In progress (2026-11-08), autopilot: built and tested; device check next.
**Manual test:** device, on Andy's iPhone 14 Pro with the SK18: going off script at a phrase end, a misheard phrase end, and listening giving up (Verification).
**Goal:** A take should know when it can't follow, and say so. Today it carries on as if it can hear in two cases. When listening gives up mid-take (#18), the take is never told: it goes on showing Waiting or Lost, with no reason. When the presenter goes off script straight after a phrase end (#19), the estimate runs on as if they were still reading, and the next phrase is released before Lost is shown, about two seconds later. After this plan, a take that can no longer hear says so and ends. Off-script speech at a phrase end holds the voice at the gate, as off-script speech mid-phrase already does. Neither change may add waits to a clean read or to a misheard phrase end.

**PRD references:** §4.3 Listening, §4.4 Following, §5.1 Inputs, §5.3 Matching (lost), §5.4 Pacing (the presenter position, gates), §8.3 Prompt, §11 Risks (recognition), §14 Success Criteria.

---

## Scope

**In:**
- the listener reporting that it has given up, and the take acting on it and saying why (#18);
- a simulated take that reproduces #19 with the device's timing;
- a rule in the presenter estimate or the gate that stops the release;
- simulated takes for both sides of that rule: off script at a phrase end, and a misheard phrase end;
- a Debug launch flag that makes listening give up mid-take, for the device check;
- the device check.

**Out:**
- the mic input level as a speech signal (#9). It may help #19's other half, a pause against a late result, but it is a change of its own, and it needs Andy's judgement on false "speaking".
- what the take summary measures (#20). It works on the same estimate and is re-measured after this plan's rule, but its measure is not changed here.
- retrying listening more than once in ten seconds, or after a failed restart. This plan only reports the give-up; how often to retry stays as it is.
- Screen mode (stage 6, now plan 007).

## Design decisions

1. **The listener gives up in two places, and both are reported.** `Listener.recover()` stops in two ways:
   - The results stream fails a second time within ten seconds ("restarted too recently").
   - The restart's own `start` fails, which sets `.failed` and tears down, with only a log line.

   Both now call a new `onGaveUp(reason)`. `HeardSource` gains `onGaveUp: ((String) -> Void)?` beside `onRestart`. `TakeHost` sets it in `begin` and clears it in `tearDown`, as it does `onRestart`. The reasons are plain text for the screen: "Listening stopped after two failures in ten seconds", or the start error.

2. **A take that can't hear ends as stopped, and says why.** The options were to hold the voice and offer to listen again, or to stop. A take that cannot hear has lost its following, and the presenter would take it again anyway. Restarting listening inside the take would also go around the ten-second rule. So:
   - the host sends Stop: the take is recorded as stopped, which it is;
   - the phase becomes `.finished(.stopped)` with a stop reason;
   - the Prompt screen's Finished shows "Stopped: listening stopped" with the reason under it, and keeps Next Take, which starts listening afresh.

   The host keeps the reason as `stopReason: String?`, published for the view model. `FollowOutcome` and `TakeOutcome` are unchanged. The take summary line says `outcome stopped (not listening)`.

   If Andy, at the device check, would rather hold with a Listen Again button, that is a change to this decision and is recorded in Results.

3. **Reproduce #19 before changing anything.** The simulated takes run at 2.5 words a second, with interim results on every simulation step. They never produced the release. The device differed in two ways:
   - the rate was about 4 words a second, which is also `rateRange`'s top, so it was clamped;
   - interim results came in bursts about a second apart.

   `SimulatedRecogniser` gains `interimInterval` (default 0, as now): an interim is shown only that long after the last one. A new scenario reproduces take 12 of plan 005's device check 4:
   - a phrase is read up to its end;
   - the presenter then goes straight on with off-script words at the same rate, with no pause;
   - all of this at 4 words a second, with bursts 1 s apart, at lead 5 (the app's default).

   It must fail as things stand, with the next phrase played before `.lost`, before any rule is changed.

4. **Find exactly when the gate opens.** Reading `PresenterEstimate.position`, the release can happen before any stray word is heard. Take an interim whose last word is the phrase end ("often"), with no final after it. The estimate is that word plus `rate × (delay + coast)`. At 4 words a second and a 0.95 s delay, that is about four words on. Lead 5 asks for only three words into a seven-word gating phrase. So the gate opens on the phrase end itself, and a clean read needs exactly that. Once the next burst carries the stray words, `sinceMatch` reaches 2 and the estimate stops, but by then the phrase has played.

   The reproduction logs the estimate, the basis and the heard text at the release. The first commit records which moment it is:
   - the phrase-end word arriving;
   - one stray word (`sinceMatch == 1`) arriving;
   - or both.

   The choice of rule depends on it.

5. **The rule: a candidate is chosen by the simulated takes, not by argument.** Three candidates, tried in this order. The first one that passes every scenario in Step 3 is kept.

   - **A. A stray word holds the estimate.** With `sinceMatch == 1`, the estimate does not coast past the confident word, as already happens at `sinceMatch >= 2` (`offScript`). This fixes the case where the release comes with the first stray word. It does nothing if the release comes on the phrase-end word itself.
   - **B. Crossing a phrase boundary needs a word heard beyond it.** Coasting from the last word of a phrase, the estimate goes no further than the first word of the next spoken phrase until a word of that phrase is heard. This mirrors the rule after a final: "taken to have begun it too, and no further".
     - Off script at a phrase end, the gate then waits for a matching word.
     - On a clean read, the first word of the next phrase is heard about a delay after it is said. So a gate whose release needs the presenter more than one word into that phrase opens about half a word later than now.
     - A misheard phrase end is not affected. The misheard words are inside the phrase being finished, so the coast still reaches its end. Two or more unmatched words already stop the estimate (`offScript`), so B adds no wait there.
   - **C. Take a release back.** If Lost comes within a short time of a release (about 2 s, as in take 12), the engine stops the released phrase and re-anchors, as it does on `.found`. This is the fallback if A and B both cost a clean read too much. The presenter still hears the first word or two of the wrong phrase, so it is the weakest of the three.

   B is expected to be the one needed, if decision 4 finds the release on the phrase-end word. Whatever is kept goes into `PresenterEstimate.position` or `FollowEngine.gateIsOpen`, which stay pure. The rule is documented there, and in PRD §5.4.

6. **What the scenarios must keep.** Every existing scenario in `FollowScenarioTests` passes unchanged: no new presenter waits, the same phrases played, and a clean read within two words for 98% of samples. Each also runs at 4 words a second with 1 s bursts. Where a scenario's own numbers depend on the rate, the 4.0 run asserts only no waits, completion and the phrases played.

   Three new scenarios:
   - **Off script at a phrase end:** reproduces #19. The next phrase is not played until the presenter is back on script, and `.lost` is shown.
   - **A misheard phrase end:** the phrase's last two words written as other words, as "in all" heard as "an hour". The wait at that gate is no longer than it is on `main`, measured before the rule changes and pinned.
   - **A stray word at a phrase end, then back on script:** one filler word ("um") after a phrase end, and the next phrase read. There are no presenter waits, and the voice is not lost.

7. **The device check provokes give-up with a Debug flag.** `-EarwigListenGivesUp YES`, Debug builds only, makes the listener call its give-up path ten seconds after listening starts in a take. Then the Prompt screen's Finished can be seen on the phone without waiting for a real failure. The flag goes in CLAUDE.md beside the others.

## Files

| File | Purpose |
|------|---------|
| `Services/Listener.swift` | `onGaveUp` from both give-up paths in `recover`; the Debug flag's timer (decisions 1, 7) |
| `Services/TakeHost.swift` | `HeardSource.onGaveUp`; Stop with `stopReason`; the summary's reason (decision 2) |
| `Services/TakeSummary.swift` | The stop reason on the summary line |
| `ViewModels/PromptViewModel.swift` | Finished's instruction with the reason |
| `Engine/PresenterEstimate.swift`, `Engine/FollowEngine.swift` | The rule kept from decision 5 |
| `EarwigTests/Simulation/TakeSimulation.swift` | `interimInterval`; logging the estimate at a release (decisions 3, 4) |
| `EarwigTests/Simulation/FollowScenarioTests.swift` | The new scenarios and the 4.0 runs (decision 6) |
| `EarwigTests/TakeHostTests.swift`, `PromptViewModelTests.swift`, `TakeSummaryTests.swift`, `PresenterEstimateTests.swift` | As Steps |
| `CLAUDE.md`, `PRD.md` | The flag; §5.4 and §8.3 as the rule and the screen end up |

## Steps

1. **#18, listening gives up.**
   - `onGaveUp` on `HeardSource` and `Listener`, from both paths.
   - `TakeHost` stops the take with the reason.
   - `PromptViewModel` shows it.
   - Tests:
     - `TakeHostTests`: the fake gives up mid-take, and the take is recorded as stopped with the reason, torn down, and nothing more is sent to the engine;
     - `TakeHostTests`: giving up while getting ready, before `begin`, changes nothing, since `listen` already returns the failure;
     - `PromptViewModelTests`: Finished's text with a reason;
     - `TakeSummaryTests`: the line with a reason.
   - The Debug flag.
   - Committed on its own.
2. **#19, reproduction.**
   - `interimInterval` in the simulated recogniser.
   - The off-script-at-a-phrase-end scenario, failing as expected.
   - The release moment found and written into this plan (decision 4).
   - The misheard-phrase-end scenario's wait measured on the current rule and pinned.
   - Committed with the failing test marked `.disabled("reproduces #19")`, so the branch's tests pass at every commit.
3. **#19, the rule.**
   - Candidates A, B, C in turn (decision 5).
   - The one kept passes every scenario at both rates (decision 6).
   - Unit tests in `PresenterEstimateTests` pin it: an interim ending on a phrase's last word, one stray word, two, and a heard word beyond the boundary.
   - The plan records what each candidate cost or failed on.
4. **Device check** on the iPhone 14 Pro with the SK18, one check at a time (Verification). Results come from Andy's verdicts and the console.
5. **Finish.**
   - `swiftlint lint` clean, no build warnings, all tests pass.
   - Results filled in.
   - PRD as v0.8 with a Document History row: the rule in §5.4, the take ending when listening stops in §4.3 and §8.3.
   - CLAUDE.md: the status and the flag.
   - `progress.md` emptied to its stub.

## Verification

- `xcodebuild test` passes in the simulator; no warnings; SwiftLint clean.
- On the iPhone 14 Pro with the SK18, installed with `devicectl` and the console read live, one at a time, with the sample script (made up, so it can be quoted here). Lead 5, hybrid, tones only (the defaults):
  1. **Off script at a phrase end.** Read a phrase to its end, then carry straight on with a sentence of your own, without pausing, then come back to the script. The next phrase is not released while you are off script. The screen shows Lost, and the voice picks you up when you come back. Andy's verdict; from the console, the estimate at the gate and the time to Lost.
  2. **A misheard or swallowed phrase end.** A normal read, with one phrase's last word mumbled or said differently. The wait at that gate is no longer than before; the console gives its length. Andy's verdict on the feel.
  3. **A clean read** of a whole step, as plan 005 check 2. No new waits; the summary's waits and longest wait against plan 005's (six waits, longest 2.4 s). Andy's verdict.
  4. **A filler at a phrase end.** An "um" after a phrase end, then the next phrase. The voice is not held or lost.
  5. **Listening gives up.** With `-EarwigListenGivesUp YES`, start a take. After ten seconds, the take stops and Finished says that listening stopped and why. Next Take starts a new take that listens.

## Results

Built as planned, with these findings and changes. The device check is still to come.

- **#18.** As decisions 1 and 2: `onGaveUp` from both of the listener's give-up paths, and the take stops with a `stopReason`. Finished says "Stopped: listening stopped after two failures in ten seconds", or "Stopped: listening could not restart (…)". The summary line says `stopped (not listening)`. **Changed from decision 7:** the Debug flag wraps the take's `HeardSource` (`GivingUpHeardSource`, beside `SilentHeardSource` in `ScriptDetailViewModel.swift`) rather than adding a timer to `Listener`, so no Debug code sits in the listener. It works with `-EarwigNoListen YES` too.
- **The simulated voice speaks as fast as the presenter.** The scenarios' voice said a word every 0.4 s (2.5 words a second), even at 1.2x slower than a presenter reading at 4. So at that pace the presenter waited on the voice at almost every word, which is not what the phone does: there, both ran at about 4 words a second. The new scenarios render the step at the presenter's pace (`SimulationScripts.harbour(step:secondsPerWord:)`).
- **Where the release comes from (decision 4).** The reproduction is the harbour step at lead 5: phrase 2 read to "stood" (word 27), then straight on with off-script words. It released phrase 4 early at all three paces (2.5; 4; and 4 with 1 s bursts), and played it twice. In every case the release came **before any stray word was heard**:
  - the estimate was coasting on the script, with the confident word at 25 or 26 and the presenter really at 27;
  - it reached word 29, which opens the gate after phrase 3 (28–33), from phrase 2.

  So it is the phrase-end words themselves that release the phrase, not a stray word. Candidate A, which acts on a stray word, could not have helped, and was not built. With a voice slower than the presenter (the old simulation), a second route showed: a stray "to" matched "where to look" five words on, which reset the off-script count and started the coast again. The same rule stops that too.
- **The rule kept: B.** Coasting goes no further than the first word after the phrase the confident word is in, so crossing into the next phrase needs a word of it confidently heard. It is in `PresenterEstimate.position`, as `Basis.boundary`, set in `FollowEngine.presenterNow`. It applies only while coasting on interim results: the rule after a final (taken to have begun the voice's phrase) is unchanged. A variant that lifted the boundary on a tentative match of the next phrase's first two words was tried. It made no difference in any scenario, so it was dropped. C was not needed.
- **What B costs and gains** (simulated, lead 5, the harbour step, every scenario at all three paces):
  - **Off script at a phrase end:** phrase 4 is now held until the presenter is back. It is played once, and Lost is shown. The longest silence is 4.0 to 6.1 s. On return there is one presenter wait of 0.4 s at 4 words a second in bursts.
  - **Clean read, and every other existing scenario:** completed, with no presenter waits at any pace. The lead is within two words more often: a clean read went from 94, 88 and 78% to 97, 91 and 88%; the others rose by between 0 and 14 points. The longest silence rose by up to 1 s in the break-off and restart scenarios, since the voice now waits for the presenter to be heard in the next phrase. Total silence stayed about the same.
  - **A misheard phrase end** ("in all" heard as "an hour", phrase 2's last two words). At 2.5 and 4 words a second there are no presenter waits. In 1 s bursts, the gate after phrase 3 held 2.45 s against 1.15 s before, and the presenter waited 0.15 s once. So the guard "no longer than on main" (decision 6) holds for the presenter at two paces, but not quite at the phone's: the test pins presenter waits at 0.2 s or less and silences under 2.5 s. **Andy's check 2 decides whether that feels right.**
  - **A filler at a phrase end:** no waits, and not lost, at any pace.
- **Commits:** steps 2 and 3 went in as one commit, since the reproduction was written and the rule found in one pass. The plan's disabled-test commit was not needed.
