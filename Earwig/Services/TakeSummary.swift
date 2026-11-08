import Foundation

/// The numbers of a take for the device check (plan 005, decision 13), gathered from the
/// engine's snapshots and the controls used: how well the voice kept the lead, how often and
/// how long it waited, the speed's range, the measured delay and rate. Pure, so it is tested
/// on a made-up run.
struct TakeSummary: Sendable {
    /// The step's spoken words.
    let wordCount: Int

    private(set) var controls: [String: Int] = [:]
    /// The furthest script word heard with confidence.
    private(set) var furthestWord = -1
    /// Seconds the voice was speaking with a lead error, and of those within two words.
    private(set) var speakingTime: TimeInterval = 0
    private(set) var withinTwoTime: TimeInterval = 0
    /// Each wait at a gate, in seconds, in order.
    private(set) var waits: [TimeInterval] = []
    private(set) var minSpeed: Double?
    private(set) var maxSpeed: Double?
    private(set) var delay: TimeInterval = 0
    private(set) var rate: Double = 0

    private var last: (snapshot: FollowSnapshot, time: TimeInterval)?
    private var waitingSince: TimeInterval?

    init(wordCount: Int) {
        self.wordCount = wordCount
    }

    /// Takes in the engine's state at a moment. Returns the length of a wait that has just
    /// ended, for the log.
    @discardableResult
    mutating func record(_ snapshot: FollowSnapshot, at time: TimeInterval) -> TimeInterval? {
        if let last, last.snapshot.status == .speaking, let error = last.snapshot.error {
            let interval = max(0, time - last.time)
            speakingTime += interval
            if abs(error) <= 2 { withinTwoTime += interval }
        }
        if snapshot.status == .speaking {
            minSpeed = min(minSpeed ?? snapshot.speed, snapshot.speed)
            maxSpeed = max(maxSpeed ?? snapshot.speed, snapshot.speed)
        }
        furthestWord = max(furthestWord, snapshot.presenterWord)
        delay = snapshot.delay
        rate = snapshot.rate

        var ended: TimeInterval?
        let wasWaiting = waitingSince != nil
        if snapshot.status == .waiting, !wasWaiting {
            waitingSince = time
        } else if snapshot.status != .waiting, let since = waitingSince {
            waitingSince = nil
            ended = time - since
            waits.append(time - since)
        }
        last = (snapshot, time)
        return ended
    }

    /// A manual control or the tap was used.
    mutating func used(_ control: FollowEvent) {
        let name: String
        switch control {
        case .hold: name = "hold"
        case .back: name = "back"
        case .forward: name = "forward"
        case .restart: name = "restart"
        case .stop: name = "stop"
        case .tap: name = "tap"
        default: return
        }
        controls[name, default: 0] += 1
    }

    /// The share of the speaking time the lead was within two words, if the voice spoke.
    var withinTwoShare: Double? { speakingTime > 0 ? withinTwoTime / speakingTime : nil }

    var wordsHeard: Int { min(furthestWord + 1, wordCount) }

    var longestWait: TimeInterval? { waits.max() }

    /// One line for the console at the end of a take.
    /// `note` says why a take stopped, when it was not the presenter: "not listening".
    /// `mode` is the take's: `voice` or `screen` (plan 008, decision 10).
    func line(duration: TimeInterval, outcome: FollowOutcome, mode: TakeMode = .voice, note: String? = nil) -> String {
        let used = controls.isEmpty ? "none" : controls.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        let lead = withinTwoShare.map { String(format: "%.0f%% of %.1f s speaking", $0 * 100, speakingTime) } ?? "no speaking"
        let waitText = waits.isEmpty ? "none" : String(format: "%d, longest %.1f s", waits.count, longestWait ?? 0)
        let speed = minSpeed.map { String(format: "%.2f–%.2f", $0, maxSpeed ?? $0) } ?? "n/a"
        return String(format: "take summary: %.1f s, %@, %@; controls %@; heard to word %d of %d; lead within 2 words %@; waits %@; speed %@; delay %.2f s; rate %.2f words/s",
                      duration, mode.logName, outcome.rawValue + (note.map { " (\($0))" } ?? ""), used, wordsHeard, wordCount, lead, waitText, speed, delay, rate)
    }
}
