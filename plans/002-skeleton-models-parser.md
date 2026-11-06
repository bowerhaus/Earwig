# Plan 002: Skeleton, Models and Parser

**GitHub Issue:** [#3](https://github.com/bowerhaus/Earwig/issues/3) (PR must include "Closes #3")
**Branch:** `skeleton-models-parser` (from `main` at `6d2b848`, after plan 001 merged)
**Manual test:** device (iPhone 14 Pro: paste a real Cutaway script by Universal Clipboard, step 7), after Andy's palette pick in the simulator (step 6)
**Goal:** Put a script into Earwig and see it as Earwig will follow it. Paste a Cutaway `script.md` or plain text; it is parsed into steps, lines, directions and phrases, stored in SwiftData, listed on the Scripts screen and shown step by step on the Script screen. Every later stage reads its script from here, so the script words and phrase indices this stage stores are the ones the follow engine (stage 3) and the renderer (stage 4) will use.

**PRD references:** §3 Core Concepts, §4.1 Scripts, §5.1 Inputs (script words), §6.1 Entities, §7 Architecture, §8.1 Scripts, §8.2 Script, §10 Design Language, §12 stage 2.

---

## Scope

**In:** the Cutaway and plain-text parsers with tests; script words (numbers as one word); the phrase list per step; the SwiftData models of §6.1 (Script, Step, Rendering, Take) and the container; paste import with re-paste and delete; `EarwigTheme` filled out; the Scripts and Script screens; a sample script.

**Out:** rendering and its status beyond a placeholder (stage 4), the follow engine and the matcher's folding of compounds, contractions and spellings (stage 3), takes being made and the Prompt screen (stage 5), Settings and its `UserDefaults` wrapper (stage 7), share sheet and Files import (P1).

## Design decisions

1. **The parsers follow Cutaway's own** (`pipeline/script.py`, `docs/file-contracts.md` in Cutaway), but leniently: Cutaway rejects a misnumbered script, Earwig shows it. Title `# Script: X` (the `Script:` prefix optional); steps `## N. Title`; fields `Shows:`, `Footage:`, `Says:`, `Open:`, case-insensitive and with or without `**` bold; `Says:` items start `- `, `* ` or `+ `; an indented line runs on to the field or item before it; a source span in round brackets at the end of a line, `(0005 28.2-41.0)`, is stripped. An old `Notes:` field and any line not understood are kept as directions. `Says: nothing` or `Says: none yet` means no lines. Text before the first step is kept as the script's preamble and shown, never spoken. A heading with no number is still a step, numbered by its place.
2. **Format detection.** Cutaway when the text has at least one `## ` heading and at least one `Says:` field; plain otherwise. The detected format is stored and shown.
3. **Plain text.** Blocks separated by blank lines are steps; with no blank lines the whole text is one step. A block's first line is the step's title when it has at most eight words and no sentence-ending punctuation; otherwise the step is untitled ("Step 2"). Every other non-empty line of a block is a line, with a leading `- `, `* ` or `+ ` dropped. A leading `# ` line is the script's title; without one the title is the first line, cut to 40 characters at a word.
4. **Directions inside a line are square-bracketed**: `[Gesture to the boats]` anywhere in a line, in both formats, is a direction at that point and never a script word. Round brackets are spoken text (a parenthesis in prose is usually said), except a Cutaway source span at the end of a line. PRD §4.1 says only "bracketed"; this pins it.
5. **Script words, with a number as one word** (PRD §5.1, plan 001 finding 4). Each written word of a line is one script word with a normalised form: lower case, diacritics and punctuation stripped, apostrophes dropped (`there's` is `theres`, one word). A number is one script word with its value: written in digits (`1890`, `1,500`, `4`, `21st`), or as a run of number words (`three hundred`, `twenty one`, `one hundred and fifty`, `eighteen ninety`). A run has at most one reading, as Cutaway's: cardinal composition (`hundred`, `thousand`, an `and` after them), and two pairs of tens as a year (`eighteen ninety` is 1890, `nineteen oh five` is 1905). This replaces today's expansion of `120` into four words, which would make a year use up the lead. **Compounds, contractions and British and American spellings are not folded here**: `sea wall` stays two script words and `there's` one, and the matcher folds them against what is heard both ways in stage 3, where the heard side is known. `WordNormaliser` keeps the shared rules; the grouping of number runs is new code beside it in `Engine/`.
6. **Phrases are derived at parse time and stored** as a `PhraseList` JSON value on each step (PRD §6.1), so indices are stable. Each phrase knows its line and its kind: **spoken** (with its script words) or **cue** (an inline bracketed direction, read later in the cue voice, never matched). A line `- [Gesture to the boats] Most of these boats…` gives a cue phrase then the spoken phrases. Step-start cues (number, title, `Shows:`) are not stored as phrases; the Slater builds them from the step's fields in stage 5. `PhraseList` carries a **parser version**: when the app's parser is newer than a stored list (stage 3 may change the splitting or the script words), the step is re-derived from the script's stored source text on open. So no migration is needed when the rules change.
7. **`PhraseToken` and `Phrase` become Codable** and keep the API the renderer uses (`text`, `tokens`, each token's UTF-16 `range`). A token gains its script word (normalised form, number value) in place of `normalised: [String]`. A multi-word number like `three hundred` is one token spanning both words, so a word marker inside it maps to it.
8. **Hash and re-paste** (PRD §3, §4.1, Flow 4). The hash is SHA-256 (CryptoKit) of the source text with line endings made `\n` and trailing whitespace trimmed per line. Paste on the Scripts screen: the same hash as a stored script opens that script and changes nothing; the same title as a stored script (case-insensitive) replaces its text, steps and format and keeps its takes, `lastStep` (clamped) and cues setting; otherwise a new script. The Script screen also has **Paste new version** for a script whose title changed. Renderings are kept on replace; re-using them per unchanged phrase is stage 4's (a phrase is identified by its text and voice, not its index).
9. **Paste with SwiftUI's `PasteButton`**, not `UIPasteboard`: it reads the clipboard without the "Allow Paste" prompt every time, which matters for Universal Clipboard from the Mac. Text only. A paste with no steps or no words shows an error and stores nothing.
10. **Models as PRD §6.1 and the siblings' conventions:** every relationship optional with an inverse, a default on every stored property, no `@Attribute(.unique)`, enums as raw strings (`formatRaw`, `outcomeRaw`) with typed accessors, Codable values as JSON `Data` behind typed accessors through one `ModelJSON` encoder (PhysiMate's), `sortOrder` on `Step` with an `orderedSteps` accessor. Steps, takes and renderings cascade on deleting a script. `Rendering` and `Take` are created now, unused until stages 4 and 5, so they arrive without a migration. Takes reference a step by index, not by relationship, so a re-paste that rebuilds the steps keeps them.
11. **One distinctive theme, not necessarily dark** (Andy, at review). Earwig has its own look rather than the system's: one palette, the same whatever the phone's light or dark setting, with the app's colour scheme set to match the palette so system controls read on it. Not split into light and dark variants. `EarwigTheme` holds it: background, surface, primary and secondary text, accent (the voice's phrase), cue (directions and cues, a muted second colour distinct from secondary text), and warning, good and caution. It must stay high-contrast and large-type legible at arm's length (PRD §10). In step 6, two or three candidate palettes are shown on the Script screen as simulator screenshots and Andy picks one; the theme is one file, so it can change again on device. Views never define a colour (CLAUDE.md). PRD §10 is updated to say so.
12. **A sample script** (the made-up harbour walk from plan 001, `7cb9880`) is a test fixture and a **Try the sample** button on the empty Scripts screen, so the simulator and a fresh install have a script without a paste. The repo is public: fixtures are made up.
13. **The Script screen in this stage**: tapping a step selects it as the start step (stored as `lastStep`, ticked) because there is no take to start yet; the rendering row says "Not rendered" with the voice name; each step shows "No takes yet". A toolbar menu has the cues switch, Paste new version and Delete.

