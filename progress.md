# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Plan:** 010, record a take with sound or video and play it back (`plans/010-take-recording.md`)
**Issue:** #16
**Branch:** `take-recording` (from `main` at `efd0e86`)
**Mode:** autopilot (/plan_autopilot). On "resume", carry on through the checklist to the PR; stop only for the manual tests or a real decision. Merging is Andy's.
**Manual test:** device, iPhone 14 Pro on the mount with the SK18. Step 1's check comes before the rest is built.

## Checklist

- [ ] 1. Device check first: the camera, the writer and the mic's second consumer behind `-EarwigRecordVideo YES`; Andy checks route, recogniser, sync, heat at 4K30
- [ ] 2. The writer and the store (`TakeRecording`, `RecordingStore`, tests)
- [ ] 3. Settings and the take (settings, start card, `TakeHost`, tests)
- [ ] 4. The screens (framing, dot, Play Back, Share, tests, screenshots)
- [ ] Tests + lint
- [ ] Review + fixes
- [ ] Manual test: device (Verification 2–6)
- [ ] Complete (commit + PR)

## Notes

