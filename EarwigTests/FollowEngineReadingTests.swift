@testable import Earwig
import Testing

/// The engine with no voice (plan 008, decision 1): Screen mode with Ear off, where it follows
/// the presenter alone.
struct FollowEngineReadingTests {

    /// Phrases 0 (words 0–4), 1 (5–9), 2 a cue, 3 (10–14) and 4 (15–19).
    private static func phrase(_ text: String) -> FollowPhrase {
        let words = ScriptWords.words(in: text)
        return FollowPhrase(kind: .spoken, words: words, wordStarts: words.indices.map { Double($0) * 0.4 }, duration: Double(words.count) * 0.4 + 0.2)
    }

    private let script = FollowScript(phrases: [
        phrase("Morning all, here we are."), phrase("The tide is out today."), .cue(duration: 1),
        phrase("Gulls wheel over our heads."), phrase("Breakfast waits at the end."),
    ])

    private func engine(_ start: StartMode = .tonesOnly) -> FollowEngine {
        var settings = FollowSettings()
        settings.start = start
        settings.voiced = false
        return FollowEngine(script: script, settings: settings, slateWords: ScriptWords.words(in: "3 take 2"))
    }

    /// An engine past the tones, reading since time 2.
    private func reading() -> FollowEngine {
        var engine = engine()
        _ = engine.handle(.start, at: 0)
        #expect(engine.handle(.tonesEnded, at: 2) == [])
        return engine
    }

    private static func isPhraseCommand(_ command: FollowCommand) -> Bool {
        switch command {
        case .play, .setSpeed, .stopVoice: true
        default: false
        }
    }

    // MARK: - Start

    @Test func theTonesGoIntoReadingWithNoPhrasePlayed() {
        var engine = engine()
        #expect(engine.handle(.start, at: 0) == [.playTones])
        #expect(engine.handle(.tonesEnded, at: 1.5) == [])
        #expect(engine.snapshot.status == .reading)
        #expect(engine.snapshot.voicePhrase == nil)
        #expect(engine.snapshot.voiceWord == nil)
        #expect(engine.tick(at: 10) == [])
    }

    @Test func theSlateStillPlays() {
        var engine = engine(.slateWithReply)
        #expect(engine.handle(.start, at: 0) == [.playCue(.slate)])
        _ = engine.handle(.cueEnded, at: 1.5)
        #expect(engine.handle(.interim("step three take"), at: 3) == [.playTones])
        #expect(engine.handle(.tonesEnded, at: 4.5) == [])
        #expect(engine.snapshot.status == .reading)
    }

    // MARK: - Following

    @Test func heardWordsMoveThePlaceAndNothingElse() {
        var engine = reading()
        #expect(engine.handle(.interim("morning all here"), at: 3) == [])
        #expect(engine.snapshot.presenterWord == 2)
        #expect(engine.snapshot.presenterEstimate >= 2)
        // Across a phrase end there is no gate: the place goes straight on.
        #expect(engine.handle(.interim("morning all here we are the tide is"), at: 5) == [])
        #expect(engine.snapshot.presenterWord == 7)
        #expect(engine.snapshot.status == .reading)
    }

    @Test func thePlaceIsCappedAtTheLastWord() {
        var engine = reading()
        for time in [2.1, 2.2, 2.3] { _ = engine.handle(.forward, at: time) }
        _ = engine.handle(.interim("breakfast waits at the"), at: 3)
        _ = engine.tick(at: 3.2)
        #expect(engine.snapshot.presenterEstimate <= 19)
    }

    @Test func lostAndFound() {
        var engine = reading()
        _ = engine.handle(.interim("morning all here"), at: 3)
        _ = engine.handle(.interim("morning all here rosie come back now girl biscuit drop"), at: 5)
        #expect(engine.snapshot.status == .lost)
        _ = engine.handle(.interim("morning all here rosie come back now girl biscuit drop the tide is out"), at: 7)
        #expect(engine.snapshot.status == .reading)
        #expect(engine.snapshot.presenterWord == 8)
    }

    @Test func aStepBackMovesThePlaceBack() {
        var engine = reading()
        _ = engine.handle(.interim("morning all here we are the tide is out"), at: 5)
        #expect(engine.snapshot.presenterWord == 8)
        _ = engine.handle(.final((0..<9).map { FinalWord(text: ["morning", "all", "here", "we", "are", "the", "tide", "is", "out"][$0], start: 2 + Double($0) * 0.4) }), at: 5.5)
        #expect(engine.handle(.interim("here we are"), at: 7) == [])
        #expect(engine.snapshot.presenterWord == 4)
    }