## Files

| File | Purpose |
|------|---------|
| `Models/Script.swift`, `Step.swift`, `Rendering.swift`, `Take.swift` | `@Model` entities per §6.1 |
| `Models/ScriptFormat.swift`, `TakeOutcome.swift`, `Direction.swift` | Enums and the direction value (kind: shows, footage, open, notes, unknown, inline; text) |
| `Models/PhraseList.swift` | Codable phrases per step with line index, kind and parser version |
| `Models/ModelJSON.swift` | The one JSON encoder and decoder for values in `Data` |
| `Engine/ScriptWords.swift` | Script words from a line's text: normalisation per word, number runs grouped with their value |
| `Engine/WordNormaliser.swift` | Changed: a number is one word with a value, no longer expanded |
| `Services/PhraseSplitter.swift` | Changed: Codable `Phrase` and `PhraseToken`, tokens from `ScriptWords` |
| `Services/ScriptParser.swift` | Format detection, `CutawayParser`, `PlainParser`; text to a `ParsedScript` value (pure Swift, Foundation only) |
| `Services/ScriptImporter.swift` | Parsed script into SwiftData: new, unchanged, replace; hash |
| `Services/ModelContainerFactory.swift` | Schema, the persistent container, an in-memory one for tests and previews |
| `Services/SampleScript.swift` | The harbour walk |
| `App/EarwigApp.swift`, `App/EarwigTheme.swift` | Container, dark scheme, the Scripts screen as root; the palette |
| `ViewModels/ScriptsViewModel.swift`, `ScriptDetailViewModel.swift` | Import and delete; step selection and cues |
| `Views/Scripts/ScriptsView.swift` | §8.1: list (title, steps, last take), `PasteButton`, swipe to delete, empty state with Try the sample |
| `Views/ScriptDetail/ScriptDetailView.swift`, `StepView.swift` | §8.2: steps with lines, inline cues and directions in the cue colour, rendering row, step selection |
| `EarwigTests/` | `CutawayParserTests`, `PlainParserTests`, `ScriptWordsTests`, `PhraseListTests`, `ScriptImporterTests`, `ModelTests`; `Fixtures.swift` with made-up scripts |

