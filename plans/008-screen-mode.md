# Plan 008: Screen Mode

**GitHub Issue:** to be created (`/plan_create_issue`); the PR must include "Closes #N".
**Branch:** `screen-mode` (from `main` at `ed33225`, after plan 007 merged)
**Status:** Approved for autopilot (2026-11-08), pausing for the device checks.
**Manual test:** device, on Andy's iPhone 14 Pro, on the mount and in the hand, with and without the SK18 (Verification).
**Goal:** Stage 6 of PRD §12. The take's step appears on the Prompt screen as large scrolling text, kept at the presenter's place by the same engine that follows them in Ear mode. Ear and Screen can run together (Flow 2, the desk head on the mount), and either can be switched off. With Ear off, the text follows the presenter directly: there is no voice and no rendering, so a take starts as soon as Start is tapped. Font size is a setting and a pinch.

**PRD references:** §4.4 Following, §4.6 Screen mode, §4.8 Settings, §5.4 Pacing (the presenter estimate), §5.5 Start, §8.3 Prompt, §8.4 Settings, §9 Flows 2 and 3, §10 Design Language, §12 stage 6.

---

## Scope

**In:**
- a voiceless way of following in the engine, for Ear off (decision 1);
- the scrolling text on the Prompt screen, with the presenter's place at a reading line, the voice's phrase lit when Ear is on, and directions in the cue colour (decisions 2 to 5);
- three modes, Ear, Screen and Ear and Screen, in Settings and beside Start on the Script screen, chosen before the take (decision 6);
- Start without rendering when Ear is off (decision 7);
- font size in Settings and as a pinch on the Prompt screen (decision 8);
- a compact Prompt layout for Screen mode, in portrait and landscape (decision 9);
- the route check and the take summary for a take with no voice (decision 10);
- unit tests, simulated takes with no voice, and the device check.

**Out:**
- the fixed-pace scroll for when listening is off (PRD §4.6, P1): its own issue, after this plan (decision 11). Flow 3 waits for it.
- mirror flip, an external display, a pedal or a remote (PRD §4.6: not wanted).
- Settings' voice group and the release (stage 7).
- the script text beyond the take's step: the engine follows one step, and so does the screen.

## Design decisions

1. **Ear off follows the presenter directly (Andy, 2026-11-08).** Andy chose this over a silent voice (the voice rendered and played muted) and over leaving Ear off out. A teleprompter shows the whole text, so a lead and phrase-end waits that nobody hears would only make the highlight run ahead and stop.

   `FollowSettings` gains `voiced: Bool`, default `true`, so every existing test and simulated take is unchanged. With `voiced == false`:
   - the start is as now: the slate and its reply or gap, then the tones; `tonesEnded` goes into following with the voice `.idle`, not `.waiting(0)`;
   - the engine sends no `.play`, `.setSpeed` or `.stopVoice` for phrases. The slate cue and the tones still play, so the camera has its sync point;
   - hearing, matching, the lost search, step backs and the presenter estimate work as now. The estimate is capped at the last spoken word, since there is no voice to cap it;
   - **Hold** freezes the place: what is heard is ignored and the text stays where it is. **Release** re-anchors at the presenter's confident word, as `.found` does;
   - **Back** and **Forward** move the place a phrase from the phrase the presenter is in, which is taken to be at the start of that phrase until they are heard again (as `move(by:)` does now, without `startPhrase`). Forward from the last phrase does nothing, as it does with a voice;
   - **completion** is the last spoken word heard, or the presenter in the last spoken phrase and not heard for `endGrace`, which is the voiced rule with the voice's end taken out;
   - the status while following is a new `FollowStatus.reading` in place of `.speaking` and `.waiting`; `.lost` and `.held` stay. The snapshot's `voicePhrase` and `voiceWord` are `nil`.

   This stays pure Swift in `Engine/`. Where the voiced and voiceless rules part, the code branches on `settings.voiced`. It is not a second engine.

2. **The reading line holds where the presenter is (Andy, 2026-11-08).** Andy chose this over the voice's position, which would keep about five words ahead of him and stay where the voice stopped while he is Lost. The reading line is a third of the way down the text, and the presenter's line sits there, with what is coming below it. The engine's place is `snapshot.presenterEstimate`, with its free coast (the snapshot's, not the gate's), so the text does not stop at each phrase end while the voice crosses it. The word shown is the estimate rounded down. Before anything is heard (an estimate of -1), the first line sits at the reading line.

