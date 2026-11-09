# Plan 012: Settings and TestFlight

**GitHub Issue:** [#38](https://github.com/bowerhaus/Earwig/issues/38) (PR must include "Closes #38"); folds in [#36](https://github.com/bowerhaus/Earwig/issues/36) and [#35](https://github.com/bowerhaus/Earwig/issues/35), and closes [#14](https://github.com/bowerhaus/Earwig/issues/14) (PR must also include "Closes #36", "Closes #35" and "Closes #14")
**Branch:** `settings-testflight` (from `main` at `af23220`, after plan 011 merged and v0.1.0 was cut)
**Status:** Draft (2026-11-09), for Andy's review.
**Manual test:** device, on Andy's iPhone 14 Pro with the SK18: the new settings heard and seen, then the first TestFlight build installed from the TestFlight app over the development build, with a take run on it (Verification).
**Goal:** PRD §12's stage 7, the last MVP stage. Settings has every setting the presenter needs and nothing they would have to look up, with a way to hear the voice before a take and to see which build is on the phone. Andy's builds reach his phone through TestFlight from one script, with the App Store Connect key kept in the Keychain, so a build no longer needs the Mac and a cable, and lasts 90 days in place of a free account's seven. The first TestFlight build is uploaded and run.

**PRD references:** §2 (Distribution, Keys), §4.2, §4.8, §8.4, §12, Document History.

---

## Context

Settings has grown stage by stage: plan 005 built it (Following, Start, Diagnostics), plan 008 added Screen, plan 010 Recording, and plan 011 the Voice group from the Script screen's old menu. Against PRD §4.8, what is still missing is:

- a **Preview** for the voice, and the **base rate** per voice (#14);
- a **cue voice** choice (today `VoiceCatalogue.cue` picks the best en-GB voice of the other gender, with no say);
- **cues on or off by default**;
- the pacer's **speed bounds**;
- #36, found while checking every screen for plan 011: a **Show Take Details** switch for the engine's line under the status ("lead error −1.5 · speed 1.08× · …"), off by default, and **Voice Speed** and **Text Size** in Title Case.

TestFlight is the other half. PRD §2 already describes the script (`scripts/release/testflight.sh`), cloud-managed signing, the refusals and the `testflight/<version>-<build>` tags, and puts the key in the Keychain under `bowerhaus.appstoreconnect`. PhysiMate's script (`bowerhaus/PhysiMate`, `scripts/release/testflight.sh` and `ExportOptions.plist`, plan 015 there) is the model, with three differences for Earwig: PhysiMate reads the key from `~/.appstoreconnect.env` and a `.p8` file, Earwig from the Keychain; PhysiMate commits its `.xcodeproj` and refuses a stale one, Earwig's is git-ignored; and CLAUDE.md says Earwig's script bumps the build number itself.

#35 joins as well (Andy, 2026-11-09), also found while checking every screen for plan 011: swiping one of the presenter's own scripts on the Scripts screen and tapping Delete removes it and its takes at once, while **Delete Script** at the foot of the Script screen asks first. It is small, and a deletion with no question is worth fixing before a build goes to TestFlight.

The App Store release (#37: name, listing, privacy policy, screenshots, App Review) depends on this plan and is its own plan after it.

## Scope

**In:**
- the Voice group finished: Preview, Voice Speed moved in from Following, Cue Voice;
- Show Take Details and Title Case (#36);
- an About group: version and build, source code, licence;
- swipe to delete on the Scripts screen asks first (#35);
- §4.8 settled: what is built, and what is struck from it and why;
- `scripts/release/testflight.sh` and `scripts/release/ExportOptions.plist`;
- `PrivacyInfo.xcprivacy`, which App Store Connect asks for on upload;
- the App Store Connect app record and an internal testing group (Andy, on the website);
- `MARKETING_VERSION` 0.2.0, the first TestFlight upload, and the v0.2.0 release after the PR merges.

**Out:**
- the App Store release (#37), including a public TestFlight link for external testers, which needs Beta App Review and a privacy policy;
- the fixed-pace scroll (#31);
- #30 (a fluff in the last phrase) and #33 (the route check's colours);
- a Reset to Defaults button.

## Design decisions

1. **Settings' groups**, in order: **Voice, Following, Start, Screen, Recording, Diagnostics, About.** Footers stay as plan 010 left them: one line where a choice does something its name does not say, or none.

2. **The Voice group** holds everything about how the script sounds:
   - **Voice**, as now.
   - **Preview**: a button that reads one sentence in the chosen voice at the chosen voice speed, through whatever the route is (the earpiece if it is in). It renders and plays the way Listen does (`VoiceRenderer`, then the player at the voice speed), so what Preview plays is what a take plays. While it plays the button reads **Stop**. The sentence is the Harbour Walk's first line (its first phrase, which the Listening check quotes, is "Morning!" alone: device check 1).
   - **Voice Speed**, moved from Following: it is how the voice sounds, and Preview plays at it. Following keeps Lead and Pacing.
   - **Cue Voice**: **Automatic** (default, today's rule: the best en-GB voice of the other gender, so a cue never sounds like the script) or any English voice of Enhanced quality or better, never a Personal Voice. Stored as an identifier in `AppSettings`, nil for Automatic; a voice since deleted falls back to Automatic. `VoiceCatalogue.choose` takes it.
   - **Allow Personal Voice** and **Stage Directions**, as now.

3. **One voice speed for every voice, not a base rate per voice** (#14). Plan 005 chose 0.95x by ear on Stephanie, in real takes, which is what #14 asked for. A rate per voice is a setting few presenters would understand, and changing the voice and then its speed is two taps with Preview to judge it. #14 closes with this plan, its verdict recorded in Results. If a second voice turns out to want a different speed, that can be its own issue.

4. **Struck from §4.8, not built:**
   - **Speed bounds.** The pacer's 0.85x to 1.2x (`FollowSettings.minSpeed`, `maxSpeed`) are tuned with the simulated takes and the engine's tests, and are the kind of number #36 hides. They stay in the engine.
   - **Cues on or off by default.** Read Cues is per script, on the start card (plan 011, decision 15), and a new script reads cues. A default for new scripts would be a second switch for the same thing.

   §4.8 is rewritten to say what Settings has, and these two go into its history line.

5. **Show Take Details** (#36), under Diagnostics with the Listening Check, off by default. Off, the Prompt screen has no engine line; on, it shows it as now. `AppSettings.showsTakeDetails`. Andy turns it on on his phone for device checks. The take's console summary (`TakeSummary`) is unchanged either way.

6. **Title Case** (#36): **Voice Speed** and **Text Size**, here and in the README's Settings section, so every Settings label is in Title Case as Apple's own Settings app writes them.

7. **About**, the last group:
   - **Version**: "0.2.0 (2)", from the bundle's `CFBundleShortVersionString` and `CFBundleVersion`, so Andy can see which TestFlight build is on the phone.
   - **Source Code**: opens `https://github.com/bowerhaus/Earwig` in Safari.
   - **Licence**: opens the repo's `LICENSE` on GitHub.

   No privacy page yet; the App Store's privacy policy URL is #37's.

8. **The release script**, `scripts/release/testflight.sh`, from PhysiMate's:
   - **Refuses** a dirty working tree, a missing Keychain item, or a build number whose tag already exists.
   - **Bumps the build.** It reads `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` from `project.yml`, writes the build number plus one, and runs `xcodegen generate` itself: the project is git-ignored, so the script makes it fresh and there is no stale project to refuse (§2 is amended to say so).
   - **Archives and uploads** as PhysiMate's does: `xcodebuild archive` for `generic/platform=iOS` in Release, then `-exportArchive` with `ExportOptions.plist` (`app-store-connect`, `upload`, automatic signing, team `S7K2GRB2RN`, symbols uploaded), each with `-allowProvisioningUpdates` and the key, so cloud-managed signing needs no distribution certificate on the Mac.
   - **On success** it commits `project.yml` ("TestFlight 0.2.0 (2)") and tags that commit `testflight/0.2.0-2`. **On failure** a trap puts `project.yml` back, so a failed upload leaves no commit and no bumped number. Pushing the commit and the tag is separate, and needs Andy's yes.
   - It prints the version, the build and the branch before it starts.

9. **The key, from the Keychain** (PRD §2, Keys):
   - Service `bowerhaus.appstoreconnect`, three items: accounts `key-id`, `issuer-id` and `key-p8` (the `.p8` in base64).
   - If one is missing, the script prints the three `security add-generic-password -s bowerhaus.appstoreconnect -a … -w …` commands with placeholders and exits. Andy runs them in his own terminal, once; the team key PhysiMate uses (Admin role) serves, since the items are named for the team.
   - At upload the `.p8` is decoded into a file in a `mktemp -d` directory made with `umask 077`, passed to xcodebuild by path, and removed by a trap on exit, success or failure. No value is echoed, logged or passed on a command line other than xcodebuild's key ID and issuer ID, and the script never runs with `set -x`.
   - Claude runs the script only with Andy's yes for each upload, and never reads, prints or handles a value. macOS may ask once whether `security` may read the items; Andy answers it.

10. **The App Store Connect record**, made by Andy on the website before the first upload (Claude cannot):
    - **New App**: iOS; name **Earwig** if it is free, or a placeholder such as "Earwig Prompter" (the store name is #37's to decide, and it can change before submission); primary language English (U.K.); bundle ID `com.bowerhaus.Earwig` (automatic signing has registered it; if it is not in the list, it is added under Identifiers first); SKU `earwig`.
    - **TestFlight**: an internal testing group with Andy in it. Internal builds need no Beta App Review.
    - **Export compliance** is answered by `ITSAppUsesNonExemptEncryption: false`, already in `project.yml`.

11. **The privacy manifest**, `Earwig/Resources/PrivacyInfo.xcprivacy`: no tracking, no tracking domains, no data collected, and the required-reason APIs the app calls, found by searching the source:
    - `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` (settings, read and written by the app itself);
    - `NSPrivacyAccessedAPICategoryDiskSpace`, reason `E174.1` (`RecordingStore.freeSpace()`, which checks there is room before a video take);
    - `NSPrivacyAccessedAPICategorySystemBootTime`, reason `35F9.1` (`mach_absolute_time` in `AudioEngineHost`, timing events within the app).

    App Store Connect mails a warning after an upload if one is missing (ITMS-91053), so the first upload is the check, and Results record what it said.

12. **Version 0.2.0.** `MARKETING_VERSION` goes to 0.2.0 on this branch, so the first TestFlight build is 0.2.0 (2). After the PR merges, v0.2.0 is cut on `main` as plan 011's scheme says (CLAUDE.md, Git Workflow), each push with Andy's yes. TestFlight builds after the merge are uploaded from `main`.

13. **The Release build.** TestFlight builds are Release, which no take has run in yet. The Debug-only launch flags are inside `#if DEBUG`; the Release configuration is built in the simulator first, with no warnings, and the device check runs a take With Voice on the TestFlight build, locked in a pocket.

14. **Swipe to delete asks first** (#35). The swipe on one of the presenter's own scripts opens the same confirmation as Delete Script on the Script screen: "Delete" and the script's title, "Its takes go with it.", and a red **Delete Script**. Nothing is deleted until that is tapped; Cancel, or a tap outside, leaves the script and its takes as they were.
    - The view model holds the script waiting to be confirmed (`ScriptsViewModel.pendingDeletion`), with `askToDelete(_:)`, `confirmDeletion(in:)` and `cancelDeletion()`, so a test can show nothing goes before the confirmation. Samples are still never deleted, either way.
    - `.onDelete` deletes at once by design, so the row's swipe becomes `.swipeActions` with one Delete button. It has no full swipe (`allowsFullSwipe: false`), and no destructive role, since a destructive swipe button slides the row away before the question is answered; it is tinted `EarwigTheme.warning` instead. The phone shows whether the row stays put while the question is up.

## Files

- `Earwig/Views/Settings/SettingsView.swift` (edited: the Voice group, Cue Voice, Preview, Show Take Details, About, Title Case).
- `Earwig/Views/Settings/VoicePreview.swift` or a small `@Observable` in `ViewModels/` (new: renders and plays the preview sentence, Stop).
- `Earwig/Models/AppSettings.swift` (edited: `cueVoiceID`, `showsTakeDetails`).
- `Earwig/Services/VoiceCatalogue.swift` (edited: `choose` takes a cue voice; the cue options).
- `Earwig/Services/ScriptRenderer.swift` (edited, if the cue voice is passed through it).
- `Earwig/Views/Prompt/PromptView.swift`, `Earwig/ViewModels/PromptViewModel.swift` (edited: the line only when Show Take Details is on).
- `Earwig/Views/Scripts/ScriptsView.swift`, `Earwig/ViewModels/ScriptsViewModel.swift` (edited: the swipe asks first, #35).
- `EarwigTests/ScriptsViewModelTests.swift` (new or edited: nothing deleted until confirmed; cancel keeps it; a sample never deleted).
- `Earwig/Resources/PrivacyInfo.xcprivacy` (new).
- `EarwigTests/VoiceCatalogueTests.swift` (edited: a chosen cue voice, a deleted one, Personal Voice never a cue).
- `scripts/release/testflight.sh`, `scripts/release/ExportOptions.plist` (new).
- `project.yml` (`MARKETING_VERSION` 0.2.0; the script bumps `CURRENT_PROJECT_VERSION`).
- `README.md` (the Settings section: the Voice group, Cue Voice, Show Take Details, About, Title Case).
- `PRD.md`, `CLAUDE.md`, `progress.md`, this plan.

## Steps

1. **Cue voice.** `VoiceCatalogue` takes a chosen cue voice, with tests first: a chosen voice is used; one no longer installed falls back to Automatic; a Personal Voice is never offered or used; Automatic is today's rule.
2. **The Voice group.** Voice Speed moved in, Cue Voice, Preview with Stop. Simulator: the group lays out, Preview's Stop works (the simulator has no Stephanie, so what it sounds like waits for the phone).
3. **Show Take Details and Title Case** (#36). Simulator: a Screen Only take (`-EarwigDemo YES -EarwigScreen YES -EarwigReads YES`) with the switch off shows no line, and on shows it.
4. **About.** Version and build from the bundle; the two links.
5. **Swipe to delete asks first** (#35, decision 14). The view model's tests first, on an in-memory container held for the test's length: a script asked to be deleted is still there; confirmed, it and its takes are gone; cancelled, both stay; a sample is never deleted. Then the swipe. Simulator: a pasted script swiped, Cancel, still there; swiped again, Delete Script, gone.
6. **Privacy manifest.** The required-reason APIs searched for again across `Earwig/`; the manifest written; the built app checked to contain `PrivacyInfo.xcprivacy`.
7. **Release build.** `MARKETING_VERSION: "0.2.0"`; the Release configuration built in the simulator, no warnings; the Debug flags checked to be compiled out.
8. **The script.** `testflight.sh` and `ExportOptions.plist`; `bash -n` and, if installed, `shellcheck`; its refusals tried without uploading (a dirty tree, a missing Keychain item, an existing tag), and a failure after the bump checked to leave `project.yml` as it was.
9. **Andy's part.** The Keychain items stored with the commands the script prints, and the App Store Connect record and internal group made (decision 10).
10. **The first upload,** run by Claude with Andy's yes: the script, the build in App Store Connect, any mail about the manifest, then the install from TestFlight on the phone and the device checks (Verification). The commit and the tag pushed with Andy's yes.
11. **Finish.**
    - SwiftLint clean, no warnings, all tests pass.
    - Results filled in, with #14's verdict.
    - README's Settings section and Title Case.
    - PRD as v0.14: §4.8 and §8.4 as built, with what was struck (decision 4); §2's Distribution (the project generated, the build bumped by the script, the Keychain items); §12 with stage 7 done, the MVP stages complete; a Document History row.
    - CLAUDE.md: the status (plan 012 complete, next #37 as plan 013), how a TestFlight build is uploaded, and the Show Take Details note for device checks.
    - `progress.md` emptied to its stub.
12. **The release, after the PR merges** (each push needs Andy's yes): the annotated tag `v0.2.0` on `main` at the merge commit, pushed, and the GitHub Release marked pre-release, notes from the Document History since v0.1.0 and the known issues.

## Verification

- `xcodebuild test` passes in the simulator with no warnings; SwiftLint clean; the Release configuration builds with no warnings.
- Simulator: Settings in its seven groups; Show Take Details hides and shows the line; About shows 0.2.0 and the build; a swipe to delete asks first, and Cancel keeps the script (step 5).
- The script's refusals, without an upload (step 8).
- On the iPhone 14 Pro with the SK18, one check at a time, the verdicts Andy's:
  1. **Preview** reads the sentence in Stephanie at 0.95x through the earpiece, and Stop stops it. At another voice speed it sounds that speed.
  2. **Cue Voice**: a voice chosen by hand reads the cues in a take on a sample with Read Cues on; Automatic reads them as before.
  3. **Show Take Details** off: a take has no engine line. On: it has.
  4. **Swipe to delete** on a script of Andy's own: the question comes up with the script's title and the row stays put; Cancel keeps it and its takes. Then a throwaway pasted script, swiped, **Delete Script**: it goes (review C1).
  5. **The TestFlight build**: it appears in the TestFlight app and installs over the development build. The Scripts screen keeps its scripts and takes. About shows 0.2.0 (2).
  6. **A take on the TestFlight build**: With Voice on The Old Watermill, the earpiece in, the phone locked in a pocket. It follows and completes as the development build did.
  7. **Back to a development build**: `devicectl` installs over the TestFlight build and the scripts and takes are still there, so development carries on as before.

## Results

To be filled in when the plan is built and checked.

## Review pass — 2026-11-09

Findings from `/review-branch` on branch `settings-testflight`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact, and each verdict under *Assessment* is a
recommendation, not a decision. Work through them and annotate each with what was done — fixed,
or rejected and why. A finding that turns out to be wrong should say so here rather than be
deleted.

### Code

**C1. WARNING: swipe-to-delete's Delete Script may delete nothing.**
`Earwig/Views/Scripts/ScriptsView.swift:52-60`. The dialog's `isPresented` is a computed binding whose setter calls `model.cancelDeletion()`, and the button calls `model.confirmDeletion(in: context)`, which reads `pendingDeletion`. When a dialog or alert button is tapped, SwiftUI sets `isPresented` to false, and I believe on current iOS it often does so before running the button's action. If so, `pendingDeletion` is already nil when `confirmDeletion` runs, and the script is never deleted. Cancel works either way.
- The view-model tests cannot catch this, since they call the methods directly.
- progress.md says the simulator did not check the swipe, and device check 4 only exercises Cancel.
- `ScriptDetailView`'s own Delete Script avoids the problem because its action does not depend on state the binding clears.
- Fix: use `confirmationDialog(_:isPresented:titleVisibility:presenting:)` with `presenting: model.pendingDeletion`, and pass that script into a `confirmDeletion(of:in:)`. Or have the setter not clear the pending script.

**C2. WARNING: Preview probably cuts off its own last word in the earpiece.**
`Earwig/ViewModels/VoicePreview.swift:35-38, 47-53`.
- The completion passed to `audio.play` fires at `.dataRendered`, which `AudioEngineHost` says is when the last sample has gone to the output, not when it is heard. That is about 356 ms early on the SK18.
- In that completion, `stop()` calls `audio.stop()` (which stops the engine) and `session.deactivate()`. That probably clips the tail of the sentence over Bluetooth.
- `StepPreview` (Listen) and `ListeningCheck.sayTest` leave the engine and session running at the end of the audio; only an explicit Stop tears them down.
- Fix: at the end, only clear `isPlaying`, perhaps after `audio.outputLatency`, and leave the engine and session until the next play, Stop or `onDisappear`. This is a device check, not something I can confirm here.

**C3. WARNING: in the release script, a failure after a successful upload undoes the build bump.**
`scripts/release/testflight.sh:780-788`.
- `succeeded=true` is only set after `git commit` and `git tag`. If the upload succeeds but the commit fails (a hook, signing, `user.email`), or `git tag` fails, the EXIT trap still runs `git checkout -- project.yml`.
- It then prints "Not uploaded. project.yml is as it was." That is false: App Store Connect has the build.
- The next run would bump to the same number again, and App Store Connect refuses it.
- If the tag fails after the commit, there is a commit with no tag.
- Fix: set a flag once `-exportArchive` returns, and after that point the trap should keep `project.yml` and say the upload went through but the commit or tag needs doing by hand.

**C4. SUGGESTION: plan step 11 is not done yet.**
None of these files has changed on the branch:
- `PRD.md`: §4.8 rewritten with what was struck (decision 4), §2 Distribution amended, §12 stage 7 done, v0.14 and a Document History row.
- `CLAUDE.md`: the status (plan 012, next #37 as plan 013), how a TestFlight build is uploaded, and the Show Take Details note.
- The plan's Results, including #14's verdict.

progress.md also notes that `docs/screenshots/settings.png` shows the old Voice group. This is expected before the PR, but it is still owed.

**C5. SUGGESTION: a stale comment in `project.yml:14-15`.**
It still says "Bump the build before each TestFlight upload and commit it". `testflight.sh` now does both, so the comment should point at the script (decision 8).

### Tests

**T1. SUGGESTION: the sample-protection test now overlaps the new suite, and half of the new test only pokes a defensive guard.**
- `SampleSeederTests.samplesAreNotDeleted` (`EarwigTests/SampleSeederTests.swift:108-118`) now runs ask then confirm over every script. That checks that samples survive and an own script is deleted, through the public flow.
- `ScriptsViewModelTests.aSampleIsNeverAskedAboutOrDeleted` (`EarwigTests/ScriptsViewModelTests.swift:50-59`) checks the same thing.
- Lines 56-57 of the new test then set `model.pendingDeletion = sample` directly. This exists only to reach the second `!script.isSample` guard in `confirmDeletion` (`Earwig/ViewModels/ScriptsViewModel.swift`). The app never reaches that guard, because only `askToDelete` sets `pendingDeletion`.
- Simpler option: make `pendingDeletion` `private(set)`, drop the redundant guard, and keep only one sample-protection test. A good choice is the `SampleSeederTests` one, which also checks that the own script goes.

**T2. SUGGESTION: `cancellingKeepsTheScriptAndItsTakes` checks the takes a second time for no gain.**
- `EarwigTests/ScriptsViewModelTests.swift:38-48`.
- Cancelling never touches the context. Checking `scripts.count == 1` after the extra `confirmDeletion` is enough to show nothing is deleted; `#expect(takes.count == 1)` on line 47 adds nothing.
- Minor. Keeping it is harmless.

**T3. SUGGESTION: one assertion repeats what an existing test already covers.**
- `aCueVoiceNoLongerInstalledIsAutomaticAgain`, `EarwigTests/VoiceCatalogueTests.swift:86`: `choose(from: voices, cueID: nil)?.cue.name == "Jamie"` is already covered by `stephanieIsThePresenterWhenSheIsThere` (lines 10-16), where no cue is picked and the cue is Jamie.
- It can go.

**T4. SUGGESTION: `VoicePreview`'s stop-before-render guard is untested and cannot be tested as written.**
- `Earwig/ViewModels/VoicePreview.swift:13-14, 25-53`.
- The `generation` counter stops a render that finishes after Stop from playing, and keeps a late completion from stopping a newer preview. That is real state logic, but it is built on the concrete `AudioSessionManager` and `AudioEngineHost`, so it cannot be faked.
- `AudioEngineHost` already conforms to `PlayerOutput` (`Earwig/Services/AudioEngineHost.swift:16`). Injecting that, plus a session seam, would allow one small test: Stop during the render, then check that nothing played and `isPlaying == false`.
- Optional. The preview is in the audio path and needs a check on the phone anyway.

### Assessment

- C1 — FIX: the action reads state the binding's setter clears (`ScriptsView.swift:54-57`); whichever order SwiftUI runs them in, `presenting:` with the script passed to `confirmDeletion(of:in:)` cannot lose it. Device check 4 gains the Delete half.
- C2 — FIX: `VoicePreview.swift:35-38` tears the engine and session down at `.dataRendered`, before the earpiece has played the last ~356 ms; wait out `audio.outputLatency` (plus a margin) before stopping, as nothing else in the app stops at that callback.
- C3 — FIX: real (`testflight.sh:84-136`); mark the upload once `-exportArchive` returns, and after that the trap keeps `project.yml` and says what to do by hand.
- C4 — SKIP: the PRD, CLAUDE.md, Results and the screenshot are the plan's Finish step, after the device checks, as the plan orders them.
- C5 — FIX: one comment, `project.yml:14-15`, to point at the script.
- T1 — FIX (part): with C1's `confirmDeletion(of:in:)` the sample guard in it is reachable again, so keep it; make `pendingDeletion` `private(set)`; drop `aSampleIsNeverAskedAboutOrDeleted` and keep `SampleSeederTests.samplesAreNotDeleted`, which goes through ask and confirm for every script.
- T2 — FIX: drop the redundant `takes.count` line; one line.
- T3 — FIX: drop the repeated assertion; one line.
- T4 — SKIP: seams for a two-second sound in Settings cost more than they catch; device check 1 covers Preview and Stop.

### Outcome — 2026-11-09

- C1 — fixed: the dialog uses `presenting: model.pendingDeletion`, and Delete Script passes that script to `confirmDeletion(of:in:)`.
- C2 — fixed: at the end of Preview the engine and session stop after the route's output latency and 0.2 s more, not at `.dataRendered`.
- C3 — fixed: `uploaded` is set once `-exportArchive` returns; after that a failed commit or tag keeps `project.yml` and says what to do by hand.
- C4 — not done here: the Finish step, after the device checks.
- C5 — fixed: the `project.yml` comment points at the script.
- T1 — fixed (part): `pendingDeletion` is `private(set)`; the duplicate sample test is gone, and `SampleSeederTests.samplesAreNotDeleted` also checks a sample is never asked about.
- T2 — fixed: the redundant check is gone.
- T3 — fixed: the repeated assertion is gone.
- T4 — not done: seams for Preview cost more than they catch; device check 1 covers it.

371 tests pass with no warnings; SwiftLint clean.
