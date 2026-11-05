import Foundation

/// The spike's stand-in for the follow engine (plan 001): where in the script the presenter
/// is, from everything heard so far. Recomputed from scratch on every result, so volatile
/// revisions need no bookkeeping. The real engine (PRD §5) is stage 3.
struct SpikeFollower {
    let script: [String]
    var behind = 8
    var ahead = 10
    /// Forward jumps longer than this need the next heard word to confirm them.
    var freeJump = 3
    /// Misses in a row after which the whole script is searched for a run of three.
    var lostAfter = 6

    struct Result: Equatable {
        /// Index of the last script word matched, or -1 before any.
        var position = -1
        var matched: Set<Int> = []

        /// Share of the script words from the first matched to the last that were heard.
        var accuracy: Double? {
            guard let first = matched.min(), let last = matched.max() else { return nil }
            return Double(matched.count) / Double(last - first + 1)
        }
    }

    func follow(_ heard: [String]) -> Result {
        var result = Result()
        var misses = 0
        var index = 0
        while index < heard.count {
            let word = heard[index]
            let next = index + 1 < heard.count ? heard[index + 1] : nil
            if let match = matchNear(word, next: next, after: result.position) {
                result.position = match
                result.matched.insert(match)
                misses = 0
            } else {
                misses += 1
                if misses >= lostAfter, let found = searchWhole(heard, from: index) {
                    for offset in 0..<3 { result.matched.insert(found + offset) }
                    result.position = found + 2
                    misses = 0
                    index += 3
                    continue
                }
            }
            index += 1
        }
        return result
    }

    /// The script word a heard word stands for, near the current position: a forward match
    /// confirmed by the next heard word first, then a confirmed step back (a restart), then
    /// an unconfirmed forward match no more than `freeJump` ahead.
    private func matchNear(_ word: String, next: String?, after position: Int) -> Int? {
        guard !script.isEmpty else { return nil }
        func confirmed(_ candidate: Int) -> Bool {
            guard let next, candidate + 1 < script.count else { return false }
            return Self.matches(next, script[candidate + 1])
        }
        var unconfirmed: Int?
        let forwardStart = max(0, position + 1)
        let forwardEnd = min(script.count - 1, position + ahead)
        if forwardStart <= forwardEnd {
            for candidate in forwardStart...forwardEnd where Self.matches(word, script[candidate]) {
                if confirmed(candidate) { return candidate }
                if unconfirmed == nil, candidate - position <= freeJump { unconfirmed = candidate }
            }
        }
        let backEnd = max(0, position - behind)
        if position >= 0, backEnd <= position {
            for candidate in stride(from: position, through: backEnd, by: -1)
            where Self.matches(word, script[candidate]) && confirmed(candidate) {
                return candidate
            }
        }
        return unconfirmed
    }

    private func searchWhole(_ heard: [String], from index: Int) -> Int? {
        guard index + 2 < heard.count, script.count >= 3 else { return nil }
        return (0...(script.count - 3)).first { start in
            (0..<3).allSatisfy { Self.matches(heard[index + $0], script[start + $0]) }
        }
    }

    /// Exact, or within one edit for words of five letters or more (PRD §5.3).
    static func matches(_ heard: String, _ scripted: String) -> Bool {
        if heard == scripted { return true }
        guard heard.count >= 5, scripted.count >= 5, abs(heard.count - scripted.count) <= 1 else { return false }
        return editDistance(Array(heard), Array(scripted), limit: 1) <= 1
    }

    private static func editDistance(_ a: [Character], _ b: [Character], limit: Int) -> Int {
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            if current.min()! > limit { return limit + 1 }
            previous = current
        }
        return previous[b.count]
    }
}
