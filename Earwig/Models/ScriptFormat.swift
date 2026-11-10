import Foundation

/// Where a script's text came from, detected on paste (PRD §4.1).
enum ScriptFormat: String, Codable, CaseIterable, Sendable {
    /// A Cutaway project's `script.md` (`cutaway/script@1`).
    case cutaway
    case plain
}

/// Text in a step that the presenter does not say (PRD §3, "Direction"; a cue where users see
/// it, plan 015, decision 11). Never matched; the title, `Shows:` and a step's opening cue are
/// read with the slate at the start of a take.
struct Direction: Codable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case shows, footage, open, notes
        /// A plain script's line wholly in square brackets before its first spoken line
        /// (plan 015, decision 4).
        case cue
        /// A line the parser did not understand, kept as it was.
        case unknown
    }

    var kind: Kind
    var text: String

    /// The label shown before the text, as the field is named in the script.
    var label: String? {
        switch kind {
        case .shows: "Shows"
        case .footage: "Footage"
        case .open: "Open"
        case .notes: "Notes"
        case .cue, .unknown: nil
        }
    }
}

/// A piece of a line: words the presenter says, or a direction in square brackets inside the
/// line ("[Gesture to the boats]"), read in the cue voice at that point.
enum LineSegment: Equatable, Sendable {
    case spoken(String)
    case direction(String)
}
