import Foundation

/// A script as parsed from pasted text, before it is stored (PRD §4.1).
struct ParsedScript: Equatable, Sendable {
    var title: String
    /// Whether the text states its title (a `# ` line, or a plain script's lone title line),
    /// rather than it being taken from a first line or first step. Only a stated title
    /// matches a stored script on re-paste.
    var titleIsStated: Bool
    var format: ScriptFormat
    /// Cutaway text before the first step: kept and shown, never spoken.
    var preamble: String?
    var steps: [ParsedStep]

    /// Whether any step has a word the presenter says.
    var hasSpokenWords: Bool {
        steps.contains { step in
            step.lines.contains { line in
                LineText.segments(of: line).contains { segment in
                    if case .spoken(let text) = segment { return !ScriptWords.words(in: text).isEmpty }
                    return false
                }
            }
        }
    }
}

struct ParsedStep: Equatable, Sendable {
    /// As the heading numbers it, or its place when it has no number.
    var number: Int
    /// Empty when the step has none.
    var title: String
    var directions: [Direction] = []
    /// Spoken lines in order, as written, with any `[direction]` still inside them and a
    /// Cutaway source span removed.
    var lines: [String] = []
}

/// Text to steps, lines and directions, in either format (PRD §4.1, §7.2).
enum ScriptParser {

    static func parse(_ text: String) -> ParsedScript {
        let normalised = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        switch detectFormat(normalised) {
        case .cutaway: return CutawayParser.parse(normalised)
        case .plain: return PlainParser.parse(normalised)
        }
    }

    /// Cutaway when the text has a `## ` heading and a `Says:` field; plain otherwise.
    static func detectFormat(_ text: String) -> ScriptFormat {
        let lines = text.components(separatedBy: .newlines)
        let hasHeading = lines.contains { $0.wholeMatch(of: CutawayParser.heading) != nil }
        let hasSays = lines.contains { line in
            line.wholeMatch(of: CutawayParser.field).map { $0.1.lowercased() == "says" } ?? false
        }
        return hasHeading && hasSays ? .cutaway : .plain
    }
}

/// Splits a line into spoken text and `[square-bracketed]` directions (plan 002, decision 4).
enum LineText {

    static func segments(of line: String) -> [LineSegment] {
        var segments: [LineSegment] = []
        var rest = Substring(line)
        while let open = rest.firstIndex(of: "[") {
            guard let close = rest[open...].firstIndex(of: "]") else { break }
            append(.spoken(String(rest[..<open])), to: &segments)
            append(.direction(String(rest[rest.index(after: open)..<close])), to: &segments)
            rest = rest[rest.index(after: close)...]
        }
        append(.spoken(String(rest)), to: &segments)
        return segments
    }

    /// The line without its directions, as the presenter says it.
    static func spoken(_ line: String) -> String {
        segments(of: line).compactMap { segment in
            if case .spoken(let text) = segment { return text }
            return nil
        }.joined(separator: " ")
    }

    private static func append(_ segment: LineSegment, to segments: inout [LineSegment]) {
        switch segment {
        case .spoken(let text), .direction(let text):
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            if case .spoken = segment { segments.append(.spoken(trimmed)) } else { segments.append(.direction(trimmed)) }
        }
    }
}

/// Cutaway's `script.md` (`cutaway/script@1`), read as Cutaway's own `pipeline/script.py`
/// reads it, but leniently: a misnumbered or unnumbered step is kept, not an error.
enum CutawayParser {

