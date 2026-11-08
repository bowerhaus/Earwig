import Foundation

/// A stretch of a recogniser result's text with its audio time range on the analyser's
/// timeline, when it has one: a final has one run per word, an interim one run for many.
struct HeardRun: Equatable, Sendable {
    var text: String
    var start: TimeInterval?
    var duration: TimeInterval?
    var confidence: Double?

    init(_ text: String, start: TimeInterval? = nil, duration: TimeInterval? = nil, confidence: Double? = nil) {
        self.text = text
        self.start = start
        self.duration = duration
        self.confidence = confidence
    }
}

/// A word of a result with its start on the analyser's timeline, exact or estimated.
struct TimedWord: Equatable, Sendable {
    var text: String
    var start: TimeInterval
    var confidence: Double?
}

/// Turns a recogniser result into what the follow engine hears (plan 005, decision 1): a
/// volatile result is its whole text as one `.interim`, the block since the last final; a
/// final is `.final` with each word's start on the host clock. Words are kept as the
/// recogniser wrote them, digits and compounds included: the engine reads them.
enum HeardEvents {

    /// A result's words in order, each with a start: a run's words spread across its range by
    /// letter count, words with no range spread evenly across the result's.
    static func words(in runs: [HeardRun], resultStart: TimeInterval, resultEnd: TimeInterval) -> (words: [TimedWord], untimed: Bool) {
        var words: [TimedWord] = []
        var untimed: [String] = []
        for run in runs {
            let pieces = run.text.split(whereSeparator: \.isWhitespace).map(String.init)
            guard !pieces.isEmpty else { continue }
            guard let start = run.start else {
                untimed += pieces
                continue
            }
            let duration = run.duration ?? 0
            let total = Double(pieces.reduce(0) { $0 + $1.count })
            var before = 0.0
            for piece in pieces {
                words.append(TimedWord(text: piece, start: start + duration * (total > 0 ? before / total : 0), confidence: run.confidence))
                before += Double(piece.count)
            }
        }
        if !untimed.isEmpty {
            let step = max(resultEnd - resultStart, 0) / Double(untimed.count)
            for (index, piece) in untimed.enumerated() {
                words.append(TimedWord(text: piece, start: resultStart + step * Double(index)))
            }
        }
        return (words, !untimed.isEmpty)
    }

    /// The engine's event for a result. `hostTime` maps an analyser time to the host clock.
    static func event(for runs: [HeardRun], isFinal: Bool, resultStart: TimeInterval, resultEnd: TimeInterval,
                      hostTime: (TimeInterval) -> TimeInterval) -> FollowEvent {
        guard isFinal else {
            let text = runs.map(\.text).joined()
            return .interim(text.split(whereSeparator: \.isWhitespace).joined(separator: " "))
        }
        let timed = words(in: runs, resultStart: resultStart, resultEnd: resultEnd).words
        return .final(timed.map { FinalWord(text: $0.text, start: hostTime($0.start)) })
    }
}
