@testable import Earwig
import CoreGraphics
import Testing

/// The scrolling text's follower: a drag holds, then fades away; a move follows at once
/// (plan 008, decision 3; review T2, C2).
@MainActor
struct ScreenFollowerTests {

    /// Words 0–3 on a row each, 50 points apart.
    private let layout: ScreenLayout = {
        let list = PhraseList(lines: ["One two three four."])
        let words = ScreenText.words(phraseList: list, firstWord: FollowScript(phraseList: list).firstWord)
        let frames = Dictionary(uniqueKeysWithValues: (0..<4).map { ($0, CGRect(x: 0, y: CGFloat($0) * 50, width: 100, height: 50)) })
        return ScreenLayout(words: words, frames: frames)
    }()

    private func frames(_ follower: ScreenFollower, from: Double, to: Double, place: Double = 1) -> CGFloat {
        var time = from
        var y: CGFloat = 0
        while time < to - 1e-9 {
            time += 1.0 / 60
            y = follower.y(at: time, place: place, confident: Int(place), layout: layout)
        }
        return y
    }

    @Test func aDragHoldsThenFadesAway() {
        let follower = ScreenFollower()
        let resting = frames(follower, from: 0, to: 1)
        follower.drag(by: 80)
        #expect(frames(follower, from: 1, to: 1.5) == resting - 80)
        follower.endDrag(at: 1.5)
        // Held for three seconds after the drag ends, then back to the place.
        #expect(frames(follower, from: 1.5, to: 4.4) == resting - 80)
        #expect(abs(frames(follower, from: 4.4, to: 6.5) - resting) < 0.5)
    }

    @Test func aMoveFollowsAtOnce() {
        let follower = ScreenFollower()
        let resting = frames(follower, from: 0, to: 1)
        follower.drag(by: 80)
        follower.endDrag(at: 1)
        follower.moved()
        #expect(abs(frames(follower, from: 1, to: 3) - resting) < 0.5)
        #expect(follower.dragged == 0)
    }
}