## Steps

1. **Script words.** `ScriptWords` and the `WordNormaliser` change, with tests: digits, commas and ordinals; number-word runs and the year reading; `and` only inside a number; a number next to a unit (`4 miles` is two words); apostrophes and punctuation; bracketed directions skipped. Update `WordNormaliserTests` and `PhraseSplitterTests` for numbers as one word. The renderer's marker mapping still works (its test passes).
2. **Parsers.** `ParsedScript`, format detection, `CutawayParser`, `PlainParser`, with tests from fixtures: the harbour walk (3 steps, titles, `Shows:`, 13 lines, the inline `[Gesture to the boats]` cue); Cutaway's own Rosie example (`Footage:`, a source span stripped, `Open:`); `# Script:` prefix and none; bold fields; `*` and `+` items; run-on indented lines in `Says:` and `Shows:`; `Notes:` and an unknown line kept as directions; `Says: nothing`; preamble; an unnumbered and a misnumbered heading; CRLF line endings. Plain: blocks, the title rule both ways, one block, no blank lines, bullets dropped, `# ` title, whitespace-only blocks ignored.
3. **Phrase list.** Phrases per step from the parsed lines with the splitter, cue phrases for inline directions, line indices; Codable round trip; the parser version and re-derivation when it is stale.
4. **Models and container.** The four entities, `ModelJSON`, `ModelContainerFactory`, wired into `EarwigApp`. Tests in an in-memory container: steps out of order come back in order; deleting a script cascades steps, takes and renderings; typed accessors persist.
5. **Import.** `ScriptImporter` with tests: a new paste; the same text again (also with CRLF and trailing spaces) opens the existing script and adds nothing; the same title with changed text replaces the steps and keeps takes and the cues setting and clamps `lastStep`; an empty or wordless paste is refused.
6. **Theme and screens.** The Scripts and Script screens and their view models, the sample. Two or three candidate palettes for `EarwigTheme` shown on the Script screen as simulator screenshots; Andy picks one (the one pause in this step). Checked in the simulator with screenshots: empty state, the sample, a pasted Cutaway and a pasted plain script, delete, Paste new version, landscape, and the phone in both light and dark settings looking the same.
7. **Device check.** Installed on Andy's iPhone 14 Pro over the plan 001 build with `devicectl`. Andy copies a real Cutaway `script.md` on the Mac and pastes it into Earwig on the phone by Universal Clipboard: it imports with no paste prompt, the steps read right, and a second paste of the same text does not duplicate it. His script stays on his phone; nothing of it is recorded here beyond counts and his verdict.
8. `swiftlint lint` clean, no build warnings, all tests pass; Results filled; PRD §4.1, §5.1, §6.1 and §10 updated where the decisions above pin them (square brackets, re-paste by title, number runs, parser version, the theme), as v0.4 with a Document History row; `progress.md` emptied to its stub.

