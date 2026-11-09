# Plan 011: Built-in Samples, a README and the First Pre-release

**GitHub Issue:** [#22](https://github.com/bowerhaus/Earwig/issues/22) (PR must include "Closes #22")
**Branch:** `first-release` (from `main` at `9c2a4aa`, after plan 010 merged)
**Status:** Complete (2026-11-09, under `/plan_autopilot`; device checks and the README review by Andy the same day). A plan outside PRD §12's stages, as plan 007 was. Stage 7 (Settings and TestFlight) moves to plan 012.
**Manual test:** device and README review, on Andy's iPhone 14 Pro: the existing store opens with its scripts and takes, the three scripts already pasted become the samples without duplicates, and a take on a sample runs as before (Verification).
**Goal:** Earwig's first public pre-release, v0.1.0. A visitor who finds the repo learns what the app is, how to use it and how to build it, from a README with screenshots. Anyone who installs it finds four made-up scripts ready on the Scripts screen, with nothing to paste. A release is an annotated tag on `main` and a GitHub Release marked pre-release; the scheme is written down so the next one is cut the same way. It is published under PolyForm Noncommercial 1.0.0, with a permission to use the app to make videos commercially.

**PRD references:** §1, §2 (Distribution, Keys), §4.1, §8.1, §12, Document History.

---

## Context

On 2026-11-09 Andy asked what was left before a "0 point release" on GitHub, whether TestFlight had to come first, and for the test scripts to be in the app without loading. The answers that shaped this plan:

- **TestFlight does not come first.** A GitHub release is a tag and notes; visitors build from source with their own team, since an `.ipa` attached to a release will not install on a device it was not signed for (#22, part 2). TestFlight is how Andy's own builds reach his phone without `devicectl`, with its own work (the App Store Connect record, export compliance, the release script), and stays in stage 7, now plan 012. That answers #22's last acceptance criterion.
- **Nothing in the open issues blocks a 0.x release.** #30 (a fluff in the last phrase ends the take short) is the one real bug, and #33 (the route check's colour) is cosmetic; both go in the release notes as known issues. The voice and the directions setting still live in the Script screen's menu until stage 7.
- **The licence.** Andy wants the code used with attribution and for non-commercial purposes only, while anyone may use the app to make their own videos, commercial ones included: PolyForm Noncommercial 1.0.0 with an extra permission (decision 12).
- **The made-up scripts.** Only *The Harbour Walk* is in the repo (`SampleScript.harbourWalk`), behind "Try the sample" on the empty Scripts screen. *The Weekend Loaf* (plan 005, check 6) and *The Old Watermill* (plans 005 and 009; the one #30 was seen on) were written for device checks and pasted on the phone, never committed. On 2026-11-09 they were read off the phone's store, which development builds allow, so no export feature is needed:

  ```bash
  xcrun devicectl device copy from --device <UDID> --domain-type appDataContainer \
    --domain-identifier com.bowerhaus.Earwig --source "Library/Application Support" --destination <dir>
  sqlite3 <dir>/default.store "SELECT ZSOURCETEXT FROM ZSCRIPT WHERE ZTITLE = 'The Old Watermill';"
  ```

  The phone held only these three scripts, all made up, so all three can be committed. The phone's *Harbour Walk* is identical to `SampleScript.harbourWalk`, so it is adopted like the other two (decision 4). The test fixtures (Rosie, the Allotment, the Ferry Crossing) are format edge cases, too short to be samples.

## Scope

**In:**
- four built-in samples on the Scripts screen, always there, in their own section;
- `Script.sampleID`, and the seeding and adoption rules;
- `README.md`: what the app is for, a first-take tutorial, every feature and how to use it, with a banner, six screenshots and two diagrams;
- the release scheme, in the README and in CLAUDE.md;
- `MARKETING_VERSION` 0.1.0;
- the licence: PolyForm Noncommercial 1.0.0 with the extra permission (decision 12);
- the v0.1.0 tag and GitHub Release, cut after the PR merges.

**Out:**
- TestFlight, the release script and the remaining settings (stage 7, plan 012);
- a tab bar or a separate demo screen (decision 1);
- an export or share for scripts (the store can be read off the phone, above);
- fixing #30 or #33 (known issues in the notes);
- a binary attached to the release.

## Design decisions

1. **The samples are a section of the Scripts list, not a tab.** Two sections: the presenter's own scripts, untitled at the top, and **Samples** below them. A tab bar is a lot of furniture for an app with one list. The list is never empty now, so the empty screen and its "Try the sample" go. While there are no scripts of their own, the top section is one row: "Copy a script on your Mac, a Cutaway script.md or plain text, then paste it here", with the Paste pill. The Paste pill is in the toolbar once there are scripts of the presenter's own; until then the paste row carries it, so the list never shows two.

2. **Four samples, each showing something different:**
   - *The Harbour Walk* (Cutaway, 3 steps): short, the quick first try; the Listening check already quotes its first phrase.
   - *The Weekend Loaf* (Cutaway, 4 steps): quantities said as numbers ("500 grams", "220 degrees") and directions inside lines, so the chime is heard.
   - *The Old Watermill* (Cutaway, 7 steps, about 900 words): long, with words the recogniser mishears ("leat" as "elite", plan 009), a real test of following.
   - *The Seaside Pier* (plain text, 3 steps): new, so the plain format has one. Andy may rewrite it:

     ```
     The Seaside Pier

     The entrance
     This pier opened in 1899, and for a while it was the longest on the coast.
     [Gesture along the boards] It runs out nearly a third of a mile, so we'll take it slowly.

     Halfway out
     Every board under your feet was replaced in the 1990s, one plank at a time.
     If you look down through the gaps, you can see the tide coming in.

     The end of the pier
     And here we are. On a clear day you can see the lighthouse from here.
     That's the pier. Thanks for walking it with me.
     ```

   In that order, the order of the section. The texts live in `SampleScript` as `harbourWalk`, `weekendLoaf`, `oldWatermill` and `seasidePier`, with `all` listing each with a stable ID (`harbour-walk`, …). The Loaf and the Watermill go in exactly as read off the phone, so the phone's copies adopt them (decision 4).

3. **Samples are stored scripts, seeded at launch.** A sample is a `Script` like any other, with `sampleID: String?` set (nil for the presenter's own). That keeps the Script screen, takes, renderings, the start step and the cues setting working unchanged, and takes on a sample are numbered and kept. `SampleSeeder.seed(in:)` runs once per launch, before the list shows:
   - for each sample, find the script with its `sampleID`; if there is none, import it and set the ID;
   - if there is one whose `sourceHash` differs from the sample's (a later build changed the text), replace its text through the same path as Paste new version, keeping its takes, cues setting and start step;
   - otherwise leave it.
   Adding an optional property is a lightweight migration that SwiftData makes by itself. The store's fallback to memory when it cannot open (`ModelContainerFactory.persistent`) makes this the plan's main risk on the phone: device check 1 confirms the store opened.

4. **Adoption, so the phone gets no duplicates.** Before importing a missing sample, the seeder looks for a script of the presenter's own whose `sourceHash` matches the sample's text and, if there is one, sets its `sampleID` instead, keeping its takes. On Andy's phone the three scripts already pasted become three of the samples, and only the Pier is new. A copy whose text was edited does not match and stays the presenter's own.

5. **Samples cannot be deleted.** No swipe to delete in the Samples section, so a sample is always there to try. One that is not wanted sits below the presenter's own scripts and costs nothing. (A Hide Samples setting can come later if it is wanted.)

6. **Paste keeps samples apart.** The same text as a sample opens the sample (the hash rule, unchanged). A paste whose stated title matches a sample's ("The Harbour Walk") is a new script of the presenter's own, never a replacement of the sample's text: `ScriptImporter.paste` matches titles against the presenter's own scripts only. Paste new version is not offered on a sample's Script screen.

7. **The Debug launch flags open the sample, without adding it.** `-EarwigDemo YES` opens *The Harbour Walk* from the Samples section; `-EarwigListen`, `-EarwigTake`, `-EarwigScreen` and the rest work as now. Since the sample is always seeded, the phone note in CLAUDE.md (launch without `-EarwigDemo` once the sample is there) becomes: the flag sets the navigation path at launch, so a tap then opens the Script screen twice; launch without it for anything but screenshots.

8. **The README is one page that sells the app, teaches it and documents it**, in this order. GitHub shows an outline of the headings, so one long page is easy to find your way around, and a separate guide would mostly go unread.
   1. **Banner** (decision 9): the mark and the name on sky blue, the one-line tagline, and three screenshots.
   2. **What it's for**, in a paragraph, written from the presenter's side. You film yourself talking to camera, walking or at a desk, with no teleprompter you can look at, and you don't want to learn the script. Earwig reads the script into one earpiece a few words ahead of you. It listens to what you actually say: it waits when you pause, keeps pace when you speed up or slow down, and picks you up where you are after a stumble. The same engine scrolls the script on the phone when you can see it.
   3. **How it works**: the flow diagram and the following diagram (decision 10), each with two or three sentences. The voice is rendered before the take with word timings. Apple's on-device `SpeechAnalyzer` listens on the iPhone's own mic, and the follow engine keeps the voice a set lead ahead and gates it at phrase ends. Everything happens on the phone, with no accounts, no network and no data leaving it.
   4. **Your first take**, a tutorial of about ten numbered steps on *The Harbour Walk*, in text alone. It starts with no earpiece: open the sample, tap Listen to hear a step, then make a Screen Only take, reading aloud and watching the text follow. Then the same step With Voice in the earpiece: the tones, reading a few words behind the voice, pausing to hear it wait, and stumbling and starting the sentence again to see it pick you up. It ends at Finished and Next Take. A presenter who has done it knows the whole loop.
   5. **Features**, every one, each with what it does and how to use it, in the app's order:
      - **Scripts:** paste a Cutaway `script.md` or plain text, with a short example of each format; directions in square brackets; a re-paste updates a script and keeps its takes; Paste New Version; the samples; deleting.
      - **The Script screen:** the steps, choosing the start step, Listen, cues on or off, directions chimed or spoken, the start card.
      - **Starting a take:** With Voice or Screen Only; Record (Off, Sound or Video); the start modes (tones only, slate alone, slate with a reply); the route check.
      - **During a take:** what the voice does (lead, waiting at a phrase end, keeping pace, re-anchoring); the screen (eyeline, heard words faint, the voice's phrase lit, pinch for text size); Hold, Back, Forward, Restart and Stop; locking the phone; what ends a take (a call, the earpiece put away, listening giving up).
      - **Recording:** sound or video; framing on the preview; the camera behind the text and the text's brightness; Play Video, Play Sound, Play Back and Share; where the files are and Keep Recordings.
      - **Settings:** each group (Following, Start, Screen, Recording, Diagnostics) and what each setting does; the Listening check.
      The list is checked against the app's screens (step 7), so nothing is missed and nothing is described that the app does not do.
   6. **Requirements:** iOS 26 or later; an earpiece that plays over Bluetooth A2DP, with the iPhone's mic always the microphone; Stephanie (Enhanced) or another good English voice, downloaded in Settings; the en-GB speech assets, downloaded on first use.
   7. **Tips** from the device checks: a few lines on the lead, voice speed, the earpiece in a pocket with the phone locked, and words the recogniser mishears.
   8. **Building from source:** Xcode 27 or later (the version it is built and tested with), `brew install xcodegen`, your own `DEVELOPMENT_TEAM` in `project.yml`, `xcodegen generate`, the build, test and SwiftLint commands, and the device install with `devicectl`.
   9. **Status, releases and licence:** a pre-release built in stages (links to `PRD.md` §12 and `plans/`), the known issues by link, one paragraph on releases (decision 11), and the licence (decision 12) in plain words: source-available, free for non-commercial use, and free for anyone to use the app to make their own videos, commercial ones included; selling it, redistributing it commercially or building it into another product needs Andy's permission; the `LICENSE` file is what counts.
   It says what is true now, not #22's draft ("Screen mode is next" is long done). UK spelling throughout, plain and direct, in the voice of the app's own text.

9. **Six screenshots, no more, and the banner; made-up scripts only** (Andy, 2026-11-09: not a screenshot for every step, or it looks overcrowded). Three are in the banner and three in one row under Features; the tutorial and the feature descriptions have none.
   - **The banner** (`docs/banner.png`, 1280 × 640, which also serves as the repo's social preview image if Andy sets it): the mark, "Earwig", the tagline and three screenshots on sky blue: the Scripts screen, a Script screen with its start card, and a Screen Only take mid-step.
   - **The row under Features**: a take With Voice, the Finished screen, and Settings.
   - **From the simulator** at the iPhone 17's size, with the status bar overridden (`xcrun simctl status_bar booted override --time 9:41 --batteryState discharging --batteryLevel 100 --cellularBars 4 --wifiBars 3`), into `docs/screenshots/`: `scripts.png` (a fresh install), `screen-take.png` (`-EarwigDemo YES -EarwigScreen YES -EarwigReads YES`) and `finished.png`.
   - **From the phone**, with `xcrun devicectl device capture screenshot` during the device check, since the simulator has no Stephanie voice (its Script screen shows the missing-voice warning) and no voice to follow: `script.png` (*The Old Watermill*'s Script screen with the start card) `voice-take.png` (a take With Voice mid-phrase), and `settings.png` (its Voice row names a voice only where an Enhanced voice is installed).
   - Shown at 250 px wide with rounded corners, with no device frames.
   - The banner and the following diagram are HTML rendered to PNG by headless Chrome, by `scripts/readme/make_readme_images.py`, the way the icon script works, so they look the same in every browser and can be rebuilt.

10. **Two diagrams.**
    - **How it works**, a Mermaid flowchart in the README itself, so GitHub draws it in the reader's theme with nothing to keep in step. The script goes to the renderer, which makes the voice with word timings, then to the player and the earpiece. The presenter's speech goes to the iPhone mic, `SpeechAnalyzer` and the follow engine, which paces and gates the player and moves the screen. A recording branch comes off the mic and the camera.
    - **Following**, one picture (`docs/diagrams/following.png`) on a self-contained sky-blue panel with transparent corners, in the app's colours, so it reads on GitHub's light and dark pages alike and needs no dark copy. A line of the Harbour Walk at three moments, with the presenter's place, the voice's place and the phrase end marked: reading along, the voice five words ahead; a pause, where the voice reaches the phrase end and waits; and going off script after a phrase, where the voice holds until a line of the script is heard. It shows no stumble picked up by the voice, because after a stumble the voice waits and gives nothing again by itself (plan 005). This is the one picture that explains what makes Earwig different from a teleprompter. It is drawn by `make_readme_images.py` with the banner, so it can be changed later.
    - Both are reviewed with the README (step 8).

11. **The release scheme**, as #22 recommends:
    - **Tags, not release branches.** Each release is an annotated tag `vX.Y.Z` on `main` with a GitHub Release, marked pre-release until v1. A release branch is cut from a tag only if an old release ever needs a fix after `main` has moved on.
    - **No binary on the release.** Visitors build from source; Andy's builds go through TestFlight from plan 012, whose script tags each upload `testflight/X.Y.Z-N`, as PhysiMate's does.
    - **Versions** come from `project.yml`: `MARKETING_VERSION` 0.1.0 from this plan (it was 1.0); `CURRENT_PROJECT_VERSION` stays 1 until the first TestFlight upload bumps it.
    - **Notes** for each release: what it does, written from the PRD's Document History rows since the last release, then the known issues by link.
    - **Cutting one**, written in CLAUDE.md for Claude: after the PR merges, on `main` at the merge commit, `git tag -a vX.Y.Z -m "Earwig X.Y.Z"`, push the tag, and `gh release create vX.Y.Z --prerelease --title "Earwig X.Y.Z" --notes-file <notes>`. Pushing the tag and creating the release each need Andy's yes, as pushing does.

12. **The licence: PolyForm Noncommercial 1.0.0, with an extra permission** (Andy, 2026-11-09).
    - `LICENSE` holds the PolyForm Noncommercial 1.0.0 text verbatim, fetched from polyformproject.org at the time, not retyped. Above it is the notice line `Required Notice: Copyright (c) 2026 Andy Bower`, which anyone passing the code on must keep.
    - Below the licence text is this paragraph, Claude's wording, not a lawyer's:

      > **Additional permission.** Andy Bower also permits you to use the software to make your own videos, recordings and other works, for any purpose, including commercial ones. This permission covers using the software; distributing it, selling it, or including it in another product remain limited to noncommercial purposes.

    - The permission is in `LICENSE` itself, not only the README, so it is part of the licence. The README says the same in plain words (decision 8).
    - The repo is source-available, not open source in the OSI sense; the README says so, and GitHub may show its licence as "Other". It has no third-party dependencies, so no other licence conflicts with it.

13. **Cutaway is not named where a visitor or a user sees it** (Andy, 2026-11-09: it is not published yet). The format is labelled **Markdown** on the Scripts screen's rows (`ScriptFormat.label`), the paste row says "in Markdown or plain text", and the README describes the format without naming Cutaway. Code names (`ScriptFormat.cutaway`, `CutawayParser`), the PRD and the plans keep the name, since they record where the format came from.

14. **Toolbar buttons on the cards' mid-blue** (Andy, 2026-11-09, option A of four: mid-blue circles, no background, buttercup circles, pale frosted circles). iOS 26 draws every toolbar item on Liquid Glass, which the app's dark scheme turns near-black on the phone. Each toolbar button hides that glass (`sharedBackgroundVisibility(.hidden)`) and draws its own: an icon in a mid-blue circle (the Settings gear, More, Back) or a word in a mid-blue capsule (Done in Settings, Listen and Playback), from `Views/Common/ToolbarButtons.swift`. iOS's back button cannot be restyled, so the Script screen and the Listening Check have Earwig's own, and the swipe from the left edge still goes back.

15. **No More menu on the Script screen** (Andy, 2026-11-09). Its items move to where they belong: **Voice**, **Allow Personal Voice** and **Directions in a Line** apply to every script, so they are a Voice group at the top of Settings, the last renamed **Stage Directions** (Andy, 2026-11-09) (PRD §4.8 planned them there for stage 7); **Read Cues** is per script, so it is a toggle on the start card, beside Start; **Delete Script** is a red button at the foot of the Script screen, for the presenter's own scripts, asking first as before. The Script screen's toolbar has only the back button.

16. **The light scheme** (Andy, 2026-11-09). Earwig asked iOS for the dark scheme, so iOS drew every surface of its own near-black: the menus of Settings' pickers, the confirmations and alerts, the stepper, the segmented control, the share sheet. In the light scheme they are pale frosted. Earwig's own colours do not change: the navigation titles stay white (`UINavigationBar` appearance in `EarwigApp`, and the bars' own scheme set dark; the Scripts screen's bar has no background of its own, since setting one makes iOS ignore the white large title), the status bar is white (`UIStatusBarStyleLightContent`), and the lists set white labels with pale headers and values. The Lead stepper is Earwig's own − and +, since iOS's light stepper hid its white symbols.

17. **An App Store version is planned** (Andy, 2026-11-09): a low-cost app for people who would rather not build it, beside the source-available repo. The README's Status section goes: "pre-release" is under the title, the known issues join the releases as **Releases and known issues** with one line on the planned App Store version, and the PRD and `plans/` links close **Building from source**. The PRD (§1, §2 Distribution, the Non-goals) and CLAUDE.md drop "never sold" for this. The App Store work itself (a privacy policy, App Review, the listing) is a later stage, after TestFlight (plan 012).

## Files

- `Earwig/Services/SampleScript.swift` (edited: the three new texts, `all` with IDs).
- `Earwig/Services/SampleSeeder.swift` (new).
- `Earwig/Models/Script.swift` (edited: `sampleID`, `isSample`).
- `Earwig/Services/ScriptImporter.swift` (edited: titles match the presenter's own scripts only).
- `Earwig/ViewModels/ScriptsViewModel.swift` (edited: `addSample` goes; the Debug flag opens the sample).
- `Earwig/Views/Scripts/ScriptsView.swift` (edited: the two sections, the paste row, no empty screen).
- `Earwig/Views/ScriptDetail/ScriptDetailView.swift` (edited: no Paste new version on a sample).
- `Earwig/App/EarwigApp.swift` (edited: seeding at launch).
- `Earwig/App/EarwigTheme.swift` (the light scheme), `SettingsView` (the Voice group, the Lead stepper) and `ScriptDetailViewModel` (the voice choice moved out) (decisions 15, 16).
- `Earwig/Views/Common/ToolbarButtons.swift` (new), and the toolbars of `ScriptsView`, `ScriptDetailView`, `SettingsView`, `ListeningCheckView`, `ListenView` and `PlaybackView` (decision 14).
- `EarwigTests/SampleSeederTests.swift` (new), `EarwigTests/ScriptImporterTests.swift` (edited).
- `project.yml` (`MARKETING_VERSION`).
- `LICENSE` (PolyForm Noncommercial 1.0.0, the notice and the extra permission).
- `README.md` (new), `docs/screenshots/*.png`, `docs/banner.png`, `docs/diagrams/following.png` (new).
- `scripts/readme/make_readme_images.py` (new).
- `PRD.md`, `CLAUDE.md`, `progress.md`, this plan.

## Steps

1. **Samples' texts.** The Loaf and the Watermill into `SampleScript` exactly as read off the phone (their hashes must match the phone's), the Pier, and `all`. A test parses each: the formats, the step counts above, and every step has spoken words.
2. **Model and seeder.** `sampleID`, `SampleSeeder` with decisions 3 and 4, seeding in `EarwigApp` before the list shows. Tests, on an in-memory container held for the test's length: a fresh store gets four samples in order; a second seed changes nothing; a changed sample text replaces the stored text and keeps its takes; a script of the presenter's own with a sample's text is adopted with its takes and no duplicate is made; an edited copy is not adopted.
3. **Paste rules.** `ScriptImporter` matches stated titles against the presenter's own scripts only (decision 6); tests for a paste titled like a sample and for a paste of a sample's exact text.
4. **Scripts screen.** The two sections, the paste row, no delete on samples, no empty screen; Paste new version hidden on a sample. `-EarwigDemo` opens the sample. Simulator: a fresh install shows the four samples and the paste row; a paste adds a script to the top section; a swipe deletes one of the presenter's own and not a sample.
5. **Version and licence.** `MARKETING_VERSION: "0.1.0"`, `xcodegen generate`, and the built app's `CFBundleShortVersionString` checked. `LICENSE` written (decision 12).
6. **Screenshots, banner and diagrams** (decisions 9 and 10). The simulator screenshots; `make_readme_images.py` run, and its output checked by eye; everything checked by eye for anything but made-up text, and committed. The two phone screenshots are taken during the device check (step 8), then the banner is rebuilt with `script.png`.
7. **README** (decision 8), with the diagrams (decision 10), the release scheme (decision 11) and the licence (decision 12). First, an inventory of every control and setting on every screen, taken from the views (`Earwig/Views/`), which the Features section is checked against. Andy reviews the README rendered on GitHub on the pushed branch before the PR (the push needs his yes), and it is revised until he is happy with it.
8. **Device check** on the iPhone 14 Pro (Verification), installed over the current build with `devicectl`, so the store migrates as it will for Andy. One check at a time; the verdicts are Andy's.
9. **Finish.**
   - SwiftLint clean, no warnings, all tests pass.
   - Results filled in.
   - PRD as v0.13 with a Document History row: §4.1's samples row, §8.1 rewritten for the two sections, §2's Distribution with the release scheme and the licence, §12 noting this plan beside the stages and stage 7 as plan 012.
   - CLAUDE.md: the status (this plan complete; stage 7 as plan 012), the repo's licence, the release scheme and how Claude cuts one (decision 11), and the `-EarwigDemo` note (decision 7).
   - `progress.md` emptied to its stub.
10. **The release, after the PR merges** (each push needs Andy's yes): the annotated tag `v0.1.0` on `main` at the merge commit, pushed; the GitHub Release marked pre-release, notes from the PRD's Document History v0.1 to v0.13, a line on the licence, and the known issues (#30, #33, and the settings still in the Script screen's menu). The release's URL recorded in Results.

## Verification

- `xcodebuild test` passes in the simulator with no warnings; SwiftLint clean.
- Simulator: a fresh install (`xcrun simctl uninstall booted com.bowerhaus.Earwig` first) shows the four samples and the paste row; a relaunch shows four, not eight; `-EarwigDemo YES` opens *The Harbour Walk*; `-EarwigScreen YES -EarwigReads YES` still follows.
- The README read on GitHub's renderer on the branch, in light and dark: images load, the Mermaid diagram draws, the following diagram reads on both, links resolve. Andy's verdict on how it reads and looks.
- The Features section against the inventory of the views: every control and setting is covered, and nothing described is missing from the app.
- On the iPhone 14 Pro, installed over the current build:
  1. **The store migrated.** The Scripts screen shows The Harbour Walk, The Weekend Loaf and The Old Watermill under Samples, with their takes ("last take …" as before), no duplicates, and The Seaside Pier added. Nothing of the presenter's own is lost.
  2. **A take on a sample.** A Screen Only take on The Seaside Pier, read aloud: it follows and completes. The plain-text sample on a real recogniser.
  3. **Samples stay.** A swipe on a sample does nothing; a relaunch after a force quit shows the same list.
- The version on the phone, checked by Claude, not Andy: `xcrun devicectl device info apps --device <UDID>` lists `com.bowerhaus.Earwig` at 0.1.0 (iOS shows no version for an app in its own Settings).

## Results

Built and checked on 2026-11-09. **PASS**: Andy reported every device check passed and approved the README on GitHub.

- **What was built.**
  - **Samples.** `SampleScript` holds the four samples (the Loaf and the Watermill exactly as read off the phone's store) and `all`, with stable IDs. `SampleSeeder` adds, updates and adopts them at launch, in `EarwigApp.init`. `Script.sampleID` marks them; paste matches titles against the presenter's own scripts only; samples cannot be deleted. The Scripts screen has the two sections and the paste row, and `-EarwigDemo` opens the Harbour Walk sample, after a short wait, since a path set in the first instant after launch can be dropped.
  - **Version and licence.** `MARKETING_VERSION` is 0.1.0. `LICENSE` holds the PolyForm Noncommercial 1.0.0 text, checked word for word against the project's own copy, with the notice and the additional permission.
  - **Decisions added on the phone.** 13, the format labelled Markdown; 14, mid-blue toolbar buttons; 15, no More menu; 16, the light scheme; 17, an App Store version planned. The directions setting is renamed Stage Directions, and the app's download hint names iOS's current path, Settings › Accessibility › Read & Speak › Voices.
  - **README.** It is written for visitors in Andy's voice: his own What it's for, the ear prompter and the standard teleprompter, a section on getting a good voice, a first take, every feature (checked against an inventory of the views), tips, building from source, releases and known issues, and the licence. `scripts/readme/make_readme_images.py` draws the banner and the following diagram. Six screenshots: three from the simulator (Scripts, a Screen Only take, Finished) and three from the phone with `devicectl device capture screenshot` (the Old Watermill's Script screen, Settings, a take With Voice).
- **Simulator:** a fresh install shows the four samples and the paste row, and a relaunch shows four, not eight. Every toolbar button, the Settings menus, the Listening Check and Listen were checked in the light scheme. 366 tests pass with no warnings, and SwiftLint is clean.
- **Device (iPhone 14 Pro), Andy's verdicts, all passed:**
  1. **The store migrated:** the three pasted scripts became samples with their takes, nothing was doubled, and the Pier was added.
  2. **A Screen Only take on the Pier** followed and completed.
  3. **Samples stay:** a swipe does nothing, and a force-quit and relaunch shows the same list.
  4. **The look check:** mid-blue buttons, no black menus, white titles, Done in full, the edge swipe going back.

  The version on the phone read 0.1.0.
- **README review:** Andy read it on GitHub and asked for:
  - the teleprompter and the term "ear prompter" in the opening;
  - his own What it's for, and the rest in that voice;
  - "earbud";
  - a section on getting a good voice, early on;
  - a note that the ear prompter takes practice;
  - no Status section, its parts moved, with the App Store version mentioned;
  - the free account's seven-day limit.

  All are in, and he approved it.
- **Review pass:** two agents' findings, recorded above with their outcomes.
- **Follow-ups proposed, not opened:**
  - the always-visible diagnostics line during a take;
  - swipe to delete on the Scripts screen not asking first;
  - the mixed capitalisation of Settings' labels.

  The inventory's "Save Video is not built" was wrong: the Photos permission is for the share sheet's Save Video (plan 010).

## Review pass — 2026-11-09

Findings from `/review-branch` on branch `first-release`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact, and each verdict under *Assessment* is a
recommendation, not a decision. Work through them and annotate each with what was done — fixed,
or rejected and why. A finding that turns out to be wrong should say so here rather than be
deleted.

Two details in C1 and C2 are redacted, at the author's instruction: a device identifier, and the earlier licence's name.

### Code

**C1 — WARNING: Phone UDID committed to a public repo.** `progress.md` lines 10 and 29 contain the device UDID `[redacted]` (not on `main`). CLAUDE.md says everything committed is public; make sure it is removed from the tree and from history before the first push (the progress stub at completion plus the planned squash would do it).

**C2 — WARNING: CLAUDE.md still contradicts the new LICENSE and the new samples behaviour.** `CLAUDE.md:11` still names the earlier licence; its Build Commands still say `-EarwigDemo YES` "add[s] the sample script" and "On the phone, launch without `-EarwigDemo` once the sample is there" (decision 7 rewrites this). `PRD.md:811` (v0.2 row) still names the earlier licence (progress notes say the row's licence words are to be dropped). These are in step 9 (Finish), so this is a reminder that they must land before the PR rather than a code defect.

**C3 — WARNING: The following diagram departs from plan decision 10, and the plan's Verification can't be met as written.** The plan (Files list, decision 10, Verification: "the diagram's dark copy shows in dark mode") specifies `docs/diagrams/following-light.png` + `following-dark.png` chosen by `<picture>`/`prefers-color-scheme`; the branch ships a single transparent-cornered `docs/diagrams/following.png` with a plain `<img>` (`README.md`, the line after "nothing leaves the phone"; `scripts/readme/make_readme_images.py`, `following()` / `MOMENTS`). The third moment is also "You go off script" rather than the plan's stumble ("the presenter goes back and the voice picks them up"). Likely a deliberate improvement; if so, update decision 10, Files and Verification in `plans/011-first-release.md` (or record it in Results).

**C4 — SUGGESTION: Toolbar Paste departs from plan decision 1 without the plan being updated.** Decision 1 says "The Paste pill stays in the toolbar always"; `Earwig/Views/Scripts/ScriptsView.swift:30-35` (`if !own.isEmpty { ToolbarItem … pasteButton }`, commit d6d8f46) shows it only once there are scripts of the presenter's own (the paste row carries it until then). Amend decision 1 so the plan matches what ships.

**C5 — SUGGESTION: README's Xcode requirement disagrees with the plan.** `README.md` (Building from source) says "Xcode 27 or later"; decision 8.8 says Xcode 26. Deployment target is iOS 26 and no iOS 27-only API was spotted; confirm 27 is really required or align the two.

**C6 — SUGGESTION: A sample dropped in a later build becomes an undeletable orphan.** `Earwig/Services/SampleSeeder.swift:26-44` (`seed`) never clears `sampleID` from a stored sample whose ID is no longer in `SampleScript.all`, so `ordered` (`:47-50`) still lists it (sorted last) and `ScriptsViewModel.delete` / `ScriptDetailView` refuse to delete it forever. Consider clearing `sampleID` on stored samples absent from `samples` so they become the presenter's own. Not reachable today; low priority.

### Tests

T1. SUGGESTION: The `updatedAt` check tests the wrong path. In `seedingAgainChangesNothing`, `#expect(walk.updatedAt == updatedAt)` runs on the unchanged-hash path, where the seeder never touches the script, so the assertion cannot fail. The code that actually saves and restores `updatedAt` is the replace branch (`stored.updatedAt = updatedAt`, Earwig/Services/SampleSeeder.swift lines 20-23), and `aChangedSampleTextReplacesTheStoredTextAndKeepsItsTakes` does not assert it. Either move the assertion into the changed-text test, or drop it. Samples are ordered by `SampleSeeder.ordered`, not by `updatedAt`, so keeping `updatedAt` currently has no visible effect.
- EarwigTests/SampleSeederTests.swift lines 50-57 and 59-71

T2. SUGGESTION: Two tests check the sample content and overlap with the others.
- `eachSampleParsesAsItsFormatWithWordsInEveryStep` asserts the id order, which `aFreshStoreGetsTheFourSamplesInOrder` covers again through the ordered titles. It also hard-codes the step count of each sample, so any edit to a sample's text breaks it.
- `theSeasidePierIsTitledAndItsStepsNamed` repeats a title that the fresh-store test already checks.

Consider folding the plain-format title and step-names check into the first test as a single expectation, and dropping the duplicated id-order assertion. The useful checks are the format, `titleIsStated`, and every step having spoken words. Step counts and the order are already pinned elsewhere.
- EarwigTests/SampleSeederTests.swift lines 22-41

T3. SUGGESTION: Adding the cues setting to the changed-text test would complete plan decision 3. That decision says a replaced sample keeps its takes, cues setting and start step. The changed-text test checks the takes and `lastStep` but not `cuesOn`. `cuesOn` survives because the seeder goes through `ScriptImporter.replace`, which is already tested in ScriptImporterTests.swift, so this is optional: setting `walk.cuesOn = false` before the reseed would cover the decision with one line.
- EarwigTests/SampleSeederTests.swift lines 59-71

### Assessment

- C1 — FIX: drop the device identifier from `progress.md` now; the squash before the first push takes it out of the branch's history.
- C2 — NOT REAL: these are the plan's step 9 (Finish) edits, made before the PR; nothing is wrong yet.
- C3 — FIX (part): update decision 10, Files and Verification to what ships. One diagram on a self-contained sky-blue panel reads on GitHub's light and dark pages, so no dark copy is needed. The third moment is "off script" because, after a stumble, the voice waits and gives nothing again by itself (CLAUDE.md, plan 005); a picture of it picking the presenter up would describe behaviour the app does not have. No code change.
- C4 — FIX: amend decision 1: the toolbar Paste shows once there are scripts of the presenter's own, and the paste row carries it until then, so the empty list never shows two Paste buttons.
- C5 — FIX (part): align the plan to the README's "Xcode 27 or later". The project is built and tested with Xcode 27.2, and building with Xcode 26 has not been tried, so the README should not claim it.
- C6 — SKIP: not reachable while all four samples ship; a plan that removes a sample can clear its ID then.
- T1 — FIX: move the `updatedAt` assertion into the changed-text test, where the seeder restores it.
- T2 — FIX (part): drop the id-order assertion from the parse test and the Pier test's title check. Keep the step counts, since they pin the plan's decision 2.
- T3 — FIX: set `cuesOn = false` before the reseed in the changed-text test, and expect it kept.

### Outcome — 2026-11-09

- C1 — fixed: the device identifier is out of `progress.md`; the squash before the first push takes it out of the branch's history.
- C2 — not done: not a defect; the CLAUDE.md and PRD edits are step 9 (Finish), made before the PR.
- C3 — fixed (part): decision 10, Files and Verification describe the single diagram and its off-script moment; no code change.
- C4 — fixed: decision 1 states the toolbar rule that ships.
- C5 — fixed (part): decision 8 says Xcode 27 or later, as the README does.
- C6 — not done: not reachable while all four samples ship.
- T1 — fixed: the `updatedAt` assertion is in the changed-text test.
- T2 — fixed (part): the duplicated id-order and title checks are gone; the step counts stay.
- T3 — fixed: the changed-text test expects the cues setting kept.
