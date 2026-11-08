import Foundation

/// A phrase's timings in its rendering: each script word's start and the length, at 1.0x.
struct PhraseTiming: Equatable, Sendable {
    var wordStarts: [TimeInterval]
    var duration: TimeInterval
}

extension FollowScript {
    /// The engine's input from a step's phrases (plan 003, decision 2). `timing` gives a
    /// phrase's rendering timings by its index in the list; without them (before rendering, and
    /// in tests) words are spaced evenly at `secondsPerWord`, and a cue lasts as long as its words.
    init(phraseList: PhraseList, secondsPerWord: TimeInterval = 0.4, timing: (Int) -> PhraseTiming? = { _ in nil }) {
        let phrases = phraseList.phrases.enumerated().map { index, stepPhrase -> FollowPhrase in
            let words = stepPhrase.phrase.scriptWords
            let even = PhraseTiming(
                wordStarts: words.indices.map { Double($0) * secondsPerWord },
                duration: Double(max(stepPhrase.phrase.tokens.count, 1)) * secondsPerWord
            )
            switch stepPhrase.kind {
            case .cue:
                return .cue(duration: timing(index)?.duration ?? even.duration)
            case .spoken:
                var timed = timing(index) ?? even
                if timed.wordStarts.count != words.count { timed.wordStarts = even.wordStarts }
                return FollowPhrase(kind: .spoken, words: words, wordStarts: timed.wordStarts, duration: timed.duration,
                                    pausesAfter: Self.pauses(in: stepPhrase.phrase))
            }
        }
        self.init(phrases: phrases)
    }

    /// The words of a phrase, by their place among its script words, that punctuation lets the
    /// presenter pause after: one ending a clause or a sentence, or one before a dash.
    static func pauses(in phrase: Phrase) -> Set<Int> {
        var pauses: Set<Int> = []
        var word = -1
        for token in phrase.tokens {
            if token.word != nil {
                word += 1
                if PhraseSplitter.endsSentence(token.text) || PhraseSplitter.endsClause(token.text) { pauses.insert(word) }
            } else if PhraseSplitter.isDash(token.text), word >= 0 {
                pauses.insert(word)
            }
        }
        return pauses
    }
}
