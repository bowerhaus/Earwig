@testable import Earwig
import Foundation
import Testing

struct TakeSummaryTests {

    private func snapshot(_ status: FollowStatus, error: Double? = nil, speed: Double = 1, presenter: Int = -1) -> FollowSnapshot {
        var snapshot = FollowSnapshot()
        snapshot.status = status
        snapshot.error = error
        snapshot.speed = speed
        snapshot.presenterWord = presenter
        snapshot.delay = 0.9
        snapshot.rate = 2.6
        return snapshot
    }

    /// Two seconds speaking within the lead, one second two and a half words off, a wait of
    /// 1.5 s, then speaking again.
    private func run() -> TakeSummary {
        var summary = TakeSummary(wordCount: 20)
        summary.record(snapshot(.tones), at: 0)
        summary.record(snapshot(.speaking, error: 0.5, speed: 1.0, presenter: 2), at: 1)
        summary.record(snapshot(.speaking, error: -1.0, speed: 0.95, presenter: 4), at: 2)
        summary.record(snapshot(.speaking, error: 2.5, speed: 1.1, presenter: 6), at: 3)
        summary.record(snapshot(.waiting, presenter: 8), at: 4)
        let wait = summary.record(snapshot(.speaking, error: 0, speed: 1.0, presenter: 9), at: 5.5)
        #expect(wait == 1.5)
        summary.record(snapshot(.finished, presenter: 9), at: 6)
        return summary
    }

    @Test func theLeadsShareWithinTwoWords() {
        let summary = run()
        // Speaking with an error from 1 to 4 (3 s, of which 1 s off) and 5.5 to 6 (0.5 s).
        #expect(abs(summary.speakingTime - 3.5) < 0.001)
        #expect(abs((summary.withinTwoShare ?? 0) - 2.5 / 3.5) < 0.001)
    }

    @Test func waitsSpeedAndWords() {
        let summary = run()
        #expect(summary.waits == [1.5])
        #expect(summary.longestWait == 1.5)
        #expect(summary.minSpeed == 0.95)
        #expect(summary.maxSpeed == 1.1)
        #expect(summary.wordsHeard == 10)
        #expect(summary.delay == 0.9)
        #expect(summary.rate == 2.6)
    }

    @Test func controlsAreCounted() {
        var summary = TakeSummary(wordCount: 5)
        summary.used(.hold)
        summary.used(.hold)
        summary.used(.back)
        summary.used(.interim("not a control"))
        #expect(summary.controls == ["hold": 2, "back": 1])
        #expect(summary.line(duration: 12, outcome: .stopped).contains("controls back 1, hold 2"))
    }

    @Test func theLine() {
        let line = run().line(duration: 6, outcome: .completed)
        #expect(line.hasPrefix("take summary: 6.0 s, completed; controls none; heard to word 10 of 20"))
        #expect(line.contains("lead within 2 words 71% of 3.5 s speaking"))
        #expect(line.contains("waits 1, longest 1.5 s"))
        #expect(line.contains("speed 0.95–1.10"))
    }

    @Test func theLineSaysWhyATakeStopped() {
        let line = run().line(duration: 6, outcome: .stopped, note: "not listening")
        #expect(line.hasPrefix("take summary: 6.0 s, stopped (not listening); controls none"))
    }

    @Test func aTakeWithNoSpeaking() {
        let summary = TakeSummary(wordCount: 5)
        #expect(summary.withinTwoShare == nil)
        #expect(summary.line(duration: 1, outcome: .stopped).contains("lead within 2 words no speaking; waits none; speed n/a"))
    }
}