## Verification

- `xcodebuild test` passes in the simulator; no warnings; SwiftLint clean (including `engine_purity` on `ScriptWords`).
- Simulator screenshots of the screens in step 6.
- The device check in step 7, recorded below from Andy's report.

## Review (2026-11-05)

Andy agreed decisions 4 (square brackets as the only inline directions), 8 (re-paste by title, plus Paste new version) and 5 (numbers as one script word here, compounds and contractions in stage 3). He did not want dark only: decision 11 is now one distinctive theme, not necessarily dark, with no separate light and dark variants.

## Results

To be filled in when the plan completes.

## Review pass — 2026-11-06

Findings from `/review-branch` on branch `skeleton-models-parser`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact, and each verdict under *Assessment* is a
recommendation, not a decision. Work through them and annotate each with what was done — fixed,
or rejected and why. A finding that turns out to be wrong should say so here rather than be
deleted.

### Code

Review of `skeleton-models-parser` against `main`. I read plan 002, CLAUDE.md, the committed diff and all new files. The working tree is clean, with no unstaged, staged or untracked changes. Overall the branch meets the plan's goals: both parsers, script words with a number as one word, a stored `PhraseList` with a parser version, the four models with cascade deletes, paste import with hash and title matching, the two screens, the sample, and a single theme. `Engine/ScriptWords.swift` imports only Foundation, and views use only `EarwigTheme` colours. Findings, most severe first:

**C1 — WARNING: number runs join across punctuation.** `ScriptWords.groups` normalises each token, which strips commas and full stops, and only then groups number words. Words the script separates with punctuation become one number. For example "aged fifteen, sixteen" gives 1516, "ten, twenty years" gives 1020, and "twenty, thirty, forty" gives 2030 then 40. A run is also built across a dash-only token (the empty groups are taken out before grouping), so "nineteen — twenty" gives 1920. The phrase splitter cuts at sentence ends but not at commas inside short sentences, so this reaches the stored phrases. The presenter will say these as separate numbers, so the stored words will not match what is heard in stage 3. A number run should end at a token whose written form ends in clause or sentence punctuation, or at a dash token.
- `Earwig/Engine/ScriptWords.swift` lines 47–76, together with `readYear` (lines 158–173) and `readCardinal` (lines 141–154).

**C2 — WARNING: deleting from the Script screen may crash.** "Delete Script" calls `model.delete(in:)`, which runs `context.delete(script)` and `save()`, and only then calls `dismiss()`. The detail view's body reads `script.title`, `script.orderedSteps`, `script.takes(forStep:)` and `script.preamble`, and it can be redrawn before the pop finishes. Reading a deleted, saved SwiftData model is a known crash source. The plan's step 6 list includes "delete" and "Paste new version", but `progress.md` records only the empty state, sample, light/dark, plain paste and landscape as checked. A safer order is to dismiss first and then delete, or to hand the delete back to the Scripts screen.
- `Earwig/Views/ScriptDetail/ScriptDetailView.swift` lines 66–69
- `Earwig/ViewModels/ScriptDetailViewModel.swift` lines 47–50

**C3 — WARNING: a paste with a derived title can replace an unrelated script.** `paste` replaces any stored script whose title matches the parsed title, ignoring case. That title is often derived rather than written:
- plain text uses its first line cut to 40 characters, or a lone short first block;
- Cutaway with no `#` title uses the first step's title, or "Untitled script".

So two different plain scripts that open with the same line, or two untitled Cutaway scripts, silently overwrite each other. The old script's takes are then attached by step index to unrelated steps. Decision 8 says "the same title", but this edge was not considered there. Matching by title only when the title was written explicitly would avoid it.
- `Earwig/Services/ScriptImporter.swift` lines 802–805
- `Earwig/Services/ScriptParser.swift` lines 1101–1103 and 1153 of the diff (`CutawayParser.parse` and `PlainParser.parse` title fallbacks)

