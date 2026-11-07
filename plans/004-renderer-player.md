# Plan 004: Renderer and Player

**GitHub Issue:** [#11](https://github.com/bowerhaus/Earwig/issues/11) (PR must include "Closes #11")
**Branch:** `renderer-player` (from `main` at `a382ac8`, after plan 003 merged)
**Status:** Complete (2026-11-07), carried by the PR for issue #11.
**Manual test:** yes, on Andy's iPhone 14 Pro with the SK18: a step rendered, then listened to through the earpiece with each word highlighted as it is spoken (Verification).
**Goal:** Turn a script into audio the follow engine can drive. The phrases of the step a take will start from are rendered in memory with their word timings, in the presenter's voice or the cue voice, as soon as the step is chosen. A player on one audio engine plays what the engine commands (phrases at a speed, the slate, the tones) on the audio clock, and reports where the voice is as the presenter hears it. Nothing listens yet: that is stage 5. To hear the result before then, the Script screen gets Listen, which plays a step straight through.

**PRD references:** §2 (persistence), §3 Core Concepts (phrase, rendering, cue voice), §4.2 Voice Rendering, §4.5 Starting a take (slate, tones), §5.1 and §5.2 (the player's events and commands), §6.1 Rendering, §7.2 Key Services (VoiceRenderer, RenderingStore, Player), §8.2 Script (the rendering row), §9 Flow 4 (the script changed), §12 stage 4.

---

## Scope

**In:** rendering a step's phrases (spoken phrases in the presenter's voice, inline directions in the cue voice) with word timings, in memory, kept while the app runs; timings mapped to the engine's script words; the default presenter and cue voices; the slate's text and its rendering at take time; the tones; the player (voice, cue and tone nodes on one `AVAudioEngine`, the time-pitch node for speed, commands in, events and progress out, allowing for the output latency); the rendering row on the Script screen; Listen, a straight play-through of a step for checking by ear; tests for all of it that the simulator can run.

**Out:** saving rendered audio to files, the `RenderingStore` and the `Rendering` record's use (decision 1); the `Listener` feeding the engine, the take host that ticks the engine and passes events between it and the player, the Prompt screen, the manual controls, route check and the Listening check (stage 5); Screen mode (stage 6); choosing voices, rate and tone level in Settings, and Personal Voice (stage 7, open question 6); imported renderings (P2). Issues #5, #6, #9 and #10 stay open.

## Design decisions

1. **Rendered audio is not saved (Andy at review).** The PRD renders every phrase before a take and caches it as files by script hash and voice, because Personal Voice may render slower than real time and imported renderings arrive as files. But Stephanie, the voice in use, renders at about 40 times real time on the 14 Pro (plan 001: 63 s of audio in 1.3 s), so a two-minute step takes about 3 s, and a step held as audio is about 20 MB. Files would bring a store, an audio format, its timing check, clean-up and the `Rendering` record as an index, all to save a few seconds. So rendering is in memory only. Whether to save comes back when Personal Voice is judged (stage 7, open question 6): if it renders slower than real time, files are added then. The `Rendering` model stays in the schema, unused; imported renderings (P2) will reach the player as buffers like any other.

2. **The step is rendered when it is chosen.** A take is one step, so the unit of rendering is the step: when a script opens, its start step is rendered, and when another step is picked as the start, that one is. Rendering a whole script on opening would hold all of it in memory (a ten-minute script is over 100 MB at the player's format) for steps that may not be taken. Phrases render in order with progress in the rendering row, and a Render button stays for a failure (a voice not downloaded, an error), with the row saying what went wrong. Inline directions are rendered in the cue voice even with cues off, so the switch never needs a render.

3. **Rendered phrases are kept while the app runs, by content.** The renderer keeps each phrase's audio and timings keyed by the voice, the rate and the phrase's text. Picking a step already rendered, or a re-paste that leaves a phrase unchanged, re-uses it at once; a changed phrase has a new key and is rendered. When another script is opened, the phrases of the one before are let go, so memory holds one script's chosen steps at most. A relaunch renders the start step again, in a few seconds.

4. **Timings are mapped to script words when a take is built.** A rendering times tokens; a token with no letters or digits (a dash) has no script word, and a number in words is one token and one word. `PhraseTiming(rendered:)` takes each script word's token start; a token no marker named takes a start spaced evenly between its neighbours (or the phrase's end), so a missing marker never shifts the other words. The adapter `FollowScript(phraseList:timing:)` from plan 003 is given these timings by phrase index.

5. **The default voices, until Settings in stage 7.** The presenter's voice is Stephanie (Enhanced, en-GB), plan 001's pick, or else the best en-GB voice installed (premium, then enhanced, then compact), or else the best English one. The cue voice is the best en-GB voice that is not the presenter's, preferring the other gender so it is clearly not a line (Jamie, Premium, if downloaded). The rate is 0.5. The Script screen names the voice; if Stephanie is missing, the row says so and how to download her (Settings, Accessibility, Spoken Content, Voices).

6. **The slate is rendered at take time, in the cue voice.** Its text has the take number, so it cannot be rendered ahead. "Step 3, take 2." (the synthesiser reads digits as words); for a step with a shot ID, the ID spelled out with spaces between letters and digits ("W 3 1, take 2.") so it is said as letters and numbers. With cues on, the step's directions come first in the same cue, as §4.2 asks: its number and title, then its `Shows:` text, then the slate ("Step 3. Rosie up ahead. Rosie trots far ahead up the long track. Step 3, take 2."). The engine's `playCue(.slate)` plays it all, and the reply is listened for once it ends. A cue renders in about a tenth of a second, so Start does not feel it.

7. **The tones are made in code, as one buffer.** Three beeps of 1 kHz, 120 ms each, 0.6 s apart, with 5 ms fades so they do not click, at about −12 dBFS, padded with silence to the fourth beat. One buffer makes the spacing sample-exact; `tonesEnded` arrives when it has played, so phrase 1 starts on the fourth beat, where the presenter expects it. The buffer is scheduled on the audio clock a short moment ahead (50 ms), so the first beep is not clipped as the node starts. The tone level becomes a setting in stage 7 if it needs one.

8. **One engine, three player nodes.** `AudioEngineHost` grows from the spike's: the **voice** node through the time-pitch node (phrases in the presenter's voice, at the engine's speed), a **cue** node and a **tone** node straight to the mixer at 1.0x, and the mic tap as before for stage 5. A cue phrase or the slate on the cue node is never sped up or slowed down. `stopVoice` stops the voice and cue nodes. A completion is checked against a token, as now, so a phrase that was stopped never reports its end.

9. **The player turns commands into sound and sound into events.** `Player` takes a `TakeAudio` (the step's rendered phrases by phrase index with their kinds, the slate, the tones) and handles each `FollowCommand`: `play(phrase:speed:)` on the voice node (or the cue node for a cue phrase), `setSpeed`, `stopVoice`, `playCue(.slate)`, `playTones`; `finished` is the host's. It reports `phraseEnded`, `cueEnded` and `tonesEnded` as each buffer is heard to its end, and on each tick the voice's progress, `voiceProgress(phrase:offset:)`, in seconds of the rendering at 1.0x. Its audio work sits behind a small protocol (`PlayerOutput`), so the command and event logic is tested against a fake; the real one is `AudioEngineHost`.

10. **Progress is where the presenter hears the voice, not where the engine renders it.** The player node's sample time is what has been rendered; the earpiece plays it later by the output latency, which for Bluetooth A2DP is a large part of a word (150 to 250 ms is typical; the session reports it as `outputLatency`). The engine's lead counts words the presenter has heard, so the offset reported is the rendered offset less the output latency (and the IO buffer) at the current speed, never below zero; a phrase's end is reported when its data has been played back. The latency is read on every route change and logged, and the 14 Pro's figure with the SK18 goes in Results.

11. **The engine's clock is host time.** Events are stamped with `HostClock.now` in seconds, the clock the mic tap already stamps buffers with, so in stage 5 the listener's words and the player's progress are on one clock without conversion.

12. **Between phrases there is no added gap.** The engine releases the next phrase at the end of the current one; the player starts it as soon as the command arrives, the time for the completion to reach the main actor (a few milliseconds). The rendered phrases already end in the synthesiser's own short silence. If Andy hears a stutter between phrases in Listen, the player schedules a released phrase straight after the current buffer instead; the gap is measured from the console and recorded.

13. **Listen plays a step straight through.** The device check needs the renderer, the player, the cue voice, the slate and the tones heard together, but nothing drives them until stage 5. Listen, on the Script screen for the start step, plays the step's slate (with its directions when cues are on, and the next take's number, recording no take), the tones, then every phrase in order, cues in the cue voice, never waiting, at 1.0x or a chosen 0.85x or 1.2x. It shows the step's text with the word the voice is saying highlighted, from the player's progress (decision 10), so Andy can see whether the timings, the speed and the latency allowance agree with what he hears. It is the P1 fixed-pace rehearsal in all but name; whether to keep it after stage 5 is Andy's call.

## Files

| File | Purpose |
|------|---------|
| `Services/ScriptRenderer.swift` | Renders a step's missing phrases in order with `VoiceRenderer`, keeps them by voice, rate and text while the app runs, lets a script's go when another opens, reports progress; `@Observable` for the row |
| `Services/VoiceCatalogue.swift` | The default presenter and cue voices (decision 5), and a voice's display name |
| `Services/Slate.swift` | The slate's text for a step and take, with its directions when cues are on |
| `Services/Tones.swift` | The tone samples (pure) and their buffer |
| `Services/AudioEngineHost.swift` | Voice, cue and tone nodes; scheduling on the audio clock; the output latency |
| `Services/Player.swift` | `TakeAudio`, `PlayerOutput`, commands to sound and events and progress back |
| `Services/StepPreview.swift` | The straight play-through behind Listen (decision 13) |
| `Models/PhraseTiming+Rendered.swift` | Token starts to script-word starts, missing markers filled (decision 4) |
| `ViewModels/ScriptDetailViewModel.swift` | Rendering the start step on open and on a new pick, the row's state, Listen |
| `Views/ScriptDetail/ScriptDetailView.swift`, `Views/ScriptDetail/ListenView.swift` | The rendering row with progress and errors; the Listen sheet with the highlighted word, speed and Stop |
| `EarwigTests/ScriptRendererTests.swift`, `PhraseTimingTests.swift`, `SlateTests.swift`, `TonesTests.swift`, `PlayerTests.swift`, `VoiceCatalogueTests.swift` | As Steps |

## Steps

1. **Renderer.** `ScriptRenderer` over a renderer protocol, tested with a fake: renders a step's phrases in order, spoken in the presenter's voice and cues in the cue voice; reports progress; stops on cancel; a step already rendered renders nothing; a re-paste with one line changed renders only that line's phrases; a key changes with the voice, the rate and the text and nothing else; opening another script lets the first one's phrases go. One simulator test with the real `VoiceRenderer` and the simulator's voice renders a step of the sample. `VoiceCatalogue` tested on made-up voice lists (Stephanie first; the best en-GB; the cue voice never the presenter's and of the other gender where there is one).
2. **Timings and slate.** `PhraseTiming(rendered:)` tests: a dash token, a number in words as one word, a missing marker filled between its neighbours and at the end. `Slate` tests: step number, shot ID spelled out, take number, directions first with cues on and not with cues off.
3. **Tones and player.** `Tones` tests on the samples: three beeps at the spacing, the fades starting and ending at zero, the length to the fourth beat. `AudioEngineHost` with the three nodes and scheduled tones. `Player` tests against a fake output: each command to the right node at the right speed; a cue phrase on the cue node at 1.0x; `stopVoice` stopping both; ends reported once and never after a stop; progress less the latency at the speed, never negative; nothing reported for a node that is idle. One simulator smoke test plays the tones through the real engine and gets `tonesEnded`.
4. **Screen.** The rendering row (rendering the step with progress, ready in a voice with the phrase count, missing voice, error and Render), rendering on open and on a new start step, and Listen with its sheet. Checked in the simulator with `-EarwigDemo YES` for layout and the flow; the sound is for the phone.
5. **Device check** on the iPhone 14 Pro with the SK18, one check at a time (Verification), results in Results from Andy's verdicts and the console.
6. `swiftlint lint` clean, no build warnings, all tests pass; Results filled; PRD updated where the decisions pin them, as v0.6 with a Document History row: no rendered audio saved in v1, with saving waiting on Personal Voice's render speed (§2, §4.1's re-paste row, §4.2, §6.1, §7.2, §7.3, §9 Flow 4, question 6); the step rendered when chosen (§4.2, §8.2); the slate's text and the tones (§4.2, §4.5); the latency allowance (§5.1); Listen (§8.2); `progress.md` emptied to its stub.

