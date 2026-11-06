@testable import Earwig
import Testing

struct PacerTests {

    @Test func theErrorIsHowFarTheVoiceIsBeyondTheLead() {
        #expect(Pacer.error(voice: 20, presenter: 15, lead: 3) == 2)
        #expect(Pacer.error(voice: 20, presenter: 18.5, lead: 3) == -1.5)
    }

    @Test func tooFarAheadSlowsDownAndTooCloseSpeedsUp() {
        let pacer = Pacer(settings: FollowSettings())
        #expect(abs(pacer.target(for: 2) - 0.9) < 1e-9)
        #expect(abs(pacer.target(for: -2) - 1.1) < 1e-9)
        #expect(pacer.target(for: 10) == 0.85)
        #expect(pacer.target(for: -10) == 1.2)
    }

    @Test func phraseGatedStaysAtOne() {
        var settings = FollowSettings()
        settings.pacing = .phraseGated
        var pacer = Pacer(settings: settings)
        pacer.reset(at: 0)
        #expect(pacer.target(for: 5) == 1)
        #expect(pacer.update(error: 5, at: 1) == nil)
        #expect(pacer.speed == 1)
    }

    @Test func theSpeedChangesNoFasterThanItsLimit() {
        var pacer = Pacer(settings: FollowSettings())
        pacer.reset(at: 0)
        #expect(pacer.update(error: 10, at: 0.1) == nil)
        let sent = pacer.update(error: 10, at: 0.5)
        #expect(sent.map { abs($0 - 0.95) < 1e-9 } == true)
        // Reaching a bound is always sent.
        #expect(pacer.update(error: 10, at: 2) == 0.85)
    }

    @Test func smallChangesAreNotSent() {
        var pacer = Pacer(settings: FollowSettings())
        pacer.reset(at: 0)
        #expect(pacer.update(error: 0.2, at: 1) == nil)
        #expect(abs(pacer.speed - 0.99) < 1e-9)
    }

    @Test func aPauseRestartsTheClock() {
        var pacer = Pacer(settings: FollowSettings())
        pacer.reset(at: 0)
        pacer.pause()
        // The first update after a pause moves nothing, however long the pause.
        #expect(pacer.update(error: 10, at: 30) == nil)
        #expect(pacer.speed == 1)
    }
}
