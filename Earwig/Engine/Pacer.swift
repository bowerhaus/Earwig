import Foundation

/// The voice's speed (PRD §5.4, plan 003 decision 10). Hybrid: speed = clamp(1 − k·e) for a
/// lead error `e` in words (positive when the voice is too far ahead), rate-limited so the voice
/// never lurches, and sent only when it moves enough to hear. Phrase-gated: always 1.0x.
struct Pacer: Equatable, Sendable {
    let settings: FollowSettings
    /// The speed the voice is playing at now.
    private(set) var speed = 1.0
    /// The last speed sent to the player.
    private(set) var sent = 1.0
    private var lastUpdate: TimeInterval?

    init(settings: FollowSettings) {
        self.settings = settings
    }

    /// The lead error: how far the voice is beyond where it should be, in words.
    static func error(voice: Int, presenter: Double, lead: Int) -> Double {
        Double(voice) - presenter - Double(lead)
    }

    /// The speed the error asks for, before rate limiting.
    func target(for error: Double) -> Double {
        guard settings.pacing == .hybrid else { return 1 }
        return min(max(1 - settings.speedPerWord * error, settings.minSpeed), settings.maxSpeed)
    }

    /// A phrase starts at 1.0x (PRD §5.4: "on release the next phrase starts at speed 1.0x").
    mutating func reset(at now: TimeInterval) {
        speed = 1
        sent = 1
        lastUpdate = now
    }

    /// Speed logic is off (waiting, a cue, held): the next update starts its time afresh.
    mutating func pause() {
        lastUpdate = nil
    }

    /// Moves the speed towards the error's target; returns a speed to send, if any.
    mutating func update(error: Double, at now: TimeInterval) -> Double? {
        let elapsed = lastUpdate.map { max(now - $0, 0) } ?? 0
        lastUpdate = now
        let step = settings.maxSpeedChangePerSecond * elapsed
        let wanted = target(for: error)
        speed += min(max(wanted - speed, -step), step)
        let atBound = speed == settings.minSpeed || speed == settings.maxSpeed || speed == 1
        guard abs(speed - sent) >= settings.speedThreshold || (atBound && speed != sent) else { return nil }
        sent = speed
        return speed
    }
}
