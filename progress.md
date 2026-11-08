# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Mode: autopilot (/plan_autopilot)**: carry on through the steps below without stopping, except for the device checks (one at a time) or a real decision.

**Plan:** `plans/008-screen-mode.md` (Screen mode, stage 6) · **Issue:** #25 · **Branch:** `screen-mode` (from `main` at `ed33225`, pushed)
**Manual test:** device, iPhone 14 Pro (Verification 1–6, one at a time)

Andy's choices (2026-11-08): Ear off follows the presenter directly; reading line at the presenter's place; smooth continuous scroll; mode chosen before the take (Settings + beside Start), fixed during it; fixed-pace scroll out.

## Checklist

- [x] Step 1: the engine with no voice (a4ad65f). Raw estimate at 4 w/s in bursts swings ±4 words; thresholds pinned at measured. Step 3 adds a rate-tracking ScreenPlace (alpha-beta in words) and measures it in the simulation.
- [x] Step 2: settings, the take's mode, Start without rendering (mode picker in the rendering row; a lost earpiece does not hold a voiceless take)
- [x] Step 3: the text: `ScreenText`, `ScreenPlace` (tracker in words), `ScreenLayout`, `ScreenTextView`, compact layout, `-EarwigScreen` and `-EarwigReads`; simulator screenshots in the scratchpad `shots/` (screen-c, both, landscape)
- [x] Step 4: the pinch (in `ScreenTextView`; checked on the device only)
- [x] Tests + lint (322 tests pass, SwiftLint clean, at ea4512e)
- [x] Review + fixes (Review pass and Outcome in the plan; #25 comment; 325 tests pass, lint clean)
- [ ] Manual test: device (Verification, revised: two modes). Check 1 passed with changes (all in the plan's device check section): two modes With Voice / Screen Only, the place stops at punctuation, the first word trusted alone with no voice, a block mark on Screen Only, redraw paused while still. Installed at the commit after d88d94f; the phone was locked, so relaunch the console (devicectl --console) before the next check. Start card restyled (card C, tiles only choose, Start Take on the step card), installed. Next: Andy re-runs check 1 on the new build, then check 2 (Screen Only: off script and back, Back, Forward, Hold).
- [ ] Complete (commit + PR)

## Notes
