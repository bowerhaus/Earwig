@testable import Earwig
import Testing

struct FollowEngineTests {

    /// Phrases 0 (words 0–4), 1 (5–9), 2 a cue, 3 (10–14) and 4 (15–19).
    private static let lines = [
        "Morning all, here we are.",
        "The tide is out today.",
        "Gulls wheel over our heads.",
        "Breakfast waits at the end.",
    ]

    private static func phrase(_ text: String) -> FollowPhrase {
        let words = ScriptWords.words(in: text)
        return FollowPhrase(kind: .spoken, words: words, wordStarts: words.indices.map { Double($0) * 0.4 }, duration: Double(words.count) * 0.4 + 0.2)
    }

    private let script = FollowScript(phrases: [
        phrase(lines[0]), phrase(lines[1]), .cue(duration: 1), phrase(lines[2]), phrase(lines[3]),
    ])

    private func engine(_ start: StartMode = .tonesOnly, lead: Int = 3) -> FollowEngine {
        var settings = FollowSettings()
        settings.start = start
        settings.lead = lead
        return FollowEngine(script: script, settings: settings, slateWords: ScriptWords.words(in: "3 take 2"))
    }

    /// An engine past the tones, playing phrase 0 since time 2.
    private func following() -> FollowEngine {
        var engine = engine()
        _ = engine.handle(.start, at: 0)
        #expect(engine.handle(.tonesEnded, at: 2) == [.play(phrase: 0, speed: 1)])
        return engine
    }

    // MARK: - Start

    @Test func tonesOnlyStartsWithTheTonesThenTheFirstPhrase() {
        var engine = engine()
        #expect(engine.snapshot.status == .idle)
        #expect(engine.handle(.start, at: 0) == [.playTones])
        #expect(engine.snapshot.status == .tones)
        #expect(engine.handle(.tonesEnded, at: 1.5) == [.play(phrase: 0, speed: 1)])
        #expect(engine.snapshot.status == .speaking)
    }

    @Test func theSlateIsRepliedTo() {
        var engine = engine(.slateWithReply)
        #expect(engine.handle(.start, at: 0) == [.playCue(.slate)])
        #expect(engine.snapshot.status == .slate)
        // Nothing heard before the cue has ended counts.
        #expect(engine.handle(.interim("step 3 take 2"), at: 1) == [])
        #expect(engine.handle(.final([FinalWord(text: "step", start: 0.2)]), at: 1.2) == [])
        _ = engine.handle(.cueEnded, at: 1.5)
        #expect(engine.handle(.interim("step"), at: 2.5) == [])
        #expect(engine.handle(.interim("step three"), at: 2.9) == [])
        #expect(engine.handle(.interim("step three take"), at: 3.3) == [.playTones])
        #expect(engine.handle(.tonesEnded, at: 5) == [.play(phrase: 0, speed: 1)])
    }

    @Test func theSlateReplyAgreesOverFinals() {
        var engine = engine(.slateWithReply)
        _ = engine.handle(.start, at: 0)
        _ = engine.handle(.cueEnded, at: 1.5)
        _ = engine.handle(.interim("three"), at: 2.5)
        #expect(engine.handle(.final([FinalWord(text: "3", start: 1.6)]), at: 3.0) == [])
        #expect(engine.handle(.interim("2"), at: 3.5) == [.playTones])
    }

    @Test func aTapStartsTheTakeFromTheSlate() {
        var engine = engine(.slateWithReply)
        _ = engine.handle(.start, at: 0)
        #expect(engine.handle(.tap, at: 0.5) == [.stopVoice, .playTones])
        var replied = self.engine(.slateWithReply)
        _ = replied.handle(.start, at: 0)
        _ = replied.handle(.cueEnded, at: 1.5)
        #expect(replied.handle(.tap, at: 4) == [.playTones])
    }

    @Test func theSlateAloneWaitsItsGapThenTheTones() {
        var engine = engine(.slate)
        #expect(engine.handle(.start, at: 0) == [.playCue(.slate)])
        _ = engine.handle(.cueEnded, at: 1.5)
        #expect(engine.handle(.interim("step 3 take 2"), at: 2.5) == [])
        #expect(engine.tick(at: 4.4) == [])
        #expect(engine.tick(at: 4.5) == [.playTones])
        var tapped = self.engine(.slate)
        _ = tapped.handle(.start, at: 0)
        _ = tapped.handle(.cueEnded, at: 1.5)
        #expect(tapped.handle(.tap, at: 2) == [.playTones])
    }

