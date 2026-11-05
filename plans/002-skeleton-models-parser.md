# Plan 002: Skeleton, Models and Parser

**GitHub Issue:** [#3](https://github.com/bowerhaus/Earwig/issues/3) (PR must include "Closes #3")
**Branch:** `skeleton-models-parser` (from `main` at `6d2b848`, after plan 001 merged)
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
