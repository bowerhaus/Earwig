# Earwig - Product Requirements Document (PRD)

**Status:** Draft v0.13, 2026-11-09. Changes by version are in the Document History at the end.
**Name:** Earwig (decided 2026-11-05: UK slang for listening in). Bundle identifier `com.bowerhaus.Earwig`.

## Executive Summary

Earwig is a personal iPhone app that reads a script into one ear, slightly ahead of the
presenter, and follows what the presenter actually says. The presenter speaks a few words
behind the voice in their ear; when they slow down, the voice slows; when they stop or
wander off the script, the voice waits at the end of its phrase and picks them up again
where they are. The script is text from elsewhere (first of all a Cutaway project's
`script.md`), turned into speech on the phone in a downloaded Apple voice (Stephanie by
default; the presenter's own recorded reading or a cloud voice later, made on the Mac), with
word timings, before the take starts.

The same script and following engine also drive an on-screen teleprompter: every take
scrolls the script on the phone at the presenter's pace, with the voice in the earpiece or,
in Screen Only, without it (plan 008).

Earwig is for the author's own video work (the Cutaway toolkit's videos, filmed on an
Osmo Pocket 3 or the iPhone itself), and the author's builds reach his phone through
TestFlight, in the mould of Brollee, Reclaim and PhysiMate. Its source is public and
source-available (section 2, Licence), and an App Store version at a low price is planned,
for people who would rather not build it (plan 011).

---

## 1. Product Overview

### 1.1 Vision

Learn nothing by heart and never look at a card. Put one earpiece in, press Start, say
the slate, and talk; the words arrive a beat before you need them, at your pace, and the
take sounds like you talking, not reading.

### 1.2 Problem Statement

- A teleprompter needs the eyes on a screen near the lens. On a beach, on a walk, or at a
  desk shot framed wide, there is nowhere to put one and the eye line shows.
- Learning a script by heart is slow and the delivery goes flat. Reading it off a card is
  worse.
- A human ear-prompter operator (the broadcast practice: an earpiece and someone reading
  the script in, waiting when the presenter pauses) is the right experience but needs a
  second person and a script read aloud by someone else.
- Recorded "read it yourself, play it back" prompting runs at a fixed pace and cannot
  wait, so a fluff or a pause for a dog, a wave or a passer-by puts it out of step with
  no way back.
- Cutaway already has the script, in a known format, on the Mac. Getting it into the ear
  should be a paste, not a typing job.

### 1.3 Target Users

- The author, presenting to an Osmo Pocket 3 (and sometimes the iPhone's own camera) with
  a small in-ear Bluetooth earpiece and the iPhone either on a mount beside the lens or
  in a pocket.
- Others later, through the planned App Store version, or by building the public source
  (plan 011). In v1 TestFlight is the author's install path, not a distribution channel.

### 1.4 Non-Goals

- Not a script editor. Scripts are written elsewhere (Cutaway, a text file). Earwig
  parses, shows and plays them; a rewrite is a new paste.
- Not a camera app in v1. The camera is the Osmo. Since plan 010 Earwig can film a take
  itself with the front camera, for checking a performance (4.7); the stock Camera app is
  still no use with it, since it takes the audio session and silences Earwig. Filming meant
  for use, with framing aids and the files to Photos, is a later phase (section 13).
- Not a transcription or editing tool. What Earwig hears is used to follow the
  presenter, not kept, in v1. A take record for Cutaway is on the roadmap (section 13).
- Not a cloud product. No accounts, no server, no API keys in the app. Cloud voices, if
  ever, are rendered on the Mac by Cutaway and imported as files (section 13).
- No beam-splitter rig support (mirrored text), no Bluetooth pedals or remotes, no iPad,
  no Apple Watch, in v1.

---

## 2. Technical Specifications

| Requirement | Specification |
|---|---|
| Platform | iOS 26.0 or later, iPhone only (`TARGETED_DEVICE_FAMILY` 1). The author's phone is an iPhone 14 Pro on iOS 27.0.1. iOS 26 is the floor because the on-device speech API introduced there (`SpeechAnalyzer` and `SpeechTranscriber`) is the recogniser; the siblings' iOS 17 floor does not apply. |
| Language and UI | Swift, SwiftUI, MVVM with `@Observable`, Swift Concurrency. |
| Persistence | SwiftData for scripts and takes; settings in `UserDefaults`. Rendered audio is held in memory, not saved (plan 004): a step renders in about a second. The `Rendering` entity is kept for imported renderings (6.2). |
| Project | XcodeGen from `project.yml`; never hand-edit the generated `.xcodeproj`, which is git-ignored. Version and build number live in `project.yml`. |
| Tests | Swift Testing (`import Testing`). The follow engine and the script parser are pure Swift and fully unit-tested with fixture word streams. |
| Lint | SwiftLint, with an `engine_purity` custom rule as PhysiMate's: `Engine/` imports no UI, audio, persistence or Combine framework. |
| Dependencies | None. Apple frameworks only: AVFoundation (`AVSpeechSynthesizer`, `AVAudioEngine`, `AVAudioSession`), Speech (`SpeechAnalyzer`, `SpeechTranscriber`), SwiftData. |
| Distribution | TestFlight, uploaded by `scripts/release/testflight.sh`; cloud-managed distribution signing; the script refuses a dirty tree, a stale project or a build number already tagged, and tags `testflight/<version>-<build>`. Builds expire after 90 days. A release on GitHub is an annotated tag `vX.Y.Z` on `main` with notes, marked pre-release until 1.0, with no binary, since an app installs only when signed for the device (plan 011). An App Store version is planned, as a later stage. |
| Licence | PolyForm Noncommercial 1.0.0, with an additional permission to use the app to make videos, recordings and other works for any purpose, commercial ones included (`LICENSE`). |
| Keys | The app has none: no cloud, no accounts. The only key is the App Store Connect API key (a team key with the Admin role, which cloud-managed signing needs) and only the release script uses it. It lives in the macOS Keychain, not in a file: service `bowerhaus.appstoreconnect`, items for the key ID, the issuer ID and the base64 `.p8`, stored once by running the command the script prints, in the author's own terminal (Claude never handles a key's value). At upload the script writes the key to an owner-only temporary file for xcodebuild and deletes it on exit, success or failure. Named for the team, not the app, so PhysiMate's script can read the same item when it is upgraded to this. |
| Background | `UIBackgroundModes: audio`. A take runs with the screen locked and the phone in a pocket. |
| Privacy strings | Microphone ("Earwig listens to you so the prompt keeps pace with what you say") and speech recognition. Personal Voice needs its own authorisation request. |
| Spelling | UK spelling in UI text and code names. |

### External Dependencies

None at run time. Development needs Xcode 27 or later, `xcodegen`, `swiftlint`.

---

## 3. Core Concepts

