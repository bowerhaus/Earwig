import Foundation
import Observation
import SwiftData

/// The script editor's text, its keyboard toolbar's edits and saving (plan 015, decisions 2, 3
/// and 7), apart from the view. Positions are character offsets into `text`, so the toolbar's
/// edits are plain functions that tests can call.
@MainActor
@Observable
final class ScriptEditor {
    enum Mode {
        /// New on the Scripts screen.
        case new
        /// Edit on the Script screen of a script of the presenter's own.
        case edit(Script)
        /// Edit a Copy on a sample's Script screen: saved as a new script of the presenter's own.
        case copy(of: Script)
    }

    /// The text and the cursor or selection after a toolbar edit.
    struct Edit: Equatable {
        var text: String
        var selection: Range<Int>
    }

    let mode: Mode
    var text: String
    /// The cursor, or the selection, as character offsets into `text`.
    var selection: Range<Int>
    private let original: String

    init(mode: Mode) {
        self.mode = mode
        let start: Edit = switch mode {
        case .new: Edit(text: "# ", selection: 2..<2)
        case .edit(let script): Edit(text: script.sourceText, selection: 0..<0)
        case .copy(let script): Self.copyText(of: script.sourceText, title: script.title)
        }
        text = start.text
        selection = start.selection
        original = start.text
    }

    /// The sheet's title.
    var heading: String {
        switch mode {
        case .new: "New Script"
        case .edit: "Edit Script"
        case .copy: "Edit a Copy"
        }
    }

    /// Whether there is anything to lose on Cancel.
    var hasChanges: Bool { ScriptImporter.cleaned(text) != ScriptImporter.cleaned(original) }

    /// Whether Save would do something: the text is a script, and an edit has changed it. A
    /// new script or a copy saves as it is.
    var canSave: Bool {
        guard case .success = ScriptImporter.check(text) else { return false }
        if case .edit = mode { return hasChanges }
        return true
    }

    /// The line under the editor: what the text makes, or how to start.
    var summary: String {
        switch ScriptImporter.check(text) {
        case .success(let parsed):
            let steps = parsed.steps.count
            let lines = parsed.steps.reduce(0) { $0 + $1.lines.count }
            return "\(parsed.title) · \(steps == 1 ? "1 step" : "\(steps) steps") · \(lines == 1 ? "1 line" : "\(lines) lines")"
        case .failure:
            return Self.hint
        }
    }

    /// How the format works, shown until there is something to say (plan 015, decision 11).
    static let hint = "Type a title, then tap Step for each part. A cue, a stage direction for you, goes in square brackets: [Gesture to the boats]."

    func addTitle() { apply(Self.title(in:)) }
    func addStep() { apply(Self.step(in:)) }
    func addCue() { apply(Self.cue(in:)) }

    private func apply(_ change: (Edit) -> Edit) {
        let edited = change(Edit(text: text, selection: Self.clamped(selection, in: text)))
        text = edited.text
        selection = edited.selection
    }

    /// Saves the text: a new script for New and Edit a Copy, or the edited script. Returns the
    /// script to show.
    func save(in context: ModelContext) throws -> Script {
        let importer = ScriptImporter(context: context)
        let script: Script = switch mode {
        case .new, .copy: try importer.create(text).script
        case .edit(let script): try importer.edit(script, with: text).script
        }
        try context.save()
        return script
    }

    // MARK: The toolbar's edits

    /// Title: the cursor to the end of the title line, or a `# ` line added at the top for one.
    static func title(in edit: Edit) -> Edit {
        let lines = edit.text.components(separatedBy: "\n")
        if let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           lines[first].trimmingCharacters(in: .whitespaces).wholeMatch(of: #/#(?!#)(?:\s.*)?/#) != nil {
            let end = lines[...first].reduce(0) { $0 + $1.count + 1 } - 1
            return Edit(text: edit.text, selection: end..<end)
        }
        let added = edit.text.isEmpty ? "# " : "# \n\n" + edit.text
        return Edit(text: added, selection: 2..<2)
    }

    /// Step: a new step at the cursor, after a blank line, with the cursor after its `## ` for
    /// an optional name. A selection is kept, after the heading.
    static func step(in edit: Edit) -> Edit {
        let before = String(edit.text.prefix(edit.selection.lowerBound))
        let after = String(edit.text.dropFirst(edit.selection.lowerBound))
        let gap = if before.isEmpty || before.hasSuffix("\n\n") { "" } else if before.hasSuffix("\n") { "\n" } else { "\n\n" }
        let end = after.isEmpty || after.hasPrefix("\n") ? "" : "\n"
        let cursor = before.count + gap.count + 3
        return Edit(text: before + gap + "## " + end + after, selection: cursor..<cursor)
    }

    /// Cue: the selection in square brackets with the cursor after them, or `[]` with the cursor
    /// between.
    static func cue(in edit: Edit) -> Edit {
        let before = String(edit.text.prefix(edit.selection.lowerBound))
        let selected = String(edit.text.dropFirst(edit.selection.lowerBound).prefix(edit.selection.count))
        let after = String(edit.text.dropFirst(edit.selection.upperBound))
        let cursor = selected.isEmpty ? before.count + 1 : before.count + selected.count + 2
        return Edit(text: before + "[" + selected + "]" + after, selection: cursor..<cursor)
    }

    /// A sample's text with "(Copy)" after its title, so the copy is never the sample's own text,
    /// which would open the sample (plan 015, decision 7). The cursor is at the title's end.
    static func copyText(of text: String, title: String) -> Edit {
        var lines = text.components(separatedBy: "\n")
        if let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           lines[first].wholeMatch(of: #/\s*#(?!#)\s+.*/#) != nil {
            lines[first] = lines[first].replacing(#/\s*#*\s*$/#, with: "") + " (Copy)"
            let end = lines[...first].reduce(0) { $0 + $1.count + 1 } - 1
            return Edit(text: lines.joined(separator: "\n"), selection: end..<end)
        }
        let heading = "# \(title) (Copy)"
        return Edit(text: heading + "\n\n" + text, selection: heading.count..<heading.count)
    }

    /// The range kept inside the text, which may have changed since the range was set.
    static func clamped(_ range: Range<Int>, in text: String) -> Range<Int> {
        let count = text.count
        return min(range.lowerBound, count)..<min(range.upperBound, count)
    }
}

extension ScriptEditor: Identifiable {}
