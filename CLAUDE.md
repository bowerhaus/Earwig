# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Earwig is a personal iPhone app (iOS 26+, SwiftUI) that reads a script into one Bluetooth earpiece slightly ahead of the presenter and follows what they actually say: it waits at a phrase end when they pause and picks them up again where they are. The script is pasted in (first of all a Cutaway project's `script.md`), rendered on the phone with word timings in the presenter's Personal Voice or a downloaded Apple voice before a take, and followed with Apple's on-device `SpeechAnalyzer`. The same engine drives an on-screen teleprompter. Distributed to its author through TestFlight; never sold.

Sibling projects with the same conventions: `../Brollee` (local), and PhysiMate and Reclaim (private repos `bowerhaus/PhysiMate`, `bowerhaus/Reclaim`; read them with `gh api repos/bowerhaus/<repo>/contents/<path>`). PhysiMate is the closest match.

**The repo is public** (`bowerhaus/Earwig`, MIT). Everything committed and every issue is public: test fixtures and examples are made-up scripts, never the author's unpublished video scripts.

## Status

Plan 001 (the voice, earpiece and recognition spike) is complete: PASS, results in its plan file, PRD v0.3. The spike screen is deleted; the services it proved stay (`AudioSessionManager`, `VoiceRenderer`, `AudioEngineHost`, `Listener`, `PhraseSplitter`, `WordNormaliser`). The default voice is Stephanie (Enhanced, en-GB); Personal Voice was judged worse in plan 004. Plan 002 (skeleton, models, parser) is complete, PRD v0.4: paste import, the Cutaway and plain parsers, script words with a number as one word, the SwiftData models, the Scripts and Script screens, and the one sky-blue theme. Plan 003 (the follow engine) is complete, PRD v0.5: `Engine/` matches heard words to the script (numbers, spellings, compounds, contractions), estimates where the presenter is now from the measured recogniser delay and speaking rate, paces and gates the voice, re-anchors on a step back, a skip or a recovery, and runs the three start modes and the manual controls; it is tested by unit tests and by simulated takes (`EarwigTests/Simulation/`). The lead is in words of felt head start (the engine adds the recogniser's delay itself); the engine's own default is 3, and the app's is 5 since plan 005. Plan 004 (renderer and player) is complete, PRD v0.6: the start step is rendered in memory with word timings when it is chosen (nothing saved), Stephanie presents and Jamie reads cues, the player plays the engine's commands on one engine (voice, cue and tone channels) and reports where the presenter hears the voice, allowing for the output latency (356 ms on the SK18), and Listen on the Script screen plays a step straight through. Directions inside a line are chimed (default) or spoken, a setting in the Script screen's menu until Settings. Personal Voice was tried and dropped. iOS 27 puts a voice's quality in its name ("Stephanie (Enhanced)"). Plan 005 (listener and the Prompt screen, Ear mode) is complete, PRD v0.7: the listener feeds the engine through `HeardEvents`, and `TakeHost` runs a take from getting ready to its end (ticking the engine at 20 Hz, recording the take at its slate, a call or a put-away earpiece ending it) behind protocols tested with fakes; the Prompt screen (status, the voice's phrase, or the whole sentence while it waits, the controls, the route check, a diagnostics line); Start on the rendering row and on the start step's card; a first Settings screen (lead, pacing, voice speed, start mode, the Listening check) from a gear on the Scripts screen. The defaults are Andy's picks on the phone: lead 5, hybrid, voice speed 0.95x (the player's base speed; cues stay at 1.0x), tones only; the engine's own `FollowSettings` defaults stay as its tests expect. After a fluff the voice waits and re-gives nothing by itself (automatic re-giving was tried and dropped). The matcher looks 24 words behind, and a misread word is not a jump. Plan 006 (#18, #19) is complete, PRD v0.8: a take whose listening gives up stops and says why, and for a gate the presenter estimate does not coast across a phrase end until a word of the next phrase is heard, so off-script speech after a phrase end holds the voice (pacing keeps the free coast); the simulated takes run at the app's lead at 2.5 and 4 words a second, with interim results in bursts a second apart as on the phone. Outdoors and the Osmo wait for the next shoot. Plan 007 (#21, beside the stages) is complete, PRD v0.9: the app icon (a white earwig crawling at 35° on sky blue, in the light, dark and tinted appearances), the same mark as a transparent `EarwigMark` image, the launch screen as the theme's sky blue alone, and a splash that fades the mark and the name in and out over the Scripts screen in under a second on a cold launch only (`showsSplash` in `EarwigApp`, never reset, so a return from the background shows nothing). Plan 008 (stage 6, Screen mode, #25) is complete, PRD v0.10: every take scrolls the script on the phone, **With Voice** (the voice in the earpiece too) or **Screen Only** (no voice, nothing rendered, so it starts at once), chosen on the Script screen's start card or in Settings and fixed for the take; Ear alone was dropped. With no voice the engine follows the presenter alone (`FollowSettings.voiced`). The screen's place is the word after the last one heard, never a guess ahead (guessing, and the rules to undo it, were tried and removed); `ScreenPlace` smooths it with two rules, a move glides and otherwise it follows forward and never back. The line being read sits at an eyeline a third of the way down and the words heard turn faint, with no word marker; the voice's phrase is lit only if Settings says so (off by default). Back and Forward ignore what was said before the press. Text size 24 to 72 pt, default 40, and a pinch. The fixed-pace scroll is its own issue. Plan 009 (longer phrases) is complete, PRD v0.11: a clause with no break is cut only past 20 words (`PhraseSplitter.maxClauseWords`; parser version 2, so stored scripts are split again), and after a final the presenter is taken to have begun the voice's phrase only if heard within 3 words of it (`lateStartReach`). Stopping the voice for a fluff, and the text going back to the phrase's start after one, were tried and dropped: the recogniser mishears some words every time ("leat" as "elite"), and each looked like a fluff. Back after a fluff gives the presenter's phrase again. Next is plan 010 (#16, `plans/010-take-recording.md`): recording a take, as sound or as front-camera video, and playing it back; stage 7 (Settings and TestFlight) follows as plan 011. The Xcode project is generated by xcodegen from `project.yml` (run `xcodegen generate` after adding or removing files; never hand-edit `Earwig.xcodeproj`, which is git-ignored). Versions come from `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`), which `Info.plist` reads.

## Build Commands

```bash
xcodegen generate
xcrun simctl boot "iPhone 17"   # boot once per session to avoid ~60 s per run
xcodebuild -scheme Earwig -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DerivedData test
swiftlint lint --quiet
uv run --with pillow scripts/app_icon/make_app_icon.py   # redraws the icon and the mark into the asset catalogue
```

Tests use Swift Testing (`import Testing`). Keep the build free of warnings and SwiftLint clean. A test that uses an in-memory `ModelContainer` must hold the container for as long as it uses its context, or the test host crashes. In the simulator, launch with `-EarwigDemo YES` (Debug builds) to add the sample script and open it without taps; add `-EarwigListen YES` to open Listen on its start step once it is rendered, or `-EarwigTake YES` to start a take; `-EarwigNoListen YES` makes a take hear nothing, since the simulator cannot transcribe en-GB; `-EarwigListenGivesUp YES` makes listening give up ten seconds into a take. `-EarwigScreen YES` starts a Screen Only take on the demo script, and `-EarwigReads YES` makes a take hear the step read at 2.5 words a second, so the simulator shows the text following. Pass launch arguments to `devicectl device process launch` after `--`.

Audio, Bluetooth routing, Personal Voice, speech recognition and lock-screen behaviour cannot be verified in the simulator. Anything in the audio path must be checked on the author's iPhone 14 Pro. Claude installs it there directly, without opening Xcode (find the phone's UDID with `xcrun devicectl list devices`):

```bash
xcodebuild -scheme Earwig -destination 'id=<UDID>' -derivedDataPath build/DerivedData -allowProvisioningUpdates build
xcrun devicectl device install app --device <UDID> build/DerivedData/Build/Products/Debug-iphoneos/Earwig.app
xcrun devicectl device process launch --device <UDID> com.bowerhaus.Earwig
```

## Architecture

**Pattern:** MVVM with `@Observable` view models and SwiftData (PRD §7).

```
Views (SwiftUI) → ViewModels (@Observable) → Models (SwiftData)
                          ↓
   Services: ScriptParser, ScriptImporter, PhraseSplitter, VoiceRenderer, ScriptRenderer,
             VoiceCatalogue, Slate, Tones, AudioSessionManager, AudioEngineHost, Player,
             TakeAudio, StepPreview, Listener, HeardEvents, TakeHost, TakeSummary,
             ScriptTakeRecorder, ScreenText
                          ↓
   Engine/: FollowEngine, Matcher, PresenterEstimate, Pacer, WordFolding, WordNormaliser,
            ScriptWords, FollowScript (pure Swift; time passed in)
```

- `Engine/` is pure Swift with time passed in on every call (`handle(_:at:)`, `tick(at:)`): **no SwiftUI, UIKit, SwiftData, AVFoundation, AVFAudio, Speech or Combine imports**; pass it plain values, never `@Model` objects or audio types. The `engine_purity` SwiftLint rule fails on those imports.
- The audio session is `.playAndRecord` with Bluetooth allowed for A2DP output only (`.allowBluetoothA2DP`, never `.allowBluetoothHFP`) and the built-in mic as preferred input. The earpiece is never the microphone.
- The take's step is rendered with word timings before it starts, in memory; the player is indifferent to where the audio came from. Phrase ends are reported on render (`.dataRendered`), not playback, so no output latency is added between phrases; progress is reported where the presenter hears it.
- `SpeechAnalyzer` gets untimed `AnalyzerInput` (stamped input ends its results). Interim results are one untimed block per stretch of speech; only finals time each word. Match interim text by order (plan 001 Results).
- Word markers from `AVSpeechSynthesizer.write` arrive by the marker callback or the `willSpeakMarker` delegate depending on the voice; `byteSampleOffset` is in bytes.
- Swift Concurrency throughout; no third-party dependencies, Apple frameworks only.
- All colours live in `EarwigTheme`; views never define their own.
- UK spelling in UI text and code names (`normalise`, `colour`).

## Rules

- **One plan per branch.** Each stage in PRD §12 is one plan (`plans/NNN-name.md`), one branch, one GitHub issue and one PR. A plan ends with a filled **Results** section where a spike or device check calls for one, and the PRD gets a version bump and a Document History row when a stage completes.
- **`progress.md` is scratch state for the plan in flight**, overwritten at the start of a plan and emptied to a stub when it completes. Nothing that must outlive the plan goes there; that belongs in the plan's Results, the PR body or the PRD's Document History.
- **Never guess a device result.** Verdicts on voice, earpiece, recognition and feel come from the author; record only what he reports.

## Git Workflow

- Claude commits locally at sensible points without asking.
- Pushing, opening a PR and creating a GitHub issue each need the author's yes.
- Branch per plan, PR to `main`.
- Keys: the app has none. The App Store Connect key lives in the macOS Keychain under service `bowerhaus.appstoreconnect`, used only by the release script (a later stage). Claude never reads, prints or handles a key's value.

## Reference Documentation

| Document | Purpose | When to Consult |
|----------|---------|-----------------|
| [PRD.md](PRD.md) | Complete product specification; Document History records each change | Authoritative source for requirements; §5 for the follow engine; §12 for MVP stages |
| [plans/](plans/) | Implementation plans, one per branch | Check for the active plan before starting work |