    @Test func theSlateIsNotFollowedAsScript() {
        var engine = engine(.slateWithReply)
        _ = engine.handle(.start, at: 0)
        _ = engine.handle(.cueEnded, at: 1.5)
        _ = engine.handle(.interim("step 3 take 2"), at: 2.5)
        _ = engine.handle(.tonesEnded, at: 4)
        // The same block grows with the first words of the script.
        _ = engine.handle(.interim("step 3 take 2 morning all"), at: 6)
        #expect(engine.snapshot.presenterWord == 1)
        #expect(engine.snapshot.status != .lost)
        // The final that settles the block is filtered by when its words were said.
        let said = [("step", 1.6), ("3", 1.9), ("take", 2.1), ("2", 2.3), ("morning", 4.6), ("all", 4.9)]
        _ = engine.handle(.final(said.map { FinalWord(text: $0.0, start: $0.1) }), at: 7)
        #expect(engine.snapshot.presenterWord == 1)
        #expect(engine.snapshot.status != .lost)
    }

    // MARK: - Gates

    @Test func theVoiceWaitsAtAGateUntilThePresenterIsWithinTheLead() {
        var engine = following()
        #expect(engine.handle(.phraseEnded(0), at: 3.8) == [])
        #expect(engine.snapshot.status == .waiting)
        // Silence after a pause: still waiting.
        #expect(engine.tick(at: 6) == [])
        // Heard "morning": one word is not confident; the estimate stays.
        #expect(engine.handle(.interim("morning"), at: 6.5) == [])
        // "Morning all" is confident at word 1; with the delay the estimate is past 0 (3 − lead).
        #expect(engine.handle(.interim("morning all"), at: 6.9) == [.play(phrase: 1, speed: 1)])
        #expect(engine.snapshot.status == .speaking)
    }

    @Test func aCuePlaysAtItsGateAndThePhraseAfterItFollowsStraightAway() {
        var engine = following()
        _ = engine.handle(.phraseEnded(0), at: 3.8)
        _ = engine.handle(.interim("morning all here we are"), at: 4)
        _ = engine.handle(.final(["morning", "all", "here", "we", "are"].enumerated().map { FinalWord(text: $1, start: 3.1 + Double($0) * 0.4) }), at: 5.5)
        _ = engine.tick(at: 5.6)
        _ = engine.handle(.phraseEnded(1), at: 7.4)
        #expect(engine.snapshot.status == .waiting)
        #expect(engine.handle(.interim("the tide is"), at: 8) == [.play(phrase: 2, speed: 1)])
        #expect(engine.handle(.phraseEnded(2), at: 9) == [.play(phrase: 3, speed: 1)])
    }

    // MARK: - Re-anchoring

    /// Phrase 0 from 2, heard into phrase 1, the cue and phrase 3 played: the voice is saying
    /// word 12 of phrase 3 and the presenter has reached the end of phrase 1.
    private func intoPhraseThree() -> FollowEngine {
        var engine = following()
        _ = engine.handle(.voiceProgress(phrase: 0, offset: 1.6), at: 3.4)
        _ = engine.handle(.interim("morning all here"), at: 3.5)
        #expect(engine.handle(.phraseEnded(0), at: 4.2) == [.play(phrase: 1, speed: 1)])
        _ = engine.handle(.voiceProgress(phrase: 1, offset: 1.6), at: 5.8)
        _ = engine.handle(.interim("morning all here we are the tide"), at: 5.9)
        #expect(engine.handle(.phraseEnded(1), at: 6.4) == [.play(phrase: 2, speed: 1)])
        #expect(engine.handle(.phraseEnded(2), at: 7.4) == [.play(phrase: 3, speed: 1)])
        _ = engine.handle(.voiceProgress(phrase: 3, offset: 0.8), at: 8.2)
        _ = engine.handle(.interim("morning all here we are the tide is out today"), at: 8.3)
        return engine
    }

    @Test func aRestartAfterTheGateOpenedReplaysFromThePhraseAfter() {
        var engine = intoPhraseThree()
        // The presenter goes back to "The tide is out today": the voice stops and, as the
        // presenter is already within the lead of that phrase's end, plays the cue after it again.
        let back = engine.handle(.interim("morning all here we are the tide is out today the tide"), at: 8.8)
        #expect(back == [.stopVoice, .play(phrase: 2, speed: 1)])
    }

    @Test func aRestartBeforeTheGateOpensNeedsNothing() {
        var engine = following()
        _ = engine.handle(.voiceProgress(phrase: 0, offset: 1.6), at: 3.4)
        _ = engine.handle(.interim("morning all here"), at: 3.5)
        _ = engine.handle(.phraseEnded(0), at: 4.2)
        _ = engine.handle(.voiceProgress(phrase: 1, offset: 1.6), at: 5.8)
        #expect(engine.handle(.phraseEnded(1), at: 6.4) == [])
        #expect(engine.snapshot.status == .waiting)
        // Back to the start of the line: the gate already holds the cue.
        let commands = engine.handle(.interim("morning all here morning all"), at: 6.6)
        #expect(commands == [])
        #expect(engine.snapshot.status == .waiting)
    }

