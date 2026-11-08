# Plan 010: Record a Take, with Sound or Video, and Play It Back

**GitHub Issue:** [#16](https://github.com/bowerhaus/Earwig/issues/16) (PR must include "Closes #16"). Its title and acceptance criteria were updated to this plan on 2026-11-08: video added, the earpiece's audio not recorded.
**Branch:** `take-recording` (from `main` at `efd0e86`, after plan 009 merged)
**Status:** Planned (2026-11-08).
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
- a preview during the take, or the text over the camera (Andy chose framing before the take only);
- a list of past recordings on the Script screen, or playing an older take's recording. A take records where its file is (decision 6), so a later plan can add it;
- Earwig saving to Photos itself. The share sheet's Save Video does it, with no Photos permission of Earwig's own;
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

5. **While recording, a dot and the time.** The Prompt screen's top row shows a red dot (a new `EarwigTheme.recording`) and the minutes and seconds recorded, for Sound and Video. When video stops early (decision 9), the dot shows the sound-only icon.

6. **The files: Earwig's folder in Files, the last take always, every take if kept (Andy, 2026-11-08).** Andy is not sure recordings need keeping, since they are for checking a performance, not for use, but wants the option left open.
   - Files go in the app's Documents, shown in the Files app (On My iPhone › Earwig), with `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` in `project.yml`: `Recordings/<script title>/Step 3 Take 2.mov` (or `.m4a`), named as the slate says it.
   - **Keep Recordings**, a switch in the Recording group, default off. Off: when a take's recording starts, the recording before it is deleted, so only the last take's is on the phone. On: every recording is kept.
   - Settings shows how much the recordings take up, with **Delete All Recordings**, which asks first.
   - `Take` gains `recordingPath: String?` (relative to Documents), an optional property, a lightweight change to the store. It is set when the recording starts and cleared when its file is deleted, so a later plan can list takes with their recordings.
   - Before a video take, if the phone has under 1 GB free (`volumeAvailableCapacityForImportantUsage`), the take records sound only and says so. A writer that fails mid-take stops recording, the take carries on, and Finished says why.

7. **Play Back and Share on the Finished screen.** When the take was recorded, Finished adds **Play Back** and **Share** above Next Take and Done. For a video take, Play Back is two buttons, **Play Video** and **Play Sound** (Andy, 2026-11-08: the option of the sound alone). Play Sound plays the file's sound track alone, from a composition of that track, so no picture is decoded.
   - Play Back opens a sheet with `VideoPlayer` (AVKit) for both video and sound, with its own play, pause and scrub, and Done. The take has let the audio session go by then. Playback sets the category to `.playback`, so it is heard on the earpiece or the speaker, whichever is connected; Next Take configures the session for a take again, as it always does.
   - Share is the share sheet with the file: AirDrop to the Mac, Save Video to Photos, Save to Files.
   - Only what was said is in the file (Out). Mixed or one-ear playback of the earpiece is not needed.

8. **Quality: 1080p30 by default, 4K30 as a setting (Andy, 2026-11-08).** 1080p is enough for checking a performance (about 60 MB a minute in HEVC); 4K30 is for a take meant for use (about 170 MB a minute), matching the Osmo. A **Video Quality** picker in the Recording group. The front camera of the iPhone 14 Pro does both.

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
  3. **Video on the mount, With Voice and Screen Only.** Frame on the preview, Start, read a step, Play Back. Andy's verdicts on framing, on the dot and time, and on the picture and sync at 1080p. The take's waits against a take with recording off.
  4. **4K30.** The same at 4K30; the file's size; Share to the Mac by AirDrop and Save Video to Photos.
  5. **Locked mid-take.** Lock the phone during a video take and unlock it at the end. The voice carries on, Finished says when the video stopped, and the file has the sound to the end.
  6. **Keeping.** With Keep Recordings off, two takes leave one file; on, two takes leave two. Settings shows the size, and Delete All empties the folder.

## Results

To be filled in.
