import Foundation

/// Where the screen shows the presenter, in script words, smoothed from the engine's estimate
/// (plan 008, decision 3). On the phone the estimate moves in bursts a second apart (plan 006),
/// so it is a sawtooth: four words at once, then still. The shown place follows it as a
/// second-order tracker, with a speed as well as a place, so that while the presenter reads
/// steadily it moves at their pace with no lag and no jumps. Plain values in, so it is tested
/// without views and in the simulated takes.
///
/// - It never runs on more than half a word past the estimate: when the presenter pauses it stops.
///   When the estimate falls back under it, it waits there; it is not pulled back.
/// - It goes back only when the presenter's confident word does, by more than `backJump` words:
///   a step back, Back, Restart, or found behind after Lost. The estimate itself falls back a few
///   words whenever a final settles a block (it stops counting the recogniser's delay), and
///   text that slipped back at every phrase end would be hard to read.
/// - A move like that, or the estimate jumping more than `forwardJump` words ahead (Forward,
///   found ahead), glides there quickly.
struct ScreenPlace: Equatable, Sendable {
    /// How quickly the tracker follows, in radians a second, critically damped.
    static let response = 2.5
    /// Time constant of the glide to a jump.
    static let jumpGlide: TimeInterval = 0.3
    /// A fall back of the confident word by more words than this, or a jump forward of the
    /// estimate by more than `forwardJump`, is a move.
    static let backJump = 2.0
    static let forwardJump = 6.0
    /// How far past the estimate the place may run.
    static let overrun = 0.5
    static let maxSpeed = 8.0
    /// The longest step taken at once, so a stall in frames is not a leap.
    static let maxStep: TimeInterval = 0.1

    private(set) var place: Double
    /// Words a second.
    private(set) var speed = 0.0
    private var lastTime: TimeInterval?
    private var lastConfident: Int?
    /// `either` is a move the presenter asked for, which may go either way.
    private enum Glide { case none, forward, back, either }
    private var glide = Glide.none

    init(place: Double = -1) {
        self.place = place
    }

    /// Back, Forward or Restart was pressed: glide to wherever the estimate goes, however near,
    /// either way (review C2: a Back of two words or fewer was not followed).
    mutating func move() {
        glide = .either
    }

    /// Moves the place on to `time`, toward the engine's estimate then; `confident` is the
    /// engine's last confident word.
    mutating func step(toward estimate: Double, confident: Int, at time: TimeInterval) {
        defer {
            lastTime = time
            lastConfident = confident
        }
        guard let lastTime else {
            place = estimate
            return
        }
        if let lastConfident, confident < lastConfident - Int(Self.backJump) { glide = .back }
        let interval = min(max(time - lastTime, 0), Self.maxStep)
        guard interval > 0 else { return }
        let error = estimate - place
        if glide == .none, error > Self.forwardJump { glide = .forward }
        if glide != .none {
            // A move: glide there, from rest. A glide forward never turns back.
            var change = error * (1 - exp(-interval / Self.jumpGlide))
            if glide == .forward { change = max(change, 0) }
            place += change
            speed = 0
            if abs(estimate - place) <= 0.25 || (glide == .forward && error <= 0) { glide = .none }
            return
        }
        let omega = Self.response
        speed = min(max(speed + omega * omega * error * interval, 0), Self.maxSpeed)
        let next = place + max((speed + 2 * omega * error) * interval, 0)
        if next > estimate + Self.overrun {
            place = max(place, estimate + Self.overrun)
            speed = 0
        } else {
            place = next
        }
    }
}
