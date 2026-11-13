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
        /// Edit, on the Script screen or a swipe on the Scripts screen: a sample too (decision 7).
        case edit(Script)
    }

    /// The text and the cursor or selection after a toolbar edit.
    struct Edit: Equatable {
        var text: String
        var selection: Range<Int>
    }

    let mode: Mode
    var text: String {
        didSet { if text != oldValue { checked = ScriptImporter.check(text) } }
    }
    /// The text as the importer sees it, worked out once per change, not on every read of the
    /// line, Save and Cancel (review C8).
    private(set) var checked: Result<ParsedScript, ScriptImporter.ImportError>
    /// Where the cursor starts, as character offsets into `text`.
    let selection: Range<Int>
    /// Where the cursor is now, in characters, as the text view reports it, for the line under
    /// the editor.
    var cursor: Int
    private let original: String

    init(mode: Mode) {
        self.mode = mode
        let start: Edit = switch mode {
        case .new: Edit(text: "# ", selection: 2..<2)
        case .edit(let script): Edit(text: script.sourceText, selection: Self.titleEnd(in: script.sourceText)..<Self.titleEnd(in: script.sourceText))
        }
        text = start.text
        selection = start.selection
        cursor = start.selection.lowerBound
        original = ScriptImporter.cleaned(start.text)
        checked = ScriptImporter.check(start.text)
    }

    /// The sheet's title.
    var heading: String {
        switch mode {
        case .new: "New Script"
        case .edit: "Edit Script"
        }
    }

    /// Whether there is anything to lose on Cancel.
    var hasChanges: Bool { ScriptImporter.cleaned(text) != original }

    /// Whether Save would do something: the text is a script, and an edit has changed it. A
    /// new script saves as it is.
    var canSave: Bool {
        guard case .success = checked else { return false }
        if case .edit = mode { return hasChanges }
        return true
    }

    /// The line under the editor: on a step's heading, what its name is for; otherwise what the
    /// text makes, or how to start, and a named step with nothing to say, which isn't a step.
    var summary: String {
        if let name = Self.stepName(at: cursor, in: text) {
            return name.isEmpty ? Self.nameHint : Self.returnHint
        }
        let silent = Self.silentStep(in: text, apartFrom: cursor).map(Self.silentHint)
        switch checked {
        case .success(let parsed):
            let steps = parsed.steps.count
            let lines = parsed.steps.reduce(0) { $0 + $1.lines.count }
            let count = "\(parsed.title) · \(steps == 1 ? "1 step" : "\(steps) steps") · \(lines == 1 ? "1 line" : "\(lines) lines")"
            return silent.map { count + "\n" + $0 } ?? count
        case .failure:
            return silent ?? Self.hint
        }
    }

    /// How the format works, shown until there is something to say (plan 015, decision 11).
    static let hint = "Type a title, then tap Step for each part. A cue, a stage direction for you, goes in square brackets: [Gesture to the boats]."
    /// On a step's heading with no name yet (plan 015, decision 2, amended on the phone).
    static let nameHint = "Name this step, or press Return to skip the name. A name is shown on the step's card and read in the slate."
    /// On a step's heading with a name.
    static let returnHint = "Press Return to write what you'll say in this step."

    /// A named step with nothing to say: what went wrong on the phone when the words went into
    /// the heading (review C4).
    static func silentHint(_ name: String) -> String {
        "“\(name)” has nothing to say yet. Words on a step's ## line are its name: press Return after it to write what you'll say."
    }

    /// The name on the step heading the cursor is on: empty for none, nil off a step's heading.
    static func stepName(at cursor: Int, in text: String) -> String? {
        let before = text.prefix(cursor).split(separator: "\n", omittingEmptySubsequences: false).last ?? ""
        let after = text.dropFirst(cursor).prefix { $0 != "\n" }
        return PlainParser.stepHeading(String(before + after).trimmingCharacters(in: .whitespaces))
    }

    /// The first step with a name and nothing to say, in a script of the documented format:
    /// the plain parser leaves such a step out. Cutaway's steps can mean to say nothing. The step
    /// the cursor is in is left out, being written (seen in the simulator: Return after a name
    /// brought the warning straight away).
    static func silentStep(in text: String, apartFrom cursor: Int? = nil) -> String? {
        guard ScriptParser.detectFormat(text) == .plain else { return nil }
        let cursorLine = cursor.map { text.prefix($0).count { $0 == "\n" } }
        var name: String?
        var says = false
        var writing = false
        func silent() -> String? {
            guard let name, !name.isEmpty, !says, !writing else { return nil }
            return name
        }
        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let heading = PlainParser.stepHeading(trimmed) {
                if let found = silent() { return found }
                name = heading
                says = false
                writing = false
            } else if PlainParser.titleLine(trimmed) == nil, !trimmed.isEmpty, trimmed.wholeMatch(of: #/\[[^\[\]]*\]/#) == nil {
                says = true
            }
            if index == cursorLine { writing = true }
        }
        return silent()
    }

    /// Saves the text: a new script for New, or the edited script. Returns the
    /// script to show.
    func save(in context: ModelContext) throws -> Script {
        let importer = ScriptImporter(context: context)
        let script: Script = switch mode {
        case .new: try importer.create(text).script
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

    /// Where Edit starts the cursor: the end of the title line, so the title shows which script
    /// this is and typing at once doesn't break its `#` (Andy on the phone: the end of a long
    /// script would scroll away from it). The top with no title line.
    static func titleEnd(in text: String) -> Int {
        let change = titleChange(in: Edit(text: text, selection: 0..<0))
        return change.text.isEmpty ? change.cursor : 0
    }

    /// Title: the cursor to the end of the title line, or a `# ` line added at the top for one.
    static func titleChange(in edit: Edit) -> Change {
        let lines = edit.text.components(separatedBy: "\n")
        if let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           PlainParser.titleLine(lines[first]) != nil {
            let end = lines[...first].reduce(0) { $0 + $1.count + 1 } - 1
            return Change(range: edit.selection.lowerBound..<edit.selection.lowerBound, text: "", cursor: end)
        }
        return Change(range: 0..<0, text: edit.text.isEmpty ? "# " : "# \n\n", cursor: 2)
    }

    /// Step: a new step at the cursor, after a blank line, with the cursor after its `## `, ready
    /// for a name, or Return to skip it (plan 015, decision 2, amended on the phone: the cursor
    /// on the line under the heading looked odd and didn't say why). The line under the editor
    /// says what to do, and names a step whose words all went into its heading. Text after the
    /// cursor goes on the line under the heading.
    static func stepChange(in edit: Edit) -> Change {
        let at = edit.selection.lowerBound
        let before = edit.text.prefix(at)
        let gap = if before.isEmpty || before.hasSuffix("\n\n") { "" } else if before.hasSuffix("\n") { "\n" } else { "\n\n" }
        let restOfLine = edit.text.dropFirst(at).prefix { $0 != "\n" }
        let heading = gap + "## "
        return Change(range: at..<at, text: heading + (restOfLine.isEmpty ? "" : "\n"), cursor: at + heading.count)
    }

    /// Cue: the selection in square brackets with the cursor after them. With none, `[]` with
    /// the cursor between, on a line of its own if tapped at the end of a line with words on it.
    /// Tapped inside a cue, it ends the cue: the cursor goes past the `]`, and for a cue on a line
    /// of its own onto a new line under it.
    static func cueChange(in edit: Edit) -> Change {
        let text = edit.text
        let selection = edit.selection
        if !selection.isEmpty {
            let selected = String(text.dropFirst(selection.lowerBound).prefix(selection.count))
            return Change(range: selection, text: "[" + selected + "]", cursor: selection.lowerBound + selected.count + 2)
        }
        let at = selection.lowerBound
        let before = text.prefix(at)
        let lineBefore = before.split(separator: "\n", omittingEmptySubsequences: false).last ?? ""
        let lineAfter = text.dropFirst(at).prefix { $0 != "\n" }
        if let open = lineBefore.lastIndex(of: "["), !lineBefore[open...].contains("]"),
           let close = lineAfter.firstIndex(of: "]") {
            let ownLine = lineBefore[..<open].allSatisfy(\.isWhitespace)
            if ownLine && lineAfter[lineAfter.index(after: close)...].allSatisfy(\.isWhitespace) {
                let end = at + lineAfter.count
                return Change(range: end..<end, text: "\n", cursor: end + 1)
            }
            return Change(range: at..<at, text: "", cursor: at + lineAfter.distance(from: lineAfter.startIndex, to: close) + 1)
        }
        if lineAfter.allSatisfy(\.isWhitespace) && !lineBefore.allSatisfy(\.isWhitespace) {
            return Change(range: at..<at, text: "\n[]", cursor: at + 2)
        }
        return Change(range: at..<at, text: "[]", cursor: at + 1)
    }

    /// What typing or dictating `inserted` at `at` puts in: its first letter a capital at the
    /// start of a title or a step's name, which the keyboard leaves small after `#` (Andy on the
    /// phone). A cue is left as it is: it needs no capital (Andy). Nil to put it in as it is; a
    /// word like "iPhone" is left.
    static func capitalised(_ inserted: String, at: Int, in text: String) -> String? {
        guard let first = inserted.firstIndex(where: { !$0.isWhitespace }), inserted[first].isLowercase else { return nil }
        let next = inserted.index(after: first)
        if next < inserted.endIndex, inserted[next].isUppercase { return nil }
        let line = String(text.prefix(at).split(separator: "\n", omittingEmptySubsequences: false).last ?? "")
            + inserted[..<first]
        guard line.wholeMatch(of: #/\s*#{1,6}\s+/#) != nil else { return nil }
        return String(inserted[..<first]) + inserted[first].uppercased() + inserted[next...]
    }

    /// Whether the keyboard should give every word a capital (plan 015, the Shift experiment):
    /// anywhere on a title's or a step's line past its `# ` or `## `, so headings are in Title
    /// Case, and at the start of the line under a step's heading. iOS has no way to light Shift,
    /// so there the text view asks the keyboard for words' capitals. The whole line, not only its
    /// start (Andy on the phone): dictation writes its words again with the capitals asked for
    /// at the time, so switching back after the first word took that word's capital away.
    /// `capitalised` stays as the backstop.
    static func wantsCapital(at: Int, in text: String) -> Bool {
        let lines = text.prefix(at).split(separator: "\n", omittingEmptySubsequences: false)
        let line = lines.last ?? ""
        if line.prefixMatch(of: #/\s*#{1,6}\s/#) != nil { return true }
        guard line.isEmpty, lines.count > 1 else { return false }
        return lines[lines.count - 2].wholeMatch(of: #/\s*#{2,6}(?:\s.*)?/#) != nil
    }

    /// The text and cursor once a change is made.
    static func applied(_ change: Change, to text: String) -> Edit {
        Edit(text: String(text.prefix(change.range.lowerBound)) + change.text + String(text.dropFirst(change.range.upperBound)),
             selection: change.cursor..<change.cursor)
    }

    static func title(in edit: Edit) -> Edit { applied(titleChange(in: edit), to: edit.text) }
    static func step(in edit: Edit) -> Edit { applied(stepChange(in: edit), to: edit.text) }
    static func cue(in edit: Edit) -> Edit { applied(cueChange(in: edit), to: edit.text) }

    /// The range kept inside the text, which may have changed since the range was set.
    static func clamped(_ range: Range<Int>, in text: String) -> Range<Int> {
        let count = text.count
        return min(range.lowerBound, count)..<min(range.upperBound, count)
    }
}

extension ScriptEditor: Identifiable {}