**C4 — WARNING: stage requirements still outstanding.** Plan step 8 and the CLAUDE.md rules require PRD §4.1, §5.1, §6.1 and §10 to be updated as v0.4 with a Document History row. They also require a filled Results section and `progress.md` emptied to a stub. PRD.md is not touched on this branch, and the plan's Results still reads "To be filled in when the plan completes."
- `PRD.md`
- `plans/002-skeleton-models-parser.md` (Results)
- `progress.md`

**C5 — SUGGESTION: plain-text title rule differs from decision 3 and isn't recorded.** Commit 37cb44e makes a lone, short, unpunctuated first block the script title and drops it as a step. Decision 3 only allows a leading `# ` line or a first-line fallback. Side effect: a one-line spoken opening such as "Morning everyone" is silently dropped from what is said. Record this in the plan (or the PRD §4.1 update), or limit it.
- `Earwig/Services/ScriptParser.swift`, `PlainParser.parse` (the "A first block that is one short title-like line" branch, around line 1136 of the diff)

**C6 — SUGGESTION: Paste new version is not in the toolbar menu.** Decision 13 puts it in the menu with the cues switch and Delete. It is a `PasteButton` in a list section at the bottom instead. That is reasonable, since `PasteButton` does not sit well inside a `Menu`, but the plan should say so.
- `Earwig/Views/ScriptDetail/ScriptDetailView.swift` lines 43–55

**C7 — SUGGESTION: decimals and times read as whole numbers.** "2.5 miles" gives 25 and "9:30" gives 930, because the normaliser removes the separator before `digits()` reads the token. Before this branch these were plain words. Now they are wrong number values, which the stage 3 matcher would compare against.
- `Earwig/Engine/ScriptWords.swift` lines 95–103

**C8 — SUGGESTION: "Step N" fallback repeated.** `StepView` rebuilds the title fallback (`step.title.isEmpty ? "Step \(step.number)" : step.title`) that `Step.displayTitle` already has. A title-only accessor on `Step` would keep one source of truth. Separately, the paste-error alert binding and the empty-text guard are copied between the two view models and the two views.
- `Earwig/Views/ScriptDetail/StepView.swift` line 18
- `Earwig/Models/Step.swift` lines 44–46
- `Earwig/ViewModels/ScriptsViewModel.swift` lines 14–18 and `Earwig/ViewModels/ScriptDetailViewModel.swift` lines 34–38

Nothing in the diff looks likely to break the build. The removed `WordNormaliser.normaliseToken`, `spelledOut`, `normalisedWords` and `EarwigTheme.muted` have no remaining references. `force_try` is disabled in `.swiftlint.yml`, which covers the `try!` uses. I did not run tests, a build or the linter.

### Tests

I found no CRITICAL issues. The two WARNINGs below are the ones worth acting on; the SUGGESTIONs are small gaps and overlaps that would shrink the suite without losing coverage.

T1. WARNING: WordNormaliserTests now test a function nothing in the app calls, and its rule contradicts the one the app uses.
- The tests exercise `WordNormaliser.words(in:)`. On this branch no production code calls it; the only caller of `WordNormaliser` is `ScriptWords.groups`, which calls `normalise(_:)`.
- `splitsOnDashesAndSlashes` pins "well-known" as two words ("well", "known"). The production path reads it as one word, "wellknown" (ScriptWordsTests.swift:15-17, plan decision 5).
- `normalise(_:)` itself has no direct test.
- Fix: point these tests at `normalise(_:)` (folding, apostrophes, punctuation-only returns nil) and delete `words(in:)`, or delete the dash/slash test.
- EarwigTests/WordNormaliserTests.swift:6-32; Earwig/Engine/WordNormaliser.swift:12-16

T2. WARNING: Two parts of the re-paste-by-title rule (decision 8) have no test.
- Title matching is case-insensitive, but the test re-pastes with the identical title, so that branch never runs.
- The importer says a replace keeps renderings. The test is named "KeepsTakes" and checks only takes, cues and lastStep.
- Both fit into the existing test at little cost: lower-case the `# The Harbour Walk` line in `shorter`, attach a `Rendering`, and assert `script.renderings?.count == 1`.
- EarwigTests/ScriptImporterTests.swift:34-52; Earwig/Services/ScriptImporter.swift:41