3. **The scroll is smooth and continuous (Andy, 2026-11-08).** Andy chose a continuous scroll over moving a line at a time.
   - **Layout.** The step is laid out as one view per word in a wrapping layout (a SwiftUI `Layout`, `WordFlow`). The layout reports each word's line, its x across the line, and each line's y and height, as a plain `TextGeometry` value.
   - **Where the text should be.** The target is a y, not a word. Take the presenter's line's y, plus the fraction of the line before the estimate, times the line height. The fraction is worked out from the estimate's word and its fractional part, by the words' x positions. As the presenter reads along a line, the text rises continuously, and that line's middle is at the reading line when they are halfway through it.
   - **Smoothing.** The shown offset follows the target with a critically damped glide, time constant 0.6 s, stepped each frame from a `TimelineView(.animation)`. The estimate moves in bursts about a second apart on the phone (plan 006), and the glide turns a burst into an even movement, not a jump.
   - **Jumps.** A step back, Back, Forward, or found after Lost glides the same way, quicker (0.3 s) when the target is more than three lines away, so the text gets to the new place without a long slow scroll.
   - **The view.** The text is a clipped container offset by the shown value, not a `ScrollView`, so the offset can be set every frame without fighting a scroll view's own animation.
   - **Plain values.** The target and the glide are worked out by `ScreenScroll`, which is tested without views: given the geometry, the estimate, the time and the last offset, the next offset.
   - **Dragging by hand.** A drag moves the text, and the automatic scroll waits. It comes back with a glide three seconds after the drag ends, or at once on Back, Forward or Restart.
   - **Why a view per word.** A step is a few hundred words at most, so it is cheap, and it gives each word its own colour and position, which one long `Text` cannot.

4. **What the text shows.**
   - Each script line of the step starts a new paragraph (`StepPhrase.line`). Directions show in brackets, in the cue colour, never lit as spoken (PRD §4.6), in Screen mode as in Ear mode, and dropped when cues are off, as the take already drops them.
   - Words the presenter has passed (before the estimate) are dimmed (`secondaryText`). The rest are full `text`.
   - **The presenter's mark** is the word at the estimate, underlined in the accent colour: a mark, not a block, so it does not fight the voice's highlight.
   - **With Ear on, the voice's phrase is lit:** its words on a faint accent background (a new `EarwigTheme.voiceHighlight`), with the word the voice is saying in the accent colour, as in Ear mode. While the voice waits, the phrase it waits after stays lit, so the gap between the voice and the mark is the lead the presenter can see.
   - While **Lost**, the mark stays on the last confident word and the status shows Lost in the caution colour. While **Held**, the text stays still.
   - Before following (Getting ready, the slate, the tones), the text sits at the start, dimmed, with the status above it. A tap on the text during the slate starts the take, as the middle does in Ear mode.

   The text is built from the take's `PhraseList` and `FollowScript.firstWord` into `[ScreenWord]` (text, flat index or none, phrase, line, whether a cue) by `ScreenText`, a plain value tested without views. Its state per word (passed, mark, in the voice's phrase, the voice's word, cue) comes from the snapshot in `PromptViewModel`.

5. **Theme and type.**
   - The Prompt screen keeps the one sky-blue theme's background, as Ear mode does. PRD §4.6 asks for "dark background", which the theme's dark appearance already gives; Andy judges both appearances on the mount.
   - The type is the system font, semibold, left aligned, with a line spacing of 0.25 of the size so the reading line is easy to find.
   - Any colour added goes in `EarwigTheme`.

6. **Choosing Ear, Screen or both, before the take begins (Andy, 2026-11-08).** Andy chose a setting plus a choice made before the take. The take starts the moment the Prompt screen opens, so the choice is on the Script screen, beside Start.
   - **Settings** gets a Screen group (PRD §8.4): **Mode**, one of Ear (the default, as today), Screen and Ear and Screen, and **Text size** (decision 8). The mode is saved in `UserDefaults` as `TakeSettings.mode`.
   - **The Script screen**, on the start step's card above Start, has a three-way segmented control: Ear, Screen, Both. It shows the saved mode, and changing it saves the mode. So it is one value, chosen where the take is started and kept for the next shoot, and Settings shows the same value. The two cannot get out of step.
   - **During a take the mode is fixed.** There are no Ear or Screen toggles on the Prompt screen. **Next Take** keeps the take's mode. A new mode is chosen on the Script screen after Done.
   - The Prompt screen's top bar shows the take's mode as a small label (Ear, Screen, Ear and Screen), so a glance at the mount confirms it.

7. **Start with Ear off needs no rendering.**
   - When the mode is Screen, Start on the Script screen is enabled as soon as there is a start step. `startTake` then builds the take's `FollowScript` from the phrase list alone, with even timings (`FollowScript(phraseList:)`, which already exists).
   - `TakeSetup.audio` takes a `TakeAudio` with no phrases, only the tones. The slate is rendered while getting ready, as now: it is one short cue, and the camera's sync wants it.
   - With Ear on, Start still waits for the rendering, as now.
   - The rendering row on the Script screen still renders the start step when it is chosen, so switching to Ear later costs no wait.

