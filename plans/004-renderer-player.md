# Plan 004: Renderer and Player

**GitHub Issue:** [#11](https://github.com/bowerhaus/Earwig/issues/11) (PR must include "Closes #11")
**Branch:** `renderer-player` (from `main` at `a382ac8`, after plan 003 merged)
**Status:** Draft for review (2026-11-06).
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

To come.
