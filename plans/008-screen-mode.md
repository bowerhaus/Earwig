# Plan 008: Screen Mode

**GitHub Issue:** to be created (`/plan_create_issue`); the PR must include "Closes #N".
**Branch:** `screen-mode` (from `main` at `ed33225`, after plan 007 merged)
**Status:** Planned (2026-11-08).
**Manual test:** device, on Andy's iPhone 14 Pro, on the mount and in the hand, with and without the SK18 (Verification).
**Goal:** Stage 6 of PRD §12. The take's step appears on the Prompt screen as large scrolling text, kept at the presenter's place by the same engine that follows them in Ear mode. Ear and Screen can run together (Flow 2, the desk head on the mount), and either can be switched off. With Ear off, the text follows the presenter directly: there is no voice and no rendering, so a take starts as soon as Start is tapped. Font size is a setting and a pinch.

**PRD references:** §4.4 Following, §4.6 Screen mode, §4.8 Settings, §5.4 Pacing (the presenter estimate), §5.5 Start, §8.3 Prompt, §8.4 Settings, §9 Flows 2 and 3, §10 Design Language, §12 stage 6.

---

## Scope

**In:**
- a voiceless way of following in the engine, for Ear off (decision 1);
- the scrolling text on the Prompt screen, with the presenter's place at a reading line, the voice's phrase lit when Ear is on, and directions in the cue colour (decisions 2 to 5);
- three modes, Ear, Screen and Ear and Screen, in Settings, plus Ear and Screen toggles on the Prompt screen during a take (decision 6);
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

3. **The scroll moves a line at a time, animated.** The step is laid out as one view per word in a wrapping layout (a SwiftUI `Layout`, `WordFlow`), each word with its flat index as its id. The text is kept in place with `ScrollViewReader.scrollTo(word, anchor: readingLine)`. Words on one line share a y, so moving along a line does not scroll. Reaching the next line scrolls one line, eased over 0.35 s. A jump (a step back, Back, Forward, found after Lost) scrolls the same way, over a longer distance.
   - The other way was a continuous scroll, a fraction of a line per word. It looks smoother in a demo, but it moves the line being read, and the estimate moves in bursts, about a second apart on the phone (plan 006). If line steps feel jumpy on the device, the continuous scroll is the change, recorded in Results.
   - A step is a few hundred words at most, so a view per word is cheap. A per-word layout also gives each word its own colour and lets the scroll target a word, which one long `Text` cannot.
   - While the presenter is dragging the text by hand, the automatic scroll waits. It comes back three seconds after the drag ends, or at once on Back, Forward or Restart.

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

6. **Choosing Ear, Screen or both (Andy, 2026-11-08).** Andy chose a setting plus toggles in the take, over Settings only or a choice on the Script screen.
   - **Settings** gets a Screen group (PRD §8.4): **Mode**, one of Ear (the default, as today), Screen and Ear and Screen, and **Text size** (decision 8). The mode is saved in `UserDefaults` as `TakeSettings.mode`.
   - **The Prompt screen** has two small toggles in its top bar, **Ear** and **Screen**, set from the mode when the take opens. A take starts the moment the Prompt screen opens, so the toggles act on the take that is running:
     - **Screen** switches between the scrolling text and Ear mode's status and phrase, at any time. Only the view changes.
     - **Ear** mutes and unmutes the voice and the cue voice (not the tones) in a take that started with Ear on. The engine runs voiced underneath, so the lead and the waits carry on and unmuting picks up where the voice is. The player gets a `muted` flag on its voice and cue channels, which the engine never sees.
     - In a take that started with Ear off, the Ear toggle is shown off and disabled: there is no rendering to play, and the take would need one. Its accessibility hint says so.
     - At least one of the two stays on: turning off the only one that is on does nothing.
   - **Next Take** keeps the toggles as they are; **Done** forgets them, and the next take opens from the setting again. The toggles never change the setting.

   This is a reading of Andy's choice: the toggles change the take after it starts, because no "before Start" exists on the Prompt screen. If he wanted the choice before the take begins, it moves to the Start button's row on the Script screen, recorded in Results.

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
   - **Top:** one row with the step number, the take number, the status as a small coloured word (Getting ready, Slate, Tones, Speaking or Reading, Waiting, Lost, Held), the Ear and Screen toggles, and the route icons, smaller than in Ear mode. The diagnostics line stays, in caption size under the row, while the follow engine is still being tuned.
   - **Bottom:** the five controls in one row of icon buttons, 56 pt high, labels for VoiceOver only. In landscape, where height is short (`verticalSizeClass == .compact`), the row moves to a column down the trailing edge.
   - **Finished** and **Can't start** replace the text with Ear mode's middle and its Next Take and Done, as now.
   - Ear mode's layout is unchanged.

10. **No voice, no earpiece warnings.**
    - In a take with Ear off, or with Ear muted, the earpiece icon is not judged: a speaker or no earpiece is fine, since nothing is played but the slate and the tones. The mic check stays as it is, since listening is what drives the text.
    - `TakeSummary` gains the mode (`ear`, `screen`, `ear+screen`, `screen (ear muted)`). For a voiceless take it reports the presenter's waits as nothing, and the time Lost as now.

