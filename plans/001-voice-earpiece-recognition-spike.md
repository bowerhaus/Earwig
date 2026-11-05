# Plan 001: Voice, Earpiece and Recognition Spike

**GitHub Issue:** not yet created (PR must include "Closes #N" once it is)
**Branch:** `voice-earpiece-recognition-spike` (from `main`)
**Goal:** Before building any product code, find out on Andy's iPhone 14 Pro whether the three things Earwig rests on hold up: a voice good enough to follow (Personal Voice, or a downloaded Apple voice) rendered fast enough with usable word timings; his in-ear Bluetooth earpieces staying at music quality (A2DP) while the iPhone's own mic is open; and on-device recognition quick and accurate enough to follow him, on a mount and in a pocket. Find the default lead by feel.

**PRD references:** §2 Technical Specifications, §4.2 Voice Rendering, §4.3 Listening, §4.4 Following (lead), §11 Risks, §12 stage 1.

---

## Why a spike

Every later stage assumes these answers, and none of them can be had from the simulator or the documentation:

- **The voice.** Personal Voice is the presenter's own voice, which is the point of Earwig, but its quality varies with how it was trained and it renders slower than real time on some phones. Apple's downloaded voices (Jamie Premium, Stephanie Enhanced) were judged good in PhysiMate, but for announcements, not for a voice you speak along behind. Whether `write(_:toBufferCallback:)` reports word boundaries for Personal Voice, and in audio time rather than wall time, is also unknown.
- **The earpieces.** With `.playAndRecord` and the mic open, a Bluetooth earpiece can drop into the hands-free profile (telephone quality, its own poor mic). The session asks for A2DP only and the built-in mic, but whether Andy's earpieces honour that is a property of the earpieces.
- **Recognition.** `SpeechAnalyzer` with `SpeechTranscriber` is new in iOS 26. Its delay from a spoken word to a volatile result, and its accuracy outdoors and from a pocket, decide how much lead the engine needs and how forgiving the matcher must be.
- **The lead.** How far ahead the voice should run is a matter of feel. It has to be found by speaking behind it.

If Personal Voice fails, the downloaded voice is v1 and the ElevenLabs import (PRD §13) moves up. If the earpieces cannot hold A2DP with the mic open, the fallback is wired or AirPods. If recognition is too slow or poor in a pocket, the mount becomes the only supported position.

## Deliverable

A throwaway spike screen in the real `Earwig` target (the spike UI is deleted at the end; the project, the audio session code and what survives of the renderer and listener stay):

1. **Voices.** Requests Personal Voice authorisation, then lists Personal Voices first and every installed Apple voice after, each with its language and quality (default, enhanced, premium). Refreshes on `availableVoicesDidChangeNotification`. Pick one to render with.
2. **Render.** Paste a script. It is split into phrases (sentence ends and clause breaks, at most about twelve words) and each phrase rendered with `AVSpeechSynthesizer.write(_:toBufferCallback:toMarkerCallback:)`. Logged per phrase: render time, audio duration, real-time factor, and word start times both from the word markers (audio offsets, from the marker callback or the `willSpeakMarker` delegate, whichever sends them) and from the `willSpeakRangeOfSpeechString` delegate (wall clock, for comparison).
3. **Play.** Rendered phrases play from an `AVAudioEngine` through an `AVAudioUnitTimePitch` node, with a speed slider (0.8x to 1.25x). Audio session `.playAndRecord`, mode default, `.allowBluetoothA2DP` set and `.allowBluetoothHFP` not, preferred input the built-in mic.
4. **Route.** The current output port and input port are always on screen, updated on route change; a red warning when the output is `bluetoothHFP` or the input is not the built-in mic.
5. **Listen.** `SpeechAnalyzer` with an en-GB `SpeechTranscriber` (volatile results, audio time ranges, optional fast results, optional script words as contextual strings) on the built-in mic, downloading the locale assets through `AssetInventory` if needed. Heard words shown live with their delay: the time the word first appeared minus the time it was spoken, from the result's audio time range on the analyser's clock.
6. **Mark.** A large tap-to-mark button: tap as you say a word; the next heard word's delay from the tap is logged, as a check on the computed delay.
7. **Gate.** A simple gated playback: phrase n+1 starts only when the heard position (a forward match of heard words against the script) is within N words of the end of phrase n, with N on a stepper. Shows the voice's phrase, the heard position and the state (speaking, waiting).
8. **Log.** A session log (render times, delays, route changes, interruptions, gate releases) that can be copied or shared from the screen, so the numbers come off the phone.

