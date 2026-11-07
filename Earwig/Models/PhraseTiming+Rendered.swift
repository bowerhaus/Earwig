import Foundation

extension PhraseTiming {
    /// A phrase's timings from its rendering (plan 004, decision 4): one start per script word,
    /// from the token it was read from. A token no marker named takes a start spaced evenly
    /// between its timed neighbours (or the phrase's start and end), so a missing marker never
    /// shifts the other words. A token with no word (a dash) is timed but has no script word.
    init(phrase: Phrase, tokenStarts: [TimeInterval?], duration: TimeInterval) {
        let count = phrase.tokens.count
        var starts = (0..<count).map { $0 < tokenStarts.count ? tokenStarts[$0] : nil }
        var index = 0
        while index < count {
            guard starts[index] == nil else {
                index += 1
                continue
            }
            var end = index
            while end + 1 < count, starts[end + 1] == nil { end += 1 }
            let gap = end - index + 1
            let next = end + 1 < count ? starts[end + 1]! : duration
            if index == 0 {
                // From the phrase's start: the first missing token starts at 0.
                for k in 0..<gap { starts[index + k] = next * Double(k) / Double(gap) }
            } else {
                let previous = starts[index - 1]!
                for k in 0..<gap { starts[index + k] = previous + (next - previous) * Double(k + 1) / Double(gap + 1) }
            }
            index = end + 1
        }
        // Markers in order are the rule; keep the starts from ever going backwards.
        var timed: [TimeInterval] = []
        var latest = 0.0
        for (token, start) in zip(phrase.tokens, starts) {
            latest = max(latest, start ?? latest)
            if token.word != nil { timed.append(latest) }
        }
        self.init(wordStarts: timed, duration: duration)
    }
}
