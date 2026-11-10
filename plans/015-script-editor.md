# Plan 015: Write and Edit Scripts

**GitHub Issue:** [#43](https://github.com/bowerhaus/Earwig/issues/43) (PR must include "Closes #43")
**Branch:** `script-editor` (from `main` at `ab9ea05`, after plan 014 merged). Plan 013, the App Store release, is in flight on `app-store-release` and touches the README, the PRD and CLAUDE.md, so whichever merges second rebases the PRD version, CLAUDE.md's status and the README.
**Status:** Draft (2026-11-10), for Andy's review. Outside PRD §12's stages, like plans 007 and 014.
**Manual test:** device | on Andy's iPhone 14 Pro: dictating into the editor, the toolbar, saving an edit keeps the takes, Share to the Mac, and the warning before a paste replaces an edit made in Earwig (Verification).
**Goal:** A script can be written and edited in Earwig, by typing or by the keyboard's own dictation, in one simple documented format: `#` for the title, `##` for a step, square brackets for a cue, everything else spoken. An edited script can go back to the Mac. Cutaway's `script.md` still pastes exactly as now.

**PRD references:** §1.4 (Non-Goals: "Not a script editor", reversed), §3 (Direction), §4.1 (Scripts), §4.2 (the slate), §8.1 and §8.2 (the Scripts and Script screens), Document History.

---

## Context

Raised by Andy on 2026-11-10. The talk settled:

- **Both New and Edit.**
  - Edit is for fixing a line on a shoot, away from the Mac.
  - New is for App Store users, who have no Cutaway and today must write a script somewhere else first.
- **Dictation is the keyboard's own.**
  - Considered and set aside:
    - a dictation mode with spoken commands ("new step", "scratch that"), too much design and testing for little over the keyboard's dictation;
    - tidying dictated text into steps with Apple's on-device model, which Andy's 14 Pro can't run.
- **A way back to the Mac is needed.**
  - Andy doesn't mind that a script started in Earwig never goes into Cutaway.
- **One format as far as users can tell** (Andy):
  - `#` title, `##` step, `[ ]` cue;
  - `Shows:` becomes a cue at the top of a step, not a field of its own.
  - The two parsers are **not** merged:
    - users already never choose a format, since Earwig detects it;
    - a merged parser would still have to accept all of Cutaway's fields;
    - so the one format is documented, the "Markdown" and "Plain text" labels go, and the plain parser learns the documented rules (decision 4).
- **Blank lines still make steps when a script has no `##`**, so pasted prose from Notes or Word isn't one long take. This reverses a recommendation made during the talk ("only `##` makes a step").
- **Cutaway's format stays `script@1`.**
  - Cutaway runs on its fields: `Footage:` spans, a line's source span, steps and lines by number from `cut.json`.
  - About seven pipeline modules and two skills read them.
  - Two small additions to Cutaway are filed as Cutaway issues when this plan's implementation starts, not before (Andy; step 1).
- **Samples stay read-only, with Edit a Copy** (Andy asked; decision 7).
- **One term: "cue"** (Andy). The app said "cue" in Read Cues and Cue Voice and "stage directions" in Settings, and the README mixed both with "directions" (decision 11).

What already exists:

- **Saving an edit is a re-paste.**
  - `ScriptImporter.replace(_:with:)` (Paste New Version) rebuilds a script's steps from new text and keeps its takes, renderings, cues setting and start step.
  - Unchanged phrases aren't rendered again while the app runs.
- **The plain parser (`PlainParser`) already accepts:**
  - a `# ` title line;
  - `## ` headings as step names;
  - square-bracket directions;
  - a leading `- ` on a line.
  - What it gets wrong for the documented format is in decision 4.
- **Takes are stored by step index.**
  - An edit that adds or removes a step before others moves their takes to the wrong step, as Paste New Version already does. This plan doesn't change that (Scope, Out).

## Scope

**In:**
- an editor for a script's text, with a keyboard toolbar (Title, Step, Cue) and a live count of steps and lines;
- **New** on the Scripts screen, **Edit** on the Script screen, **Edit a Copy** for a sample;
- the plain parser's rules for the documented format, a cue on its own line at the top of a step read in the slate, and parser version 3;
- the format labels removed, and the Seaside Pier sample rewritten in the documented format;
- **Share** on the Script screen: the text, or a `.md` file;
- a warning before a paste replaces changes made in Earwig;
- "cue" as the one term in the app and the README, with Settings' Stage Directions renamed Cues in Lines (decision 11);
- the two Cutaway issues, filed at the start of implementation;
- tests, the simulator flag, the device check, and the README's short "Writing a script".

**Out:**
- keeping takes with their step when an edit adds or removes steps above them (a follow-up issue if it bites);
- styled headings in the editor (decision 2, option b), for later if raw text proves confusing;
- spoken editing commands, and on-device tidying into steps (Context);
- import from Files and the share sheet (#5, P1);
- Cutaway's own changes, which are Cutaway's issues.

## Design decisions

1. **Where the buttons are.**
   - **New:**
     - on the Scripts screen, a **New** pill in the toolbar beside **Paste**, in the same style;
     - while there are no scripts of the presenter's own, the hint row has both, and its text loses "in Markdown or plain text": "Paste a script you've copied, or write a new one."
   - **Edit:**
     - on the Script screen, an **Edit** button at the top right (`toolbarCapsule()`), for the presenter's own scripts;
     - **Paste New Version** and **Delete Script** stay where they are.
   - **Share:** on the Script screen, a share button beside Edit (`toolbarCircle()`), for every script, samples included.
   - The Script screen has had no More menu since plan 011, so these are plain buttons, not a menu.

2. **The editor. Options:**
   - **(a) The raw text in a `TextEditor` (recommended).**
     - A full-screen sheet with **Cancel** and **Save**.
     - It shows exactly what was pasted or written: a Cutaway script shows its `##`, `Says:` and `- `; a plain one looks plain.
     - `TextEditor(text:selection:)` gives the cursor and selection for the toolbar.
     - Pro: simple and honest. Undo, dictation and copy and paste are the system's own.
     - Con: the hashes are visible.
   - **(b) The same, with `#` and `##` lines styled** (larger, hashes faded), using iOS 26's `AttributedString` editing.
     - Pro: friendlier to look at.
     - Con: keeping styles right while text is typed, dictated and pasted is fiddly. It's for later if (a) confuses.
   - **The keyboard toolbar** (`.toolbar { ToolbarItemGroup(placement: .keyboard) }`):
     - **Title** turns the cursor's line into the title (`# `), or adds a `# ` line at the top if there's none;
     - **Step** starts a new step at the cursor: a blank line, then `## ` with the cursor after it, ready for an optional name;
     - **Cue** wraps the selection in square brackets, or puts `[]` with the cursor between them.
   - **Under the editor**, a line from `ScriptParser.parse` of the text as it stands: "The Harbour Walk · 3 steps · 13 lines", or why it can't be saved yet ("Nothing to say yet").
   - **Save** is enabled only when the importer would accept the text (at least one step with spoken words).
   - **Cancel** with changes asks "Discard your changes?" first.
   - **Dictation** is the keyboard's microphone; Earwig adds nothing. The device check finds out whether iOS's "new line" and "new paragraph" commands work in the editor (Verification, check 1).

3. **Saving.**
   - **Edit** saves through `ScriptImporter.replace(_:with:)`, the same path as Paste New Version, so takes, renderings, the cues setting and the start step are kept. Unchanged text saves nothing.
   - **New** saves through a new `ScriptImporter.create(_:)`, which always adds a script.
     - Unlike Paste, a stated title that matches a stored script never replaces it.
     - Text identical to a stored script's opens that script, as a paste does.
   - After saving, New opens the new script's Script screen; Edit returns to it.
   - **New starts with** `# ` and the cursor after it, and a placeholder "Title, then Step for each part".

4. **The documented format, and the plain parser's rules.** The format users are told about:
   - a `# ` line is the title;
   - a `## ` line starts a step, with its name if it has one;
   - with no `##` at all, each paragraph (text between blank lines) is a step;
   - square brackets are a cue: inside a line, chimed or spoken there (Settings' Cues in Lines); on its own line at the top of a step, read in the slate before the take, as Cutaway's `Shows:` is;
   - everything else is spoken. Round brackets are spoken.

   What changes in `PlainParser`:
   - **(i) `##` sections.**
     - When the text has a `##` line, each one starts a step, and blank lines inside a step are only spacing.
     - Today a blank line under a heading starts another step.
     - Text before the first `##` (other than the title) is a step with no name, not a preamble: nothing written to be said is quietly never said.
   - **(ii) No step-name guess.**
     - Today a short first line with no full stop is taken as a step's name and never spoken.
     - With dictation, "Hello everyone" would vanish into a name.
     - Step names now come only from `##`.
   - **(iii) The script-title guess stays.**
     - A first paragraph that is one short line, with more after it, is still the title.
     - Pasted documents often start with one, and a wrong guess shows at once as the script's name.
     - Options considered:
       - drop it too, so the only rule is `#` (pro: fully predictable; con: a pasted "My Video" line is spoken as step 1);
       - keep it (recommended).
   - **(iv) A cue at the top of a step.**
     - A line that is wholly in square brackets, before the step's first spoken line, becomes the step's cue.
     - It's a new `Direction.Kind.cue`, read by `Slate.text(for:take:cuesOn:)` in place of `Shows:` text.
     - It's shown on the card in square brackets in the cue colour, with no "SHOWS" label.
     - A bracketed line further down stays an inline direction, as now.
   - **(v) `PhraseList.currentVersion` 3**, so stored scripts are parsed again.
     - Cutaway scripts come out the same.
     - Plain scripts with guessed step names or headings over blank lines split differently.
     - Their takes stay by index. Only Andy and the TestFlight testers have plain scripts stored.
   - **The Cutaway parser is untouched**, and its tests stay as they are.

5. **The format labels go.**
   - `ScriptFormat.label` is deleted, and the Scripts screen's row reads "3 steps · last take yesterday".
   - `ScriptFormat` itself stays inside the app, choosing the parser.
   - **The Seaside Pier** is rewritten with `#` and `##`, since its step names were guessed. A later build's sample text replaces the stored one and keeps its takes (plan 011).

6. **Share: the way back to the Mac.**
   - A `Transferable` `ScriptText` gives the share sheet the text both as plain text (so **Copy** gives the words, for Universal Clipboard) and as a `.md` file named after the title (for AirDrop, Files and Mail).
   - Which one each destination takes is checked on the phone (Verification, check 4).
   - What's shared is the stored text, exactly as written, so a Cutaway script goes back as valid Cutaway.

7. **Samples: Edit a Copy** (Andy asked).
   - Samples stay read-only: their text is the app's, and a later build replaces it (plan 011, decision 6).
   - On a sample's Script screen, the Edit button reads **Edit a Copy**.
   - It opens the editor on the sample's text with the title changed to "The Harbour Walk (Copy)", and saves through `create(_:)` as a script of the presenter's own, with no takes.
   - The changed title matters twice:
     - text identical to a sample's would just open the sample;
     - `SampleSeeder` adopts a script of the presenter's own with exactly a sample's text, though only when that sample is missing.
   - Cancel makes nothing. The copy can be renamed in the editor like any script.

8. **A warning before a paste replaces an edit.**
   - `Script` gains `editedInEarwig: Bool` (default false, a lightweight migration).
   - It's set when Edit saves a change, and cleared by any paste that replaces the script's text.
   - When a paste would replace a script with it set, on the Scripts screen (by title) or by Paste New Version, a dialog asks first:
     - title: "Replace the changes made in Earwig?"
     - message: "This script was edited here since it was last pasted. Share it first to keep those changes."
     - buttons: **Replace** and **Cancel**.
   - The importer reports this as an outcome to confirm rather than replacing at once.

9. **The Cutaway issues** (step 1, at the start of implementation, with Andy's yes; Cutaway is private, so they aren't public):
   - **Square-bracket cues in `Says:` lines.** Cutaway accepts `[Gesture to the boats]` in a line and keeps it out of captions, voice-over lines and matching against the transcript.
   - **A line whose words no longer match its source span.** `script check` warns when a line with a source span in round brackets has been reworded since, so an edit made in Earwig and copied back is caught.

10. **Simulator flags** (Debug builds):
    - `-EarwigEdit YES` opens the editor on the demo script once its Script screen is open;
    - `-EarwigNew YES` opens New on the Scripts screen.
    - Both are for screenshots and for checking the toolbar.

11. **One term: "cue"** (Andy). Anything said to the presenter that isn't the script is a cue everywhere users see it: what's in square brackets, Cutaway's `Shows:`, and the step's name read in the slate.
    - **Why "cue":**
      - it covers everything the cue voice reads and Read Cues turns on, where "stage direction" covers only the brackets;
      - it's the broadcast word for an instruction to the presenter, and Earwig copies a broadcast practice;
      - it's short, for the toolbar, the start card and Settings;
      - Read Cues and Cue Voice already use it.
    - **Settings' Stage Directions** (Chime or Spoken) becomes **Cues in Lines**. That also says what decision 4 makes true: a cue at the top of a step is always read with the slate, and only cues inside a line are chimed or spoken. Its name says what it does, so it has no footer.
    - **Read Cues** and **Cue Voice** keep their names.
    - **"Stage direction"** appears once, as the explanation in the README and the editor's placeholder: a cue is "a stage direction for you, like [Gesture to the boats]".
    - **The README** says "cue" throughout, in place of "stage direction" and "direction".
    - **Code stays as it is.** `Direction`, `InlineDirections` and the settings' storage keys keep their names, so stored settings carry over. The PRD's §3 keeps "Direction" as the term for text that isn't spoken, and notes that users see it as a cue.

## Files

- `Earwig/Views/Editor/ScriptEditorView.swift` (new): the sheet, the keyboard toolbar, the live line.
- `Earwig/ViewModels/ScriptEditor.swift` (new): the text, the selection and the toolbar's edits as plain functions, the parse for the live line, and save.
- `Earwig/Models/ScriptText.swift` (new): the `Transferable` for Share.
- `Earwig/Services/ScriptImporter.swift`: `create(_:)`, the edit flag, the outcome a paste asks to confirm.
- `Earwig/Services/ScriptParser.swift`: `PlainParser`'s rules (decision 4).
- `Earwig/Models/ScriptFormat.swift`: `Direction.Kind.cue`; `label` deleted.
- `Earwig/Models/Script.swift`: `editedInEarwig`.
- `Earwig/Models/PhraseList.swift`: `currentVersion` 3.
- `Earwig/Services/Slate.swift`: reads a step's cue.
- `Earwig/Services/SampleScript.swift`: the Seaside Pier rewritten.
- `Earwig/Views/Scripts/ScriptsView.swift`, `Earwig/ViewModels/ScriptsViewModel.swift`: New, the hint, the row, the paste warning.
- `Earwig/Views/ScriptDetail/ScriptDetailView.swift`, `Earwig/ViewModels/ScriptDetailViewModel.swift`, `Earwig/Views/ScriptDetail/StepView.swift`: Edit, Edit a Copy, Share, the warning, the cue on the card.
- `Earwig/Views/Settings/SettingsView.swift`: Cues in Lines.
- `EarwigTests/`: the parser, importer, editor and slate tests.
- `README.md`, `PRD.md`, `CLAUDE.md`, `progress.md`, this plan.

## Steps

1. **The Cutaway issues.** With Andy's yes, file decision 9's two issues in `bowerhaus/Cutaway`, and link them here.
2. **The parser.** Decision 4's rules, parser version 3, `Direction.Kind.cue`, and the slate reading it.
   - Tests for:
     - `##` sections with blank lines inside;
     - text before the first `##`;
     - no step-name guess, and the script-title guess kept;
     - a top cue, and a bracketed line further down;
     - paragraphs as steps without `##`.
   - The Cutaway parser's tests pass unchanged, and the samples' tests are updated for the new Seaside Pier.
3. **The importer.** `create(_:)`, `editedInEarwig` and the paste outcome to confirm, with tests:
   - New never replaces by title;
   - Edit keeps takes and the start step;
   - the flag is set by Edit and cleared by a paste;
   - a paste of an edited script asks first;
   - Edit a Copy is a script of the presenter's own and never adopted as the sample.
4. **The editor.** `ScriptEditor` with tests for Title, Step and Cue at the start, middle and end of the text and with a selection, then the sheet. Checked in the simulator with `-EarwigNew YES` and `-EarwigEdit YES`, with screenshots to Andy for a first look.
5. **The screens.** New, Edit, Edit a Copy, Share, the labels gone, the hint, the paste warning, the cue on the card, and Cues in Lines.
6. **Device check** on the iPhone 14 Pro, one check at a time (Verification), installed with `devicectl`. Verdicts are Andy's.
7. **Finish.**
   - SwiftLint clean, no warnings, all tests pass.
   - Results filled in.
   - The README: "cue" throughout (decision 11), and a short "Writing a script" (the format in four lines), in Andy's voice.
   - The PRD:
     - §1.4's non-goal struck;
     - §3 and §4.1 for the format, the editor and Share;
     - §8.1 and §8.2 for the buttons;
     - a Document History row and the version bump.
   - CLAUDE.md's status.
   - `progress.md` emptied to its stub.

## Verification

- `xcodebuild test` passes with no warnings; SwiftLint clean.
- Simulator:
  - New, Edit and Edit a Copy open, save and cancel;
  - the toolbar's three buttons;
  - the live line;
  - Save disabled with nothing to say;
  - the paste warning;
  - Share's sheet offers Copy;
  - the Scripts row has no format label.
- On the iPhone 14 Pro, Andy's verdicts:
  1. **Dictating a new script.**
     - Write a short script by dictation with the toolbar.
     - Do "new line" and "new paragraph" work as commands, and does the punctuation dictation adds suit the voice's phrases?
  2. **Editing on a shoot.**
     - Change a line of a script with takes, save, and run a take of that step.
     - The takes are still there, and the voice says the new words.
  3. **A cue at the top of a step.** With Read Cues on, the slate reads it before the take, as `Shows:` is read.
  4. **Back to the Mac.**
     - Share, then Copy, and paste on the Mac by Universal Clipboard.
     - Share by AirDrop. What arrives in each case?
  5. **The warning.** Edit a script in Earwig, then paste a version from the Mac. Earwig asks before replacing it.
  6. **Edit a Copy.** Copy a sample, change it, and save. It's listed with your own scripts, and the sample is unchanged.

## Results

Not started.