## Evaluation

On Andy's iPhone 14 Pro (iOS 27.0.1), with his in-ear Bluetooth earpieces, on a real script he pastes. Voices: his Personal Voice, Jamie (Premium, en-GB), Stephanie (Enhanced, en-GB). Positions: the phone on a mount near the camera, and in a pocket; screen locked for about ten minutes; outdoors if he can.

| Criterion | Pass |
|-----------|------|
| Voice quality | Andy would speak along behind it for a two-minute step through the earpiece, and it sounds like talking, not reading |
| Render speed | A two-minute step renders in under a minute on the 14 Pro (real-time factor at most 0.5); slower is marginal, as pre-rendering absorbs it |
| Word timings | Word markers arrive during `write` for the chosen voice, at sample offsets that fall inside the phrase's audio and in order |
| Speed change | 0.85x to 1.2x through the time-pitch node sounds natural |
| Earpiece route | Output stays `bluetoothA2DP` and input `builtInMic` with the mic open, for the whole ten-minute run; music quality by ear |
| Mic hears the earpiece | Words played into the earpiece are not heard by the recogniser when Andy is silent |
| Recognition delay, mount | Median delay from spoken word to first heard at most 1.0 s |
| Recognition delay, pocket | Median at most 1.5 s |
| Accuracy, mount | At least 90% of script words read are heard (volatile or final) |
| Accuracy, pocket and outdoors | At least 80% |
| Background | Playback and recognition continue with the screen locked for ten minutes |
| Lead | Andy names the N (words) that felt right with gated playback |

## Outcomes

- **Pass:** Personal Voice is the presenter's voice in v1 (PRD §4.2), with the downloaded voices as fallback; the default lead is the N Andy chose (§4.4); the risks it settled are marked in §11.
- **Voice marginal or fail:** a downloaded voice (Jamie Premium or Stephanie Enhanced) is the default; Personal Voice stays as an option if it renders at all; the ElevenLabs import (§13) is considered for an earlier stage.
- **Earpiece fail:** the earpieces cannot hold A2DP with the mic open; §11's fallback (wired or AirPods) becomes the supported output and §4.3 says so.
- **Recognition fail in a pocket:** the mount is the only supported position in v1; §4.3 and §11 say so; a lavalier into the phone moves up.

## Steps

1. Create the project: `project.yml` (iOS 26.0, iPhone only, background audio, microphone and speech recognition usage strings; Personal Voice has no documented usage-description key, its authorisation is requested in code), `CLAUDE.md`, `.gitignore`, `.swiftlint.yml` with the `engine_purity` rule. Builds clean with SwiftLint.
2. Implement `AudioSessionManager` (session, route, interruptions), `VoiceRenderer` (phrases to buffers with word timings), `PhrasePlayer` (`AVAudioEngine` with time-pitch), `Listener` (`SpeechAnalyzer` on the mic), a basic `PhraseSplitter` and `WordNormaliser` with tests, and the spike screen with the route, the mark button, gated playback and the log.
3. Installed on Andy's iPhone 14 Pro with `devicectl`; he tries it per the evaluation table; results recorded in this file under **Results**, from his verdicts and the copied logs.
4. Update the PRD (§4.2 voice, §4.4 default lead, §11 risks) to v0.3 with a Document History row.
5. Delete the spike UI; keep the project, the audio session code and whatever of the renderer, player and listener survives.

## Results

### Before the device: simulator check (2026-11-05)

On the iOS 26.5 simulator with its compact Daniel (en-GB) voice, so says nothing about quality or the 14 Pro:

- `write` produces audio (22,050 Hz mono float32) about 7x faster than real time.
- **The `write` marker callback sends no markers.** Word markers arrive through the `willSpeakMarker` delegate instead, one per word, in order. The renderer takes them from whichever source sends them and logs which.
- **`byteSampleOffset` is in bytes**, not samples: four bytes per float frame. Read that way, every word starts inside the phrase's audio, in order.
- The `willSpeakRangeOfSpeechString` delegate is useless for timing during `write`: all its calls for a phrase arrive within a few milliseconds, because rendering runs ahead of real time.

Whether the same holds for Personal Voice and the downloaded voices on the phone is for the device trial.

### On the device

Tested on Andy's iPhone 14 Pro (iOS 27.0.1) with his SK18 in-ear earpiece, 2026-11-05, on a made-up two-step script (the harbour walk, about 230 spoken words). Personal Voice is not yet set up on the phone, so it is untested.