8. **Font size.**
   - One saved value, `TakeSettings.textSize`, in points, 24 to 72, default 40, kept in `UserDefaults`.
   - In Settings it is a slider with a sample line at that size.
   - On the Prompt screen, a pinch on the text scales it live and saves the size when the pinch ends; the reading line keeps its word in place while the size changes.
   - The size is the same in portrait and landscape: landscape gives longer lines, not bigger type.

9. **The Prompt screen in Screen mode is compact.** The text gets most of the screen, and the controls stay where a hand can reach them at the mount:
   - **Top:** one row with the step number, the take number, the status as a small coloured word (Getting ready, Slate, Tones, Speaking or Reading, Waiting, Lost, Held), the take's mode, and the route icons, smaller than in Ear mode. The diagnostics line stays, in caption size under the row, while the follow engine is still being tuned.
   - **Bottom:** the five controls in one row of icon buttons, 56 pt high, labels for VoiceOver only. In landscape, where height is short (`verticalSizeClass == .compact`), the row moves to a column down the trailing edge.
   - **Finished** and **Can't start** replace the text with Ear mode's middle and its Next Take and Done, as now.
   - Ear mode's layout is unchanged.

10. **No voice, no earpiece warnings.**
    - In a take with Ear off, the earpiece icon is not judged: a speaker or no earpiece is fine, since nothing is played but the slate and the tones. The mic check stays as it is, since listening is what drives the text.
    - `TakeSummary` gains the mode (`ear`, `screen`, `ear+screen`). For a voiceless take it reports the presenter's waits as nothing, and the time Lost as now.

11. **The fixed-pace scroll is its own issue, after this plan (Andy, 2026-11-08).** It is P1, and the P0 parts are enough for one plan. The scroll is built so that something else can drive the word at the reading line: `PromptViewModel` takes the place from a `place` value, which a fixed pace can set later. An issue for it is drafted at the end of this plan, for Andy's yes.

## Files

| File | Purpose |
|------|---------|
| `Engine/FollowSettings.swift` | `voiced` (decision 1) |
| `Engine/FollowEvent.swift` | `FollowStatus.reading` |
| `Engine/FollowEngine.swift` | Following with no voice: tones into following, the cap, Hold, Back, Forward, completion (decision 1) |
| `Models/AppSettings.swift` | `TakeMode` (Ear, Screen, Ear and Screen), `TakeSettings.mode` and `textSize` (decisions 6, 8) |
| `App/EarwigTheme.swift` | `voiceHighlight`, the mark's colour if it needs its own |
| `Services/TakeHost.swift` | A setup with no phrase audio; the take's mode (decisions 6, 7) |
| `Services/TakeSummary.swift` | The mode on the summary line (decision 10) |
| `Services/ScreenText.swift` (new) | The step's words for the screen, from the phrase list (decision 4) |
| `ViewModels/PromptViewModel.swift` | Per-word state, the place, the compact status, the route check without a voice (decisions 2, 4, 9, 10) |
| `ViewModels/ScriptDetailViewModel.swift` | Start without rendering when the mode is Screen (decision 7) |
| `Views/Prompt/PromptView.swift` | Ear or Screen middle, the compact layout, the mode label (decision 9) |
| `Views/Prompt/ScreenTextView.swift` (new) | The scrolling text, `WordFlow`, the reading line, the pinch (decisions 3, 8) |
| `Views/Prompt/ScreenScroll.swift` (new) | The target offset and the glide, plain values (decision 3) |
| `Views/ScriptDetail/ScriptDetailView.swift` | The mode control beside Start; Start enabled without rendering in Screen mode (decisions 6, 7) |
| `Views/Settings/SettingsView.swift` | The Screen group (decisions 6, 8) |
| `EarwigTests/FollowEngineTests.swift`, `Simulation/FollowScenarioTests.swift`, `Simulation/TakeSimulation.swift` | Voiceless following (Step 1) |
| `EarwigTests/ScreenTextTests.swift` (new), `ScreenScrollTests.swift` (new), `PromptViewModelTests.swift`, `TakeHostTests.swift`, `AppSettingsTests.swift`, `ScriptDetailViewModelTests.swift`, `TakeSummaryTests.swift` | As Steps |
| `CLAUDE.md`, `PRD.md` | Status, the launch flag; §4.6, §4.8, §5, §8.3, §8.4, §12 as built |

## Steps

