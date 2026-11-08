import Foundation

/// Where the screen shows the presenter, in script words, smoothed from the engine's place: the
/// word after the last one heard (plan 008, decision 3). That place moves in steps, a burst of
/// words about once a second on the phone (plan 006), so the shown place follows it as a
/// second-order tracker, with a speed as well as a place, and turns the bursts into an even
/// movement at the presenter's pace. Plain values in, so it is tested without views and in the
/// simulated takes. Two rules:
///
/// - **A move glides.** Back, Forward or Restart (`move()`), the place falling more than
///   `backJump` words behind (the presenter stepped back), or jumping more than `forwardJump`
///   ahead: the place glides there quickly, and the mark shows the word it is going to at once.
/// - **Otherwise it follows forward**, never back, and never as far as the word after the
///   engine's place: it may run on into that word (up to `runOn`), so the scroll keeps moving
///   between bursts, but the mark, which is on whole words, never passes the next word to say.
///   A fall of a word or two, as the recogniser rewrites a block, is waited out.
struct ScreenPlace: Equatable, Sendable {
    /// How quickly the tracker follows, in radians a second, critically damped. 1.5 moved on 96%
    /// of frames through bursts of four words a second, against 68% at 2.5, for 0.2 words more
    /// trail in the simulated takes.
    static let response = 1.5
    /// Time constant of a glide.
    static let jumpGlide: TimeInterval = 0.3
    /// Past the run-on into the next word, a fall of more than a word and a half; the engine's
    /// own step back is three words or more.
    static let backJump = 2.5
    static let forwardJump = 6.0
    static let maxSpeed = 8.0
    /// How far into the next word the place may run, short of a whole word.
    static let runOn = 0.9
    /// The longest step taken at once, so a stall in frames is not a leap.
    static let maxStep: TimeInterval = 0.1

    private(set) var place: Double
    /// Words a second.
    private(set) var speed = 0.0
    private var lastTime: TimeInterval?
    /// Where a glide is going, while one is under way.
    private var glideTarget: Double?
    private var gliding = false

    init(place: Double = -1) {
        self.place = place
    }

    /// The place the mark shows: while gliding, the target, so the mark jumps straight to the
    /// word it is going to and does not hop through each word on the way (Andy, device check 1);
    /// otherwise the place.
    var markPlace: Double { gliding ? glideTarget ?? place : place }

    /// Back, Forward or Restart was pressed: glide to the engine's place, however near.
    mutating func move() {
        gliding = true
        glideTarget = nil
    }

    /// Whether a step toward this place would leave the shown place where it is.
    func isAtRest(toward target: Double) -> Bool {
        !gliding && speed == 0 && target <= place + 0.01 && target >= place - Self.backJump
    }

    /// Moves the shown place on to `time`, toward the engine's place then.
    mutating func step(toward target: Double, at time: TimeInterval) {
        defer { lastTime = time }
        guard let lastTime else {
            place = target
            return
        }
        let interval = min(max(time - lastTime, 0), Self.maxStep)
        guard interval > 0 else { return }
        let error = target - place
        if error < -Self.backJump || error > Self.forwardJump { gliding = true }
        if gliding {
            glideTarget = target
            place += error * (1 - exp(-interval / Self.jumpGlide))
            speed = 0
            // Landed on the target exactly: just short of it, gliding forward, is still the word
            // before, and the mark showed it for a moment (device check 2 of plan 008).
            if abs(target - place) <= 0.05 {
                place = target
                gliding = false
            }
            return
        }
        let omega = Self.response
        speed = min(max(speed + omega * omega * error * interval, 0), Self.maxSpeed)
        let next = place + max((speed + 2 * omega * error) * interval, 0)
        let limit = target + Self.runOn
        if next >= limit {
            place = max(place, limit)
            speed = 0
        } else {
            place = next
        }
    }
}
