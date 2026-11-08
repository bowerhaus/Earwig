import Foundation

/// Where the presenter is now, rather than where the recogniser last heard them (PRD §5.4,
/// plan 003 decision 8), from the recogniser's measured delay and the presenter's measured
/// speaking rate.
struct PresenterEstimate: Equatable, Sendable {
    let settings: FollowSettings
    private var delays: [TimeInterval] = []
    /// Start times of recent final words.
    private var finalStarts: [TimeInterval] = []

    init(settings: FollowSettings) {
        self.settings = settings
    }

    /// The recogniser's delay: the median of recent first appearances against the finals' start
    /// times, or the default before any.
    var delay: TimeInterval {
        guard !delays.isEmpty else { return settings.defaultDelay }
        let sorted = delays.sorted()
        let middle = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
        return min(max(median, settings.delayRange.lowerBound), settings.delayRange.upperBound)
    }

    /// Words a second over the recent finals, pauses taken out, or the default before enough.
    var rate: Double {
        var spoken: TimeInterval = 0
        var gaps = 0
        for (earlier, later) in zip(finalStarts, finalStarts.dropFirst()) {
            let gap = later - earlier
            guard gap > 0, gap <= settings.rateMaxGap else { continue }
            spoken += gap
            gaps += 1
        }
        guard gaps >= 4, spoken > 0 else { return settings.defaultRate }
        return min(max(Double(gaps) / spoken, settings.rateRange.lowerBound), settings.rateRange.upperBound)
    }

    mutating func recordDelay(_ delay: TimeInterval) {
        delays.append(delay)
        if delays.count > settings.delaySamples { delays.removeFirst(delays.count - settings.delaySamples) }
    }

    mutating func recordFinalStarts(_ starts: [TimeInterval]) {
        finalStarts += starts
        finalStarts.sort()
        guard let latest = finalStarts.last else { return }
        finalStarts.removeAll { $0 < latest - settings.rateWindow }
    }

    /// What the estimate is built from at a moment.
    struct Basis: Equatable, Sendable {
        /// The last confident word, -1 before any.
        var confident: Int
        /// When that word first appeared.
        var confidentAt: TimeInterval?
        /// Whether the latest result was a final: the presenter had paused.
        var afterFinal: Bool
        /// Words are arriving that match nothing: the presenter is not moving through the script.
        var offScript: Bool
        /// The first word of the phrase the voice is in, and when the voice started it.
        var voicePhraseStart: Int?
        var voiceStartedAt: TimeInterval?
        /// The estimate never passes this word: the end of the phrase the voice is in.
        var cap: Int?
        /// The first word after the phrase holding the confident word. Coasting stops there:
        /// crossing into the next phrase needs a word of it heard (plan 006, decision 5).
        var boundary: Int?
    }

    /// The presenter's position now, in words (fractional).
    ///
    /// While interim results arrive, it is the last confident word advanced by the rate over
    /// the time since it appeared plus the delay, for at most `maxCoast` with nothing new. After
    /// a final the presenter has paused, so it stays at the last word, unless the voice has
    /// since started a phrase the presenter has not begun: then, a lead's worth of time after
    /// the voice started it, they are taken to have begun it too, and no further (plan 001: the
    /// first interim result after a pause can come 1.5 s late, which stalled the gate of a short
    /// phrase). Going no further than its first word means silence lets at most a phrase of
    /// `lead + 1` words through a gate. Off script, or lost, it stays at the last confident word.
    ///
    /// Coasting never crosses a phrase boundary: it goes no further than the first word of the
    /// next phrase until a word of that phrase is confidently heard. A phrase end is where a
    /// presenter pauses or leaves the script, and there the coast is a guess with nothing heard
    /// to back it: off script straight after a phrase end, it released the next phrase before
    /// the presenter was seen to be lost (#19, plan 006).
    func position(_ basis: Basis, lead: Int, at now: TimeInterval) -> Double {
        let base = Double(basis.confident)
        var estimate = base
        if basis.offScript {
            estimate = base
        } else if !basis.afterFinal, let at = basis.confidentAt {
            let coast = min(max(now - at, 0), settings.maxCoast)
            estimate = base + rate * (delay + coast)
            if let boundary = basis.boundary { estimate = min(estimate, Double(boundary)) }
        } else if let start = basis.voicePhraseStart, let startedAt = basis.voiceStartedAt, start > basis.confident {
            let following = now - startedAt - Double(lead) / rate
            estimate = min(base + rate * max(following, 0), Double(start))
        }
        if let cap = basis.cap { estimate = min(estimate, Double(cap)) }
        return max(estimate, base)
    }
}
