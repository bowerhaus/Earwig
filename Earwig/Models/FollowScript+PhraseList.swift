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
                return FollowPhrase(kind: .spoken, words: words, wordStarts: timed.wordStarts, duration: timed.duration)
            }
        }
        self.init(phrases: phrases)
    }
}
