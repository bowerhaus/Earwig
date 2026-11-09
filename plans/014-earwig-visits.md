# Plan 014: Earwig Visits

**GitHub Issue:** _to be created (needs Andy's yes)_ (PR must include "Closes #NN")
**Branch:** `earwig-visits` (from `main` at `2294bc0`, after plan 012 merged; plan 013, the App Store release, is in flight on `app-store-release` and touches none of this plan's code, so whichever merges second rebases the PRD version and CLAUDE.md's status)
**Status:** Draft (2026-11-09). A plan for fun, outside PRD §12's stages, like plan 007.
**Manual test:** device, on Andy's iPhone 14 Pro: the walk, its size and speed, behind and in front, the tap, and that it keeps away during a take, Listen and Preview (Verification). How often it comes is decided after about a week of TestFlight use.
**Goal:** Every so often, the earwig from the icon walks across the screen. Sometimes it goes behind the cards, showing in the gaps between them; sometimes it walks over them. Tap it while it's in front and it runs off. It never appears during a take, while Listen or Preview is reading, or with Reduce Motion on, and it never gets in the way of a tap meant for the app.

**PRD references:** §8 (screens), §10 Design Language (the mark), Document History.

---

## Context

Raised by Andy on 2026-11-09 as a bit of fun. The feasibility talk settled:

- **Anywhere outside a take**, so the Scripts screen, the Script screen and Settings.
- **No Settings switch** for users. Reduce Motion still keeps it away, because that's the system's rule, not ours.
- **A tap makes it run away.**
- **It's the white mark as it is** (plan 007, decision 2), with its legs and antennae moving.
- **A temporary How Often slider** in Diagnostics, for tuning only, removed before the App Store build that follows the tuning.

Then, from the questions on the same day:

- **It keeps away while Listen or Voice Preview is playing.**
- **It's safe behind the cards.** Only the earwig in front runs from a tap.
- **How often is a chance plus a rest:** a small chance each time a screen appears, and never two visits within a few minutes.
- **Everyone sees the slider until it's removed.** It isn't hidden by build type, so removing it is a finish item for this plan and a line in the next release's checklist (decision 10).

The mark is already drawn from simple shapes in `scripts/app_icon/make_app_icon.py`: ellipses, rounded rectangles and one path for the body, and each leg, antenna and forceps as a separate round-capped stroke. That's what makes it animatable without redrawing it.

## Scope

**In:**
- the walking earwig, drawn from the mark's geometry;
- its paths, pauses and running away;
- how often it comes, and when it keeps away;
- the behind and in-front layers on the Scripts, Script and Settings screens;
- the temporary How Often slider;
- a simulator launch flag;
- tests for the parts that are plain logic;
- the device check.

**Out:**
- anything on the Prompt screen: the take, the framing preview, Finished and Play Back;
- the Listen sheet and the Listening Check;
- crossing from behind to in front during a walk (diving under a card), for later if wanted;
- more than one earwig at once, sounds, and haptics on the tap (a haptic is easy to add if the tap feels flat on the phone);
- changes to the icon or the mark.

## Design decisions

1. **How it's drawn. Options:**
   - **(a) The script writes the geometry as Swift (recommended).** `make_app_icon.py` also writes `Earwig/Views/Visitor/EarwigGeometry.swift`: the head, pronotum, wing cases, abdomen and cuts as points and sizes, and each leg, antenna and forceps as its points with its pivot (where it joins the body). The file is generated and committed, with a "do not edit" header. A `Canvas` draws it in white.
     - Pro: one source for the icon, the mark and the walker, keeping plan 007's rule of "no Swift drawing to keep in step with the Python".
     - Pro: crisp at any size, and cheap to draw.
     - Con: the script grows a Swift writer.
   - **(b) Port the geometry to Swift by hand.**
     - Pro: no change to the script.
     - Con: two copies of the shape, which will drift apart the first time the mark is touched.
   - **(c) The script renders each part as its own image**, and SwiftUI rotates the legs about their pivots.
     - Pro: no path code in Swift.
     - Con: about fifteen images to place and pivot exactly. Joints show seams at large sizes, and the cuts' mask is harder to keep.

2. **The gait.** Insects walk on two alternating sets of three legs: front and back on one side with the middle leg on the other. Each leg swings forward and back about its pivot, through an angle tuned on the phone (start at ±12°). The legs' phase follows the distance walked, not the clock, so they stop when it pauses and never slide. The body sways slightly with each step, the antennae twitch on their own slow rhythm, and the forceps stay still. A pure `Gait` struct gives every part's angle for a distance walked, and it is tested.

3. **Size and speed.** About 70 pt long, close to a real earwig on the 14 Pro's screen. It walks at about 60 pt a second, so a crossing takes 6–10 seconds with its pauses. Both are constants, tuned on the phone.

4. **The path.** A pure `VisitPath`, made from the screen's size and a random source (seeded in tests):
   - It enters off one edge and leaves off another, or sometimes the same one, along a gentle curve. It always faces the way it's going.
   - It pauses once or twice for 0.5–1.5 s, with the antennae still twitching.
   - Now and then it turns back halfway and leaves the way it came.
   - It never pauses under the top bar or the home indicator, so it never seems to hide there.
   - Position and heading come from time since the walk began, so the view only asks `place(at:)`.

5. **What drives the animation. Options:**
   - **(a) `TimelineView(.animation)` asking the path and the gait for each frame (recommended).**
     - Pro: everything is plain logic, testable without SwiftUI.
     - Pro: running away is just a new path from the current place.
     - Pro: it only ticks while a walk is on screen.
   - **(b) SwiftUI keyframe animations.**
     - Pro: smooth easing for free.
     - Con: legs tied to distance walked are awkward to express.
     - Con: a walk can't easily be interrupted and turned into a run.

6. **Behind and in front. Options:**
   - **(a) One modifier per screen, `.earwigVisits(on:)` (recommended).** It puts one layer between the screen's sky blue and its list and one over the list. The layer over the list takes taps only on the earwig itself, and each walk picks one layer at random.
     - Pro: plain SwiftUI. Behind really is behind, because the cards are drawn over it.
     - Pro: the take's cover and the Listen sheet simply don't have it.
     - Con: it can't walk over a sheet's edge, and a new screen must remember to add it.
   - **(b) A transparent window above the whole app for "in front", plus the per-screen layer for "behind".**
     - Pro: it could cross over sheets and the top bar.
     - Con: the window would sit above the take's cover too, so it must be torn down reliably for every take. That's risky in exactly the place it must never appear.
     - Con: it needs UIKit for its window and its hit testing.
   - On the Scripts and Script screens the layer over the list sits under the navigation bar, so it walks under the title and the buttons, not over them.

7. **Running away.** A tap on the earwig in front:
   - turns it away from your finger;
   - sends it to the nearest edge at about four times its walking speed, its legs going four times as fast;
   - takes nothing from the app: the earwig's shape takes the tap, and everything else on the layer lets taps through.
   - The earwig behind is under the list, which takes every tap, so it's safe by construction.
   - A tap on it never counts as a visit ending early for the rest in decision 8.

8. **How often.** A pure `VisitSchedule`:
   - When one of the three screens appears, it rolls the slider's chance.
   - If the roll hits, and no visit started within the rest (3 minutes), a walk starts after a random 2–6 s, so it isn't there the moment the screen opens.
   - The rest is app-wide, so moving quickly between screens can't bring visits close together.
   - Every Visit on the slider ignores the rest, for testing.
   - There is never a visit during the splash, and never more than one earwig at a time.

9. **When it keeps away.** An app-wide `@Observable` `EarwigVisits` in the environment holds the last visit's time and the keep-away conditions:
   - **A take:** the Script screen's visit is removed the moment `model.take` is set, not just covered. Nothing should animate under the take's cover while the engine ticks at 20 Hz.
   - **Listen:** the Listen sheet has no earwig, and the Script screen's visit is removed while the sheet is up.
   - **Preview:** in Settings, none starts while Preview plays, and one already walking runs off when Preview starts.
   - **Reduce Motion:** no visits at all.
   - **VoiceOver:** the earwig is hidden from it.
   - **A visit already on screen** when a sheet opens over it carries on underneath. It's harmless, and it's gone in seconds.

10. **The temporary How Often slider.**
    - **Where:** Settings › Diagnostics, as Earwig Visits.
    - **Steps:** Never, 1 in 50, 1 in 20, 1 in 10, 1 in 5, 1 in 2, Every Visit, uneven so the rare choices are easy to pick.
    - **Storage:** kept in `@AppStorage`. The default is 1 in 10 while testing.
    - **Removal:** it's shown in every build until removed (Andy's choice), so removing it is part of finishing:
      - the chosen chance becomes a constant;
      - the slider is deleted, in this plan if the rate is settled before the PR, or in a small follow-up branch otherwise;
      - CLAUDE.md's status says it must go before the next App Store build until it has gone.

