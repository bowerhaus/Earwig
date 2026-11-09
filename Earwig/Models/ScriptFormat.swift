import Foundation

/// Where a script's text came from, detected on paste (PRD §4.1).
enum ScriptFormat: String, Codable, CaseIterable, Sendable {
    /// A Cutaway project's `script.md` (`cutaway/script@1`).
    case cutaway
    case plain

    /// Shown to the presenter. The format is Cutaway's, but Cutaway is not published, so the app
    /// calls it what it is (plan 011, decision 13).
    var label: String {
        switch self {
        case .cutaway: "Markdown"
        case .plain: "Plain text"
        }
    }
}

/// Text in a step that the presenter does not say (PRD §3, "Direction"). Never matched; the
/// title and `Shows:` are read as cues at the start of a step (stage 5).
struct Direction: Codable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case shows, footage, open, notes
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
        case .unknown: nil
        }
    }
}

/// A piece of a line: words the presenter says, or a direction in square brackets inside the
/// line ("[Gesture to the boats]"), read in the cue voice at that point.
enum LineSegment: Equatable, Sendable {
    case spoken(String)
    case direction(String)
}
