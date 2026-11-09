# Plan 010: Record a Take, with Sound or Video, and Play It Back

**GitHub Issue:** [#16](https://github.com/bowerhaus/Earwig/issues/16) (PR must include "Closes #16"). Its title and acceptance criteria were updated to this plan on 2026-11-08: video added, the earpiece's audio not recorded.
**Branch:** `take-recording` (from `main` at `efd0e86`, after plan 009 merged)
**Status:** Complete (2026-11-09). PASS on the iPhone 14 Pro; results below. PRD v0.12.
**Manual test:** device, on Andy's iPhone 14 Pro on the mount with the SK18 (Verification). Step 1 is a device check that decides whether video stays in the plan.
**Goal:** A take can be recorded, as sound alone or as video from the front camera with the sound from the iPhone's mic, and played back on the Finished screen. It is for checking a performance: how the reading sounds and looks when following the voice or the text. Recording never changes what the recogniser hears, what the earpiece plays, or its latency.

**PRD references:** §1.4 Non-Goals (camera), §4.7 Takes, §4.8 Settings, §7.2 Key Services, §8.3 Prompt, §8.4 Settings, §11 Risks, §13 Phase 3.

---

## Scope

**In:**
- the choice to record a take, Off, Sound or Video, on the start card and in Settings (decision 1);
- filming inside Earwig with the front camera, the capture session given no microphone and kept off the audio session (decision 2);
- the sound from the mic tap the listener already has, written with the video by one `AVAssetWriter` on the host clock (decisions 2, 3);
- framing on a camera preview before the take begins (decision 4);
- a recording dot and time on the Prompt screen while recording (decision 5);
- the files in Earwig's folder in Files, the last take's always, every take's if Keep Recordings is on (decision 6);
- Play Back and Share on the Finished screen (decision 7);
- 1080p30 by default, 4K30 as a setting (decision 8);
- video stopping, and sound carrying on, when the phone locks or Earwig leaves the screen (decision 9);
- unit tests, writer tests with made-up frames and sound, and the device checks.

**Out:**
- **What the earpiece played.** Andy (2026-11-08): only what was said, not what was played. The issue's first criterion asked for both; it is dropped.
- the rear camera (Andy chose the front; it can be added later as a setting);
- a preview during the take, or the text over the camera (Andy chose framing before the take only). *Moved in after check 3, at Andy's asking: decision 4, amended.*
- a list of past recordings on the Script screen, or playing an older take's recording. A take records where its file is (decision 6), so a later plan can add it;
- Earwig saving to Photos itself. The share sheet's Save Video does it. *Check 4 found the share sheet offers Save Video only with `NSPhotoLibraryAddUsageDescription`, so Earwig has that add-only permission (decision 7).*
- filming the Osmo takes. They stay sound only, in the pocket;
- the take record for Cutaway (Phase 2), framing aids and a camera mode of its own (Phase 3's remainder).

## Can it be done?

Yes, by the route in decision 2. The PRD kept filming out of v1 because the stock Camera app takes the audio session and silences Earwig. That does not apply when Earwig runs the camera itself. An `AVCaptureSession` with `automaticallyConfiguresApplicationAudioSession = false` and no audio input never touches the session: the category, the A2DP route and the built-in mic stay as `AudioSessionManager` set them, and the engine is not restarted. What iOS does not allow is the camera running in the background, so a video take needs Earwig on screen and the phone unlocked (decision 9). Load and heat (video encoding, `SpeechAnalyzer`, the time-pitch node and a bright screen together) are unknown and are what step 1 checks.

Two other ways were weighed and not chosen (2026-11-08):
- **Video alone from `AVCaptureMovieFileOutput`, the sound in its own file, joined after the take.** Apple's file output does the video, but its start is known only roughly, so the lips can be out by a frame or more, and every take needs a join that takes seconds.
- **The capture session recording the mic itself.** The least code, but two owners of the mic: the capture session can reconfigure the session or restart the engine, which is what the issue says recording must never do.

## Design decisions

1. **Off, Sound or Video, chosen before the take.** One saved value, `TakeSettings.recording` (`off`, `sound`, `video`), default Off. It is chosen on the start card, as a row under the With Voice and Screen Only tiles, and in Settings in a new **Recording** group; it is the same value in both, as the mode is (plan 008, decision 6). It is fixed for the take, and Next Take keeps it. Video works with either mode: With Voice (the earpiece and the text) or Screen Only.

2. **The camera gives frames, the listener's mic gives sound, one writer writes both.**
   - **`CameraCapture`** (new, `Services/`): an `AVCaptureSession` with the front wide-angle camera as its only input and an `AVCaptureVideoDataOutput`, frames delivered on its own serial queue. `automaticallyConfiguresApplicationAudioSession = false`, and no audio input is ever added. 30 frames a second, the format for the quality (decision 8). Video stabilisation `.auto`. Front camera video is written as the camera sees it, not mirrored; the preview is mirrored, as the Camera app's is.
   - **The mic, shared.** `AudioEngineHost.installMicTap` keeps its one block for the listener, and gains a second consumer, set and cleared under a lock, which the same tap calls after the listener's block with the same buffer and host time. The listener's feed is not changed or delayed. The recording consumer copies the buffer (a copy of 1024 frames, on the audio thread) and hands it to the writer's queue; it never waits. A buffer the writer is not ready for is dropped and counted, and the count logged.
   - **`TakeRecording`** (new, `Services/`): an `AVAssetWriter` with an HEVC video input (settings from the output's `recommendedVideoSettingsForAssetWriter`) and an AAC audio input, mono, at the mic's rate, 128 kb/s. Sound alone is the same writer with the audio input only, writing `.m4a`.
   - Behind a protocol (`TakeCapture`), so `TakeHost` is tested with a fake, as the session, the output and the listener are.

3. **One clock.** The mic tap's buffers carry host time already (`installMicTap` passes it). The camera's sample buffers are on the capture session's `synchronizationClock`, converted to the host clock with `CMSyncConvertTime`. The writer's session starts at the first video frame at or after the recording's start, and sound before it is trimmed, so the file opens on a frame with its sound. Sound alone starts at the first mic buffer after the start.
   - **When it starts:** when the take is recorded, at its slate (or, with tones only, its tones), so the spoken slate is in the file.
   - **When it ends:** when the take finishes, whatever the outcome, and when the screen closes mid-take. The writer is finished before the session is let go.

4. **Framing before the take (Andy, 2026-11-08: a preview before the take only).** A video take opens on the front camera's preview, full screen, with the step and take at the top and **Start** at the foot. The take gets ready behind it (session, engine, listening, slate). The tap on Start begins it: the preview goes, the Prompt screen's text comes, and the slate or tones play. Getting ready alone would be too short to frame in, since a Screen Only take with tones is ready in about a second. Cancel leaves without a take, as now. A Sound or Off take starts as now, with no extra tap.
   - `TakeHost` gains a wait after getting ready, when the setup asks for one (`waitsForGo`), ended by `go()`. Nothing is recorded or numbered until then.
   - **Amended after check 3 (Andy, 2026-11-09: "let's add the preview to this plan").** The camera also shows behind the scrolling text while a video take runs, under a scrim (`EarwigTheme.cameraScrim`, the cards' mid-blue at 60%) so the white text reads on a moving picture. A **Camera Behind the Text** toggle in the Recording group, on by default (`TakeSettings.cameraBehindText`), fixed for the take. The preview goes when the video stops early (decision 9), since it would freeze, and is never shown for Sound. It is the same capture session's second preview layer, so the file is unchanged.
   - **After check 4b (Andy, 2026-11-09):** the picture at its own brightness, with no scrim (Andy: "Why are we adding the blue layer at all?"), and the text faded instead, as a slider on the preview says (10% to 100%, default 35%; Andy: "I was actually quite hoping the slider could also be on the phone screen"). With Camera Behind the Text on, the preview shows the step's opening words as the take will, over the picture, with the slider above Start; the take uses the slider's last value. One preview for the whole take, under a `ZStack`: a `Group`'s modifiers go to each child, so a camera behind a `Group` was built again at Start, and attaching that second preview layer to the running session held the main thread for about seven seconds (the tones ended 9.2 s after Start against 1.8 s; `player: tone of 1.80 s rendered in 1.79 s, its end handled 7.40 s later`).

5. **While recording, a dot and the time.** The Prompt screen's top row shows a red dot (a new `EarwigTheme.recording`) and the minutes and seconds recorded, for Sound and Video. When video stops early (decision 9), the dot shows the sound-only icon.

6. **The files: Earwig's folder in Files, the last take always, every take if kept (Andy, 2026-11-08).** Andy is not sure recordings need keeping, since they are for checking a performance, not for use, but wants the option left open.
   - Files go in the app's Documents, shown in the Files app (On My iPhone › Earwig), with `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` in `project.yml`: `Recordings/<script title>/Step 3 Take 2.mov` (or `.m4a`), named as the slate says it.
   - **Keep Recordings**, a switch in the Recording group, default off. Off: when a take's recording starts, the recording before it is deleted, so only the last take's is on the phone. On: every recording is kept.
   - Settings shows how much the recordings take up, with **Delete All Recordings**, which asks first.
   - `Take` gains `recordingPath: String?` (relative to Documents), an optional property, a lightweight change to the store. It is set when the recording starts and cleared when its file is deleted, so a later plan can list takes with their recordings.
   - Before a video take, if the phone has under 1 GB free (`volumeAvailableCapacityForImportantUsage`), the take records sound only and says so. A writer that fails mid-take stops recording, the take carries on, and Finished says why.

7. **Play Back and Share on the Finished screen.** When the take was recorded, Finished adds **Play Back** and **Share** above Next Take and Done. For a video take, Play Back is two buttons, **Play Video** and **Play Sound** (Andy, 2026-11-08: the option of the sound alone). Play Sound plays the file's sound track alone, from a composition of that track, so no picture is decoded. Share offers Save Video only with `NSPhotoLibraryAddUsageDescription` in `project.yml` (added after check 4, where it was missing).
   - Play Back opens a sheet with `VideoPlayer` (AVKit) for both video and sound, with its own play, pause and scrub, and Done. The take has let the audio session go by then. Playback sets the category to `.playback`, so it is heard on the earpiece or the speaker, whichever is connected; Next Take configures the session for a take again, as it always does.
   - Share is the share sheet with the file: AirDrop to the Mac, Save Video to Photos, Save to Files.
   - Only what was said is in the file (Out). Mixed or one-ear playback of the earpiece is not needed.

8. **Quality: 1080p30 by default, 4K30 as a setting (Andy, 2026-11-08).** *Measured in check 4 (2026-11-09): about 80 MB a minute at 1080p (take 55, 38.6 MB for 29.3 s) and about 280 MB at 4K (step 2 take 15, 128.5 MB for 27.2 s), against the estimates below. Settings said the measured figures until its footers were cut to one line (Results, beside the checks), and now states none.* 1080p is enough for checking a performance (about 60 MB a minute in HEVC); 4K30 is for a take meant for use (about 170 MB a minute), matching the Osmo. A **Video Quality** picker in the Recording group. The front camera of the iPhone 14 Pro does both.

9. **Orientation, locking and leaving the screen (Andy, 2026-11-08: as proposed).**
   - **Orientation** is the phone's at Start (from `AVCaptureDevice.RotationCoordinator`), fixed for the take, written as the file's rotation.
   - **The phone locked, or Earwig off screen, mid-take:** the capture session is interrupted. Video stops there and is not resumed; the file keeps the video to that point and the sound carries on to the take's end in the same file, so players hold the last frame. The take itself goes on, with the voice, as a pocket take does. Finished says "Video stopped at 1:23: the phone was locked" (or "Earwig left the screen").
   - A call ends the take, as now, and the recording with it.
   - The screen already stays awake during a take (plan 005).

10. **Recording never changes the take.**
    - The engine is untouched; the simulated takes run unchanged.
    - The listener's block is called first and unchanged (decision 2).
    - The capture session never touches the audio session (decision 2), and the output latency is read as now.
    - `TakeSummary` gains the recording (`off`, `sound`, `video 1080p`, `video 4K`), the dropped mic buffers and the thermal state at the end (`ProcessInfo.thermalState`), so a take with and without recording can be compared from the console.

## Files

| File | Purpose |
|------|---------|
| `Models/AppSettings.swift` | `TakeRecordingMode`, `VideoQuality`, `TakeSettings.recording`, `videoQuality`, `keepsRecordings` (decisions 1, 6, 8) |
| `Models/Take.swift` | `recordingPath` (decision 6) |
| `App/EarwigTheme.swift` | `recording` |
| `Services/AudioEngineHost.swift` | The mic tap's second consumer, under a lock (decision 2) |
| `Services/CameraCapture.swift` (new) | The front camera's capture session, preview layer, rotation, interruptions (decisions 2, 4, 9) |
| `Services/TakeRecording.swift` (new) | The writer, the clock, sound alone or with video, `TakeCapture` (decisions 2, 3) |
| `Services/RecordingStore.swift` (new) | File names, the folder, keep or delete the last, the total size, free space (decision 6) |
| `Services/TakeHost.swift` | Waiting for Go, starting and ending the recording, video stopped early, the setup's recording (decisions 3, 4, 9) |
| `Services/TakeSummary.swift` | The recording, dropped buffers, thermal state (decision 10) |
| `ViewModels/PromptViewModel.swift` | Framing, the recording dot and time, Finished's Play Back and Share and the video note (decisions 4, 5, 7, 9) |
| `ViewModels/ScriptDetailViewModel.swift` | The recording in the take's setup |
| `Views/Prompt/PromptView.swift`, `Views/Prompt/FramingView.swift` (new), `Views/Prompt/PlaybackView.swift` (new) | Framing, the dot, Play Back and Share (decisions 4, 5, 7) |
| `Views/ScriptDetail/ScriptDetailView.swift` | Off, Sound, Video on the start card (decision 1) |
| `Views/Settings/SettingsView.swift` | The Recording group (decisions 1, 6, 8) |
| `project.yml` | `NSCameraUsageDescription`, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace` |
| `EarwigTests/TakeRecordingTests.swift`, `RecordingStoreTests.swift` (new), `TakeHostTests.swift`, `AppSettingsTests.swift`, `PromptViewModelTests.swift`, `ScriptDetailViewModelTests.swift`, `TakeSummaryTests.swift` | As Steps |
| `CLAUDE.md`, `PRD.md` | Status, the launch flag; §1.4, §4.7, §4.8, §7.2, §8.3, §8.4, §11, §13 as built |

## Steps

1. **Device check first: can the phone film and follow at once?** The least code that answers it: `CameraCapture`, `TakeRecording` and the mic's second consumer, started by a Debug launch flag (`-EarwigRecordVideo YES`) on an ordinary take, writing to Documents. On the iPhone 14 Pro, on the mount, with the SK18, at 4K30 (the heavier):
   - the earpiece stays on A2DP and the route check stays green;
   - the recogniser's delays and the take's waits in the console are as without recording (a take each way, the same step);
   - the lips are in sync in the file, judged on the Mac;
   - heat and battery over ten minutes of takes.
   If the route or the recogniser changes, or the phone gets too hot, video comes out of this plan and it goes on as sound only, with the reason in Results. Andy's verdicts only. Committed on its own.
2. **The writer and the store.**
   - `TakeRecording` complete: sound alone and with video, the clock, dropped buffers, video stopping early with sound carrying on, failure.
   - `RecordingStore`: names, the folder, keep or delete the last, the size, free space.
   - Tests: `TakeRecordingTests` writes files in the simulator from made-up frames and mic buffers on a chosen host time: the durations, the video starting on a frame with sound before it trimmed, sound alone as `.m4a`, video stopped halfway with sound to the end. `RecordingStoreTests` in a temporary folder: the name from step and take, the last deleted when not kept and kept when kept, the size, Delete All.
3. **Settings and the take** (decisions 1, 4, 9, 10).
   - The three settings, the Recording group, and Off, Sound, Video on the start card.
   - `TakeHost`: the setup's recording, the wait for Go, the recording started at the slate and ended at the finish and on close, video stopped early, a failed writer not stopping the take, `recordingPath` on the take.
   - Tests: `AppSettingsTests` (defaults); `TakeHostTests` with a fake `TakeCapture` (started at the slate, not before Go, ended on every outcome, Cancel at framing records nothing, the take going on after the video stops or the writer fails); `ScriptDetailViewModelTests` (the recording in the setup, Next Take keeping it); `TakeSummaryTests`.
4. **The screens** (decisions 4, 5, 7). Framing, the dot and time, Finished's Play Back and Share, the playback sheet, the note when video stopped early. `PromptViewModelTests` for what Finished offers and the note. Screenshots in the simulator for Andy before the device checks; the simulator has no camera, so framing there shows a placeholder.
5. **Review.** `/review-branch`, with its findings fixed or recorded.
6. **Device checks** on the iPhone 14 Pro, one at a time (Verification). Results from Andy's verdicts and the console.
7. **Finish.**
   - `swiftlint lint` clean, no build warnings, all tests pass.
   - Results filled in.
   - PRD as v0.12 with a Document History row: §1.4 (Earwig films its own takes for checking; still not a camera app), §4.7 (recording), §4.8 and §8.4 (the Recording group), §7.2 (the new services), §8.3 (framing, the dot, Play Back), §11 (heat), §13 Phase 3 (what is left).
   - CLAUDE.md: the status, the camera's rule (never an audio input on the capture session), and the flag.
   - `progress.md` emptied to its stub.

## Verification

- `xcodebuild test` passes in the simulator; no warnings; SwiftLint clean.
- On the iPhone 14 Pro, installed with `devicectl` and the console read live, one at a time, with the sample script (made up). Lead 5, hybrid, tones only, voice speed 0.95x (the defaults):
  1. **Filming and following at once** (step 1, before the rest is built): as step 1. 1a to 1c done on 2026-11-08 (Results). **1d, deferred by Andy to here:** ten minutes of filmed takes at 4K30 for heat and battery, and the last take's final sentence in the picture (the fix after 1c).
  2. **Sound only, in the hand.** Record Sound, With Voice, the SK18. Read a step, then Play Back. Andy's verdict on hearing his reading; the file in Files under the script's name.
  3. **Video on the mount, With Voice and Screen Only.** Frame on the preview (it shows as soon as the camera runs, while the take gets ready), Start, read a step. Finished shows "Saving the recording…" with Next Take and Done held, then Play Video and Play Sound. Andy's verdicts on framing, on the dot and time, and on the picture and sync at 1080p. The take's waits against a take with recording off.
  4. **4K30.** The same at 4K30; the file's size; Share to the Mac by AirDrop and Save Video to Photos.
  4b. **The camera behind the text** (added after check 3). A video take with Camera Behind the Text on: Andy's verdicts on reading the text over the picture, and on whether seeing himself draws his eye off the line. Off: the take looks as before.
  5. **Locked mid-take.** Lock the phone during a video take and unlock it at the end. The voice carries on, the dot turns to the sound icon, Finished says "Video stopped at m:ss: the phone was locked or Earwig left the screen.", and the file has the sound to the end.
  6. **Keeping.** With Keep Recordings off, two takes leave one file; on, two takes leave two. Settings shows the size, and Delete All empties the folder.

## Results

**PASS**, on Andy's iPhone 14 Pro with the SK18, 2026-11-08 and 2026-11-09. Verdicts are Andy's; numbers are from the console. 356 tests in 40 suites pass, no warnings, SwiftLint clean.

**1. Filming and following at once.**
- 1a, take 49, 4K, flag build: Andy: the voice stayed in the earpiece throughout and "everything felt as usual". SK18 A2DP and the built-in mic throughout, no drops, thermal nominal; lead within 2 words 24%, waits 3 (longest 1.9 s), delay 0.89 s.
- 1b, take 50, the same not filmed: delay 0.95 s, waits 6 (longest 4.2 s). Later pairs (checks 2 and 3) match closely: take 53, sound, waits 3, longest 1.9 s; take 54, video, waits 3, longest 1.9 s. Recording does not change the follow.
- 1c: Andy: "The sound is in sync, looks great with the picture. The picture is upright. However, the last sentence is cut off." The video was about 1.5 s short of the sound, since the camera delivers frames 1 to 1.6 s late. Fixed: the recording runs on a second past the take's end and waits up to three seconds for late frames.
- 1d, deferred by Andy to the end: six 4K takes in a row, about four minutes, with the camera behind the text: thermal nominal throughout, battery 90% throughout, no buffers or frames dropped. Andy: "The phone got slightly warm, but not really too bad. I didn't see any stuttering or slowing down, and the last recording did seem to be good." Ten minutes were not run; Andy did about five.

**2. Sound only.** Takes 52 and 53: Andy: "The recording is clear to hear back"; the file in Files under the script's name.

**3. Video on the mount, 1080p, With Voice and Screen Only.** Takes 54 and 55: Andy: the preview "worked, and it was easy to frame the shot"; "The picture and sound are good quality and in sync." He did not notice the dot and time; in check 4: "they're small, but they're not really that essential." Andy then asked for the preview kept on during the take, with the words over it, and for it in this plan (decision 4, amended).

**4. 4K30 and Share.** About 280 MB a minute at 4K (step 2 take 15: 128.5 MB for 27.2 s) and 80 MB at 1080p (take 55: 38.6 MB for 29.3 s), against the plan's 170 and 60. AirDrop to the Mac worked. Save Video was missing from Share, for want of `NSPhotoLibraryAddUsageDescription`; added, and then "I can save a video to photos."

**4b. The camera behind the text** (added after check 3), four tries:
- The first three: the tones ended 9.2 s after Start against 1.8 s, and Andy "thought it had hung". The console line added for it read `player: tone of 1.80 s rendered in 1.79 s, its end handled 7.40 s later`: the main thread was held. Cause: the Prompt screen's content was a `Group`, whose modifiers go to each child, so the camera behind it was built again at Start, and a preview layer added to the running capture session held the main thread for about seven seconds. Fixed with one preview for the whole take, in a `ZStack`.
- The picture: a blue scrim at 60% made the picture "too faint"; at 30% better; Andy then asked why there was a layer at all, and for the picture near normal with the text faded instead, by a slider he can set on the preview. Built so.
- The fourth try, takes 60 to 64: "the screen appeared at once"; the tones ended 1.8 s after Start in every take, no frames dropped. "The text in the take matches what we set, and the picture looks right without the blue layer … Everything looked good."
- Each video take's end holds the main thread about 0.7 s at 1080p and 1.1 s at 4K as the preview goes, a short delay before Finished. Andy: not worth an issue.
- Not reported: the Off leg (a video take with Camera Behind the Text off, after the `ZStack` change), and Andy's verdict on whether seeing himself draws his eye off the line. With the toggle off, the preview goes at Start, as in check 3, where the tones ended 1.8 s after Start (takes 54, 55).

**5. Locked mid-take.** Take 65: Andy: "The voice kept going in the [ear]piece while the phone was locked"; on waking, the voice was running and the camera gone from behind the text; Finished said "Video stopped at 0:07: the phone was locked or Earwig left the screen."; "The video is cut short at the point the phone locked. To be honest, I don't see this as much of a problem." The listener followed to the last word, and the sound ran the whole 28.4 s.

**6. Keeping.** With Keep Recordings off, two takes left one file (check 2); on, every take was kept (checks 3 and 4). Andy: "The delete all recordings works fine, and it does then show 0 kilobytes at the end."

**Beside the checks.**
- Settings' footers cut to one line where a choice does something its name does not say, or none, at Andy's asking ("They tend to let you work things out yourself"), all of them in this plan.
- Andy saw the Script screen open twice ("the page slide twice"; Back went to a second Script screen). Not this plan: most likely the Debug `-EarwigDemo` flag, whose `.task` pastes the sample and sets the navigation path at launch, so a tap pushes a second copy. Andy chose no issue for it, since the flag is Debug only; CLAUDE.md says to launch the phone without it.
- Andy: the route icons never look green on the take screen (the theme's pale mint on sky blue), and they show only once the take has begun, too late to act on: #33.

## Review pass — 2026-11-08

Findings from `/review-branch` on branch `take-recording`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact, and each verdict under *Assessment* is a
recommendation, not a decision. Work through them and annotate each with what was done — fixed,
or rejected and why. A finding that turns out to be wrong should say so here rather than be
deleted.

### Code

Review of `take-recording` against `main` (plan 010, issue #16). I did not run a build or tests. I found no compile breaks, the engine is untouched, and the colours are kept in `EarwigTheme` as CLAUDE.md asks. Seven findings, the first two the most important.

**C1 — WARNING: Done during "Saving the recording…" lets a new take overlap the old take's teardown.**
- Next Take is held until `isTornDown`, but Done is not.
- `endTake()` drops the host. Its `Task { await tearDown() }` keeps running for 1–4 s, because `capture.finish()` waits `RecordingWriter.tail` plus up to `endWait`.
- A Start tapped on the Script screen in that window builds a new take. The old teardown then calls `session.deactivate()` on the shared `AVAudioSession` under the new take. With video, the old capture session may also still hold the front camera while the new one configures it.
- Before this branch the teardown was short. The recording widens the window to seconds.
- Fix options: hold Done like Next Take, or have the Script screen's Start wait for the previous host's `isTornDown`.
- Where: `Earwig/ViewModels/ScriptDetailViewModel.swift` (`endTake`, `startTake` guard `take == nil`), `Earwig/Services/TakeHost.swift:466-488`, `Earwig/Views/Prompt/PromptView.swift` bottom (Done always shown).

**C2 — WARNING: two scripts with the same title share a recordings folder, so kept recordings get overwritten.**
- `RecordingStore.url(scriptTitle:step:take:video:)` names the file only by title, step and take. It deletes any file already at that path, and it does so when the `TakeHost` is created, before Start or Cancel.
- With Keep Recordings on, two scripts with the same title (or a script deleted and re-imported, whose take numbers restart at 1) silently replace each other's "Step 1 Take 1.mov". The older take's `recordingPath` then points at the other script's file.
- Where: `Earwig/Services/RecordingStore.swift:15-21`, called from `ScriptDetailViewModel.takeRecording` (about line 186).

**C3 — WARNING: a video take whose camera never delivers a frame after Start loses all its sound.**
- `TakeRecording.stopVideo` does nothing until the writer exists (`guard video, let writer`). So an interruption or `runtimeErrorNotification` during framing is dropped, and nothing tells the writer the video has ended.
- After Go, `writeAudio` holds the sound in `pending` (capped at 300 buffers, about 6 s, oldest dropped) waiting for a first frame that never comes. `end()` finds no `sessionStart` and returns nil, and Finished says "Nothing was recorded." Decision 9 says the sound carries on.
- A related case: when `stopVideo` arrives before the first frame, `videoEnded` is set but `pending` is never flushed. The sound up to that point is lost.
- Where: `Earwig/Services/TakeRecording.swift:139-145` (`stopVideo` guard), `:327-339` (pending hold), `:252-263` (`RecordingWriter.stopVideo`).

**C4 — SUGGESTION: Play Video is offered for a `.mov` with no picture.**
- `canPlayVideo` is `result.video == true && (videoStoppedAt ?? 1) > 0`. When video stopped before the first frame (C3, or `cameraMissing` in the simulator), `videoStoppedAt` stays nil but `video` is true. Finished then offers Play Video for a file with no video track.
- Where: `Earwig/ViewModels/PromptViewModel.swift` (`canPlayVideo`), `Earwig/Services/TakeRecording.swift:258-261`.

**C5 — SUGGESTION: three gaps against the plan's decisions.**
- **Decision 9:** locking the phone produces `.videoDeviceNotAvailableInBackground`, which is mapped to "Earwig left the screen". The plan's "the phone was locked" is never shown. (`Earwig/Services/CameraCapture.swift`, `interrupted(_:)`)
- **Decision 4:** the preview is meant to show while the take gets ready behind it. In fact the camera is prepared only after listening has started, and `CameraCapture.device` is not observed. So the "video.slash" placeholder stays up until `readyToGo` happens to trigger a redraw. (`Earwig/Services/TakeHost.swift` `readyListeningAndCamera`, `Earwig/Views/Prompt/FramingView.swift:15`)
- **Decision 10:** the plan puts the dropped mic buffers and the thermal state on `TakeSummary`'s line. The line gains only the recording mode; the drops and thermal state go on a separate `recording: finished …` log line. (`Earwig/Services/TakeSummary.swift:86`)

**C6 — SUGGESTION: the recording dot stays after the recording fails.**
- `showsRecordingDot` depends only on `recordingSince` and the running phase. After `onFailed` the dot and timer go on although nothing is being recorded.
- The sound-only icon is chosen by matching the note's text (`hasPrefix("Video stopped")`), which is fragile.
- Where: `Earwig/ViewModels/PromptViewModel.swift` (`showsRecordingDot`, `recordingSoundOnly`).

**C7 — SUGGESTION: a doc comment was split from its function.**
- The new `TakeRecordingChoice` struct and `takeRecording(...)` were inserted between `endTake()` and its comment ("Closes the Prompt screen; a take still running is stopped and recorded so."). That comment now sits on the private struct, and `endTake()` has none.
- Where: `Earwig/ViewModels/ScriptDetailViewModel.swift:160-197`.

Files reviewed in full: `Earwig/Services/TakeRecording.swift`, `Earwig/Services/CameraCapture.swift`, `Earwig/Services/RecordingStore.swift`, `Earwig/Views/Prompt/FramingView.swift`, `Earwig/Views/Prompt/PlaybackView.swift`, plus the diffs of `TakeHost.swift`, `AudioEngineHost.swift`, `ScriptTakeRecorder.swift`, `PromptViewModel.swift`, `ScriptDetailViewModel.swift`, `PromptView.swift`, `ScriptDetailView.swift`, `SettingsView.swift`, `project.yml` and `Info.plist`. The test files were skimmed only. The only uncommitted change is `progress.md` (checklist ticks).

### Tests

Test review of take-recording against main. I read the committed test diff and all of TakeRecordingTests.swift. There are no staged, unstaged or untracked test changes. I also read TakeRecording.swift, RecordingStore.swift, and the diffs of TakeHost, ScriptTakeRecorder, PromptViewModel, ScriptDetailViewModel, AppSettings and TakeSummary.

Overall the tests are well aimed. TakeHost's new paths are covered with a small fake: started at the slate, waiting for Go, cancelling on the preview, the camera failing, the video stopping or the writer failing mid-take. RecordingStore's keep/replace logic has clear, focused tests. The main gaps are the SwiftData side of recording and Next Take keeping the chosen recording. Both are pure logic and the plan lists them as tests to write.

**T1 WARNING: ScriptTakeRecorder's new recording logic has no tests.**
- `Earwig/Services/ScriptTakeRecorder.swift:32-60`
- What is untested:
  - `started(at:)` setting `take.recordingPath`.
  - `forget(_:)` clearing `recordingPath` on earlier takes whose file the store just deleted. This is a `#Predicate` fetch, so it is easy to get wrong.
  - `recordingFinished(nil)` discarding the file and clearing the path.
- All of it runs with an in-memory `ModelContainer` and a `RecordingStore` in a temp folder, as `RecordingStoreTests` already does.
- Where to add it: `EarwigTests/ScriptDetailViewModelTests.swift:116` (`aTakeIsRecordedAtItsSlateAndFinishedAtItsEnd`) is the place to extend. One test would do: two takes with keep off, the first take's `recordingPath` becomes nil; then `recordingFinished(nil)` clears the second.
- Related host gap: TakeHost calling `recorder.recordingFinished(nil)` when the take started but the capture gave nothing back (`TakeHost.swift` tearDown, `if startedAt != nil`) is also unexercised. `FakeCapture.finish()` only returns nil when `start` was never called. One assertion would cover it, e.g. `recorder.recordings == [nil]` with `capture.result = nil`.

**T2 WARNING: Next Take keeping the chosen recording is not tested.**
- `Earwig/ViewModels/ScriptDetailViewModel.swift:161-201` (`takeRecording`, `nextTake` at 203)
- The plan's step 3 lists ScriptDetailViewModelTests for "the recording in the setup, Next Take keeping it", but that file is unchanged on this branch.
- The existing `onTheScreenAloneATakeStartsWithNothingRendered` (`EarwigTests/ScriptDetailViewModelTests.swift:65-87`) already checks that Next Take keeps the mode against a changed setting. The same few lines could check `setup.chosenRecording` / `setup.recording` for `.sound`.
- It also matters that Next Take keeps `chosenRecording` and not the fallback mode. A take that fell back to sound because space was low should try video again on the next take.

**T3 SUGGESTION: the camera-failure test does not check that everything is released.**
- `EarwigTests/TakeHostTests.swift:249-257` (`aCameraThatCannotStartRecordsNoTake`)
- It checks the phase and that no take was recorded. It does not check `capture.finishes == 1` or `session.deactivated == 1`.
- That is the point of the fail path through `tearDown()`: the camera and the session are let go. The cancel test at 234 does assert this, so this test could too.

**T4 SUGGESTION: the writer tests depend on timing and could be flaky on a loaded simulator.**
- `EarwigTests/TakeRecordingTests.swift:55-79, 145-156`
- `feed` hands over frames with `usleep(4_000)` and relies on the writer dropping frames it is not ready for. `finish` hands over the late media after a fixed 50 ms sleep.
- `theEndWaitsForLateFrames` then expects the video track to be within 0.1 s (3 frames) of 1.0 s. If the last frames are dropped as not ready, the end waits the full 3 s `endWait` and the track comes out short.
- Possible fixes: widen the tolerance, or have the last few frames wait until the writer is ready.

**T5 SUGGESTION: two writer tests overlap.**
- `EarwigTests/TakeRecordingTests.swift:106-125` and `145-156`
- `videoStartsOnAFrameWithTheSoundBeforeItTrimmed` already hands over frames after the end is asked for (1.2 to 2.2 past an end of 1.6). `theEndWaitsForLateFrames` covers the same path and only adds the video-track duration check.
- Adding `#expect(abs(video.duration.seconds - 1.5) < 0.1)` to the first test would let the second go. That is one fewer real-file writer test, and these are the slowest and most timing-sensitive tests here.

**T6 SUGGESTION: a small pure branch in the writer is untested.**
- `Earwig/Services/TakeRecording.swift:420-433`
- `RecordingWriter.monoCopy` has an interleaved branch (stride > 1) that no test reaches; `micBuffer()` is always non-interleaved mono.
- It is pure and cheap to test: a 2-channel interleaved buffer in, the first channel out. Do this only if the device's mic tap can actually deliver interleaved buffers; otherwise the branch could be removed.

**T7 SUGGESTION: the settings round-trip test adds little.**
- `EarwigTests/AppSettingsTests.swift:28-35` (`theRecordingSettingsAreKept`)
- It only checks the UserDefaults setters round-trip.
- The non-trivial part of the new getters is falling back on a stored value they do not recognise (`flatMap(init) ?? .off` / `.hd1080`), which `theModeIsKept` tests for the mode. Swap the round-trip for one "nonsense" fallback check per enum, or drop it.

**T8 SUGGESTION: one PromptViewModel test checks two properties under one name.**
- `EarwigTests/PromptViewModelTests.swift:48-56` (`theDotShowsWhileRecording`)
- It also checks `recordingSoundOnly`, which the name does not mention.
- Rename it, or split the two `recordingSoundOnly` expectations off. Keep it within the existing test count either way.

No other issues. The volume of tests is proportionate: about 460 lines for roughly 1,000 lines of new non-view logic. The PromptViewModel and TakeSummary additions are compact and well aimed.

### Assessment

- C1 — FIX: real; `PromptViewModel.canTakeAgain` waits for `isSavingRecording` but Done does not, and `ScriptDetailViewModel.startTake` only guards `take == nil`. Hold Done while the recording is saved, as Next Take is.
- C2 — FIX: real; `RecordingStore.url` removes any file at the name when the take is set up. Never delete there: when the name is taken, add " 2", " 3" … so no recording is overwritten.
- C3 — FIX (part): real. Remember a camera interruption during framing and stop the video at Start (as for the simulator's missing camera); and when the video stops before its first frame, start the file on the held sound and write it. No frame-arrival timeout (a camera that runs but never delivers is not seen).
- C4 — FIX: set `videoStoppedAt` to 0 when the video stops before a frame, so `canPlayVideo` is false.
- C5 — FIX (part): prepare the camera before listening and publish when it is ready, so the preview shows while the take gets ready (decision 4); say "the phone was locked or Earwig left the screen", as iOS reports both the same. The summary line (decision 10) stays as built: the drops and thermal state are on the recording's own line, recorded in Results.
- C6 — FIX: clear the dot when the recording fails; a `videoStopped` flag in place of matching the note's text.
- C7 — FIX: move the comment back onto `endTake()`.
- T1 — FIX: one ScriptTakeRecorder test (two takes with Keep off, the first's path cleared; `recordingFinished(nil)` clears the second); one TakeHost assertion for `recordingFinished(nil)` after a take that started.
- T2 — FIX: extend the screen-only test to check Next Take keeps the chosen recording against a changed setting.
- T3 — FIX: add `capture.finishes == 1` and `session.deactivated == 1`.
- T4 — SKIP: three full runs passed; the timing is inside a fixed in-process feed. Revisit if it ever fails.
- T5 — FIX: fold the late-frames check into `videoStartsOnAFrameWithTheSoundBeforeItTrimmed` and drop `theEndWaitsForLateFrames`.
- T6 — SKIP: the phone's tap gives standard non-interleaved float (48 kHz, seen in device check 1a); the branch is a guard, and a test of it costs more than it tells.
- T7 — FIX: swap the round-trip for a nonsense-value fallback check per enum.
- T8 — FIX: rename to say it covers the sound-only icon too.

### Outcome — 2026-11-08

- C1 — fixed: Done is held, as Next Take is, while the recording is saved (`PromptView`).
- C2 — fixed: `RecordingStore.url` never deletes; a name already taken gets " 2", " 3" … (test `aNameAlreadyTakenIsNeverWrittenOver`).
- C3 — fixed (part): a camera interruption while framing stops the video at Start; video stopped before a frame starts the file on the held sound (test `videoStoppedBeforeAnyFrameKeepsTheSound`). No frame-arrival timeout.
- C4 — fixed: `videoStoppedAt` is 0 when the video stopped before a frame, so Play Video is not offered.
- C5 — fixed (part): the camera is prepared before listening and `TakeHost.cameraReady` shows the preview; the interruption reads "the phone was locked or Earwig left the screen". Not done: the summary line, as the drops and thermal state are on the recording's own line.
- C6 — fixed: a failed recording clears the dot; `TakeHost.videoStopped` replaces matching the note's text.
- C7 — fixed: the comment is back on `endTake()`.
- T1 — fixed: `ScriptTakeRecorderTests` (two takes with Keep off, then a recording that came to nothing); `aRecordingThatCameToNothingIsGivenBackAsNothing` in `TakeHostTests`.
- T2 — fixed: the screen-only test checks Next Take keeps the chosen recording.
- T3 — fixed: the camera-failure test checks the camera and session are let go, and that listening never started.
- T4 — not done: three full runs passed; revisit if it fails.
- T5 — fixed: the late-frames check folded into `videoStartsOnAFrameWithTheSoundBeforeItTrimmed`; `theEndWaitsForLateFrames` removed.
- T6 — not done: the phone's tap gives non-interleaved float; the branch is a guard.
- T7 — fixed: `anUnknownStoredRecordingReadsAsTheDefault` in place of the round trip.
- T8 — fixed: renamed `theDotShowsWhileRecordingAndTurnsToSoundWhenTheVideoStops`.

## Review pass — 2026-11-09

Findings from `/review-branch` on branch `take-recording`, the range `d16639e..HEAD` only (the commits since the first pass's fixes: the camera behind the text, the one preview, the slider on the preview, Save Video, the console lines, the footers), **unresolved as written**. Each is a claim from a review on that date, not an established fact, and each verdict under *Assessment* is a recommendation, not a decision. Work through them and annotate each with what was done — fixed, or rejected and why. A finding that turns out to be wrong should say so here rather than be deleted.

### Code

Review of `d16639e..HEAD` on `take-recording`, 19 commits. No critical bugs. The build should be fine (I did not build or run tests, as asked).

What I checked and found sound:
- **One preview for the whole take.** In `PromptView.swift` (lines 27-28 and 172-179) `camera(model)` is the first child of the `ZStack`, a single `if` on `showsCamera`. That is `(isFraming && cameraReady) || showsCameraBehindText` (`PromptViewModel.swift` lines 82-90).
  - `TakeHost.begin` (`TakeHost.swift` line 313) sets `phase = .running` synchronously, and `cameraReady` stays true. So nothing renders between framing and running where the condition could be false.
  - The `CameraPreview` UIView therefore stays the same from framing into the running take when Camera Behind the Text is on.
  - `.task(id:)` and `.sheet` now attach once to the `ZStack`, which is an improvement on the `Group`.
- **`AudioEngineHost` completion callback** (lines 155-170).
  - The captures are all Sendable values: `scheduled`, `length`, `delay` (Doubles), `channel` and `token`.
  - `HostClock.now` is nonisolated and is already called from the mic tap, under `SWIFT_VERSION` 5.
  - The token guard runs before the log, so a stopped or replaced buffer's early callback logs nothing.
- **Tick-loop diagnostic** (`TakeHost.swift` lines 506-512): correct. The ticker task runs on the main actor, so a late wake does measure a held main thread.
- **Other requirements are met:**
  - the camera stays behind the text while a video take runs;
  - the camera goes when the video stops or the take finishes, and is never shown for Sound;
  - the text is faded by the shared `@AppStorage` slider, 10-100%, default 35%;
  - the slider is on the framing preview over the opening words;
  - the scrim is gone from `EarwigTheme`;
  - `NSPhotoLibraryAddUsageDescription` is in both `project.yml` and `Info.plist`, for Save Video;
  - the toggle is on by default and fixed for the take through `TakeSetup` and the `Summary`;
  - the footers are one line or none.
- **CLAUDE.md compliance:** colours come only from `EarwigTheme`, the UI text uses UK spelling, and `Engine/` is untouched.

Findings, most severe first:

**C1. SUGGESTION. Verification 4b is only partly recorded.** The plan's Verification 4b asks for two things that the 4b Results do not report:
- the Off leg ("Off: the take looks as before");
- Andy's verdict on "whether seeing himself draws his eye off the line".

The 4b Results cover only Camera Behind the Text on (takes 60-64, "Everything looked good"). This matters because, with the toggle off, the framing preview is now taken down at Start, while the slate or tones play. The Results' own last 4b bullet says taking the preview down holds the main thread about 0.7 s (1080p) to 1.1 s (4K) at a take's end. The same behaviour existed in check 3 before this range, so the risk is low, but the Off path was not re-checked after the `ZStack` change.
- `plans/010-take-recording.md`: Verification 4b (line ~146); Results 4b (lines ~166-171)
- `Earwig/Views/Prompt/PromptView.swift` lines 172-179

**C2. SUGGESTION. Parts of the plan now contradict the amended behaviour.**
- The Scope "Out" list still excludes "a preview during the take, or the text over the camera".
- It also still says Save Video works "with no Photos permission of Earwig's own", but this range adds `NSPhotoLibraryAddUsageDescription`.
- Decision 8 says "Settings says the measured figures", but d5ed82b removed the sizes from the Recording footer, and Settings now states none.
- `plans/010-take-recording.md` lines ~27-31 (Out) and ~67 (decision 8)

**C3. SUGGESTION. The new Following footer says something that isn't true.** "Hybrid speeds the voice up or down to keep the lead; Phrase-gated only waits." reads as if Hybrid does not wait. The earlier text, and the PRD, say Hybrid also waits at every phrase end. A wording such as "Both wait at phrase ends; Hybrid also speeds the voice up or down to keep the lead." would still fit on one line.
- `Earwig/Views/Settings/SettingsView.swift` line 42

**C4. SUGGESTION. The new clamp is never applied in the app.**
- `TakeSettings.textOverCamera` and `clampTextOverCamera` are used only by the tests.
- Both views bind the raw `@AppStorage(TakeSettings.textOverCameraKey)` value, so a stored value outside the range is never clamped. Only the Slider's bounds keep it in range.
- This copies the existing `textSize` pattern, so it is consistent, but the clamp protects nothing in the running app.
- `Earwig/Models/AppSettings.swift` lines 191-202
- `Earwig/Views/Prompt/FramingView.swift` line 16
- `Earwig/Views/Prompt/PromptView.swift` line 17

**C5. SUGGESTION. The framing screen fades the text in more cases than the take does.**
- `FramingView` fades its text whenever `setup.cameraBehindText` is on, including while the `video.slash` placeholder shows (camera not ready, or no device in the simulator).
- The running take fades only when `showsCameraBehindText` is true.
- So the framing text can look dimmer than the take's when there is no picture behind it.
- `Earwig/Views/Prompt/FramingView.swift` lines 43-47
- compare `Earwig/Views/Prompt/PromptView.swift` line 250

### Tests

Test review of d16639e..HEAD. These commits add three test changes: two new PromptViewModel tests (`showsCameraBehindText`, `showsCamera`), one AppSettings clamp test, and two new lines in `theDefaults`. The volume is about right for the change, and the logging-only changes in AudioEngineHost and TakeHost need no tests. There is one real gap and a few small rationalisations.

**T1. WARNING: no test shows that framing ignores the "Camera Behind the Text" setting.**
- In `PromptViewModel.swift:90`, framing shows the camera whatever the setting says: `showsCamera = (isFraming && recording.cameraReady) || showsCameraBehindText`. That is the point of the one-preview change, because with the setting off the framing preview must still appear.
- The only test of the framing case, `EarwigTests/PromptViewModelTests.swift:63`, uses the helper's default `cameraBehind: true`. So a regression that added `setup.cameraBehindText` to `showsCamera` would blank the framing screen for anyone who turned the setting off, and no test would fail.
- Fix: pass `cameraBehind: false` on line 63, or add one expectation with it.

**T2. SUGGESTION: `onePreviewCarriesOnFromFramingToTheTake` overlaps the test above it.**
- Lines 64–65 (running, ready, setting on or off) repeat lines 51–52 of `theCameraShowsBehindTheTextWhileAVideoTakeRuns`, because `showsCamera` just ORs in `showsCameraBehindText`.
- The only new things this test covers are the framing branch (line 63, see T1) and the camera-not-ready case (line 66).
- Fix: cut it to those two framing expectations (with T1's `cameraBehind: false`). Or fold them into the first test as a short `showsCamera` block. That file: `EarwigTests/PromptViewModelTests.swift:61-67`.

**T3. SUGGESTION: the clamp test covers a property the app never uses.**
- `EarwigTests/AppSettingsTests.swift:30-35` tests that `TakeSettings.textOverCamera` clamps its value. But nothing in the app reads or writes that property.
- `FramingView` and `PromptView` use `@AppStorage(TakeSettings.textOverCameraKey)` directly, and the Slider's range is what keeps the value in bounds (`Earwig/Views/Prompt/FramingView.swift:16,82`, `Earwig/Views/Prompt/PromptView.swift:17,250`).
- So the test guards code that has no effect on the app. Either drop the accessor with its clamp and this test, keeping only the default check in `theDefaults`, or have the views use it.
- If it stays, the test checks clamping at both ends but never that an in-range value comes back unchanged (the `textSize` test does check this).

**T4. SUGGESTION: no test checks that the setting reaches the take.**
- `ScriptDetailViewModel.swift:145` copies `AppSettings.take.cameraBehindText` into the take's setup.
- `TakeSetup.cameraBehindText` and `Summary.cameraBehindText` default to `false`, but the setting defaults to `true`. If that copy line were lost, the feature would quietly switch off.
- One `#expect(setup.cameraBehindText == AppSettings.take.cameraBehindText)` would cover it. It fits in the existing `onTheScreenAloneATakeStartsWithNothingRendered` (`EarwigTests/ScriptDetailViewModelTests.swift:76-81`), beside the `recording` check; no new test is needed.

The 7-expectation truth table in `theCameraShowsBehindTheTextWhileAVideoTakeRuns` (lines 49–59) is clear and well focused; it needs no change.

### Assessment

- C1 — FIX (part): say in Results 4b that the Off leg and the eye-line verdict were not reported. Nothing to change in code: with the toggle off, the preview going at Start is what check 3 ran, and the tones then ended 1.8 s after Start (takes 54, 55). A quick Off take is Andy's to give or not.
- C2 — FIX: the Scope's Out list (the preview during the take, and the Photos permission) and decision 8's "Settings says the measured figures" now contradict what was built; correct them.
- C3 — FIX: the footer reads as if Hybrid never waits; use "Both wait at phrase ends; Hybrid also speeds the voice up or down to keep the lead." (`SettingsView.swift:42`).
- C4 — SKIP: real, but it is the same unused accessor and clamp as `textSize` (`AppSettings.swift`, used only by `AppSettingsTests`); the Slider's range bounds the value. Consistent, harmless.
- C5 — SKIP: on the phone the placeholder shows only for the 0.3 s before the camera runs (`camera running` 0.3 s after `camera configured`); fading only with a picture would make the text flash bright, then faint.
- T1 — FIX: `onePreviewCarriesOnFromFramingToTheTake` checks framing only with the setting on; add `cameraBehind: false` to the framing expectation.
- T2 — FIX: with T1, cut that test to the framing expectations (setting off, and camera not ready); its running cases repeat the test above.
- T3 — SKIP: as C4. The clamp test stays with its accessor, like `textSize`'s.
- T4 — FIX: add `#expect(setup.cameraBehindText == AppSettings.take.cameraBehindText)` in `onTheScreenAloneATakeStartsWithNothingRendered` (`ScriptDetailViewModelTests.swift`), so a lost copy line fails a test.

### Outcome — 2026-11-09

- C1 — fixed (part): Results 4b says the Off leg and the eye-line verdict were not reported.
- C2 — fixed: the Scope's Out list notes the preview moved in and the Photos add permission; decision 8 notes Settings no longer states the sizes.
- C3 — fixed: the Following footer reads "Both wait at phrase ends; Hybrid also speeds the voice up or down to keep the lead."
- C4 — not done: the same unused accessor and clamp as `textSize`; the Slider bounds the value.
- C5 — not done: 0.3 s on the phone; fading only with a picture would flash the text.
- T1 — fixed: `framingShowsTheCameraWhateverTheSettingSays` checks framing with the setting off.
- T2 — fixed: that test keeps only the framing expectations.
- T3 — not done: as C4.
- T4 — fixed: the Screen Only take test checks the setting reaches the take's setup.
