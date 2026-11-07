# Plan 005: Listener and the Prompt Screen, Ear Mode

**GitHub Issue:** to be created (PR must include "Closes #N")
**Branch:** `listener-prompt` (from `main` at `48844f2`, after plan 004 merged)
**Status:** Draft, for Andy's review.
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

*(Filled at the end of the stage.)*
