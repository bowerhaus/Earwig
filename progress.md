# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Plan:** 004, renderer and player (`plans/004-renderer-player.md`), stage 4 of PRD §12.
**Mode:** autopilot (`/plan_autopilot`): build, test, review, stop only for the manual test or a real decision, then complete with a PR. Merging is Andy's.
**Branch:** `renderer-player`, from `main` at `a382ac8`. Pushed.
**Issue:** #11 (the PR closes it).
**Manual test:** on the iPhone 14 Pro with the SK18 (plan's Verification: render, Listen, highlight, locked).

## Checklist

- [x] 1. Renderer: `ScriptRenderer` (in-memory, by voice, rate and text), `VoiceCatalogue`, tests
- [x] 2. Timings and slate: `PhraseTiming(rendered:)`, `Slate`, tests
- [x] 3. Tones and player: `Tones`, `AudioEngineHost` nodes, `Player`, tests
- [x] 4. Screen: rendering row, render on open and on a new start step, Listen sheet
- [x] Tests + lint
- [x] Review + fixes (pass and outcome in the plan; comment on #11)
- [ ] Manual test: device check on the iPhone 14 Pro (one check at a time)
- [ ] Complete (Results, PRD v0.6, commit + PR)

## Notes

- Built: `ScriptRenderer`, `VoiceCatalogue`, `Slate`, `Tones`, `PhraseTiming(phrase:tokenStarts:duration:)`, `AudioEngineHost` (voice, cue, tone channels; `PlayerOutput`), `Player`, `StepPreview`, the rendering row and `ListenView`. 187 tests pass, SwiftLint clean.
- Slate signature changed for SwiftLint's parameter count: `Slate.text(number:shotID:take:directions:)`, `directions` nil with cues off.
- Debug flag `-EarwigListen YES` (with `-EarwigDemo YES`) opens Listen once the start step is ready, for the simulator.
- Review: 7 code, 10 test findings, none critical; all fixed except T6 (skipped) and C3/T3 in part. 188 tests pass.
- Simulator (Daniel compact): step 1 renders 10 phrases, 21.7 s of audio in 0.7 s, 74 of 74 words timed (delegate markers). Listen runs slate, tones, all phrases; next phrase starts < 0.5 ms after an end; ends arrive about 145 ms after the audio length; output latency 10 ms on the speaker.


**Next:** manual test on the iPhone 14 Pro, one check at a time (plan's Verification 1–4). Build c1c96ae is installed; launched with `devicectl ... process launch --console` in the background, log in the session scratchpad. Check 1 (Render) handed to Andy; waiting for his verdict. Then checks 2 (Listen), 3 (Highlight), 4 (Locked), Results, PRD v0.6, PR.

## Device results so far (iPhone 14 Pro, SK18)

- Bug found at check 1: iOS 27 puts the quality in a voice's name ("Stephanie (Enhanced)"), so Stephanie was not found and Jamie was used. Fixed in daa1aac (`VoiceInfo.baseName`); en-GB voices now logged at launch.
- Check 1 Render: PASS (Andy: "It all looks good to me"). Voices: presenter Stephanie (Enhanced), cue Jamie (Premium). Step 1: 10 phrases, 22.4 s of audio in 1.12 s, 74 of 74 words timed, markers from both, 22,050 Hz source. Step 2: 8 phrases, 19.5 s in 0.35 s, 76 of 76 timed. Step 1 again: nothing rendered.
- From Andy's early Listen on the Jamie build: output latency 356 ms on the SK18 (333 ms route + 23 ms buffer); phrase 1 ended 547 ms after its length.
