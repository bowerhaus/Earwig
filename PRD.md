# Earwig - Product Requirements Document (PRD)

**Status:** Draft v0.4, 2026-11-06. Changes by version are in the Document History at the end.
**Name:** Earwig (decided 2026-11-05: UK slang for listening in). Bundle identifier `com.bowerhaus.Earwig`.

## Executive Summary

Earwig is a personal iPhone app that reads a script into one ear, slightly ahead of the
presenter, and follows what the presenter actually says. The presenter speaks a few words
behind the voice in their ear; when they slow down, the voice slows; when they stop or
wander off the script, the voice waits at the end of its phrase and picks them up again
where they are. The script is text from elsewhere (first of all a Cutaway project's
`script.md`), turned into speech on the phone in the presenter's own voice (Apple's
Personal Voice) or a downloaded Apple voice, with word timings, before the take starts.

The same script, voice rendering and following engine also drive an ordinary on-screen
teleprompter, where the text scrolls at the presenter's pace instead of being spoken.

Earwig is for the author's own video work (the Cutaway toolkit's videos, filmed on an
Osmo Pocket 3 or the iPhone itself). It is distributed to the author through TestFlight,
in the mould of Brollee, Reclaim and PhysiMate, and will never be sold.

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
- Nobody else in v1. TestFlight is the install path, not a distribution channel.

### 1.4 Non-Goals

- Not a script editor. Scripts are written elsewhere (Cutaway, a text file). Earwig
  parses, shows and plays them; a rewrite is a new paste.
- Not a camera app in v1. The camera is the Osmo. Filming on the iPhone with Earwig
  prompting is a later phase (section 13), because the stock Camera app takes the audio
  session when it records and silences any other app.
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
| Persistence | SwiftData for scripts, renderings, takes and settings; rendered phrase audio as files in Application Support, referenced by the rendering record. |
| Project | XcodeGen from `project.yml`; never hand-edit the generated `.xcodeproj`, which is git-ignored. Version and build number live in `project.yml`. |
| Tests | Swift Testing (`import Testing`). The follow engine and the script parser are pure Swift and fully unit-tested with fixture word streams. |
| Lint | SwiftLint, with an `engine_purity` custom rule as PhysiMate's: `Engine/` imports no UI, audio, persistence or Combine framework. |
| Dependencies | None. Apple frameworks only: AVFoundation (`AVSpeechSynthesizer`, `AVAudioEngine`, `AVAudioSession`), Speech (`SpeechAnalyzer`, `SpeechTranscriber`), SwiftData. |
| Distribution | TestFlight, uploaded by `scripts/release/testflight.sh`; cloud-managed distribution signing; the script refuses a dirty tree, a stale project or a build number already tagged, and tags `testflight/<version>-<build>`. Builds expire after 90 days. |
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
| **Phrase** | The unit of playback and gating: a line split at sentence ends and at clause breaks (commas, dashes, semicolons) so no phrase is longer than about twelve words. The voice can only wait at a phrase boundary. |
| **Rendering** | A phrase's audio in one voice, with the start time of every word in it. All of a script's phrases are rendered before a take, and cached by script hash and voice. |
| **Lead** | How far ahead of the presenter the voice runs, set in words (default 5, found in plan 001), with the equivalent in seconds shown. |
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
| Import by paste from the clipboard (Universal Clipboard from the Mac) | P0 | The Scripts screen has a Paste button (SwiftUI's `PasteButton`, so no Allow Paste prompt; confirmed on the iPhone in plan 002); Earwig detects the format (Cutaway when the text has a `## ` heading and a `Says:` field) and names the script from its title or first line. The clipboard must hold the script's text: a `script.md` copied as a file in Finder pastes only its name (plan 002). |
| Parse Cutaway `script.md` (`cutaway/script@1`) | P0 | As Cutaway's own parser, but lenient: a misnumbered or unnumbered step is kept, not an error. Title `# Script: X` (prefix optional), the first such line before the first step; steps `## N. Title`; `Says:` items (`- `, `* `, `+ `) are lines; `Shows:`, `Footage:`, `Open:` and an old `Notes:` are directions; fields may be bold; a source span in round brackets at the end of a line is stripped; run-on indented lines are joined. Text before the first step is kept as a preamble, shown, never spoken. Unknown lines are kept as directions. |
| Parse plain text | P0 | Blank-line-separated blocks are steps (no blank lines: one step); a block's first line is its title if it has at most eight words, no sentence-ending punctuation and more lines after it. The script's title is a leading `# ` line, or a first block that is only such a title line, or else the first line cut to 40 characters. |
| Directions inside a line | P0 | Square brackets only, in both formats: `[Gesture to the boats]` is a direction at that point, read in the cue voice. Round brackets are spoken. |
| Show a script as its steps with each step's lines and directions | P0 | Read-only. The start-from-step picker lives here. |
| Re-paste replaces a script's text, keeping its takes | P0 | The same text (line endings and trailing spaces aside) opens the stored script. A paste whose stated title (a `# ` line, or a plain script's lone title line) matches a stored script's, ignoring case, replaces that script's text and keeps its takes, renderings, cues setting and start step; a title taken from a first line or first step never replaces another script. The Script screen has Paste new version for a script whose title changed. Renderings are re-used for unchanged phrases (stage 4). |
| Delete a script | P0 | |
| Import from the share sheet and Files, and a pasted file | P1 | After paste proves the flow. Includes a `script.md` copied as a file in Finder, which today pastes only its name. |
| Watch an iCloud Drive folder so a Cutaway project's script appears by itself | P2 | Roadmap, section 13. |

