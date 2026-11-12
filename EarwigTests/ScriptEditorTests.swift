import Foundation
@testable import Earwig
import SwiftData
import Testing

@MainActor
struct ScriptEditorTests {

    // Held: a context outlived by its container crashes.
    private let container = ModelContainerFactory.inMemory()
    private var context: ModelContext { container.mainContext }

    private typealias Edit = ScriptEditor.Edit

    // MARK: Title

    @Test func titleAddsALineAtTheTop() {
        #expect(ScriptEditor.title(in: Edit(text: "Hello.", selection: 3..<3)) == Edit(text: "# \n\nHello.", selection: 2..<2))
        #expect(ScriptEditor.title(in: Edit(text: "", selection: 0..<0)) == Edit(text: "# ", selection: 2..<2))
    }

    @Test func titleGoesToTheEndOfATitleThatIsThere() {
        // No text changes, so the text view makes no edit for it.
        #expect(ScriptEditor.titleChange(in: Edit(text: "\n# The Pier\n\nHello.", selection: 15..<15)) == ScriptEditor.Change(range: 15..<15, text: "", cursor: 11))
        // A step heading is not the title.
        #expect(ScriptEditor.title(in: Edit(text: "## One\nHi.", selection: 0..<0)).text == "# \n\n## One\nHi.")
    }

    // MARK: Step

    @Test func stepAtTheStartOfEmptyText() {
        #expect(ScriptEditor.step(in: Edit(text: "", selection: 0..<0)) == Edit(text: "## ", selection: 3..<3))
    }

    @Test func stepAtTheEndOfALineLeavesABlankLineFirst() {
        #expect(ScriptEditor.step(in: Edit(text: "# Pier", selection: 6..<6)) == Edit(text: "# Pier\n\n## ", selection: 11..<11))
        #expect(ScriptEditor.step(in: Edit(text: "# Pier\n", selection: 7..<7)) == Edit(text: "# Pier\n\n## ", selection: 11..<11))
        #expect(ScriptEditor.step(in: Edit(text: "# Pier\n\n", selection: 8..<8)) == Edit(text: "# Pier\n\n## ", selection: 11..<11))
    }

    /// The line under the editor says what a step's heading is for while the cursor is on it.
    @Test func onAStepsHeadingTheLineSaysWhatTheNameIsFor() {
        let editor = ScriptEditor(mode: .new)
        let stepped = ScriptEditor.step(in: Edit(text: "# The Pier", selection: 10..<10))
        editor.text = stepped.text
        editor.cursor = stepped.selection.lowerBound
        #expect(editor.summary == ScriptEditor.nameHint)
        editor.text += "Arriving"
        editor.cursor = editor.text.count
        #expect(editor.summary == ScriptEditor.returnHint)
        editor.text += "\nHello there."
        editor.cursor = editor.text.count
        #expect(editor.summary == "The Pier · 1 step · 1 line")
        #expect(editor.canSave)
    }

    /// Words dictated into a step's heading make a step with nothing to say, which the line names
    /// (Andy on the phone: Save never came on, and nothing said why).
    @Test func aStepWithOnlyANameIsNamed() {
        let editor = ScriptEditor(mode: .new)
        editor.text = "# The Pier\n\n## Hello there everyone"
        editor.cursor = 0
        #expect(editor.summary == ScriptEditor.silentHint("Hello there everyone"))
        #expect(!editor.canSave)
        editor.text = "# The Pier\n\n## One\nHello.\n\n## Two\n[Wave]\n\n## \n"
        #expect(editor.summary == "The Pier · 1 step · 1 line\n" + ScriptEditor.silentHint("Two"))
    }

    @Test func theStepBeingWrittenIsNotNamed() {
        let text = "# The Pier\n\n## One\nHello.\n\n## Two\n"
        #expect(ScriptEditor.silentStep(in: text, apartFrom: text.count) == nil)
        #expect(ScriptEditor.silentStep(in: text, apartFrom: 13) == "Two")
    }

    @Test func aStepWithNothingYetOrACutawayStepIsNotNamed() {
        #expect(ScriptEditor.silentStep(in: "# The Pier\n\n## One\nHello.\n\n## ") == nil)
        #expect(ScriptEditor.silentStep(in: "# The Pier\n\n## One\n[Wave] Hello.") == nil)
        #expect(ScriptEditor.silentStep(in: "# Walk\n\n## 1. Off\nShows: Gate.\nSays: nothing\n\n## 2. On\nSays:\n- Hi.") == nil)
    }

