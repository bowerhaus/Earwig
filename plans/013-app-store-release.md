# Plan 013: App Store Release

**GitHub Issue:** [#37](https://github.com/bowerhaus/Earwig/issues/37) (PR must include "Closes #37")
**Branch:** `app-store-release` (from `main` at `2294bc0`, after plan 012 merged and v0.2.0 was cut)
**Status:** Draft, for Andy's review.
**Manual test:** device, on Andy's iPhone 14 Pro with the SK18: the store build installed from TestFlight and a take run on it; then App Review, whose verdict is Apple's.
**Goal:** Earwig on the App Store at a low price, for people who would rather not build it from source (plan 011, decision 17). Everything between the TestFlight build plan 012 made and a store version: the agreements, the privacy and support pages, the listing, the screenshots, the review notes, the submission and the release. Afterwards the README sends visitors to the App Store.

**PRD references:** §1, §2 (Distribution), §12, §13, Document History.

---

## Context

Plan 012 made the App Store Connect record (**Earwig Ear Prompter**, bundle ID `com.bowerhaus.Earwig`, SKU `earwig`, primary language English (U.K.)), the privacy manifest, the release script and the first TestFlight build, 0.2.0 (2), internal testing only. #37 lists what is left. Much of it is Andy's on the website and slow to come through (the Paid Apps Agreement, banking and tax), so that starts first, while the pages, the listing and the screenshots are made here.

What Earwig is to a reviewer:
- iPhone only (`TARGETED_DEVICE_FAMILY` 1). An iPhone-only app is also offered on iPads, in a compatibility window, and App Review may test it there.
- It speaks and listens in British English only: the voices are en-GB (`ScriptRenderer`, `VoiceCatalogue.preferredLanguage`) and so is the recogniser (`Listener`, which downloads the en-GB speech assets through `AssetInventory` if they are missing).
- It wants a downloaded Enhanced voice (Stephanie) to sound good, and falls back to a lesser installed voice without one.
- It collects nothing: no accounts, no servers, no analytics, recognition on the phone. The manifest already says so.
- `UIBackgroundModes: audio`, which reviewers check is really used.

Two open issues are seen in the first minute of a take: #30 (a fluff in the last phrase ends the take short) and #33 (the route check's green reads as white, and it appears only once the take has begun). The README lists both as known issues of the pre-release.

## Scope

**In:**
- the decisions below, confirmed by Andy;
- Andy's agreements, banking, tax, the Small Business Program and the EU trader status;
- a privacy page and a support page, on GitHub Pages;
- the Photos purpose string reworded;
- `MARKETING_VERSION` 1.0.0, and the store build from the release script;
- the listing text, the review notes and the screenshots, kept in `docs/app-store/`;
- checks a reviewer will make that no take has: a first launch with permissions denied, no Enhanced voice, no earbud, and an iPad;
- App Store Connect filled in, the build submitted, the release;
- the README, the PRD and CLAUDE.md for an app that is on the store, and v1.0.0 on GitHub.

**Out:**
- #30 and #33 themselves: each is its own plan (decision 3);
- an app preview video (decision 9);
- in-app purchases, subscriptions, a free trial;
- other languages, and American voices and recognition;
- a public TestFlight link for external testers;
- a marketing website beyond the two pages.

## Design decisions

Each is a recommendation until Andy confirms it; his answers replace these in place.

1. **Version 1.0.0.** The store version is the first one people pay for, and the README says pre-release until 1.0. `MARKETING_VERSION` goes to 1.0.0 on this branch; the build number carries on from 2, so the first store build is 1.0.0 (3) and its tag `testflight/1.0.0-3`. After it, the GitHub release is `v1.0.0`, not marked pre-release, and the README's "Pre-release" goes.

2. **Price and territories.**
   - **Paid up front**, one price, no in-app purchases. The price is Andy's: #37 and plan 011 say low. A price point such as £2.99 / $2.99 is a starting point, not a recommendation.
   - **Every territory**, with the description saying plainly that Earwig speaks and listens in British English. An American presenter can still use it; a US English voice and recogniser would be their own issue.
   - The **EU** needs a trader declaration under the Digital Services Act (decision 5). If Andy does not want a trader address shown, the EU territories are left out until he has one he is happy to show.
   - **Not on Apple silicon Macs.** App Store Connect offers iPhone apps on Macs by default; it is unticked under Pricing and Availability, since there is no earbud-and-walk use there and the Mac has not been tried. **iPads stay**, since they cannot be unticked for an iPhone app; step 6 checks it runs there.

3. **#30 and #33 go first.** Each is a short plan of its own, merged to `main` and from there into this branch before the store build is uploaded, so the build App Review sees and people buy has neither. The README's known issues then have neither. If Andy would rather ship with them, the listing's promotional text says nothing of them and the README keeps them as known issues.

4. **Category**: Photo & Video primary, Productivity secondary. **Age rating**: the questionnaire answered with nothing, which comes out 4+. **Copyright**: "2026 Andy Bower" (or a business name, if Andy sells under one).

5. **Andy's accounts, on the website** (Claude cannot do these):
   - the **Paid Apps Agreement** in App Store Connect (Business), with the bank account and the tax forms (UK, and the US form), without which a paid app cannot be submitted;
   - the **App Store Small Business Program**, so Apple's commission is 15% in place of 30% (on the developer website, enrolment by the account holder);
   - the **EU trader status** (Business, Digital Services Act). Someone selling an app is a trader, and a trader's address, phone number and email are shown on the EU App Store. A business address, phone and email are better than home ones;
   - **App Review contact** details: a name, phone and email, which only Apple sees.

6. **The privacy and support pages**, as Markdown in `docs/` served by GitHub Pages (`main`, `/docs`), so the store links to `https://bowerhaus.github.io/Earwig/privacy` and `…/support`, which read as part of a finished app rather than as files in a repo. Turning Pages on is a repo setting, Andy's yes first.
   - **Privacy** (`docs/privacy.md`): Earwig collects nothing and has no servers or accounts. What it uses and why: the microphone and on-device speech recognition to follow you; the camera when you choose Video; Photos only when you save a video there from the share sheet. Scripts, takes and recordings stay on the phone, in its storage and its Documents folder; deleting the app deletes them. No tracking, no analytics, no third-party code. A contact for questions. Dated.
   - **Support** (`docs/support.md`): what Earwig needs (iOS 26, a Bluetooth earbud for the voice, an Enhanced voice and how to download one in Settings → Accessibility → Read & Speak → Voices), the questions a first user asks (no voice, the route check, Screen Only without an earbud, where recordings are), and how to get in touch: an email address for buyers, and the issues for those who use GitHub. **Which email is Andy's choice**; it is shown publicly, so a dedicated address is better than a personal one.
   - The pages are written in Andy's voice (warm, benefit first, "earbud"), with no links to the licence from them; the repo links to them, not the other way round (plan 012, decision 7).

7. **Purpose strings.** The Photos string mentions "Save Video", the share sheet's own button, not one of Earwig's. It becomes "Earwig saves a take's video to Photos when you share it and choose Save Video." The others stay: they say what is used and that recognition stays on the phone.

8. **The listing**, drafted in `docs/app-store/listing.md` for Andy to edit and paste, every field within its limit:
   - **Name**: Earwig Ear Prompter (19 of 30).
   - **Subtitle** (30): a choice of three, for example "Your script in your earbud".
   - **Promotional text** (170), which can change without a new build.
   - **Description** (4,000): the README's What it's for, rewritten for a buyer. The ear prompter first, then the teleprompter, recording, the samples to try, everything on the phone, British English, and the Enhanced voice to download. No Cutaway (unpublished), no Personal Voice, no licence or source talk.
   - **Keywords** (100, commas, no spaces): words not already in the name or subtitle, for example teleprompter, prompter app, script, presenter, vlog, earbud, speech, cue, reader, YouTube. **No "autocue"**: Autocue is a trademark, and App Review rejects other people's trademarks in keywords. The description may still say "autocue" in passing only if Andy wants it; the safer choice is "teleprompter".
   - **Support URL** and **privacy policy URL** (decision 6); **marketing URL** the GitHub repo or none, Andy's choice.

9. **Screenshots, no preview video.**
   - The 6.9-inch size (1320 × 2868), which App Store Connect scales for the smaller iPhones, taken in the iPhone 17 Pro Max simulator with the status bar set to 9:41, full battery and signal (`xcrun simctl status_bar override`), on the made-up samples. Five or six: the Scripts screen with the samples, the Script screen's start card, a take With Voice (the voice's phrase), a Screen Only take with the text following (`-EarwigScreen YES -EarwigReads YES`), the finished take with Play and Share, and Settings.
   - Each with a short caption above it on the theme's sky blue, drawn by `scripts/app_store/make_screenshots.py` (pillow, as the README's images are) from the raw captures in `docs/app-store/screenshots/raw/`, so they can be redrawn when the screens change.
   - iPad screenshots are not asked for, since the app is iPhone only.
   - A **preview video** is the best way to show the voice keeping ahead, but it must be a screen recording of the app at the 6.9-inch size, and the voice is heard through the earbud, not the recording. It is left for a later version.