1. **The engine with no voice** (decision 1).
   - `voiced`, `.reading`, and the branches in `FollowEngine`.
   - `FollowEngineTests`:
     - the tones go into reading, with no `.play`;
     - heard words move the estimate, capped at the last word;
     - Hold ignores heard words, and Release re-anchors;
     - Back and Forward move the place, and Forward from the last phrase does nothing;
     - completion on the last word, and after `endGrace` in the last phrase;
     - Lost and found;
     - no phrase commands at any point.
   - The simulated takes gain a voiceless run: a clean read, a stop and resume, a fluff and step back, and a wander off script, at 2.5 and 4 words a second with 1 s bursts. Each asserts:
     - the estimate within two words of the presenter's true place for 95% of samples while reading;
     - completion;
     - Lost shown while off script.
   - Every existing test passes unchanged.
   - Committed on its own.
2. **Settings and the take's mode** (decisions 6, 7, 8, 10).
   - `TakeMode`, `mode` and `textSize` in `TakeSettings`, and the Screen group in Settings.
   - `startTake` without rendering for Screen.
   - The mode control on the start step's card.
   - The route check and the summary.
   - Tests:
     - `AppSettingsTests`: the defaults and the clamps;
     - `ScriptDetailViewModelTests`: Start with Screen and nothing rendered builds a voiceless setup, and with Ear it still needs the rendering;
     - `TakeHostTests`: a voiceless take from getting ready to completion, sending nothing to the voice channel, and Next Take keeping the mode;
     - `PromptViewModelTests`: the earpiece not judged without a voice;
     - `TakeSummaryTests`: the mode.
3. **The text** (decisions 2 to 5, 9).
   - `ScreenText`, the per-word state in `PromptViewModel`, `ScreenTextView` with `WordFlow` and the reading line, and the compact layout in portrait and landscape.
   - Tests:
     - `ScreenTextTests`: paragraphs by line, cues, numbers as one word, cues dropped when off;
     - `ScreenScrollTests`: the target through a line and across lines, the glide converging without overshoot, a burst becoming an even movement, a jump's quicker glide, and a drag pausing the follow for three seconds;
     - `PromptViewModelTests`: passed, the mark, the voice's phrase and word, Lost, Held, and the start before following.
   - A Debug launch flag, `-EarwigScreen YES`, opens a demo take in Screen mode with `-EarwigNoListen`, so the simulator can show the layout.
   - Screenshots in the simulator, portrait and landscape, light and dark, at 24, 40 and 72 pt, for Andy before the device check.
4. **The pinch** (decision 8): live scaling with the reading word held in place, saved at the end of the pinch.
5. **Review.** `/review-branch`, with its findings fixed or recorded.
6. **Device check** on the iPhone 14 Pro, one check at a time (Verification). Results come from Andy's verdicts and the console.
7. **Finish.**
   - `swiftlint lint` clean, no build warnings, all tests pass.
   - Results filled in.
   - PRD as v0.10 with a Document History row: §4.6, §4.8, §5 (following with no voice), §8.3, §8.4, and §12 stage 6 done.
   - CLAUDE.md: the status and the flag.
   - The fixed-pace issue drafted for Andy's yes.
   - `progress.md` emptied to its stub.

## Verification

- `xcodebuild test` passes in the simulator; no warnings; SwiftLint clean.
- On the iPhone 14 Pro, installed with `devicectl` and the console read live, one at a time, with the sample script (made up, so it can be quoted here). Lead 5, hybrid, tones only, voice speed 0.95x (the defaults):
  1. **Screen only, on the mount.** Mode Screen, no earpiece. Start without waiting for a render. Read a step at your own pace. The text keeps your line at the reading line, and the take completes at the end. Andy's verdict on whether he could keep his place at a glance, and whether the scroll feels smooth and steady to read from (decision 3); from the console, the summary.
  2. **Screen only, off and back.** Stop mid-sentence and say something else, then go back a sentence and read on. Lost shows while you are off; the text steps back with you. Then Back, Forward and Hold, Release. Andy's verdict.
  3. **Ear and Screen, on the mount (Flow 2).** With the SK18. The voice leads, its phrase is lit ahead of your mark, and the text stays at your place. Andy's verdict on whether the lit phrase helps or distracts, and on the reading line's height.
  4. **Choosing the mode.** On the Script screen, switch the control beside Start between Ear, Screen and Both, and start a take in each. The Prompt screen shows the chosen mode, Settings shows the same value, and Next Take keeps it.
  5. **Size and orientation.** Pinch the text larger and smaller during a take; landscape on the mount; the size from Settings at the next take. Andy's verdict on the default size at the mount's distance, and on the light and dark appearances.
  6. **Ear only, unchanged.** A take in Ear mode, to confirm nothing changed: no new waits against plan 006's clean read.

## Results

*To be filled in at the device check.*
