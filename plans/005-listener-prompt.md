# Plan 005: Listener and the Prompt Screen, Ear Mode

**GitHub Issue:** [#15](https://github.com/bowerhaus/Earwig/issues/15) (PR must include "Closes #15")
**Branch:** `listener-prompt` (from `main` at `48844f2`, after plan 004 merged)
**Status:** Complete (2026-11-08). Results below; PRD v0.7.
**Manual test:** yes, on Andy's iPhone 14 Pro with the SK18: the first real takes, one check at a time (Verification).
**Goal:** Make Earwig follow. The recogniser feeds the follow engine, the engine drives the player, and a take runs from the Script screen's Start to its end on the Prompt screen in Ear mode: the slate, the reply, the tones, the voice a lead ahead, waiting when the presenter stops and picking them up where they are, with the manual controls and the route check. Each take is recorded and numbered. The Listening check comes back as a diagnostic. The open judgements left for this stage are made by ear: lead 3 against 5, the start mode, hybrid against phrase-gated pacing.

**PRD references:** §3 Core Concepts (lead, take, mode), §4.3 Listening, §4.4 Following, §4.5 Starting a take, §4.7 Takes, §4.8 Settings (lead, pacing, start, diagnostics), §5.1 Inputs (heard words, the player's position, time), §5.5 Start, §8.3 Prompt, §8.5 Listening check, §9 Flows 1 and 2, §11 (outdoors, the Osmo hearing the earpiece), §12 stage 5, §14 Success Criteria, §15 question 1.

---

## Scope

**In:** the listener's results turned into the engine's heard-word events; the take host, which owns the session, the audio engine, the player, the listener and the engine, ticks the engine and passes events and commands between them; the slate's reply words; a take recorded and numbered; Start on the Script screen; the Prompt screen in Ear mode (status, the current phrase with the voice's word, the route check, Hold, Back, Forward, Restart, Stop, a tap to skip the slate reply); a call or a lost earpiece during a take; a first Settings screen holding only what this stage judges (lead, pacing, start mode) and the Listening check; a take summary in the console for the device check; tests for all of it that the simulator can run.

**Out:** Screen mode and the scrolling text (stage 6); the rest of Settings (voices, rate, cues, directions, speed bounds, font size) and TestFlight (stage 7); the input level as a speech signal (#9); a shot ID said as letters and numbers in the slate reply (#10, unless the device check shows it is needed); the base speaking rate (#14 stays open, though this stage's takes inform it); the take record (phase 2); fixed-pace modes (P1). Issues #5, #6 and #13 stay open.

## Design decisions

1. **The listener emits the engine's events; its word list stays for the Listening check.** `Listener` already turns each result into `HeardWord`s for display. Alongside, it now reports each result as a `FollowEvent` stamped with when it arrived: a volatile result as `.interim(text)`, its whole text (the block since the last final, plan 001 Results), and a final as `.final(words)`, each word with its start mapped to the host clock (`MicFeeder.hostTime(forAnalyzerTime:)`, as `HeardWord.spokenAt` already is). The conversion from a result's text runs and times to the event is a pure function (`HeardEvents`), so it is tested without the analyser. The listener's clock and the player's are both `HostClock`, so nothing is converted (plan 004, decision 11).

2. **A listener restart settles the block.** When the results stream fails mid-take, `Listener` restarts itself (plan 001) and the interim block it was building is lost without a final. The host then sends an empty `.final([])`, which clears the engine's block stamps without matching anything, so the new block is not aligned as the tail of the old one. The restart is logged; if it happens on the phone, Results records it.

3. **The take host is where the parts meet** (`Services/TakeHost.swift`, `@MainActor @Observable`). It is built for one take from the step's rendered phrases (as `StepPreview` builds them, chimed directions included), the slate, the settings and the take number. It configures the session, starts the audio engine and then the listener on it (the mic tap is on the same engine), renders the slate, sends the engine `.start`, and from then on, twenty times a second, passes the player's progress to the engine and ticks it; player events and listener events go to the engine as they arrive; the engine's commands go to the player, and `.finished` ends the take. It publishes the engine's snapshot for the screen. Its audio and listening sit behind the player's `PlayerOutput` and a small `HeardSource` protocol, so the whole loop is tested in the simulator against fakes on a clock the test controls, the same way plan 003's simulated takes test the engine.

4. **Listening starts before the slate, and runs to the end of the take.** The analyser takes a moment to prepare, and the first take may download the en-GB assets. So Start opens the Prompt screen in **Getting ready** (microphone permission, the session, listening, the slate's render; the asset download with its progress when there is one) and the slate plays only once the listener is listening. Listening goes on through the voice: the mic does not hear the SK18 (plan 001). The step's words and the slate's reply words are the analyser's contextual strings. A failure to get ready (no microphone permission, no assets, the voice not rendered) is shown on the Prompt screen with what to do, and no take is recorded.

5. **The slate's reply words come from the slate.** The engine listens for the step's number or shot ID, "take" and the take number (PRD §5.5). `Slate.replyWords(number:shotID:take:)` gives them as script words: "3 take 2", or for a shot ID its letters and digits apart ("W 3 1 take 2"), matched only as well as the matcher already can (#10).

6. **A take is recorded when its slate plays, not when it ends.** The camera hears "take 2" at the start, so take 2 must exist from then, even if the app is killed mid-take; the next slate then says take 3. `Take` is inserted with outcome `stopped` when the engine is started, and its duration and outcome are set when it finishes. With tones only, the take is still numbered and recorded, though no number is said. Restart goes back through the tones within the same take (PRD §4.4); getting ready that fails records nothing.

7. **The Prompt screen, Ear mode** (PRD §8.3), a full-screen cover over the Script screen, in the one theme:
   - Top: the step's number and title, the take number, and the route check: an earpiece icon and a mic icon, each red when wrong (decision 9).
   - Middle: a large status word (Getting ready, Slate, Tones, Speaking, Waiting, Lost, Held, Finished) and the current phrase with the word the voice is saying in the accent colour. In the slate-with-reply mode it says what to do ("Say the slate, or tap"); a tap anywhere in the middle is the engine's `.tap`.
   - Bottom: Hold (a toggle, lit while held), Back, Forward, Restart, Stop, each a large target.
   - A small diagnostics line under the phrase for the device check: lead error, speed, the measured delay and rate. Whether it stays is Andy's call after the checks.
   - The screen stays awake while a take runs (`isIdleTimerDisabled`); for a pocket the phone is locked, which background audio already survives (plan 001). Finished shows the outcome with **Next Take** (the same step again) and **Done** (back to the Script screen, where the next take's number shows on the step).

8. **Start lives on the Script screen's rendering row.** Tapping a step still makes it the start step and renders it (plan 004); the rendering row, once the step is ready, has **Start** (primary, accent) beside Listen. PRD §8.2 says "Tap a step to start a take from it"; a tap that starts a take by accident while scrolling is worse than one more tap, so it is Start, and the PRD is changed to say so.

9. **The route check, and what happens when the route goes wrong mid-take.** Red for the earpiece when the output is in the hands-free profile; red for the mic when the input is not the built-in mic (PRD §4.3). With the phone's speaker as the output, the earpiece icon is amber with "Speaker: the mic will hear the voice", since the recogniser would follow the voice itself; a take can still run, for trying the screen at a desk. If the earpiece goes mid-take (a route change with the old device unavailable), the host sends Hold, so the voice is not heard by the room or the mic; the presenter releases Hold or stops. After an audio engine restart from a configuration change mid-take (plan 004, C3: the buffer playing is cut off), the host sends Hold twice, so the voice re-anchors to where the presenter got to (PRD §5.4) rather than waiting for an end that may never come. Each is logged.

10. **A call ends the take.** An interruption beginning sends Stop: the take is recorded as stopped and the Prompt screen shows Finished; the presenter starts the next take after the call (PRD §8.3, §11).

11. **A first Settings screen, with what this stage judges.** The lead, the start mode and the pacing are to be decided by ear in this stage (PRD §3, §4.4, §15 question 1), so they need to be changeable on the phone. A gear on the Scripts screen opens Settings with three groups: **Following** (lead in words, 2 to 6, with its seconds at the default rate; pacing, hybrid or phrase-gated), **Start** (slate with a reply, slate alone, tones only) and **Diagnostics** (the Listening check). They are kept in `AppSettings` and read into `FollowSettings` when a take is built. The voice and directions settings stay in the Script screen's menu, and the rest of §4.8 waits for stage 7.

12. **The Listening check comes back** (PRD §4.3, §8.5), built on the listener as it is now: the words heard live with each one's delay, interim words dimmed until final, the input level, the route, the asset state, and **Say Test**, which plays a phrase of the sample in the presenter's voice through the earpiece while listening, so it shows whether the mic hears the earpiece. No engine.

13. **The console tells the device check what happened.** Every command and player event, each heard result (interim text and finals with their delays), each status change and each wait at a gate with its length, are logged with `Log.event`. At the end of a take, one summary line: duration, outcome, controls used, script words heard against the step's, the lead error within two words for what share of the speaking time, the longest wait and the number of waits, the speed's range, the median delay and the rate. These are the numbers Results records, alongside Andy's verdicts (CLAUDE.md: never guess a device result).

14. **Listen stays for now.** It is the straight play-through from plan 004; whether to keep it once takes run is asked at the device check.

## Files

| File | Purpose |
|------|---------|
| `Services/Listener.swift` | Reports each result as a `FollowEvent` (decision 1); `HeardSource` conformance |
| `Services/HeardEvents.swift` | A result's text and word times to `.interim` or `.final` (pure) |
| `Services/TakeHost.swift` | `HeardSource`, the take loop: getting ready, the tick, events and commands, the take record, route and interruption handling, the summary (decisions 2 to 6, 9, 10, 13) |
| `Services/TakeSummary.swift` | Collects the take's numbers from snapshots and commands for the summary line (pure) |
| `Services/Slate.swift` | `replyWords` (decision 5) |
| `Services/AudioSessionManager.swift` | The route's speaker case; a lost-device callback |
| `Models/AppSettings.swift` | Lead, pacing and start mode; `followSettings` |
| `ViewModels/PromptViewModel.swift` | The Prompt screen's text: status word, phrase with the voice's word, route state, controls enabled |
| `ViewModels/ScriptDetailViewModel.swift` | Start, with the take number and the step's audio |
| `Views/Prompt/PromptView.swift` | The Prompt screen (decision 7) |
| `Views/Settings/SettingsView.swift`, `Views/Settings/ListeningCheckView.swift` | Settings (decision 11) and the Listening check (decision 12) |
| `Views/ScriptDetail/ScriptDetailView.swift`, `Views/Scripts/ScriptsView.swift` | Start in the rendering row; the gear |
| `EarwigTests/HeardEventsTests.swift`, `TakeHostTests.swift`, `TakeSummaryTests.swift`, `PromptViewModelTests.swift`, `SlateTests.swift`, `AppSettingsTests.swift` | As Steps |

`StepPreview`'s building of the take's audio and timings moves to one place both it and `TakeHost` use.

## Steps

1. **Heard events.** `HeardEvents` and its tests: a volatile result's whole text as one interim; a final's words with their host-clock starts; a final with a number in digits and a compound kept as the recogniser wrote them (the engine folds them); an empty result. `Listener` reports through it.
2. **Slate reply and settings.** `Slate.replyWords` tests (step number, shot ID apart, take number). `AppSettings` lead, pacing and start mode with defaults 3, hybrid, slate with a reply; `followSettings` carries them.
3. **Take host.** `TakeAudio` building shared with `StepPreview`. `TakeHost` against `FakeOutput` and a fake `HeardSource` on a test clock, as simulated takes: getting ready in order (listening before the slate); a clean read with the slate reply completes and the take is recorded with its number, duration and outcome `completed`; Stop records `stopped`; a tap skips the reply; the commands reach the right channels; progress reaches the engine every tick; a listener restart sends an empty final; an interruption stops the take; a lost earpiece holds; an engine restart re-anchors; getting ready that fails records no take. `TakeSummary` tests on a made-up run.
4. **Screens.** `PromptViewModel` tests (status words, the phrase and its highlighted word, Waiting showing the phrase the voice is after, route states, the controls enabled by status). The Prompt screen, Start in the rendering row, Settings with the gear, the Listening check. Checked in the simulator with `-EarwigDemo YES` for layout and the flow (with a `-EarwigTake YES` Debug flag that starts a take once the start step is ready); following itself is for the phone.
5. **Device check** on the iPhone 14 Pro with the SK18, one check at a time (Verification), results in Results from Andy's verdicts and the console.
6. `swiftlint lint` clean, no build warnings, all tests pass; Results filled; PRD updated where the decisions and the checks pin them, as v0.7 with a Document History row: Start on the rendering row (§8.2), the Prompt screen as built (§8.3), the route check's speaker case and a lost earpiece (§4.3), a call ending the take (§7.2, §11), a take recorded at its slate (§4.7), the lead, start mode and pacing defaults Andy chooses (§3, §4.4, §4.5, §15 question 1), the first Settings screen (§4.8, §8.4), the outdoor and Osmo risks if checked (§11); CLAUDE.md status; `progress.md` emptied to its stub.

## Verification

- `xcodebuild test` passes in the simulator; no warnings; SwiftLint clean.
- On the iPhone 14 Pro with the SK18, installed with `devicectl` and the console read live, one at a time, with the sample script (made up, so it can be quoted in the repo):
  1. **Listening check.** Words appear live with their delay; the level moves; the route shows the SK18 in A2DP and the built-in mic. Say Test with the earpiece in: the voice's words are not heard by the mic.
  2. **First take.** Phone in the hand at a desk, slate with a reply, lead 3: Start, the slate, say it back, the tones, read step 1 cleanly behind the voice. It completes with no control used. Andy's verdict on the feel; from the console, the summary (lead error within two words, waits, speed range, delay, rate) and the take numbered and recorded.
  3. **Stop and pick up.** Mid-step, stop for ten seconds, then say the last phrase again: the voice waits at its gate, then is back in step within one phrase (PRD §14).
  4. **Fluff and wander.** Fluff a phrase and say it again; then say a sentence off the script and come back to it. The voice steps back with the fluff and waits through the wander.
  5. **Controls.** Hold and release, Back, Forward, Restart (the tones, not the slate, same take), Stop.
  6. **Choices.** Lead 3 against 5; hybrid against phrase-gated; the three start modes. Andy's picks become the defaults. His view of the voice's speed under pacing goes to #14.
  7. **Pocket and locked.** A take with the phone locked in a pocket, to the end of the step.
  8. **Route.** Take the earpiece out mid-take: the voice holds and the earpiece icon goes red. The route check on the speaker shows amber.
  - Outdoors and the Osmo (PRD §11, §14: a two-minute step on the beach in a pocket, the earpiece not heard by the Osmo) are done when Andy next films; if not done in this stage, they are named in Results and carried to stage 6 or 7.

## Results

Built as planned, with these changes from the device checks:

- **While the voice waits, the Prompt screen shows the whole sentence** it stopped in, not only its phrase (check 3, Andy: on a restart "I may have forgotten what I have just said"). The part the voice has not given yet is dimmed; a cue never ends a sentence. While the voice speaks, the phrase as before.
- **The route is judged only while a take runs.** The session is let go at the end, after which the phone reports no input, so Finished said "Not listening on the iPhone's mic".
- **The matcher looks 24 words behind**, not 12 (check 4): a restart of the sentence before, "The plan is simple", was 17 words back, outside the window, and went Lost.
- **After a fluff the voice waits; nothing is given again automatically.** Three ways of re-giving were tried in check 4 and dropped: the rest of the phrase from the next word ("the fluff did not work"), then the sentence from its start after 1.5 s of silence, which repeated itself on the recogniser's gaps and natural pauses ("multiple repeats of the re-entry phrase"). Andy: "after a fluff, I would want to be able to recompose myself… I shouldn't be expected to start straight away", and "I'm wondering if we're making this resetting too complex." So the voice waits at its gate as at any phrase end; the presenter goes back in their own time, is followed back, and the next phrase comes a lead ahead; Back re-gives a phrase on request. Found on the way by a simulated take: after a re-anchor the estimate still followed the phrase the voice had last started, opening the next gate at once; fixed.
- **Forward from the last phrase does nothing** (check 5: it clamped to the last phrase and played it again).
- **The end grace runs from the later of the voice finishing and the presenter's last confident word** (check 6: coming back to the last phrase 8.8 s after a fluff, the take completed at its first word and cut him off).
- **A misread word is not a jump** (check 7: "salt on the side" for "on one side" took "the side" for "the other side" in the next line, seven words on, and the voice stuttered on the step back that followed). A word that would leave the run, with the next word carrying the run on, is taken as misheard.
- **A voice speed setting** (#14): at 1.0x the voice was "still too quick", phrase-gated as well as hybrid. The player plays the engine's speeds times a base, 0.8x to 1.0x, on the voice only (cues, slate and tones at 1.0x), so hybrid's 0.85x to 1.2x runs around it. Rendering more slowly was measured first, but the simulator's only voice moves its rate in coarse steps, so a render rate could not be chosen reliably. Listen still plays at its own 0.85x, 1.0x or 1.2x.
- **Start on the start step's card starts a take**, as well as Start Take N in the rendering row (Andy: the badge "not working", it was a label). The card itself is no longer a button, so a tap while scrolling cannot start one.
- **An earpiece put away mid-take came as an interruption**, not as the device going, so the take stopped rather than holding. Andy: "stopping is fine".
- **The console stamps each line** with seconds since launch, to time pickups.
- **Kept:** the diagnostics line on the Prompt screen and Listen (decisions 7 and 14), for the next stages. The direction chime stays where it is: it is released with the phrase after it, so it reaches the presenter about a lead before the end of the sentence before the direction, which at lead 5 is the earlier chime Andy asked for at lead 3.
- **Known, not changed:** off script, one stray word at a phrase end still looks like reading on (the estimate runs on about four words past the last match, for the recogniser's delay), so the next phrase can be released; treating one unmatched word as off script would stall the gate whenever a phrase's last word is misheard. An opening phrase longer than the lead waits about 1.5 s for the presenter to be heard.

### Device check (iPhone 14 Pro, SK18), 2026-11-07 and 08

The sample script, and a second made-up one, *The Weekend Loaf*, from check 6.

| Check | Result |
|-------|--------|
| 1. Listening check | Pass (Andy: "all as expected"). SK18 in A2DP, the built-in mic, output latency 356 ms; Say Test not heard by the mic. |
| 2. First take | Pass (completed, "felt right"). Slate with a reply, lead 3, no control used; 41.2 s; lead within two words 58% of the speaking time; six waits, longest 2.4 s; speed 0.85x to 1.14x; delay 0.93 s; rate 4.0 words/s. Finals came only at sentence ends, 1.3 to 5.7 s after the words. |
| 3. Stop and pick up | Pass on the rerun ("it picked up fine"). After 9.5 s stopped and the sentence said again, the next phrase was released with him about three words from its end: on the lead. The first run "picked up a little late"; it led to the sentence view. |
| 4. Fluff and wander | Pass on the fourth run ("worked"), with the changes above: completed, no control used, heard to word 66 of 70, Lost three times briefly and found each time; delay 0.95 s, rate 3.6 words/s. |
| 5. Controls | Pass after the Forward fix ("all worked"): Hold and release, Back, Forward, Restart (the tones, same take), Stop. |
| 6. Choices | **Lead 5** ("I prefer 5"; at lead 3 a short opening phrase waited 1.5 s), **hybrid**, **voice speed 0.95x** (after 0.85x and 0.9x), **tones only**. These are the defaults. Under hybrid at 1.0x the pacer mostly sped the voice up (to 1.19x), which led to the voice speed. |
| 7. Pocket and locked | Pass ("it worked"): *The Weekend Loaf* step 2 to the end with the phone locked in a pocket, completed, heard 60 of 60; the misread jump above was found here. |
| 8. Route | Pass ("worked"): the earpiece put away mid-take stopped the take (an interruption); on the speaker the route check showed amber. |

Outdoors and the Osmo (PRD §11, §14) were not done in this stage; they wait for Andy's next shoot and are carried to stage 6 or 7.

**Outcome: PASS** (2026-11-08). Earwig follows on the iPhone 14 Pro with the SK18: takes run from Start to the end of the step in the hand and locked in a pocket, the voice waits when the presenter stops and picks them up where they are, fluffs and wanders are followed, and the controls and the route check work. Follow-ups: #16 (record a take and play it back), and #14 for a base rate per voice in stage 7's Settings.

## Review pass — 2026-11-08

Findings from `/review-branch` on branch `listener-prompt`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact, and each verdict under *Assessment* is a
recommendation, not a decision. Work through them and annotate each with what was done — fixed,
or rejected and why. A finding that turns out to be wrong should say so here rather than be
deleted.

### Code

Review of branch `listener-prompt` against `main`. I read the plan (Goal, Scope, Decisions, Verification, Results), CLAUDE.md, the committed diff, the unstaged diff and all 15 untracked files. Nothing is staged.

**Requirements:** The branch delivers the plan and the changes recorded in Results:
- `HeardEvents` and the listener feeding the engine.
- A listener restart sends an empty `.final([])`.
- `TakeHost` gets ready in order: microphone, session, engine, listening, slate.
- The take is recorded at the slate; a failed get-ready records nothing.
- Route check: amber on the speaker, judged only while a take runs.
- A call or interruption ends the take; a lost device holds; an engine restart re-anchors.
- Prompt screen: the whole sentence shown while the voice waits; Next Take and Done.
- Start on the card and on the rendering row; Settings with the gear and voice speed; the Listening check.
- Defaults: lead 5, hybrid, 0.95x, tones only.
- Matcher: 24-word window; a misread word is not taken as a jump.
- Forward from the last phrase does nothing; the end grace runs from the last heard word.
- PRD is at v0.7 with a History row, and the CLAUDE.md status is updated.

Colours all come from `EarwigTheme`, `Engine/` gains no forbidden imports, and the test fakes conform to the new protocols. I found no build-breaking issues.

**C1 — WARNING — The old take's teardown can turn off the shared audio session under the next take.**
- `TakeHost.finish` starts `Task { await tearDown() }`. That teardown waits on `heard.stopListening()`, which runs `finalizeAndFinishThroughEndOfInput` and can take a while, then calls `session.deactivate()`.
- `deactivate()` is `AVAudioSession.sharedInstance().setActive(false)`, and that session is shared by every `AudioSessionManager`.
- Next Take (`nextTake`), or Done followed quickly by Start, builds a new `TakeHost` whose `start()` calls `session.configure()` at once. If the old teardown finishes after that, it deactivates the session under the new take's running engine, which stops its I/O.
- Fix: await the old host's teardown before starting the next take, for example an `async` close on `TakeHost`.
- Files: `Earwig/Services/TakeHost.swift` 316, 328–341; `Earwig/ViewModels/ScriptDetailViewModel.swift` 711–721 (`endTake`, `nextTake`).

**C2 — WARNING — `startTake` replaces a take that is still running without ending it.**
- There are now two Start buttons (the card and the rendering row), plus the `-EarwigTake` debug path. A second call before the cover is up replaces `model.take` without calling `end()`.
- `.task(id:)` cancels the old `start()` task, but `TakeHost.start()` never checks for cancellation, only `ended`, which stays false. So the orphaned host carries on: it records a take with the same number, plays slate, tones and voice, and keeps ticking, with no screen to stop it.
- Fix: guard `take == nil` in `startTake` (or end the old take first), and/or check `Task.isCancelled` in `start()`.
- Files: `Earwig/ViewModels/ScriptDetailViewModel.swift` ~652–706; `Earwig/Services/TakeHost.swift` 157–182.

**C3 — SUGGESTION — The slate is rendered even in tones-only mode, which is now the default.**
- Every take waits for a slate render it never plays.
- If that render fails, the take fails with "The slate could not be rendered" even though no slate was wanted.
- File: `Earwig/Services/TakeHost.swift` 174–179.

**C4 — SUGGESTION — The Listening check can start listening after its screen has gone.**
- `.onDisappear { Task { await check.stop() } }` can run while `.task { await check.start() }` is still waiting on the microphone prompt, the asset check or analyser start-up.
- `stop()` then runs first, `start()` goes on to configure the session and start listening, and nothing stops it. (`TakeHost` avoids this with its `ended` flag.)
- Files: `Earwig/ViewModels/ListeningCheck.swift` 30–55; `Earwig/Views/Settings/ListeningCheckView.swift` 56–57.

**C5 — SUGGESTION — A listener that gives up mid-take is not reported to the take.**
- When `Listener.recover()` stops because it "restarted too recently", it sets `.failed` and stops listening.
- `HeardSource` only reports restarts, so `TakeHost` never learns this. The take carries on unable to hear, showing Waiting or Lost with no explanation.
- Files: `Earwig/Services/Listener.swift` (`recover`); `Earwig/Services/TakeHost.swift` 4–17, 191–195.

**C6 — SUGGESTION — An engine restart while waiting for the slate reply skips the reply.**
- `engineRestarted` sends `.tap` for any `.slate` status. That covers both the slate playing (where it is cut off) and the wait for the presenter's reply (where nothing was cut).
- In the second case the reply wait is skipped and the tones start over the presenter.
- File: `Earwig/Services/TakeHost.swift` 295–296.

**C7 — SUGGESTION — Two small repeats (DRY).**
- `HeardEvents.event(for:…)` works out `words(in:)` again for the same result that `Listener.handle` has just worked out. The final event could be built from the `timed` words already in hand.
- `ListeningCheckView.routeRow` repeats the earpiece and mic good/amber/red judgement inline instead of reusing `PromptViewModel`'s route-state logic or `AudioRoute.isGoodForTake`.
- Files: `Earwig/Services/Listener.swift` 383–393; `Earwig/Services/HeardEvents.swift` 61–70; `Earwig/Views/Settings/ListeningCheckView.swift` 12–14.

### Tests

Review of the test changes on `listener-prompt`, all uncommitted. I read the 7 modified test files and the 5 untracked suites in full (AppSettings, HeardEvents, PromptViewModel, TakeHost, TakeSummary), plus the source each one covers. Overall the tests are proportionate (about 860 test lines for about 1,700 source lines) and well aimed. The pure parts (HeardEvents, TakeSummary, PromptViewModel, PhraseList.sentence, Slate.replyWords) and the take loop against fakes are covered well. The findings below are mostly gaps and weak assertions, not over-testing.

T1. WARNING: `TakeHost.end()` while a take is running is never tested.
- `end()` is what `ScriptDetailViewModel.endTake()` and `nextTake()` call, and closing the Prompt screen mid-take must stop the take and record it as stopped.
- Only the getting-ready branch is tested (`closingWhileGettingReadyStartsNothing`).
- No test checks that a finished, stopped or interrupted take tears down: `session.deactivated`, `heard.stopped` and `output.stop` after `finish`'s `Task { await tearDown() }`. Only the listen-failure path checks teardown.
- Files: /Users/andybower/Projects/Earwig/EarwigTests/TakeHostTests.swift:191-199, 252-258, 324-330; source /Users/andybower/Projects/Earwig/Earwig/Services/TakeHost.swift:307-341

T2. WARNING: Weak or either-way assertions in TakeHostTests hide what the behaviour should be.
- `aLostEarpieceHolds` passes if either of two things is true: `output.stopped.last == .cue || output.stopped.contains(.voice)`. At that point the voice is speaking, so the hold should stop `.voice` and nothing else. Assert that one outcome.
- `anEngineRestartReanchorsTheVoice` only checks that the stop count went up and that the status is `!= .held`. It never checks the re-anchor itself: the voice playing again, or waiting at the right phrase, after the double Hold.
- `aListenerRestartSettlesTheBlock` uses `presenterWord >= 1`. A fixed value would be clearer.
- Files: /Users/andybower/Projects/Earwig/EarwigTests/TakeHostTests.swift:246, 266, 276-280

T3. WARNING: `TakeSetup.contextWords(phraseList:slateText:)` has no test. It is new pure logic that feeds the analyser's context: it strips punctuation and symbols, de-duplicates case-insensitively and drops empty tokens. Neither the TakeHost tests (which pass a hand-made `contextWords`) nor the ScriptDetailViewModel tests assert on it. One small table test would cover it.
- Source: /Users/andybower/Projects/Earwig/Earwig/Services/TakeHost.swift:86-92

T4. SUGGESTION: `TakeAudio.build` has no direct test. It was moved out of StepPreview and is now shared by Listen and takes. `withCuesOffATakeHasNoCuePhrases` only compares counts. One test would cover the chime branch: a chimed cue gets `ring` set and a script timing of `Tones.Chime.hold`, while a spoken cue keeps its rendered buffer.
- Source: /Users/andybower/Projects/Earwig/Earwig/Services/TakeAudio.swift:19-42; test /Users/andybower/Projects/Earwig/EarwigTests/ScriptDetailViewModelTests.swift:66-80

T5. SUGGESTION: `#expect(setup.settings == AppSettings.take.followSettings)` proves nothing. It repeats the source's own expression and reads the test host's `UserDefaults.standard`. Drop it, or assert one known field.
- File: /Users/andybower/Projects/Earwig/EarwigTests/ScriptDetailViewModelTests.swift:59

T6. SUGGESTION: Two overlapping tests in HeardEventsTests could be merged.
- `numbersAndCompoundsAreKeptAsWritten` goes down the same path as `aFinalsWordsCarryTheirHostClockStarts`: a final, one timed run per word, mapped to host time. Nothing in `HeardEvents` treats numbers or compounds differently.
- Merging them (add "20" and "twenty-one" to the first) keeps the coverage.
- File: /Users/andybower/Projects/Earwig/EarwigTests/HeardEventsTests.swift:15-36

T7. SUGGESTION: Two Slate tests could be folded in.
- `theReplyForAStoredStep` tests a pass-through wrapper.
- The `"--"` fallback case in `aShotIDsReplyHasItsLettersAndDigitsApart` repeats `theReplyIsTheNumberTakeAndTakeNumber`'s expectation.
- These could become two tests: number, and shot ID with its fallback.
- File: /Users/andybower/Projects/Earwig/EarwigTests/SlateTests.swift:34-47

T8. SUGGESTION: The three failure tests use two different assertion styles.
- `noMicrophoneRecordsNoTake` and `aSlateThatFailsRecordsNoTake` use a `guard case .failed` with `Issue.record` block.
- `listeningThatFailsRecordsNoTakeAndTearsDown` uses a direct `#expect(host.phase == .failed(...))`. The messages are fixed strings, so the direct form works everywhere and is shorter.
- The slate-failure test could also check teardown, as the listen-failure one does.
- Separately, the doc comment on `finals(_:spokenFrom:)` mentions a `delay` parameter that does not exist.
- File: /Users/andybower/Projects/Earwig/EarwigTests/TakeHostTests.swift:126-129, 291-322

T9. SUGGESTION: `PromptViewModel.routeNote` sets an order of priority (hands-free, then mic, then speaker), but `theRouteStates` only asserts the speaker note. Adding `routeNote` checks to the hands-free and headset-mic cases would cover the two other messages and their order, at no extra test cost.
- File: /Users/andybower/Projects/Earwig/EarwigTests/PromptViewModelTests.swift:84-101

T10. SUGGESTION: Some small AppSettingsTests tidying.
- Each test makes a new `UserDefaults` suite and never removes it, so every run leaves one plist per test in the simulator. Remove the domain afterwards, or reuse one fixed suite name and clear it.
- `theLeadsSecondsAtTheDefaultRate` checks a one-line division and could go.
- File: /Users/andybower/Projects/Earwig/EarwigTests/AppSettingsTests.swift:8-13, 42-44

### Assessment

- **C1 — FIX.** Real: `deactivate()` acts on the one shared `AVAudioSession`, and a finished take's teardown runs in a detached task (`TakeHost.swift:314`), so a quick Next Take or Start could be deactivated under it. On the phone the teardown took about 0.25 s, so it is rare, but it would kill a take. Fix in `AudioSessionManager`: a deactivate only acts if no session has been configured since this one was, so a late teardown leaves a newer take's session alone.
- **C2 — FIX.** Real: two Start buttons now, and `startTake` overwrites `take` with no `end()`. Guard `take == nil` in `startTake`; `nextTake` clears `take` after ending it.
- **C3 — FIX.** Real, and tones only is now the default: skip the slate's render when the start mode is tones only (the player already handles a missing slate).
- **C4 — FIX.** Real (`ListeningCheck.swift:30-55`): give `ListeningCheck` a stopped flag that `start()` checks after each wait, as `TakeHost` does with `ended`.
- **C5 — FOLLOW-UP.** Real, but it needs a choice of what the presenter sees and whether the take ends: "Tell the take when listening gives up mid-take".
- **C6 — SKIP.** Real but rare (an engine configuration change during the reply wait), and the default start is now tones only, which has no reply wait.
- **C7 — SKIP.** Both repeats are small; the Listening check's route row has no take phase to share `PromptViewModel`'s logic with, and recomputing a final's words is cheap.
- **T1 — FIX.** Add one test: `end()` on a running take records it stopped and tears down (listening stopped, the session let go).
- **T2 — FIX (part).** Tighten `aLostEarpieceHolds` to `output.stopped.contains(.voice)` (a stop of the voice stops both channels). Leave the other two: the re-anchor's exact phrase is the engine's, tested there.
- **T3 — FIX.** One table test for `TakeSetup.contextWords`.
- **T4 — SKIP.** Moved code, played in every take and Listen on the phone; the chime branch is unchanged from plan 004.
- **T5 — FIX.** Drop the tautological assertion.
- **T6 — SKIP.** Cosmetic merge.
- **T7 — SKIP.** Cosmetic merge.
- **T8 — FIX (part).** Correct the `finals(_:spokenFrom:)` doc comment only; the two assertion styles both work.
- **T9 — FIX.** Add the hands-free and headset-mic `routeNote` expectations.
- **T10 — SKIP.** Simulator-only leftovers; the lead's seconds are shown on the Settings screen, so the test is cheap insurance.

### Outcome — 2026-11-08

- C1 — fixed: each `AudioSessionManager.configure` takes the next number of the shared session, and `deactivate` leaves the session alone if it has been configured since, logging "session left active"; test `AudioSessionManagerTests`.
- C2 — fixed: `startTake` starts nothing while a take is up; `nextTake` clears the take after ending it.
- C3 — fixed: with tones only no slate is rendered; `tonesOnlyPlaysNoSlate` now uses a slate that would fail to render.
- C4 — fixed: `ListeningCheck` has a stopped flag, checked after each wait in `start()`, which then tears down.
- C5 — follow-up, not opened (autopilot): "Tell the take when listening gives up mid-take", listed in the PR.
- C6 — not done: rare, and tones only, the default, has no reply wait.
- C7 — not done: small repeats with nothing clean to share.
- T1 — fixed: `closingARunningTakeStopsItAndLetsEverythingGo`.
- T2 — fixed (part): `aLostEarpieceHolds` expects the voice stopped; the other two left, as assessed.
- T3 — fixed: `theContextWordsAreTheStepsAndTheSlatesOnceEach`.
- T4 — not done: moved code, played in every take and Listen.
- T5 — fixed: the tautological assertion dropped.
- T6, T7 — not done: cosmetic merges.
- T8 — fixed (part): the `finals(_:spokenFrom:)` doc comment corrected.
- T9 — fixed: the hands-free and headset-mic route notes asserted.
- T10 — not done: simulator-only leftovers.

253 tests pass, SwiftLint clean, no warnings. C1 and C3 touch the audio path, so a short device recheck follows.
- Device recheck of the review fixes, 2026-11-08: Andy: "All passed". *The Weekend Loaf* step 1, tones only: take 8 started with no slate and completed (heard 51 of 51); Next Take straight after Finished started take 9 2.9 s later, which completed; Done then Start opened take 10 normally (stopped by Andy). Each take configured the session and each teardown deactivated it.
