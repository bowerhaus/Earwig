import Foundation

/// Whether a phrase is said by the presenter or read as a cue.
enum PhraseKind: String, Codable, Sendable {
    /// Read in the presenter's voice and followed.
    case spoken
    /// A `[direction]` inside a line, read in the cue voice and never matched.
    case cue
}

/// One phrase of a step, with the line it came from.
struct StepPhrase: Codable, Equatable, Sendable {
    /// Index into the step's lines.
    var line: Int
    var kind: PhraseKind
    var phrase: Phrase
}

/// A step's phrases, derived at parse time and stored on the step so the engine's indices are
/// stable (PRD §6.1). A list from an older parser is rebuilt from the script's source text.
struct PhraseList: Codable, Equatable, Sendable {
    /// Bump when the splitting or the script words change, so stored lists are rebuilt.
    static let currentVersion = 1

    var parserVersion: Int
    var phrases: [StepPhrase]

    init(parserVersion: Int = PhraseList.currentVersion, phrases: [StepPhrase] = []) {
        self.parserVersion = parserVersion
        self.phrases = phrases
    }

    /// The phrases of a step's lines, in order: inline directions as cue phrases, the rest
    /// split by the phrase splitter.
    init(lines: [String], splitter: PhraseSplitter = PhraseSplitter()) {
        var phrases: [StepPhrase] = []
        for (index, line) in lines.enumerated() {
            for segment in LineText.segments(of: line) {
                switch segment {
                case .spoken(let text):
                    phrases += splitter.phrases(in: text).map { StepPhrase(line: index, kind: .spoken, phrase: $0) }
                case .direction(let text):
                    let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
                    phrases.append(StepPhrase(line: index, kind: .cue, phrase: Phrase(tokens: words)))
                }
            }
        }
        self.init(phrases: phrases)
    }

    var isCurrent: Bool { parserVersion >= Self.currentVersion }

    var spoken: [StepPhrase] { phrases.filter { $0.kind == .spoken } }

    /// The words the presenter says in this step, in order: what the engine matches.
    var scriptWords: [ScriptWord] { spoken.flatMap(\.phrase.scriptWords) }
}