### 4.2 Voice Rendering

| Feature | Priority | Notes |
|---|---|---|
| Render every phrase of a script before a take, with word timings | P0 | `AVSpeechSynthesizer.write(_:toBufferCallback:toMarkerCallback:)` for the audio; the word boundaries come from word markers, by the marker callback or the `willSpeakMarker` delegate (whichever the voice sends), with `byteSampleOffset` in bytes. The `willSpeakRangeOfSpeechString` delegate is no use for timing during `write`, which runs far ahead of real time (plan 001). The downloaded voices render about 40 times faster than real time on the iPhone 14 Pro, so a progress bar is only needed for long scripts; cached afterwards by script hash and voice. |
| Presenter's voice: Apple Personal Voice | P0 | Trained once by the presenter in Settings, Accessibility, Personal Voice, with Allow Apps to Request to Use on. Earwig requests authorisation in code (there is no usage-description key) and lists the Personal Voices available. Not yet judged: the author had not made one at plan 001; it is to be tried against Stephanie for quality, render speed and word markers once made (section 15). |
| Default voice until Personal Voice is judged: Apple downloaded voices | P0 | Stephanie (Enhanced, en-GB) is the default, the author's pick in plan 001 ("okay, not fantastic"); Jamie (Premium, en-GB) is the alternative. Both rendered every word with timings. Compact default voices are listed but marked poor. |
| Cue voice for slates and directions | P0 | An Apple voice chosen in Settings, by default the best downloaded voice that is not the presenter's. Directions read as cues: at the start of a step, its number and title, then its `Shows:` text ("Step three. Rosie up ahead. Rosie trots far ahead up the long track."). A per-script switch turns cues off; a bracketed direction inside a line is read in the cue voice at that point. Cues are never matched. |
| Rate | P0 | A base speaking rate per voice in Settings, applied at render time (default 0.5). The engine's pacing changes playback speed, not the render; 0.85x to 1.2x through the time-pitch node sounded natural in plan 001. |
| Import a rendering made elsewhere | P2 | A folder of phrase audio and a timings file, as Cutaway could produce with ElevenLabs or from the presenter's own recording (section 13). |