T3. SUGGESTION: The view models have branching that no test reaches.
- `ScriptsViewModel.paste`: a nil or empty clipboard sets the error, a refused paste sets the error and stores nothing, a success sets `path`.
- `ScriptDetailViewModel.pasteNewVersion` picks between "already here" and "Updated" notices.
- One small test per view model would cover these.
- Earwig/ViewModels/ScriptsViewModel.swift:14-26; Earwig/ViewModels/ScriptDetailViewModel.swift:33-45

T4. SUGGESTION: No test covers a hyphenated token that reads as two numbers.
- `groupsMapBackToTheirTokens` covers only number runs that span several tokens.
- A single hyphenated token such as "one-two" or "nine-eleven" gives two groups with the same token range, so `Phrase` gets two tokens with identical text and range.
- A test would pin whether that is intended.
- EarwigTests/ScriptWordsTests.swift:62-66; Earwig/Engine/ScriptWords.swift:46-48

T5. SUGGESTION: Two parts of `refreshIfStale` are untested.
- It deliberately restores `updatedAt`, and it rebuilds when `steps` is empty. Neither is checked.
- One `#expect(script.updatedAt == before)` in the existing test would cover the first.
- EarwigTests/ScriptImporterTests.swift:75-83; Earwig/Services/ScriptImporter.swift:64-72

T6. SUGGESTION: The JSON round trip is tested three times.
- `PhraseSplitterTests.phrasesRoundTripThroughJSON`, `PhraseListTests.roundTripsThroughModelJSON` (a PhraseList contains Phrases) and `ModelTests.typedAccessorsPersist` all cover it.
- Keep the PhraseList equality test and the persistence test; drop the Phrase one.
- EarwigTests/PhraseSplitterTests.swift:79-83; EarwigTests/PhraseListTests.swift:38-41; EarwigTests/ModelTests.swift:43-71

T7. SUGGESTION: Several cases are tested in two files.
- "3pm": WordNormaliserTests.swift:30-32 and ScriptWordsTests.swift:27-29.
- "1,500": WordNormaliserTests.swift:26-28 and ScriptWordsTests.swift:21.
- "there's": both `plainWordsAreNormalisedOneEach` and `contractionsAndCompoundsAreNotSplitOrJoined` (ScriptWordsTests.swift:10-17), which could merge.
- `PhraseListTests.aYearIsOneScriptWord` (PhraseListTests.swift:31-36) re-checks that 1890 is one word, via its position in the sample script. `cueWordsAreNotScriptWords` already covers `PhraseList.scriptWords`.

T8. SUGGESTION: Two more tests repeat existing ones.
- `CutawayParserTests.titleWithoutThePrefix` (CutawayParserTests.swift:43-45) repeats the corners fixture, whose `# The Allotment` title is asserted at line 49.
- `ScriptImporterTests.hashIgnoresLineEndingsAndTrailingSpace` (ScriptImporterTests.swift:85-88) largely repeats `theSameTextAgainAddsNothing` (lines 25-32), which already pastes CRLF text with trailing spaces and expects `.unchanged`.

T9. SUGGESTION: Small gaps in the Script model and the Cutaway parser.
- `#expect(result.script.phraseCount > 13)` is a vague bound (ScriptImporterTests.swift:21). Assert the exact count or drop it.
- `Script.takes(forStep:)` (filter by step, newest first) and `lastTake` are used by the views but untested (Earwig/Models/Script.swift:46-50). A few lines in ModelTests would cover them.
- A Cutaway script with no `#` title takes its title from the first step or "Untitled script". That fallback is untested (Earwig/Services/ScriptParser.swift:216-218).

### Assessment

