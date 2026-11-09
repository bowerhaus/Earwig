@testable import Earwig
import CoreGraphics
import Foundation
import Testing

/// A repeatable random source, so every walk in these tests is the same each run.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        // SplitMix64.
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// The earwig's walks (plan 014, decisions 2 to 4 and 7).
struct EarwigWalkTests {
    /// The iPhone 17's screen, with a large title's bars at the top and the home indicator below.
    let area = VisitArea(size: CGSize(width: 402, height: 874), top: 116, bottom: 34)
    var planner: WalkPlanner { WalkPlanner(area: area) }

    private func isOffScreen(_ point: CGPoint) -> Bool {
        let half = WalkPlanner.length / 2
        return point.x < -half || point.x > area.size.width + half || point.y < -half || point.y > area.size.height + half
    }

    @Test func aPathIsMeasuredAlongItself() {
        let path = VisitPath(curves: [WalkCurve(start: .zero, control1: CGPoint(x: 100, y: 0),
                                                control2: CGPoint(x: 200, y: 0), end: CGPoint(x: 300, y: 0))])
        #expect(abs(path.length - 300) < 0.01)
        #expect(abs(path.point(at: 150).x - 150) < 0.5)
        #expect(path.point(at: -10) == path.start)
        #expect(path.point(at: 1000) == path.end)
    }

    @Test func headingsFaceTheWayItGoes() {
        #expect(abs(Heading.facing(from: .zero, to: CGPoint(x: 0, y: -1))) < 1e-9, "up is no turn")
        #expect(abs(Heading.facing(from: .zero, to: CGPoint(x: 1, y: 0)) - .pi / 2) < 1e-9, "right is a quarter turn clockwise")
        let direction = Heading.direction(.pi / 2)
        #expect(abs(direction.dx - 1) < 1e-9 && abs(direction.dy) < 1e-9)
        #expect(abs(Heading.turn(from: 3, to: -3) - (2 * .pi - 6)) < 1e-9, "the short way round")
    }

    @Test(arguments: 0..<40)
    func aVisitStartsAndEndsOffScreen(seed: Int) {
        var random = SeededRandom(seed: UInt64(seed))
        let walk = planner.visit(layer: .behind, start: 100, using: &random)
        #expect(isOffScreen(walk.path.start))
        #expect(isOffScreen(walk.path.end))
        #expect(walk.place(at: walk.end + 0.01) == nil, "gone after its end")
        #expect(walk.place(at: walk.end - 0.01) != nil)
    }

    @Test(arguments: 0..<40)
    func aVisitTakesSecondsNotMinutes(seed: Int) {
        var random = SeededRandom(seed: UInt64(seed))
        let walk = planner.visit(layer: .inFront, start: 0, using: &random)
        #expect(walk.duration > 2 && walk.duration < 20, "\(walk.duration) s")
    }

    @Test(arguments: 0..<40)
    func pausesAreWhereItCanBeSeen(seed: Int) {
        var random = SeededRandom(seed: UInt64(seed))
        let walk = planner.visit(layer: .behind, start: 0, using: &random)
        #expect((0...2).contains(walk.pauses.count))
        for pause in walk.pauses {
            #expect(planner.isClear(walk.path.point(at: pause.distance)), "never under a bar or off the edge")
            #expect(WalkPlanner.pauseDurations.contains(pause.duration))
        }
    }

    @Test func itFacesAlongItsRoute() {
        let path = VisitPath(curves: [WalkCurve(start: CGPoint(x: -50, y: 400), control1: CGPoint(x: 100, y: 400),
                                                control2: CGPoint(x: 300, y: 400), end: CGPoint(x: 450, y: 400))])
        let walk = Walk(path: path, speed: 90, layer: .behind, start: 0)
        let place = walk.place(at: 2)
        #expect(abs((place?.heading ?? 0) - .pi / 2) < 0.01, "walking right, it faces right")
        #expect(abs((place?.position.x ?? 0) - 130) < 1, "90 pt a second from x −50")
    }