    @Test func stepInTheMiddleOfALineBreaksIt() {
        #expect(ScriptEditor.step(in: Edit(text: "Hello world", selection: 6..<6)) == Edit(text: "Hello \n\n## \nworld", selection: 11..<11))
    }

    @Test func stepPutsASelectionUnderTheHeading() {
        #expect(ScriptEditor.step(in: Edit(text: "One. Two.", selection: 5..<9)) == Edit(text: "One. \n\n## \nTwo.", selection: 10..<10))
    }

    @Test func stepBeforeALineBreak() {
        #expect(ScriptEditor.step(in: Edit(text: "One.\nTwo.", selection: 4..<4)) == Edit(text: "One.\n\n## \nTwo.", selection: 9..<9))
    }

    // MARK: Cue

    @Test func cueInTheMiddleOfALineIsInline() {
        #expect(ScriptEditor.cue(in: Edit(text: "Hi. Bye.", selection: 4..<4)) == Edit(text: "Hi. []Bye.", selection: 5..<5))
    }

    @Test func cueAtTheEndOfALineStartsALineOfItsOwn() {
        #expect(ScriptEditor.cue(in: Edit(text: "Hi.", selection: 3..<3)) == Edit(text: "Hi.\n[]", selection: 5..<5))
        #expect(ScriptEditor.cue(in: Edit(text: "Hi.\nBye.", selection: 3..<3)) == Edit(text: "Hi.\n[]\nBye.", selection: 5..<5))
        // On an empty line, or in empty text, it is there already.
        #expect(ScriptEditor.cue(in: Edit(text: "Hi.\n", selection: 4..<4)) == Edit(text: "Hi.\n[]", selection: 5..<5))
        #expect(ScriptEditor.cue(in: Edit(text: "", selection: 0..<0)) == Edit(text: "[]", selection: 1..<1))
    }

    @Test func cueInsideACueOnItsOwnLineEndsItOnANewLine() {
        #expect(ScriptEditor.cue(in: Edit(text: "Hi.\n[Wave]", selection: 8..<8)) == Edit(text: "Hi.\n[Wave]\n", selection: 11..<11))
        #expect(ScriptEditor.cue(in: Edit(text: "[Wave]\nBye.", selection: 5..<5)) == Edit(text: "[Wave]\n\nBye.", selection: 7..<7))
    }

    @Test func cueInsideAnInlineCueGoesPastIt() {
        #expect(ScriptEditor.cue(in: Edit(text: "Hi [wave] bye", selection: 6..<6)) == Edit(text: "Hi [wave] bye", selection: 9..<9))
    }

    @Test func cueWrapsASelection() {
        #expect(ScriptEditor.cue(in: Edit(text: "Hi wave bye", selection: 3..<7)) == Edit(text: "Hi [wave] bye", selection: 9..<9))
    }

    // MARK: Capitals

    @Test func theStartOfATitleOrAStepGetsACapital() {
        #expect(ScriptEditor.capitalised("my walk", at: 2, in: "# ") == "My walk")
        #expect(ScriptEditor.capitalised("the pier", at: 9, in: "# Hi\n\n## ") == "The pier")
        #expect(ScriptEditor.capitalised(" the pier", at: 8, in: "# Hi\n\n##") == " The pier")
    }

    @Test func otherTextIsLeft() {
        #expect(ScriptEditor.capitalised("walk", at: 4, in: "# My ") == nil)
        #expect(ScriptEditor.capitalised("hello", at: 0, in: "") == nil)
        #expect(ScriptEditor.capitalised("My walk", at: 2, in: "# ") == nil)
        #expect(ScriptEditor.capitalised("iPhone", at: 2, in: "# ") == nil)
        #expect(ScriptEditor.capitalised("wave", at: 5, in: "Hi.\n[]") == nil)
        #expect(ScriptEditor.capitalised("w", at: 4, in: "Hi [") == nil)
        #expect(ScriptEditor.capitalised("#", at: 0, in: "") == nil)
    }

    @Test func theKeyboardOffersCapitalsOnATitleOrAStepAndAtAStepsStart() {
        #expect(ScriptEditor.wantsCapital(at: 2, in: "# "))
        #expect(ScriptEditor.wantsCapital(at: 3, in: "# M"))
        #expect(ScriptEditor.wantsCapital(at: 17, in: "# Hi\n\n## The pier"))
        #expect(ScriptEditor.wantsCapital(at: 9, in: "# Hi\n\n## "))
        #expect(ScriptEditor.wantsCapital(at: 9, in: "# Hi\n\n##\n"))
        #expect(ScriptEditor.wantsCapital(at: 18, in: "# Hi\n\n## The pier\n"))
    }