## Verification

- `xcodebuild test` passes in the simulator; no warnings; SwiftLint clean.
- On the iPhone 14 Pro, installed with `devicectl` and the console read live, one at a time:
  1. **Render.** Open the sample script: its start step renders by itself; pick the other step: it renders; pick the first again: nothing renders. Recorded: time per step, words timed by markers against words in all, which marker source.
  2. **Listen.** Earpiece in, Listen to a step with cues on: the directions and slate in the cue voice, the tones, then the phrases, with an inline direction in the cue voice. Andy's verdicts: the tones (level, pitch, spacing, phrase 1 on the beat), the cue voice against the presenter's, any stutter between phrases. Recorded from the console: the output latency on the SK18 and the gaps between phrases.
  3. **Highlight.** In the same Listen, at 1.0x, then 0.85x and 1.2x: whether the highlighted word is the word heard, early or late, and by how much by his ear.
  4. **Locked.** Listen with the screen locked: it plays to the end of the step. (Plan 001 already showed background audio; this checks the new player.)

## Review (2026-11-06)

Andy asked why rendered audio is saved at all. With Stephanie rendering at about 40 times real time, it need not be: decision 1 renders in memory, a step at a time, and leaves saving until Personal Voice's render speed is known.

## Results

### Built

All steps done. 192 Swift Testing tests pass, the build has no warnings and SwiftLint is clean.

