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

    /// Device check 1: pausing after a phrase, the mark showed the second word of the next one.
    /// Through a pause it waits at the phrase's last word or the next phrase's first.
    @Test(arguments: paces)
    func aPauseAtAPhraseEndWaitsAtTheNextPhrasesStart(_ pace: Pace) {
        // Phrase 0 is words 0–6.
        let take = run([.read(0...6), .pause(3), .read(7...75)], pace)
        let resume = take.presenter.spoken.first { $0.word.script == 7 }?.start ?? 0
        let paused = take.screenPlaces.filter { $0.time > resume - 2 && $0.time < resume }.map(\.place)
        #expect(!paused.isEmpty)
        #expect(paused.allSatisfy { (6...7).contains(Int($0.rounded(.down))) })
        expectFollowed(take, pace)
    }

    /// Device check 1 again: "The plan is simple:" then a pause, and the mark was on "up the
    /// cliff path", five words into the same phrase. It now waits at the colon's next word.
    @Test(arguments: paces)
    func aPauseAtAColonMidPhraseWaitsAtTheNextWord(_ pace: Pace) {
        // Step 1: "Morning! … tide turns." is words 0–11, "The plan is simple:" 12–15.
        let script = SimulationScripts.harbour(step: 0)
        #expect(script.words[15].text == "simple")
        let take = run([.read(0...15), .pause(3), .read(16...(script.words.count - 1))], pace, script: script)
        let resume = take.presenter.spoken.first { $0.word.script == 16 }?.start ?? 0
        let paused = take.screenPlaces.filter { $0.time > resume - 2 && $0.time < resume }.map(\.place)
        #expect(!paused.isEmpty)
        #expect(paused.allSatisfy { Int($0.rounded(.down)) <= 16 })
        #expect(take.screenBackSteps.isEmpty)
    }

    /// Device check 1 a third time: a pause after "village", where the script has no comma,
    /// ran the mark into the next words. Once the recogniser settles, it comes back to "for".
    @Test(arguments: paces)
    func aPauseNoPunctuationMarksComesBackToTheNextWord(_ pace: Pace) {
        let script = SimulationScripts.harbour(step: 0)
        guard let village = script.words.firstIndex(where: { $0.text == "village" }) else {
            Issue.record("no village")
            return
        }
        let take = run([.read(0...village), .pause(3), .read((village + 1)...(script.words.count - 1))], pace, script: script)
        let resume = take.presenter.spoken.first { $0.word.script == village + 1 }?.start ?? 0
        let settled = take.screenPlaces.filter { $0.time > resume - 0.5 && $0.time < resume }.map(\.place)
        #expect(!settled.isEmpty)
        #expect(settled.allSatisfy { Int($0.rounded(.down)) == village + 1 })
        #expect(take.outcome == .completed)
    }

    @Test(arguments: paces)
    func aFluffAndStepBack(_ pace: Pace) {
        // A step back of two words, which the text waits out rather than moving back for.
        expectFollowed(run([.read(0...21), .say(["blah", "blah", "blah"]), .read(19...75)], pace), pace)
    }
}