11. **Simulator flag.** `-EarwigVisits YES` (Debug builds) makes every screen appearance a visit, ignoring the slider and the rest, so the walk can be seen and screenshotted without waiting.

## Files

- `scripts/app_icon/make_app_icon.py` (edited: writes the Swift geometry).
- `Earwig/Views/Visitor/EarwigGeometry.swift` (new, generated).
- `Earwig/Views/Visitor/EarwigFigure.swift` (new: the `Canvas` drawing for a gait pose).
- `Earwig/Views/Visitor/EarwigVisitorLayer.swift` (new: the two layers and the `.earwigVisits(on:)` modifier).
- `Earwig/Services/EarwigVisits.swift` (new: `EarwigVisits`, `VisitSchedule`, `VisitPath`, `Gait`).
- `Earwig/Views/Scripts/ScriptsView.swift`, `Earwig/Views/ScriptDetail/ScriptDetailView.swift`, `Earwig/Views/Settings/SettingsView.swift` (edited: the modifier, the keep-away conditions and the slider).
- `Earwig/App/EarwigApp.swift` (edited: `EarwigVisits` in the environment, and no visit before the splash ends).
- `EarwigTests/EarwigVisitsTests.swift` (new).
- `PRD.md`, `CLAUDE.md`, `progress.md`, this plan.