**Why pre-render.** The synthesiser cannot change speed mid-utterance, Personal Voice
renders slower than real time on some phones, and a future cloud or recorded voice
arrives as files. Rendering everything to buffers up front makes the player and the
engine indifferent to where the voice came from, and makes the take itself free of
synthesis latency.

### 4.3 Listening

| Feature | Priority | Notes |
|---|---|---|
| On-device continuous recognition of the presenter | P0 | `SpeechAnalyzer` with a `SpeechTranscriber` in the script's locale (en-GB), volatile and fast results on, with audio time ranges, the script's words as contextual strings. The mic audio is fed untimed (stamping it made the analyser stop with "audio input timestamp overlaps or precedes prior audio input"). Interim results come as one untimed block of text per stretch of speech, rewritten as it grows, about 0.9 s behind the presenter; finals time every word but arrive only at a pause. So the engine follows the interim text by word order and takes exact times from finals. Listening restarts itself if its results fail, and the audio engine restarts on a configuration change. Locale assets are downloaded once through `AssetInventory` with a prompt. |
| The iPhone's own microphone, always | P0 | The audio session is `.playAndRecord` with Bluetooth allowed for A2DP output only (never the hands-free profile), and the preferred input set to the built-in mic. The earpiece is never the microphone: the hands-free profile would drop its audio to telephone quality and use its poor mic. |
| Route check before a take | P0 | The Prompt screen shows the output route and input in use and warns if the earpiece has fallen into the hands-free profile or the input is not the built-in mic. |
| Runs locked and in a pocket | P0 | Background audio mode; recognition continues with the screen off (verified for over eight minutes locked in plan 001). The pocket is a supported position, the mount beside the lens is the designed one (section 11). |
| Listening check screen | P0 | Shows recognised words live with their delay, the input level, and the route. Used by the spike and kept as a diagnostic in Settings. |

### 4.4 Following

The follow engine (section 5) takes the script's phrases with word timings and the
stream of heard words, and decides what the player does.

| Feature | Priority | Notes |
|---|---|---|
| Hold the lead | P0 | The voice stays about `lead` words ahead of the presenter. Default 5 words, the author's preference in plan 001; shorter leads left a gap at every phrase end. Five words is about two words of felt head start plus the recogniser's delay, so the engine should measure that delay and add it itself (5.4), and the setting can then come down to the felt head start. |
| Hybrid pacing | P0 | Playback speed is nudged between bounds (default 0.85x to 1.2x, in Settings) to keep the lead; a phrase boundary is a gate: the next phrase starts only when the presenter is within `lead` words of the end of the current one. Phrase-gated only, with speed fixed at 1.0x, is the first milestone and remains available as a setting. |
| Wait | P0 | When the voice reaches a gate and the presenter is not there, it waits silently. No filler, no repeat. |
| Pick up again | P0 | While waiting, every heard word is matched first near the expected position, then across the whole step, then the script. On a confident match the voice resumes from `lead` words past the presenter, at the next phrase start on or after that point. |
| Off piste | P0 | Heard words that match nothing are ignored. The voice waits at its gate for as long as it takes. |
| Fluffs and restarts | P0 | A presenter who goes back and says a phrase again is matched where they are, so the voice steps back with them. In plan 001, without stepping back, the gates already held while the presenter repeated a line, and the author "could live with" every fluff; the one awkward case is a restart after the gate has opened, when the voice is already into the next phrase. Stepping back should be simple: replay from the phrase the presenter is in. |
| Manual controls | P0 | On screen, large: Hold (toggle), Back a phrase, Forward a phrase, Restart the step, Stop. Where else they live (an earpiece button, a Watch) is open (section 15). |
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
3. Three short tones, then the first phrase plays in the presenter's voice. The presenter
   starts speaking `lead` words behind it; from here on the engine follows.

Alternatives, kept for the first plan to try:

- **Tones only.** Press Start, three tones, first phrase. Simplest; no slate heard by the
  camera and no proof that listening works before the take.
- **Spoken trigger.** The presenter says "go" or "action"; Earwig starts on hearing it.
  Hands-free, but a word the camera hears and the editor must cut, and a false start on
  stray speech.