| Term | Meaning |
|---|---|
| **Script** | A text imported into Earwig, kept with its source text, its format (plain or Cutaway) and a hash so a re-paste of the same text is recognised. |
| **Step** | A numbered section of a script. From Cutaway's `script.md` a step is `## N. Title`; plain text has one step per blank-line-separated block, or a single step. Takes are started from a step. |
| **Line** | A spoken sentence or item within a step. In Cutaway's format, each `- ` item under `Says:`. |
| **Direction** | Text in a step that is not spoken by the presenter: a step's title and `Shows:` field, anything in brackets inside a line, a `Footage:` or `Open:` field. Directions are never matched against what the presenter says. Some are read as cues (section 4.2). |
| **Phrase** | The unit of playback and gating: a line split at sentence ends and, in a sentence of more than about twelve words, at clause breaks (commas, dashes, semicolons, colons), packing clauses into phrases of up to twelve words. A clause itself is not cut unless it is longer than twenty words, since a cut with no punctuation sounds like a full stop (plan 009). The voice can only wait at a phrase boundary. |
| **Rendering** | A phrase's audio in one voice, with the start time of every word in it. The phrases of the step a take starts from are rendered when the step is chosen, and kept in memory while the app runs by voice, rate and text (plan 004). |
| **Lead** | How far ahead of the presenter the voice runs, set in words, with the equivalent in seconds shown: the head start the presenter feels, since the engine allows for the recogniser's delay itself (5.4). Default 5, the author's pick against 3 on real takes in plan 005. |
| **Position** | Two positions in the script, both as a word index: the voice's (where playback is) and the presenter's (the last script word confidently heard). The engine's job is to keep the difference near the lead. |
| **Cue voice** | A second, clearly different voice (an Apple voice, never the presenter's) that reads directions and slates so the presenter knows at once that it is not a line. |
| **Take** | One attempt at a step, numbered from 1 for that step within the script. The slate says it. |
| **Mode** | Ear (spoken prompt), Screen (scrolling text), or both. Each follows the presenter; Screen can also run at a fixed pace. |

---

## 4. Core Features

Priorities: P0 is v1, P1 should follow soon, P2 is nice to have.

### 4.1 Scripts

| Feature | Priority | Notes |
|---|---|---|
| Import by paste from the clipboard (Universal Clipboard from the Mac) | P0 | The Scripts screen has a Paste button, Earwig's own in the accent yellow (plan 004: SwiftUI's `PasteButton` avoided the Allow Paste prompt, but iOS darkens its tint to gold-brown to keep its white text legible). iOS asks Allow Paste until Settings › Apps › Earwig › Paste from Other Apps is set to Allow, once; Earwig detects the format (Cutaway when the text has a `## ` heading and a `Says:` field) and names the script from its title or first line. The clipboard must hold the script's text: a `script.md` copied as a file in Finder pastes only its name (plan 002). |
| Parse Cutaway `script.md` (`cutaway/script@1`) | P0 | As Cutaway's own parser, but lenient: a misnumbered or unnumbered step is kept, not an error. Title `# Script: X` (prefix optional), the first such line before the first step; steps `## N. Title`; `Says:` items (`- `, `* `, `+ `) are lines; `Shows:`, `Footage:`, `Open:` and an old `Notes:` are directions; fields may be bold; a source span in round brackets at the end of a line is stripped; run-on indented lines are joined. Text before the first step is kept as a preamble, shown, never spoken. Unknown lines are kept as directions. |
| Parse plain text | P0 | Blank-line-separated blocks are steps (no blank lines: one step); a block's first line is its title if it has at most eight words, no sentence-ending punctuation and more lines after it. The script's title is a leading `# ` line, or a first block that is only such a title line, or else the first line cut to 40 characters. |
| Directions inside a line | P0 | Square brackets only, in both formats: `[Gesture to the boats]` is a direction at that point, read in the cue voice. Round brackets are spoken. |
| Show a script as its steps with each step's lines and directions | P0 | Read-only. The start-from-step picker lives here. |
| Re-paste replaces a script's text, keeping its takes | P0 | The same text (line endings and trailing spaces aside) opens the stored script. A paste whose stated title (a `# ` line, or a plain script's lone title line) matches a stored script's, ignoring case, replaces that script's text and keeps its takes, renderings, cues setting and start step; a title taken from a first line or first step never replaces another script. The Script screen has Paste new version for a script whose title changed. Unchanged phrases are not rendered again while the app runs (plan 004). |
| Delete a script | P0 | Swipe on the Scripts screen, or Delete Script at the foot of the Script screen, which asks first. Samples cannot be deleted. |
| Built-in samples | P0 | Four made-up scripts, *The Harbour Walk*, *The Weekend Loaf* and *The Old Watermill* (Markdown) and *The Seaside Pier* (plain text), always in a Samples section below the presenter's own scripts (plan 011). Seeded at launch as stored scripts with a `sampleID`, so their takes are kept; a later build's new text replaces a sample's, keeping its takes; a script of the presenter's own with a sample's exact text becomes that sample. A paste titled like a sample is a new script, never a replacement. The format is labelled Markdown, not Cutaway, wherever the presenter sees it. |
| Import from the share sheet and Files, and a pasted file | P1 | After paste proves the flow. Includes a `script.md` copied as a file in Finder, which today pastes only its name. |
| Watch an iCloud Drive folder so a Cutaway project's script appears by itself | P2 | Roadmap, section 13. |

### 4.2 Voice Rendering

