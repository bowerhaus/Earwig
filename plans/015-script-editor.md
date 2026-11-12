# Plan 015: Write and Edit Scripts

**GitHub Issue:** [#43](https://github.com/bowerhaus/Earwig/issues/43) (PR must include "Closes #43")
**Branch:** `script-editor` (from `main` at `ab9ea05`, after plan 014 merged). Plan 013, the App Store release, is in flight on `app-store-release` and touches the README, the PRD and CLAUDE.md, so whichever merges second rebases the PRD version, CLAUDE.md's status and the README.
**Status:** Approved (2026-11-10) under `/plan_autopilot`; in progress. Outside PRD §12's stages, like plans 007 and 014.
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
- "cue" as the one term in the app and the README, with Settings' Stage Directions renamed Hear Cues As (decision 11);
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
   - **Amended in the simulator:**
     - Edit is a pencil icon (`toolbarCircle()`) like Share, not a capsule: "Edit a Copy" in a capsule cut the title to "The Harbo…". The sheet's title says Edit a Copy for a sample.
     - The toolbar showed New and Paste as icons alone, which can't be told apart, so `AccentPill` now shows its word in a toolbar too.
   - **Amended on the phone (Andy, after device check 1): superseded by decision 12.** The Scripts toolbar's yellow pills and the Script toolbar's blue circles didn't match, Edit meant Edit a Copy on a sample, and the Share and pencil icons sat off-centre in their circles.

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
   - **Amended in the simulator:**
     - **Not a keyboard toolbar.** iOS 26 showed nothing for `ToolbarItemGroup(placement: .keyboard)` in the sheet, so Title, Step and Cue are a bar of Earwig's own capsules under the text, above the keyboard and there with it down too.
     - **Not SwiftUI's `TextEditor`.** It lost a button's edit made while the keyboard still held a word it was suggesting for, as it does while dictating, and put the cursor short of the edit. The text is UIKit's `UITextView` (`ScriptTextView`), and a button's edit is a replacement (`ScriptEditor.Change`) made through the input system, with the keyboard told of it first, so it can be undone and the keyboard stays in step.
     - **The bar stays put.** The help line keeps three lines, so the bar doesn't move up when the hint gives way to the count.
     - **The help line** is the hint while there's nothing to say: "Type a title, then tap Step for each part. A cue, a stage direction for you, goes in square brackets: [Gesture to the boats]." It replaces the placeholder.
     - **Title** never turns a line into the title; it goes to the title line's end, or adds a `# ` line at the top.
     - **On the keyboard, after all (Andy, on the phone: the pills under the text "look a bit 1985").** Title, Step and Cue, each an icon and a word in mid-blue, are one glass capsule floating just above the keyboard, as iOS 26 shows its own editing tools: the text view's `inputAccessoryView`, which shows in the sheet where SwiftUI's keyboard toolbar didn't. It goes with the keyboard; a tap on the text brings both back. The sheet's sky blue runs under the keyboard, so the glass is tinted by it, not white. A flat keyboard-grey bar was tried first and sat on iOS 26's rounded glass keyboard as a separate block.
   - **Amended on the phone (device check 1):**
     - **Step puts the cursor on the line under its `## `.** With it after the `## `, everything Andy dictated became the step's name, the step had nothing to say and Save never came on (review C4). A name is typed after the `## `.
     - **Cue at the end of a line starts a line of its own**, and **tapped inside a cue it ends it**: past the `]`, and for a cue on a line of its own onto a new line under it. Mid-sentence it is still inline.
     - **Capitals.** The keyboard leaves the first letter after `# `, `## ` or `[` small, so the text view makes it a capital as it is typed or dictated (`ScriptEditor.capitalised`), leaving a word like "iPhone".
     - **No capital in a cue** (Andy: "I don't think cues need to be capitalized"): `capitalised` is for titles and step names only.
     - **Step leaves the cursor after its `## ` after all** (Andy, after Title Case headings: the cursor on the line under looked odd, didn't say why, and a name meant going back up). A name is typed or dictated there, then Return; Return straight away skips it. The heading is bold and in Title Case, so words that land there by mistake show at once, which they didn't when the next-line rule was made. The line under the editor follows the cursor: on a heading with no name, "Name this step, or press Return to skip the name. A name is shown on the step's card and read in the slate."; with one, "Press Return to write what you'll say in this step." Elsewhere it names a step with a name and nothing to say, which the plain parser leaves out (review C4), apart from the step the cursor is in.
     - **Shift on a title's or step's line** (an experiment, kept: Andy on the phone, "this all looks good"). iOS has no way to light Shift, so while the cursor is on a title's or step's line past its `# ` or `## `, or at the start of the line under a step's heading (`ScriptEditor.wantsCapital`), the text view asks for `.words` capitals and reloads the keyboard, and `.sentences` elsewhere: only when the choice changes, never while the keyboard is composing. Headings come out in Title Case. Only at a heading's start was tried first: dictation writes its words again with the capitals asked for at the time, and switching back after the first word took its capital away (seen in the console). iOS 26 gives no sign that dictation is running (`textInputMode` stays "en-GB"). `capitalised` stays as the backstop.
     - **`##` kept, but quieter** (Andy chose this over "a blank line starts a step"). The editor colours the text as it is typed (`ScriptHighlight`), attributes only, the stored text unchanged: the `#` and `##` faint (`EarwigTheme.editorMark`), the title bold and larger, a step's heading bold, cues in the cue colour. Skipped while the keyboard is composing or dictating. This is option (b), after all.

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
   - square brackets are a cue: inside a line, chimed or spoken there (Settings' Hear Cues As); on its own line at the top of a step, read in the slate before the take, as Cutaway's `Shows:` is;
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
   - **The Seaside Pier** is rewritten with `#` and `##`, since its step names were guessed. A later build's sample text replaces the stored one and keeps its takes (plan 011). **Amended: all four samples are in the documented format (decision 13).**

6. **Share: the way back to the Mac.**
   - A `Transferable` `ScriptText` gives the share sheet the text both as plain text (so **Copy** gives the words, for Universal Clipboard) and as a `.md` file named after the title (for AirDrop, Files and Mail).
   - Which one each destination takes is checked on the phone (Verification, check 4).
   - What's shared is the stored text, exactly as written, so a Cutaway script goes back as valid Cutaway.

7. **Samples: Edit a Copy** (Andy asked). **Amended on the phone: samples are edited and reset (Andy), and Edit a Copy is gone.**
   - Edit means the same on every script. An edited sample is `editedInEarwig`; `SampleSeeder` leaves it alone, so a later build's text doesn't replace an edit, and **Reset Sample** (in More, and a swipe on the Scripts list) puts this build's text back, keeping the takes, after asking ("Your changes to it will be lost. Its takes are kept.").
   - A paste still never replaces a sample, and a sample is still never deleted.
   - There is no longer a one-tap way to keep a sample and also have a variant of it of your own; thought rare.
   - What follows is the decision as first made:
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
     - message: "Changes made to this script in Earwig will be lost. Share it first to keep them." (Amended from "edited here since it was last pasted": a script written with New was never pasted.)
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
    - **Settings' Stage Directions** (Chime or Spoken) becomes **Hear Cues As** (Andy), so it reads with its choice: "Hear Cues As Chime".
      - Its footer says what the name doesn't: "Cues at the top of a step are always read with the slate." Decision 4 makes that true, and only cues in the middle of what you say are chimed or spoken.
      - **Cues in Lines** was tried first and dropped: "lines" is Earwig's word for a script's parts, and Andy couldn't tell what it meant until it was explained. **Cues While You Speak** was also offered.
    - **Read Cues** and **Cue Voice** keep their names.
    - **"Stage direction"** appears once, as the explanation in the README and the editor's placeholder: a cue is "a stage direction for you, like [Gesture to the boats]".
    - **The README** says "cue" throughout, in place of "stage direction" and "direction".
    - **Code stays as it is.** `Direction`, `InlineDirections` and the settings' storage keys keep their names, so stored settings carry over. The PRD's §3 keeps "Direction" as the term for text that isn't spoken, and notes that users see it as a cue.

12. **One set of buttons** (Andy, after device check 1: "take a step back and consider the UI/UX again").
    - **Named button styles** in `Views/Common/ButtonStyles.swift`, beside `EarwigTheme`'s colours: views never build a button's fill, shape or height themselves (Andy asked for one place to change the look).
      - **Toolbar:** an icon in a mid-blue circle (`toolbarCircle`) only for Back, Settings and More; everything else a word in a mid-blue capsule (`ToolbarWordButton`, `toolbarCapsule`): New, Paste, Edit, Done, Cancel, Save. Never filled with the accent.
      - **Main action:** `AccentPill`, filled with the accent (Start Take, Next Take, Play, and New and Paste on the empty Scripts screen).
      - **Choice:** `choice(_:)`, on the accent when chosen (With Voice, Record, Hold). Yellow is "chosen" as well as the main action, so no rule ties yellow to the main action alone (Andy).
      - **Second action** (`secondAction`), **circle outside the toolbar** (`surfaceCircle`), **row action** (`rowAction`), **destructive** (`destructiveAction`).
      - The screens look as before apart from the toolbars.
    - **The Script screen's toolbar:** **Edit** (a word) and **More** (an ellipsis, which centres in its circle), with Share, Paste New Version, and Delete Script or Reset Sample. All at the top, however long the script: the foot was too far down to find (Andy). The foot's Paste New Version and Delete cards are gone.
      - The menu is iOS's pale one: the screen sets no bar background or dark bar of its own, as the Scripts screen sets none. A dark bar made the menu near-black; a bar background without it turned the Scripts title black on the way back. The menu's icons are mid-blue, as the accent is faint on it.
    - **The title is on the page**, large and wrapping, not in the bar, where a long one was cut short beside the buttons.
    - **Swipe on the Scripts list** gives **Edit** beside Delete on your own scripts, and Edit, with Reset once edited, on a sample: a shortcut, not the only way (Andy wasn't convinced a swipe alone would be found).

13. **The samples in the documented format** (Andy, on the phone). The Harbour Walk, the Weekend Loaf and the Old Watermill were Cutaway scripts, which is unpublished and shows `Shows:`, `Says:` and `- ` in the editor; a sample should show a new user how to write a script.
    - Each is `# Title`, `## Step name` (the "1." numbering dropped), the `Shows:` text as a cue line at the top of its step, and each `- ` line a plain line.
    - The same steps in the same order, so takes (kept by step) stay right; the seeder replaces unedited stored samples on the next launch (plan 011). A test checks the Harbour Walk says what its Cutaway version said.
    - Cutaway is still tested: the Cutaway Harbour Walk is `Fixtures.harbourWalk`, the parser and import tests' main fixture. Cutaway paste is unchanged.
    - For Completion: the README's screenshots and banner show "SHOWS" on the Harbour Walk and need retaking (`scripts/readme/make_readme_images.py`), as do plan 013's App Store screenshots.

## Files

- `Earwig/Views/Editor/ScriptEditorView.swift` (new): the sheet, the bar of buttons, the live line.
- `Earwig/Views/Editor/ScriptTextView.swift` (new): UIKit's text view, and the buttons' edits made through the input system.
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
- `Earwig/Views/Settings/SettingsView.swift`: Hear Cues As and its footer.
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
5. **The screens.** New, Edit, Share, the labels gone, the hint, the paste warning, the cue on the card, and Hear Cues As.
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
  - New and Edit open, save and cancel, on a sample too;
  - the toolbars (decision 12), the More menu, and the swipe's Edit and Reset;
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
  6. **A sample edited and reset.** Edit a sample, change a line, and save; then More › Reset Sample, or a swipe on the Scripts list. The text is back, and the takes are kept.
  7. **The buttons** (decision 12). Do the Scripts and Script toolbars, the More menu and the swipe feel consistent and easy to find?

## Results

Not started.

## Review pass — 2026-11-10

Findings from `/review-branch` on branch `script-editor`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact, and each verdict under *Assessment* is a
recommendation, not a decision. Work through them and annotate each with what was done — fixed,
or rejected and why. A finding that turns out to be wrong should say so here rather than be
deleted.

### Code

Review of `script-editor` against `main` (plan 015, issue #43)

The working tree is clean and there are no untracked files, so the whole review is of `git diff main...HEAD`. I read all five new files in full. I found nothing that looks like it would break the build, and nothing that breaks CLAUDE.md: colours come from `EarwigTheme`, toolbar buttons use `toolbarCircle()` / `toolbarCapsule()`, labels are in Title Case, spelling is UK, and the engine is untouched. On requirements, everything in the plan's In scope that is due before Finish is implemented, with the simulator amendments followed. The findings are two parser bugs and some smaller points.

**C1. WARNING: A new script can be saved with an empty title.**
- File: `/Users/andybower/Projects/Earwig/Earwig/Services/ScriptParser.swift:285-286`
- The fallback title is `stepHeading(firstLine) ?? firstLine`. When the first content after the `#` line is a bare `##` heading, `stepHeading` returns `""` and `shortened("")` gives `""`.
- This is the ordinary New flow when no title is typed. New starts with `# `, the presenter taps Step, presses Return and says a line, giving `"# \n\n## \nHello."`. That parses to `title == ""`.
- The result is an empty Scripts row and navigation title, " · 1 step · 1 line" in the editor's summary, and a share file called `Script.md`.
- The test `checkSaysWhyTextCannotBeSaved` only covers `"#\n\nHello."`, which has no heading.
- Fix: skip empty heading names when choosing the fallback, using the first spoken line, then "Untitled script".

**C2. WARNING: Text before the first `##` can become two steps, against decision 4(i).**
- File: `/Users/andybower/Projects/Earwig/Earwig/Services/ScriptParser.swift:312-320` (`leading`), called from `headedBlocks`.
- `leading` always splits off a short, title-like first paragraph, even when a `# ` title has already been stated.
- Example: `"# The Pier\n\nHello everyone\n\nWelcome to the pier.\n\n## The end\nAnd here we are."` gives three steps, with "Hello everyone" alone as step 1. The spec says text before the first heading is one step with no name.
- Dictated text often has no full stop on a short opening phrase, so this case will come up.
- The test `textBeforeTheFirstHeadingIsAStep` misses it because its first line is "Hello everyone." with a full stop.
- Fix: split off the title candidate only when no `# ` title was found, by passing `scriptTitle == nil` into `headedBlocks` / `leading`.

**C3. SUGGESTION: A cue-only paragraph or step is dropped, cue and all.**
- File: `/Users/andybower/Projects/Earwig/Earwig/Services/ScriptParser.swift:268-277`
- `"[Walk to the end]\n\nAnd here we are."` gives one step with no cue: the `.cue` direction is thrown away with the empty block. The test `aCueAloneIsNotAStep` makes that the expected result.
- The same happens to `"## Quiet\n[A view]"` before a step. Without `##`, a cue in its own paragraph above the words it belongs to is a natural way to write.
- Consider carrying its directions forward to the next step instead.

**C4. SUGGESTION: Dictating straight after Step makes the words the step's name.**
- File: `/Users/andybower/Projects/Earwig/Earwig/ViewModels/ScriptEditor.swift:113-122`
- The cursor is left on the `## ` line, as decision 2 specifies. Anything dictated straight after tapping Step becomes the step's name and is never spoken.
- That is the failure decision 4(ii) removed the name guess to prevent ("Hello everyone" vanishing into a name).
- This follows the spec, but it is worth watching for in device check 1.

**C5. SUGGESTION: The Settings footer says "always", but these cues are read only with Read Cues on.**
- File: `/Users/andybower/Projects/Earwig/Earwig/Views/Settings/SettingsView.swift:82`
- "Cues at the top of a step are always read with the slate." But `Slate.text(for:take:cuesOn:)` reads them only when Read Cues is on, as `SlateTests` asserts.
- The wording is decision 11's, but "always" may read as "whatever Read Cues says". Something like "…are read with the slate, not chimed" would avoid that.

**C6. SUGGESTION: A sample could stop updating if its stored script carries the edit flag.**
- File: `/Users/andybower/Projects/Earwig/Earwig/Services/SampleSeeder.swift:21` (that line is unchanged; the change in behaviour comes from this branch's `replace(_:with:replacingEdits:)`)
- The seeder discards the result of `replace`. Suppose a script of the presenter's own is adopted as a sample (identical text) while its `editedInEarwig` is true. Every later build's text for that sample would then return `.wouldReplaceEdits` and be skipped without notice.
- This is unlikely. Passing `replacingEdits: true` here, or clearing the flag on adoption, makes it impossible.

**C7. SUGGESTION: Repeated code (DRY).**
- Three slightly different regexes decide what counts as a `#` title line:
  - `PlainParser.parse` (`#(?!#)(?:\s+(.*?))?\s*#*`)
  - `ScriptEditor.titleChange` (`#(?!#)(?:\s.*)?`)
  - `ScriptEditor.copyText` (`\s*#(?!#)\s+.*`)
- One shared helper on `PlainParser`, like `stepHeading`, would keep the parser, the Title button and the copy in agreement.
- The paste-warning `confirmationDialog` is written out twice, with the title string repeated:
  - `/Users/andybower/Projects/Earwig/Earwig/Views/Scripts/ScriptsView.swift:57-66`
  - `/Users/andybower/Projects/Earwig/Earwig/Views/ScriptDetail/ScriptDetailView.swift:181-190`
- `ReplaceEdits` holds only the message, and it lives in `ScriptEditorView.swift` although only the two paste flows use it. Put the title in it too, or make a small shared modifier.

**C8. SUGGESTION: The editor parses the whole script several times per keystroke.**
- Files: `/Users/andybower/Projects/Earwig/Earwig/ViewModels/ScriptEditor.swift:54-74` and `/Users/andybower/Projects/Earwig/Earwig/Views/Editor/ScriptEditorView.swift:33, 55-56`
- `summary` and `canSave`, which is read twice (for `.disabled` and `.opacity`), each call `ScriptImporter.check(text)`. `hasChanges` runs `cleaned` on both texts, and it is read for `.interactiveDismissDisabled` too.
- That is three full parses per body update. It is fine for short scripts but grows with a long Cutaway script. Working the parse out once per text change, for example in `didSet`, would avoid it.

### Tests

Test review of `script-editor` against `main`. There are no unstaged, staged or untracked test changes. The branch adds about 30 tests over 4 files. That volume fits the change, and most tests are short and well aimed. One gap probably hides a real bug.

**T1. WARNING: a probable blank-title bug sits in a gap the bare-heading test leaves open.**
`EarwigTests/PlainParserTests.swift:56-60` (`aBareHeadingStartsAStepWithNoName`) never asserts the script's title.
- In `PlainParser.parse` (`Earwig/Services/ScriptParser.swift`), the fallback title is `stepHeading(firstLine) ?? firstLine`. For a bare `##` that gives `""`, so `"##\nFirst part.\n##\nSecond part."` parses with the title `""`.
- This is the editor's normal New flow when no title is typed. New starts with `"# "`, and tapping Step without typing a name gives text that cleans to `"#\n\n##\nHello."`.
- The result is a script saved with an empty title, and the editor summary reads `" · 1 step · 1 line"`.
- The Cutaway parser guards this case with "Untitled script" (around line 220); the plain parser has no such guard.
- Fix: assert the title in this test, or add a `check("# \n\n## \nHello.")` case to `checkSaysWhyTextCannotBeSaved` (`EarwigTests/ScriptImporterTests.swift:174`). Then fix the fallback.

**T2. WARNING: nothing tests the view-model side of the ask-before-replacing-edits flow (decision 8).**
The importer side is tested well (`ScriptImporterTests.swift:137-165`). Nothing tests the view-model state the alerts depend on:
- In `ScriptsViewModel` (`Earwig/ViewModels/ScriptsViewModel.swift`):
  - `paste` should set `pendingPaste` and leave `path` alone on `.wouldReplaceEdits`.
  - `confirmPaste` should clear it, replace the text and open the script.
  - `cancelPaste` should leave the edited text in place.
- In `ScriptDetailViewModel.pasteNewVersion` / `confirmNewVersion` (`Earwig/ViewModels/ScriptDetailViewModel.swift`): `pendingNewVersion` should be set, and no notice or save should happen until it is confirmed.

These are cheap to write:
- `EarwigTests/ScriptsViewModelTests.swift` already has the same ask/confirm/cancel pattern for deletion.
- `ScriptDetailViewModelTests` already builds a `ScriptRenderer` with `FakeRenderer`.

One test per view model, ask then confirm, would do.

**T3. SUGGESTION: Edit a Copy is tested end to end only with the plain sample.**
- `editACopyMakesAScriptOfYourOwn` (`EarwigTests/ScriptEditorTests.swift:120`) uses the Seaside Pier, but three of the four samples are Cutaway.
- The Cutaway case in `aCopysTitleSaysCopy` (`ScriptEditorTests.swift:70-75`) checks only `hasPrefix` of the text, not that the copy parses to the "(Copy)" title.
- Switching the end-to-end test to `SampleScript.harbourWalk` would cover the common path without adding a test.

**T4. SUGGESTION: `aMarkdownTitleNamesTheScript` now duplicates the new heading test.**
- `EarwigTests/PlainParserTests.swift:112-118` was changed and now asserts the same things as `headingsMakeStepsAndBlankLinesInsideAreSpacing` (`PlainParserTests.swift:19-35`): the `#` title, the `##` name, and blank lines inside a step being only spacing.
- The only extra it covers is a whitespace-only line. Put the `"   "` line into the heading test's text and drop this one.

**T5. SUGGESTION: the existing-title case is tested twice.**
- `aTitleThatIsThereChangesNothingButTheCursor` (`EarwigTests/ScriptEditorTests.swift:63-66`) asserts the raw `Change`.
- `titleGoesToTheEndOfATitleThatIsThere` (`ScriptEditorTests.swift:21-26`) asserts the applied `Edit` for the same case.
- If the empty-range `Change` matters for the text view's undo, keep only the `Change` assertion and fold it into the first test. Otherwise drop it.

**T6. SUGGESTION: a few small pure-logic paths have no test (one-liners would do).**
- `ScriptEditor.stepChange` with a non-empty selection: its doc says "A selection is kept, after the heading" (`Earwig/ViewModels/ScriptEditor.swift`, `stepChange`).
- An empty `[]` line at the top of a step, which the parser drops. This is exactly what the Cue button inserts.
- `ScriptText.fileName` (`Earwig/Models/ScriptText.swift`): stripping the characters a file name can't have, and the `"Script"` fallback.

These could be added as an extra `#expect` to existing tests rather than as new tests.

The new Slate test (`EarwigTests/SlateTests.swift:34-39`), the `create`/`edit`/sample tests in `ScriptImporterTests`, and the other `ScriptEditorTests` are focused and in proportion. I found nothing else worth flagging.

### Assessment

- C1 — FIX: real (`PlainParser.parse`'s fallback takes a bare `##`'s empty name); the fallback skips headings with no name, then falls back to "Untitled script", as the Cutaway parser does.
- C2 — FIX: real (`leading` splits a title-like first paragraph off even under a stated `# ` title, making an extra step); split it off only when no `# ` title was found.
- C3 — SKIP: a cue alone in a paragraph is outside the documented format (a cue on its own line at the top of a step), and carrying it to the next step is a new rule the plan didn't ask for.
- C4 — SKIP: as decision 2 specifies; device check 1 watches for words dictated onto the heading line.
- C5 — FIX: cheap and clearer; the footer becomes "Cues at the top of a step are read with the slate, not chimed."
- C6 — FIX: unlikely but one argument; the seeder replaces a sample's text with `replacingEdits: true`, since a sample's text is the app's.
- C7 — FIX (part): one shared title-line helper on `PlainParser` for the parser, Title and the copy; the dialog's title goes into `ReplaceEdits` beside its message. The two dialogs stay written out, as their bindings differ.
- C8 — FIX: the parse is worked out once per text change, which also lightens each keystroke while typing quickly.
- T1 — FIX: with C1, the bare-heading test asserts the title.
- T2 — FIX: one test per view model, ask then confirm (and cancel for the Scripts screen).
- T3 — FIX: the end-to-end Edit a Copy test uses the Harbour Walk.
- T4 — FIX: the whitespace-only line goes into the heading test, and the duplicate is dropped.
- T5 — FIX: the `Change` assertion folds into the existing-title test, and its separate test is dropped.
- T6 — FIX: one-line expectations for Step with a selection, an empty `[]` at the top of a step, and `ScriptText.fileName`.

### Outcome — 2026-11-10

- C1 — fixed: the fallback title skips a heading with no name and takes the first line with words, else "Untitled script".
- C2 — fixed: a title-like first paragraph before the first `##` is split off only when no `# ` line gave a title.
- C3 — not done: a cue alone in a paragraph is outside the documented format, and carrying it forward would be a new rule.
- C4 — fixed after device check 1: Step puts the cursor on the line under its heading (decision 2, amended on the phone).
- C5 — fixed: the footer reads "Cues at the top of a step are read with the slate, not chimed."
- C6 — fixed: the seeder replaces a sample's text with `replacingEdits: true`.
- C7 — fixed (part): `PlainParser.titleLine` is shared by the parser, Title and Edit a Copy; `ReplaceEdits.title` sits beside its message. The two dialogs stay written out.
- C8 — fixed: `ScriptEditor.checked` is worked out once per text change.
- T1 — fixed: the bare-heading test asserts the title, with New's bare `#` and an empty script.
- T2 — fixed: `aPasteOverAnEditAsksThenReplacesOrKeeps` (Scripts screen: ask, cancel, ask, confirm) and `pasteNewVersionOverAnEditAsksFirst` (Script screen).
- T3 — fixed: Edit a Copy end to end uses the Harbour Walk, and checks the copy stays Cutaway.
- T4 — fixed: the whitespace-only line is an expectation in the heading test; the duplicate is gone.
- T5 — fixed: the existing-title test asserts the `Change`; its twin is gone.
- T6 — fixed: Step with a selection, an empty `[]` at the top of a step, and `ScriptText.fileName`.
- Tests: 434 pass; SwiftLint clean; no warnings.
