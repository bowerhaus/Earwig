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
- **The rule kept: B, at the gate only.** For a gate, coasting goes no further than the first word after the phrase the confident word is in, so crossing into the next phrase needs a word of it confidently heard. It is in `PresenterEstimate.position`, as `Basis.boundary`, which `FollowEngine.presenterNow(atGate:)` sets only for `gateIsOpen`. Pacing and the snapshot keep the free coast. It applies only while coasting on interim results: the rule after a final (taken to have begun the voice's phrase) is unchanged.
  - **Gate only, after the review (C2).** First built into the estimate everywhere, the boundary also pinned the pacer's view at every phrase crossing, and the voice dipped to about 0.86x there. At the gate only, the lowest speed is 0.92 to 0.95x. Every scenario has the same waits and outcome, and the lead is within two words at most four points less often (the clean-read figures below are unchanged).
  - A variant that lifted the boundary on a tentative match of the next phrase's first two words was tried. It made no difference in any scenario, so it was dropped.
  - C was not needed.
- **What B costs and gains** (simulated, lead 5, the harbour step, every scenario at all three paces):
  - **Off script at a phrase end:** phrase 4 is now held until the presenter is back. It is played once, and Lost is shown. The longest silence is 4.0 to 6.1 s. On return there is one presenter wait of 0.4 s at 4 words a second in bursts.
  - **Clean read, and every other existing scenario:** completed, with no presenter waits at any pace. The lead is within two words more often: a clean read went from 94, 88 and 78% to 97, 91 and 88%; the others rose by between 0 and 14 points. The longest silence rose by up to 1 s in the break-off and restart scenarios, since the voice now waits for the presenter to be heard in the next phrase. Total silence stayed about the same.
  - **A misheard phrase end** ("in all" heard as "an hour", phrase 2's last two words). At 2.5 and 4 words a second there are no presenter waits. In 1 s bursts, the gate after phrase 3 held 2.45 s against 1.15 s before, and the presenter waited 0.15 s once. So the guard "no longer than on main" (decision 6) holds for the presenter at two paces, but not quite at the phone's: the test pins presenter waits at 0.2 s or less and silences under 2.5 s. **Andy's check 2 decides whether that feels right.**
  - **A filler at a phrase end:** no waits, and not lost, at any pace.
### Device check (iPhone 14 Pro, SK18), 2026-11-08

| Check | Result |
|-------|--------|
| 1. Off script at a phrase end | **Pass** (Andy). Take 16, step 1, as plan 005's take 12: he read "…if we don't stop too often," then went straight on with "we may be able to find a different way to do this" and more. The voice waited after "it should take a couple of hours" and released nothing while he was off script. Lost was shown 1.0 s after the gate closed, about 3.5 s after his first own word. The direction chime and "Most of these boats…" were held for 10.6 s and released on "It should take" when he came back. Completed, heard 70 of 70. The console confirmed the bursts: interim results in groups a few milliseconds apart, about a second between groups. |
| 2. A misheard phrase end | **Pass** (Andy). Take 6, step 2, saying "where the old ones *were*" in place of "stood". Heard as "were". The voice held 1.62 s before "if you know where to look", against 1.47 s at the clean gate before it. The gate after that held 0.32 s. Completed, heard 76 of 76, no control used. Speed 0.95x to 1.16x, with no dip below the base speed (C2). Seven waits, longest 2.3 s. |
| 3. A clean read | **Pass** (Andy). Take 10, step 3, read cleanly: 29.0 s, completed, heard 74 of 74, no control used. Six waits, longest 2.1 s, against plan 005's clean take (six waits, longest 2.4 s). Speed 0.95x to 1.17x; delay 0.81 s; rate 3.78 words a second. Never Lost. |

- **Commits:** steps 2 and 3 went in as one commit, since the reproduction was written and the rule found in one pass. The plan's disabled-test commit was not needed.
- **Not written: "giving up while getting ready changes nothing"** (step 1). It cannot happen. `onGaveUp` is set only in `begin`, which moves to running at once, and `tearDown` clears it. Listening that fails to start is already `listen`'s failure, covered by `listeningThatFailsRecordsNoTakeAndTearsDown`.

## Review pass — 2026-11-08

Findings from `/review-branch` on branch `take-hearing`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact, and each verdict under *Assessment* is a
recommendation, not a decision. Work through them and annotate each with what was done — fixed,
or rejected and why. A finding that turns out to be wrong should say so here rather than be
deleted.

### Code

**C1 — WARNING (requirements): the rule adds a wait on a misheard phrase end at the phone's pace, which #19 and decision 6 say it must not.** Issue #19 asks for a rule "without adding waits on misheard phrase ends", and decision 6 says the wait at that gate is "no longer than it is on `main`, measured before the rule changes and pinned". At 4 w/s with 1 s bursts the gate after phrase 3 now holds 2.45 s against 1.15 s on `main`, and the presenter waits 0.15 s once. The test does not pin the `main` value; it loosens the guard to `waits ≤ 0.2 s` and `silences < 2.5 s` (a 0.05 s margin). The Results record this honestly and hand it to Andy's device check 2, but until his verdict this acceptance criterion is not met. `EarwigTests/Simulation/FollowScenarioTests.swift` lines 197–205 (`aMisheardPhraseEndHoldsThePresenterNoMoreThanAMoment`).

**C2 — SUGGESTION (bug risk): the boundary also feeds the Pacer and the snapshot, not only the gate.** The rule went into `PresenterEstimate.position`, which serves `gateIsOpen` (`FollowEngine.swift:385`), the Pacer's error (`FollowEngine.swift:145`) and `snapshot.presenterEstimate`. At every phrase crossing in a clean read (voice usually playing the next phrase), the estimate is now pinned at the next phrase's first word for about one recogniser delay (~4 words at 4 w/s), inflating the lead error and, with hybrid pacing (no deadband), slowing the voice briefly at each boundary. The simulated lead errors use the presenter's true position and improved, so this may be harmless, but the new 4 w/s runs assert only completion and no waits, not speeds. Worth watching the summary's speed range in device check 3, or applying the clamp only in the gate check (decision 5 allowed `gateIsOpen`). `Earwig/Engine/FollowEngine.swift` lines 269–280, `Earwig/Engine/PresenterEstimate.swift` line 96.

**C3 — SUGGESTION (Debug wrapper): `GivingUpHeardSource` swallows the real listener's give-up.** The wrapper keeps its own stored `onGaveUp` and never forwards it to `inner.onGaveUp`, so with `-EarwigListenGivesUp YES` on the phone a genuine `Listener` give-up within the first ten seconds would not be reported and the take would carry on deaf (the #18 bug, inside the tool meant to check #18). Forwarding `onGaveUp` to the inner source as well, like `onHeard` and `onRestart`, fixes it. `Earwig/ViewModels/ScriptDetailViewModel.swift` lines 211–248.

**C4 — SUGGESTION (requirements/tests): a plan-listed test is missing.** Step 1 asks for a `TakeHostTests` case "giving up while getting ready, before `begin`, changes nothing"; only `aTakeStoppedByThePresenterHasNoStopReason` was added alongside the mid-take case. `EarwigTests/TakeHostTests.swift` lines 255–279.

**C5 — SUGGESTION (DRY/requirements): the all-paces matrix duplicates scenario acts and asserts less than decision 6.** `FollowScenarioTests.scenarios` restates each scenario's `PresenterAct` list by hand rather than sharing with the original tests, so the two can drift. Decision 6 says the 4 w/s runs assert no waits, completion "and the phrases played"; `everyScenarioAtTheAppsLeadAndEveryPace` does not check `played`. It also omits three existing scenarios (fluff-then-restart, late first result, delay/rate measurement). `EarwigTests/Simulation/FollowScenarioTests.swift` lines 248–267.

**C6 — SUGGESTION (CLAUDE.md, completeness before the PR).** PRD is not yet at v0.8 with a Document History row (the rule in §5.4, which decision 5 says is documented there; the take ending when listening stops in §4.3 and §8.3), and the CLAUDE.md Status paragraph is not updated for plan 006 (only the flag line). Expected, since the plan says the device check is next, but required before the PR per the "One plan per branch" rule. `PRD.md`, `CLAUDE.md` Status section.

### Tests

**T1 — WARNING — Engine boundary wiring has no direct test.** `FollowEngine.presenterNow` now computes `boundary` as `script.phrase(containing: current.confident).map { script.range(of: $0).upperBound }` (Earwig/Engine/FollowEngine.swift:269-270), the first word after the confident word's phrase. Every `PresenterEstimateTests` case passes `boundary` by hand, so nothing pins what the engine actually computes (upperBound vs. the phrase's last word, confident == -1 giving no boundary). It is covered only indirectly by the simulation scenarios via outcomes (release position, waits), where an off-by-one could slip through. A single `FollowEngineTests` case — feed an interim ending on a phrase's last word, tick past the coast, and assert `snapshot.presenterEstimate` stops at the next phrase's first word — would close this and replace a scenario-level inference with a direct check.

**T2 — WARNING — Plan-listed test missing.** Plan 006 Step 1 lists a `TakeHostTests` case: "giving up while getting ready, before `begin`, changes nothing". It isn't there. In practice the path is unreachable (`onGaveUp` is only set in `begin`, which immediately sets `.running`; TakeHost.swift:203,214; `tearDown` clears it), so the honest options are to drop the item from the plan or record why it was skipped — but as it stands Step 1 claims coverage that doesn't exist. (plans/006-take-hearing.md Steps §1; EarwigTests/TakeHostTests.swift:571-596)

**T3 — SUGGESTION — Redundant off-script test.** `offScriptTheEstimateStaysAtTheConfidentWord` duplicates the existing `offScriptItStaysAtTheLastConfidentWord` (line 89): the off-script branch never reads `boundary`, so adding `boundary: 11` exercises nothing new. Delete it. (EarwigTests/PresenterEstimateTests.swift:115-118)

**T4 — SUGGESTION — Two tests cover the same case.** `aWordHeardInTheNextPhraseMovesTheBoundaryOn` (confident 11, boundary 17) and `insideAPhraseTheCoastRunsOnAsBefore` (boundary 20 / 13) both assert "boundary above the coast ⇒ no effect". "Moving the boundary on" is just a different input at this level; the real moving-on happens in `FollowEngine` (see T1). Fold the 11/17 case into the inside-a-phrase test, or move its intent into the T1 engine test. (EarwigTests/PresenterEstimateTests.swift:119-123, 130-134)

**T5 — SUGGESTION — Unused diagnostic fields in the simulation.** `TakeSimulation.Release` records `time`, `estimate`, `confident` and `heard`, but the only test reader (`offScriptAtAPhraseEndHoldsTheVoice`) uses just `phrase` and `presenterAt`; `SimulatedRecogniser.lastInterim` was widened to `private(set)` solely to feed `heard`. These were decision-4 investigation aids now written up in the plan. Trim `Release` to `phrase` + `presenterAt` (and keep `lastInterim` private), or use the extra fields in the failure message so they earn their place. (EarwigTests/Simulation/TakeSimulation.swift:286-297, 326-330, 494)

**T6 — SUGGESTION — Proportionality of the scenario matrix.** `everyScenarioAtTheAppsLeadAndEveryPace` runs 8 scenarios × 3 paces = 24 full simulated takes on top of the 3×3 new targeted runs and the existing scenarios. Decision 6 asks for this, so it isn't wrong, but the (2.5, 0) pace largely re-runs the existing lead-3 scenarios at a different lead. Consider keeping only the two phone paces (4/0, 4/1) in the matrix unless lead-5-at-2.5 has caught something. (EarwigTests/Simulation/FollowScenarioTests.swift:437-454)

**T7 — SUGGESTION — The reported lead-accuracy gain isn't pinned.** The plan's Results claim B lifted a clean read's within-two-words share to 97/91/88% at lead 5, but none of the new tests assert lead accuracy at the app's lead or the phone's pace, so a regression there would pass silently. One threshold on the "a clean read" matrix row (e.g. `share(underWay(take), within: 2) >= 0.85`) would pin it. (EarwigTests/Simulation/FollowScenarioTests.swift:448-454)

**T8 — SUGGESTION — Low-value test.** `aTakeStoppedByThePresenterHasNoStopReason` adds one `nil` assertion via a full slate run. Fold `#expect(host.stopReason == nil)` into an existing presenter-stop/completed-take test instead of a separate test. (EarwigTests/TakeHostTests.swift:590-595)

**T9 — SUGGESTION — Untested new code with no harness.** `Listener.recover`'s two `onGaveUp` calls (Earwig/Services/Listener.swift:86, 94) and `GivingUpHeardSource` (Earwig/ViewModels/ScriptDetailViewModel.swift:249-286) have no tests; none existed before for this code. The first is acceptable to leave to device check (Verification 5) given the real recogniser; the wrapper is Debug-only and likewise left to device check — its one piece of logic worth a quick test, if any, is that `stopListening` cancels the timer.

Covered adequately, no action needed: the give-up stop (phase, reason, recorder, voice stopped, no further engine traffic, teardown, callback cleared), the Prompt "Stopped: …" text, the summary note, the boundary clamp and its pause-rule counter-case, and the three new off-script/misheard/filler scenarios at each pace.

### Assessment

- C1 — SKIP (decided at the device check): real, and already the plan's recorded trade-off. The 0.15 s presenter wait and the longer silence come from B waiting for a word of the next phrase to be heard, which bursts make up to a second late; the misheard end itself is unaffected at 2.5 and 4 w/s. Whether it is acceptable is Andy's call by ear in check 2, which the autopilot's manual-test stop puts in front of him.
- C2 — FIX: measured: with the boundary in the pacer the voice dipped to 0.86–0.88x at phrase crossings; at the gate only, 0.92–0.95x, with the same waits, outcomes and #19 fix in every scenario. Apply the boundary in `gateIsOpen` only (`presenterNow(atGate:)`).
- C3 — FIX: forward `onGaveUp` to the wrapped source (`didSet`), so a real give-up is still reported with the flag on.
- C4 — FIX (part): same as T2. Do not write the test (the path is unreachable: `onGaveUp` is set only in `begin`); record in Results why it was not written.
- C5 — SKIP: sharing the acts would tie the readable one-scenario tests to a table. `played` differs per scenario at lead 5 (the wander replays phrase 3 there, as on `main`), so completion and no waits are the common guard. The three left out do not cross the changed code (fluff-then-restart is another step and covered at lead 3; the late first result is the after-final rule, which is unchanged; delay and rate are measurement).
- C6 — SKIP now: done at completion (`plan_completed`), after the device check settles the PRD wording.
- T1 — FIX: one `FollowEngineTests` case. The gate holds on a coast from a phrase's last word while the free estimate is past the threshold, and opens once a word of the next phrase is heard.
- T2 — FIX (part): as C4.
- T3 — FIX: delete the redundant off-script test.
- T4 — FIX: fold both "boundary beyond the coast" cases into one test.
- T5 — FIX (part): use `estimate`, `confident` and `heard` in the reproduction's failure message, and drop the unused `time`.
- T6 — SKIP: decision 6 asks for it; the 24 runs take well under a second, and lead 5 at 2.5 is the app's lead, which the lead-3 scenarios do not run.
- T7 — FIX: pin the clean read at lead 5 to within two words for at least 85% of samples at every pace.
- T8 — FIX: fold the `stopReason == nil` check into `stopRecordsAStoppedTake`.
- T9 — SKIP: no harness for the real recogniser; both are exercised by device check 5.

### Outcome — 2026-11-08

- C1 — not done here: for Andy's device check 2 (the misheard phrase end by ear).
- C2 — fixed: the boundary applies to the gate only (`presenterNow(atGate:)`); pacing and the snapshot keep the free coast. Results updated.
- C3 — fixed: `GivingUpHeardSource.onGaveUp` forwards to the wrapped source.
- C4 — fixed (part): the test is not written; Results say why.
- C5 — not done: see Assessment.
- C6 — not done here: at completion.
- T1 — fixed: `FollowEngineTests.aGateDoesNotOpenOnACoastAcrossAPhraseEnd`.
- T2 — fixed (part): as C4.
- T3 — fixed: deleted.
- T4 — fixed: one test, `aBoundaryBeyondTheCoastChangesNothing`.
- T5 — fixed (part): the extra fields are in the failure message; `time` is dropped.
- T6 — not done: see Assessment.
- T7 — fixed: the clean read at lead 5 is pinned at 85% or more within two words, at every pace.
- T8 — fixed: folded into `stopRecordsAStoppedTake`.
- T9 — not done: left to device check 5.
