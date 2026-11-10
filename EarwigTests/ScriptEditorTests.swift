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

    @Test func stepInTheMiddleOfALineBreaksIt() {
        #expect(ScriptEditor.step(in: Edit(text: "Hello world", selection: 6..<6)) == Edit(text: "Hello \n\n## \nworld", selection: 11..<11))
    }

    @Test func stepKeepsASelectionAfterTheHeading() {
        #expect(ScriptEditor.step(in: Edit(text: "One. Two.", selection: 5..<9)) == Edit(text: "One. \n\n## \nTwo.", selection: 10..<10))
    }

    @Test func stepBeforeALineBreakAddsNoSecondOne() {
        #expect(ScriptEditor.step(in: Edit(text: "One.\nTwo.", selection: 4..<4)) == Edit(text: "One.\n\n## \nTwo.", selection: 9..<9))
    }

    // MARK: Cue

    @Test func cueWithNoSelectionPutsTheCursorInside() {
        #expect(ScriptEditor.cue(in: Edit(text: "Hi. Bye.", selection: 4..<4)) == Edit(text: "Hi. []Bye.", selection: 5..<5))
    }

    @Test func cueWrapsASelection() {
        #expect(ScriptEditor.cue(in: Edit(text: "Hi wave bye", selection: 3..<7)) == Edit(text: "Hi [wave] bye", selection: 9..<9))
    }

    @Test func aSelectionPastTheEndIsKeptInside() {
        #expect(ScriptEditor.clamped(9..<12, in: "Hi") == 2..<2)
        #expect(ScriptEditor.clamped(1..<12, in: "Hi") == 1..<2)
    }

    // MARK: Copies

    @Test func aCopysTitleSaysCopy() {
        let copy = ScriptEditor.copyText(of: "# The Pier\n\nHello.", title: "The Pier")
        #expect(copy == Edit(text: "# The Pier (Copy)\n\nHello.", selection: 17..<17))
        let cutaway = ScriptEditor.copyText(of: "# Script: The Walk #\n\n## 1. Off\nSays:\n- Hi.", title: "The Walk")
        #expect(cutaway.text.hasPrefix("# Script: The Walk (Copy)\n"))
    }

    @Test func aCopyOfTextWithNoTitleLineGetsOne() {
        let copy = ScriptEditor.copyText(of: "The Pier\n\nHello.", title: "The Pier")
        #expect(copy.text == "# The Pier (Copy)\n\nThe Pier\n\nHello.")
        #expect(copy.selection == 17..<17)
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

    @Test func editACopyMakesAScriptOfYourOwn() throws {
        let sample = try ScriptImporter(context: context).add(SampleScript.harbourWalk)
        sample.sampleID = "harbour-walk"
        let editor = ScriptEditor(mode: .copy(of: sample))
        #expect(editor.heading == "Edit a Copy")
        #expect(editor.canSave)
        let copy = try editor.save(in: context)
        #expect(copy !== sample)
        #expect(!copy.isSample)
        #expect(copy.title == "The Harbour Walk (Copy)")
        #expect(copy.format == .cutaway)
        #expect(sample.title == "The Harbour Walk")
        #expect(try context.fetchCount(FetchDescriptor<Script>()) == 2)
    }

    @Test func aSharedFileIsNamedAfterTheTitle() {
        #expect(ScriptText(title: "Walk: 1/2?", text: "").fileName == "Walk 12.md")
        #expect(ScriptText(title: " / ", text: "").fileName == "Script.md")
    }
}