- C1 — FIX: real (`ScriptWords.groups` strips punctuation before reading runs, and drops dash tokens out of the run, `Earwig/Engine/ScriptWords.swift:45-66`). End a number run at a token whose written form ends in `, ; : . ! ? …` and at a token with no word.
- C2 — FIX: real ordering risk (`ScriptDetailView.swift:66-69`). Dismiss first, delete after, and guard the body against a deleted script.
- C3 — FIX: real. Match by title only when the script states its title (a `# ` line, or a plain script's lone title line); a title derived from a first line or a first step never replaces another script. A refinement of decision 8, not a new rule.
- C4 — NOT REAL: plan step 8 (PRD v0.4, Results, the progress stub) is the completion step and has not been reached yet; it is still on the checklist in `progress.md`.
- C5 — FIX (part): keep the rule (in the simulator check, a plain script's lone title line showed as Step 1 with the title as its only line); record it in the plan's Results and PRD §4.1.
- C6 — FIX (part): record in Results that Paste new version is a section on the Script screen because `PasteButton` does not work in a `Menu`. No code change.
- C7 — FIX: real (`ScriptWords.swift` `digits`). A token with a digit, a `.` or `:`, and a digit is a plain word, not a number.
- C8 — FIX (part): add `Step.heading` (title or "Step N"), used by `displayTitle` and `StepView`. The duplicated alert binding is two lines in two views: skip.
- T1 — FIX: `words(in:)` has no caller (only `normalise(_:)` is used, `ScriptWords.swift:46,49`). Delete it and point the tests at `normalise(_:)`; the number cases move out (T7).
- T2 — FIX: lower-case the title in the replace test and attach a rendering.
- T3 — SKIP: the view models only route to the importer, whose refusals and outcomes are tested; covered by the simulator checks.
- T4 — FIX: real (two groups with one token range). Split a hyphenated token into number pieces only when they read as one number ("twenty-one"); otherwise it is one word. Add the case to the tests.
- T5 — FIX (part): add the `updatedAt` check. The empty-steps branch is not reachable from an import (a script with no steps is refused): skip.
- T6 — FIX: drop `PhraseSplitterTests.phrasesRoundTripThroughJSON`.
- T7 — FIX (part): the "3pm" and "1,500" duplicates go with T1; merge the two "there's" tests. Keep `aYearIsOneScriptWord`: it is the one check that stored phrases carry a number as one word.
- T8 — FIX (part): drop `titleWithoutThePrefix`. Keep the hash test: it also checks that different text hashes differently.
- T9 — FIX: exact phrase count; a test for `takes(forStep:)` and `lastTake`; the untitled Cutaway fallback joins the C3 test.

### Outcome — 2026-11-06

- C1 — fixed: a number run ends at a token ending in `, ; : . ! ? …` and at a dash token (`ScriptWords.groups`); tests for "fifteen, sixteen", "twenty, thirty, forty", "nineteen — twenty".
- C2 — fixed: Delete dismisses first, then deletes, and the Script screen draws nothing from a deleted script. Checked in the simulator: delete from the Script screen returns to the list with no crash or fault.
- C3 — fixed: `ParsedScript.titleIsStated`; a paste replaces a stored script by title only when the text states its title (a `# ` line, or a plain script's lone title line). Test: two plain scripts with the same first line stay two scripts.
- C4 — not done: not a defect; PRD v0.4, Results and the progress stub are the completion step.
- C5 — fixed (part): the rule is kept; recorded in Results and PRD §4.1 at completion.
- C6 — fixed (part): recorded in Results at completion; no code change.
- C7 — fixed: a token with a digit, `.` or `:`, and a digit is a plain word; tested with "2.5" and "9:30".
- C8 — fixed (part): `Step.heading` is the one "Step N" fallback (`displayTitle` removed, it had no other caller). The repeated alert binding: not done, two lines.
- T1 — fixed: `WordNormaliser.words(in:)` removed; `WordNormaliserTests` test `normalise(_:)`.
- T2 — fixed: the replace test uses a lower-case title and checks a rendering is kept.
- T3 — not done: the view models route to the importer, which is tested.
- T4 — fixed: a hyphenated token splits into number pieces only when they read as one number; "one-two" is one word.
- T5 — fixed (part): `refreshIfStale` keeps `updatedAt`, tested. The no-steps branch: not done, unreachable after an import.
- T6 — fixed: `phrasesRoundTripThroughJSON` removed.
- T7 — fixed (part): normaliser number cases removed; the two "there's" tests merged. `aYearIsOneScriptWord` kept.
- T8 — fixed (part): `titleWithoutThePrefix` removed; the hash test kept.
- T9 — fixed: exact phrase count (27); `takes(forStep:)` and `lastTake` tested; the untitled Cutaway fallback tested.

Tests: 62 pass (three duplicates removed, new cases added); no build warnings; SwiftLint clean.
