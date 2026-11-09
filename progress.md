# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

## Plan

**Plan 013, App Store Release** ([#37](https://github.com/bowerhaus/Earwig/issues/37)): `plans/013-app-store-release.md`. Read it in full before resuming; its decisions and steps are the authority, this file only tracks where we are.

- **Branch:** `app-store-release`, from `main` at `2294bc0` (after plan 012 merged and v0.2.0 was cut). The branch already had the plan's name, so no second branch was made.
- **Approved** by Andy on 2026-11-09, with decisions 2, 4, 5 and 6 amended: Andy sells as an **individual** (no company; his legal name is the seller, copyright "2026 Andy Bower"); every territory **except the EU** (the DSA trader rule would make his own address and phone public) **and mainland China** (ICP filing); a **dedicated support email**, set up by Andy, on the support and privacy pages; the US tax form is the **W-8BEN**; no EU trader declaration.
- Other decisions as drafted: version **1.0.0** (first store build 1.0.0 (3)); **#30 and #33 fixed first**, each its own plan, merged to `main` and then into this branch before the store build; pages on **GitHub Pages** from `/docs` (`bowerhaus.github.io/Earwig/privacy`, `/support`); **no "autocue"** in keywords; captioned **6.9-inch** screenshots (1320 × 2868) from the iPhone 17 Pro Max simulator, no preview video; **manual release**; **one branch to the end** (the PR merges after approval, then `v1.0.0` on `main`).

## Working rules for this plan

- **Do not stage or commit.** Andy stages and commits by hand (his instruction, 2026-11-09, overriding CLAUDE.md's "Claude commits locally" for this plan). Leave changes in the working tree and tell him what changed.
- The plan's two commits so far (`e687c8d`, `13a8a8c`) were made before that instruction. The Status line and this file are uncommitted edits.
- Pushing, opening the PR, turning on GitHub Pages and each TestFlight upload need Andy's yes. Device verdicts are Andy's; never guess one.
- Facts found while planning: voices and recognition are en-GB only (`ScriptRenderer`, `VoiceCatalogue.preferredLanguage`, `Listener`); `Listener` downloads the en-GB speech assets through `AssetInventory`; the Photos string is in `project.yml` (`NSPhotoLibraryAddUsageDescription`) and the share sheet is `ShareLink` in `Earwig/Views/Prompt/PromptView.swift`; the simulators include iPhone 17 Pro Max and iPad Air 13-inch (M4).

## Steps

1. [ ] **Decisions confirmed.** Done 2026-11-09. Still open: **Andy sets up the dedicated support email and names it.** Until then the pages use a placeholder `SUPPORT_EMAIL`.
2. [ ] **Andy's accounts** (Andy, on the website, start now): the Paid Apps Agreement with a personal bank account and the W-8BEN; the Small Business Program; the App Review contact. Not started.
3. [ ] **The pages**: `docs/privacy.md`, `docs/support.md` (and `docs/_config.yml` if wanted), in Andy's voice; Andy reads them; GitHub Pages on for `/docs` (Andy's yes); both URLs load. Not started. **Next for Claude.**
4. [ ] **The build's changes**: the Photos string ("Earwig saves a take's video to Photos when you share it and choose Save Video."); `MARKETING_VERSION: "1.0.0"`; Release build in the simulator, no warnings; tests; SwiftLint. Not started.
5. [ ] **First-launch checks in the simulator**: fresh install on an erased simulator; microphone and speech denied (`xcrun simctl privacy … revoke`); camera denied; no Enhanced voice. Record what happens. Not started.
6. [ ] **iPad**: iPad Air 13-inch simulator in iPhone compatibility; Scripts, Screen Only take with `-EarwigReads YES`, Settings, rotation. Not started.
7. [ ] **Listing and review notes**: `docs/app-store/listing.md`, `docs/app-store/review-notes.md`, lengths counted; Andy edits. Not started.
8. [ ] **Screenshots**: `scripts/app_store/make_screenshots.py`; raw captures in `docs/app-store/screenshots/raw/` with `xcrun simctl status_bar override`; captions agreed with Andy; output at 1320 × 2868. Not started.
9. [ ] **#30 and #33**, each its own plan, merged to `main`, then `main` merged into this branch. Not started.
10. [ ] **The store build**: `scripts/release/testflight.sh` with Andy's yes → 1.0.0 (3); push the commit and tag with Andy's yes; install from TestFlight on the phone; device checks 1 to 4. Not started.
11. [ ] **App Store Connect** (Andy): version page, App Privacy (Data Not Collected), age rating, category, price, territories (EU and mainland China unticked), Macs unticked, review notes and contact, manual release; Submit for Review. PR opened with Andy's yes. Not started.
12. [ ] **App Review**: verdict and questions into Results. Not started.
13. [ ] **After approval**: release; README (App Store link, "Pre-release" gone, known issues); PRD v0.15; CLAUDE.md; Results; this file emptied to its stub; PR merged; `v1.0.0` tagged and released (not pre-release). Not started.

## To resume

"Resume from progress.md": read this file and `plans/013-app-store-release.md`, run `git status` on `app-store-release`, then carry on with the first unchecked step that is Claude's (step 3 now), ticking steps here as they finish.