## Steps

1. **Geometry.** The script writes `EarwigGeometry.swift`. Two runs are byte-identical, and the icon and mark PNGs don't change. `xcodegen generate` for the new folder.
2. **The figure and the gait.** `EarwigFigure` and `Gait`, checked in a SwiftUI preview walking on the spot and along a line. Screenshots from the simulator go to Andy for a first look at the gait before anything else is built on it.
3. **Paths and running away.** `VisitPath`, with tests: it starts and ends off screen, faces the way it goes, its legs are still during a pause, and it doesn't pause under the bars. A run starts from the current place and leaves by the nearest edge.
4. **Schedule and keep-away.** `VisitSchedule` and `EarwigVisits`, with tests: the chance, the rest, Every Visit ignoring the rest, Never never visiting, and each keep-away condition.
5. **On the screens.** The modifier on Scripts, Script and Settings, with the layers behind and in front and tap-through checked in the simulator with `-EarwigVisits YES`. Also checked there: a take started mid-walk removes it, and Listen and Preview keep it away.
6. **The slider.** Earwig Visits in Diagnostics.
7. **Device check** on the iPhone 14 Pro, one check at a time (Verification), installed with `devicectl`. Verdicts are Andy's.
8. **Finish.**
   - SwiftLint clean, no warnings, all tests pass.
   - Results filled in.
   - The slider's fate settled (decision 10).
   - PRD bumped with a Document History row and a short *Earwig visits* paragraph in §10.
   - CLAUDE.md's status updated.
   - `progress.md` emptied to its stub.

## Verification

- `uv run --with pillow scripts/app_icon/make_app_icon.py` twice: the second run changes nothing.
- `xcodebuild test` passes with no warnings; SwiftLint clean.
- Simulator, with `-EarwigVisits YES`: a walk on each of the three screens, behind and in front; rows still open and swipe under the earwig in front; a take, Listen and Preview keep it away.
- On the iPhone 14 Pro, Andy's verdicts:
  1. **The walk.** The gait, size and speed read as an earwig walking, not sliding or swimming.
  2. **Behind.** It shows in the gaps and disappears cleanly under the cards.
  3. **In front.** It walks over the cards under the navigation bar, and the list under it still scrolls and opens.
  4. **The tap.** It runs from your finger, fast, off the nearest edge, and the tap opens nothing.
  5. **Keeping away.** With Every Visit, start a take mid-walk: it is gone, and the take behaves as usual. Open Listen and play Preview: no earwig. Turn on Reduce Motion: no earwig.
  6. **Smoothness.** No hitch while scrolling the list during a walk.
  7. **How often.** After about a week of TestFlight use at a chosen setting, Andy picks the rate.

## Results

_To be filled in when the plan completes._
