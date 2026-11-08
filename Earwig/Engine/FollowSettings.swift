import Foundation

/// How the voice keeps the lead (PRD §4.4, §5.4).
enum PacingMode: String, Codable, CaseIterable, Sendable {
    /// Speed nudged within bounds, and a gate at every phrase end.
    case hybrid
    /// Speed fixed at 1.0x; gates only.
    case phraseGated
}

/// How a take starts (PRD §4.5, plan 003 decision 12).
enum StartMode: String, Codable, CaseIterable, Sendable {
    /// The slate is read in the cue voice and the presenter repeats it to start the take.
    case slateWithReply
    /// The slate is read, then a pause to say it to the camera; nothing is listened for.
    case slate
    /// The tones, then the first phrase.
    case tonesOnly
}

/// Everything the engine can be tuned by, with the plan's defaults.
struct FollowSettings: Equatable, Sendable {
    /// Words the voice runs ahead of the presenter's estimated position: the head start the
    /// presenter feels, since the estimate already allows for the recogniser's delay.
    var lead = 3
    var pacing: PacingMode = .hybrid
    var minSpeed = 0.85
    var maxSpeed = 1.2
    /// Change in speed per word of lead error.
    var speedPerWord = 0.05
    /// The most the speed changes in a second.
    var maxSpeedChangePerSecond = 0.1
    /// A speed change smaller than this is not sent.
    var speedThreshold = 0.02

    /// The matching window around the expected position, in words. Twenty-four behind, two
    /// whole phrases, so a restart from the start of the sentence before is seen at once (device
    /// check 4 of plan 005: twelve missed "The plan is simple" seventeen words back).
    var windowBehind = 24
    var windowAhead = 12
    /// Consecutive matches that make the position confident, normally and when lost.
    var run = 2
    var lostRun = 3
    /// Unmatched heard words, or seconds of them, after which the presenter is lost.
    var lostWords = 6
    var lostSeconds: TimeInterval = 4
    /// A confident position this many words or more behind the last is a step back.
    var stepBackWords = 3

    /// How long the presenter estimate goes on advancing with no new result.
    var maxCoast: TimeInterval = 0.5
    var defaultDelay: TimeInterval = 0.9
    var delayRange: ClosedRange<TimeInterval> = 0.3...2.0
    /// Delays kept for the median.
    var delaySamples = 20
    /// Words a second.
    var defaultRate = 2.5
    var rateRange: ClosedRange<Double> = 1.0...4.0
    /// Seconds of finals the rate is measured over, and the longest gap counted as speech.
    var rateWindow: TimeInterval = 10
    var rateMaxGap: TimeInterval = 1.0

    /// Seconds after the voice finishes the last phrase, and after the presenter was last heard
    /// in it, that the take completes.
    var endGrace: TimeInterval = 3

    var start: StartMode = .slateWithReply
    /// The pause after the slate in `.slate` mode.
    var slateGap: TimeInterval = 3
    /// Slate words to hear before the take starts in `.slateWithReply` mode.
    var slateWordsNeeded = 2

    /// Whether a voice reads the script. Without one (Screen mode with Ear off, plan 008,
    /// decision 1), the engine follows the presenter alone: no phrases are played, no lead is
    /// kept and nothing waits at a phrase end. The slate and the tones are as with a voice.
    var voiced = true
}
