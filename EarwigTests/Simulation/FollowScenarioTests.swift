@testable import Earwig
import Testing

/// The scenarios of PRD §12 stage 3 and §14, as simulated takes of the harbour walk's second
/// step: 76 words in eight phrases (0–6, 7–16, 17–27, 28–33, 34–43, 44–53, 54–64, 65–75). The
/// presenter reads at 2.5 words a second behind the voice, pausing 0.6 s at phrase ends; the
/// recogniser is 0.9 s late. A presenter "wait" is time they were ready to speak and the voice
/// had not given them the word.
struct FollowScenarioTests {

    private let step = SimulationScripts.harbour(step: 1)
    private let everyPhraseOnce = Array(0...7)

    private func run(_ acts: [PresenterAct], rate: Double = 2.5, recogniser: SimulatedRecogniser = SimulatedRecogniser()) -> TakeSimulation {
        var take = TakeSimulation(script: step, acts: acts, rate: rate, recogniser: recogniser)
        take.run()
        return take
    }

    /// Lead errors once phrase 1 has started, so the start's run-up is left out.
    private func underWay(_ take: TakeSimulation, after: Double? = nil) -> [Int] {
        let start = after ?? take.player.plays.first { $0.phrase == 1 }?.time ?? 0
        return take.leadErrors.filter { $0.time >= start }.map(\.error)
    }

    private func share(_ errors: [Int], within words: Int) -> Double {
        Double(errors.filter { abs($0) <= words }.count) / Double(max(errors.count, 1))
    }

    @Test func aCleanReadHoldsTheLead() {
        let take = run([.read(0...75)])
        #expect(take.outcome == .completed)
        #expect(take.played == everyPhraseOnce)
        #expect(take.repeatedWords.isEmpty)
        #expect(take.unsaidWords.isEmpty)
        #expect(take.presenter.waits.isEmpty)
        #expect(!take.statuses.contains(.lost))
        // PRD §14: within two words through a clean read. Measured: 99% of samples, none beyond
        // three; the threshold leaves a little room.
        let errors = underWay(take)
        #expect(share(errors, within: 2) >= 0.98)
        #expect(errors.allSatisfy { abs($0) <= 3 })
        #expect(take.player.speeds.allSatisfy { (0.85...1.2).contains($0) })
    }

    @Test func aSlowReadSlowsTheVoiceAndWaitsAtGates() {
        let take = run([.read(0...75)], rate: 1.6)
        #expect(take.outcome == .completed)
        #expect(take.played == everyPhraseOnce)
        #expect(take.presenter.waits.isEmpty)
        #expect(take.player.speeds.min() == 0.85)
        #expect(take.player.silences.filter { $0 > 1.5 }.count >= 5)
        // Never more than a phrase ahead.
        #expect(take.leadErrors.allSatisfy { $0.error + take.engine.settings.lead <= 11 })
    }

    @Test func aBreakOffAndResumeIsHeldAtTheGate() {
        // "You can still see the, blah, blah, blah, still see the marks …"
        let take = run([.read(0...21), .say(["blah", "blah", "blah"]), .read(19...75)])
        #expect(take.outcome == .completed)
        #expect(take.played == everyPhraseOnce)
        #expect(take.repeatedWords.isEmpty)
        #expect(take.presenter.waits.isEmpty)
        #expect(take.player.silences.contains { $0 > 2 })
    }

    @Test func aRestartFromTheStartOfALineIsFollowed() {
        let take = run([.read(0...20), .pause(0.5), .read(17...75)])
        #expect(take.outcome == .completed)
        #expect(take.played == everyPhraseOnce)
        #expect(take.repeatedWords.isEmpty)
        #expect(take.presenter.waits.isEmpty)
    }

    @Test func aRestartAfterTheGateOpenedReplaysTheNextPhrase() {
        // Plan 001's third fluff: "… on the tide, timetape," then "the trick is …" again, after
        // the voice has gone on into the last phrase. The spike waited 5.4 s here.
        let take = run([.read(0...63), .say(["timetape"]), .read(54...75)])
        #expect(take.outcome == .completed)
        #expect(take.player.stops == 1)
        #expect(take.played == everyPhraseOnce + [7])
        #expect(take.presenter.waits.isEmpty)
    }

