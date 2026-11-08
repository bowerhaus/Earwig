@testable import Earwig
import Testing

struct PresenterEstimateTests {

    private let settings = FollowSettings()

    private func basis(
        confident: Int = 10, at: Double? = 0, afterFinal: Bool = false, offScript: Bool = false,
        voiceStart: Int? = nil, voiceStartedAt: Double? = nil, cap: Int? = nil, boundary: Int? = nil
    ) -> PresenterEstimate.Basis {
        PresenterEstimate.Basis(
            confident: confident, confidentAt: at, afterFinal: afterFinal, offScript: offScript,
            voicePhraseStart: voiceStart, voiceStartedAt: voiceStartedAt, cap: cap, boundary: boundary
        )
    }

    @Test func defaultsBeforeAnythingIsMeasured() {
        let estimate = PresenterEstimate(settings: settings)
        #expect(estimate.delay == 0.9)
        #expect(estimate.rate == 2.5)
    }

    @Test func theDelayIsTheMedianWithinItsRange() {
        var estimate = PresenterEstimate(settings: settings)
        for delay in [0.8, 1.0, 1.2, 5.0] { estimate.recordDelay(delay) }
        #expect(abs(estimate.delay - 1.1) < 1e-9)
        var slow = PresenterEstimate(settings: settings)
        for _ in 0..<5 { slow.recordDelay(3) }
        #expect(slow.delay == 2)
        var fast = PresenterEstimate(settings: settings)
        fast.recordDelay(0.1)
        #expect(fast.delay == 0.3)
    }

    @Test func theDelayKeepsOnlyRecentSamples() {
        var estimate = PresenterEstimate(settings: settings)
        for _ in 0..<30 { estimate.recordDelay(1.5) }
        for _ in 0..<20 { estimate.recordDelay(0.7) }
        #expect(abs(estimate.delay - 0.7) < 1e-9)
    }

    @Test func theRateLeavesPausesOut() {
        var estimate = PresenterEstimate(settings: settings)
        // Five words at 0.5 s, a three-second pause, five more at 0.5 s: 2 words a second.
        estimate.recordFinalStarts([0, 0.5, 1, 1.5, 2])
        estimate.recordFinalStarts([5, 5.5, 6, 6.5, 7])
        #expect(abs(estimate.rate - 2) < 1e-9)
    }

    @Test func theRateNeedsEnoughWordsAndStaysInRange() {
        var few = PresenterEstimate(settings: settings)
        few.recordFinalStarts([0, 0.2, 0.4])
        #expect(few.rate == 2.5)
        var gabbling = PresenterEstimate(settings: settings)
        gabbling.recordFinalStarts([0, 0.1, 0.2, 0.3, 0.4, 0.5])
        #expect(gabbling.rate == 4)
    }

    @Test func whileSpeakingTheEstimateAddsTheDelayAndTheTimeSince() {
        let estimate = PresenterEstimate(settings: settings)
        #expect(abs(estimate.position(basis(at: 0), lead: 3, at: 0.5) - (10 + 2.5 * 1.4)) < 1e-9)
    }

    @Test func itStopsCoastingWithNothingNew() {
        let estimate = PresenterEstimate(settings: settings)
        let later = estimate.position(basis(at: 0), lead: 3, at: 1.0)
        #expect(estimate.position(basis(at: 0), lead: 3, at: 5) == later)
        #expect(abs(later - (10 + 2.5 * 1.4)) < 1e-9)
    }

    @Test func afterAFinalItStaysPut() {
        let estimate = PresenterEstimate(settings: settings)
        #expect(estimate.position(basis(afterFinal: true), lead: 3, at: 3) == 10)
        // The voice is in the phrase the presenter is in: still put.
        #expect(estimate.position(basis(afterFinal: true, voiceStart: 8, voiceStartedAt: 1), lead: 3, at: 3) == 10)
    }

    @Test func afterAFinalItFollowsAPhraseTheVoiceHasJustStarted() {
        let estimate = PresenterEstimate(settings: settings)
        let started = basis(confident: 8, afterFinal: true, voiceStart: 11, voiceStartedAt: 1, cap: 20)
        // A lead's worth of time (1.2 s) before the presenter is taken to move on.
        #expect(estimate.position(started, lead: 3, at: 2.2) == 8)
        #expect(abs(estimate.position(started, lead: 3, at: 2.6) - 9) < 1e-9)
        // No further than the phrase's first word, however long.
        #expect(estimate.position(started, lead: 3, at: 10) == 11)
    }

    /// Stopped inside the phrase before, more than `lateStartReach` words short of the voice's
    /// phrase: not taken to have begun it (plan 009, where silence let two phrases through).
    @Test func afterAFinalStoppedWellShortItStaysPut() {
        let estimate = PresenterEstimate(settings: settings)
        let stopped = basis(confident: 14, afterFinal: true, voiceStart: 22, voiceStartedAt: 1, cap: 30)
        #expect(estimate.position(stopped, lead: 5, at: 10) == 14)
    }

    @Test func offScriptItStaysAtTheLastConfidentWord() {
        let estimate = PresenterEstimate(settings: settings)
        #expect(estimate.position(basis(offScript: true), lead: 3, at: 0.5) == 10)
    }

    @Test func itNeverPassesTheEndOfTheVoicesPhrase() {
        let estimate = PresenterEstimate(settings: settings)
        #expect(estimate.position(basis(cap: 12), lead: 3, at: 0.5) == 12)
        // Nor falls behind what was heard.
        #expect(estimate.position(basis(cap: 8), lead: 3, at: 0.5) == 10)
    }

    // MARK: - The phrase boundary (plan 006, #19)

    @Test func fromAPhrasesLastWordTheCoastStopsAtTheNextPhrasesFirstWord() {
        let estimate = PresenterEstimate(settings: settings)
        // Word 10 ends its phrase: 10 + 2.5 × (0.9 + 0.2) would be 12.75.
        #expect(estimate.position(basis(boundary: 11), lead: 3, at: 0.2) == 11)
    }

    @Test func aBoundaryBeyondTheCoastChangesNothing() {
        let estimate = PresenterEstimate(settings: settings)
        #expect(abs(estimate.position(basis(boundary: 13), lead: 3, at: 0.2) - 12.75) < 1e-9)
    }

    @Test func theBoundaryLeavesThePauseRuleAlone() {
        let estimate = PresenterEstimate(settings: settings)
        // After a final, with the voice's phrase two words on: taken to have begun it, past the
        // boundary.
        let paused = basis(afterFinal: true, voiceStart: 13, voiceStartedAt: 0, boundary: 11)
        #expect(estimate.position(paused, lead: 3, at: 5) == 13)
    }
}
