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

    /// Off screen at both ends, a crossing of seconds, out at a side when in at the top or the
    /// foot, and pauses only where it can be seen.
    @Test(arguments: 0..<40)
    func aVisitCrossesTheScreen(seed: Int) {
        var random = SeededRandom(seed: UInt64(seed))
        let walk = planner.visit(start: 100, using: &random)
        let start = walk.path.start, end = walk.path.end
        #expect(isOffScreen(start) && isOffScreen(end))
        #expect(walk.place(at: walk.end + 0.01) == nil, "gone after its end")
        #expect(walk.place(at: walk.end - 0.01) != nil)
        #expect(walk.duration > 2 && walk.duration < 15, "\(walk.duration) s")
        if start.y < 0 || start.y > area.size.height {
            #expect(end.x < 0 || end.x > area.size.width, "never the phone's whole height")
        }
        #expect((0...2).contains(walk.pauses.count))
        for pause in walk.pauses {
            #expect(planner.isClear(walk.path.point(at: pause.distance)), "never under a bar or off the edge")
            #expect(WalkPlanner.pauseDurations.contains(pause.duration))
        }
    }

    @Test func itFacesAlongItsRoute() {
        let path = VisitPath(curves: [WalkCurve(start: CGPoint(x: -50, y: 400), control1: CGPoint(x: 100, y: 400),
                                                control2: CGPoint(x: 300, y: 400), end: CGPoint(x: 450, y: 400))])
        let walk = Walk(path: path, speed: 90, start: 0)
        let place = walk.place(at: 2)
        #expect(abs((place?.heading ?? 0) - .pi / 2) < 0.01, "walking right, it faces right")
        #expect(abs((place?.position.x ?? 0) - 130) < 1, "90 pt a second from x −50")
    }

    @Test func itStandsStillWhilePausedAndItsLegsDoToo() throws {
        let path = VisitPath(curves: [WalkCurve(start: .zero, control1: CGPoint(x: 100, y: 0),
                                                control2: CGPoint(x: 200, y: 0), end: CGPoint(x: 300, y: 0))])
        let walk = Walk(path: path, speed: 100, pauses: [Walk.Pause(distance: 100, duration: 1)], start: 0)
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
        let run = planner.run(from: place, awayFrom: tap, start: 10)
        #expect(run.isRun)
        #expect(isOffScreen(run.path.end))
        let away = CGVector(dx: here.x - tap.x, dy: here.y - tap.y)
        let gone = CGVector(dx: run.path.end.x - here.x, dy: run.path.end.y - here.y)
        #expect(away.dot(gone) > 0, "it leaves on the far side from the finger")
        #expect(try #require(run.place(at: 10)).stepped == 37, "its legs carry on from the walk's")
    }

    @Test func aRunLeavesByTheNearestEdgeAwayFromTheFinger() {
        // Near the right edge, tapped from the left: out to the right, not round the long way.
        let place = WalkPlace(position: CGPoint(x: 370, y: 500), heading: 0, stepped: 0)
        let run = planner.run(from: place, awayFrom: CGPoint(x: 340, y: 500), start: 0)
        #expect(run.path.end.x > area.size.width)
        #expect(run.duration < 1.5, "a dash")
    }

    @Test func aRunTurnsOnTheSpotTheShortWayRound() throws {
        // Facing down and tapped from below: it turns to run up, by way of the nearer side.
        let here = CGPoint(x: 200, y: 450)
        let facing: CGFloat = .pi - 0.3
        let place = WalkPlace(position: here, heading: facing, stepped: 0)
        let run = planner.run(from: place, awayFrom: CGPoint(x: 200, y: 500), start: 0)
        let target = run.path.heading(at: 0)
        let halfway = try #require(run.place(at: WalkPlanner.runTurn / 2))
        #expect(halfway.position == here, "it turns before it moves")
        let whole = Heading.turn(from: facing, to: target), sofar = Heading.turn(from: facing, to: halfway.heading)
        #expect(sofar * whole > 0 && abs(sofar) < abs(whole), "partway round, the short way")
        let turned = try #require(run.place(at: WalkPlanner.runTurn))
        #expect(abs(Heading.turn(from: turned.heading, to: target)) < 0.01)
    }

    private func walkAcross(at start: TimeInterval) -> Walk {
        let path = VisitPath(curves: [WalkCurve(start: CGPoint(x: -50, y: 400), control1: CGPoint(x: 100, y: 400),
                                                control2: CGPoint(x: 300, y: 400), end: CGPoint(x: 450, y: 400))])
        return Walk(path: path, speed: 90, start: start)
    }

    /// Under a card only when it would be out within two seconds; over it otherwise (Andy,
    /// device check 2). The walk goes right along y 400 at 90 pt a second, so 2 s is 180 pt.
    @Test func underAShortCardOverALongOne() {
        let walk = walkAcross(at: 0)
        let short = CGRect(x: 100, y: 370, width: 120, height: 60)
        let long = CGRect(x: 20, y: 370, width: 360, height: 60)
        #expect(walk.layer(at: 160, cards: [short]) == .behind)
        #expect(walk.layer(at: 160, cards: [long]) == .inFront)
        #expect(walk.layer(at: 160, cards: []) == .inFront)
        #expect(walk.layer(at: 0, cards: [short]) == .inFront, "away from the cards")
    }

    @Test func itGoesUnderFromHeadToTail() {
        let walk = walkAcross(at: 0)
        let card = CGRect(x: 150, y: 370, width: 100, height: 60)
        // The route starts at x −50, so distance d is at x d − 50; the earwig is 70 pt long.
        #expect(walk.layer(at: 175, cards: [card]) == .behind, "its head, at x 160, is under")
        #expect(walk.layer(at: 160, cards: [card]) == .inFront, "its head, at x 145, is not yet")
        #expect(walk.layer(at: 325, cards: [card]) == .behind, "its tail, at x 240, is still under")
    }

    @Test func touchingCardsAreOneStretch() throws {
        let walk = walkAcross(at: 0)
        // Two rows of one card, 100 pt each: 200 pt together, over two seconds.
        let rows = [CGRect(x: 100, y: 370, width: 100, height: 60), CGRect(x: 200, y: 370, width: 100, height: 60)]
        let stretch = try #require(walk.stretchUnderCards(at: 200, cards: rows))
        #expect(abs(stretch - 200) < 8)
        #expect(walk.layer(at: 200, cards: rows) == .inFront)
    }

    @Test func leavingAtOnceLeavesNothing() {
        #expect(planner.leaving(walkAcross(at: 0), .vanishes, at: 2) == nil)
        #expect(planner.leaving(walkAcross(at: 0), .runsOff, at: 100) == nil, "already gone")
    }

    @Test func runningOffGoesStraightOn() throws {
        let walk = walkAcross(at: 0)
        let run = try #require(planner.leaving(walk, .runsOff, at: 2))
        #expect(run.isRun)
        #expect(run.path.end.x > area.size.width, "on to the right, the way it was going")
        #expect(planner.leaving(run, .runsOff, at: 2.1) == run, "a run is left to finish")
        #expect(planner.leaving(run, .vanishes, at: 2.1) == nil)
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
        defaults.set(true, forKey: "EarwigVisits")
        #expect(VisitFrequency.current(defaults) == .everyVisit, "-EarwigVisits YES, in a Debug build")
        defaults.removePersistentDomain(forName: "EarwigVisitsTests")
    }

    @Test func everyVisitComesSoonButNeverUnderTheSplash() {
        var random = SeededRandom(seed: 3)
        #expect(VisitSchedule.delay(for: .everyVisit, using: &random) == VisitSchedule.testingDelay)
        #expect(VisitSchedule.testingDelay > SplashTiming.total, "never under the splash")
    }

    private func walk(at start: TimeInterval) -> Walk {
        let path = VisitPath(curves: [WalkCurve(start: .zero, control1: CGPoint(x: 100, y: 0),
                                                control2: CGPoint(x: 200, y: 0), end: CGPoint(x: 300, y: 0))])
        return Walk(path: path, speed: 100, start: start)
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
        #expect(visits.lastVisit == 10, "the rest still runs from when it began")
        #expect(visits.begin(walk(at: 11.5)))
    }

    @Test func aRunKeepsTheAppBusyUntilItsEnd() {
        let visits = EarwigVisits()
        visits.ready = true
        #expect(visits.begin(walk(at: 10)))
        visits.ran(walk(at: 12))
        #expect(visits.lastVisit == 10, "a tap does not restart the rest")
        #expect(!visits.begin(walk(at: 14)), "the run is out of sight at 15")
        #expect(visits.begin(walk(at: 15)))
    }
}
