# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Plan:** 010, record a take with sound or video and play it back (`plans/010-take-recording.md`)
**Issue:** #16
**Branch:** `take-recording` (from `main` at `efd0e86`)
**Mode:** autopilot (/plan_autopilot). On "resume", carry on through the checklist to the PR; stop only for the manual tests or a real decision. Merging is Andy's.
**Manual test:** device, iPhone 14 Pro on the mount with the SK18. Step 1's check comes before the rest is built.

## Checklist

- [x] 1. (1a–1c passed; 1d, heat and the fixed ending, deferred by Andy to the manual tests) Device check first: the camera, the writer and the mic's second consumer behind `-EarwigRecordVideo YES`; Andy checks route, recogniser, sync, heat at 4K30
- [x] 2. The writer and the store (`TakeRecording`, `RecordingStore`, tests)
- [x] 3. Settings and the take (settings, start card, `TakeHost`, tests)
- [x] 4. The screens (framing, dot, Play Back, Share, tests, screenshots)
- [x] Tests + lint
- [x] Review + fixes (review pass and outcome in the plan; issue comment posted)
- [ ] Manual test: device (Verification 1d, then 2–6)
- [ ] Complete (commit + PR)

## Notes

- **Next: recheck 4b** (the Text over the camera slider, no blue layer) and Save Video; ask Andy about the double slide when the Prompt screen opens (with Record Off too? new on this branch?); then 5, then 1d. Check 6 is done but for Settings' size and Delete All. Console in the scratchpad `console-4e.log`.
- Check 4b, fourth try (take 60): Andy: "the screen appeared at once this time"; tones ended 1.82 s after Start, 0 frames dropped, waits 3 (longest 1.9 s). Andy saw "the page slide twice after it has rendered the text" when starting a take, "basically working okay". He asked for a slider for the text's brightness over the camera, and why the blue layer: removed, with a Text over the camera slider (10-100%, default 35%) in its place. `take: main thread held 0.67 s` as the take ended (the preview going), a delay before Finished.
- Check 4b, third try (take 59, 1080p): Andy: "The beeps occur straight away, but there's still a gap before the video screen appears and also the text over the top of it." Console: `player: tone of 1.80 s rendered in 1.79 s, its end handled 7.40 s later`, so the main thread was held. Cause: the camera sat behind a `Group`, whose modifiers go to each child, so it was built again at Start. Fixed with a `ZStack`. Andy then asked for the picture near normal brightness and the text faded right down, the more so with the voice: scrim 10%, text 35% With Voice, 60% Screen Only.
- Check 6, Keep on half: Andy has Keep Recordings on; take 55 and step 2 takes 12-15 were all kept, so two takes leave two files.
- Check 4b, second try (takes 57 at 4K, 58 at 1080p): Andy: "The video density is better" (the scrim at 30%), but "about a 10-second gap after pressing start". Console: the tones ended 9.2 s after Start in both, as in the first try; 12 frames dropped. Not 4K and not the second preview layer. Every video take without the camera behind the text took 1.8 s.
- Check 4b, first try, 2026-11-09 (step 1 take 56, 4K): Andy: "It took quite a long time to set up the scene with the video behind it. I thought it had hung for a moment. Also, the video is too faint." Console: the tones took 9.2 s against 1.8 s in every earlier take, and 12 frames dropped. Fixed: one preview for the whole take (no second layer at Start), scrim 60% to 30%.
- Check 4, 2026-11-09: takes step 2 14 and 15 at 4K, 3840x2160, 0 drops, thermal nominal, battery 100% to 95%. Andy: AirDrop works; the dot and time "are fine, they're small, but they're not really that essential". Save Video was missing from Share: `NSPhotoLibraryAddUsageDescription` added. The file's size is still to be read.
- Check 3, 2026-11-09: takes 54 (With Voice) and 55 (Screen Only), 1080p, rotation 90°, 0 drops, frames 1.6 s late (covered by the tail and wait). Andy: the preview "worked, and it was easy to frame the shot"; "the picture and sound are good quality and in sync". Waits with video (take 54: 3, longest 1.9 s) the same as sound only (take 53: 3, longest 1.9 s). Dot and time: Andy didn't notice them; to look again in check 4.
- Andy asked for the preview kept on during the take, perhaps with the words over it. A product change beyond decision 3; offered as a follow-up issue ("Show the camera behind the text during a video take").
- Check 2 passed, 2026-11-09: takes 52 and 53, sound, 0 drops, thermal nominal. Andy: "The recording is clear to hear back", the file is in Files. Check 6's Keep-off half passed with it: the two takes left one file (take 53 replaced take 52).

- Step 1's build is on the phone. Next: Andy unlocks it; launch with `xcrun devicectl device process launch --console --terminate-existing --device 00008120-000471EE14E0201E com.bowerhaus.Earwig -- -EarwigDemo YES -EarwigRecordVideo YES` (in the background, console to the scratchpad), then check 1a: a filmed take, route and recogniser. Then 1b (the same take not filmed, to compare), 1c (sync, the file pulled to the Mac with `devicectl device copy from`), 1d (ten minutes of takes for heat).
- 1a PASS (Andy): voice in the earpiece throughout, following as usual. Console: take 49 SK18 A2DP + built-in mic throughout, 27.8 s completed, lead within 2 words 24%, waits 3 (longest 1.9 s), delay 0.89 s, rate 3.95 w/s; recording 0 dropped; thermal nominal. Andy: the route icons never look green (the theme's pale mint `good` on sky blue) — a follow-up, not this plan.
- Take 49's file (copied to the scratchpad `takes/`): HEVC 3840x2160 30 fps rotation -90, AAC; video 26.20 s against sound 27.68 s, so the video's last ~1.5 s is missing: frames are likely delivered late (stabilisation), and finish stops the sink before they arrive. To fix: finish waits for a frame past the stop time (or a timeout), and log the frames' delivery delay and the stabilisation mode.
- 1b (take 50, not filmed): delay 0.95 s against 0.89 filmed; rate 3.62 against 3.95; lead within 2 words 36% against 24%; waits 6 (longest 4.2 s) against 3 (1.9 s). Andy gave no verdict on feel for 1b.
- 1c PASS (Andy): sound in sync, picture upright; the last sentence missing from the video. Fixed: the recording runs on `RecordingWriter.tail` (1 s) past the take's end and waits (up to 3 s) for the camera's late frames; the log gives the frames' delay. To check in 1d.
- Done: Next Take waits for the recording to be saved (`isSavingRecording`). Andy added Play Sound beside Play Video (decision 7). Simulator screenshots taken (start card, framing placeholder, dot, Finished, Settings); the simulator records nothing, since its take hears a made-up reading with the mic off.
- (was) Step 4 must hold Next Take until the take's recording is finished (teardown now runs 1–4 s longer while it records on).
- No framing preview yet (step 4): frame the mount with the Camera app first.