    static var title: Regex<(Substring, Substring)> { #/#\s+(?:[Ss][Cc][Rr][Ii][Pp][Tt]:\s*)?(.*?)\s*#*\s*/# }
    static var heading: Regex<(Substring, Substring)> { #/##(?!#)\s*(.*?)\s*#*\s*/# }
    // swiftlint:disable:next large_tuple
    static var numbered: Regex<(Substring, Substring, Substring?)> { #/(\d+)\s*[.):]?(?:\s+(.*))?/# }
    // swiftlint:disable:next large_tuple
    static var field: Regex<(Substring, Substring, Substring)> {
        #/\*{0,2}(shows|footage|says|open|notes)\*{0,2}\s*:\s*\*{0,2}\s*(.*?)\s*/#.ignoresCase()
    }
    static var item: Regex<(Substring, Substring)> { #/\s*[-*+]\s+(.*\S)\s*/# }
    /// A line's source span at its end: `(0005 28.2-41.0)`.
    static var source: Regex<Substring> { #/\s*\(\s*\S+\s+\d+(?:\.\d+)?\s*[-–]\s*\d+(?:\.\d+)?\s*\)\s*$/# }
    static var nothing: Regex<Substring> { #/(?:none|none yet|nothing|nothing yet)\.?/#.ignoresCase() }

    private enum Field: String {
        case shows, footage, says, open, notes
    }

    /// One step's text while it is being read.
    private struct Draft {
        var number: Int?
        var title: String
        var shows: [String] = []
        var footage: [String] = []
        var open: [String] = []
        var notes: [String] = []
        var says: [String] = []
        var unknown: [String] = []
        /// The field the lines being read belong to.
        var current: Field?

        /// Reads one line of the step's body.
        mutating func read(_ line: String) {
            if let match = line.wholeMatch(of: CutawayParser.field), let named = Field(rawValue: match.1.lowercased()) {
                start(named, rest: String(match.2))
                return
            }
            if current == .open || current == .notes {
                // Free text: every line until the next field or step, blank ones included.
                if current == .open { open.append(line) } else { notes.append(line) }
                return
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            let indented = line.first?.isWhitespace == true
            if current == .says, let match = line.wholeMatch(of: CutawayParser.item) {
                says.append(String(match.1))
            } else if indented, runOn(trimmed) {
                return
            } else {
                unknown.append(trimmed)
            }
        }

        private mutating func start(_ field: Field, rest: String) {
            current = field
            switch field {
            case .says:
                if !rest.isEmpty, rest.wholeMatch(of: CutawayParser.nothing) == nil { says.append(rest) }
            case .shows: shows.append(rest)
            case .footage: footage.append(rest)
            case .open: open.append(rest)
            case .notes: notes.append(rest)
            }
        }

        /// Joins an indented line to the item or field before it, if there is one.
        private mutating func runOn(_ text: String) -> Bool {
            switch current {
            case .says where !says.isEmpty: says[says.count - 1] += " " + text
            case .shows where !shows.isEmpty: shows.append(text)
            case .footage where !footage.isEmpty: footage.append(text)
            default: return false
            }
            return true
        }

        func finished(place: Int) -> ParsedStep {
            var directions: [Direction] = []
            func add(_ kind: Direction.Kind, _ lines: [String], separator: String) {
                let text = lines.joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { directions.append(Direction(kind: kind, text: text)) }
            }
            add(.shows, shows, separator: " ")
            add(.footage, footage, separator: " ")
            add(.open, open, separator: "\n")
            add(.notes, notes, separator: "\n")
            directions += unknown.map { Direction(kind: .unknown, text: $0) }
            let lines = says.map { line in
                line.replacing(CutawayParser.source, with: "").trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
            return ParsedStep(number: number ?? place, title: title, directions: directions, lines: lines)
        }
    }

    static func parse(_ text: String) -> ParsedScript {
        var title: String?
        var preamble: [String] = []
        var steps: [ParsedStep] = []
        var draft: Draft?

        for line in text.components(separatedBy: "\n") {
            if let match = line.wholeMatch(of: heading) {
                if let draft { steps.append(draft.finished(place: steps.count + 1)) }
                let headingText = String(match.1)
                if let numberedMatch = headingText.wholeMatch(of: numbered) {
                    draft = Draft(number: Int(numberedMatch.1), title: String(numberedMatch.2 ?? ""))
                } else {
                    draft = Draft(number: nil, title: headingText)
                }
            } else if draft != nil {
                draft?.read(line)
            } else if title == nil, let match = line.wholeMatch(of: Self.title) {
                // Cutaway takes a title only before any preamble; Earwig takes the first.
                title = String(match.1)
            } else {
                preamble.append(line)
            }
        }
        if let draft { steps.append(draft.finished(place: steps.count + 1)) }

        let preambleText = preamble.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let named = title.flatMap { $0.isEmpty ? nil : $0 }
            ?? steps.first.map { $0.title.isEmpty ? "Untitled script" : $0.title }
            ?? "Untitled script"
        return ParsedScript(
            title: named,
            titleIsStated: title.map { !$0.isEmpty } ?? false,
            format: .cutaway,
            preamble: preambleText.isEmpty ? nil : preambleText,
            steps: steps
        )
    }
}

/// Plain text, the format Earwig documents (PRD §4.1; plan 015, decision 4): a `# ` line is the
/// title; a `## ` line starts a step, with its name, and blank lines inside a step are only
/// spacing; with no `## ` line at all, each paragraph is a step. A line wholly in square
/// brackets before a step's first spoken line is the step's cue, read before the take. A first
/// paragraph that is one short title-like line, with more after it, is the script's title.
/// Step names come only from headings: a short first line is spoken, never taken as a name.
enum PlainParser {

    static let maxTitleWords = 8
    static let maxScriptTitleLength = 40

    /// A step as it is read: its name from a heading, if any, and its lines.
    private struct Block {
        var title = ""
        var lines: [String] = []
    }

    static func parse(_ text: String) -> ParsedScript {
        var lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        var scriptTitle: String?
        // A bare `#`, as New starts with before a title is typed, names nothing and is not spoken.
        if let first = lines.firstIndex(where: { !$0.isEmpty }), let title = titleLine(lines[first]) {
            scriptTitle = title.isEmpty ? nil : title
            lines.remove(at: first)
        }

        var blocks = lines.contains { stepHeading($0) != nil }
            ? headedBlocks(lines, mayHoldTitle: scriptTitle == nil)
            : paragraphs(lines)
        // A first paragraph that is one short title-like line names the script, and is not a step.
        if scriptTitle == nil, blocks.count > 1, let first = blocks.first, first.title.isEmpty, first.lines.count == 1,
           isTitle(first.lines[0]) {
            scriptTitle = first.lines[0]
            blocks.removeFirst()
        }

        let steps = blocks.compactMap { block -> ParsedStep? in
            var body = block.lines.map { $0.replacing(#/^[-*+]\s+/#, with: "") }.filter { !$0.isEmpty }
            var directions: [Direction] = []
            while let first = body.first, let cue = first.wholeMatch(of: #/\[([^\[\]]*)\]/#) {
                let text = cue.1.trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { directions.append(Direction(kind: .cue, text: text)) }
                body.removeFirst()
            }
            guard !body.isEmpty else { return nil }
            return ParsedStep(number: 0, title: block.title, directions: directions, lines: body)
        }
        .enumerated().map { index, step in
            var step = step
            step.number = index + 1
            return step
        }

        // The first line with words, a heading's name or a line; never a bare `##` (review C1).
        let firstLine = lines.lazy.map { stepHeading($0) ?? $0 }.first { !$0.isEmpty }
        let fallback = firstLine.map(shortened) ?? "Untitled script"
        return ParsedScript(title: scriptTitle ?? fallback, titleIsStated: scriptTitle != nil, format: .plain, preamble: nil, steps: steps)
    }

    /// Steps by `## ` headings. Text before the first heading is a step with no name, so nothing
    /// written to be said is quietly never said; its first paragraph may still be the title when
    /// no `# ` line has given one (review C2).
    private static func headedBlocks(_ lines: [String], mayHoldTitle: Bool) -> [Block] {
        var blocks: [Block] = []
        var before: [String] = []
        var current: Block?
        for line in lines {
            if let heading = stepHeading(line) {
                if let current { blocks.append(current) }
                current = Block(title: heading)
            } else if current != nil {
                if !line.isEmpty { current?.lines.append(line) }
            } else {
                before.append(line)
            }
        }
        if let current { blocks.append(current) }
        return paragraphs(before).isEmpty ? blocks : leading(before, mayHoldTitle: mayHoldTitle) + blocks
    }

    /// The text before the first heading: its first paragraph alone if it could be the title,
    /// then the rest as one step.
    private static func leading(_ lines: [String], mayHoldTitle: Bool) -> [Block] {
        let paras = paragraphs(lines)
        guard let first = paras.first else { return [] }
        if mayHoldTitle, first.lines.count == 1, isTitle(first.lines[0]) {
            let rest = paras.dropFirst().flatMap(\.lines)
            return [first] + (rest.isEmpty ? [] : [Block(lines: rest)])
        }
        return [Block(lines: paras.flatMap(\.lines))]
    }

    /// Blank-line-separated paragraphs, each a step with no name.
    private static func paragraphs(_ lines: [String]) -> [Block] {
        var blocks: [Block] = [Block()]
        for line in lines {
            if line.isEmpty {
                if !(blocks.last?.lines.isEmpty ?? true) { blocks.append(Block()) }
            } else {
                blocks[blocks.count - 1].lines.append(line)
            }
        }
        return blocks.filter { !$0.lines.isEmpty }
    }

    /// A title line's title ("# The Pier" is "The Pier"; a bare "#", as New starts with, is ""),
    /// or nil. The parser and the editor's Title button share it (review C7).
    static func titleLine(_ line: String) -> String? {
        line.trimmingCharacters(in: .whitespaces).wholeMatch(of: #/#(?!#)(?:\s+(.*?))?\s*#*/#).map { String($0.1 ?? "") }
    }

    /// A step heading's name ("## The sea wall" is "The sea wall"; a bare "##" is ""), or nil.
    static func stepHeading(_ line: String) -> String? {
        line.wholeMatch(of: #/#{2,6}(?:\s+(.*?))?\s*#*/#).map { String($0.1 ?? "") }
    }

    static func isTitle(_ line: String) -> Bool {
        let words = line.split(whereSeparator: \.isWhitespace)
        guard words.count <= maxTitleWords, let last = line.last else { return false }
        return !".!?…,;".contains(last) && !line.contains("[")
    }

    /// The first line cut to `maxScriptTitleLength` characters at a word.
    static func shortened(_ line: String) -> String {
        guard line.count > maxScriptTitleLength else { return line }
        var result = ""
        for word in line.split(whereSeparator: \.isWhitespace) {
            let next = result.isEmpty ? String(word) : result + " " + word
            if next.count > maxScriptTitleLength { break }
            result = next
        }
        let cut = result.isEmpty ? String(line.prefix(maxScriptTitleLength)) : result
        return cut.trimmingCharacters(in: CharacterSet(charactersIn: ",;:—– ")) + "…"
    }
}
