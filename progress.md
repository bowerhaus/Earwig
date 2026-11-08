# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Mode: autopilot (/plan_autopilot)**: carry on through the steps below without stopping, except for a device check or a real decision. Commit and the PR are authorised by autopilot; merging is Andy's.

**Plan:** `plans/008-screen-mode.md` (Screen mode, stage 6) · **Issue:** #25 · **Branch:** `screen-mode` (from `main` at `ed33225`; pushed once early, now 39+ commits ahead of `origin/screen-mode`, so push before the PR)
**Manual test:** device, iPhone 14 Pro. All six checks PASSED and are recorded in the plan ("Device check" section and "Results"). No more device checks are needed unless a fix below changes behaviour Andy has seen.

## Where things stand

- The plan is marked Complete, with Results (an "As built" list of 12 items and the measured figures). PRD v0.10 (with a Document History row) and the CLAUDE.md status and flags are written and committed (af602c5).
- **Second review** (Andy asked for it after the device-check changes): recorded verbatim in the plan as `## Review pass — 2026-11-08 (second)`, with an Assessment where every finding is FIX, and posted on #25. **Stopped for Andy's answer**, because T1 is CRITICAL. The question was "Apply all the fixes?", with options "Yes, fix all" or "Only T1 and C1".

## Next (on Andy's answer)

Apply the FIXes he approves, from the plan's second Assessment:
- **T1:** the voiced `move(by:)` in `Earwig/Engine/FollowEngine.swift` sets `held = false` but not `heldPlace = nil`. Clear it via a shared re-anchor helper (C2) used by `move(by:)` and `moveReading(by:)`: set `settled` and `current`, `ignoreHeardBefore = now + estimate.delay`, `ignoreSpokenBefore = now`, `held = false`, `heldPlace = nil`. Add a voiced test (Hold, then Forward, then `presenterPlace` follows) and assert `presenterPlace` in the voiceless Hold test.
- **C1:** `ScreenTextView`'s `TimelineView(.animation(paused:))` is never re-read at rest, because `TakeHost.publish` assigns `snapshot` only on change. Add `@State var resting`: paused = `resting && follower.isStill(toward: place) && !dragging`; in the timeline closure, when the stillness differs from `resting`, set it via `Task { @MainActor in }`.
- **T2:** a voiced twin of `whatWasSaidBeforeAMoveIsNotFollowed`.
- **T3:** fold the three pause tests in `EarwigTests/Simulation/ScreenPlaceScenarioTests.swift` (phrase end, colon, after "village") into one, parameterised by where the pause falls, asserting the place rests on the next word and `screenBackSteps` stays empty.
- **C2:** merge `isCompleteReading` into `isComplete` with an optional voice-done time.
- **C3:** drop `phraseList` and `firstWord` from `TakeSetup.Summary`, and have the tests build `screenWords` with `ScreenText` directly.
- **C4 and T4:** move `AccentPill`'s doc comment back above `AccentPill` (`ModeTile` was inserted between them); fix `ReadingHeardSource`'s doc to name `-EarwigReads`; update stale "Ear off" and "reading line" wording (FollowSettings.voiced, startTake, the ScreenTextView and IconControl headers, three test comments).
- **T5:** the `screen(...)` helper in `PromptViewModelTests` takes `place` and sets only `presenterPlace`; one `isHeard` test; `lostAndHeldStillFollow` keeps only `place` and `diagnostics`.
- **T6:** one forward-glide test with both triggers; `ScreenFollowerTests.theMarkIsTheSmoothedPlacesWord` keeps `nil` and the rounding down.
- **T7:** merge `backAndForwardMoveThePlaceAPhraseAndPassOverCues` with `afterAMoveTheScreensPlaceIsThePhrasesFirstWord`, and assert `presenterPlace` in `thePlaceIsCappedAtTheLastWord`.

Then:
1. Run the tests and lint (CLAUDE.md commands; 324 tests passed before the fixes).
2. Append `### Outcome — <date>` below the second review pass in the plan.
3. Install on the iPhone (UDID `00008120-000471EE14E0201E`, `devicectl`, with app arguments after `--`). Ask Andy for a quick look only if T1 or C1 change what he sees (Hold, then Forward, With Voice).
4. Finish `/plan_completed`:
   - empty this file to its stub (state what is true of the work and name PR N; never claim the PR's state);
   - commit, `git push`, and open the PR to `main` with "Closes #25", a summary, docs reviewed, and the tests and lint run;
   - list the follow-up issue drafts in the PR and the final report, not opened: "Fixed-pace scroll when listening is off (PRD §4.6, P1)", and optionally "Make Lost more visible in Screen mode".
5. Then the ccd_pr tools: `get_status`, `bind_pr`, CI.
6. End with the autopilot's single final report, asking only whether to open the follow-up issues.

## Notes

- **Console logs from the device checks:** the scratchpad `console-*.log` files. Launch with `xcrun devicectl device process launch --device <UDID> --terminate-existing --console com.bowerhaus.Earwig` in the background, redirected to the scratchpad's `console.log`. If the launch fails with "Locked", ask Andy to unlock the phone.
- **Andy's decisions this plan** (all recorded in the plan):
  - two modes, With Voice and Screen Only (Ear alone dropped);
  - the start card in "card C" style, with Start Take at the foot of the step card;
  - mark only what has been heard;
  - an eyeline with the heard words dimmed and no word marker;
  - Light the Voice's Phrase as a setting, off by default;
  - text size default 40;
  - no 1.5 s pause rule;
  - the fixed-pace scroll as its own issue.
- Simulator Debug flags: `-EarwigDemo YES -EarwigScreen YES -EarwigReads YES`.