- **Renderer** (`Services/ScriptRenderer.swift`): the start step rendered in memory when the script opens or another step is picked, phrases kept by voice, rate and text while the app runs, a script's let go when another opens, progress for the row. `VoiceRenderer` now runs one render at a time, so a superseded render cannot take another's word markers (review C1).
- **Voices** (`Services/VoiceCatalogue.swift`): Stephanie (Enhanced, en-GB) by default, else the best en-GB voice; the cue voice the best en-GB voice that is not the presenter's, the other gender first (Jamie, Premium). A presenter voice can be picked by hand.
- **Timings** (`Models/PhraseTiming+Rendered.swift`): one start per script word, missing markers spaced between their neighbours.
- **Slate** (`Services/Slate.swift`), **tones and chime** (`Services/Tones.swift`), **player** (`Services/Player.swift`, `Services/AudioEngineHost.swift`: voice, cue and tone channels behind `PlayerOutput`), **Listen** (`Services/StepPreview.swift`, `Views/ScriptDetail/ListenView.swift`), the rendering row, and the settings in `Models/AppSettings.swift`.

### Decided while building and on the phone

- **Phrase ends are reported on render, not on playback.** With `.dataPlayedBack`, each phrase's end arrived about 520 ms after its length on the SK18 (433 to 533 ms over ten phrases), the next phrase starting only then; Andy heard the pauses at commas as "slightly too long". With `.dataRendered` the ends arrive 68 to 95 ms after the length and the next phrase reaches the earpiece through the same latency, so nothing is added; Andy: "The comma pauses do sound right." Decision 12's fallback was not needed.
- **iOS 27 puts the quality in a voice's name** ("Stephanie (Enhanced)"), so the first build did not find Stephanie and used Jamie; `VoiceInfo.baseName` strips it. The en-GB voices are logged at launch.
- **Directions inside a line are a setting (Andy), Chime by default or Spoken.** A spoken direction costs its own length as a gap in the take: "Gesture to the boats" is 1.35 s, about 1.9 s with the old end delay. Andy: "it pauses my overall performance… I'm not sure this is a workable solution." The first chime (0.15 s, high) was "noticeable", but he wanted "an elongated low ping or pong": now D4 with two partials, 0.8 s, about −14 dBFS ("much better", then "slightly louder"), played on the tone channel and ringing on under the next line while the voice waits only 0.25 s. Reading the step's inline directions in the slate was tried and dropped: "If there were several directions, it would be difficult to remember them."
- **Personal Voice tried and dropped** (open question 6), when Andy's was ready: "The voice quality is actually terrible. It sounds like some cross between me and the built-in voices… It takes longer to render, and it's really not worth it." It rendered step 1's nine spoken phrases (16.8 s of audio) in 7.33 s, about 2.3 times real time against Stephanie's 20, with every word timed (70 of 70, markers from both). Andy would rather put the effort into a better built-in voice, a voice from another source, or his own reading as recorded.
- **Our own Paste button.** iOS darkens a `PasteButton`'s tint to keep its forced white text legible, which made the accent "goldy brown"; dark text and a light scheme were both ignored. Andy chose our own yellow button, which asks Allow Paste until Paste from Other Apps is set to Allow; in the toolbar its iOS 26 glass capsule is hidden.
- **The voice and the directions setting sit in the Script screen's ••• menu** until the Settings screen (stage 7).

