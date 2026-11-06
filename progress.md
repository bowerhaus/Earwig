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
- [ ] Review + fixes
- [ ] Manual test: device check on the iPhone 14 Pro (one check at a time)
- [ ] Complete (Results, PRD v0.6, commit + PR)

## Notes

- Built: `ScriptRenderer`, `VoiceCatalogue`, `Slate`, `Tones`, `PhraseTiming(phrase:tokenStarts:duration:)`, `AudioEngineHost` (voice, cue, tone channels; `PlayerOutput`), `Player`, `StepPreview`, the rendering row and `ListenView`. 187 tests pass, SwiftLint clean.
- Slate signature changed for SwiftLint's parameter count: `Slate.text(number:shotID:take:directions:)`, `directions` nil with cues off.
- Debug flag `-EarwigListen YES` (with `-EarwigDemo YES`) opens Listen once the start step is ready, for the simulator.
- Simulator (Daniel compact): step 1 renders 10 phrases, 21.7 s of audio in 0.7 s, 74 of 74 words timed (delegate markers). Listen runs slate, tones, all phrases; next phrase starts < 0.5 ms after an end; ends arrive about 145 ms after the audio length; output latency 10 ms on the speaker.

