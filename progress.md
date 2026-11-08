# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Mode:** autopilot (/plan_autopilot). On resume, carry on through the checklist to the PR; stop only for the manual test or a real decision. Merging is Andy's.

**Plan:** 006, when the take can't hear the script (`plans/006-take-hearing.md`).
**Branch:** `take-hearing`, from `main` at `253d080`.
**Issues:** #18 and #19 (no issue of its own; the PR closes both).
**Manual test:** device, on the iPhone 14 Pro with the SK18 (the plan's Verification, five checks, one at a time).

## Checklist

- [x] Step 1: #18, listening gives up (`onGaveUp`, the take stops with a reason, the Finished text, the Debug flag); commit
- [x] Step 2: #19 reproduction (`interimInterval`, 4 w/s scenario disabled as reproducing, release moment recorded in the plan, misheard-end wait pinned); commit
- [x] Step 3: #19 rule (candidates A, B, C; the kept one passes all scenarios at both rates; `PresenterEstimateTests`); commit
- [x] Tests + lint (265 tests pass, no warnings, SwiftLint clean)
- [x] Review + fixes (C2, C3, C4 part, T1, T3, T4, T5 part, T7, T8 fixed; C1 for device check 2)
- [ ] Manual test: device (iPhone 14 Pro, SK18). Installed f753123 build; console in scratchpad console1.log. Checks 1, 2 PASS; check 3 given, awaiting verdict
- [ ] Complete (commit + PR)

## Notes

- #19: the release came on the phrase-end words themselves (on-script coast), so candidate B (coasting stops at a phrase boundary until a word beyond it is heard) is kept; see the plan's Results. Its cost (a misheard phrase end in 1 s bursts: gate 2.45 s, one 0.15 s presenter wait) is for Andy's device check 2.
- Screen mode becomes plan 007.
- Still open, not in this plan: #5, #6, #9, #10, #13, #14, #16, #20, #21, #22; outdoors and the Osmo on the next shoot; the Scripts toolbar's Paste pill showing only its icon.