### Device check (iPhone 14 Pro, iOS 27.0.1, SK18), 2026-11-06 and 07

| Check | Result |
|-------|--------|
| 1. Render | Pass (Andy: "It all looks good to me"). Step 1: 10 phrases, 22.4 s of audio in 0.78 to 1.14 s, 74 of 74 words timed; step 2: 8 phrases, 19.5 s in 0.35 s, 76 of 76. Stephanie's markers come through both the callback and the delegate; source 22,050 Hz. Picking a rendered step again renders nothing. |
| 2. Listen | Pass after the changes above. The slate and cues in Jamie are recognisable "because of the change in voice"; Andy does not like the voices much. Output latency on the SK18: **356 ms** (333 ms route plus 23 ms buffer), against 41 ms on the phone's speaker. Overall speed "a little fast"; 0.85x "seemed more normal", to be judged again on real takes in stage 5, where the engine paces the voice. |
| 3. Highlight | Pass (Andy: "everything looks good"), at 1.0x and the other speeds. |
| 4. Locked | Pass: Listen played the whole step with the screen locked and the sheet said Finished on unlocking. |

**Outcome: PASS** (2026-11-07). Rendering, the player, the tones, the cue voice and the latency allowance work through the SK18 on the iPhone 14 Pro, locked as well. The voice itself remains the weak point: Personal Voice is worse than Stephanie, so a better voice (another downloaded voice, or an imported recording) is a follow-up. PRD v0.6.