    // MARK: - Controls

    @Test func holdKeepsThePlaceAndReleaseGoesToWhereThePresenterIs() {
        var engine = reading()
        _ = engine.handle(.interim("morning all here"), at: 3)
        #expect(engine.handle(.hold, at: 3.1) == [])
        #expect(engine.snapshot.status == .held)
        let place = engine.snapshot.presenterEstimate
        _ = engine.handle(.interim("morning all here we are the tide"), at: 5)
        #expect(engine.snapshot.presenterEstimate == place)
        #expect(engine.handle(.hold, at: 5.5) == [])
        #expect(engine.snapshot.status == .reading)
        #expect(engine.snapshot.presenterWord == 6)
    }

    @Test func backAndForwardMoveThePlaceAPhraseAndPassOverCues() {
        var engine = reading()
        #expect(engine.handle(.forward, at: 2.5) == [])
        // At the start of phrase 1: the place is the word before it.
        #expect(engine.snapshot.presenterWord == 4)
        _ = engine.handle(.forward, at: 2.6)
        // Phrase 2 is a cue, so Forward goes to phrase 3.
        #expect(engine.snapshot.presenterWord == 9)
        _ = engine.handle(.back, at: 2.7)
        #expect(engine.snapshot.presenterWord == 4)
        _ = engine.handle(.back, at: 2.8)
        #expect(engine.snapshot.presenterWord == -1)
        _ = engine.handle(.back, at: 2.9)
        #expect(engine.snapshot.presenterWord == -1)
    }

    @Test func backFromInsideAPhraseGoesToThePhraseBefore() {
        var engine = reading()
        _ = engine.handle(.interim("morning all here we are the tide"), at: 4)
        #expect(engine.handle(.back, at: 4.5) == [])
        #expect(engine.snapshot.presenterWord == -1)
    }

    @Test func forwardFromTheLastPhraseDoesNothing() {
        var engine = reading()
        for time in [2.1, 2.2, 2.3] { _ = engine.handle(.forward, at: time) }
        #expect(engine.snapshot.presenterWord == 14)
        #expect(engine.handle(.forward, at: 2.4) == [])
        #expect(engine.snapshot.presenterWord == 14)
    }

    @Test func restartAndStop() {
        var engine = reading()
        _ = engine.handle(.interim("morning all here"), at: 3)
        #expect(engine.handle(.restart, at: 3.5) == [.playTones])
        #expect(engine.handle(.tonesEnded, at: 5) == [])
        #expect(engine.snapshot.presenterWord == -1)
        #expect(engine.handle(.stop, at: 6) == [.finished(.stopped)])
    }

    // MARK: - The end

    @Test func theTakeCompletesWhenTheLastWordIsHeard() {
        var engine = reading()
        for time in [2.1, 2.2, 2.3] { _ = engine.handle(.forward, at: time) }
        #expect(engine.handle(.interim("breakfast waits at the"), at: 3) == [])
        #expect(engine.handle(.interim("breakfast waits at the end"), at: 3.4) == [.finished(.completed)])
    }

    @Test func orAWhileAfterThePresenterWasLastHeardInTheLastPhrase() {
        var engine = reading()
        for time in [2.1, 2.2, 2.3] { _ = engine.handle(.forward, at: time) }
        _ = engine.handle(.interim("breakfast waits"), at: 3)
        #expect(engine.tick(at: 5.9) == [])
        #expect(engine.tick(at: 6.0) == [.finished(.completed)])
    }

    @Test func nothingHeardNeverCompletes() {
        var engine = reading()
        #expect(engine.tick(at: 60) == [])
        #expect(engine.snapshot.status == .reading)
    }

    @Test func aWholeReadSendsNoPhraseCommands() {
        var engine = reading()
        let words = ["morning", "all", "here", "we", "are", "the", "tide", "is", "out", "today",
                     "gulls", "wheel", "over", "our", "heads", "breakfast", "waits", "at", "the", "end"]
        var commands: [FollowCommand] = []
        for count in 1...words.count {
            let time = 2 + Double(count) * 0.4
            commands += engine.handle(.interim(words.prefix(count).joined(separator: " ")), at: time)
            commands += engine.tick(at: time + 0.2)
        }
        #expect(!commands.contains(where: Self.isPhraseCommand))
        #expect(commands.last == .finished(.completed))
    }
}
