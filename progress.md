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
- [ ] Manual test: device. Check 1 passed with changes; check 2 led to the simplification (the screen marks only what has been heard; engine ignores speech before Back/Forward), all recorded in the plan's device check section. Now the eyeline with heard words dimmed, no word marker (Andy's choice), installed; console in scratchpad console.log. Next: Andy judges the eyeline and redoes check 2 (Lost, Back, Forward, Hold), then 3 (With Voice on the mount), 4 (choosing the mode), 5 (size, landscape), 6 (With Voice in a pocket).
- [ ] Complete (commit + PR)

## Notes