## Review pass — 2026-11-06

Findings from `/review-branch` on branch `renderer-player`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact, and each verdict under *Assessment* is a
recommendation, not a decision. Work through them and annotate each with what was done — fixed,
or rejected and why. A finding that turns out to be wrong should say so here rather than be
deleted.

### Code

Review of `renderer-player` against `main` (plan 004, issue #11). Everything is committed and there are no untracked files. Steps 1–4 of the plan are covered, including both simulator tests: the real-voice render and the tones smoke test. Steps 5–6 (device check, Results, PRD v0.6) are still to do, so their absence is not flagged.

**C1 — WARNING: renders can overlap on the one shared `VoiceRenderer`, and the second loses its word timings.**
- **Where:** `Earwig/Services/ScriptRenderer.swift:92-95` (`prepare`), and the `ScriptRenderer.cancel()` that follows. They collide with `Earwig/Services/VoiceRenderer.swift:51,64`.
- **Cause:** `prepare` and `cancel` only cancel the `Task`. `VoiceRenderer.render` waits in `withCheckedContinuation`, ignores cancellation, and `VoiceRenderer.cancel()` is never called. So picking another step, pasting a new version, or reopening the screen while a step is rendering starts a second `render` while the first is still in flight.
- **Effect:**
  - The new call sets `self.job = newJob`.
  - When the old one finishes it runs `self.job = nil`, which wipes out the new job.
  - From then on the delegate's `willSpeakMarker` and `didFinish` callbacks for the new utterance are dropped (`guard let job, job.utterance === utterance`).
  - On voices that send markers only through the delegate, as the simulator does, those phrases lose their word timings and silently fall back to even spacing. That breaks the highlight check and, in stage 5, the engine.
- **Fix:** call `VoiceRenderer.cancel()` when a render is superseded, or wait for the previous task to finish before starting the next.

**C2 — WARNING: Stop or dismissing the sheet while Listen is preparing does nothing, and the audio then plays with no screen.**
- **Where:** `Earwig/Services/StepPreview.swift:62-89, 100-101`.
- **Cause:** `start()` sets `status = .preparing`, then waits on `renderer.renderCue(slateText)`. It assigns `self.player` only after that. `stop()` begins with `guard player != nil else { return }`.
- **Effect:**
  - Tapping Stop (shown during `.preparing`) does nothing.
  - If the sheet is dismissed in that window, `onDisappear` → `stop()` also does nothing. `start()` then resumes, since it holds `self` strongly, and plays the whole step with no UI. The session stays active and the host is never stopped.
- **Fix:** `stop()` should work from any playing status (for example, guard on `isPlaying`), and `start()` should check after each `await` that it has not been stopped.

**C3 — WARNING: a hardware configuration change during playback leaves the engine stopped.**
- **Where:** `Earwig/Services/AudioEngineHost.swift:70-76` (`configurationChanged`).
- **Cause:** the engine is restarted only when a mic tap is installed. This branch adds playback with no tap (Listen, and the `Player` path generally).
- **Effect:** a route or sample-rate change mid-play (earpiece connecting or dropping, or the A2DP rate change) stops the engine and it stays down. Listen then either goes silent or carries on only if the stopped node happens to fire its completion. Either way the behaviour now depends on chance.
- **Fix:** restart the engine whenever it was running, tap or not.

**C4 — SUGGESTION: the rendering state does not say which script it belongs to.**
- **Where:** `Earwig/Services/ScriptRenderer.swift` (`State`) and `Earwig/ViewModels/ScriptDetailViewModel.swift:52-59` (`renderState`).
- **Cause:** `renderState` compares only the step index with `script.lastStep`.
- **Effect:** when a second script is opened, its row briefly shows the previous script's `.ready(step:)` state, Listen button included, until the new `prepare` task runs. The DEBUG `-EarwigListen` `onChange` can fire on it too. Tapping Listen in that moment gets "The step is not rendered yet."
- **Fix:** carry the script id in `State`, or reset to `.idle` synchronously in `prepare`.

**C5 — SUGGESTION: many plan-decision numbers in code comments are off by one.**
- **Cause:** they look like they follow an earlier draft of the plan.
- **Where, and the correct number:**
  - `Earwig/Models/PhraseTiming+Rendered.swift:4` says decision 5; it is 4.
  - `Earwig/Services/AudioEngineHost.swift:3` says 9; it is 8.
  - `AudioEngineHost.swift:14` says 10; it is 9.
  - `AudioEngineHost.swift:85` says 11; it is 10.
  - `AudioEngineHost.swift:180` says 12; it is 11.
  - `Earwig/Services/Player.swift:4` says 10; it is 9.
  - `Player.swift:17` says "9 to 11"; it is 8 to 10.
  - `Earwig/Services/Tones.swift:3` says 8; it is 7.

**C6 — SUGGESTION: the new `-EarwigListen YES` Debug launch flag is not documented.**
- **Where:** `Earwig/Views/ScriptDetail/ScriptDetailView.swift:74-86`.
- **Fix:** add it next to `-EarwigDemo` in CLAUDE.md's Build Commands, so the simulator workflow is discoverable.

**C7 — SUGGESTION: each Listen leaves `NotificationCenter` observers behind.**
- **Where:** `Earwig/Services/AudioEngineHost.swift` init.
- **Cause:** the new `routeChangeNotification` observer has `object: nil`, and the observer tokens are never removed (there is no `deinit`). A new `AudioEngineHost` is built for every `StepPreview`.
- **Effect:** observers pile up across Listen sessions. They do nothing, since they capture `weak self`, but they are never released.
- **Fix:** remove them in a `deinit`.

### Tests

I read all six new test files in full: PhraseTiming, Player, ScriptRenderer, Slate, Tones and VoiceCatalogue. Nothing is staged, unstaged or untracked under EarwigTests/. I compared each against its source. I did not run the suite. Most of the new code has focused tests, and the volume (about 556 lines for about 700 lines of source) is reasonable. Two tests give more confidence than they earn, and two pieces of logic have no tests.

**T1. WARNING: `aNewPhraseReplacesTheOneBefore` would pass even if the player's logic were broken.**
- **Where:** `/Users/andybower/Projects/Earwig/EarwigTests/PlayerTests.swift:110-116`
- **Why it proves nothing:** `FakeOutput.play` overwrites `completions[channel]`. So when one voice phrase follows another on the same channel, only the second can ever end, whatever `Player` does.
- **What goes untested:** the logic that matters is `play()` calling `stopVoice()` first, which drops an older completion on another channel (`/Users/andybower/Projects/Earwig/Earwig/Services/Player.swift:86`).
- **Fix:** play cue phrase 1, then voice phrase 2, call `output.end(.cue)`, and expect no event. This one change exercises the "never reported after a stop" rule for real.

**T2. WARNING: if audio fails to start, the real-engine tones test hangs for a minute instead of failing.**
- **Where:** `/Users/andybower/Projects/Earwig/EarwigTests/PlayerTests.swift:184-198`
- **Why:** when `output.play` throws, `Player.start` only passes the error to `onLog` (`/Users/andybower/Projects/Earwig/Earwig/Services/Player.swift:104-110`). `tonesEnded` then never arrives, and the continuation waits until the one-minute limit.
- **Fix:** set `player.onLog` to record an `Issue` and resume, or call `try host.start()` before `handle(.playTones)` so the error surfaces at once.

**T3. WARNING: the view model's new rendering logic has no tests.**
- **Where:** `/Users/andybower/Projects/Earwig/Earwig/ViewModels/ScriptDetailViewModel.swift:27-31, 40-44, 52-60, 62-71`
- **What is untested:**
  - `renderState`, which hides the shared renderer's state when it is for another step.
  - The early return in `select` when the step picked is already the start step.
  - The `startStep` fallback when `lastStep` is out of range.
  - The next take's number in `listen`.
- **Note:** `renderState` compares only the step index, not the script, which is easy to get wrong.
- **Fix:** one test using an in-memory container and `ScriptRenderer(renderer: FakeRenderer(), ...)`, covering pick step 1, the state shown for step 0 versus step 1, and picking the same step twice. That would pin it cheaply.

**T4. SUGGESTION: `progressIsReportedAndAFailureShown` is hard to follow.**
- **Where:** `/Users/andybower/Projects/Earwig/EarwigTests/ScriptRendererTests.swift:106-127`
- **Why:**
  - It tests three things at once: progress, failure and resuming after a failure.
  - It counts successes indirectly, through `seen.count` from the hook.
  - It depends on "breakfast" appearing at phrase 2 or later of the sample's step 1.
- **Fix:** split it into a progress test and a failure-then-retry test that states the expected number of renders. A small `PhraseList(lines:)` written in the test would replace the dependence on the sample script.

**T5. SUGGESTION: a render superseded by a newer one is not tested.**
- **Where:** `/Users/andybower/Projects/Earwig/Earwig/Services/ScriptRenderer.swift:92-95, 127, 135`
- **What is missing:** the common real case, where another step is picked mid-render and the stale render must not write its state or cache. Only the `cancel()` case is covered, at `/Users/andybower/Projects/Earwig/EarwigTests/ScriptRendererTests.swift:129-136`. The guard after a failure (line 135) is also untested.
- **Fix:** worth one test if it can be written without awkward async plumbing.

**T6. SUGGESTION: Listen's playback order is untested.**
- **Where:** `/Users/andybower/Projects/Earwig/Earwig/Services/StepPreview.swift:113-134`
- **What is untested:**
  - The sequence: slate, then tones, then the first phrase, then each phrase after the one that ended.
  - Cue phrases being skipped when cues are off.
- **Why it can't be tested today:** the class creates its own `AudioSessionManager` and `AudioEngineHost`.
- **Judgement:** Listen is a device-check tool that may go after stage 5, so leaving it untested is defensible. If it stays, pass in a `PlayerOutput` and add one cues-off test.

**T7. SUGGESTION: two Player tests overlap.**
- **Where:** `/Users/andybower/Projects/Earwig/EarwigTests/PlayerTests.swift:139-145` and `:100-108`
- **Why:** `aStoppedSlateNeverEnds` checks the same thing as `stopVoiceStopsBothAndNoEndIsReported`: that `stopVoice` stops the cue channel and the fake then drops its completion.
- **Fix:** fold the slate case into the stop test, or drop it.

**T8. SUGGESTION: `aNumberInWordsIsOneWord` duplicates other tests.**
- **Where:** `/Users/andybower/Projects/Earwig/EarwigTests/PhraseTimingTests.swift:21-26`
- **Why:** the token-count check repeats `PhraseSplitterTests.swift:70-71`. The timing check is the same one-start-per-word mapping as `eachScriptWordTakesItsTokensStart`.
- **Fix:** fold it into the dash test as a single phrase, for example "about three hundred feet — up".

**T9. SUGGESTION: the Tones tests could be smaller and less noisy.**
- **Where:** `/Users/andybower/Projects/Earwig/EarwigTests/TonesTests.swift:22-39`
- **Why:**
  - `noLouderThanMinusTwelve` is a one-line bound that could join the first test.
  - `eachBeepFadesInAndOut` runs `#expect` inside a loop of about 720 samples, so one envelope bug floods the output with hundreds of failures.
- **Fix:** use a single `allSatisfy` per beep instead.

**T10. SUGGESTION: a shared test helper lives in another test's file.**
- **Where:** `/Users/andybower/Projects/Earwig/EarwigTests/ScriptRendererTests.swift:5-12`
- **Why:** `silence(seconds:)` is used by `PlayerTests.swift` as well, which couples the two files.
- **Fix:** move it beside the other shared test data in `/Users/andybower/Projects/Earwig/EarwigTests/Fixtures.swift`.

### Assessment

- C1 — FIX: real (`VoiceRenderer.swift:51,64` sets and clears one shared `job`; `ScriptRenderer.prepare` only cancels the Task). Serialise `VoiceRenderer.render` so one write runs at a time, and clear `job` only if it is still this call's; the generation check already drops a superseded result.
- C2 — FIX: real (`StepPreview.stop` guards on `player`, set only after the slate's `await`). `stop()` works whenever playing or preparing, and `start()` gives up after the `await` if it was stopped.
- C3 — FIX (part): restart the engine after a configuration change whenever it was running, tap or not, and log it. Not resuming the interrupted phrase: that is the take host's re-anchor in stage 5.
- C4 — FIX: `prepare` records the script it is for synchronously, and `renderState` shows nothing for another script.
- C5 — FIX: renumber the decision references (the plan lost three decisions at review).
- C6 — FIX: one line in CLAUDE.md's Build Commands beside `-EarwigDemo`.
- C7 — FIX: remove the observers in `deinit` (the spike's configuration observer was never removed either; this branch made it one per Listen).
- T1 — FIX: play a cue phrase then a voice phrase, end the cue channel, expect nothing.
- T2 — FIX: resume and record an issue from `onLog`.
- T3 — FIX (part): one view-model test of `renderState` (another step, another script) and of picking the start step again; not the `startStep` fallback or the take number, which are one-liners.
- T4 — FIX: split into a progress test and a failure-then-retry test on a small phrase list of its own.
- T5 — FIX: one test that a render superseded by `prepare` for another step leaves the new step's state and nothing of the old one's; cheap once C1's serialising is in.
- T6 — SKIP: Listen builds its own audio and exists for the device check, which covers its order by ear; injecting an output for a tool that may go after stage 5 costs more than it saves.
- T7 — FIX: fold the stopped-slate case into the stop test.
- T8 — FIX: fold the number into the dash test.
- T9 — FIX: loudness into the first test; one `allSatisfy` per beep for the fades.
- T10 — FIX: move `silence(seconds:)` to `Fixtures.swift`.

### Outcome — 2026-11-06

- C1 — fixed: `VoiceRenderer.render` runs one call at a time, in order, and clears its job only if it is still that call's.
- C2 — fixed: `StepPreview.stop()` works while preparing, and `start()` gives up after the slate's `await` if it was stopped.
- C3 — fixed (part): after a configuration change the engine is restarted whenever it was started and not stopped, mic tap or not. A buffer cut off by the change is not resumed (stage 5's re-anchor).
- C4 — fixed: `ScriptRenderer.target` names the script, set synchronously by `prepare`, which also resets the state for a new script; `renderState` shows nothing for another script.
- C5 — fixed: decision references renumbered.
- C6 — fixed: `-EarwigListen YES` documented in CLAUDE.md beside `-EarwigDemo`.
- C7 — fixed: `AudioEngineHost` removes its observers in `deinit`.
- T1 — fixed: `aNewPhraseStopsTheOneBeforeOnTheOtherChannel` plays a cue phrase then a voice phrase and ends the cue: nothing is reported.
- T2 — fixed: the real-engine tones test ends on a logged failure.
- T3 — fixed (part): `ScriptDetailViewModelTests` covers the state shown for another step and another script and re-picking the start step; not the `startStep` fallback or the take number.
- T4 — fixed: split into `progressIsReportedAsEachPhraseRenders` and `aFailureIsShownAndARetryRendersOnlyTheRest`, on a three-phrase list of their own.
- T5 — fixed: `aRenderSupersededByAnotherStepLeavesNothingOfItself`, and `anotherScriptStartsIdleAtOnce` for C4.
- T6 — not done: Listen is covered by ear in the device check and may go after stage 5.
- T7 — fixed: the stopped slate folded into the stop test.
- T8 — fixed: the number folded into the dash test.
- T9 — fixed: loudness in the first test; one `allSatisfy` per beep for the fades.
- T10 — fixed: `silence(seconds:)` moved to `Fixtures.swift`.

188 tests pass, no warnings, SwiftLint clean. Listen rechecked in the simulator.
