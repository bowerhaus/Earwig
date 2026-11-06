# Plan 004: Renderer and Player

**GitHub Issue:** not yet created (after review: `/plan_create_issue`)
**Branch:** `renderer-player` (from `main` at `a382ac8`, after plan 003 merged)
**Status:** Draft for review (2026-11-06).
**Manual test:** yes, on Andy's iPhone 14 Pro with the SK18: render the sample, the cache and a re-paste, and a step listened to through the earpiece with the words highlighted as they are spoken (Verification).
**Goal:** Turn a script into audio the follow engine can drive. Every phrase is rendered once, in the presenter's voice or the cue voice, to a file with its word timings, and kept until the text, the voice or the rate changes. A player on one audio engine plays what the engine commands (phrases at a speed, the slate, the tones), on the audio clock, and reports where the voice is as the presenter hears it. Nothing listens yet: that is stage 5. To hear the result before then, the Script screen gets Listen, which plays a step straight through.

**PRD references:** §3 Core Concepts (phrase, rendering, cue voice), §4.2 Voice Rendering, §4.5 Starting a take (slate, tones), §5.1 and §5.2 (the player's events and commands), §6.1 Rendering, §7.2 Key Services (VoiceRenderer, RenderingStore, Player), §8.2 Script (the rendering row), §9 Flow 4 (the script changed), §12 stage 4.

---

## Scope

**In:** rendering every phrase of a script (spoken phrases in the presenter's voice, inline directions in the cue voice) to files with word timings; the rendering store, with files kept by content so an unchanged phrase is never rendered twice, and cleared when nothing uses them; the `Rendering` record as the script's index; timings mapped to the engine's script words; the default presenter and cue voices; the slate's text and its rendering at take time; the tones; the player (voice, cue and tone nodes on one `AVAudioEngine`, the time-pitch node for speed, commands in, events and progress out, allowing for the output latency); the rendering row on the Script screen; Listen, a straight play-through of a step for checking by ear; tests for all of it that the simulator can run.

**Out:** the `Listener` feeding the engine, the take host that ticks the engine and passes events between it and the player, the Prompt screen, the manual controls, route check and the Listening check (stage 5); Screen mode (stage 6); choosing voices, rate and tone level in Settings, and Personal Voice (stage 7, open question 6); imported renderings (P2). Issues #5, #6, #9 and #10 stay open.

## Design decisions

1. **Files are kept by content, not by script.** PRD §6.1 puts files in `Renderings/<script hash>/<voice>/`, but a re-paste changes the script hash, and §4.1 and Flow 4 want unchanged phrases to keep their renderings. A phrase's file is named by a key: the first 16 hex digits of SHA-256 over a format version, the voice identifier, the rate and the phrase's text. The files live in `Application Support/Renderings/<voice identifier>/<key>.m4a`, with `<key>.json` beside each (the word starts and the duration). A changed phrase has a new key and is rendered; an unchanged one, in this script or any other, is found and re-used. Kind does not enter the key: the voice already tells a cue from a spoken phrase.

2. **The `Rendering` record is the script's index of what it uses.** One per script for the current presenter voice, cue voice and rate (a new property, `cueVoiceIdentifier`; SwiftData migrates an added property with a default). Its phrase map, keyed by phrase key, holds each file's name and word starts, which the Script screen counts ("Rendered in Stephanie, 42 phrases") and a take loads from. A script is rendered when every phrase of every step has its key in the record and its file on disk. When a script is deleted or re-rendered in another voice, files that no `Rendering` lists are deleted (at that moment and once at launch).

3. **Rendering starts by itself.** Opening a script with anything unrendered renders the missing phrases straight away, in order, with progress in the rendering row; plan 001 measured Stephanie at about 40 times real time on the 14 Pro, so the sample takes a second or two. A Render button stays for a failure (a voice not downloaded, an error), and the row says what went wrong. Inline directions are rendered in the cue voice even with cues off, so the switch never needs a render.

4. **Files are AAC in `.m4a`, 48 kHz mono.** The player's format is 48 kHz mono float (`VoiceRenderer.outputFormat`), 192 KB a second: a ten-minute script would take over 100 MB as raw audio. AAC at 64 kbit/s is about 8 KB a second. AAC adds priming frames at the start of a file; `AVAudioFile` writes the packet table and trims them on reading, which a round-trip test confirms by frame count and by a click placed at a known time. If it does not, the format becomes Apple Lossless at the same rate, about half of 16-bit PCM, with no priming at all.

5. **Timings are mapped to script words when a take is built.** A rendering times tokens; a token with no letters or digits (a dash) has no script word, and a number in words is one token and one word. `PhraseTiming(rendered:)` takes each script word's token start; a token no marker named takes a start spaced evenly between its neighbours (or the phrase's end), so a missing marker never shifts the other words. The adapter `FollowScript(phraseList:timing:)` from plan 003 is given these timings by phrase index.

6. **The default voices, until Settings in stage 7.** The presenter's voice is Stephanie (Enhanced, en-GB), plan 001's pick, or else the best en-GB voice installed (premium, then enhanced, then compact), or else the best English one. The cue voice is the best en-GB voice that is not the presenter's, preferring the other gender so it is clearly not a line (Jamie, Premium, if downloaded). The rate is 0.5. The Script screen names the voice; if Stephanie is missing, the row says so and how to download her (Settings, Accessibility, Spoken Content, Voices).

7. **The slate is rendered at take time, in the cue voice.** Its text has the take number, so it cannot be rendered ahead. "Step 3, take 2." (the synthesiser reads digits as words); for a step with a shot ID, the ID spelled out with spaces between letters and digits ("W 3 1, take 2.") so it is said as letters and numbers. With cues on, the step's directions come first in the same cue, as §4.2 asks: its number and title, then its `Shows:` text, then the slate ("Step 3. Rosie up ahead. Rosie trots far ahead up the long track. Step 3, take 2."). The engine's `playCue(.slate)` plays it all, and the reply is listened for once it ends. A cue renders in about a tenth of a second, so Start does not feel it.

8. **The tones are made in code, as one buffer.** Three beeps of 1 kHz, 120 ms each, 0.6 s apart, with 5 ms fades so they do not click, at about −12 dBFS, padded with silence to the fourth beat. One buffer makes the spacing sample-exact; `tonesEnded` arrives when it has played, so phrase 1 starts on the fourth beat, where the presenter expects it. The buffer is scheduled on the audio clock a short moment ahead (50 ms), so the first beep is not clipped as the node starts. The tone level becomes a setting in stage 7 if it needs one.

9. **One engine, three player nodes.** `AudioEngineHost` grows from the spike's: the **voice** node through the time-pitch node (phrases in the presenter's voice, at the engine's speed), a **cue** node and a **tone** node straight to the mixer at 1.0x, and the mic tap as before for stage 5. A cue phrase or the slate on the cue node is never sped up or slowed down. `stopVoice` stops the voice and cue nodes. A completion is checked against a token, as now, so a phrase that was stopped never reports its end.

10. **The player turns commands into sound and sound into events.** `Player` takes a `TakeAudio` (the take's phrases loaded into buffers by phrase index with their kinds, the slate buffer, the tones) and handles each `FollowCommand`: `play(phrase:speed:)` on the voice node (or the cue node for a cue phrase), `setSpeed`, `stopVoice`, `playCue(.slate)`, `playTones`; `finished` is the host's. It reports `phraseEnded`, `cueEnded` and `tonesEnded` as each buffer is heard to its end, and on each tick the voice's progress, `voiceProgress(phrase:offset:)`, in seconds of the rendering at 1.0x. Its audio work sits behind a small protocol (`PlayerOutput`), so the command and event logic is tested against a fake; the real one is `AudioEngineHost`.

11. **Progress is where the presenter hears the voice, not where the engine renders it.** The player node's sample time is what has been rendered; the earpiece plays it later by the output latency, which for Bluetooth A2DP is a large part of a word (150 to 250 ms is typical; the session reports it as `outputLatency`). The engine's lead counts words the presenter has heard, so the offset reported is the rendered offset less the output latency (and the IO buffer) at the current speed, never below zero; a phrase's end is reported when its data has been played back. The latency is read on every route change and logged, and the 14 Pro's figure with the SK18 goes in Results.

12. **The engine's clock is host time.** Events are stamped with `HostClock.now` in seconds, the clock the mic tap already stamps buffers with, so in stage 5 the listener's words and the player's progress are on one clock without conversion.

13. **Between phrases there is no added gap.** The engine releases the next phrase at the end of the current one; the player starts it as soon as the command arrives, the time for the completion to reach the main actor (a few milliseconds). The rendered phrases already end in the synthesiser's own short silence. If Andy hears a stutter between phrases in Listen, the player schedules a released phrase straight after the current buffer instead; the gap is measured from the console and recorded.

14. **Listen plays a step straight through.** The device check needs the renderer, the store, the player, the cue voice, the slate and the tones heard together, but nothing drives them until stage 5. Listen, on the Script screen for the start step, plays the step's slate (with its directions when cues are on, and the next take's number, recording no take), the tones, then every phrase in order, cues in the cue voice, never waiting, at 1.0x or a chosen 0.85x or 1.2x. It shows the step's text with the word the voice is saying highlighted, from the player's progress (decision 11), so Andy can see whether the timings, the speed and the latency allowance agree with what he hears. It is the P1 fixed-pace rehearsal in all but name; whether to keep it after stage 5 is Andy's call.

## Files

| File | Purpose |
|------|---------|
| `Services/RenderingStore.swift` | Phrase keys, the folder, writing and reading audio and timings, which phrases of a script are missing, the `Rendering` record kept up to date, removing files nothing uses |
| `Services/ScriptRenderer.swift` | Renders a script's missing phrases in order with `VoiceRenderer`, through the store, reporting progress; `@Observable` for the row |
| `Services/VoiceCatalogue.swift` | The default presenter and cue voices (decision 6), and a voice's display name |
| `Services/Slate.swift` | The slate's text for a step and take, with its directions when cues are on |
| `Services/Tones.swift` | The tone samples (pure) and their buffer |
| `Services/AudioEngineHost.swift` | Voice, cue and tone nodes; scheduling on the audio clock; the output latency |
| `Services/Player.swift` | `TakeAudio`, `PlayerOutput`, commands to sound and events and progress back |
| `Services/StepPreview.swift` | The straight play-through behind Listen (decision 14) |
| `Models/Rendering.swift` | `cueVoiceIdentifier`; the phrase map keyed by phrase key |
| `Models/PhraseTiming+Rendered.swift` | Token starts to script-word starts, missing markers filled (decision 5) |
| `ViewModels/ScriptDetailViewModel.swift` | Rendering on open, the row's state, Listen |
| `Views/ScriptDetail/ScriptDetailView.swift`, `Views/ScriptDetail/ListenView.swift` | The rendering row with progress and errors; the Listen sheet with the highlighted word, speed and Stop |
| `EarwigTests/RenderingStoreTests.swift`, `ScriptRendererTests.swift`, `PhraseTimingTests.swift`, `SlateTests.swift`, `TonesTests.swift`, `PlayerTests.swift`, `VoiceCatalogueTests.swift` | As Steps |

## Steps

1. **Store.** `RenderingStore` with tests in a temporary folder: a key changes with the text, the voice, the rate and the format version and with nothing else; audio written and read back is the same length to the frame and in the player's format, with a click placed at 1.0 s still at 1.0 s (decision 4; Apple Lossless if AAC fails); timings round-trip; a script's missing phrases, spoken and cue each against its own voice; the `Rendering` record kept in step; files no record lists removed, and listed ones kept.
2. **Renderer.** `ScriptRenderer` over a renderer protocol, tested with a fake: renders only what is missing, in step and phrase order, reports progress, stops on cancel; after a re-paste with one line changed, only that line's phrases render (Flow 4). One simulator test with the real `VoiceRenderer` and the simulator's voice renders the sample and reads it back. `VoiceCatalogue` tested on made-up voice lists (Stephanie first; the best en-GB; the cue voice never the presenter's and of the other gender where there is one).
3. **Timings and slate.** `PhraseTiming(rendered:)` tests: a dash token, a number in words as one word, a missing marker filled between its neighbours and at the end. `Slate` tests: step number, shot ID spelled out, take number, directions first with cues on and not with cues off.
4. **Tones and player.** `Tones` tests on the samples: three beeps at the spacing, the fades starting and ending at zero, the length to the fourth beat. `AudioEngineHost` with the three nodes and scheduled tones. `Player` tests against a fake output: each command to the right node at the right speed; a cue phrase on the cue node at 1.0x; `stopVoice` stopping both; ends reported once and never after a stop; progress less the latency at the speed, never negative; nothing reported for a node that is idle. One simulator smoke test plays the tones through the real engine and gets `tonesEnded`.
5. **Screen.** The rendering row (rendering with progress, rendered in a voice with the phrase count, missing voice, error and Render), rendering on open, and Listen with its sheet. Checked in the simulator with `-EarwigDemo YES` for layout and the flow; the sound is for the phone.
6. **Device check** on the iPhone 14 Pro with the SK18, one check at a time (Verification), results in Results from Andy's verdicts and the console.
7. `swiftlint lint` clean, no build warnings, all tests pass; Results filled; PRD §4.2, §6.1, §7.2, §7.3 and §8.2 updated where the decisions pin them (files by content, the record as the index, rendering on open, the slate's text, the tones, the latency allowance, Listen), as v0.6 with a Document History row; `progress.md` emptied to its stub.

## Verification

- `xcodebuild test` passes in the simulator; no warnings; SwiftLint clean.
- On the iPhone 14 Pro, installed with `devicectl` and the console read live, one at a time:
  1. **Render.** Open the sample script: it renders by itself. Recorded: time taken, phrases, words timed by markers against words in all, which marker source, the size on disk.
  2. **Cache.** Quit and relaunch, open the sample: nothing renders. Paste a version with one line changed: only that line's phrases render.
  3. **Listen.** Earpiece in, Listen to a step with cues on: the directions and slate in the cue voice, the tones, then the phrases, with an inline direction in the cue voice. Andy's verdicts: the tones (level, pitch, spacing, phrase 1 on the beat), the cue voice against the presenter's, any stutter between phrases. Recorded from the console: the output latency on the SK18 and the gaps between phrases.
  4. **Highlight.** In the same Listen, at 1.0x, then 0.85x and 1.2x: whether the highlighted word is the word heard, early or late, and by how much by his ear.
  5. **Locked.** Listen with the screen locked: it plays to the end of the step. (Plan 001 already showed background audio; this checks the new player.)

## Review

To come.

## Results

To come.
