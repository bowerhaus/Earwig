import CoreGraphics
import Foundation

/// What the scrolling text shows each frame (plan 008, decision 3): the place smoothed by
/// `ScreenPlace` and turned into a y by `ScreenLayout`, less any offset dragged by hand. A drag
/// holds until `dragHold` seconds after it ends, then fades away; Back, Forward and Restart end
/// the hold at once and glide to the new place. A reference type, so a frame's update is not a
/// state change; time is passed in, so it is tested without views.
@MainActor
final class ScreenFollower {
    /// How long the text waits after a drag before following again.
    static let dragHold: TimeInterval = 3

    private(set) var screenPlace = ScreenPlace()
    /// Points dragged, positive when the text was pulled down (back).
    private(set) var dragged: CGFloat = 0
    private var dragStart: CGFloat?
    private var heldUntil: TimeInterval?
    private var lastTime: TimeInterval?

    func y(at time: TimeInterval, place: Double, confident: Int, layout: ScreenLayout) -> CGFloat {
        defer { lastTime = time }
        screenPlace.step(toward: place, confident: confident, at: time)
        if dragStart == nil, dragged != 0, let lastTime, time >= heldUntil ?? 0 {
            dragged *= CGFloat(exp(-(time - lastTime) / ScreenPlace.jumpGlide))
            if abs(dragged) < 0.5 { dragged = 0 }
        }
        return layout.y(at: screenPlace.place) - dragged
    }

    func drag(by translation: CGFloat) {
        if dragStart == nil { dragStart = dragged }
        dragged = (dragStart ?? 0) + translation
        heldUntil = .infinity
    }

    func endDrag(at time: TimeInterval) {
        dragStart = nil
        heldUntil = time + Self.dragHold
    }

    /// Back, Forward or Restart: follow again at once, gliding to the new place.
    func moved() {
        dragStart = nil
        heldUntil = nil
        screenPlace.move()
    }
}