- **First phrase, then gate.** Press Start and the first phrase plays at once; every later
  phrase is gated as normal. Nothing to say first, but no slate.

The slate flow is the recommended default; tones-only is a setting for shoots that slate
another way.

### 4.6 Screen mode (teleprompter)

| Feature | Priority | Notes |
|---|---|---|
| Scrolling text with the current phrase highlighted and the presenter's heard position marked | P0 | Large type, dark background, the step title small at the top. Portrait and landscape. The same engine positions the text: the highlighted phrase is the voice's position, the mark is the presenter's. |
| Ear and Screen together | P0 | On the mount beside the lens the screen shows the text while the earpiece speaks it. Either can be switched off. |
| Fixed-pace scroll when listening is off | P1 | Words per minute in Settings, start and stop on tap. |
| Font size | P0 | A setting, and a pinch on the Prompt screen. |
| Directions shown in the cue colour, never highlighted as spoken | P0 | |
| Mirror flip, external display, pedal or remote | Out | Not wanted. |

### 4.7 Takes

A take is one attempt at one step. Earwig numbers takes per step from 1, says the number
in the slate, and keeps a list per script: step, take number, when, how long, and whether
it ran to the end of the step or was stopped. This is what lets the slate on the camera's
sound track say "take two" and mean it, and lets the next shoot carry on from "take
three". Nothing the presenter said is kept in v1.

The take record for Cutaway (the take's audio, the words heard with their times, and the
slate) is a roadmap item (section 13): cheap once the microphone is open, but scope.

### 4.8 Settings

- Presenter's voice (Personal Voice or downloaded voice), base rate, and a Preview button.
- Cue voice, cues on or off by default.
- Lead, in words, with seconds shown for the chosen voice and rate.
- Pacing: hybrid or phrase-gated; speed bounds.
- Start ritual: slate or tones only.
- Screen: font size, fixed-pace words per minute.
- Diagnostics: the Listening check (4.3) and the route check.

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
  matcher's (stage 3).
- Each phrase's rendering duration and per-word start times.
- **Heard words**: from the recogniser, each with its normalised text, whether it is
  volatile or final, and for finals its start time on the engine's clock. Volatile words
  have no times of their own (4.3): they are matched by order and move the position
  tentatively; final words commit it.
- The player's reported playback position (phrase and word).
- Settings: lead, pacing mode, speed bounds, and the thresholds in 5.3.

### 5.2 Outputs

Commands to the player and the screen: play phrase n at speed r; set speed r; wait at the
end of phrase n; jump to phrase m; and position updates (voice position, presenter
position, confidence) for the screen and the diagnostics.

### 5.3 Matching

- The engine keeps an **expected position**: the last committed presenter position
  advanced by the words heard since.
- A heard word is matched within a **window** of script words around the expected
  position (default 8 words behind to 12 ahead). A match is exact on the normalised form,
  or within a small edit distance for words of five letters or more.
- Runs count: two consecutive heard words matching two consecutive script words in the
  window commit the position; a single match only moves it tentatively. This stops a
  common word ("the", "and") jumping the position.
- When nothing has matched for `lostWords` heard words (default 6) or `lostSeconds`
  (default 4) the presenter is **lost**: the window widens to the current step, then the
  whole script, and a run of three consecutive matches is needed to commit. Once committed
  the voice resumes as 4.4 "Pick up again" says.
- Heard words that match nothing are dropped. The engine never guesses a position.

### 5.4 Pacing

- The **presenter position** used for pacing and gates is an estimate of where the
  presenter is now: the last heard word advanced by their speaking rate over the time since
  it was heard, plus the recogniser's measured delay (about 0.9 s in plan 001). Waiting for
  the recogniser alone stalls a gate, worst on a short phrase just after a final, when the
  first interim result can arrive 1.5 s late.
