import Foundation
import Observation
import SwiftData

/// The script editor's text, its buttons' edits and saving (plan 015, decisions 2, 3 and 7),
/// apart from the view. Positions are character offsets into `text`, so the buttons' edits are
/// plain functions that tests can call.
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
    /// Where the cursor starts, as character offsets into `text`.
    let selection: Range<Int>
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

    /// A button's edit as a replacement, so the text view can make it through the keyboard's
    /// input system, keeping the keyboard in step and the edit undoable: `range` of the old
    /// text, in characters, becomes `text`, and the cursor goes to `cursor` in the new text.
    struct Change: Equatable {
        var range: Range<Int>
        var text: String
        var cursor: Int
    }

    /// Title: the cursor to the end of the title line, or a `# ` line added at the top for one.
    static func titleChange(in edit: Edit) -> Change {
        let lines = edit.text.components(separatedBy: "\n")
        if let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           lines[first].trimmingCharacters(in: .whitespaces).wholeMatch(of: #/#(?!#)(?:\s.*)?/#) != nil {
            let end = lines[...first].reduce(0) { $0 + $1.count + 1 } - 1
            return Change(range: edit.selection.lowerBound..<edit.selection.lowerBound, text: "", cursor: end)
        }
        return Change(range: 0..<0, text: edit.text.isEmpty ? "# " : "# \n\n", cursor: 2)
    }

    /// Step: a new step at the cursor, after a blank line, with the cursor after its `## ` for
    /// an optional name. A selection is kept, after the heading.
    static func stepChange(in edit: Edit) -> Change {
        let at = edit.selection.lowerBound
        let before = edit.text.prefix(at)
        let after = edit.text.dropFirst(at)
        let gap = if before.isEmpty || before.hasSuffix("\n\n") { "" } else if before.hasSuffix("\n") { "\n" } else { "\n\n" }
        let end = after.isEmpty || after.hasPrefix("\n") ? "" : "\n"
        return Change(range: at..<at, text: gap + "## " + end, cursor: at + gap.count + 3)
    }

    /// Cue: the selection in square brackets with the cursor after them, or `[]` with the cursor
    /// between.
    static func cueChange(in edit: Edit) -> Change {
        let selected = String(edit.text.dropFirst(edit.selection.lowerBound).prefix(edit.selection.count))
        let cursor = edit.selection.lowerBound + (selected.isEmpty ? 1 : selected.count + 2)
        return Change(range: edit.selection, text: "[" + selected + "]", cursor: cursor)
    }

    /// The text and cursor once a change is made.
    static func applied(_ change: Change, to text: String) -> Edit {
        Edit(text: String(text.prefix(change.range.lowerBound)) + change.text + String(text.dropFirst(change.range.upperBound)),
             selection: change.cursor..<change.cursor)
    }

    static func title(in edit: Edit) -> Edit { applied(titleChange(in: edit), to: edit.text) }
    static func step(in edit: Edit) -> Edit { applied(stepChange(in: edit), to: edit.text) }
    static func cue(in edit: Edit) -> Edit { applied(cueChange(in: edit), to: edit.text) }

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