| Voice | Quality | Verdict |
|-------|---------|---------|
| Personal Voice | Personal | Not tested: none set up yet |
| Jamie (en-GB) | Premium | Okay; not fantastic |
| Stephanie (en-GB) | Enhanced | Okay; not fantastic. Andy's pick |

| Criterion | Result |
|-----------|--------|
| Render speed | Pass. Stephanie: 27 phrases, 63.0 s of audio rendered in 1.3 s (RTF 0.02). Jamie: RTF 0.03 |
| Word timings | Pass for Stephanie: 221 of 221 words timed by markers |
| Speed change | Pass: 0.85x and 1.2x through the time-pitch node work and sound okay |
| Earpiece route | At the start of a take, with the mic open: output SK18 (A2DP), input iPhone Microphone (built-in mic). The ten-minute run is still to come |
| Mic hears the earpiece | Pass: a 26-second straight-through take of Stephanie through the SK18 at Andy's normal volume, Andy silent, with mic audio flowing throughout: no words recognised. Listening picked his voice up again at once afterwards |
| Recognition delay, first read | Indoors, phone in Andy's hand. Median 0.92 s from the start of a word to its first appearance, p90 1.33 s (0.67 s and 1.01 s from the word's end); 78 words. Computed from the console after the fact, as the app's own figure (0.52 s) was wrong (below) |
| Recognition, in hand (full read) | Indoors, phone in Andy's hand, whole harbour walk read at presenting pace (222 script words), script words as context, fast results on. Delay median 0.94 s, p90 1.35 s (220 words; 0.72 s and 1.05 s from the word's end). Accuracy 96% (214 of 222 heard in order from the final results); of the 8 misses only 2 were mishearings ("at" as "of", "path climbs" as "paths climb up"), the rest spelling ("sea wall"/"seawall", "three hundred"/"300", "there's"/"there is"), so about 99% with a better normaliser. Two taps on Mark gave 2.3 s and 2.7 s from tap to first appearance; unreliable, as a mark resolves before the final times its words |
| Recognition, pocket (indoors) | Phone locked in Andy's left-hand gilet pocket, indoors, same read. Delay median 0.91 s, p90 1.31 s (220 words; 0.69 s and 1.02 s from the word's end). Accuracy 97% (216 of 222 in order); mishearings "thought" as "talk", "ours" as "hours", a dropped "to" and two stray words, the rest spelling. Listening ran throughout (health line every 5 s for 93 s, engine running, no restarts). No worse than in the hand. Outdoors still to try |
| Lead 3 and lead 2 (gated, Stephanie, indoors) | Andy: "seems okay", but the pauses are too long: after reaching the end of a beat he waits a long time for the next to start. Waits after the voice finished a phrase averaged 1.26 s at lead 3 and 1.41 s at lead 2, the longest 3.5 s, mostly at sentence ends. Recognition while following the voice: median 0.93 s and 0.96 s, accuracy 98% in both. Cause: the gate opens on the recogniser hearing the release word, about 0.9 s (two to three words) after it is said, so at lead 2 the presenter has already finished the phrase. Leads 4 and 5 still to try |
| Recognition, staying on | After fixing the input timestamps (below), listening ran for the whole session; results stopped only when Andy stopped speaking |

**Recognition findings (device, iOS 27.0.1):**
1. **Never stamp the analyser's input.** Feeding `AnalyzerInput(buffer:bufferStartTime:)` with a start time counted from frames ended the results after a few seconds with "audio input timestamp overlaps or precedes prior audio input". Untimed input is taken as contiguous and works.
2. **Interim (volatile) results carry no word times.** Each is one run for the whole stretch since the last final, timed from the end of that final (pause included) to the end of the audio so far, rewritten on every result. Finals time every word, but arrive only at a pause, about 1 s after its last word.
3. So a word's delay is measured as its first appearance in an interim result (by its place in the block) against its start time from the final. The follow engine must match on interim text by order, not by time; exact word times arrive too late to follow by.
4. The normaliser (stage 3) must fold compounds ("sea wall" and "seawall") and contractions ("there's" and "there is") as well as numbers; the recogniser writes numbers as digits ("4 miles", "300 feet").
5. Device markers: Stephanie sends word markers through both the `write` marker callback and the `willSpeakMarker` delegate (the simulator's compact voice used only the delegate), `byteSampleOffset` in bytes.
