import Foundation

/// A word as heard, with when it first appeared on the engine clock.
struct HeardScriptWord: Equatable, Sendable {
    var word: ScriptWord
    var heardAt: TimeInterval
}

/// Where the matcher has the presenter (PRD §5.3, plan 003 decisions 5 to 7). Positions are
/// flat script word indices; -1 is before the first word.
struct MatchState: Equatable, Sendable {
    /// The last script word matched, tentatively or confidently.
    var last = -1
    /// The last script word matched as part of a run long enough to trust.
    var confident = -1
    /// When the heard word that set `confident` first appeared.
    var confidentAt: TimeInterval?
    /// Script words matched in the current run.
    var run = 0
    /// Heard words since the last match.
    var sinceMatch = 0
    /// Unmatched heard words since the last run long enough to trust, and when the first came.
    var unmatched = 0
    var firstUnmatchedAt: TimeInterval?
    var lost = false

    /// Where the next heard word is expected: the last match advanced by the words heard since.
    var expected: Int { last + sinceMatch + 1 }
}

/// Aligns heard words with the script words of a take. Pure: the same words from the same state
/// give the same result, so an interim block is re-aligned whole every time it is rewritten.
struct Matcher: Sendable {
    let words: [ScriptWord]
    let settings: FollowSettings

    /// One way to read the heard word at a position.
    private struct Candidate {
        /// First script word matched, and how many.
        let script: Int
        let scriptCount: Int
        /// Heard words used.
        let heardCount: Int
        let strength: MatchStrength
        let continues: Bool
        let confirmed: Bool
        let distance: Int
        let ahead: Bool

        /// Better first: continues the run, confirmed by the next heard word, exact, nearest,
        /// ahead before behind.
        func isBetter(than other: Candidate) -> Bool {
            if continues != other.continues { return continues }
            if confirmed != other.confirmed { return confirmed }
            if strength != other.strength { return strength > other.strength }
            if distance != other.distance { return distance < other.distance }
            if ahead != other.ahead { return ahead }
            return script < other.script
        }
    }

    /// The state after hearing `heard` from `state`. `prefixLast` allows the last word to be
    /// digits still building up, as in an interim result.
    func align(_ heard: [HeardScriptWord], from state: MatchState, prefixLast: Bool) -> MatchState {
        var state = state
        var index = 0
        while index < heard.count {
            if let candidate = best(at: index, in: heard, state: state, prefixLast: prefixLast) {
                apply(candidate, heardAt: heard[index + candidate.heardCount - 1].heardAt, to: &state)
                index += candidate.heardCount
            } else {
                miss(heard[index], in: &state)
                index += 1
            }
        }
        return state
    }

    // MARK: - Candidates

    private func window(for state: MatchState) -> ClosedRange<Int>? {
        guard !words.isEmpty else { return nil }
        if state.lost { return 0...(words.count - 1) }
        let low = max(0, state.expected - settings.windowBehind)
        let high = min(words.count - 1, state.expected + settings.windowAhead)
        return low <= high ? low...high : nil
    }

    private func continues(_ script: Int, _ state: MatchState) -> Bool {
        guard state.run > 0 else { return false }
        switch state.sinceMatch {
        case 0: return script == state.last + 1 || script == state.last + 2 // one script word dropped
        case 1: return script == state.last + 2 // one word misheard
        default: return false
        }
    }

    private func best(at index: Int, in heard: [HeardScriptWord], state: MatchState, prefixLast: Bool) -> Candidate? {
        guard let window = window(for: state) else { return nil }
        let word = heard[index].word
        let next = index + 1 < heard.count ? heard[index + 1].word : nil
        let allowPrefix = prefixLast && index == heard.count - 1
        var best: Candidate?

        func consider(script: Int, scriptCount: Int, heardCount: Int, strength: MatchStrength) {
            let after = index + heardCount
            let end = script + scriptCount
            var confirmed = false
            if after < heard.count {
                for target in [end, end + 1] where target < words.count {
                    if WordFolding.match(heard[after].word, words[target], allowPrefix: prefixLast && after == heard.count - 1) != nil {
                        confirmed = true
                        break
                    }
                }
            }
            let candidate = Candidate(
                script: script, scriptCount: scriptCount, heardCount: heardCount, strength: strength,
                continues: continues(script, state), confirmed: confirmed,
                distance: abs(script - state.expected), ahead: script >= state.expected
            )
            if best.map({ candidate.isBetter(than: $0) }) ?? true { best = candidate }
        }

        for script in window {
            if let strength = WordFolding.match(word, words[script], allowPrefix: allowPrefix) {
                consider(script: script, scriptCount: 1, heardCount: 1, strength: strength)
            }
            if script + 1 < words.count, WordFolding.matchesPair(word, words[script], words[script + 1]) {
                consider(script: script, scriptCount: 2, heardCount: 1, strength: .exact)
            }
            if let next, WordFolding.matchesPair(words[script], word, next) {
                consider(script: script, scriptCount: 1, heardCount: 2, strength: .exact)
            }
        }
        // A word that would leave the run, when the word heard after it carries the run on as if
        // this one were misheard: a misreading, not a jump. "Salt on the side" for "salt on one
        // side" took "the side" for "the other side" in the next line and jumped seven words
        // (device check 7 of plan 005).
        if let found = best, !found.continues, state.run > 0, state.sinceMatch == 0, let next,
           state.last + 2 < words.count,
           WordFolding.match(next, words[state.last + 2], allowPrefix: prefixLast && index + 1 == heard.count - 1) != nil {
            return nil
        }
        return best
    }

    // MARK: - State

    private func apply(_ candidate: Candidate, heardAt: TimeInterval, to state: inout MatchState) {
        state.run = candidate.continues ? state.run + candidate.scriptCount : candidate.scriptCount
        state.last = candidate.script + candidate.scriptCount - 1
        state.sinceMatch = 0
        let needed = state.lost ? settings.lostRun : settings.run
        if state.run >= needed {
            state.confident = state.last
            state.confidentAt = heardAt
            state.unmatched = 0
            state.firstUnmatchedAt = nil
            state.lost = false
        }
    }

    /// An unmatched word: dropped, but counted towards being lost. A single tentative match
    /// does not reset the count, so a stray "the" in off-script talk does not keep it found.
    private func miss(_ word: HeardScriptWord, in state: inout MatchState) {
        state.sinceMatch = min(state.sinceMatch + 1, settings.lostWords)
        state.unmatched += 1
        let first = state.firstUnmatchedAt ?? word.heardAt
        state.firstUnmatchedAt = first
        if state.unmatched >= settings.lostWords || word.heardAt - first >= settings.lostSeconds {
            state.lost = true
        }
    }
}