    @Test func itStandsStillWhilePausedAndItsLegsDoToo() throws {
        let path = VisitPath(curves: [WalkCurve(start: .zero, control1: CGPoint(x: 100, y: 0),
                                                control2: CGPoint(x: 200, y: 0), end: CGPoint(x: 300, y: 0))])
        let walk = Walk(path: path, speed: 100, pauses: [Walk.Pause(distance: 100, duration: 1)], layer: .behind, start: 0)
        let early = try #require(walk.place(at: 1.2))
        let late = try #require(walk.place(at: 1.8))
        #expect(early.position == late.position)
        #expect(early.stepped == late.stepped, "the legs never slide")
        let after = try #require(walk.place(at: 2.5))
        #expect(abs(after.position.x - 150) < 1, "walking again after the pause")
        #expect(abs(walk.duration - 4) < 0.01)
    }

    @Test(arguments: [CGPoint(x: 100, y: 450), CGPoint(x: 300, y: 450), CGPoint(x: 200, y: 200), CGPoint(x: 200, y: 700)])
    func aTapSendsItAwayFromTheFinger(tap: CGPoint) throws {
        let here = CGPoint(x: 200, y: 450)
        let place = WalkPlace(position: here, heading: 0, stepped: 37)
        let run = planner.run(from: place, awayFrom: tap, layer: .inFront, start: 10)
        #expect(run.isRun)
        #expect(run.speed == WalkPlanner.walkingSpeed * WalkPlanner.runningFactor)
        #expect(isOffScreen(run.path.end))
        let away = CGVector(dx: here.x - tap.x, dy: here.y - tap.y)
        let gone = CGVector(dx: run.path.end.x - here.x, dy: run.path.end.y - here.y)
        #expect(away.dot(gone) > 0, "it leaves on the far side from the finger")
        let start = try #require(run.place(at: 10))
        #expect(start.position == here, "it turns on the spot first")
        #expect(start.stepped == 37, "its legs carry on from the walk's")
    }

    @Test func aRunLeavesByTheNearestEdgeAwayFromTheFinger() {
        // Near the right edge, tapped from the left: out to the right, not round the long way.
        let place = WalkPlace(position: CGPoint(x: 370, y: 500), heading: 0, stepped: 0)
        let run = planner.run(from: place, awayFrom: CGPoint(x: 340, y: 500), layer: .inFront, start: 0)
        #expect(run.path.end.x > area.size.width)
        #expect(run.duration < 1.5, "a dash")
    }

    @Test func aRunTurnsTheShortWayToFaceItsRoute() throws {
        let place = WalkPlace(position: CGPoint(x: 200, y: 450), heading: 0, stepped: 0)
        // Tapped from below: it was facing up already, so it hardly turns.
        let run = planner.run(from: place, awayFrom: CGPoint(x: 200, y: 500), layer: .inFront, start: 0)
        let turned = try #require(run.place(at: WalkPlanner.runTurn))
        #expect(abs(Heading.turn(from: 0, to: turned.heading)) < 0.6)
    }
}

/// The gait (plan 014, decision 2).
struct GaitTests {
    @Test func theTwoSetsOfThreeSwingOpposite() {
        let pose = Gait.pose(stepped: WalkPlanner.length * Gait.strideShare / 4, time: 0)
        // The front and back legs of the left side with the middle leg of the right are one set.
        #expect(pose.left[0] == pose.left[2])
        #expect(pose.left[0] == pose.right[1])
        #expect(pose.left[1] == pose.right[0] && pose.left[1] == pose.right[2])
        #expect(pose.left[0] == -pose.left[1])
        #expect(abs(pose.left[0] - Gait.swing) < 1e-9, "a quarter stride is the full swing")
    }

    @Test func theLegsFollowTheDistanceNotTheClock() {
        let one = Gait.pose(stepped: 12, time: 1)
        let other = Gait.pose(stepped: 12, time: 50)
        #expect(one.left == other.left && one.right == other.right && one.sway == other.sway)
        #expect(one.leftAntenna != other.leftAntenna, "the antennae twitch on their own")
    }

    @Test func theSwingStaysSmall() {
        for step in stride(from: 0, through: 200, by: 3.7) {
            let pose = Gait.pose(stepped: CGFloat(step), time: Double(step))
            #expect((pose.left + pose.right).allSatisfy { abs($0) <= Gait.swing + 1e-9 })
            #expect(abs(pose.leftAntenna) < 0.2 && abs(pose.rightAntenna) < 0.2)
        }
    }
}

/// How often it comes and when it keeps away (plan 014, decisions 8 to 11).
@MainActor
struct VisitScheduleTests {
    @Test func neverNeverVisits() {
        #expect(!VisitSchedule.visits(.never, roll: 0, at: 1000, lastVisit: nil))
    }