    @Test func aPresenterAheadMakesTheVoiceJumpNotRace() {
        var engine = following()
        _ = engine.handle(.voiceProgress(phrase: 0, offset: 0.5), at: 2.5)
        // The presenter has skipped ahead to phrase 3 from memory. Two words in, they are
        // estimated near its end (the recogniser's delay added), so phrase 4 plays at once.
        let commands = engine.handle(.interim("gulls wheel"), at: 3)
        #expect(commands == [.stopVoice, .play(phrase: 4, speed: 1)])
    }

    @Test func lostThenFoundPicksUpWhereThePresenterIs() {
        var engine = following()
        _ = engine.handle(.voiceProgress(phrase: 0, offset: 1.2), at: 3.2)
        _ = engine.handle(.interim("morning all"), at: 3.3)
        _ = engine.handle(.phraseEnded(0), at: 3.8)
        _ = engine.handle(.interim("morning all rosie come back here girl biscuit drop"), at: 5)
        #expect(engine.snapshot.status == .lost)
        _ = engine.handle(.phraseEnded(1), at: 5.8)
        #expect(engine.tick(at: 6) == [])
        // Back on script, in the third phrase.
        let commands = engine.handle(.interim("morning all rosie come back here girl biscuit drop gulls wheel over"), at: 7)
        #expect(engine.snapshot.status != .lost)
        #expect(commands == [.play(phrase: 4, speed: 1)])
    }

    @Test func aRewriteOfWordsAlreadyHeardIsNotAStepBack() {
        var engine = intoPhraseThree()
        // The recogniser rewrites the block so that the run breaks after "the".
        let commands = engine.handle(.interim("morning all here we are the tied hiss aught tow day"), at: 8.6)
        #expect(!commands.contains(.stopVoice))
    }

    @Test func aPresenterInTheLastPhraseFinishesTheVoice() {
        var engine = following()
        for time in [2.1, 2.2, 2.3] { _ = engine.handle(.forward, at: time) }
        _ = engine.handle(.voiceProgress(phrase: 3, offset: 0.5), at: 2.8)
        // Skipped to the last phrase: nothing to queue, so the voice stops and is finished.
        #expect(engine.handle(.interim("breakfast waits at"), at: 3) == [.stopVoice])
        #expect(engine.handle(.interim("breakfast waits at the end"), at: 4) == [.finished(.completed)])
    }

    // MARK: - Controls

    @Test func holdStopsTheVoiceAndReleaseReAnchors() {
        var engine = following()
        #expect(engine.handle(.hold, at: 2.5) == [.stopVoice])
        #expect(engine.snapshot.status == .held)
        #expect(engine.tick(at: 3) == [])
        // Release with nothing heard: phrase 0 again.
        #expect(engine.handle(.hold, at: 4) == [.play(phrase: 0, speed: 1)])
    }

    @Test func releasingHoldPicksUpWhereThePresenterGotTo() {
        var engine = following()
        _ = engine.handle(.voiceProgress(phrase: 0, offset: 1.6), at: 3.4)
        #expect(engine.handle(.hold, at: 3.5) == [.stopVoice])
        // The presenter carries on while held: nothing moves.
        #expect(engine.handle(.interim("morning all here we are the tide"), at: 5) == [])
        #expect(engine.handle(.hold, at: 5.5) == [.play(phrase: 2, speed: 1)])
    }

    @Test func holdWhileWaitingStopsNothing() {
        var engine = following()
        _ = engine.handle(.phraseEnded(0), at: 3.8)
        #expect(engine.handle(.hold, at: 4) == [])
        #expect(engine.snapshot.status == .held)
    }

    @Test func backWhileWaitingReplaysThePhraseThenWaitsForThePresenter() {
        var engine = following()
        _ = engine.handle(.phraseEnded(0), at: 3.8)
        #expect(engine.handle(.back, at: 4) == [.play(phrase: 0, speed: 1)])
        // Nothing heard: after the moved phrase the voice waits at the gate.
        #expect(engine.handle(.phraseEnded(0), at: 6) == [])
        #expect(engine.tick(at: 9) == [])
        #expect(engine.snapshot.status == .waiting)
    }

