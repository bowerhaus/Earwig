@testable import Earwig
import Foundation
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
        // Stopped in "if you know where to look", then back to its start. Phrase 4 had begun; the
        // voice stops it once the presenter has been quiet a while, and gives it again when
        // they are back (plan 009).
        let take = run([.read(0...31), .pause(10), .read(28...75)])
        #expect(take.outcome == .completed)
        #expect(take.played == [0, 1, 2, 3, 4, 4, 5, 6, 7])
        #expect(take.player.stops == 1)
        #expect(take.player.silences.contains { $0 >= 8 })
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

    // MARK: - Off script at a phrase end (plan 006, #19)

    /// The paces the scenarios run at, at the app's lead: the simulation's own, the phone's
    /// (presenter and voice about 4 words a second, plan 005), and the phone's with interim
    /// results in bursts a second apart.
    static let paces: [(rate: Double, interval: TimeInterval)] = [(2.5, 0), (4, 0), (4, 1)]

    private func atLeadFive(_ acts: [PresenterAct], rate: Double, interval: TimeInterval, writes: [Int: String] = [:]) -> TakeSimulation {
        var settings = FollowSettings()
        settings.lead = 5
        var recogniser = SimulatedRecogniser()
        recogniser.interimInterval = interval
        recogniser.writes = writes
        let script = SimulationScripts.harbour(step: 1, secondsPerWord: 1 / rate)
        var take = TakeSimulation(script: script, settings: settings, acts: acts, rate: rate, recogniser: recogniser)
        take.run()
        return take
    }

    /// Take 12 of plan 005's device check 4: a phrase read to its end ("stood", word 27), then
    /// straight on with words of the presenter's own, then back to the script at word 28. With the
    /// voice waiting after phrase 3 (28–33), whose gate opens with the presenter estimated at word
    /// 29, the coast from "stood" (and at 4 words a second a stray "to" matching "where to look")
    /// released phrase 4 while the presenter was off script.
    @Test(arguments: Self.paces.indices)
    func offScriptAtAPhraseEndHoldsTheVoice(pace: Int) {
        let (rate, interval) = Self.paces[pace]
        let ownWords = ["we", "may", "be", "able", "to", "find", "a", "different", "way", "to", "do", "this"]
        let take = atLeadFive([.read(0...27), .runOn, .say(ownWords), .read(28...75)], rate: rate, interval: interval)
        #expect(take.outcome == .completed)
        #expect(take.statuses.contains(.lost))
        let release = take.releases.first { $0.phrase == 4 }
        #expect((release?.presenterAt ?? -1) >= 28,
                "phrase 4 released with the presenter at word \(release?.presenterAt ?? -1), estimated \(release?.estimate ?? -1) from \(release?.confident ?? -1), heard “\(release?.heard ?? "")”")
        #expect(take.player.plays.filter { $0.phrase == 4 }.count == 1)
        #expect(take.presenter.waits.allSatisfy { $0.length <= 0.5 })
    }

    /// "in all" heard as "an hour" (plan 005, take 12): phrase 2's last two words written as other
    /// words. The voice waits at the gate after phrase 3 until a word of it is heard, which with
    /// results in bursts a second apart can be a second later than before. Measured before plan
    /// 006, the longest silences were 1.5, 1.1 and 1.15 s, with no presenter waits; after, 1.5,
    /// 1.35 and 2.45 s, and one presenter wait of 0.15 s at the phone's pace in bursts.
    @Test(arguments: Self.paces.indices)
    func aMisheardPhraseEndHoldsThePresenterNoMoreThanAMoment(pace: Int) {
        let (rate, interval) = Self.paces[pace]
        let take = atLeadFive([.read(0...75)], rate: rate, interval: interval, writes: [26: "an", 27: "hour"])
        #expect(take.outcome == .completed)
        #expect(take.played == everyPhraseOnce)
        #expect(take.presenter.waits.allSatisfy { $0.length <= 0.2 })
        #expect(take.player.silences.allSatisfy { $0 < 2.5 })
    }

    /// An "um" after a phrase end, then the next phrase: nothing is held and the voice is not lost.
    @Test(arguments: Self.paces.indices)
    func aFillerAtAPhraseEndCostsNothing(pace: Int) {
        let (rate, interval) = Self.paces[pace]
        let take = atLeadFive([.read(0...27), .say(["um"]), .read(28...75)], rate: rate, interval: interval)
        #expect(take.outcome == .completed)
        #expect(take.played == everyPhraseOnce)
        #expect(!take.statuses.contains(.lost))
        #expect(take.presenter.waits.isEmpty)
    }

    /// The furthest word the voice began between two times.
    private func furthestSaid(_ take: TakeSimulation, from start: TimeInterval, to end: TimeInterval) -> Int {
        take.player.said.filter { $0.value.contains { (start..<end).contains($0) } }.keys.max() ?? -1
    }

    /// Plan 009, the first fluff of a take on the phone: a wrong word in a phrase while the voice
    /// gives the next one, a long pause, then back a word and on. Before, the voice read the next
    /// phrase to its end and waited for the presenter to say it from memory; now it stops, and
    /// gives that phrase again as they come to it.
    @Test(arguments: Self.paces.indices)
    func aFluffAndALongPauseStopTheVoiceAndItGivesThePhraseAgain(pace: Int) {
        let (rate, interval) = Self.paces[pace]
        // Phrase 3 is words 28–33, phrase 4 34–43.
        let take = atLeadFive([.read(0...30), .say(["around"]), .pause(14), .read(29...75)], rate: rate, interval: interval)
        #expect(take.outcome == .completed)
        #expect(take.player.plays.filter { $0.phrase == 4 }.count == 2, "plays \(take.played)")
        #expect(take.presenter.waits.isEmpty, "waits \(take.presenter.waits.map(\.length))")
        let fluff = take.presenter.spoken.first { $0.word.script == nil }?.start ?? 0
        let back = take.presenter.spoken.first { $0.word.script == 29 && $0.start > fluff }?.start ?? 0
        #expect(furthestSaid(take, from: fluff + 4, to: back) == -1, "the voice went on in the pause")
    }

    /// Plan 009, the second fluff: a wrong word, a stop, then straight on. Before, the gate had
    /// opened on the coast in the recogniser's delay and the voice read the next phrase to its
    /// end, eleven words past the stop. Now it stops within the lead and its margin, and a little
    /// for the recogniser's delay.
    @Test(arguments: Self.paces.indices)
    func aFluffAndAStopStopTheVoiceNearTheLead(pace: Int) {
        let (rate, interval) = Self.paces[pace]
        // Phrase 5 is words 44–53, phrase 6 54–64.
        let take = atLeadFive([.read(0...46), .say(["about"]), .pause(5), .read(47...75)], rate: rate, interval: interval)
        #expect(take.outcome == .completed)
        #expect(take.presenter.waits.isEmpty, "waits \(take.presenter.waits.map(\.length))")
        let fluff = take.presenter.spoken.first { $0.word.script == nil }?.start ?? 0
        let resume = take.presenter.spoken.first { $0.word.script == 47 && $0.start > fluff }?.start ?? 0
        let furthest = furthestSaid(take, from: fluff, to: resume)
        #expect(furthest <= 46 + 5 + 3 + Int((rate * 1.5).rounded(.up)), "the voice reached word \(furthest)")
    }

    /// The scenarios above at the app's lead and every pace: each completes with the presenter
    /// never waiting for the voice.
    static let scenarios: [(name: String, acts: [PresenterAct], writes: [Int: String])] = [
        ("a clean read", [.read(0...75)], [:]),
        ("a break off and resume", [.read(0...21), .say(["blah", "blah", "blah"]), .read(19...75)], [:]),
        ("a restart from the start of a line", [.read(0...20), .pause(0.5), .read(17...75)], [:]),
        ("a restart after the gate opened", [.read(0...63), .say(["timetape"]), .read(54...75)], [:]),
        ("a ten-second stop", [.read(0...31), .pause(10), .read(28...75)], [:]),
        ("a wander", [.read(0...21), .say(["rosie", "come", "back", "here", "girl", "leave", "that", "squirrel", "good", "dog"]), .read(22...75)], [:]),
        ("a skipped phrase", [.read(0...16), .recite(28...75)], [:]),
        ("a year and a compound", [.read(0...75)], [1: "seawall", 2: ""]),
    ]

    @Test(arguments: Self.scenarios.indices, Self.paces.indices)
    func everyScenarioAtTheAppsLeadAndEveryPace(scenario: Int, pace: Int) {
        let (rate, interval) = Self.paces[pace]
        let take = atLeadFive(Self.scenarios[scenario].acts, rate: rate, interval: interval, writes: Self.scenarios[scenario].writes)
        #expect(take.outcome == .completed, "\(Self.scenarios[scenario].name)")
        #expect(take.presenter.waits.isEmpty, "\(Self.scenarios[scenario].name): waits \(take.presenter.waits.map(\.length))")
        if scenario == 0 {
            // A clean read at lead 5 was within two words for 97, 91 and 88% of samples.
            #expect(share(underWay(take), within: 2) >= 0.85)
        }
    }
}
