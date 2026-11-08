@testable import Earwig
import Foundation
import Testing

/// What the screen shows through simulated takes (plan 008, decision 3): the engine's place,
/// the word after the last one heard, smoothed by `ScreenPlace`, against the last word the
/// presenter began, with no voice and with one. It only marks what has been heard (Andy, device
/// check 2), so it trails. Measured on 2026-11-08: at 2.5 words a second, 0.7 words behind on
/// average and within two words 98–100% of the time; at the phone's 4 words a second in bursts
/// a second apart, 2.6–3.0 words behind, within four words 70–85% of the time. Through every
/// read the text never moves back.
struct ScreenPlaceScenarioTests {

    private let step = SimulationScripts.harbour(step: 1)

    struct Pace: CustomTestStringConvertible, Sendable {
        let rate: Double
        let interimInterval: TimeInterval
        let voiced: Bool
        /// The least share of samples within `words` of the presenter.
        let words: Double
        let share: Double
        var testDescription: String { "\(voiced ? "voiced" : "voiceless"), \(rate) w/s, bursts \(interimInterval) s" }
    }

    static let paces = [false, true].flatMap { voiced in
        [Pace(rate: 2.5, interimInterval: 0, voiced: voiced, words: 2, share: 0.95),
         Pace(rate: 4, interimInterval: 1, voiced: voiced, words: 4, share: 0.65)]
    }

    private func run(_ acts: [PresenterAct], _ pace: Pace, script: FollowScript? = nil) -> TakeSimulation {
        var settings = FollowSettings()
        settings.voiced = pace.voiced
        settings.lead = TakeSettings.defaultLead
        var recogniser = SimulatedRecogniser()
        recogniser.interimInterval = pace.interimInterval
        // With a voice the presenter reads behind it; with none, from the screen.
        let acts = pace.voiced ? acts : acts.map { if case .read(let range) = $0 { .recite(range) } else { $0 } }
        var take = TakeSimulation(script: script ?? step, settings: settings, acts: acts, rate: pace.rate, recogniser: recogniser)
        take.run()
        return take
    }

    private func share(_ errors: [Double], within words: Double) -> Double {
        Double(errors.filter { abs($0) <= words }.count) / Double(max(errors.count, 1))
    }

    /// Errors while reading, from the fifth word on, so the first result's delay is left out.
    private func expectFollowed(_ take: TakeSimulation, _ pace: Pace) {
        #expect(take.outcome == .completed)
        guard let start = take.presenter.spoken.first(where: { ($0.word.script ?? -1) >= 4 })?.start else {
            Issue.record("the presenter never read")
            return
        }
        let errors = take.screenErrors.filter { $0.time >= start + 1.5 }.map(\.error)
        #expect(share(errors, within: pace.words) >= pace.share)
        // Behind on average, as it only marks what has been heard, and by no more than the
        // recogniser's delay at the presenter's pace and a word.
        let mean = errors.reduce(0, +) / Double(max(errors.count, 1))
        #expect(mean <= 0.5)
        #expect(mean >= -(pace.rate * 0.9 + 1))
        #expect(take.screenBackSteps.isEmpty)
    }

    @Test(arguments: paces)
    func aCleanRead(_ pace: Pace) {
        expectFollowed(run([.read(0...75)], pace), pace)
    }

    @Test(arguments: paces)
    func aStopAndResume(_ pace: Pace) {
        expectFollowed(run([.read(0...27), .pause(6), .read(28...75)], pace), pace)
    }

    /// Where a pause falls. On the device the mark ran on past each of these (device check 1):
    /// a phrase end, a colon mid-phrase and a word with no punctuation after it.
    struct Pause: CustomTestStringConvertible, Sendable {
        let step: Int
        /// The last word read before the pause.
        let after: String
        var testDescription: String { "after \"\(after)\"" }
    }

    static let pauses = [
        Pause(step: 1, after: "1890"),
        Pause(step: 0, after: "simple"),
        Pause(step: 0, after: "village"),
    ]

    /// Through a pause the place rests on the next word, and the text never moves back.
    @Test(arguments: paces, pauses)
    func aPauseRestsOnTheNextWord(_ pace: Pace, _ pause: Pause) {
        let script = SimulationScripts.harbour(step: pause.step)
        guard let after = script.words.firstIndex(where: { $0.text == pause.after }) else {
            Issue.record("no \(pause.after)")
            return
        }
        let take = run([.read(0...after), .pause(3), .read((after + 1)...(script.words.count - 1))], pace, script: script)
        let resume = take.presenter.spoken.first { $0.word.script == after + 1 }?.start ?? 0
        let resting = take.screenPlaces.filter { $0.time > resume - 1 && $0.time < resume }.map(\.place)
        #expect(!resting.isEmpty)
        #expect(resting.allSatisfy { Int($0.rounded(.down)) == after + 1 })
        #expect(take.screenBackSteps.isEmpty)
        #expect(take.outcome == .completed)
    }

    /// Words off the script, then back two words. Once the wrong words have run on a while, the
    /// text goes back to the start of the phrase (17–27), so the presenter can see where to take
    /// it again from (plan 009), and moves back no other time.
    @Test(arguments: paces)
    func aFluffAndStepBack(_ pace: Pace) {
        let take = run([.read(0...21), .say(["blah", "blah", "blah"]), .read(19...75)], pace)
        #expect(take.outcome == .completed)
        let fluff = take.presenter.spoken.first { $0.word.script == nil }?.start ?? 0
        let back = take.presenter.spoken.first { $0.word.script == 19 && $0.start > fluff }?.start ?? 0
        #expect(take.screenBackSteps.allSatisfy { $0.time > fluff && $0.time < back + 2 })
        #expect(take.screenPlaces.allSatisfy { $0.time < fluff || $0.place >= 16.9 })
    }

    /// A word off the script and a stop, then on: the text goes back to the start of the phrase
    /// while the presenter is stopped, then follows them from where they take it up.
    @Test(arguments: paces)
    func aFluffAndAStopShowTheStartOfThePhrase(_ pace: Pace) {
        // Phrase 2 is words 17–27.
        let take = run([.read(0...22), .say(["gravy"]), .pause(4), .read(17...75)], pace)
        #expect(take.outcome == .completed)
        let fluff = take.presenter.spoken.first { $0.word.script == nil }?.start ?? 0
        let back = take.presenter.spoken.first { $0.word.script == 17 && $0.start > fluff }?.start ?? 0
        let resting = take.screenPlaces.filter { $0.time > back - 0.5 && $0.time < back }.map(\.place)
        #expect(!resting.isEmpty)
        #expect(resting.allSatisfy { abs($0 - 17) < 0.1 }, "rested at \(resting.first ?? -1)")
        #expect(take.screenBackSteps.allSatisfy { $0.time > fluff && $0.time < back })
    }
}