    @Test func theKeyboardIsLeftAloneElsewhere() {
        #expect(!ScriptEditor.wantsCapital(at: 0, in: ""))
        #expect(!ScriptEditor.wantsCapital(at: 1, in: "#"))
        #expect(!ScriptEditor.wantsCapital(at: 8, in: "#hashtag"))
        #expect(!ScriptEditor.wantsCapital(at: 5, in: "# Hi\n"))
        #expect(!ScriptEditor.wantsCapital(at: 5, in: "Hi.\n["))
        #expect(!ScriptEditor.wantsCapital(at: 26, in: "# Hi\n\n## The pier\nHello.\n"))
    }

    // MARK: How the text looks

    private func styles(_ text: String) -> [String] {
        ScriptHighlight.styles(in: text).map { "\($0.kind) \((text as NSString).substring(with: $0.range))" }
    }

    @Test func aTitleAndAStepAreBoldWithTheirMarksFaint() {
        #expect(styles("# The Walk\n\n## Off we go\nHello.") == ["title # The Walk", "mark #", "step ## Off we go", "mark ##"])
        #expect(styles("##") == ["step ##", "mark ##"])
    }

    @Test func cuesAreColouredOpenOrClosed() {
        #expect(styles("[Wave] Hello [smile] there.\n[Turn") == ["cue [Wave]", "cue [smile]", "cue [Turn"])
    }

    @Test func otherTextIsNotStyled() {
        #expect(styles("#hashtag and ####### and Morning!\n- Says (round)") == [])
    }

    @Test func stylesCountAsUIKitDoes() {
        #expect(styles("Café 👋 [wave]") == ["cue [wave]"])
    }

    @Test func aSelectionPastTheEndIsKeptInside() {
        #expect(ScriptEditor.clamped(9..<12, in: "Hi") == 2..<2)
        #expect(ScriptEditor.clamped(1..<12, in: "Hi") == 1..<2)
    }

    // MARK: The editor

    @Test func newStartsWithATitleAndCannotSaveYet() {
        let editor = ScriptEditor(mode: .new)
        #expect(editor.text == "# ")
        #expect(editor.selection == 2..<2)
        #expect(!editor.hasChanges)
        #expect(!editor.canSave)
        #expect(editor.summary == ScriptEditor.hint)
    }

    @Test func theSummarySaysWhatTheTextMakes() {
        let editor = ScriptEditor(mode: .new)
        editor.text = "# The Pier\n\n## One\nHello.\nIt opened in 1899.\n\n## Two\nBye."
        #expect(editor.summary == "The Pier · 2 steps · 3 lines")
        #expect(editor.canSave)
    }

    @Test func newSavesANewScriptMarkedAsWrittenHere() throws {
        let editor = ScriptEditor(mode: .new)
        editor.text = "# The Pier\n\nHello."
        let script = try editor.save(in: context)
        #expect(script.title == "The Pier")
        #expect(script.editedInEarwig)
    }

    @Test func anEditCanSaveOnlyOnceChanged() throws {
        let script = try ScriptImporter(context: context).paste("# The Pier\n\nHello.").script
        let editor = ScriptEditor(mode: .edit(script))
        #expect(!editor.canSave)
        editor.text += " Again."
        #expect(editor.hasChanges)
        #expect(editor.canSave)
        #expect(try editor.save(in: context) === script)
        #expect(script.orderedSteps[0].lines == ["Hello. Again."])
    }

    @Test func editingASampleEditsTheSample() throws {
        let sample = try ScriptImporter(context: context).add(SampleScript.harbourWalk)
        sample.sampleID = "harbour-walk"
        let editor = ScriptEditor(mode: .edit(sample))
        #expect(editor.heading == "Edit Script")
        #expect(!editor.canSave)
        editor.text = editor.text.replacingOccurrences(of: "Morning!", with: "Hello!")
        #expect(try editor.save(in: context) === sample)
        #expect(sample.isEditedSample)
        #expect(sample.format == .plain)
        #expect(try context.fetchCount(FetchDescriptor<Script>()) == 1)
    }

    @Test func aSharedFileIsNamedAfterTheTitle() {
        #expect(ScriptText(title: "Walk: 1/2?", text: "").fileName == "Walk 12.md")
        #expect(ScriptText(title: " / ", text: "").fileName == "Script.md")
    }
}