10. **The review notes**, drafted in `docs/app-store/review-notes.md`, for the App Review Information box:
    - Earwig reads a script into a Bluetooth earbud a few words ahead of the presenter and follows them with on-device speech recognition on the iPhone's own microphone. The earbud is output only.
    - No login, nothing to paste: open **The Harbour Walk** under Samples and tap **Start Take**.
    - **Without an earbud**: choose **Screen Only** on the start card, and read the sample aloud; the text follows. **Listen** plays the voice through the speaker.
    - It sounds best with an Enhanced English (UK) voice downloaded (Settings → Accessibility → Read & Speak → Voices → English (UK) → Stephanie (Enhanced)); without one it uses the best voice installed.
    - **Background audio**: a take is meant to be run with the phone locked in a pocket; the voice keeps playing and the microphone keeps listening. Lock the phone during a take to see it carry on.
    - It speaks and listens in British English.
    - It collects no data; recognition never leaves the phone.

11. **Release**: **manual**, so Andy picks the day once it is approved. Phased release only spreads automatic updates, so it means nothing for a first version.

12. **One branch to the end.** The store build is uploaded from this branch once `main` (with #30 and #33) is merged into it. The PR opens when the build is submitted and merges once the app is approved and the README carries its App Store link, so `main` gets the release in one merge and `v1.0.0` is tagged there. If App Review asks for a change, it is made here and a new build uploaded.

## Files

- `docs/privacy.md`, `docs/support.md` (new: the GitHub Pages pages), and `docs/_config.yml` if the pages want a title or theme.
- `docs/app-store/listing.md`, `docs/app-store/review-notes.md` (new).
- `docs/app-store/screenshots/raw/*.png`, `docs/app-store/screenshots/*.png` (new).
- `scripts/app_store/make_screenshots.py` (new: captions on the raw captures).
- `project.yml` (`MARKETING_VERSION` 1.0.0; the Photos string; the script bumps the build).
- `README.md` (the App Store link, "Pre-release" gone, Releases and known issues).
- `PRD.md`, `CLAUDE.md`, `progress.md`, this plan.

## Steps

1. **Andy's decisions** (1 to 12) confirmed or changed, and the plan amended. The email for the support page chosen.
2. **Andy's accounts** (decision 5), started at once since banking and tax can take days: the Paid Apps Agreement, the Small Business Program, the EU trader status, the App Review contact.
3. **The pages.** `docs/privacy.md` and `docs/support.md`, read by Andy; GitHub Pages turned on for `/docs` (Andy's yes, or Andy in the repo's settings); both URLs checked to load.
4. **The build's changes.** The Photos string; `MARKETING_VERSION: "1.0.0"`; the Release configuration built in the simulator with no warnings; tests and SwiftLint.
5. **First-launch checks in the simulator**, as a reviewer meets the app (results recorded, not assumed):
   - a fresh install on an erased simulator: the samples are there, and The Harbour Walk opens;
   - the microphone and speech recognition **denied** (`xcrun simctl privacy … revoke`): a take says why it cannot listen, and Screen Only, Listen and the rest still work, with no crash;
   - the camera denied: a Video take says so;
   - no Enhanced voice installed (the simulator's case): Listen and a take use another voice and nothing breaks.
6. **iPad.** The app in the iPad Air 13-inch simulator, in iPhone compatibility: the Scripts screen, a Screen Only take with `-EarwigReads YES`, Settings, rotation. Anything broken is fixed here or noted for review.
7. **The listing and review notes** drafted (decisions 8 and 10), with every field's length counted; Andy edits.
8. **Screenshots.** `make_screenshots.py`; the raw captures from the iPhone 17 Pro Max simulator with the status bar overridden; the captions agreed with Andy; the finished images checked at 1320 × 2868.
9. **#30 and #33** (decision 3), each its own plan, merged to `main`; `main` merged into this branch.
10. **The store build**, run by Claude with Andy's yes: `scripts/release/testflight.sh`, giving 1.0.0 (3); the commit and tag pushed with Andy's yes; installed from TestFlight on the phone and checked (Verification).
11. **App Store Connect**, by Andy on the website, from the files in `docs/app-store/`: the 1.0.0 version page (screenshots, text, URLs, build 3), App Privacy (**Data Not Collected**), the age rating, the category, the price and territories, Macs unticked, the review notes and contact, manual release. Andy presses **Submit for Review**. The PR opened (Andy's yes), saying the app is in review.
12. **App Review.** Its verdict and any questions recorded in Results; a rejection fixed on this branch and a new build uploaded.
13. **After approval**, with Andy's yes at each push:
    - Andy releases it in App Store Connect;
    - the README: the App Store link at the top and in Releases, "Pre-release" gone, the known issues brought up to date;
    - the PRD as v0.15 (§1 and §2 Distribution: on the App Store, how a store version is cut; §12 and §13; a Document History row) and CLAUDE.md's status and release steps;
    - Results filled in; `progress.md` emptied to its stub;
    - the PR merged; the annotated tag `v1.0.0` on `main` at the merge commit, pushed, and the GitHub release, not marked pre-release, notes from the Document History since v0.2.0.

## Verification

- `xcodebuild test` passes in the simulator with no warnings; SwiftLint clean; the Release configuration builds with no warnings.
- The first-launch and iPad checks (steps 5 and 6) in the simulator, as recorded.
- The privacy and support URLs load from a phone that is not signed in to GitHub.
- Every listing field within its limit; the screenshots at 1320 × 2868.
- On the iPhone 14 Pro with the SK18, one check at a time, the verdicts Andy's:
  1. **The store build from TestFlight**: it installs over the development build, the scripts and takes are kept, and About shows 1.0.0 (3).
  2. **A take With Voice** on a sample, the phone locked in a pocket: it follows and completes.
  3. **Screen Only with no earbud**, as a reviewer would: the text follows.
  4. **Saving a video to Photos** from the share sheet: the reworded string is the one asked.
- App Review's verdict.
- After the release: Earwig Ear Prompter found by searching the App Store, bought and installed on the phone by Andy (over the TestFlight build, keeping the data, or recorded if not).

## Results

To be filled in.