- Error `e` = (voice position − presenter position) − lead, in words.
- Hybrid: speed = clamp(1 + k·e, minSpeed, maxSpeed), with k such that one word of error
  changes speed by about 0.05x; speed changes are rate-limited so the voice never lurches.
- Phrase-gated: speed stays at 1.0x.
- At the end of phrase n the voice **waits** unless the presenter's position is at least
  (end of phrase n − lead). While waiting the speed logic is off. On release the next
  phrase starts at speed 1.0x.
- When the presenter is ahead of the voice (e < −lead), the engine jumps to the phrase
  containing (presenter position + lead) rather than speeding up past maxSpeed.

### 5.5 Start

The engine starts in **slate** state: it plays the slate cue, then listens for the slate
words (a step number or shot ID, "take", a number). On hearing them, or on a tap, it emits
the tones and plays phrase 1. In tones-only mode it skips the slate.

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
  of phrase to audio file name and word start times. Files live in Application
  Support/Renderings/<script hash>/<voice>/.
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
             RenderingStore, AudioSessionManager, Listener, Player, Slater
                          ↓
   Engine/: FollowEngine (pure; words in, commands out)
```

### 7.2 Key Services

- **ScriptParser**: text to steps, lines and directions; the Cutaway and plain formats.
- **PhraseSplitter** and **WordNormaliser**: shared by the parser and the engine; the
  normaliser mirrors Cutaway's rules so what Cutaway calls "as spoken" matches here too.
- **VoiceRenderer**: renders phrases to buffers with word timings through
  `AVSpeechSynthesizer`; one queue, progress reported; results to **RenderingStore**.
- **AudioSessionManager**: configures the session (`.playAndRecord`, A2DP output only,
  built-in mic input), reports the route, handles interruptions (a call pauses the take;
  resume by hand).
- **Listener**: wraps `SpeechAnalyzer`; feeds the mic to the transcriber and emits
  heard words with times to the engine.
- **Player**: `AVAudioEngine` with a `varispeed` or `timePitch` node (time-pitch, so
  slowing down does not drop the voice's pitch), plays rendered phrases on command, and
  reports its position by the audio clock. Tones are scheduled on the audio clock, as
  PhysiMate's plan 001 found necessary.
- **Slater**: the start ritual (4.5).

### 7.3 Folder Structure

```
Earwig/
  App/           EarwigApp, AppState
  Models/        SwiftData models, PhraseList, ModelJSON, Settings
  Engine/        FollowEngine, Matcher, Pacer, WordNormaliser, ScriptWords (pure Swift)
  Services/      ScriptParser, ScriptImporter, PhraseSplitter, VoiceRenderer, RenderingStore,
                 AudioSessionManager, Listener, Player, Slater, ModelContainerFactory
  ViewModels/    ScriptsViewModel, ScriptDetailViewModel, …
  Views/         Scripts, ScriptDetail, Prompt, Settings, ListeningCheck
  Resources/     Info.plist, Assets, tones
