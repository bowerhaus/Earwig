# Plan 007: App Icon, Logo and Splash

**GitHub Issue:** [#21](https://github.com/bowerhaus/Earwig/issues/21) (PR must include "Closes #21")
**Branch:** `app-icon-splash` (from `main` at `5b1849e`, after plan 006 merged)
**Status:** Draft (2026-11-08). A cosmetic plan outside PRD §12's stages, like PhysiMate's plans 010 (app icon) and 012 (launch splash). Screen mode (stage 6) moves to plan 008.
**Manual test:** device, on Andy's iPhone 14 Pro: the icon in light, dark and tinted, the splash on a cold launch, and no splash on a return from the background or an unlock mid-take (Verification).
**Goal:** Give Earwig its identity. The Home Screen tile and TestFlight show a blank slot, and the app opens on a plain screen and snaps to sky blue. After this plan the tile is the chosen mark, a white earwig crawling at an angle on the theme's sky blue, in the three iOS appearances, drawn by a committed script so it can be regenerated; a cold launch opens on the same sky blue, the earwig and the name fade in and out in under a second, and nothing happens on a return from the background. The same mark is the logo wherever the app comes to show its name. A decision is recorded on the wider visual refresh the issue raises.

**PRD references:** §7 (services and folders), §10 Design Language, §12 (the stages this sits beside), Document History.

---

## Context

The mark was chosen on 2026-11-08 from a page of drafted concepts, [Earwig icon concepts](https://claude.ai/artifact/8hvAFycZj6MXAquw53z5cL) (private; read it back with the Artifact tool, `action: "read"`). Five rounds:

1. Eight first drafts in the app's palette: a cartoon earwig in one white line, the same flat with outlines, an ear with the earpiece as a buttercup disc, an ear from three sound arcs, word bars with the voice's word in buttercup, quotation marks, a letter e, and a glassy earbud. Rejected: the word bars, the quotation marks and the earbud.
2. Riffs on the arcs (turned anticlockwise, taller, with a lobe), on the e, and on the earwig redrawn to the insect's real proportions with no face. The e was dropped; the forceps alone were rejected.
3. The shortlist (the arcs at 18° and 28°, the earwig crawling at 35°) as splash screens, and a hybrid of the earwig with the arcs, rejected.
4. The buttercup tried in the earwig (wing cases, head, bands, forceps, the whole insect, inverted blue on buttercup) and less elongated earwigs.
5. Three colourings refined for the tile. Once Andy decided that the tile, the splash and the logo must carry one mark, the arcs dropped out (as a still they are a generic sound symbol; the earwig is the app's name), and blue on buttercup was set aside (the splash and launch colour would have had to follow it, and iOS's dark backdrop takes its colour away). **Chosen: 2d-j, the white earwig on sky blue**, over the same insect in buttercup on surface blue and with buttercup wing cases.

The sibling apps set the pattern: PhysiMate's icon is drawn as SVG by `scripts/app_icon/make_app_icon.py` and rendered by headless Chrome into light, dark and tinted PNGs (its plan 010); its splash is a SwiftUI overlay that fades in from a launch screen of the background colour alone, on cold launch only (its plan 012, whose Results found that a static launch picture handing over to the overlay "read as a jerk", and that iOS caches launch screens across reinstalls). OtterLite's splash (its plan 222) followed the same shape.

## Scope

**In:**
- the icon script and its SVG sources;
- the three icon PNGs and `Contents.json`, with light, dark and tinted appearances;
- a transparent mark image for the splash and the logo, from the same script;
- the launch screen colour, pinned to the theme by a test;
- the splash overlay on cold launch;
- a review of the renders on the concepts page before they go in, as PhysiMate's plan 010 step 2;
- the device check;
- the decision on the visual refresh, recorded in Results.

**Out:**
- a layered Liquid Glass icon (Icon Composer `.icon`); iOS 26 shows the classic set as it is;
- alternate icons, and a splash switch or styles in Settings (PhysiMate's grew these; Earwig's splash is under a second and has nothing to choose);
- showing the name or the logo on a screen the app does not have yet (About, the Settings header); the mark image is made here for that use, but no screen is added;
- the visual refresh itself (decision 8);
- the README screenshots and the release scheme (#22).

## Design decisions

1. **One mark for the tile, the splash and the logo** (Andy, round 5). The white earwig on the theme's sky blue. Its single ground means the chain from tile to launch colour to splash to the first screen is one colour, which is what makes a seamless splash possible.

2. **The mark's geometry**, in a 1024 × 1024 box, as the concepts page's "Chosen" section records it. The insect is drawn upright and then turned and scaled about the centre: `rotate(-35°)`, then `scale(1.06)`, both about (512, 512). Every stroke has round caps and joins. "Ground" lines are drawn in the ground colour to cut the body; on the transparent appearances they are drawn with the backdrop colour of that appearance, so they read as gaps (decision 4).
   - head: ellipse centre (512, 258), rx 44, ry 48;
   - pronotum: rect x 460, y 296, 104 × 68, rx 18;
   - wing cases: rect x 454, y 356, 116 × 102, rx 26, split by a ground line from (512, 366) to (512, 448), width 7;
   - abdomen: `M456 452 C448 540 468 640 486 704 L538 704 C556 640 576 540 568 452 Z`;
   - cuts: ground lines at y 520, 582 and 644, width 11, each from x 456 + 0.1 (y − 450) to 568 − 0.1 (y − 450);
   - antennae: `M492 224 C464 172 442 130 416 86`, width 22, and its mirror about x 512;
   - legs: `M462 336 L404 302 L362 330`, `M456 398 L394 410 L354 400`, `M460 448 L406 490 L372 530`, width 22, and their mirrors;
   - forceps: `M488 702 C430 764 424 856 496 896`, width 44, and its mirror.
   Drawing order: the body parts first (head, pronotum, abdomen, the cuts, the wing cases, the split), then the antennae, legs and forceps for each side.

3. **Drawn as SVG by a script, rendered by headless Chrome**, as PhysiMate's plan 010 decisions 1 and 2. `scripts/app_icon/make_app_icon.py` holds the geometry and the three palettes, writes `AppIcon-{light,dark,tinted}.svg` beside itself, renders them with `Google Chrome --headless --screenshot --window-size=1024,1024` (installed on the Mac; ImageMagick is not), and checks the PNGs with Pillow. Pillow is not in the Mac's Python, so the script runs with `uv run --with pillow scripts/app_icon/make_app_icon.py` from the repo root, as OtterLite's scripts do (`uv` is installed). Outputs are committed. Re-running gives byte-identical SVGs.

4. **The three appearances** (iOS 18+):
   - **Light:** the insect in white (`EarwigTheme.text`, #FFFFFF) on sky blue (`EarwigTheme.background`, #5CB8F3). Opaque RGB, as the App Store requires.
   - **Dark:** a transparent ground, so iOS supplies its dark backdrop; the insect in a slightly cooler white (#E9F3FC) so it does not glare; the cuts drawn in near-black (#0B1B2B), which reads as gaps on the backdrop.
   - **Tinted:** greyscale on a transparent ground; the insect light grey (#D9D9D9), the cuts near-black (#141414), so iOS can tint it.
   `Contents.json` lists the three 1024 images, the dark and tinted ones with `"appearances": [{"appearance": "luminosity", "value": "dark" | "tinted"}]`. No project changes: `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` is already set, and the catalogue is already a source.

5. **The mark for the splash and the logo is an image from the same script.** `make_app_icon.py` also renders the white insect alone, transparent, into `EarwigMark.imageset` at @2x and @3x for a 160 pt box (the splash shows it at about 150 pt; a smaller use scales it down with `.resizable()`). One source for every appearance of the mark, no Swift drawing to keep in step with the Python. The wordmark is live text: "Earwig" in the system font, rounded design, bold, white, judged on the phone against the concepts page's lockup.

6. **Launch screen: the colour alone.** `UILaunchScreen: { UIColorName: LaunchBackground }` in `project.yml`. `LaunchBackground.colorset` holds #5CB8F3 for both appearances, since the app has one look (PRD §10). It is an asset only because the launch screen needs one, so `LaunchSplashTests` pins it to `EarwigTheme.background` by loading the named colour from the app bundle and comparing its components. Views still take colours from `EarwigTheme`. No launch picture, after PhysiMate's plan 012 Results. iOS caches launch screens across reinstalls: restart the phone (or reboot the simulator) to see a change.

7. **The splash overlay**, `Views/Splash/SplashView.swift`, over `ScriptsView` in `EarwigApp`:
   - Opens as the plain sky blue, matching the launch screen exactly, so there is no handover to see.
   - The mark and the name fade in over 0.25 s, hold 0.4 s, and the whole overlay fades out over 0.3 s: about 0.95 s in all, under the issue's second. The timings are constants in a `SplashTiming` enum, tuned on the phone.
   - **Cold launch only, by construction**, as PhysiMate's decision 4: `@State private var showsSplash = true` in `EarwigApp`, set false by the view's completion and never reset. It is not tied to `scenePhase`, so a return from the background never replays it, and an unlock during a take (the app alive in the background with its audio) shows nothing. A relaunch after iOS ends the app shows it again, which is right.
   - **Reduce Motion** changes nothing: fades are not motion.
   - It swallows taps for its second, so a tap on launch cannot land on the list beneath, and it is hidden from VoiceOver.
   - The Debug launch flags (`-EarwigDemo`, `-EarwigListen`, `-EarwigTake`) keep working: the splash sits over whatever they open and is gone in a second.

8. **The visual refresh is decided at completion, not built here.** The issue's third part (colour, type, the step cards, the Prompt screen) is a judgement Andy makes with the icon and splash on the phone. The plan proposes **splitting it into its own issue** if any of it is wanted, since it touches every screen and stage 6's Screen mode is about to redraw the Prompt screen anyway. Results record the decision.

9. **Review before the assets go in**, as PhysiMate's plan 010 step 2: a Final section on the concepts page with the script's actual renders at 1024, 60, 40 and 29, in all three appearances, and the splash timing played. Andy approves or asks for changes; then step 3.

## Files

- `scripts/app_icon/make_app_icon.py` (new), with `AppIcon-{light,dark,tinted}.svg` and `EarwigMark.svg` (new, written by it).
- `Earwig/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` (edited) and `AppIcon-{light,dark,tinted}.png` (new).
- `Earwig/Resources/Assets.xcassets/EarwigMark.imageset/` (new: `Contents.json`, `EarwigMark@2x.png`, `EarwigMark@3x.png`).
- `Earwig/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json` (new).
- `project.yml`: `UILaunchScreen` (edited).
- `Earwig/App/EarwigApp.swift` (edited: `showsSplash` and the overlay).
- `Earwig/Views/Splash/SplashView.swift` (new: `SplashView`, `SplashTiming`).
- `EarwigTests/LaunchSplashTests.swift` (new).
- `PRD.md`, `CLAUDE.md`, `progress.md`, this plan.

## Steps

1. **Script.** `make_app_icon.py` from decision 2's geometry and decision 4's palettes; the SVGs, the three icon PNGs and the mark PNGs rendered and checked (1024 × 1024; light opaque RGB; dark, tinted and the mark RGBA with transparent corners). Run twice: identical SVGs. Committed on its own.
2. **Review.** The Final section on the concepts page from the rendered PNGs (decision 9). Andy approves, or step 1 is repeated.
3. **Asset catalogue.** `Contents.json` with the three appearances; `EarwigMark.imageset`. `xcodegen generate` (new folders); `xcodebuild … test` with no warnings, asset catalogue ones included; SwiftLint clean. Simulator: the icon on the Home Screen (`xcrun simctl io booted screenshot`); the dark appearance is checked with `assetutil --info` on the built `Assets.car`, since the simulator keeps the light icon (PhysiMate's plan 010 Results).
4. **Launch colour.** `LaunchBackground.colorset`, `UILaunchScreen` in `project.yml`, `xcodegen generate`, and `LaunchSplashTests` pinning the colour to the theme.
5. **Splash.** `SplashView` and `SplashTiming`; `showsSplash` in `EarwigApp`. Simulator: the splash on a cold launch; none on a return from the background (`xcrun simctl` to background and foreground it); the Debug flags still open their screens.
6. **Device check** on the iPhone 14 Pro, one check at a time (Verification), installed with `devicectl`. Verdicts are Andy's.
7. **Finish.**
   - SwiftLint clean, no warnings, all tests pass.
   - Results filled in, with the decision on the visual refresh (decision 8) and an issue opened for it if wanted (needs Andy's yes).
   - PRD as v0.9 with a Document History row: an *App icon and splash* paragraph in §10 (the mark, the appearances, the script, the launch colour and the splash's rules), and §12 noting the plan beside the stages, as PhysiMate's does.
   - CLAUDE.md: the status (this plan complete; Screen mode as plan 008) and one line on the icon script in Build Commands.
   - `progress.md` emptied to its stub.

## Verification

- `uv run --with pillow scripts/app_icon/make_app_icon.py` twice from the repo root: the second run changes nothing in `git status`.
- `xcodebuild test` passes in the simulator, with no warnings (none from the asset catalogue: no "unassigned child", no "alpha channel" on the light icon); SwiftLint clean.
- Simulator: the icon on the Home Screen in light; the splash once on a cold launch and not on a return from the background; `-EarwigDemo YES` still opens the sample script.
- On the iPhone 14 Pro, after a restart so the launch screen cache is cleared:
  1. **The icon.** Home Screen in light, dark and tinted; Settings and Spotlight sizes; nothing clipped by the rounded corners; the insect reads as an earwig at 60 pt. Andy's verdict.
  2. **Cold launch.** Open the app from the Home Screen: sky blue, the earwig and the name fade in and out, the Scripts screen appears, with no visible step at any point, under a second. Andy's verdict on the timing, with the constants adjusted if asked.
  3. **Return from the background.** Switch away and back: no splash.
  4. **Unlock mid-take.** Start a take with the phone in the hand, lock it, speak on, unlock: the Prompt screen, no splash, the take still following.
  5. **The lockup.** The name's weight and size beside the mark against the concepts page. Andy's verdict.

## Results

_To be filled in when the plan completes._