    @Test func afterATenSecondStopTheVoiceIsBackInStepWithinAPhrase() {
        // Stopped in "if you know where to look", then back to its start.
        let take = run([.read(0...31), .pause(10), .read(28...75)])
        #expect(take.outcome == .completed)
        #expect(take.played == everyPhraseOnce)
        #expect(take.player.silences.contains { $0 >= 10 })
        #expect(take.presenter.waits.isEmpty)
        // PRD §14: back in step within one phrase of the restart.
        let restart = take.presenter.spoken.first { $0.word.script == 28 && $0.start > 15 }?.start ?? 0
        let errors = underWay(take, after: restart + 4.4)
        #expect(share(errors, within: 2) >= 0.9)
        #expect(errors.allSatisfy { abs($0) <= 3 })
    }

    @Test func aFluffThenARestartOfThePreviousSentenceIsFollowed() {
        // Device check 4 of plan 005, on the step Andy read (words 12–23 "The plan is simple:
        // along the sea wall, up the cliff path," and 24–32 "and back through the village for a
        // late breakfast."): "And back to the village foot", then "The plan is simple" and a
        // stop. Sixteen words behind, outside a 12-word window, it went lost and was never found.
        var take = TakeSimulation(script: SimulationScripts.harbour(step: 0), acts: [
            .read(0...28), .say(["foot"]), .pause(1), .read(12...15), .pause(4), .read(16...69),
        ])
        take.run()
        #expect(take.outcome == .completed)
        // Seen as a step back at once, never lost; in the pause the voice waits, and gives
        // nothing again (Andy, take 12: "we're making this resetting too complex").
        #expect(!take.statuses.contains(.lost))
        #expect(take.player.said[12]?.count == 1)
    }

    @Test func aWanderOffScriptIsWaitedForAndPickedUp() {
        let take = run([.read(0...21), .say(["rosie", "come", "back", "here", "girl", "leave", "that", "squirrel", "good", "dog"]), .read(22...75)])
        #expect(take.statuses.contains(.lost))
        #expect(take.outcome == .completed)
        #expect(take.played == everyPhraseOnce)
        #expect(take.repeatedWords.isEmpty)
        #expect(take.presenter.waits.isEmpty)
        #expect(take.player.silences.contains { $0 > 4 })
    }

    @Test func aPresenterWhoSkipsAPhraseIsJumpedToNotRacedAfter() {
        // Phrase 2 skipped, phrase 3 said from memory.
        let take = run([.read(0...16), .recite(28...75)])
        #expect(take.outcome == .completed)
        #expect(take.player.stops == 1)
        #expect(!take.played.contains(3))
        #expect(take.player.speeds.allSatisfy { $0 <= 1.2 })
        #expect(take.presenter.waits.isEmpty)
    }

    @Test func aYearAndACompoundHoldNoGate() {
        // "The sea wall was built in 1890": heard "seawall", and 1890 building up as "18", "189".
        var recogniser = SimulatedRecogniser()
        recogniser.writes = [1: "seawall", 2: ""]
        let take = run([.read(0...75)], recogniser: recogniser)
        #expect(take.outcome == .completed)
        #expect(take.played == everyPhraseOnce)
        #expect(take.presenter.waits.isEmpty)
        // The spike's gate after "1890" held 2.8 s.
        #expect(take.player.silences.allSatisfy { $0 < 1.5 })
    }

    @Test func aLateFirstResultAfterAPauseDoesNotStallTheGate() {
        var recogniser = SimulatedRecogniser()
        recogniser.firstAfterFinal = 1.5
        let take = run([.read(0...75)], recogniser: recogniser)
        #expect(take.outcome == .completed)
        #expect(take.played == everyPhraseOnce)
        #expect(take.presenter.waits.isEmpty)
        #expect(take.player.silences.allSatisfy { $0 < 1.5 })
    }

    @Test func theEngineMeasuresTheRecognisersDelayAndThePresentersRate() {
        var recogniser = SimulatedRecogniser()
        recogniser.delay = 1.4
        recogniser.firstAfterFinal = 1.4
        let take = run([.read(0...75)], rate: 2, recogniser: recogniser)
        #expect(take.outcome == .completed)
        #expect(abs(take.engine.snapshot.delay - 1.4) < 0.06)
        #expect(abs(take.engine.snapshot.rate - 2) < 0.15)
        #expect(take.presenter.waits.isEmpty)
    }

    @Test func phraseGatedModeKeepsOneSpeed() {
        var settings = FollowSettings()
        settings.pacing = .phraseGated
        var take = TakeSimulation(script: step, settings: settings, acts: [.read(0...75)])
        take.run()
        #expect(take.outcome == .completed)
        #expect(take.player.speeds.allSatisfy { $0 == 1 })
        #expect(take.presenter.waits.isEmpty)
    }
}
