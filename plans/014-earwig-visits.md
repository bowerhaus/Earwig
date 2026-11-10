# Plan 014: Earwig Visits

**GitHub Issue:** [#40](https://github.com/bowerhaus/Earwig/issues/40) (PR must include "Closes #40")
**Branch:** `earwig-visits` (from `main` at `2294bc0`, after plan 012 merged; plan 013, the App Store release, is in flight on `app-store-release` and touches none of this plan's code, so whichever merges second rebases the PRD version and CLAUDE.md's status)
**Status:** Complete (2026-11-10; built under `/plan_autopilot` and checked on the phone, with Andy's changes at the device checks). A plan for fun, outside PRD §12's stages, like plan 007.
**Manual test:** device | on Andy's iPhone 14 Pro: the walk, its size and speed, behind and in front, the tap, and that it keeps away during a take, Listen and Preview (Verification). How often it comes is decided after about a week of TestFlight use.
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

Then, at device check 2 on 2026-11-10, after the walk passed check 1 (Andy's words, then his answers to the choices put to him):

- **Going under a big card hid it for too long.** It now goes under a card only when it would be out the other side within **2 seconds**, and over the card otherwise (decision 6, amended). Andy first picked "within about a second", then asked for 2.
- **Critter is a setting for everyone.** This replaces "no Settings switch" and the temporary slider. The **Critter** slider runs from Never to All the Time in the Screen group, and stays (decision 10, amended; its first step was labelled Off until Andy asked for Never).
- **Not documented.** Critter isn't in the README. Its footer in Settings says only that it's a bit of fun.
- **It can come while you stay on a screen**, not only when you arrive. A screen rolls again every **30 seconds** while it stays (decision 8, amended).
- **Kept to as few files as possible**, since it isn't a fundamental part of the app (Andy). Everything is in `Earwig/Critter/`:
  - `Critter.swift` draws it, puts it on a screen and holds Settings' row;
  - `CritterWalk.swift` plans its walks and says when they come;
  - `CritterGeometry.swift` is its shape, written by the icon script.
  - Its types sit in a `Critter` namespace and its tests in `EarwigTests/CritterTests.swift`.
  - Outside the folder, the screens have:
    - `critterVisits()` on the Scripts, Script and Settings lists;
    - `critterCard()` on the Scripts and Script screens' card backgrounds (Settings marks none, so there it always walks over the cards);
    - `Critter.SettingRow()` and its footer in Settings.
  - `EarwigApp` is untouched. The visits are one shared `Critter.Visits`, and none comes under the splash, because the first is at least a second after a screen appears.
  - The Debug flag is now `-EarwigCritter YES`.

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

3. **Size and speed.** About 70 pt long, close to a real earwig on the 14 Pro's screen. It walks at 90 pt a second (raised from the drafted 60 in the simulator, where crossings took up to 17 s; 90 is about 1.5 cm a second on the 14 Pro, near a real earwig's pace), so a crossing takes 6–11 seconds with its pauses. Both are constants, tuned on the phone.

4. **The path.** A pure `VisitPath`, made from the screen's size and a random source (seeded in tests):
   - It enters off one edge and leaves off another, or sometimes the same one, along a gentle curve that bends at most a quarter of its length either side of the straight line. A walk that enters at the top or the foot leaves at a side, so none is the phone's whole height. It always faces the way it's going.
   - It pauses once or twice for 0.5–1.5 s, with the antennae still twitching.
   - Now and then a walk that came in at a side turns back halfway and leaves the way it came (only from a side, so one in at the top or the foot always leaves at a side).
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
   - **Amended at device check 2: which layer, card by card.** A walk no longer picks a layer at random.
     - The cards' backgrounds report their frames (`earwigCard()` on each `listRowBackground`).
     - On every frame, `Walk.layer(at:cards:)` works out which side of the cards the earwig is on: under a card only when the stretch of its route under that card takes 2 s or less (`Walk.longestHide`), and over it otherwise.
     - It asks of its head, middle and tail, so it goes under from the moment its head reaches a card until its tail leaves. A long stretch anywhere along its body keeps it over.
     - The rows of one card touch, so they count as one stretch.
     - Both layers follow the walk and each draws it only while it's on that layer's side, so it can go under one card and over the next.
     - Walks go across the phone and cards are wide, so going under is now mostly at corners and across short cards top to bottom, as Andy chose.

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
   - **Amended at device check 2:** while a screen stays up, it rolls again every 30 s (`VisitSchedule.again`), still subject to the rest. The Scripts screen keeps away while Settings is up over it.

9. **When it keeps away.** An app-wide `@Observable` `EarwigVisits` in the environment holds the last visit's time and the keep-away conditions: *Amended: this is `Critter.Visits`, shared by the screens (`Critter.Visits.shared`), not put in the environment.*
   - **A take:** the Script screen's visit is removed the moment `model.take` is set, not just covered. Nothing should animate under the take's cover while the engine ticks at 20 Hz.
   - **Listen:** the Listen sheet has no earwig, and the Script screen's visit is removed while the sheet is up.
   - **Preview:** in Settings, none starts while Preview plays, and one already walking runs off when Preview starts.
   - **Reduce Motion:** no visits at all.
   - **VoiceOver:** the earwig is hidden from it.
   - **A visit already on screen** when a sheet opens over it carries on underneath. It's harmless, and it's gone in seconds.

10. **The temporary How Often slider.** *Superseded at device check 2 by Critter, below.*
    - **Where:** Settings › Diagnostics, as Earwig Visits.
    - **Steps:** Never, 1 in 50, 1 in 20, 1 in 10, 1 in 5, 1 in 2, Every Visit, uneven so the rare choices are easy to pick.
    - **Storage:** kept in `@AppStorage`. The default is 1 in 10 while testing.
    - **Removal:** it's shown in every build until removed (Andy's choice), so removing it is part of finishing:
      - the chosen chance becomes a constant;
      - the slider is deleted, in this plan if the rate is settled before the PR, or in a small follow-up branch otherwise;
      - CLAUDE.md's status says it must go before the next App Store build until it has gone.
    - **Amended at device check 2: Critter.** A setting for everyone, kept in the app.
      - **Where:** the last row of Settings' Screen group, under Text Size, labelled **Critter**.
      - **Steps:** Never, Rarely, Now and Then, Sometimes, Often, Very Often, All the Time. These are the same chances as before, 0, 1 in 50, 1 in 20, 1 in 10, 1 in 5, 1 in 2 and 1. All the Time ignores the rest.
      - **Default:** Sometimes.
      - **Pace:** each walk picks its own between 65 and 120 pt a second, so some amble and some hurry; a run is four times the walk's pace (Andy, after device check 2). Decision 3's 90 pt a second is now the middle of that range.
    - **It moves with the list's scroll** (Andy, device check 3).
      - The walk is drawn as if on the page: the list's scroll since it set off (`onScrollGeometryChange`) shifts it, and the cards with it, so a scroll carries it along with the cards.
      - A run, or running off, sets off afresh from where it is on the screen at that moment.
    - **A run keeps to its side, at three times the walk** (Andy, device check 4).
      - A tap sent the earwig under the card it was on: at a run's pace nearly every card is quick to cross, so the 2-second rule put it under.
      - A run now keeps to the side of the cards it set off on: over them after a tap, and whichever side it was on when Preview sends it off.
      - Four times the walking pace seemed a little quick, so three times was tried. With the tap fixed, Andy asked for four again, and four stays.
    - **The splash, half as long again** (Andy, at the same check): 0.375 s in, 0.6 s held, 0.45 s out, 1.425 s in all, against plan 007's 0.95 s. The first critter now waits two seconds after a screen appears, so it never comes under the splash.
      - **Footer:** "Critter is just a bit of fun."
      - **Not in the README** (Andy).
      - Nothing is left to remove before a release.

11. **Simulator flag.** `-EarwigVisits YES` (Debug builds) makes every screen appearance a visit, ignoring the slider and the rest, so the walk can be seen and screenshotted without waiting. *Amended: the flag is now `-EarwigCritter YES`, and the first visit comes two seconds after a screen appears, then every 30 s.*

## Files

As built, after device check 2 (the drafted list named `Views/Visitor/` and `Services/` files, since merged here):

- `Earwig/Critter/Critter.swift`, `Earwig/Critter/CritterWalk.swift` (new) and `Earwig/Critter/CritterGeometry.swift` (new, generated).
- `scripts/app_icon/make_app_icon.py` (edited: writes the Swift geometry).
- `Earwig/Views/Scripts/ScriptsView.swift`, `Earwig/Views/ScriptDetail/ScriptDetailView.swift`, `Earwig/Views/Settings/SettingsView.swift` (edited: a line or two each).
- `EarwigTests/CritterTests.swift` (new).
- `PRD.md`, `CLAUDE.md`, `progress.md`, this plan.

## Steps

1. **Geometry.** The script writes `EarwigGeometry.swift`. Two runs are byte-identical, and the icon and mark PNGs don't change. `xcodegen generate` for the new folder.
2. **The figure and the gait.** `EarwigFigure` and `Gait`, checked in a SwiftUI preview walking on the spot and along a line. Screenshots from the simulator go to Andy for a first look at the gait before anything else is built on it.
3. **Paths and running away.** `VisitPath`, with tests: it starts and ends off screen, faces the way it goes, its legs are still during a pause, and it doesn't pause under the bars. A run starts from the current place and leaves by the nearest edge.
4. **Schedule and keep-away.** `VisitSchedule` and `EarwigVisits`, with tests: the chance, the rest, Every Visit ignoring the rest, Never never visiting, and each keep-away condition.
5. **On the screens.** The modifier on Scripts, Script and Settings, with the layers behind and in front and tap-through checked in the simulator with `-EarwigVisits YES`. Also checked there: a take started mid-walk removes it, and Listen and Preview keep it away.
6. **The slider.** Earwig Visits in Diagnostics; Critter in the Screen group since device check 2.
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
- Simulator, with `-EarwigCritter YES` (drafted as `-EarwigVisits YES`): a walk on each of the three screens, behind and in front; rows still open and swipe under the earwig in front; a take, Listen and Preview keep it away.
- On the iPhone 14 Pro, Andy's verdicts:
  1. **The walk.** The gait, size and speed read as an earwig walking, not sliding or swimming.
  2. **Behind.** It shows in the gaps and disappears cleanly under the cards, and never stays hidden more than about 2 s (amended).
  3. **In front.** It walks over the cards under the navigation bar, and the list under it still scrolls and opens.
  4. **The tap.** It runs from your finger, fast, off the nearest edge, and the tap opens nothing.
  5. **Keeping away.** With Every Visit, start a take mid-walk: it is gone, and the take behaves as usual. Open Listen and play Preview: no earwig. Turn on Reduce Motion: no earwig.
  6. **Smoothness.** No hitch while scrolling the list during a walk.
  7. **How often.** After about a week of TestFlight use at a chosen setting, Andy picks the rate. Critter's default is set from this.

## Results

Built 2026-11-09 and checked on the iPhone 14 Pro on 2026-11-10. **PASS** on checks 1 to 6, with Andy's changes along the way (Context, "at device check 2", and the amended decisions). Check 7, the default rate, waits for a week of TestFlight use.

**What was built**
- The critter: the mark, drawn from the icon script's geometry, with a two-set gait and twitching antennae.
- Each walk is at its own pace (65 to 120 pt/s) and moves with the list's scroll. It goes under a card only if out within 2 s, and over it otherwise.
- A tap sends it running off over the cards at four times its pace.
- The Critter setting (Never to All the Time, default Sometimes) is in the Screen group.
- A roll a moment after a screen appears and every 30 s while it stays, with a 3-minute rest between visits.
- It keeps away during a take, Listen, Preview and Reduce Motion, and none comes under the splash.
- Kept to `Earwig/Critter/`: `Critter.swift`, `CritterWalk.swift`, and `CritterGeometry.swift`, which the icon script generates. Tests are in `EarwigTests/CritterTests.swift`. `EarwigApp` is unchanged.
- Beside it, at Andy's request, the splash is half as long again: 1.425 s.

**Simulator**
- Walks behind and in front.
- A tap on a row passes through an earwig in front.
- Five cards reported on the Scripts screen.
- The list's scroll reaches the critter.
- The icon script's outputs are byte-identical, and the icon PNGs unchanged.
- 400 tests pass, SwiftLint clean, no warnings.

**Device (iPhone 14 Pro), Andy's verdicts**
1. **The walk:** passed ("Walk looks right"). 29 visits logged in 3½ minutes, 4 to 14 s each.
2. **Under and over:** the first build hid it under big cards for too long. Andy asked for:
   - under a card only if out quickly (first 1 s, then 2 s);
   - Critter as a setting for everyone, not in the README, its footer "just a bit of fun";
   - a chance while staying on a screen;
   - the feature in as few files as possible;
   - each walk at its own pace;
   - Never for the first step.
   After these, passed ("Looks pretty good").
3. **Over the cards and the scroll:** Andy asked for the critter to move with the scroll and for a longer splash. After both, the scroll passed ("works well"). He judged the splash himself.
4. **The tap:** a tap sent it under the card it was on, and the run seemed quick. A run now keeps to its side. Three times the walk was tried, and Andy asked for four again. Passed ("seems okay").
5. **Keeping away:** passed for a take, Listen, Preview and Reduce Motion.
6. **Smoothness:** passed ("Smooth").
7. **How often:** not yet. The default (Sometimes) and the rates are for Andy to judge after about a week of TestFlight use; a follow-up.

**How often, for reference (staying on one screen)**

| Setting | One about every |
|---|---|
| Rarely | 27 min |
| Now and Then | 12–13 min |
| Sometimes | 7½ min |
| Often | 5 min |
| Very Often | 3½ min |
| All the Time | 30 s |

**Review pass:** recorded below with its Outcome. C1 (a pending visit read stale keep-away and Reduce Motion) and the test findings were fixed. C2 is this section.

## Review pass — 2026-11-09

Findings from `/review-branch` on branch `earwig-visits`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact, and each verdict under *Assessment* is a
recommendation, not a decision. Work through them and annotate each with what was done — fixed,
or rejected and why. A finding that turns out to be wrong should say so here rather than be
deleted.

### Code

**C1. WARNING: the keep-away check after the start delay reads an old value, so a walk can begin during Listen, Preview or a take.**
- **Where:** `Earwig/Views/Visitor/EarwigVisitorLayer.swift`, lines 848 and 886–901.
- **What happens:** `.task { await visit() }` runs once, when the screen appears. It captures the modifier struct, and `keepAway` is a plain `let`. After the 2–6 s sleep, `guard !keepAway` still sees the value from when the screen appeared, not the current one. `reduceMotion` is the same: it's an `@Environment` value copied into that struct.
- **Effect:**
  - Open Settings and tap Preview within 2–6 s: a walk starts while Preview plays. That breaks decision 9.
  - Open Listen within that window on the Script screen: a walk starts under the sheet. The plan says the Script screen's visit is removed while the sheet is up.
  - Tap Start within that window: a walk may start as the take begins. That depends on whether the fullScreenCover fires `onDisappear` and cancels the task.
- **Why the existing handler misses it:** `onChange(of: keepAway)` only acts on a walk already under way. A visit that is still pending is not touched.
- **Fix:** have the pending visit read the live value. Options:
  - mirror `keepAway` into `@State`;
  - restart the task with `.task(id: keepAway)`;
  - cancel the pending visit from the `onChange`.

**C2. WARNING: the plan's finish items are not done yet.**
- **Where:** `plans/014-earwig-visits.md` (Results, line 175), `PRD.md`, `CLAUDE.md`.
- Results is still "_To be filled in_".
- The PRD has no version bump, no Document History row and no §10 *Earwig visits* paragraph.
- CLAUDE.md's Status doesn't mention plan 014. Decision 10 asks for a line saying the temporary Earwig Visits slider must be removed before the next App Store build.
- These are the plan's step 8 and its decision 10, so they have to land before the PR.

**C3. SUGGESTION: the `-EarwigVisits YES` simulator flag isn't documented in CLAUDE.md.**
- **Where:** `CLAUDE.md` Build Commands; the flag is read in `Earwig/Services/EarwigVisits.swift`, lines 79–82.
- Every other Debug launch flag is listed there, so this one should be too.

**C4. SUGGESTION: the cuts' geometry is written twice in the icon script.**
- **Where:** `scripts/app_icon/make_app_icon.py`, lines 261–267, which repeat `cut_lines()` at lines 83–90.
- `swift_geometry()` redoes the taper (`inset = 0.1 * (y - 450)`, the 456/568 ends) and the wing split's endpoints.
- If the mark's cuts change in `cut_lines()`, the walking earwig drifts from the icon. That breaks decision 1's single source. Both writers should take the endpoints from one helper.

Nothing looks likely to break the build:
- the referenced symbols exist (`SplashTiming.total`, `Log.event`);
- `line_length` is disabled, so the long generated lines are fine;
- `EarwigTests` is outside SwiftLint.

I checked the gait's alternating sets of three, including the mirrored right side, and the heading convention against `rotationEffect`; both are correct.

### Tests

**T1. WARNING: `aRunTurnsTheShortWayToFaceItsRoute` never checks the turn itself.**
- File: EarwigTests/EarwigVisitsTests.swift:124-130.
- It samples at `WalkPlanner.runTurn`. That is the moment the turn ends: `elapsed < turning` is false at Earwig/Services/EarwigWalk.swift:159, so `place` takes the walking branch and returns `path.heading(at: 0)`. The test only shows that the route's first heading points away from the tap.
- The eased turn on the spot (EarwigWalk.swift:159-165) is never sampled mid-turn. Only elapsed 0 is touched, in `aTapSendsItAwayFromTheFinger`.
- That test's "it turns on the spot first" (line 112) also passes without any turn, because `path.start == here` either way.
- Fix: one sample at `start + runTurn / 2`, from a heading about π away from the route. Expect the position to equal `here` and the heading to lie between `turn.from` and the target the short way round. That covers the turn and lets lines 111-112 shrink to the `stepped` check.

**T2. WARNING: the keep-away rules (plan decision 9, step 4) have no unit tests.**
- File: Earwig/Views/Visitor/EarwigVisitorLayer.swift:79-127.
- Plan step 4 asks for tests of "each keep-away condition". They live only in the private SwiftUI modifier:
  - the `keepAway` and Reduce Motion guards in `visit()`;
  - `leave(.vanishes)` calling `visits.ended(at:)`;
  - `leave(.runsOff)` running straight on from the heading and extending the visit via `ran`, with no `ended`;
  - an existing run left alone.
- These were checked in the simulator only.
- Option 1: move the leave decision into `EarwigVisits` or `WalkPlanner` as a small pure function (current walk, how, time → new walk or nil), with two short tests.
- Option 2: if it stays view-only, note in the plan's Results that it was simulator-verified rather than unit-tested.
- Either way, a test of `planner.run(from:awayFrom:)` with the tap just behind the heading would pin down Preview's "runs off straight on" route.

**T3. SUGGESTION: decision 7's "a tap never counts as a visit ending early for the rest" is not asserted.**
- File: EarwigTests/EarwigVisitsTests.swift:241-248.
- `aRunKeepsTheAppBusyUntilItsEnd` should also `#expect(visits.lastVisit == 10)` after `ran`, so a later change cannot reset the rest from a run.
- `aWalkTakenAwayFreesTheApp` (233-239) could likewise assert that `lastVisit` survives `ended(at:)`.
- That is one line each.

**T4. SUGGESTION: fold the three 40-seed tests into one.**
- File: EarwigTests/EarwigVisitsTests.swift:50-76.
- `aVisitStartsAndEndsOffScreen`, `aVisitTakesSecondsNotMinutes` and `pausesAreWhereItCanBeSeen` each build the same seeded walks. They differ only by layer, which the planner ignores.
- One `@Test(arguments: 0..<40)` that checks the ends, the duration and the pauses gives the same coverage with 40 cases instead of 120.

**T5. SUGGESTION: the duration bound is too loose to guard decision 3.**
- File: EarwigTests/EarwigVisitsTests.swift:64.
- `2 < duration < 20` would still pass at the old 60 pt/s, whose up-to-17 s crossings were the reason the speed was raised.
- A bound nearer the plan's figure (for example under 15 s, allowing for turn-back walks) would catch that regression.
- While there, assert that walks entering at the top or the foot leave at a side (decision 4), the one path rule left untested.

**T6. SUGGESTION: a few checks are tautological and could go.**
- `theSwingStaysSmall` (152-158): `swing * sin(...)` is bounded by `swing` by construction, and the antennae's fixed amplitudes (at most 0.14) are always under 0.2. Line 142 of `theTwoSetsOfThreeSwingOpposite` already pins the swing amplitude.
- `theDelayIsAMomentAfterTheScreenOpens` (204-206): the loop re-tests that `Double.random(in:)` stays in its range. Only the `.everyVisit` line (207) and the splash comparison (208) carry weight.
- Line 106 restates two constants multiplied together.

**T7. SUGGESTION: the Debug `-EarwigVisits YES` override is untested.**
- Source: `VisitFrequency.current` at Earwig/Services/EarwigVisits.swift:45-47.
- The keys differ only in case (`EarwigVisits` against `earwigVisits`), which is easy to break.
- Fix: add one line to `theSettingIsReadBackAndDefaultsToOneInTen` (EarwigVisitsTests.swift:190-200): `defaults.set(true, forKey: "EarwigVisits")` → `.everyVisit`.

Not flagged: `EarwigFigure`, `EarwigGeometry` (generated), the Settings slider binding, and the one-line `.earwigVisits` call sites. These are drawing code or trivial pass-throughs.

### Assessment

- C1 — FIX: real. `visit()` runs in the task started on appear and reads the modifier's `let keepAway` and its copied `reduceMotion` from that moment (`EarwigVisitorLayer.swift:81`, `:88`). Mirror both into `@State` (set with `onChange(…, initial: true)`), which the pending task reads live.
- C2 — SKIP: these are the plan's step 8, done at completion before the PR as `/plan_autopilot` orders it. Nothing is missing yet.
- C3 — FIX: add `-EarwigVisits YES` to CLAUDE.md's list of Debug flags.
- C4 — FIX: one helper gives the cuts' endpoints, and both `cut_lines()` and `swift_geometry()` use it.
- T1 — FIX: sample the run halfway through its turn, from a heading opposite the route, and check that it stays put and turns the short way.
- T2 — FIX (part): move the leaving decision into a small pure function in `EarwigWalk.swift` (the walk, how it leaves, the time → the walk that follows or nil), with tests for vanishing, running off straight on, and a run left alone. The `keepAway` and Reduce Motion guards stay in the view and are checked on the device.
- T3 — FIX: assert that `lastVisit` survives `ran` and `ended(at:)`.
- T4 — FIX: fold the three seeded tests into one.
- T5 — FIX: a bound of 15 s, and a check that a walk in at the top or the foot leaves at a side.
- T6 — FIX: drop `theSwingStaysSmall`, the random-range loop and line 106's restated constants.
- T7 — FIX: one line for the Debug override.

### Outcome — 2026-11-09

- C1 — fixed: `keepAway` and Reduce Motion are mirrored into `@State` (`held`, set by `onChange(…, initial: true)`), which a visit waiting to begin reads after its delay.
- C2 — not done here: the plan's step 8, done at completion before the PR.
- C3 — fixed: `-EarwigVisits YES` is in CLAUDE.md's list of Debug flags.
- C4 — fixed: `cuts()` gives the cuts' ends and widths to both `cut_lines()` and `swift_geometry()`. The SVGs, the PNGs and the Swift are byte-identical to before.
- T1 — fixed: `aRunTurnsOnTheSpotTheShortWayRound` samples halfway through the turn from nearly opposite the route.
- T2 — fixed (part): the leaving decision is `WalkPlanner.leaving(_:_:at:)`, tested by `leavingAtOnceLeavesNothing` and `runningOffGoesStraightOn`. The guards that stop a visit beginning stay in the view, for the device check.
- T3 — fixed: `lastVisit` is asserted after `ended(at:)` and `ran`.
- T4 — fixed: one seeded test, `aVisitCrossesTheScreen`.
- T5 — fixed: the bound is 15 s, with a check that a walk in at the top or the foot leaves at a side. That check found a walk in at the top that turned back and took over 15 s. Turning back is now only for walks that come in at a side (decision 4 updated).
- T6 — fixed: `theSwingStaysSmall`, the random-range loop and the restated speed are gone.
- T7 — fixed: the Debug override is checked.
- M1 — found while checking T4: `EarwigVisitsTests.swift` had been added after the last `xcodegen generate`, so the first two test runs (372 tests) did not include it. Regenerated, all 395 tests pass, the earwig suites among them.

## Review pass — 2026-11-10

Findings from `/review-branch` on branch `earwig-visits`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact, and each verdict under *Assessment* is a
recommendation, not a decision. Work through them and annotate each with what was done — fixed,
or rejected and why. A finding that turns out to be wrong should say so here rather than be
deleted.

### Code

**Summary:** I found no CRITICAL or WARNING issues. The amended requirements are met by the code as it stands:
- **Under or over:** a walk goes under a card only if it is out within 2 s, judged at its head, middle and tail; rows that touch count as one card.
- **Settings:** the Critter slider runs Never to All the Time, defaults to Sometimes, and its footer is "Critter is just a bit of fun."
- **How often:** the first roll comes 2–6 s after a screen appears, then every 30 s while it stays. There are 3 minutes between visits, except at All the Time.
- **Pace and the tap:** each walk has its own pace (65–120 pt/s). A tap sends it running over the cards at 4× that pace.
- **Scroll:** the walk moves with the list's scroll.
- **Keeping away:** it stays away during a take (`model.take`), Listen (`model.preview`), Preview (`preview.isPlaying`, where it runs off), Reduce Motion and the splash (2 s against 1.425 s). The Scripts screen keeps away while Settings is up. The Listening Check is pushed, so the critter's visits on Settings stop while it is open.
- **Layout and docs:** the code is kept to `Earwig/Critter/`, `EarwigApp` is untouched, and the flag is documented as `-EarwigCritter YES`.
- **Earlier review:** the 2026-11-09 C1 fix (the `held` mirror read by the waiting visit) is in place.

Coordinate checks:
- The drift and origin arithmetic in `cardFrames`, `run(awayFrom:)` and `leave` is consistent.
- The tap location and the walk positions use the same layer space.
- The icon script's `cuts()` helper feeds both the SVG and the Swift writers.

C1. SUGGESTION: the plan still names the old Debug flag in its decision and test text. The app and CLAUDE.md use `-EarwigCritter YES`.
- `plans/014-earwig-visits.md`, line 170 (decision 11) and lines 188 and 203 (Steps and Verification), still say `-EarwigVisits YES`. Line 137 still names an `EarwigVisits` type.
- The Context on line 46 records the rename, but decision 11 has no "amended" note, so anyone reading the decision or the Verification list would use a flag that does nothing.

C2. SUGGESTION: a stale doc comment on `SettingRow`.
- `Earwig/Critter/Critter.swift`, lines 338–339, says "Off to All the Time".
- Andy renamed the first step Never at device check 2, and `Frequency.title` says "Never".

C3. SUGGESTION: two tests make the same splash assertion.
- `EarwigTests/CritterTests.swift`, line 266 (in `everyVisitComesSoonButNeverUnderTheSplash`) and line 277 (in `noVisitUnderTheSplash`), both expect `testingDelay > SplashTiming.total`.
- Dropping it from the first test leaves that test about `.everyVisit`'s delay only.

C4. SUGGESTION: the crossing-time bound is back to 20 s, though the plan's Outcome T5 says 15 s.
- `EarwigTests/CritterTests.swift`, line 60, bounds the crossing at `< 20` s.
- That looks deliberate, since the slowest pace is now 65 pt/s and the message says "even at the slowest pace". But it no longer matches what the Outcome records.
- Either note the change in the plan, or tighten the bound to what the 65 pt/s worst case actually needs.

Build integrity: nothing looks likely to break the build.
- The referenced symbols exist (`EarwigTheme.text`, `SplashTiming.total`, `Log.event`, `VoicePreview.isPlaying`, `ScriptDetailViewModel.preview` and `.take`).
- `vertical_whitespace` and `line_length` are disabled in `.swiftlint.yml`, so the double blank line at `CritterWalk.swift` lines 295–296 and the long generated lines are fine.
- `EarwigTests` is excluded from SwiftLint.

### Tests

I found one coverage gap worth fixing (T1). The rest are small simplifications. The earlier review's T1 to T7 fixes are all still in place, though the duration bound from the old T5 has since been loosened (see T3).

Scope: the only test changes on the branch are `EarwigTests/CritterTests.swift` (new, 303 lines) and a one-test edit to `EarwigTests/LaunchSplashTests.swift`. Nothing is staged, unstaged or untracked under `EarwigTests/`.

**T1. WARNING: the scroll drift and the side kept when a walk leaves have a pure seam but are never tested.**
- `Planner.leaving(_:_:at:drift:side:)` (`Earwig/Critter/CritterWalk.swift:343-349`) takes `drift` (from device check 3, the scroll) and `side` (from device check 4: a run keeps to its side of the cards).
- Its only tests, `leavingAtOnceLeavesNothing` and `runningOffGoesStraightOn` (`EarwigTests/CritterTests.swift:185-197`), always use the defaults (`drift: 0`, `side: .inFront`). `drift` and `side` appear nowhere else in the tests.
- So nothing checks that Preview's run-off starts where the list has scrolled the earwig to, or that an earwig under a card stays under when it runs off.
- Fix: in `runningOffGoesStraightOn`, call `leaving(walk, .runsOff, at: 2, drift: 50, side: .behind)` and expect two things:
  - `run.path.start.y` is about 350;
  - `run.layer(at: 0, cards: []) == .behind`.
- The tap path's `place.position.y -= cards.drift` and the side chosen in `leave()` (`Earwig/Critter/Critter.swift:281` and `:292`) are inside the private view. They could only be device-checked unless that small calculation moved into the planner.

**T2. SUGGESTION: the splash test now pins the constant and no longer states a rule.**
- `theSplashIsBrief` (`EarwigTests/LaunchSplashTests.swift:33-36`) expects `SplashTiming.total` to equal 1.425 exactly. That is just appear + hold + fade, so any retune breaks it without anything regressing.
- The rule that matters to this branch, no visit under the splash, is already covered by `noVisitUnderTheSplash`.
- Fix: test a bound that says what "brief" means (for example under 1.5 s), or drop the test.
- Separately, CLAUDE.md's Status still says the splash finishes "in under a second", which is now out of date.

**T3. SUGGESTION: the duration bound is now as loose as it was before the earlier review's T5.**
- The Outcome records that T5 was fixed with a 15 s bound. `aVisitCrossesTheScreen` is back to `duration > 2 && duration < 20` (`EarwigTests/CritterTests.swift:60`), presumably for the slowest pace in the new `walkingSpeeds` (65 to 120).
- If 20 s is really needed at 65 pt/s, say so in the plan's Results. Otherwise tighten it, so a crossing that slows down again still fails.

**T4. SUGGESTION: the splash comparison is asserted twice.**
- `Critter.Schedule.testingDelay > SplashTiming.total` is in both `everyVisitComesSoonButNeverUnderTheSplash` (line 266) and `noVisitUnderTheSplash` (line 277).
- Keep it only in `noVisitUnderTheSplash`, and rename the first test to match what is left.

**T5. SUGGESTION: the same test routes are built five times over.**
- The straight 300 pt route appears at lines 34, 82 and 270 (the last as the private `walk(at:)` in `CritterScheduleTests`).
- The y-400 crossing route appears at line 73 (`itFacesAlongItsRoute`) and again in `walkAcross(at:)` at line 140.
- One file-level helper for each would remove the copies, and `itFacesAlongItsRoute` could use `walkAcross(at: 0)` as it is.

**T6. SUGGESTION: one check is true by construction.**
- In `theStepsRunFromNeverToEveryVisit` (`EarwigTests/CritterTests.swift:246`), the rawValue check can only hold for an `Int` enum with implicit raw values.
- Keep the first/last and sorted checks on `chance`, and drop line 246.

The volume of tests suits about 570 lines of pure planning logic. Most tests are short and each covers one plan decision. I left out drawing code (`Figure`, `CritterGeometry`), the Settings slider binding and the one-line modifier call sites, which are trivial or visual. I did not run the test suite.

### Assessment

- C1 — FIX: add an amended note to decision 11 and to decision 9's `EarwigVisits`, and give the Verification line the new flag. The Steps are left as the record of what was planned.
- C2 — FIX: the comment says Never to All the Time.
- C3 — FIX: the same as T4; it is fixed once.
- C4 — FIX (part): keep 20 s, which is what the slowest pace needs (the 15 s bound at 90 pt/s scales to about 20.8 s at 65), and record why in this pass's Outcome.
- T1 — FIX: `runningOffGoesStraightOn` also leaves with `drift: 50, side: .behind` and checks where the run starts and the side it keeps.
- T2 — FIX (part): `theSplashIsBrief` bounds the splash at under 1.5 s rather than pinning 1.425. NOT REAL for its CLAUDE.md note: CLAUDE.md's Status says "1.425 s since plan 014", and "under a second" is in neither CLAUDE.md nor the PRD.
- T3 — as C4.
- T4 — FIX: the splash comparison stays only in `noVisitUnderTheSplash`, and the other test becomes `everyVisitComesSoon`.
- T5 — FIX: one file-level helper for each route.
- T6 — FIX: drop the rawValue check.

### Outcome — 2026-11-10

- C1 — fixed: decisions 9 and 11 carry amended notes (`Critter.Visits.shared`; `-EarwigCritter YES`, two seconds, then every 30 s), and the Verification line names the new flag. The Steps stay as the record of what was planned.
- C2 — fixed: `SettingRow`'s comment says Never to All the Time.
- C3 — fixed with T4.
- C4 — kept at 20 s: at the slowest pace, 65 pt/s, the 15 s bound set at 90 pt/s scales to about 20.8 s, and 40 seeded walks all finish within 20 s. A crossing that slows down again still fails.
- T1 — fixed: `runningOffGoesStraightOn` also leaves with `drift: 50, side: .behind` and checks that the run starts at y 350 and stays under the cards.
- T2 — fixed (part): `theSplashIsBrief` checks the splash is over a second and under 1.5 s. Its CLAUDE.md note was not real: CLAUDE.md says "1.425 s since plan 014".
- T3 — as C4.
- T4 — fixed: the splash comparison is only in `noVisitUnderTheSplash`; the other test is `everyVisitComesSoon`.
- T5 — fixed: `straightRoute()` and `walkAcross(at:)` are file-level helpers, used by every test that had its own copy.
- T6 — fixed: the rawValue check is gone.
- 400 tests pass, SwiftLint clean.
