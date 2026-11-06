import Foundation

/// One script word of a phrase as written, with where it sits in the phrase's text. Usually
/// one written word; a number said in words ("three hundred") is one token over all of them.
struct PhraseToken: Codable, Equatable, Sendable {
    let text: String
    /// The token's UTF-16 range in its phrase's `text`, as speech synthesis markers report it.
    let range: NSRange
    /// `nil` for a token with no letters or digits, such as a dash.
    let word: ScriptWord?
}

/// The unit of playback and gating (PRD §3): part of a line, cut at sentence ends and, where
/// a sentence is too long, at clause breaks.
struct Phrase: Codable, Equatable, Sendable {
    let text: String
    let tokens: [PhraseToken]

    init(tokens words: [String]) {
        var text = ""
        var ranges: [NSRange] = []
        for word in words {
            if !text.isEmpty { text += " " }
            let start = (text as NSString).length
            text += word
            ranges.append(NSRange(location: start, length: (word as NSString).length))
        }
        self.text = text
        self.tokens = ScriptWords.groups(words).map { group in
            let first = ranges[group.tokens.lowerBound]
            let last = ranges[group.tokens.upperBound]
            let range = NSRange(location: first.location, length: NSMaxRange(last) - first.location)
            return PhraseToken(text: (text as NSString).substring(with: range), range: range, word: group.word)
        }
    }

    /// The phrase's script words, in order.
    var scriptWords: [ScriptWord] { tokens.compactMap(\.word) }

    /// The token containing a UTF-16 offset in `text`, for mapping a synthesis marker.
    func tokenIndex(containing location: Int) -> Int? {
        tokens.firstIndex { NSLocationInRange(location, $0.range) }
            ?? tokens.lastIndex { $0.range.location <= location }
    }
}

/// Splits spoken text into phrases of at most `maxWords` words (PRD §3, "Phrase"): first at
/// sentence ends and line breaks, then, for a sentence that is too long, at commas, semicolons,
/// colons and dashes, packing clauses together while they fit. A clause longer than the limit
/// is cut into near-equal pieces.
struct PhraseSplitter {
    var maxWords = 12

    func phrases(in text: String) -> [Phrase] {
        sentences(in: text).flatMap(split).map(Phrase.init(tokens:))
    }

    /// Sentences as word lists. A sentence ends at a word ending in `.`, `!`, `?` or `…`
    /// (ignoring closing quotes and brackets), or at a line break.
    func sentences(in text: String) -> [[String]] {
        var sentences: [[String]] = []
        for line in text.components(separatedBy: .newlines) {
            var current: [String] = []
            for word in line.split(whereSeparator: \.isWhitespace).map(String.init) {
                current.append(word)
                if Self.endsSentence(word) {
                    sentences.append(current)
                    current = []
                }
            }
            if !current.isEmpty { sentences.append(current) }
        }
        return sentences
    }

    /// A run of words that is never broken inside, and how bad a break after it would be.
    private struct Unit {
        let words: [String]
        /// 0 after a semicolon or colon or before a dash, 1 after a comma, 2 inside a clause.
        var breakPenalty: Int
    }

    /// A way of phrasing a sentence, compared field by field: fewer is better in each.
    private struct Score: Comparable {
        let count: Int
        let penalty: Int
        let imbalance: Int

        static func < (a: Score, b: Score) -> Bool {
            (a.count, a.penalty, a.imbalance) < (b.count, b.penalty, b.imbalance)
        }
    }

    /// Splits a sentence choosing, in order: the fewest phrases, then the cleanest breaks
    /// (dash, semicolon or colon before comma, comma before mid-clause), then the most even
    /// lengths.
    private func split(_ sentence: [String]) -> [[String]] {
        guard sentence.count > maxWords else { return [sentence] }
        let units = self.units(of: sentence)
        // best[i]: the best way to phrase units[0..<i], and where its last phrase starts.
        var best: [(score: Score, start: Int)?] = Array(repeating: nil, count: units.count + 1)
        best[0] = (Score(count: 0, penalty: 0, imbalance: 0), 0)
        for end in 1...units.count {
            var length = 0
            for start in stride(from: end - 1, through: 0, by: -1) {
                length += units[start].words.count
                if length > maxWords { break }
                guard let previous = best[start] else { continue }
                let penalty = start == 0 ? 0 : units[start - 1].breakPenalty
                let score = Score(count: previous.score.count + 1, penalty: previous.score.penalty + penalty, imbalance: previous.score.imbalance + length * length)
                if best[end] == nil || score < best[end]!.score {
                    best[end] = (score, start)
                }
            }
        }
        var phrases: [[String]] = []
        var end = units.count
        while end > 0, let entry = best[end] {
            phrases.insert(units[entry.start..<end].flatMap(\.words), at: 0)
            end = entry.start
        }
        return phrases
    }

    private func units(of sentence: [String]) -> [Unit] {
        var units: [Unit] = []
        let clauses = clauses(of: sentence)
        for (index, clause) in clauses.enumerated() {
            let pieces = clause.count > maxWords ? evenPieces(of: clause) : [clause]
            for piece in pieces { units.append(Unit(words: piece, breakPenalty: 2)) }
            guard let last = clause.last else { continue }
            let nextIsDash = index + 1 < clauses.count && clauses[index + 1].first.map(Self.isDash) == true
            let closer = Self.stripTrailingClosers(last).last
            units[units.count - 1].breakPenalty = nextIsDash || closer == ";" || closer == ":" ? 0 : (closer == "," ? 1 : 2)
        }
        return units
    }

    private func clauses(of sentence: [String]) -> [[String]] {
        var clauses: [[String]] = []
        var current: [String] = []
        for word in sentence {
            if Self.isDash(word) {
                if !current.isEmpty { clauses.append(current) }
                current = [word]
                continue
            }
            current.append(word)
            if Self.endsClause(word) {
                clauses.append(current)
                current = []
            }
        }
        if !current.isEmpty { clauses.append(current) }
        return clauses
    }

    private func evenPieces(of words: [String]) -> [[String]] {
        let count = (words.count + maxWords - 1) / maxWords
        let size = (words.count + count - 1) / count
        return stride(from: 0, to: words.count, by: size).map { Array(words[$0..<min($0 + size, words.count)]) }
    }

    private static func stripTrailingClosers(_ word: String) -> Substring {
        var trimmed = Substring(word)
        while let last = trimmed.last, "\"'”’)]".contains(last) { trimmed = trimmed.dropLast() }
        return trimmed
    }

    private static func endsSentence(_ word: String) -> Bool {
        guard let last = stripTrailingClosers(word).last else { return false }
        return ".!?…".contains(last)
    }

    private static func endsClause(_ word: String) -> Bool {
        guard let last = stripTrailingClosers(word).last else { return false }
        return ",;:".contains(last)
    }

    private static func isDash(_ word: String) -> Bool {
        ["-", "–", "—", "--"].contains(word)
    }
}
