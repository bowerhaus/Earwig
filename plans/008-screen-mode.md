# Plan 008: Screen Mode

**GitHub Issue:** [#25](https://github.com/bowerhaus/Earwig/issues/25) (PR must include "Closes #25")
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

2. **The reading line holds where the presenter is (Andy, 2026-11-08).** Andy chose this over the voice's position, which would keep about five words ahead of him and stay where the voice stopped while he is Lost. The reading line is a third of the way down the text, and the presenter's line sits there, with what is coming below it. The engine's place for the screen is `snapshot.presenterPlace`: the estimate with the gate's rule from plan 006, so it does not coast across a phrase end until a word of the next phrase is heard. The free coast was planned first, so the text would not stop at each phrase end. On the phone, a pause at a phrase end then left the mark on the second word of the next phrase, since the screen's place never moves back (device check 1). The word shown is the estimate rounded down. Before anything is heard (an estimate of -1), the first line sits at the reading line.

3. **The scroll is smooth and continuous (Andy, 2026-11-08).** Andy chose a continuous scroll over moving a line at a time.
   - **Layout.** The step is laid out as one view per word in a wrapping layout (a SwiftUI `Layout`, `WordFlow`). The layout reports each word's line, its x across the line, and each line's y and height, as a plain `TextGeometry` value.
   - **Where the text should be.** The target is a y, not a word. Take the presenter's line's y, plus the fraction of the line before the estimate, times the line height. The fraction is worked out from the estimate's word and its fractional part, by the words' x positions. As the presenter reads along a line, the text rises continuously, and that line's middle is at the reading line when they are halfway through it.
   - **Smoothing, in words.** The shown place is smoothed in script words by `ScreenPlace`, then turned into a y by `ScreenLayout` every frame from a `TimelineView(.animation)`. The estimate moves in bursts about a second apart on the phone (plan 006): four words at once, a half-second coast, then still. A plain glide on the y (as first planned, time constant 0.6 s) would lag a steady reader by about 2.4 words at 4 words a second. So `ScreenPlace` is a critically damped second-order tracker (2.5 rad/s), with a speed as well as a place. While the presenter reads steadily it moves at their pace with no lag, and turns each burst into an even movement.
     - It never runs on more than half a word past the estimate, so it stops when the presenter pauses.
     - It never moves back for a fall in the estimate. The estimate falls a few words whenever a final settles a block, because it stops counting the recogniser's delay. Followed, that slipped the text back at every phrase end in the simulated takes.
     - It moves back only when the confident word does, by more than two words: a step back, Back, Restart, or found behind after Lost.
     - It glides forward on a jump of more than six words (Forward, found ahead), with time constant 0.3 s, and never turns back during that glide.
   - **Measured** in the simulated takes (`ScreenPlaceScenarioTests`), against the last word the presenter began. At 2.5 words a second, 86–90% of samples are within two words and 96–99% within three. At 4 words a second in bursts, 69–89% are within two and 88–100% within three, against 60–70% and 80–85% for the raw estimate. Through a clean read, a stop and a fluff, the text never moves back.
   - **The view.** The text is a clipped container offset by the shown value, not a `ScrollView`, so the offset can be set every frame without fighting a scroll view's own animation.
   - **Plain values.** `ScreenPlace` (the smoothing) and `ScreenLayout` (the word frames and the y of a place) are tested without views.
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
   - The Prompt screen keeps the one sky-blue theme's background, as Ear mode does. The app has one appearance, whatever the phone's setting (plan 002), so PRD §4.6's "dark background" is read as the theme's ground. Andy judges it on the mount.
   - The voice's phrase is lit on the cards' mid-blue at 70%. A faint accent was tried first and looked green on the sky blue.
   - The type is the system font, semibold, left aligned, with a line spacing of 0.25 of the size so the reading line is easy to find.
   - Any colour added goes in `EarwigTheme`.

6. **Choosing Ear, Screen or both, before the take begins (Andy, 2026-11-08).** Andy chose a setting plus a choice made before the take. The take starts the moment the Prompt screen opens, so the choice is on the Script screen, beside Start.
   - **Settings** gets a Screen group (PRD §8.4): **Mode**, one of Ear (the default, as today), Screen and Ear and Screen, and **Text size** (decision 8). The mode is saved in `UserDefaults` as `TakeSettings.mode`.
   - **The Script screen** has a three-way segmented control, Ear, Screen and Both, in the rendering row at the top, above Listen and Start Take. The start step's card keeps its small Start, which uses the same mode. Built there, not on the card, so it sits by the main Start, which Screen mode shows before anything is rendered. It shows the saved mode, and changing it saves the mode. So it is one value, chosen where the take is started and kept for the next shoot, and Settings shows the same value. The two cannot get out of step.
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
   - On the Prompt screen, a pinch on the text scales it live, saving the size as it changes. The place stays at the reading line while the size changes, since the y is worked out from the place every frame.
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
| `ViewModels/ScreenPlace.swift`, `ViewModels/ScreenLayout.swift` (new) | The smoothed place, and the y of a place from the word frames, plain values (decision 3) |
| `Views/ScriptDetail/ScriptDetailView.swift` | The mode control beside Start; Start enabled without rendering in Screen mode (decisions 6, 7) |
| `Views/Settings/SettingsView.swift` | The Screen group (decisions 6, 8) |
| `EarwigTests/FollowEngineTests.swift`, `Simulation/FollowScenarioTests.swift`, `Simulation/TakeSimulation.swift` | Voiceless following (Step 1) |
| `EarwigTests/ScreenTextTests.swift` (new), `ScreenPlaceTests.swift`, `ScreenLayoutTests.swift`, `Simulation/ScreenPlaceScenarioTests.swift` (new), `PromptViewModelTests.swift`, `TakeHostTests.swift`, `AppSettingsTests.swift`, `ScriptDetailViewModelTests.swift`, `TakeSummaryTests.swift` | As Steps |
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
     - the estimate near the presenter's place, pinned at what was measured (review C6): within two words for 87% of samples at 2.5 words a second and 55% at 4 in bursts, within three for 97% and 77%. The 95% first asked for was not reachable from the raw estimate at the phone's pace, where each burst moves it four words. What the screen shows is the smoothed place (decision 3), measured and pinned in `ScreenPlaceScenarioTests`;
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
     - `ScreenPlaceTests`: a steady read with no lag, bursts becoming an even movement, a pause, a fall in the estimate not moving it back, a step back and a jump forward gliding;
     - `ScreenLayoutTests`: the y through a row, across rows and a paragraph gap, before the first word and past the last;
     - `ScreenPlaceScenarioTests`: the smoothed place through simulated takes, with and without a voice, at both paces;
     - `PromptViewModelTests`: passed, the mark, the voice's phrase and word, Lost, Held, and the start before following.
   - Debug launch flags: `-EarwigScreen YES` opens a demo take in Screen mode, and `-EarwigReads YES` makes a take hear the step read at 2.5 words a second, so the simulator shows the text following.
   - Screenshots in the simulator, portrait and landscape, Screen and Ear and Screen, for Andy before the device check.
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
  5. **Size and orientation.** Pinch the text larger and smaller during a take; landscape on the mount; the size from Settings at the next take. Andy's verdict on the default size at the mount's distance, and on the sky blue as the ground.
  6. **Ear only, unchanged.** A take in Ear mode, to confirm nothing changed: no new waits against plan 006's clean read.

## Results

*To be filled in at the device check.*

## Review pass — 2026-11-08

Findings from `/review-branch` on branch `screen-mode`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact, and each verdict under *Assessment* is a
recommendation, not a decision. Work through them and annotate each with what was done — fixed,
or rejected and why. A finding that turns out to be wrong should say so here rather than be
deleted.

### Code

Review of branch `screen-mode` against `main`, judged on plan 008's Goal, Scope, Design decisions and Verification. All changes are committed. There are no unstaged, staged or untracked files. I did not run the build or the tests.

Overall the branch matches the plan:
- **Engine:** `voiced` is a branch in `FollowEngine`, not a second engine.
- **Prompt screen:** `.reading` status, the compact layout in portrait and landscape, and the mode label.
- **Starting a take:** Start works without rendering in Screen mode, and Next Take keeps the take's mode.
- **Settings:** the Screen group with Mode and Text size, and the pinch.
- **Route check and summary:** the earpiece is not judged in a take with no voice, and the summary line gives the mode.

Engine purity, all colours in `EarwigTheme`, and UK spelling are respected. `project.yml` picks new files up from the folders, so no project change is needed. I found no build-breaking changes.

**C1 — WARNING: Hold does not freeze the text in Ear and Screen.**
- Decision 4 says "While Held, the text stays still", and the plan does not limit that to Screen alone. But the held place is only kept with no voice (`if !settings.voiced { heldPlace = presenterNow() }`).
- With a voice, `snapshot.presenterEstimate` keeps changing while held:
  - matching carries on (`afterHearing` only skips re-anchoring);
  - the voice's `voiceStartedAt` is not cleared;
  - `PresenterEstimate.position` keeps creeping toward the start of the held phrase (lines 97–100), up to the cap `firstWord[p] - 1`.
- `PromptViewModel.place` feeds this estimate straight into the scroll and the mark, so in Both mode the text and the underline keep moving during Hold.
- Fix: set `heldPlace` whatever `voiced` is. It only changes the snapshot; the pacer and the gates use `presenterNow()` directly and are skipped while held.
- Files: `/Users/andybower/Projects/Earwig/Earwig/Engine/FollowEngine.swift:479-481` (and 171), `/Users/andybower/Projects/Earwig/Earwig/ViewModels/PromptViewModel.swift:171`.

**C2 — SUGGESTION: the scroll can miss Back and Restart when the confident word falls by two words or fewer.**
- `ScreenPlace` only moves back when the confident word falls by more than `backJump` (2). Decision 3 says it moves back on Back and Restart.
- Cases that miss it:
  - Voiceless Back from the start of a phrase into a one- or two-word phrase.
  - Voiced Back, which sets the confident word from the voice's phrase (ahead of the presenter), so it can land within two words of where the presenter is, or even ahead.
- In both cases the text stays where it was while the estimate falls back.
- The view already counts `moves` on Back, Forward and Restart (`PromptView.move`), but only uses it to cancel a drag. Passing that signal into `ScreenPlace` to force a glide would make it reliable.
- File: `/Users/andybower/Projects/Earwig/Earwig/ViewModels/ScreenPlace.swift:56`.

**C3 — SUGGESTION: the take's mode is stored twice in `TakeSetup`.**
- `TakeSetup` has both `mode` and `settings.voiced`, and each is set on its own (`ScriptDetailViewModel.startTake` sets both; `TakeHostTests` sets both by hand and empties `audio.phrases`).
- If they ever disagree, `TakeHost.deviceLost` and the route check (which use `mode`) would act differently from the engine (which uses `voiced`).
- Deriving one from the other, for example `settings.voiced` from `mode` when the setup is built, would remove that risk.
- Files: `/Users/andybower/Projects/Earwig/Earwig/Services/TakeHost.swift:87`, `/Users/andybower/Projects/Earwig/Earwig/ViewModels/ScriptDetailViewModel.swift:117-120`.

**C4 — SUGGESTION: a word wider than the column is clipped.**
- `WordFlow` sizes each word at its natural width and never breaks or scales it.
- At the top text size (72 pt) on an iPhone 14 Pro in portrait (about 353 pt of column), or in landscape's narrower column beside the controls, a long word runs past the clipped edge.
- Fix: limit the width offered to each word to the column width (and let it scale down), or lower the top of `textSizeRange`.
- File: `/Users/andybower/Projects/Earwig/Earwig/Views/Prompt/ScreenTextView.swift:224`.

**C5 — SUGGESTION: the summary's mode names repeat `TakeMode`'s.**
- `TakeSummary.line` has its own `switch` from `TakeMode` to `ear` / `screen` / `ear+screen`, beside `TakeMode`'s existing `label` and `title`.
- A `logName` (or similar) on `TakeMode` would keep the names in one place.
- File: `/Users/andybower/Projects/Earwig/Earwig/Services/TakeSummary.swift:91-95`.

**C6 — SUGGESTION: the plan and the simulated-take thresholds disagree.**
- Plan step 1 asks the voiceless runs to keep the estimate within two words for 95% of samples while reading.
- `FollowReadingScenarioTests` sets that pass mark at the measured results instead: 87% at 2.5 words a second, and 55% at 4 words a second in bursts.
- The thresholds are recorded as measured in `progress.md` and in the test's doc comment, but the plan still says 95%. It should be reconciled in the plan's Results (or decision 3) so the plan matches what was accepted.
- The new `-EarwigScreen` and `-EarwigReads` launch flags also still need adding to CLAUDE.md, which is planned for the Finish step.
- File: `/Users/andybower/Projects/Earwig/EarwigTests/Simulation/FollowReadingScenarioTests.swift:27-30`.

### Tests

Test review of branch screen-mode against main. I read the committed test diff and every new suite in full. There are no unstaged, staged or untracked test changes. Overall the coverage is good: the engine running with no voice, ScreenText, ScreenLayout, ScreenPlace, the Screen-mode paths in PromptViewModel, TakeHost (no voice, earpiece put away), ScriptDetailViewModel (start without rendering, Next Take keeping the mode), TakeSummary and AppSettings are all tested. My findings:

T1. WARNING: Tests that call `startTake` without a mode now depend on the app's real stored setting.
`startTake` now reads `AppSettings.take.mode` from `UserDefaults.standard`, which the test host shares with the app in the simulator. If the author picks Screen in Settings or beside Start, then runs the tests in the same simulator:
- `withCuesOffATakeHasNoCuePhrases` fails, because its audio phrases are empty and its count check (`setup.audio.phrases.count == setup.phraseList.phrases.count`) breaks.
- `startOpensATakeNumberedAfterTheStepsLast` silently runs as a Screen take.
- The Next Take check in `onTheScreenAloneATakeStartsWithNothingRendered` claims "whatever the setting" but never sets the setting. It only proves the mode was kept if the stored setting happens to be Ear.

Fix: pass `mode: .ear` explicitly in those existing calls, and in the Next Take test set the stored mode to `.ear` first (or inject `TakeSettings`).
File: /Users/andybower/Projects/Earwig/EarwigTests/ScriptDetailViewModelTests.swift, lines 52, 79-81, 106-108.

T2. SUGGESTION: The drag-and-resume logic in `ScreenFollower` is untested.
It holds a hand drag, fades it out `dragHold` seconds after the drag ends, and Back, Forward and Restart cancel the hold through `resume()`. This is real behaviour the presenter relies on, it is plain logic with time passed in, and it currently lives in a view file. Moving it beside `ScreenPlace` and adding one or two tests would cover it: a drag holds, the hold then fades away, and `resume()` follows again at once.
File: /Users/andybower/Projects/Earwig/Earwig/Views/Prompt/ScreenTextView.swift, lines 88-122.

T3. SUGGESTION: The two scenario suites duplicate each other's helpers and some of each other's runs.
Each defines its own `Pace` struct, `run`, `share` and a "from the fifth word on" filter. The voiceless rows of `ScreenPlaceScenarioTests` also run the same three takes (same acts, settings and paces) as `FollowReadingScenarioTests`, measuring only a different series. `TakeSimulation` already records both `placeErrors` and `screenErrors` in one run. Shared helpers in a `TakeSimulation` extension, plus asserting both measures on the same voiceless runs, would remove about 6 duplicate simulated takes with no loss of coverage.
Files: /Users/andybower/Projects/Earwig/EarwigTests/Simulation/FollowReadingScenarioTests.swift (lines 26-57) and /Users/andybower/Projects/Earwig/EarwigTests/Simulation/ScreenPlaceScenarioTests.swift (lines 30-52, 66-79).

T4. SUGGESTION: `TakeSimulation.measure()` repeats the same reading guard twice.
The `screenErrors` and `placeErrors` blocks each check `presenter.position >= 0, let last = presenter.spoken.last, last.word.script != nil, time - last.end < 0.7`. Computing it once as a local `isReading` would make the two series easier to compare.
File: /Users/andybower/Projects/Earwig/EarwigTests/Simulation/TakeSimulation.swift, lines 352-358.

T5. SUGGESTION: One assertion in `aPauseStopsItHalfAWordPastTheEstimate` checks almost nothing.
`#expect(place.speed == 0 || place.place < 6.5)` can only fail when the place is exactly 6.5 with a non-zero speed, and the first expectation already bounds the place at 6.5 or below. The behaviour the test is named for is that the place stops, so `#expect(place.speed == 0)` (possibly after a few more steps) would test it.
File: /Users/andybower/Projects/Earwig/EarwigTests/ScreenPlaceTests.swift, line 59.

T6. SUGGESTION: `aWholeReadSendsNoPhraseCommands` overlaps with the scenario suite.
`FollowReadingScenarioTests.aCleanReadIsFollowed` already checks that a clean voiceless read completes and that the voice never plays (`neverPlays`) at two paces. The unit test adds little beyond that and could go. Even after removing it, the other 13 tests in the file each cover a distinct branch.
File: /Users/andybower/Projects/Earwig/EarwigTests/FollowEngineReadingTests.swift, line 180.

T7. SUGGESTION: Back or Forward pressed during Hold, with no voice, is not tested.
`moveReading` clears `held` and `heldPlace`, so a move releases the hold and moves the place, but no test exercises that combination. One extra step in `holdKeepsThePlaceAndReleaseGoesToWhereThePresenterIs` (or in the Back/Forward test) would cover it.
Files: /Users/andybower/Projects/Earwig/EarwigTests/FollowEngineReadingTests.swift, lines 104-130; source /Users/andybower/Projects/Earwig/Earwig/Engine/FollowEngine.swift, `moveReading`.

T8. SUGGESTION: Two small tidy-ups in `ScreenLayoutTests`.
- `theWordsAreAsExpected` re-tests `ScreenText` output that `ScreenTextTests` already covers. As a fixture sanity check it could be dropped or folded into one of the layout tests.
- The `words` fixture builds the same `PhraseList` twice. Building it once would make the fixture easier to read.
File: /Users/andybower/Projects/Earwig/EarwigTests/ScreenLayoutTests.swift, lines 10-24.

### Assessment

- C1 — FIX: real; `heldPlace` is set only when voiceless (`FollowEngine.swift:481`), so in Ear and Screen the estimate the scroll follows creeps during Hold. Set it in both; only the snapshot reads it.
- C2 — FIX: real; Back into a one-word phrase ("Morning!") or a voiced Back near the presenter drops the confident word by two or fewer, which `ScreenPlace` ignores. Back, Forward and Restart force a glide through the follower's `resume()`.
- C3 — FIX: real duplication; `TakeHost` builds the engine from `setup.settings` with `voiced` taken from `setup.mode`, so the two cannot disagree; `followSettings` loses its `for:` parameter.
- C4 — FIX: real at 72 pt ("breakfast." is near the column's width); a word is offered at most the column's width and scales down to fit.
- C5 — FIX: cheap; `TakeMode.logName`.
- C6 — FIX (part): reconcile the plan's 95% with the pinned, measured thresholds in Step 1's text; the CLAUDE.md flags are already in Finish.
- T1 — FIX: real; pass `mode: .ear` in the two existing `startTake` calls, and set the stored mode to Ear around the Next Take check, restoring it after.
- T2 — FIX: move `ScreenFollower` beside `ScreenPlace` (no SwiftUI needed) with time passed in, and test that a drag holds then fades and that `resume()` follows again at once and forces a glide (with C2).
- T3 — SKIP: the simulated takes are cheap (under a second together) and each suite reads as its own measure with its own documented numbers; merging couples them for little gain.
- T4 — FIX: trivial; one `isReading` local.
- T5 — FIX: assert the speed is 0 once the place has stopped.
- T6 — SKIP: it pins at the engine's own level that no `.stopVoice` or `.setSpeed` is ever sent, which the scenario's `neverPlays` does not check (it sees plays and speeds only).
- T7 — FIX: one step: Forward during Hold releases it and moves the place.
- T8 — FIX: build the fixture's phrase list once and drop `theWordsAreAsExpected`, folding its check of the word indices into a layout test.

### Outcome — 2026-11-08

- C1 — fixed: the held place is kept with a voice too (`FollowEngine.toggleHold`); `whileHeldThePlaceShownStaysStill` pins it.
- C2 — fixed: `ScreenPlace.move()` forces a glide either way; the follower's `moved()` calls it on Back, Forward and Restart; `aMoveAskedForGlidesHoweverNear`.
- C3 — fixed: `TakeSetup.engineSettings` takes `voiced` from the mode, and `TakeHost` builds the engine from it; `followSettings` has no mode parameter.
- C4 — fixed: a word wider than the column is offered the column and scales down (`WordFlow`, `WordView`). Checked at the device check.
- C5 — fixed: `TakeMode.logName`.
- C6 — fixed (part): Step 1's 95% now records the pinned, measured thresholds; the CLAUDE.md flags are written at Finish.
- T1 — fixed: the two existing `startTake` calls pass `.ear`, and the Next Take check sets the stored mode to Ear and restores it.
- T2 — fixed: `ScreenFollower` is in `ViewModels/ScreenFollower.swift` with time passed in; `ScreenFollowerTests` covers a drag holding then fading and a move following at once.
- T3 — not done: the simulated takes are cheap and each suite is its own measure with its own numbers.
- T4 — fixed: one `reading` local in `TakeSimulation.measure()`.
- T5 — fixed: the pause test checks the speed is 0 and the place stays put.
- T6 — not done: the unit test pins that no `.stopVoice` or `.setSpeed` is sent, which the scenario does not see.
- T7 — fixed: Forward during Hold releases it and moves the place.
- T8 — fixed: the fixture's phrase list is built once and `theWordsAreAsExpected` folded into a layout test.

## Device check (iPhone 14 Pro), 2026-11-08

1. **Screen only, on the mount.** Two takes of step 1 with no earpiece, both started without a render and both completed: 28.9 s and 49.1 s, all 70 words heard, delay 0.80 s and 0.93 s, rate 4.0 words a second (the console). Andy: the scroll was "smooth and steady", he could keep his place at a glance, and it was steady enough to read from. Two things looked odd. The reading-line tick in the left margin was unclear. The yellow underline jumped backwards and forwards, because it followed the engine's raw estimate while the scroll followed the smoothed place. Changed: the underline and the dimming now follow the smoothed place, as the scroll does, and the tick is gone. Andy then asked why the place is an underline rather than a block (decision 4).

   Then, Andy: pausing at a phrase end, the first word underlined was the second word of the next phrase. Simulated, the screen's place sat 1.5 to 3.8 words past the phrase end through the pause. The estimate's free coast ran on past the end, and the screen's place, which never moves back, stayed there when the final pulled the estimate back. Changed: the screen follows `presenterPlace`, which keeps the gate's rule and stops at the next phrase's first word until a word of it is heard. Simulated, through the pause the place now sits at the phrase's last word or the next phrase's first; `aPauseAtAPhraseEndWaitsAtTheNextPhrasesStart` pins it.

   Then, on the next take, Andy reported four things.
   - **The mark still ran ahead.** He said "the plan is simple" and the underline was on "up the cliff path". "The plan is simple: along the sea wall, up the cliff path," is one phrase, so the phrase-end rule did not apply at the colon. When "simple" arrived, about 0.9 s late, the estimate assumed he had carried on at his measured 4 words a second. Changed: the screen's place also stops at punctuation, the next comma, colon, full stop or dash, until a word beyond it is heard (`FollowScript.pausesAfter`). Simulated, the mark waits at "along" through that pause. Reading straight on, the place is closer than before: on average 0.4 to 0.6 words behind instead of about a word ahead, and within three words 97–98% of the time at the phone's pace. `aPauseAtAColonMidPhraseWaitsAtTheNextWord` pins it.
   - **The start was slow.** The tones ended at 16.02 and the recogniser's first word came at 18.29, which is the recogniser's own delay. The engine then waited for a second word, at 19.11. Changed: with no voice, the take's first word is trusted on its own (with a voice the first gate still waits for two), and the mark sits on the first word from the tones on.
   - **The modes (decision 6 changed, Andy's call).** He asked whether to drop Both, then, having tried all three, whether to drop Ear instead: "the both mode does give you a better context". Ear alone showed less than the voice with the text, at no gain. So there are two modes: **With Voice** (the voice and the scrolling text) and **Screen Only** (the text, no voice). A stored Ear or Both reads as With Voice. The Ear-only take screen, its phrase and sentence display and its large controls are removed. Finished and Can't start keep their layout.
   - **The marker (decision 4 changed).** Asked why an underline and not a block: with no voice the place is a block on the word, and with the voice a thicker underline, so it does not compete with the voice's word on the accent.
   - The redraw pauses while the text is still, for battery with the phone in a pocket.
   - **Still to do:** the Script screen's start card is to be restyled (Andy): icons for the modes, a Start Take button that fits, no "Step 1 ready in Stephanie" line, and no black borders on its buttons.
