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
/// - When the presenter has paused (the recogniser has settled and heard nothing since) and the
///   place ran on past the word after the one they stopped at, it slides back to that word: a
///   pause the punctuation did not mark (Andy's choice, device check 1).
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
    /// How far past the word after a pause the place may sit before it slides back.
    static let settleSlack = 0.6
    /// The longest step taken at once, so a stall in frames is not a leap.
    static let maxStep: TimeInterval = 0.1

    private(set) var place: Double
    /// Words a second.
    private(set) var speed = 0.0
    private var lastTime: TimeInterval?
    private var lastConfident: Int?
    /// `either` is a move the presenter asked for, which may go either way.
    private enum Glide { case none, forward, back, either, settle }
    private var glide = Glide.none
    /// Where a glide is going, while one is under way.
    private var glideTarget: Double?

    /// The place the mark shows: while gliding, the glide's target, so the mark jumps straight
    /// to the word it is going to and does not hop through each word on the way (Andy, device
    /// check 1); otherwise the place.
    var markPlace: Double { glide == .none ? place : glideTarget ?? place }

    init(place: Double = -1) {
        self.place = place
    }

    /// Whether a step toward this estimate would leave the place where it is: no glide, at rest,
    /// and not behind the estimate, nor the confident word fallen back far enough to glide.
    func isAtRest(toward estimate: Double, confident: Int, paused: Bool = false) -> Bool {
        guard glide == .none, speed == 0, estimate <= place + 0.01 else { return false }
        if paused, place > Double(confident + 1) + Self.settleSlack { return false }
        return lastConfident.map { confident >= $0 - Int(Self.backJump) } ?? false
    }

    /// Back, Forward or Restart was pressed: glide to wherever the estimate goes, however near,
    /// either way (review C2: a Back of two words or fewer was not followed).
    mutating func move() {
        glide = .either
    }

    /// Moves the place on to `time`, toward the engine's estimate then; `confident` is the
    /// engine's last confident word.
    mutating func step(toward estimate: Double, confident: Int, paused: Bool = false, at time: TimeInterval) {
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
        if settle(confident: confident, paused: paused, interval: interval) { return }
        if glideIfMoving(toward: estimate, interval: interval) { return }
        track(estimate, interval: interval)
    }

    /// Paused past the word after the one the presenter stopped at: slide back to it. Heard
    /// again, the slide is given up and the place follows as ever. Whether it moved.
    private mutating func settle(confident: Int, paused: Bool, interval: TimeInterval) -> Bool {
        let settled = Double(confident + 1)
        if paused, glide == .none, place > settled + Self.settleSlack { glide = .settle }
        guard glide == .settle else { return false }
        guard paused else {
            glide = .none
            return false
        }
        glideTarget = settled
        place += (settled - place) * (1 - exp(-interval / Self.jumpGlide))
        speed = 0
        if abs(settled - place) <= 0.05 { glide = .none }
        return true
    }

    /// A move: glide there, from rest. A glide forward never turns back. Whether it moved.
    private mutating func glideIfMoving(toward estimate: Double, interval: TimeInterval) -> Bool {
        let error = estimate - place
        if glide == .none, error > Self.forwardJump { glide = .forward }
        guard glide != .none else { return false }
        glideTarget = estimate
        var change = error * (1 - exp(-interval / Self.jumpGlide))
        if glide == .forward { change = max(change, 0) }
        place += change
        speed = 0
        if abs(estimate - place) <= 0.25 || (glide == .forward && error <= 0) { glide = .none }
        return true
    }

    /// Reading on: the second-order tracker, never back, and never more than `overrun` past.
    private mutating func track(_ estimate: Double, interval: TimeInterval) {
        let error = estimate - place
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
