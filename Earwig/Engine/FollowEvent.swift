import Foundation

/// A final word from the recogniser: its text and its start on the engine clock.
struct FinalWord: Equatable, Sendable {
    var text: String
    var start: TimeInterval
}

/// What happens to the engine (PRD §5.1, plan 003 decision 14).
enum FollowEvent: Equatable, Sendable {
    /// The take begins, by the start mode.
    case start
    /// The recogniser's interim text: the whole untimed block since the last final, rewritten.
    case interim(String)
    /// The recogniser's final words, which settle the block.
    case final([FinalWord])
    /// The player is at `offset` seconds into phrase `phrase`'s rendering (1.0x time).
    case voiceProgress(phrase: Int, offset: TimeInterval)
    /// The player has finished a phrase.
    case phraseEnded(Int)
    /// The slate cue has finished.
    case cueEnded
    /// The tones have finished.
    case tonesEnded
    /// A tap on the screen: starts the take from the slate.
    case tap
    /// Manual controls (PRD §4.4).
    case hold
    case back
    case forward
    case restart
    case stop
}

/// How a take ended.
enum FollowOutcome: String, Equatable, Sendable {
    case completed
    case stopped
}

/// A cue the engine asks for that is not a phrase.
enum FollowCue: Equatable, Sendable {
    case slate
}

/// What the engine asks the player and the host to do (PRD §5.2).
enum FollowCommand: Equatable, Sendable {
    case playCue(FollowCue)
    case playTones
    /// Play a phrase from its start; a cue phrase in the cue voice.
    case play(phrase: Int, speed: Double)
    case setSpeed(Double)
    /// Stop the voice now.
    case stopVoice
    case finished(FollowOutcome)
}

/// What the screen and diagnostics show (PRD §8.3).
enum FollowStatus: String, Equatable, Sendable {
    case idle
    case slate
    case tones
    case speaking
    case waiting
    /// Following the presenter with no voice (plan 008, decision 1).
    case reading
    case lost
    case held
    case finished
}

/// The engine's state for the screen, Screen mode and the Listening check.
struct FollowSnapshot: Equatable, Sendable {
    var status: FollowStatus = .idle
    /// The phrase the voice is in or waiting after, and the word it is saying (flat index).
    var voicePhrase: Int?
    var voiceWord: Int?
    /// The last confident word heard, and where the presenter is estimated to be now.
    var presenterWord = -1
    var presenterEstimate = -1.0
    /// Where the screen shows the presenter (plan 008): the estimate with the gate's rule, so it
    /// does not coast across a phrase end until a word of the next phrase is heard. With the
    /// free coast, a pause at a phrase end left the screen's mark two words into the next
    /// phrase (device check 1). Kept still while held.
    var presenterPlace = -1.0
    /// The recogniser has settled a block and nothing has been heard since, while following and
    /// not held: the presenter has paused at `presenterWord`. The screen's place may then go
    /// back to the word after it, if it ran on past a pause no punctuation marked (plan 008).
    var presenterPaused = false
    /// Whether the last word heard was part of a confident run.
    var confident = false
    var speed = 1.0
    /// The lead error in words, while the voice speaks.
    var error: Double?
    var delay: TimeInterval = 0
    var rate: Double = 0
    var outcome: FollowOutcome?
}