EarwigTests/     Engine and parser tests with fixture word streams
scripts/release/ testflight.sh, ExportOptions.plist
plans/           One plan per branch
docs/            development.md (gotchas), this PRD stays at the root
```

---

## 8. Screens

### 8.1 Scripts

A list of imported scripts (title, step count, format, last take). Paste button in the
toolbar. Swipe to delete. Tap for the script. When empty: a Paste button and Try the
sample (a made-up harbour walk in Cutaway's layout).

### 8.2 Script

The steps, each with its lines and directions in the cue colour. A rendering status row
("Rendered in Andy, 42 phrases" or a Render button with progress). Tap a step to start a
take from it; the takes so far for that step are shown on it. Each step shows its number
large, as the slate says it. A menu holds the cues switch and Delete; Paste new version is
a button at the foot of the screen (a `PasteButton` cannot sit in a menu).

### 8.3 Prompt

The take screen, usable at arm's length and glanceable from a mount:

- Top: step title, take number, route check (earpiece and mic icons, red when wrong).
- Middle: in Screen mode the scrolling text (4.6); in Ear mode a large status word
  (Slate, Speaking, Waiting, Lost, Held) and the current phrase.
- Bottom: Hold, Back, Forward, Restart step, Stop. Big targets; the screen stays awake
  while the take runs.
- A take ends at the end of the step, on Stop, or on an interruption; the Script screen
  returns with the next take number ready.

### 8.4 Settings

As 4.8, grouped: Voice, Following, Start, Screen, Diagnostics.

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

Phone on the mount beside the lens, Ear and Screen both on. The text is there to glance
at, the voice is the one actually driving. Font large. Stop with a tap.

### Flow 3: A teleprompter, plain

A plain-text script pasted in. Screen mode only, Ear off, fixed-pace scroll at 140 words
a minute because the room is noisy. Pinch to size the type.

### Flow 4: The script changed

Cutaway's script was edited on the Mac. Copy it, open Earwig, Paste: the script's text is
replaced, unchanged phrases keep their renderings, the changed ones render, the takes
stay.

---

## 10. Design Language

One distinctive look, the same whatever the phone's light or dark setting, with no
separate light and dark variants (plan 002, the author's pick from nine candidates): a
clear sky blue as the ground, mid-blue cards with white text, a buttercup yellow accent
for the voice's phrase, the start step and the slate numerals, and peach for cues and
directions. High contrast and large type for arm's length. Few screens, nothing
decorative. SF Symbols. All colours in `EarwigTheme`; views never define their own.

---

## 11. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Personal Voice is not good enough to follow comfortably, or renders too slowly on the 14 Pro | Still open: no Personal Voice existed at plan 001. Stephanie (Enhanced) is the v1 default meanwhile, judged "okay, not fantastic" and rendering about 40 times faster than real time. Pre-rendering absorbs slow synthesis. If Personal Voice fails too, the ElevenLabs import (section 13) moves up. |
| The in-ear earpieces fall into the hands-free profile, so the prompt sounds like a phone call | Retired for the author's SK18: with the session allowing Bluetooth for A2DP only and the built-in mic pinned, it stayed in A2DP with the mic open through every take in plan 001, including over eight minutes locked, and the mic did not pick up the earpiece. The route check (4.3) still shows it on every take, for other earpieces. |
| Recognition is poor outdoors (wind, sea) or with the phone in a pocket | Indoors it is good in the hand and in a gilet pocket alike (plan 001: about 0.9 s median delay, 96 to 98% of script words, most misses spelling, not hearing). Outdoors and the mount are not yet measured; they are checked on the first real takes. The engine tolerates missed words (5.3, runs of two, lost after six). A lavalier into the phone is a possible later input. |
| Speed changes sound wrong | Time-pitch, not varispeed; narrow default bounds (0.85x to 1.2x); phrase-gated mode with no speed change as the fallback. |
| The lead is wrong for the presenter | It is a setting; plan 001 found 5 words by trial. The recogniser's delay is part of it, so the engine measures and adds that delay itself (5.4). |
| Speech recognition stops in the background or on lock | Retired: background audio mode kept the session alive with the screen locked for 8 min 20 s of looping takes in plan 001, with mic audio continuous throughout. Listening also restarts itself if its results fail. |
| en-GB on-device transcription assets are missing | Downloaded once through `AssetInventory` with a prompt; Settings shows the state. |
| Numbers, years and compounds stall the follower | Plan 001 saw a year at a phrase end hold a gate for 2.8 s at every lead, and "sea wall" heard as "seawall". The normaliser rules in 5.1 cover them; the engine's fixture word streams (stage 3) include years, numbers, compounds and contractions. |
| An incoming call | Pauses the take; the presenter restarts the step. Not tested in the spike (calls are rare; waived as in PhysiMate). |
| Earpiece audio heard by the Osmo | One listen on the first real take at the chosen volume. Expected inaudible. |
| Filming on the iPhone with Earwig running | Out of v1 (section 13). The stock Camera app stops Earwig's audio; the later mode films inside Earwig. |

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
3. **Follow engine.** Pure, with the matcher, the pacer, the gates, lost and resume,
   tested against fixture word streams (a clean read, a slow read, a fluff and restart, a
   stop and resume, a wander off script).
4. **Renderer and player.** Pre-rendering to files with timings, the rendering store,
   the audio session, the time-pitch player on the audio clock, tones.
5. **Listener and the Prompt screen, Ear mode.** The recogniser feeding the engine, the
   slate flow, manual controls, route check, Listening check in Settings.
6. **Screen mode.** The scrolling text driven by the same engine, Ear and Screen
   together, font size.
7. **Settings and TestFlight.** The settings in 4.8, the release script, the first
   TestFlight build.

### Excluded from MVP

Share sheet and Files import, fixed-pace modes, the take record, imported renderings,
filming on the iPhone, Watch or earpiece-button controls.

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

A camera view inside Earwig (front camera, recording to Photos) with the prompt running,
for the shots filmed on the phone. Its own plan: capture, framing aids, the audio session
shared between recording and listening.

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
  clean read.
- After a stop of ten seconds and a restart from the last phrase, the voice is back in
  step within one phrase.
- The earpiece plays at music quality throughout, with the built-in mic in use, and the
  route check never shows red on a take that was set up right.
- The author would rather use it than learn the script.

---

## 15. Open Questions

1. The start ritual: the slate flow (4.5) is recommended; confirmed or not after the
   spike.
2. Manual controls beyond the screen: whether the earpieces have a button worth mapping,
   or a Watch is wanted. Decide after a few real takes.
3. Commit policy for this repo: Cutaway's (Claude commits at sensible points, never
   pushes) or the iOS siblings' (commits only when asked). Proposed: Cutaway's.
4. Whether cues should also read a line's own bracketed directions mid-line, or only step
   directions at the start of a step. Proposed: both, with the per-script switch.
5. Whether Personal Voice's authorisation and the Personal Voice itself survive a
   TestFlight install (the voice lives in the OS, so it should).
6. Personal Voice against Stephanie, once the author has made one: quality through the
   earpiece, render speed, and whether its word markers arrive. Until then Stephanie is
   the default.

---

## Document History

| Version | Date | Changes |
|---|---|---|
| 0.4 | 2026-11-06 | Plan 002 results: paste import confirmed on the iPhone with no Allow Paste prompt, and a file copied in Finder pastes only its name (4.1, P1 row); the Cutaway and plain parsing rules as built, square brackets as the only inline directions, re-paste by stated title (4.1); script words read at parse time, a number run never crossing punctuation (5.1); the entities as built, with the phrase list's parser version (6.1); folders (7.3); screens (8.1, 8.2); the theme, one sky-blue look not split into light and dark (10); stage 2 done (12). |
| 0.3 | 2026-11-05 | Plan 001 results (spike on the iPhone 14 Pro with the SK18 earpiece): Stephanie (Enhanced) is the default voice until Personal Voice is judged; the default lead is 5 words; the earpiece holds A2DP with the mic open and recognition runs locked, so those risks are retired; recognition is about 0.9 s behind, untimed in its interim results, and fed untimed audio (4.3); the engine estimates the presenter's place and adds the delay (5.4) and treats numbers, compounds and contractions as said (5.1); render and rate details (4.2); fluffs (4.4); open question 6. |
| 0.2 | 2026-11-05 | The App Store Connect key lives in the Keychain under a team-level name, not in a file; the app itself has no keys (section 2). MIT licence; repo public. |
| 0.1 | 2026-11-05 | First draft from the author's answers: Osmo as camera with the iPhone in a pocket or on a mount; in-ear Bluetooth earpieces as output only; Personal Voice first with downloaded voices as fallback; on-device recognition; hybrid pacing with phrase gating as the fallback; configurable lead with the default from the spike; paste import first; cues in a second voice; no mirror, pedals or remotes; name Earwig. |