    @Test func everyVisitIgnoresTheChanceAndTheRest() {
        #expect(VisitSchedule.visits(.everyVisit, roll: 0.99, at: 1000, lastVisit: 999))
    }

    @Test func theChanceDecides() {
        #expect(VisitSchedule.visits(.oneIn10, roll: 0.05, at: 1000, lastVisit: nil))
        #expect(!VisitSchedule.visits(.oneIn10, roll: 0.15, at: 1000, lastVisit: nil))
        #expect(!VisitSchedule.visits(.oneIn50, roll: 0.05, at: 1000, lastVisit: nil))
    }

    @Test func thereIsARestBetweenVisits() {
        #expect(!VisitSchedule.visits(.oneIn2, roll: 0, at: 1000, lastVisit: 1000 - VisitSchedule.rest + 1))
        #expect(VisitSchedule.visits(.oneIn2, roll: 0, at: 1000, lastVisit: 1000 - VisitSchedule.rest))
    }

    @Test func theStepsRunFromNeverToEveryVisit() {
        let chances = VisitFrequency.allCases.map(\.chance)
        #expect(chances.first == 0 && chances.last == 1)
        #expect(chances == chances.sorted())
        #expect(VisitFrequency.allCases.map(\.rawValue) == Array(0..<VisitFrequency.allCases.count), "the slider's steps")
    }

    @Test func theSettingIsReadBackAndDefaultsToOneInTen() throws {
        let defaults = try #require(UserDefaults(suiteName: "EarwigVisitsTests"))
        defaults.removePersistentDomain(forName: "EarwigVisitsTests")
        #expect(VisitFrequency.current(defaults) == .standard)
        #expect(VisitFrequency.standard == .oneIn10)
        defaults.set(VisitFrequency.oneIn50.rawValue, forKey: VisitFrequency.key)
        #expect(VisitFrequency.current(defaults) == .oneIn50)
        defaults.set(VisitFrequency.never.rawValue, forKey: VisitFrequency.key)
        #expect(VisitFrequency.current(defaults) == .never)
        defaults.removePersistentDomain(forName: "EarwigVisitsTests")
    }

    @Test func theDelayIsAMomentAfterTheScreenOpens() {
        var random = SeededRandom(seed: 3)
        for _ in 0..<20 {
            #expect(VisitSchedule.delays.contains(VisitSchedule.delay(for: .oneIn10, using: &random)))
        }
        #expect(VisitSchedule.delay(for: .everyVisit, using: &random) == VisitSchedule.testingDelay)
        #expect(VisitSchedule.testingDelay > SplashTiming.total, "never under the splash")
    }

    private func walk(at start: TimeInterval) -> Walk {
        let path = VisitPath(curves: [WalkCurve(start: .zero, control1: CGPoint(x: 100, y: 0),
                                                control2: CGPoint(x: 200, y: 0), end: CGPoint(x: 300, y: 0))])
        return Walk(path: path, speed: 100, layer: .behind, start: start)
    }

    @Test func noVisitBeforeTheSplashHasGone() {
        let visits = EarwigVisits()
        #expect(!visits.begin(walk(at: 10)))
        visits.ready = true
        #expect(visits.begin(walk(at: 10)))
        #expect(visits.lastVisit == 10)
    }

    @Test func onlyOneAtATime() {
        let visits = EarwigVisits()
        visits.ready = true
        #expect(visits.begin(walk(at: 10)))
        #expect(!visits.begin(walk(at: 12)), "the first is still walking until 13")
        #expect(visits.begin(walk(at: 13.5)))
    }

    @Test func aWalkTakenAwayFreesTheApp() {
        let visits = EarwigVisits()
        visits.ready = true
        #expect(visits.begin(walk(at: 10)))
        visits.ended(at: 11)
        #expect(visits.begin(walk(at: 11.5)))
    }

    @Test func aRunKeepsTheAppBusyUntilItsEnd() {
        let visits = EarwigVisits()
        visits.ready = true
        #expect(visits.begin(walk(at: 10)))
        visits.ran(walk(at: 12))
        #expect(!visits.begin(walk(at: 14)), "the run is out of sight at 15")
        #expect(visits.begin(walk(at: 15)))
    }
}
