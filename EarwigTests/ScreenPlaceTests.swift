@testable import Earwig
import Testing

/// The screen's place (plan 008, decision 3): two rules, a move glides and otherwise it follows
/// forward.
struct ScreenPlaceTests {

    /// Steps the place every 1/60 s from `from` to `to`, toward a target given by time.
    private func run(_ place: inout ScreenPlace, from: Double, to: Double, target: (Double) -> Double) {
        var time = from
        while time < to - 1e-9 {
            time += 1.0 / 60
            place.step(toward: target(time), at: time)
        }
    }

    /// The engine's place on the phone at 4 words a second: four words heard at once, every second.
    private static func bursts(_ time: Double) -> Double { 4 * time.rounded(.down) }

    @Test func theFirstStepIsTheTarget() {
        var place = ScreenPlace()
        place.step(toward: 7, at: 1)
        #expect(place.place == 7)
    }

    @Test func burstsBecomeAnEvenMovement() {
        var place = ScreenPlace()
        run(&place, from: 0, to: 4, target: Self.bursts)
        var places: [Double] = []
        var time = 4.0
        while time < 8 {
            time += 1.0 / 60
            place.step(toward: Self.bursts(time), at: time)
            places.append(place.place)
        }
        // It moves on nearly every frame, never back, and never by a leap.
        let moves = zip(places.dropFirst(), places).map { $0 - $1 }
        #expect(moves.allSatisfy { $0 >= 0 })
        #expect(Double(moves.filter { $0 > 0.001 }.count) / Double(moves.count) > 0.9)
        #expect(moves.allSatisfy { $0 < 0.25 })
    }

    @Test func itNeverReachesTheWordAfterTheTarget() {
        var place = ScreenPlace()
        run(&place, from: 0, to: 6) { $0 < 1 ? 0 : 6 }
        #expect(place.place < 7)
        #expect(Int(place.markPlace.rounded(.down)) == 6)
        #expect(place.speed == 0)
    }

    @Test func aSmallFallIsWaitedOut() {
        var place = ScreenPlace()
        run(&place, from: 0, to: 2) { _ in 10 }
        let reached = place.place
        run(&place, from: 2, to: 3) { _ in 9 }
        #expect(place.place == reached)
    }

    @Test func aStepBackGlidesAndTheMarkIsAtTheTargetAtOnce() {
        var place = ScreenPlace()
        run(&place, from: 0, to: 2) { _ in 12 }
        place.step(toward: 3, at: 2 + 1.0 / 60)
        #expect(place.place > 11)
        #expect(Int(place.markPlace.rounded(.down)) == 3)
        run(&place, from: 2 + 1.0 / 60, to: 4) { _ in 3 }
        #expect(abs(place.place - 3) < 0.1)
        #expect(place.markPlace == place.place)
    }

    /// A glide forward, after a big jump or a move, puts the mark on the target at once, never
    /// on a word before it, and ends there.
    @Test(arguments: [false, true])
    func aGlideForwardMarksTheTargetAtOnce(_ moved: Bool) {
        var place = ScreenPlace()
        run(&place, from: 0, to: 2) { _ in moved ? 7 : 0 }
        // Forward to a phrase starting at word 12, or a jump to word 20.
        let target: Double = moved ? 12 : 20
        if moved { place.move() }
        var marks: [Int] = []
        var time = 2.0
        while time < 5 {
            time += 1.0 / 60
            place.step(toward: target, at: time)
            marks.append(Int(place.markPlace.rounded(.down)))
        }
        #expect(marks.allSatisfy { $0 == Int(target) })
        #expect(((target - 0.1)..<(target + ScreenPlace.runOn + 0.01)).contains(place.place))
    }

    @Test func aMoveGlidesHoweverNear() {
        var place = ScreenPlace()
        run(&place, from: 0, to: 2) { _ in 12 }
        // Back into a one-word phrase: one word back, which alone would be waited out.
        place.move()
        run(&place, from: 2, to: 3.5) { _ in 11 }
        #expect(abs(place.place - 11) < 0.1)
    }

    @Test func aStallInFramesIsNotALeap() {
        var place = ScreenPlace()
        run(&place, from: 0, to: 2) { _ in 4 }
        let before = place.place
        place.step(toward: before + 5, at: 10)
        #expect(place.place - before < 4)
    }
}