    @Test func backAndForwardPlayAPhraseNow() {
        var engine = following()
        #expect(engine.handle(.forward, at: 2.5) == [.stopVoice, .play(phrase: 1, speed: 1)])
        #expect(engine.snapshot.presenterWord == 4)
        #expect(engine.handle(.back, at: 3) == [.stopVoice, .play(phrase: 0, speed: 1)])
        #expect(engine.handle(.back, at: 3.5) == [.stopVoice, .play(phrase: 0, speed: 1)])
    }

    @Test func forwardFromTheLastPhraseDoesNothing() {
        var engine = following()
        for time in [2.1, 2.2, 2.3, 2.4] { _ = engine.handle(.forward, at: time) }
        // Playing the last phrase: it is not cut off or played again.
        #expect(engine.handle(.forward, at: 2.5) == [])
        #expect(engine.snapshot.status == .speaking)
        // Finished and waiting at the end: still nothing.
        _ = engine.handle(.phraseEnded(4), at: 4.2)
        #expect(engine.handle(.forward, at: 4.5) == [])
    }

    @Test func restartGoesBackThroughTheTones() {
        var engine = following()
        #expect(engine.handle(.restart, at: 3) == [.stopVoice, .playTones])
        #expect(engine.handle(.tonesEnded, at: 4.5) == [.play(phrase: 0, speed: 1)])
    }

    @Test func stopEndsTheTake() {
        var engine = following()
        #expect(engine.handle(.stop, at: 3) == [.stopVoice, .finished(.stopped)])
        #expect(engine.snapshot.status == .finished)
        #expect(engine.snapshot.outcome == .stopped)
        #expect(engine.handle(.stop, at: 4) == [])
    }

    // MARK: - The end

    @Test func theTakeCompletesWhenTheLastWordIsHeard() {
        var engine = following()
        _ = engine.handle(.forward, at: 2.1)
        _ = engine.handle(.forward, at: 2.2)
        _ = engine.handle(.forward, at: 2.3)
        _ = engine.handle(.forward, at: 2.4)
        #expect(engine.handle(.phraseEnded(4), at: 4.2) == [])
        #expect(engine.handle(.interim("breakfast waits at the"), at: 5) == [])
        #expect(engine.handle(.interim("breakfast waits at the end"), at: 5.4) == [.finished(.completed)])
    }

    @Test func orAWhileAfterTheVoiceFinishesWithThePresenterInTheLastPhrase() {
        var engine = following()
        for time in [2.1, 2.2, 2.3, 2.4] { _ = engine.handle(.forward, at: time) }
        _ = engine.handle(.phraseEnded(4), at: 4.2)
        _ = engine.handle(.interim("breakfast waits"), at: 5)
        // Three seconds after they were last heard there (5), not after the voice finished (4.2).
        #expect(engine.tick(at: 7.9) == [])
        #expect(engine.tick(at: 8.0) == [.finished(.completed)])
    }

    @Test func aPresenterWhoComesBackToTheLastPhraseLateIsNotCutOff() {
        var engine = following()
        for time in [2.1, 2.2, 2.3, 2.4] { _ = engine.handle(.forward, at: time) }
        _ = engine.handle(.phraseEnded(4), at: 4.2)
        // Ten seconds later they start the last phrase: the take goes on while they say it.
        #expect(engine.handle(.interim("breakfast waits"), at: 14.2) == [])
        #expect(engine.tick(at: 15) == [])
        #expect(engine.handle(.interim("breakfast waits at the end"), at: 15.4) == [.finished(.completed)])
    }

    // MARK: - Speed

    @Test func theVoiceSlowsWhenThePresenterFallsBehind() {
        let words = ScriptWords.words(in: "one day the old boat came back into the harbour at last")
        let long = FollowScript(phrases: [
            FollowPhrase(kind: .spoken, words: words, wordStarts: words.indices.map { Double($0) * 0.4 }, duration: 5),
        ])
        var settings = FollowSettings()
        settings.start = .tonesOnly
        var engine = FollowEngine(script: long, settings: settings)
        _ = engine.handle(.start, at: 0)
        _ = engine.handle(.tonesEnded, at: 1)
        // Not heard yet: no speed change, whatever the voice does.
        _ = engine.handle(.voiceProgress(phrase: 0, offset: 2), at: 3)
        #expect(engine.tick(at: 3) == [])
        _ = engine.handle(.interim("one day"), at: 3.1)
        var speeds: [Double] = []
        for step in 1...10 {
            let time = 3.1 + Double(step) * 0.1
            _ = engine.handle(.voiceProgress(phrase: 0, offset: 4 + Double(step) * 0.02), at: time)
            for command in engine.tick(at: time) {
                if case .setSpeed(let speed) = command { speeds.append(speed) }
            }
        }
        #expect(!speeds.isEmpty)
        #expect(speeds.allSatisfy { $0 < 1 && $0 >= 0.85 })
    }
}