| Feature | Priority | Notes |
|---|---|---|
| Render the take's step before it starts, with word timings | P0 | `AVSpeechSynthesizer.write(_:toBufferCallback:toMarkerCallback:)` for the audio; the word boundaries come from word markers, by the marker callback or the `willSpeakMarker` delegate (whichever the voice sends), with `byteSampleOffset` in bytes. The `willSpeakRangeOfSpeechString` delegate is no use for timing during `write`, which runs far ahead of real time (plan 001). Stephanie renders about 20 to 50 times faster than real time on the iPhone 14 Pro (plan 004: a 22 s step in 0.8 to 1.1 s, every word timed), so the start step is rendered, with progress in the Script screen's row, as soon as the script opens or another step is picked, and held in memory while the app runs. Nothing is saved; whether to is reconsidered for a voice that renders slowly. |
| Presenter's voice: Apple downloaded voices | P0 | Stephanie (Enhanced, en-GB) is the default, the author's pick in plan 001 ("okay, not fantastic"); any English voice of Enhanced quality or better can be picked instead (plan 004, in the Script screen's menu until Settings). iOS 27 puts the quality in a voice's name ("Stephanie (Enhanced)"), which the voice list allows for. A better voice is wanted (section 15). |
| Personal Voice | Dropped | Tried in plan 004: "the voice quality is actually terrible. It sounds like some cross between me and the built-in voices", and it rendered about 2.3 times faster than real time against Stephanie's 20, though it timed every word. It can still be picked once allowed, but is never the default or the cue voice. The presenter's own recorded reading, or a cloud voice, made on the Mac and imported (section 13), is the route to a better voice. |
| Cue voice for slates and directions | P0 | An Apple voice, by default the best en-GB voice that is not the presenter's, the other gender first (Jamie, Premium, with Stephanie). The slate reads the step's number and title, then its `Shows:` text, then the slate ("Step 3. Rosie up ahead. Rosie trots far ahead up the long track. Step 3, take 2."); a shot ID is spelled out ("W 3 1"). A per-script switch turns cues off. Cues are never matched. |
| Directions inside a line | P0 | A setting (plan 004): **Chime**, the default, plays a low soft pong (0.8 s, about −14 dBFS) at that point, which rings on under the next line while the voice waits only 0.25 s; **Spoken** reads the direction in the cue voice there, and the take waits for it. A spoken direction leaves its own length as a gap in the take (about 1.4 s for "Gesture to the boats"), which is why the chime is the default. Reading the step's inline directions in the slate was tried and dropped: several would be hard to remember. |
| Rate | P0 | The render uses the synthesiser's default rate (0.5). A **voice speed** in Settings, 0.8x to 1.0x, default 0.95x (plan 005: at 1.0x the voice was "still too quick", phrase-gated as well as hybrid), is the base the player plays the voice at; the engine's pacing speeds multiply it, and cues, the slate and the tones stay at 1.0x. 0.85x to 1.2x through the time-pitch node sounded natural in plan 001. A base rate per voice is for stage 7 (#14). |
| Import a rendering made elsewhere | P2 | A folder of phrase audio and a timings file, as Cutaway could produce with ElevenLabs or from the presenter's own recording (section 13). |

**Why pre-render.** The synthesiser cannot change speed mid-utterance, a slower voice
may render near real time, and a future cloud or recorded voice arrives as files. Rendering everything to buffers up front makes the player and the
engine indifferent to where the voice came from, and makes the take itself free of
synthesis latency.

### 4.3 Listening

| Feature | Priority | Notes |
|---|---|---|
| On-device continuous recognition of the presenter | P0 | `SpeechAnalyzer` with a `SpeechTranscriber` in the script's locale (en-GB), volatile and fast results on, with audio time ranges, the script's words as contextual strings. The mic audio is fed untimed (stamping it made the analyser stop with "audio input timestamp overlaps or precedes prior audio input"). Interim results come as one untimed block of text per stretch of speech, rewritten as it grows, about 0.9 s behind the presenter; finals time every word but arrive only at a pause. So the engine follows the interim text by word order and takes exact times from finals. Listening restarts itself if its results fail, at most once in ten seconds; if it fails again, or the restart cannot start, it gives up and the take stops, saying so (plan 006). The audio engine restarts on a configuration change. Locale assets are downloaded once through `AssetInventory` with a prompt. |
| The iPhone's own microphone, always | P0 | The audio session is `.playAndRecord` with Bluetooth allowed for A2DP output only (never the hands-free profile), and the preferred input set to the built-in mic. The earpiece is never the microphone: the hands-free profile would drop its audio to telephone quality and use its poor mic. |
| Route check during a take | P0 | The Prompt screen shows the output route and input in use while a take runs, red if the earpiece has fallen into the hands-free profile or the input is not the built-in mic, amber on the phone's speaker ("Speaker: the mic will hear the voice"; the take still runs, for trying the screen at a desk). An earpiece that goes mid-take holds the voice; on the SK18, put away in its case, it came as an interruption instead, which ends the take (plan 005; the author: "stopping is fine"). |
| Runs locked and in a pocket | P0 | Background audio mode; recognition continues with the screen off (verified for over eight minutes locked in plan 001). The pocket is a supported position, the mount beside the lens is the designed one (section 11). |
| Listening check screen | P0 | Shows recognised words live with their delay, the input level, the route, and Say Test (a phrase through the earpiece while listening). Used by the spike; in Settings' Diagnostics since plan 005. |

### 4.4 Following

The follow engine (section 5) takes the script's phrases with word timings and the
stream of heard words, and decides what the player does.

| Feature | Priority | Notes |
|---|---|---|
| Hold the lead | P0 | The voice stays about `lead` words ahead of where the presenter is estimated to be now. In plan 001 lead 5, counted from the last word heard, felt best; that is about two words of felt head start plus the recogniser's delay. The engine now measures the delay and adds it (5.4), so the setting is the felt head start: default 5, chosen against 3 on real takes in plan 005. In plan 003's simulated clean read the voice stayed within two words of the lead 99% of the time; on the phone in plan 005, by the console's measure, 28 to 59% of the speaking time (the recogniser's delay and the speaking rate vary more than the simulation's). |
| Hybrid pacing | P0 | Playback speed is nudged between bounds (default 0.85x to 1.2x, in Settings) to keep the lead; a phrase boundary is a gate: the next phrase starts only when the presenter is within `lead` words of the end of the current one (counted to the boundary after its last word, so the next phrase starts exactly a lead ahead). Phrase-gated only, with speed fixed at 1.0x, is the first milestone and remains available as a setting. |
| Wait | P0 | When the voice reaches a gate and the presenter is not there, it waits silently. No filler, no repeat. |
| Pick up again | P0 | While waiting, every heard word is matched near the expected position and, once the presenter is lost, across the whole step (a take is one step). On a confident match the voice re-anchors (5.4): it queues the first phrase the presenter has not begun, released by the usual gate, so it never repeats a word just said or skips one not yet said. While it waits (or is lost or held), the Prompt screen shows the whole sentence it stopped in, so the presenter can see where to start again (plan 005). |
| Off piste | P0 | Heard words that match nothing are ignored. The voice waits at its gate for as long as it takes. Known: one stray word straight after a phrase end can still release the next phrase, since the estimate runs on for the recogniser's delay (5.4). |
| Fluffs and restarts | P0 | A presenter who goes back and says a phrase again is matched where they are, so the voice steps back with them. In plan 001, without stepping back, the gates already held while the presenter repeated a line, and the author "could live with" every fluff; the one awkward case is a restart after the gate has opened, when the voice is already into the next phrase. Plan 003: on a step back of three words or more, heard as new words, a voice already into a later phrase stops and re-anchors to the phrase after the one the presenter is in; in simulation the third fluff of plan 001, which waited 5.4 s, gave no wait. Plan 005 on the phone: the voice gives nothing again by itself after a fluff. Re-giving the rest of the phrase, then the sentence from its start after a pause, were tried and dropped: the author wants to recompose himself first ("I shouldn't be expected to start straight away"), and the pause detection repeated itself on natural pauses. The voice waits; the presenter goes back in their own time and is followed back (a 24-word window, 5.3); Back re-gives a phrase on request. |
| Manual controls | P0 | On screen, large: Hold (toggle), Back a phrase, Forward a phrase, Restart the step, Stop. Hold stops the voice at once; listening goes on, and release re-anchors to where the presenter got to. Back and Forward play that phrase now; with nothing heard the voice then waits at the next gate; Forward from the last phrase does nothing. Restart goes back through the tones, not the slate, in the same take. Start on the start step's card, or Start Take N on the rendering row, opens the Prompt screen (8.2). Where else the controls live (an earpiece button, a Watch) is open (section 15). |
| Fixed pace (no listening) | P1 | The voice reads at 1.0x and never waits; the presenter keeps up. For rehearsal and for noisy places. |

### 4.5 Starting a take

Every take needs a start ritual, because at the start the voice must speak before the
presenter has said anything, and the recording needs a slate. The author's existing
practice (the Cutaway video's script) is a spoken slate at the start of every take, the
shot ID and the take number. Earwig builds on that:

1. The presenter picks a step and presses Start. Earwig announces the slate in the cue
   voice: "Step three, take two." (For a script whose steps carry shot IDs, the ID is
   said instead: "W three one, take two.")
2. The presenter repeats the slate aloud to the camera. Earwig hears it; that is both the
   confirmation that listening works and the trigger.
3. Three short tones (1 kHz beeps 0.6 s apart, made in code as one buffer), then the first
   phrase plays on the fourth beat in the presenter's voice. The presenter starts speaking
   `lead` words behind it; from here on the engine follows.

Alternatives, kept for the first plan to try:

- **Tones only.** Press Start, three tones, first phrase. Simplest; no slate heard by the
  camera and no proof that listening works before the take.
- **Spoken trigger.** The presenter says "go" or "action"; Earwig starts on hearing it.
  Hands-free, but a word the camera hears and the editor must cut, and a false start on
  stray speech.
- **First phrase, then gate.** Press Start and the first phrase plays at once; every later
  phrase is gated as normal. Nothing to say first, but no slate.

Plan 003 builds three start modes, chosen in Settings: **slate with a reply** (the
slate is read and the take starts when two of its three parts are heard repeated, or on a tap),
**slate alone** (the slate is read, then a 3 s pause to say it to the camera, nothing listened
for; a tap skips it) and **tones only**. On the phone in plan 005 the author chose **tones
only** as the default; the slate modes stay in Settings for shoots that want a spoken slate.

### 4.6 Screen mode (teleprompter)

| Feature | Priority | Notes |
|---|---|---|
| Scrolling text that follows the presenter | P0 | Every take (plan 008). Large type on the theme's sky blue, the step and take small at the top, in portrait and landscape (the controls down the side). The line the presenter is on is held at an eyeline a third of the way down, by a smooth scroll; the words already heard turn faint, so their place is where the white starts. No marker on a single word: one showed the recogniser's second of delay as a word always behind. |
| Two modes, chosen before the take | P0 | **With Voice**: the voice in the earpiece and the scrolling text. **Screen Only**: the text and no voice, nothing rendered, so a take starts at once. Chosen on the Script screen's start card or in Settings (one value), fixed for the take, kept by Next Take. Ear alone, the first build's third mode, was dropped: the voice with the text showed more at no cost. |
| The voice's phrase lit | P1 | With the voice, its phrase on the cards' mid-blue and its word on the accent. A setting, off by default (Andy, plan 008). |
| Fixed-pace scroll when listening is off | P1 | Words per minute in Settings, start and stop on tap. Not built: its own issue. |
| Font size | P0 | A setting (24 to 72 pt, default 40) and a pinch on the Prompt screen. |
| Directions shown in the cue colour, never lit or dimmed as spoken | P0 | A long one wraps a word at a time. |
| Mirror flip, external display, pedal or remote | Out | Not wanted. |

### 4.7 Takes

A take is one attempt at one step. Earwig numbers takes per step from 1, says the number
in the slate, and keeps a list per script: step, take number, when, how long, and whether
it ran to the end of the step or was stopped. This is what lets the slate on the camera's
sound track say "take two" and mean it, and lets the next shoot carry on from "take
three". A take is recorded when its slate (or, with tones only, its tones) plays, as
stopped, and its length and outcome are set when it ends, so a take the app never finished
still holds its number; getting ready that fails records nothing (plan 005). Nothing the
presenter said is kept unless the take is recorded.

**Recording a take (plan 010, #16).** A take can be recorded, Off (default), Sound or
Video, chosen on the start card's Record row or in Settings and kept by Next Take. Sound is
the built-in mic, the same buffers the listener hears; Video adds the front camera, 1080p30
by default or 4K30, with no sound of its own, so the earpiece's audio is never recorded and
the audio session, the route and the engine are untouched. A video take opens on the
camera's preview to frame the shot, and Start begins it; the preview can stay behind the
scrolling text while the take runs (Camera Behind the Text, on by default), the picture at
its own brightness and the text faded as a slider on the preview says (35% by default).
While recording, a red dot and the time show in the top row. Locking the phone or leaving
the screen stops the video, since iOS allows no camera in the background, and the sound
and the take carry on; Finished says when ("Video stopped at 0:07: the phone was locked or
Earwig left the screen."). Finished saves the file ("Saving the recording…", Next Take and
Done held), then offers Play Video and Play Sound, or Play Back for sound, and Share
(AirDrop, Save Video to Photos). Files are in Earwig's folder in the Files app,
`Recordings/<script title>/Step 3 Take 2.mov` (or `.m4a`), never written over; with Keep
Recordings off (default) each recording replaces the last, and Settings shows their size
and deletes them all. Below 1 GB free a video take records sound only and says so. About
80 MB a minute at 1080p and 280 MB at 4K. Recording does not change the take: on the
phone, the waits and the delay were the same filmed as not.

The take record for Cutaway (the take's audio, the words heard with their times, and the
slate) is a roadmap item (section 13): cheap once the microphone is open, but scope.

### 4.8 Settings

- Presenter's voice (a downloaded voice), base rate, and a Preview button. Plan 004 found
  1.0x a little fast and 0.85x "more normal" in Listen; plan 005's voice speed (4.2) is
  the base, default 0.95x.
- Cue voice, cues on or off by default, and directions inside a line chimed or spoken.
- Lead, in words (2 to 6, default 5), with seconds shown for the chosen voice and rate.
- Pacing: hybrid (default) or phrase-gated; speed bounds; voice speed.
- Start ritual: slate with a reply, slate alone, or tones only (default).
- Screen: the mode (With Voice or Screen Only), whether the voice's phrase is lit, font
  size; fixed-pace words per minute when that is built.
- Recording: Off, Sound or Video; video quality (1080p or 4K); Camera Behind the Text;
  Keep Recordings; the recordings' size and Delete All Recordings (plan 010). The text's
  brightness over the camera is set on the preview, not here.
- Diagnostics: the Listening check (4.3) and the route check.

Plan 005 built the first Settings screen, from a gear on the Scripts screen, with what it
judged: Following (lead, pacing, voice speed), Start, and Diagnostics (the Listening check).
Plan
008 added the Screen group: Mode, Light the Voice's Phrase, and Text size. Plan 010 added
the Recording group, and cut every footer to one line where a choice does something its
name does not say, or none (the author: other iPhone apps "tend to let you work things out
yourself"). Plan 011 moved the voice, Allow Personal Voice and the directions setting
(renamed Stage Directions) out of the Script screen's menu into a Voice group at the top,
and Read Cues, which is per script, to the start card; the Script screen has no menu.

---

## 5. Follow Engine Specification

The engine is a pure Swift module (`Engine/`) with no UI, audio or persistence imports,
an injectable clock, and deterministic behaviour from its inputs, as PhysiMate's timing
engine. Every rule here is unit-tested with fixture word streams.

### 5.1 Inputs

- The script as a flat list of **script words**, each knowing its phrase, line and step,
  with a normalised form (lower case, punctuation stripped, British and American spellings
  folded, as Cutaway's `pipeline/script.py` does). A number is **one** script word whatever
  its length, matched by value, so "1890", "eighteen ninety" and the recogniser's digits
  agree and a year does not use up the lead; it matches while its digits are still
  arriving ("18" on the way to "1890"). Compounds and contractions fold both ways
  ("sea wall" and "seawall", "there's" and "there is"). All three cost words in plan 001.
  Plan 002 reads the script words at parse time: each written word is one script word
  (`there's` one, `sea wall` two); a number in digits ("1,500", "21st") or a run of number
  words ("three hundred", "twenty-one", "eighteen ninety", "nineteen oh five") is one word
  with its value, with one reading per run; a run never crosses a comma, full stop or dash,
  so "fifteen, sixteen" is two numbers; a decimal or a time ("2.5", "9:30") is a plain
  word. Folding compounds, contractions and spellings against what is heard is the
  matcher's (plan 003, 5.3).
- Each phrase's rendering duration and per-word start times.
- **Heard words**: the recogniser's interim text, the whole untimed block since the last
  final, rewritten on every result, and its final words with their start times on the
  engine's clock. The engine stamps each interim word with when it first appeared and
  re-aligns the whole block from the position at the last final on every result, so a
  rewrite needs no bookkeeping; a final settles the block. Pairing first appearances with
  the finals' start times measures the recogniser's delay; the finals' spacing measures the
  presenter's rate.
- The player's reported playback position (phrase and offset into its rendering), where
  the presenter hears it: the rendered offset less the output latency at the current
  speed (356 ms on the SK18, plan 004); and the end of each phrase, cue and the tones,
  reported when its last sample has gone to the output, so the next follows with no gap
  in the ear.
- The manual controls and a tap; settings: lead, pacing mode, speed bounds, start mode and
  the thresholds in 5.3.
- Time: every input carries a time on one engine clock and the host ticks the engine about
  ten times a second; the engine never reads a clock, so its behaviour is deterministic.

### 5.2 Outputs

Commands to the player: play the slate cue, play the tones, play phrase n at speed r (a
cue phrase in the cue voice), set speed r, stop the voice, and the take finished
(completed or stopped). Waiting is not a command: the voice simply gets no next phrase. A
snapshot for the screen and diagnostics: the status (slate, tones, speaking, waiting,
lost, held, finished), the voice's phrase and word, the presenter's confident word and
estimated position, the speed, the lead error, and the measured delay and rate.

### 5.3 Matching

- The engine keeps an **expected position**: the last matched script word advanced by the
  words heard since.
- A heard word is matched within a **window** of script words around the expected
  position (24 words behind, two whole phrases, so a restart of the sentence before is seen
  at once, as plan 005 needed; 12 ahead). It matches when the normalised forms are equal; when both are the same
  number, or the last word of an interim result is digits still building up to the
  script's number; within an edit distance (transpositions counting one) of 1 for words of
  five to seven letters and 2 for eight or more, which covers most British and American
  spellings; or as a pair in a short spelling table ("grey" and "gray", "tyre" and
  "tire"). Compounds and contractions match across a word boundary both ways, a
  contraction from a table ("theres" is "there is").
- Runs decide **confidence**: two consecutive matches (three when lost) make the position
  confident; a single match only moves it tentatively, and no gate, step back or jump acts
  on it. Within a run one script word may be dropped or one heard word misheard; an
  inserted heard word breaks it. A heard word that would leave the run, when the next heard
  word carries the run on as if it were misheard, is taken as misheard rather than as a jump
  ("salt on the side" for "on one side" must not jump to "the other side", plan 005). A final
  makes a block **settled**; an interim block may
  still be rewritten. Among candidates: one continuing the run, then one confirmed by the
  next heard word, then an exact match over a near one, then the nearest, ahead before
  behind.
- When `lostWords` heard words (default 6) match nothing, or `lostSeconds` (default 4)
  pass from the first of them with words still arriving, the presenter is **lost**: the
  window widens to the whole step and a run of three is needed. A single stray match ("the")
  does not reset the count. Silence is never lost. Once found the voice re-anchors (5.4).
- Heard words that match nothing are dropped. The engine never guesses a position.

### 5.4 Pacing

- The **presenter position** used for pacing and gates is an estimate of where the
  presenter is now: the last confident word advanced by their measured speaking rate over
  the recogniser's measured delay plus the time since that word appeared, for at most
  0.5 s with nothing new (the median of the last 20 delays, default 0.9 s, kept within 0.3
  to 2 s; the rate over the last 10 s of finals, pauses over a second left out, default 2.5
  words a second). Off script it stays at the last confident word. After a final the
  presenter has paused, so it stays there, unless the voice has since started a phrase the
  presenter has not begun and they were heard within three words of it (at the end of the
  phrase before, or short of it by a misheard word or two; stopped further back they have not
  reached it, plan 009): a lead's worth of time later they are taken to have begun it,
  and no further, which bridges a first interim result that is late after a pause while
  letting silence through a gate only for a phrase of `lead + 1` words or fewer. It never
  passes what the voice has given. For a gate, the coast does not cross a phrase end: it
  goes no further than the first word of the next phrase until a word of that phrase is
  confidently heard, so speech that leaves the script straight after a phrase end holds the
  voice rather than releasing the next phrase (plan 006, #19). Pacing keeps the free coast,
  so the voice is not slowed at every phrase crossing. Telling a late result from silence needs a speech signal
  (the input level), a possible later refinement (#9).
- Error `e` = (voice position − presenter position) − lead, in words: positive when the
  voice is too far ahead.
- Hybrid: speed = clamp(1 − k·e, minSpeed, maxSpeed), k = 0.05 (one word of error is
  0.05x), changing by at most 0.1x a second and sent only when it moves by 0.02 or reaches
  a bound; only once the presenter has been heard. (Before v0.5 this read 1 + k·e, which
  would speed up a voice already too far ahead.)
- Phrase-gated: speed stays at 1.0x.
- At the end of phrase n the voice **waits** unless the presenter's position is at least
  (end of phrase n − lead), the end counted as the boundary after its last word, so a
  released phrase starts a lead ahead. While waiting the speed logic is off. On release the
  next phrase starts at speed 1.0x. A cue phrase is gated by the spoken phrase before it,
  and the spoken phrase after a cue follows it at once.
- **Re-anchoring** replaces the jump: the voice stops and queues the first phrase the
  presenter has not begun, released by the usual gate. It happens on a step back (a
  confident position, from newly heard words, three or more words behind the last, with
  the voice already past the phrase it would queue), when the presenter is ahead of the
  voice (in place of speeding up past maxSpeed), when the presenter is found after being
  lost, and when Hold is released. With the presenter in the last phrase there is nothing
  to queue, and the voice stops and is finished.
- The take **completes** when the last word is heard, or, with the presenter in the last
  phrase, 3 s after the later of the voice finishing it and the presenter's last confident
  word, so a presenter who comes back to the last phrase late is not cut off at its first
  word (plan 005).

### 5.4a Following with no voice, and the screen's place (plan 008)

With no voice (`voiced` off, Screen Only) the engine follows the presenter alone. The start
is as with a voice, and the slate and tones still play. After the tones it is **Reading**:
no phrase is played and nothing waits at a phrase end. Hearing, matching, Lost and step backs
are as with a voice, and the estimate is capped at the last word. Hold keeps the place, and
Release goes to wherever the presenter has been heard since. Back and Forward move the place
a spoken phrase, passing over cues. The take completes on the last word, or with the
presenter in the last phrase and not heard for `endGrace`. With no voice, the take's first
word, heard first, is trusted on its own.

The screen's place (`presenterPlace`) is the word after the last one confidently heard, kept
still while held. It is only what has been heard, never a guess ahead. Guessing ran the mark
past pauses, and the rules added to undo bad guesses interacted with each other (Andy,
device check 2 of plan 008). It trails the presenter by about the recogniser's delay. The
screen smooths it (`ScreenPlace`): a move glides, otherwise it follows forward and never
back.

After Back or Forward, with a voice or without, what was said before the press is not
followed (heard from a delay on, spoken from the press). It reached the recogniser late and
pulled the place straight back.

### 5.5 Start

By the start mode (4.5). **Slate with a reply**: the engine plays the slate cue, then,
once it has ended, listens for the slate's words (the step number or shot ID, "take", the
take number, numbers by value); two of them heard, or a tap, emits the tones, and phrase 1
plays when they end. Words heard before the tones are not followed. **Slate alone**: the
cue, a 3 s pause, the tones. **Tones only**: the tones. A shot ID said as letters and
numbers ("W three one") is matched only as well as the matcher already can; better handling
waits for real scripts with shot IDs (#10). The default is tones only (plan 005).

---

## 6. Data Model

### 6.1 SwiftData Entities

- **Script**: title, source text (line endings made `\n`, trailing spaces trimmed), format
  (`plain`, `cutaway`), source hash (SHA-256), preamble, imported at, updated at, cues on
  or off, lastStep. Relationships: steps, takes, renderings, all deleted with the script.
- **Step**: sortOrder, number (as the script numbers it), title, shotID (optional),
  directions (ordered, each a kind and text), lines (ordered, each a string with any
  `[direction]` inside it). Phrases are derived at parse time and stored as a JSON value
  on the step (`PhraseList`) so the engine's indices are stable: each phrase with its line
  and kind (spoken, or cue for an inline direction) and its tokens' script words. The list
  carries a parser version; a list from an older parser is rebuilt from the script's
  source text when the script is opened, so changing the rules needs no migration.
- **Rendering**: script, script hash, voice identifier, rate, created at, and a JSON map
  of phrase to audio file name and word start times. Unused in v1, where rendered audio
  is held in memory (plan 004); kept for imported renderings (6.2).
- **Take**: script, step index (not a relationship, so a re-paste that rebuilds the steps
  keeps it), number, started at, duration, outcome (`completed`, `stopped`).
- **Settings** is `UserDefaults` through a typed wrapper, not a model.

Conventions as the siblings: every relationship optional with an inverse, a default on
every stored property, explicit `sortOrder` on ordered relationships, enums stored as
raw strings, Codable value types as JSON `Data` behind typed accessors.

### 6.2 Imported rendering (P2)

A folder containing `rendering.json` (`earwig/rendering@1`: script hash, voice name, and
per phrase the audio file name and word start times) and the audio files. This is the
contract Cutaway would write.

---

## 7. Architecture

### 7.1 Pattern

MVVM with SwiftData, as PhysiMate.

```
Views (SwiftUI) → ViewModels (@Observable) → Models (SwiftData)
                          ↓
   Services: ScriptParser, PhraseSplitter, WordNormaliser, VoiceRenderer,
             ScriptRenderer, AudioSessionManager, Listener, Player, Slate, TakeHost
                          ↓
   Engine/: FollowEngine (pure; words in, commands out)
```

### 7.2 Key Services

- **ScriptParser**: text to steps, lines and directions; the Cutaway and plain formats.
- **PhraseSplitter** and **WordNormaliser**: shared by the parser and the engine; the
  normaliser mirrors Cutaway's rules so what Cutaway calls "as spoken" matches here too.
- **VoiceRenderer**: renders phrases to buffers with word timings through
  `AVSpeechSynthesizer`, one at a time.
- **ScriptRenderer**: renders the start step's missing phrases through VoiceRenderer, keeps
  them in memory by voice, rate and text, reports progress; **VoiceCatalogue** chooses the
  voices.
- **AudioSessionManager**: configures the session (`.playAndRecord`, A2DP output only,
  built-in mic input), reports the route and a lost output device, handles interruptions
  (a call ends the take as stopped; the presenter starts the next).
- **Listener**: wraps `SpeechAnalyzer`; feeds the mic to the transcriber and emits
  heard words with times to the engine.
- **Player**: `AVAudioEngine` with a `varispeed` or `timePitch` node (time-pitch, so
  slowing down does not drop the voice's pitch), plays rendered phrases on command, and
  reports its position by the audio clock. Three channels on one engine: the voice through
  the time-pitch node, cues and the slate at 1.0x, and the tones and the chime. Tones are
  scheduled on the audio clock, as PhysiMate's plan 001 found necessary.
- **Slate**: the slate's text and its reply words (4.5).
- **ScreenText**: the take's step as words for the scrolling text (plan 008).
- **CameraCapture**, **TakeRecording** and **RecordingStore** (plan 010): the front camera
  as an `AVCaptureSession` that never configures the audio session and has no audio input;
  one `AVAssetWriter` writing the mic's buffers (a second consumer of the listener's tap)
  and the camera's frames on the host clock, running on a second past the take's end for
  frames that come late; and where the files go, what is kept and what is deleted. The
  preview is one layer for the whole take: a second layer added to the running session held
  the main thread for seven seconds.
- **TakeHost**: one take, from getting ready (microphone, session, audio engine, listening,
  the slate's render, in that order) to its end: ticks the engine twenty times a second with
  the player's progress, passes it what is heard and what the player reports, passes its
  commands to the player, records the take, and handles the route and interruptions. Its
  parts sit behind protocols so the whole loop is tested against fakes (plan 005).

### 7.3 Folder Structure

```
Earwig/
  App/           EarwigApp, AppState
  Models/        SwiftData models, PhraseList, ModelJSON, Settings
  Engine/        FollowEngine, Matcher, PresenterEstimate, Pacer, WordFolding, WordNormaliser,
                 ScriptWords, FollowScript (pure Swift)
  Services/      ScriptParser, ScriptImporter, PhraseSplitter, VoiceRenderer, ScriptRenderer,
                 VoiceCatalogue, Tones, StepPreview, TakeAudio, Slate, AudioSessionManager,
                 AudioEngineHost, Listener, HeardEvents, Player, TakeHost, TakeSummary,
                 ScriptTakeRecorder, ScreenText, ModelContainerFactory
  ViewModels/    ScriptsViewModel, ScriptDetailViewModel, PromptViewModel, ListeningCheck,
                 ScreenPlace, ScreenLayout, ScreenFollower
  Views/         Scripts, ScriptDetail, Prompt, Settings (with the Listening check), Splash
  Resources/     Info.plist, Assets (the app icon, the mark, the launch colour), tones
EarwigTests/     Engine and parser tests with fixture word streams
scripts/app_icon/ make_app_icon.py and the SVGs it writes: the icon and the mark
scripts/release/ testflight.sh, ExportOptions.plist
plans/           One plan per branch
docs/            development.md (gotchas), this PRD stays at the root
```

---

## 8. Screens

### 8.1 Scripts

The presenter's own scripts at the top (title, step count, format, last take), swipe to
delete, and the four samples below them under **Samples**, which cannot be deleted (plan
011). Tap for the script. The Paste pill is in the toolbar once there are scripts of the
presenter's own; until then the top section is one row, "Copy a script on your Mac, in
Markdown or plain text, then paste it here", with the pill. The Settings gear is top left.

### 8.2 Script

The steps, each with its lines and directions in the cue colour. At the top, the start card
(plan 008, Andy's pick): "Step N · take M", the two modes as large tiles that only choose
(With Voice, Screen Only), **Listen** once the step is rendered (the step played straight
through, slate, tones, phrases and directions as set, at 0.85x, 1.0x or 1.2x, the word being
said highlighted, recording no take; plan 004), and the rendering only while it runs or if
it failed, with a Render button. **Start Take N** is at the foot of the start step's own
card, once it can start (rendered, or at once in Screen Only). Tap a step to make it the
start step. A tap on the card itself never starts a take, so one is not started by accident
while scrolling (plan 005). The takes so far for each step, and the next take's number, are
shown on it. Each step shows its number large, as the slate says it. The start card also
has the Record chips and the Read Cues toggle. Paste new version and Delete Script are
buttons at the foot of the screen, for the presenter's own scripts; the toolbar has only the
back button (plan 011).

### 8.3 Prompt

The take screen, usable at arm's length and glanceable from a mount (plan 008):

- Top, one row: step number and title, take number, the status as a word (Getting ready,
  Slate, Tones, Speaking, Waiting, Reading, Lost, Held), the take's mode, and the route
  check (earpiece and mic icons, red when wrong, the earpiece amber on the speaker; not
  judged in Screen Only), judged only while the take runs. What to do under it (in the
  slate-with-reply mode "Say the slate, or tap"; a tap on the text skips it). No line of the
  engine's numbers: the take's summary in the console has them (plan 012).
- Middle: the scrolling text (4.6). A drag moves it by hand; it follows again three seconds
  after, or at once on Back, Forward or Restart. A pinch sizes it, scaled about the eyeline
  while pinching and laid out again when the pinch ends.
- Bottom: Back, Hold, Forward, Restart step, Stop as one row of icons, down the side in
  landscape. The screen stays awake while the take runs, the text redraws only while it
  moves, and a take runs on with the phone locked (a video take's video stops; 4.7).
- A recorded take (4.7): a video take opens on the camera's preview with the step's opening
  words, a slider for their brightness, Cancel and Start; the camera can stay behind the
  text while it runs. The top row shows a red dot and the time recorded, the sound icon
  once the video has stopped.
- A take ends at the end of the step, on Stop, on an interruption, or when listening gives
  up ("Stopped: listening stopped …", with why). Finished then shows the outcome large and
  offers Next Take (the same step again, in the same mode) and Done, with Play Video, Play
  Sound (or Play Back) and Share above them for a recorded take, and the Script screen
  shows the next take number. Getting ready that fails (no microphone, listening or slate)
  says why, with Done.

### 8.4 Settings

As 4.8, grouped: Voice, Following, Start, Screen, Recording, Diagnostics. From plan 005,
Following, Start and Diagnostics, opened from a gear on the Scripts screen; from plan 008,
Screen; from plan 010, Recording; from plan 011, Voice (the voice, Allow Personal Voice and
Stage Directions). A footer only where a choice does something its name does
not say, in one line.

### 8.5 Listening check

Live heard words with delay, input level, route, and a Say test button that speaks a
phrase through the earpiece while listening, to show the mic is not picking the
earpiece up.

---

## 9. Key User Flows

### Flow 1: The beach walk with the Osmo

Script pasted from the Mac the night before and rendered. Earpiece in, phone in a jacket
pocket, Osmo in hand. Open the script, tap step three, Start. "Step three, take one."
Say it to the Osmo. Tones. The voice begins; speak behind it. Rosie runs off; stop
talking; the voice finishes its phrase and waits. Call Rosie, come back, say the last
few words again; the voice steps back with you and goes on. At the end of the step the
take ends. Tap the step again for take two.

### Flow 2: The desk head, phone on the mount

Phone on the mount beside the lens, With Voice. The text is there to glance at, the voice is
the one actually driving. Font large. Stop with a tap.

### Flow 3: A teleprompter, plain

A plain-text script pasted in. Screen Only, fixed-pace scroll at 140 words
a minute because the room is noisy. Pinch to size the type.

### Flow 4: The script changed

Cutaway's script was edited on the Mac. Copy it, open Earwig, Paste: the script's text is
replaced, the start step renders again (unchanged phrases at once, if rendered since the
app started), the takes stay.

---

## 10. Design Language

One distinctive look, the same whatever the phone's light or dark setting, with no
separate light and dark variants (plan 002, the author's pick from nine candidates): a
clear sky blue as the ground, mid-blue cards with white text, a buttercup yellow accent
for the voice's phrase, the start step and the slate numerals, and peach for cues and
directions. High contrast and large type for arm's length. Few screens, nothing
decorative. SF Symbols. All colours in `EarwigTheme`; views never define their own.

**App icon and splash** (plan 007). One mark for the Home Screen tile, the splash and the
logo: a white earwig crawling at 35° on the theme's sky blue, drawn to the insect's
proportions with no face, chosen from five rounds of concepts. The icon has the three iOS
appearances: light is the insect in white on sky blue, opaque; dark is a cooler white on a
transparent ground, so iOS supplies its backdrop, with the body's cuts in near-black; tinted
is greyscale on a transparent ground. A committed script, `scripts/app_icon/make_app_icon.py`,
holds the geometry, writes the SVGs, renders the PNGs with headless Chrome and also renders
the mark alone, transparent, as the `EarwigMark` image the splash and any logo use; nothing
is drawn twice. The launch screen is the sky blue alone, a colour set pinned to the theme by a
test, so a cold launch opens on the app's own ground. A splash overlay then fades the mark and
the name ("Earwig" in SF Rounded, bold, white) in and out over the Scripts screen in under a
second; it shows once per process, so a return from the background or an unlock mid-take
shows nothing, and Reduce Motion changes nothing, since fades are not motion.

**System chrome** (plan 011). The app runs in the light scheme, so iOS draws its own menus,
confirmations, alerts and sheets pale and frosted, never near-black; Earwig's colours are its
own all the same. Navigation titles and the status bar are white, and lists set white labels
with pale headers and values. Toolbar buttons hide iOS's glass and draw their own: an icon in
a mid-blue circle (the gear, Back) or a word in a mid-blue capsule (Done). The back button is
Earwig's own, and the edge swipe still goes back. Lead's − and + are Earwig's own too.

---

## 11. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| The voice is not good enough to follow comfortably | Personal Voice failed in plan 004 (poor quality, slow to render), so Stephanie (Enhanced), "okay, not fantastic", stays the v1 voice. The imported rendering (section 13: the presenter's own recorded reading, or an ElevenLabs voice, made by Cutaway on the Mac) moves up. |
| The in-ear earpieces fall into the hands-free profile, so the prompt sounds like a phone call | Retired for the author's SK18: with the session allowing Bluetooth for A2DP only and the built-in mic pinned, it stayed in A2DP with the mic open through every take in plan 001, including over eight minutes locked, and the mic did not pick up the earpiece. The route check (4.3) still shows it on every take, for other earpieces. |
| Recognition is poor outdoors (wind, sea) or with the phone in a pocket | Indoors it is good in the hand and in a gilet pocket alike (plan 001: about 0.9 s median delay, 96 to 98% of script words, most misses spelling, not hearing; plan 005's takes, locked in a pocket as well: 0.8 to 1.05 s). Outdoors and the mount are not yet measured; they wait for the author's next shoot (stage 6 or 7). The engine tolerates missed words (5.3, runs of two, lost after six). A lavalier into the phone is a possible later input. |
| Speed changes sound wrong | Time-pitch, not varispeed; narrow default bounds (0.85x to 1.2x); phrase-gated mode with no speed change as the fallback. |
| The lead is wrong for the presenter | It is a setting; plan 001 found 5 words by trial, and plan 005 chose 5 again with the delay allowed for. The recogniser's delay is part of it, so the engine measures and adds that delay itself (5.4). |
| Speech recognition stops in the background or on lock | Retired: background audio mode kept the session alive with the screen locked for 8 min 20 s of looping takes in plan 001, with mic audio continuous throughout. Listening also restarts itself if its results fail. |
| en-GB on-device transcription assets are missing | Downloaded once through `AssetInventory` with a prompt; Settings shows the state. |
| Numbers, years and compounds stall the follower | Plan 001 saw a year at a phrase end hold a gate for 2.8 s at every lead, and "sea wall" heard as "seawall". The matcher folds them (5.3); in plan 003's simulated take with "seawall" and 1890 building up as digits, no gate held (longest voice gap 1.1 s, no wait felt by the presenter). |
| An incoming call | Ends the take as stopped; the presenter starts the next take after it. An interruption on an earpiece put away does the same (plan 005). A call itself is not tested (calls are rare; waived as in PhysiMate). |
| Earpiece audio heard by the Osmo | One listen on the first real take at the chosen volume. Expected inaudible. Not yet done: it waits for the author's next shoot (stage 6 or 7). |
| Filming on the iPhone with Earwig running | The stock Camera app stops Earwig's audio, so Earwig films its own takes (plan 010) with a capture session that leaves the audio session alone: the earpiece stayed in A2DP with the built-in mic throughout. Heat: six 4K takes in a row with the camera behind the text stayed at the nominal thermal state, battery steady, no frames dropped ("slightly warm, but not really too bad"). Longer runs are not measured. |

---

## 12. MVP Scope (Phase 1)

Each stage is one plan, one branch, one issue and one PR.

1. **Spike: voice, earpiece and recognition** (plan 001, done: see its Results). A throwaway screen in the real
   target: list voices, render a real script phrase by phrase with timings, play through
   the earpiece with the built-in mic open and the route shown, show heard words live.
   Tried on the author's phone, on the beach script, in a pocket and on the mount, screen
   locked. Records in the plan: the voice verdict, whether the earpieces hold A2DP, the
   recognition delay, and the lead that felt right. Decides 4.2's voice and 4.4's default
   lead.
2. **Skeleton, models, parser** (plan 002, done: see its Results). Project, theme,
   SwiftData, the Cutaway and plain parsers with tests, the Scripts and Script screens,
   paste import.
3. **Follow engine** (plan 003, done: see its Results). Pure, with the matcher, the pacer, the gates, lost and resume,
   tested against fixture word streams (a clean read, a slow read, a fluff and restart, a
   stop and resume, a wander off script).
4. **Renderer and player** (plan 004, done: see its Results). The start step rendered in
   memory with word timings, the default voices, the slate and tones, the time-pitch player
   on the audio clock with the output latency allowed for, directions chimed or spoken,
   and Listen.
5. **Listener and the Prompt screen, Ear mode** (plan 005, done: see its Results). The
   recogniser feeding the engine, the take host, the slate flow, manual controls, route
   check, takes recorded at the slate, the first Settings screen (lead, pacing, voice speed,
   start) and the Listening check; the defaults chosen by ear on the phone.
6. **Screen mode** (plan 008, done: see its Results). The scrolling text driven by the
   same engine in every take, With Voice or Screen Only, the start card, font size. The
   fixed-pace scroll is its own issue.
7. **Settings and TestFlight** (plan 012). The settings in 4.8, the release script, the
   first TestFlight build.

Beside the stages, plan 007 (app icon, logo and splash, #21) gave the app its mark (10), and
plan 011 (#22) the built-in samples, the README and the first pre-release, v0.1.0.

### Excluded from MVP

Share sheet and Files import, fixed-pace modes, the take record, imported renderings,
filming on the iPhone for use (plan 010 records takes for checking only), Watch or
earpiece-button controls.

---

## 13. Future Phases

### Phase 2: Round trip with Cutaway

- **Take record.** Each take's audio (the phone's mic), the heard words with times, the
  slate and the step, written as a folder Cutaway can read, so the shot log and the
  transcript of a shoot start from what the presenter was prompted to say and what they
  said.
- **Imported renderings** (6.2) from Cutaway: the ElevenLabs clone it already holds, or
  the presenter's own recording of the script aligned by Whisper on the Mac. Cutaway
  renders and asks before spending, as it does now; Earwig only plays files.
- **Seamless import**: a Files or iCloud Drive folder per project, watched, so the
  current script is simply there.

### Phase 3: Filming on the iPhone

Plan 010 built the base: Earwig films a take with the front camera at 1080p or 4K, with
the mic's sound, the prompt running and the camera behind the text, and plays it back. What
is left for filming meant for use: framing aids, the back cameras, files to Photos
directly, and filming with the phone locked, which iOS does not allow.

### Phase 4: Expansion

- Talking points: a line marked loose (the Cutaway video script's convention, where only
  starred lines are verbatim) is read as a cue and not followed; following resumes at the
  next verbatim line.
- Controls off the screen: a Watch complication or an earpiece button mapped through the
  remote command centre to Hold.
- Share sheet import; iPad.

---

## 14. Verification Plan

### Testing Approach

- Unit tests (Swift Testing) for the parsers, the normaliser, and the engine: every rule
  in section 5 has a fixture word stream and an expected command sequence.
- The spike's device checks in plan 001, with results recorded in the plan.
- Each later stage ends with a take on the real phone, Osmo rolling, judged by ear and by
  the Listening check. Audio, Bluetooth and background behaviour cannot be verified in
  the simulator.

### Success Criteria

- A two-minute step from a real Cutaway script, read on the beach with the phone in a
  pocket, completes with no manual control used.
- The voice is never heard to run away: the lead error stays within two words through a
  clean read. (Plan 005's console put it within two words for 28 to 59% of the speaking
  time on the phone; the author did not report it running away. The measure, or the
  criterion, is to be looked at again.)
- After a stop of ten seconds and a restart from the last phrase, the voice is back in
  step within one phrase.
- The earpiece plays at music quality throughout, with the built-in mic in use, and the
  route check never shows red on a take that was set up right.
- The author would rather use it than learn the script.

---

## 15. Open Questions

1. Answered in plan 005: tones only is the default start; the slate modes stay in Settings.
2. Manual controls beyond the screen: whether the earpieces have a button worth mapping,
   or a Watch is wanted. Decide after a few real takes.
3. Commit policy for this repo: Cutaway's (Claude commits at sensible points, never
   pushes) or the iOS siblings' (commits only when asked). Proposed: Cutaway's.
4. Answered in plan 004: a line's own directions are a setting, chimed (the default) or
   spoken at that point; step directions are read in the slate.
5. Moot: Personal Voice is not used (plan 004).
6. Answered in plan 004: Personal Voice is worse than Stephanie through the earpiece and
   slower to render, though it times every word. A better voice is still wanted: another
   downloaded voice, or the presenter's own reading or a cloud voice imported from Cutaway.

---

## Document History

| Version | Date | Changes |
|---|---|---|
| 0.13 | 2026-11-09 | Plan 011 (#22): four built-in samples in their own section of the Scripts screen, seeded at launch and adopted from pasted copies, never deleted or replaced by a paste (4.1, 8.1); the format labelled Markdown where users see it; the README; version 0.1.0 and the release scheme, tags on `main` with no binary; the licence, PolyForm Noncommercial with a permission to make videos commercially; an App Store version planned (1, 1.3, 2). No More menu: the voice, Personal Voice and Stage Directions in a Voice group in Settings, Read Cues on the start card, Delete Script at the foot of the Script screen (4.8, 8.2, 8.4). The light scheme, mid-blue toolbar buttons and Earwig's own back button and Lead stepper (10). Stage 7 is plan 012. |
| 0.12 | 2026-11-09 | Plan 010 (#16): recording a take, Off, Sound or Video, as built and checked on the iPhone 14 Pro with the SK18 (4.7). The front camera at 1080p30 (default) or 4K30, the sound from the built-in mic, never the earpiece; the audio session, route and engine untouched, and the follow the same filmed as not. Framing on the preview before Start; the camera behind the text while the take runs, the text's brightness set on the preview (8.3). Locking stops the video while the sound and the take go on. Finished saves, then Play Video, Play Sound or Play Back, and Share with Save Video. Files in Earwig's folder in Files, the last kept or every one, and Delete All (4.8, 8.4). Settings' footers cut to one line or none (4.8). The new services (7.2); heat (11); Phase 3 is what is left (12, 13). Non-goals (1.4). |
| 0.11 | 2026-11-08 | Plan 009, longer phrases: a clause with no break is cut only past twenty words, after the voice stopped mid-clause on the phone ("…that ground flour for"); stored scripts are split again (3, "Phrase"). After a final, the presenter is taken to have begun the voice's phrase only if heard within three words of it, after silence let two phrases through once Andy had stopped mid-phrase (5.4). Stopping the voice for a fluff, and the text going back to the phrase's start after one, were tried on the phone and dropped: the recogniser mishears some words every time, and each looked like a fluff (recorded in the plan). |
| 0.10 | 2026-11-08 | Plan 008 (#25), stage 6: Screen mode as built and judged on the phone. Every take scrolls the script, With Voice or Screen Only, chosen on the start card or in Settings and fixed for the take; Ear alone dropped (Executive Summary, 4.6, 4.8, 8.3, Flow 2, Flow 3). The eyeline with the heard words dimmed, no word marker; the voice's phrase lit as a setting, off by default (4.6). Following with no voice, the screen's place as the word after the last one heard, and what was said before Back or Forward not followed (5.4a). The start card, Start Take on the step's card (8.2). The Prompt screen's one layout (8.3). ScreenText and the screen's view models (7.2, 7.3). Stage 6 done (12). |
| 0.9 | 2026-11-08 | Plan 007 (#21): the app icon, the mark and the splash, with the launch colour and the splash's rules (10); the plan noted beside the stages (12); folders (7.3). Checked on the iPhone 14 Pro: the icon in the three appearances, the splash on a cold launch only, no visual refresh asked for. |
| 0.8 | 2026-11-08 | Plan 006 results (#18, #19): a take whose listening gives up stops and says why (4.3, 8.3); for a gate, the presenter estimate does not coast across a phrase end until a word of the next phrase is heard, so off-script speech after a phrase end holds the voice (5.4). Checked on the iPhone 14 Pro: off script at a phrase end, a misheard phrase end, a clean read, a filler, and listening giving up. |
| 0.7 | 2026-11-08 | Plan 005 results: the default lead 5, hybrid pacing and tones only, chosen on the phone (3, 4.4, 4.5, 4.8, 5.5, question 1); a voice speed, default 0.95x, as the base the player plays the voice at (4.2, 4.8); the route check during a take, amber on the speaker, an earpiece put away ending the take (4.3, 7.2, 11); the whole sentence shown while the voice waits, and no automatic re-giving after a fluff (4.4, 8.3); Forward from the last phrase does nothing, Start on the start step's card (4.4, 8.2); a take recorded at its slate (4.7); a 24-word window behind, a misread word not a jump, and completion timed from the presenter's last word (5.3, 5.4); the take host and the Slate service (7.2); the Prompt screen and the first Settings screen as built (8.3, 8.4); the measured lead and delays, outdoors and the Osmo still to do (4.4, 11); stage 5 done (12). |
| 0.6 | 2026-11-07 | Plan 004 results: rendered audio held in memory, the start step rendered when chosen, nothing saved (2, 3, 4.2, 6.1, 9); Personal Voice tried and dropped, Stephanie the default and any good English voice pickable (Executive Summary, 4.2, 4.8, 11, questions 5 and 6); the cue voice the other gender first, the slate's text, a shot ID spelled out (4.2); directions inside a line a setting, a low chime by default or spoken (4.2, 4.8, question 4); the tones (4.5); the player's position where the presenter hears it and phrase ends on render (5.1); services and folders (7); the rendering row and Listen (8.2); our own Paste button in place of `PasteButton` (4.1, 8.2); stage 4 done (12). |
| 0.5 | 2026-11-06 | Plan 003 results: the lead is the felt head start, default 3 (3, 4.4); the gate counted to the phrase boundary (4.4, 5.4); re-anchoring in place of the three targets for stepping back, picking up and jumping, and a lost search over the take's step only (4.4, 5.3, 5.4); the manual controls as built (4.4); three start modes in Settings (4.5, 4.8, 5.5, question 1); the engine's inputs and outputs as built, with time passed in (5.1, 5.2); matching with its folds, confidence and a 12-word window behind (5.3); the presenter estimate as built and the hybrid speed's sign fixed to 1 − k·e (5.4); completion (5.4); folders (7.3); the numbers risk (11); stage 3 done (12). |
| 0.4 | 2026-11-06 | Plan 002 results: paste import confirmed on the iPhone with no Allow Paste prompt, and a file copied in Finder pastes only its name (4.1, P1 row); the Cutaway and plain parsing rules as built, square brackets as the only inline directions, re-paste by stated title (4.1); script words read at parse time, a number run never crossing punctuation (5.1); the entities as built, with the phrase list's parser version (6.1); folders (7.3); screens (8.1, 8.2); the theme, one sky-blue look not split into light and dark (10); stage 2 done (12). |
| 0.3 | 2026-11-05 | Plan 001 results (spike on the iPhone 14 Pro with the SK18 earpiece): Stephanie (Enhanced) is the default voice until Personal Voice is judged; the default lead is 5 words; the earpiece holds A2DP with the mic open and recognition runs locked, so those risks are retired; recognition is about 0.9 s behind, untimed in its interim results, and fed untimed audio (4.3); the engine estimates the presenter's place and adds the delay (5.4) and treats numbers, compounds and contractions as said (5.1); render and rate details (4.2); fluffs (4.4); open question 6. |
| 0.2 | 2026-11-05 | The App Store Connect key lives in the Keychain under a team-level name, not in a file; the app itself has no keys (section 2). Repo public. |
| 0.1 | 2026-11-05 | First draft from the author's answers: Osmo as camera with the iPhone in a pocket or on a mount; in-ear Bluetooth earpieces as output only; Personal Voice first with downloaded voices as fallback; on-device recognition; hybrid pacing with phrase gating as the fallback; configurable lead with the default from the spike; paste import first; cues in a second voice; no mirror, pedals or remotes; name Earwig. |
