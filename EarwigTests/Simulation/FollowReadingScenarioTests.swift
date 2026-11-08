@testable import Earwig
import Foundation
import Testing

/// Simulated takes with no voice (plan 008, decision 1): the presenter reads the harbour walk's
/// second step from the screen after the tones, and the engine follows them alone. Each runs at
/// the old simulated pace (2.5 words a second, interim results every step) and at the phone's
/// (4 words a second, interim results in bursts a second apart, plan 006).
struct FollowReadingScenarioTests {

    private let step = SimulationScripts.harbour(step: 1)

    /// A pace, and the least share of samples the engine's estimate is within two and three
    /// words of the presenter. Measured on 2026-11-08: at 2.5 w/s 89–94% within two and 98–100%
    /// within three; at 4 w/s in bursts 60–70% within two and 80–85% within three, as each burst
    /// moves the estimate four words. The screen's place smooths the bursts (decision 3), and is
    /// measured in `ScreenPlaceScenarioTests`.
    struct Pace: CustomTestStringConvertible, Sendable {
        let rate: Double
        let interimInterval: TimeInterval
        let within2: Double
        let within3: Double
        var testDescription: String { "\(rate) w/s, bursts \(interimInterval) s" }
    }

    static let paces = [
        Pace(rate: 2.5, interimInterval: 0, within2: 0.87, within3: 0.97),
        Pace(rate: 4, interimInterval: 1, within2: 0.55, within3: 0.77),
    ]

    private func expectFollowed(_ errors: [Double], _ pace: Pace) {
        #expect(share(errors, within: 2) >= pace.within2)
        #expect(share(errors, within: 3) >= pace.within3)
    }

    private func run(_ acts: [PresenterAct], _ pace: Pace) -> TakeSimulation {
        var settings = FollowSettings()
        settings.voiced = false
        settings.lead = TakeSettings.defaultLead
        var recogniser = SimulatedRecogniser()
        recogniser.interimInterval = pace.interimInterval
        var take = TakeSimulation(script: step, settings: settings, acts: acts, rate: pace.rate, recogniser: recogniser)
        take.run()
        return take
    }

    private func share(_ errors: [Double], within words: Double) -> Double {
        Double(errors.filter { abs($0) <= words }.count) / Double(max(errors.count, 1))
    }

    /// Place errors while reading, from the fifth word on, so the first result's delay is left out.
    private func reading(_ take: TakeSimulation, from word: Int = 4) -> [Double] {
        guard let start = take.presenter.spoken.first(where: { ($0.word.script ?? -1) >= word })?.start else { return [] }
        return take.placeErrors.filter { $0.time >= start + 1.5 }.map(\.error)
    }

    private static func neverPlays(_ take: TakeSimulation) -> Bool {
        take.player.plays.isEmpty && take.player.speeds == [1]
    }

    @Test(arguments: paces)
    func aCleanReadIsFollowed(_ pace: Pace) {
        let take = run([.recite(0...75)], pace)
        #expect(take.outcome == .completed)
        #expect(Self.neverPlays(take))
        #expect(!take.statuses.contains(.lost))
        expectFollowed(reading(take), pace)
    }

    @Test(arguments: paces)
    func aStopAndResumeIsFollowed(_ pace: Pace) {
        let take = run([.recite(0...27), .pause(6), .recite(28...75)], pace)
        #expect(take.outcome == .completed)
        #expect(Self.neverPlays(take))
        expectFollowed(reading(take), pace)
    }

    @Test(arguments: paces)
    func aFluffAndStepBackIsFollowed(_ pace: Pace) {
        // "You can still see the, blah, blah, blah, still see the marks …"
        let take = run([.recite(0...21), .say(["blah", "blah", "blah"]), .recite(19...75)], pace)
        #expect(take.outcome == .completed)
        #expect(Self.neverPlays(take))
        expectFollowed(reading(take), pace)
    }

    @Test(arguments: paces)
    func aWanderOffScriptShowsLostAndPicksUp(_ pace: Pace) {
        let off = ["rosie", "come", "back", "here", "girl", "leave", "that", "alone", "good", "dog", "now", "sit"]
        let take = run([.recite(0...33), .say(off), .recite(34...75)], pace)
        #expect(take.outcome == .completed)
        #expect(Self.neverPlays(take))
        #expect(take.statuses.contains(.lost))
        // Back on the script, the place is with the presenter again.
        let backAt = take.presenter.spoken.first { $0.word.script == 40 }?.start ?? .infinity
        let after = take.placeErrors.filter { $0.time >= backAt }.map(\.error)
        expectFollowed(after, pace)
    }
}
