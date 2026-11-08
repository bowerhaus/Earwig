import Foundation

/// One phrase as the follow engine sees it (plan 003, decision 2): plain values, never a model.
struct FollowPhrase: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// Said by the presenter and followed.
        case spoken
        /// Read in the cue voice and never matched.
        case cue
    }

    let kind: Kind
    /// The script words, in order. Empty for a cue.
    let words: [ScriptWord]
    /// Each word's start in the rendering, in seconds at 1.0x. Same count as `words`.
    let wordStarts: [TimeInterval]
    /// The rendering's length at 1.0x.
    let duration: TimeInterval
    /// The words, by their place in the phrase, after which the script's punctuation lets the
    /// presenter pause: a comma, colon, full stop and the like (plan 008, device check 1).
    let pausesAfter: Set<Int>

    init(kind: Kind, words: [ScriptWord], wordStarts: [TimeInterval], duration: TimeInterval, pausesAfter: Set<Int> = []) {
        precondition(words.count == wordStarts.count, "one start time per word")
        self.kind = kind
        self.words = kind == .cue ? [] : words
        self.wordStarts = kind == .cue ? [] : wordStarts
        self.duration = duration
        self.pausesAfter = kind == .cue ? [] : pausesAfter.filter { words.indices.contains($0) }
    }

    static func cue(duration: TimeInterval) -> FollowPhrase {
        FollowPhrase(kind: .cue, words: [], wordStarts: [], duration: duration)
    }
}

/// The phrases of a take, with every spoken word given one flat index across the take, which is
/// what positions are counted in.
struct FollowScript: Equatable, Sendable {
    let phrases: [FollowPhrase]
    /// Every spoken word of the take, in order.
    let words: [ScriptWord]
    /// The flat index of each phrase's first word. For a cue, or a phrase with no words, the
    /// index of the next word after it.
    let firstWord: [Int]
    /// The flat indices of the words after which the punctuation lets the presenter pause, in
    /// order, each phrase's last word among them.
    let pausesAfter: [Int]

    init(phrases: [FollowPhrase]) {
        self.phrases = phrases
        var words: [ScriptWord] = []
        var firstWord: [Int] = []
        var pauses: [Int] = []
        for phrase in phrases {
            firstWord.append(words.count)
            pauses += phrase.pausesAfter.union(phrase.words.isEmpty ? [] : [phrase.words.count - 1]).sorted().map { words.count + $0 }
            words += phrase.words
        }
        self.words = words
        self.firstWord = firstWord
        pausesAfter = pauses
    }

    /// The first word after the next place the presenter may pause, at or after `word`: where
    /// the screen's place stops coasting until a word beyond it is heard (plan 008). `nil` with
    /// none left.
    func pauseBoundary(after word: Int) -> Int? {
        pausesAfter.first { $0 >= word }.map { $0 + 1 }
    }

    /// The flat indices of a phrase's words; empty for a cue.
    func range(of phrase: Int) -> Range<Int> {
        firstWord[phrase]..<(firstWord[phrase] + phrases[phrase].words.count)
    }

    /// The last word of a phrase, or `nil` for one with no words.
    func lastWord(of phrase: Int) -> Int? {
        let range = range(of: phrase)
        return range.isEmpty ? nil : range.upperBound - 1
    }

    /// The phrase holding a flat word index.
    func phrase(containing word: Int) -> Int? {
        phrases.indices.first { range(of: $0).contains(word) }
    }

    /// The first phrase that starts after a word: the next one the presenter has not begun
    /// (plan 003, decision 11). For a position before any word, the first phrase.
    func firstPhrase(after word: Int) -> Int? {
        phrases.indices.first { firstWord[$0] > word && (phrases[$0].kind == .cue || !phrases[$0].words.isEmpty) }
    }

    /// The last spoken phrase with words before a phrase, whose end gates it.
    func gatingPhrase(before phrase: Int) -> Int? {
        stride(from: phrase - 1, through: 0, by: -1).first { phrases[$0].kind == .spoken && !phrases[$0].words.isEmpty }
    }

    /// The last spoken word of the take, if it has any.
    var lastSpokenWord: Int? { words.isEmpty ? nil : words.count - 1 }

    /// The word being said at an offset into a phrase's rendering, as a flat index. Before the
    /// first word, the first word; a cue gives `nil`.
    func word(in phrase: Int, at offset: TimeInterval) -> Int? {
        let starts = phrases[phrase].wordStarts
        guard !starts.isEmpty else { return nil }
        let inPhrase = starts.lastIndex { $0 <= offset } ?? 0
        return firstWord[phrase] + inPhrase
    }
}
