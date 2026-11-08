@testable import Earwig
import Testing

/// The screen's place (plan 008, decision 3).
struct ScreenPlaceTests {

    /// Steps the place every 1/60 s from `from` to `to`, toward an estimate given by time.
    private func run(_ place: inout ScreenPlace, from: Double, to: Double, confident: Int = 0, estimate: (Double) -> Double) {
        var time = from
        while time < to - 1e-9 {
            time += 1.0 / 60
            place.step(toward: estimate(time), confident: confident, at: time)
        }
    }

    @Test func theFirstStepIsTheEstimate() {
        var place = ScreenPlace()
        place.step(toward: 7, confident: 6, at: 1)
        #expect(place.place == 7)
    }

    @Test func aSteadyReadIsFollowedWithNoLag() {
        var place = ScreenPlace()
        run(&place, from: 0, to: 6) { 3 * $0 }
        #expect(abs(place.place - 18) < 0.3)
        #expect(abs(place.speed - 3) < 0.2)
    }

    /// The estimate on the phone at 4 words a second: a burst every second, then the engine's
    /// half-second coast, then still until the next.
    private static func bursts(_ time: Double) -> Double {
        let burst = time.rounded(.down)
        return 4 * burst + 4 * min(time - burst, 0.5)
    }

    @Test func burstsBecomeAnEvenMovement() {
        var place = ScreenPlace()
        run(&place, from: 0, to: 4, estimate: Self.bursts)
        var places: [Double] = []
        var time = 4.0
        while time < 8 {
            time += 1.0 / 60
            place.step(toward: Self.bursts(time), confident: 0, at: time)
            places.append(place.place)
        }
        // It keeps moving between bursts, never back, and never by a leap.
        let moves = zip(places.dropFirst(), places).map { $0 - $1 }
        #expect(moves.allSatisfy { $0 >= 0 })
        #expect(moves.filter { $0 > 0.001 }.count > moves.count * 3 / 4)
        #expect(moves.allSatisfy { $0 < 0.25 })
        #expect(abs(place.place - Self.bursts(8)) < 2)
    }

    @Test func aPauseStopsItHalfAWordPastTheEstimate() {
        var place = ScreenPlace()
        run(&place, from: 0, to: 3) { min(3 * $0, 6) }
        #expect(place.place <= 6 + ScreenPlace.overrun + 1e-9)
        #expect(place.place > 5.5)
        #expect(place.speed == 0 || place.place < 6.5)
    }

    @Test func aFallInTheEstimateDoesNotMoveItBack() {
        var place = ScreenPlace()
        run(&place, from: 0, to: 2) { 3 * $0 }
        let reached = place.place
        // A final settles the block: the estimate falls three words, the confident word does not.
        run(&place, from: 2, to: 3) { _ in 3 }
        #expect(place.place >= reached)
    }

    @Test func aStepBackGlidesBackQuickly() {
        var place = ScreenPlace()
        run(&place, from: 0, to: 4, confident: 11) { _ in 12 }
        #expect(abs(place.place - 12) < 0.01)
        // Back: the confident word goes to the start of an earlier phrase.
        run(&place, from: 4, to: 5.5, confident: 3) { _ in 3 }
        #expect(abs(place.place - 3) < 0.3)
        #expect(place.speed == 0)
    }

    @Test func aJumpForwardGlidesQuicklyAndNeverTurnsBack() {
        var place = ScreenPlace()
        run(&place, from: 0, to: 1) { _ in 0 }
        var last = place.place
        var time = 1.0
        var turnedBack = false
        while time < 2.5 {
            time += 1.0 / 60
            place.step(toward: 20, confident: 19, at: time)
            if place.place < last { turnedBack = true }
            last = place.place
        }
        #expect(!turnedBack)
        #expect(abs(place.place - 20) < 0.3)
    }

    @Test func aStallInFramesIsNotALeap() {
        var place = ScreenPlace()
        run(&place, from: 0, to: 2) { 3 * $0 }
        let before = place.place
        place.step(toward: before + 5, confident: 0, at: 10)
        #expect(place.place - before < 4)
    }
}