11. **The fixed-pace scroll is its own issue, after this plan (Andy, 2026-11-08).** It is P1, and the P0 parts are enough for one plan. The scroll is built so that something else can drive the word at the reading line: `PromptViewModel` takes the place from a `place` value, which a fixed pace can set later. An issue for it is drafted at the end of this plan, for Andy's yes.

## Files

| File | Purpose |
|------|---------|
| `Engine/FollowSettings.swift` | `voiced` (decision 1) |
| `Engine/FollowEvent.swift` | `FollowStatus.reading` |
| `Engine/FollowEngine.swift` | Following with no voice: tones into following, the cap, Hold, Back, Forward, completion (decision 1) |
| `Models/AppSettings.swift` | `TakeMode` (Ear, Screen, Ear and Screen), `TakeSettings.mode` and `textSize` (decisions 6, 8) |
| `App/EarwigTheme.swift` | `voiceHighlight`, the mark's colour if it needs its own |
| `Services/Player.swift`, `Services/AudioEngineHost.swift` | `muted` on the voice and cue channels (decision 6) |
| `Services/TakeHost.swift` | The take's toggles; Ear muted through the player; a setup with no phrase audio (decisions 6, 7) |
| `Services/TakeSummary.swift` | The mode on the summary line (decision 10) |
| `Services/ScreenText.swift` (new) | The step's words for the screen, from the phrase list (decision 4) |
| `ViewModels/PromptViewModel.swift` | Per-word state, the place, the compact status, the route check without a voice (decisions 2, 4, 9, 10) |
| `ViewModels/ScriptDetailViewModel.swift` | Start without rendering when the mode is Screen (decision 7) |
| `Views/Prompt/PromptView.swift` | Ear or Screen middle, the compact layout, the toggles (decision 9) |
| `Views/Prompt/ScreenTextView.swift` (new) | The scrolling text, `WordFlow`, the reading line, the pinch (decisions 3, 8) |
| `Views/ScriptDetail/ScriptDetailView.swift` | Start enabled without rendering in Screen mode |
| `Views/Settings/SettingsView.swift` | The Screen group (decisions 6, 8) |
| `EarwigTests/FollowEngineTests.swift`, `Simulation/FollowScenarioTests.swift`, `Simulation/TakeSimulation.swift` | Voiceless following (Step 1) |
| `EarwigTests/ScreenTextTests.swift` (new), `PromptViewModelTests.swift`, `TakeHostTests.swift`, `AppSettingsTests.swift`, `ScriptDetailViewModelTests.swift`, `TakeSummaryTests.swift`, `PlayerTests.swift` | As Steps |
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
   - The player's `muted`.
   - The toggles in `TakeHost`.
   - The route check and the summary.
   - Tests:
     - `AppSettingsTests`: the defaults and the clamps;
     - `ScriptDetailViewModelTests`: Start with Screen and nothing rendered builds a voiceless setup, and with Ear it still needs the rendering;
     - `PlayerTests`: muted channels play silently and still report progress;
     - `TakeHostTests`: the toggles, muting a voiced take, the Ear toggle disabled in a voiceless one, at least one on;
     - `PromptViewModelTests`: the earpiece not judged without a voice;
     - `TakeSummaryTests`: the mode.
3. **The text** (decisions 2 to 5, 9).
   - `ScreenText`, the per-word state in `PromptViewModel`, `ScreenTextView` with `WordFlow` and the reading line, and the compact layout in portrait and landscape.
   - Tests:
     - `ScreenTextTests`: paragraphs by line, cues, numbers as one word, cues dropped when off;
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
  1. **Screen only, on the mount.** Mode Screen, no earpiece. Start without waiting for a render. Read a step at your own pace. The text keeps your line at the reading line, and the take completes at the end. Andy's verdict on whether he could keep his place at a glance, and whether the line steps feel jumpy (decision 3); from the console, the summary.
  2. **Screen only, off and back.** Stop mid-sentence and say something else, then go back a sentence and read on. Lost shows while you are off; the text steps back with you. Then Back, Forward and Hold, Release. Andy's verdict.
  3. **Ear and Screen, on the mount (Flow 2).** With the SK18. The voice leads, its phrase is lit ahead of your mark, and the text stays at your place. Andy's verdict on whether the lit phrase helps or distracts, and on the reading line's height.
  4. **The toggles.** In an Ear and Screen take: Screen off and on, Ear off (silence, the text carries on) and on (the voice picks up where it is). In a Screen-only take, Ear is disabled.
  5. **Size and orientation.** Pinch the text larger and smaller during a take; landscape on the mount; the size from Settings at the next take. Andy's verdict on the default size at the mount's distance, and on the light and dark appearances.
  6. **Ear only, unchanged.** A take in Ear mode, to confirm nothing changed: no new waits against plan 006's clean read.

## Results

*To be filled in at the device check.*
