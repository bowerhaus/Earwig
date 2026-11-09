import CoreGraphics
import Foundation

/// Which side of the cards a walk is on (plan 014, decision 6): behind them, seen only in the
/// gaps, or over them, where a tap sends it running.
enum VisitLayer: Equatable, Sendable {
    case behind
    case inFront
}

/// One cubic stretch of a walk.
struct WalkCurve: Equatable, Sendable {
    var start: CGPoint
    var control1: CGPoint
    var control2: CGPoint
    var end: CGPoint

    func point(at t: CGFloat) -> CGPoint {
        let u = 1 - t
        let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
        return CGPoint(x: a * start.x + b * control1.x + c * control2.x + d * end.x,
                       y: a * start.y + b * control1.y + c * control2.y + d * end.y)
    }
}

/// A walk's route, sampled by distance along it (plan 014, decision 4), so a place can be found
/// for any distance walked.
struct VisitPath: Equatable, Sendable {
    let points: [CGPoint]
    /// The distance along the route to each point.
    let distances: [CGFloat]

    init(curves: [WalkCurve], samplesPerCurve: Int = 96) {
        var points: [CGPoint] = []
        for (index, curve) in curves.enumerated() {
            for step in (index == 0 ? 0 : 1)...samplesPerCurve {
                points.append(curve.point(at: CGFloat(step) / CGFloat(samplesPerCurve)))
            }
        }
        var distances: [CGFloat] = [0]
        for index in points.indices.dropFirst() {
            distances.append(distances[index - 1] + points[index].distance(to: points[index - 1]))
        }
        self.points = points
        self.distances = distances
    }

    var length: CGFloat { distances.last ?? 0 }
    var start: CGPoint { points.first ?? .zero }
    var end: CGPoint { points.last ?? .zero }

    func point(at distance: CGFloat) -> CGPoint {
        guard points.count > 1 else { return start }
        let distance = min(max(distance, 0), length)
        // The last sample at or before the distance, by halving.
        var low = 0, high = distances.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if distances[middle] <= distance { low = middle } else { high = middle }
        }
        let span = distances[high] - distances[low]
        let fraction = span > 0 ? (distance - distances[low]) / span : 0
        return points[low].moved(toward: points[high], by: fraction)
    }

    /// The figure's turn to face along the route: 0 is head up, a quarter turn clockwise faces
    /// right. Taken across a few points either side, so a sample's kink cannot jerk it.
    func heading(at distance: CGFloat) -> CGFloat {
        let reach: CGFloat = 4
        let behind = point(at: min(distance - reach, length - 2 * reach))
        let ahead = point(at: max(distance + reach, 2 * reach))
        return Heading.facing(from: behind, to: ahead)
    }
}

enum Heading {
    /// The turn that faces the upright figure (head toward −y) from one point to another.
    static func facing(from: CGPoint, to: CGPoint) -> CGFloat {
        atan2(to.x - from.x, from.y - to.y)
    }

    /// The direction a heading faces, as a unit vector.
    static func direction(_ heading: CGFloat) -> CGVector {
        CGVector(dx: sin(heading), dy: -cos(heading))
    }

    /// The shortest turn from one heading to another, between −π and π.
    static func turn(from: CGFloat, to: CGFloat) -> CGFloat {
        var delta = (to - from).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return delta
    }
}

/// Where the earwig is at a moment of its walk.
struct WalkPlace: Equatable, Sendable {
    var position: CGPoint
    var heading: CGFloat
    /// How far its legs have walked, for the gait: it grows while it walks or turns and stands
    /// still while it pauses, so the legs never slide.
    var stepped: CGFloat
}

/// One walk across the screen, or one run off it (plan 014, decisions 4 and 7). Everything
/// follows from the time since it began, so the view only asks `place(at:)`.
struct Walk: Identifiable, Equatable, Sendable {
    struct Pause: Equatable, Sendable {
        var distance: CGFloat
        var duration: TimeInterval
    }

    /// A turn on the spot before setting off, from the heading it had: a run starts with one.
    struct Turn: Equatable, Sendable {
        var from: CGFloat
        var duration: TimeInterval
    }

    let id = UUID()
    let path: VisitPath
    /// Points a second.
    let speed: CGFloat
    /// In order along the route.
    let pauses: [Pause]
    let turn: Turn?
    let layer: VisitLayer
    /// When it began, as `Date.timeIntervalSinceReferenceDate`.
    let start: TimeInterval
    let isRun: Bool
    /// How far its legs had walked when it began, so a run's legs carry on from the walk's.
    let steppedBefore: CGFloat

    init(path: VisitPath, speed: CGFloat, pauses: [Pause] = [], turn: Turn? = nil, layer: VisitLayer,
         start: TimeInterval, isRun: Bool = false, steppedBefore: CGFloat = 0) {
        self.path = path
        self.speed = speed
        self.pauses = pauses.sorted { $0.distance < $1.distance }
        self.turn = turn
        self.layer = layer
        self.start = start
        self.isRun = isRun
        self.steppedBefore = steppedBefore
    }

    /// Legs shuffle at this share of the speed while it turns on the spot.
    static let turningStep: CGFloat = 0.5

    var duration: TimeInterval {
        (turn?.duration ?? 0) + TimeInterval(path.length / speed) + pauses.reduce(0) { $0 + $1.duration }
    }

    var end: TimeInterval { start + duration }

    /// Where it is at a moment, or nil once it has gone.
    func place(at time: TimeInterval) -> WalkPlace? {
        let elapsed = max(0, time - start)
        guard elapsed <= duration else { return nil }
        let turning = turn?.duration ?? 0
        if let turn, elapsed < turning {
            let fraction = CGFloat(elapsed / turning)
            let eased = fraction * fraction * (3 - 2 * fraction)
            let heading = turn.from + Heading.turn(from: turn.from, to: path.heading(at: 0)) * eased
            return WalkPlace(position: path.start, heading: heading,
                             stepped: steppedBefore + speed * Self.turningStep * CGFloat(elapsed))
        }
        let walked = distance(after: elapsed - turning)
        return WalkPlace(position: path.point(at: walked), heading: path.heading(at: walked),
                         stepped: steppedBefore + speed * Self.turningStep * CGFloat(turning) + walked)
    }

    /// The distance along the route after so long walking, allowing for the pauses.
    private func distance(after time: TimeInterval) -> CGFloat {
        var walked: CGFloat = 0
        var remaining = time
        for pause in pauses {
            let toPause = TimeInterval((pause.distance - walked) / speed)
            if remaining < toPause { return walked + speed * CGFloat(remaining) }
            remaining -= toPause
            walked = pause.distance
            if remaining < pause.duration { return walked }
            remaining -= pause.duration
        }
        return min(path.length, walked + speed * CGFloat(remaining))
    }
}

/// The space a walk crosses: the screen, and the bars at its top and foot, where it never pauses.
struct VisitArea: Equatable, Sendable {
    var size: CGSize
    var top: CGFloat
    var bottom: CGFloat

    static let zero = VisitArea(size: .zero, top: 0, bottom: 0)
}

/// Makes the walks (plan 014, decisions 3, 4 and 7).
struct WalkPlanner {
    /// The earwig's length on screen, from its antennae to its forceps, tuned on the phone.
    static let length: CGFloat = 70
    /// About 1.5 cm a second on the 14 Pro, near a real earwig's pace.
    static let walkingSpeed: CGFloat = 90
    static let runningFactor: CGFloat = 4
    static let runTurn: TimeInterval = 0.15
    static let pauseDurations: ClosedRange<Double> = 0.5...1.5
    /// The share of walks that turn back halfway and leave the way they came.
    static let turnBackChance = 0.2

    let area: VisitArea
    var length: CGFloat = Self.length

    /// Far enough past an edge that none of it shows.
    private var margin: CGFloat { length * 0.6 }
    private var width: CGFloat { area.size.width }
    private var height: CGFloat { area.size.height }

    enum Edge: CaseIterable {
        case left, right, top, bottom

        var outward: CGVector {
            switch self {
            case .left: CGVector(dx: -1, dy: 0)
            case .right: CGVector(dx: 1, dy: 0)
            case .top: CGVector(dx: 0, dy: -1)
            case .bottom: CGVector(dx: 0, dy: 1)
            }
        }
    }

    /// A walk across, entering off one edge and leaving off another, or turning back.
    func visit<G: RandomNumberGenerator>(layer: VisitLayer, start: TimeInterval, using random: inout G) -> Walk {
        let entry = randomEdge(using: &random)
        let from = offScreen(entry, using: &random)
        let curves: [WalkCurve]
        if Double.random(in: 0..<1, using: &random) < Self.turnBackChance {
            curves = turningBack(from: from, at: entry, using: &random)
        } else {
            // In at the top or the foot, out at a side, so no walk is the phone's whole height.
            let exits = entry == .top || entry == .bottom ? [Edge.left, .right] : Edge.allCases.filter { $0 != entry }
            let exit = exits.randomElement(using: &random) ?? .right
            curves = [gentle(from: from, to: offScreen(exit, using: &random), using: &random)]
        }
        let path = VisitPath(curves: curves)
        return Walk(path: path, speed: Self.walkingSpeed, pauses: pauses(on: path, using: &random), layer: layer, start: start)
    }

    /// A run from where it is, turning away from the finger and off the nearest edge that lies
    /// away from it.
    func run(from place: WalkPlace, awayFrom tap: CGPoint, layer: VisitLayer, start: TimeInterval) -> Walk {
        let here = place.position
        var away = CGVector(dx: here.x - tap.x, dy: here.y - tap.y)
        if away.length < 1 { away = Heading.direction(place.heading) }
        away = away.unit
        // Edges within about 70° of straight away; one is always within 45°.
        let edges = Edge.allCases.filter { $0.outward.dot(away) > 0.3 }
        let edge = (edges.isEmpty ? Edge.allCases : edges).min { distance(from: here, to: $0) < distance(from: here, to: $1) } ?? .right
        let exit = beyond(edge, from: here)
        let curve = WalkCurve(start: here,
                              control1: here.offset(by: away, times: length * 1.2),
                              control2: exit.offset(by: edge.outward, times: -length),
                              end: exit)
        return Walk(path: VisitPath(curves: [curve]), speed: Self.walkingSpeed * Self.runningFactor,
                    turn: Walk.Turn(from: place.heading, duration: Self.runTurn), layer: layer, start: start,
                    isRun: true, steppedBefore: place.stepped)
    }

    func distance(from point: CGPoint, to edge: Edge) -> CGFloat {
        switch edge {
        case .left: point.x
        case .right: width - point.x
        case .top: point.y
        case .bottom: height - point.y
        }
    }

    /// Mostly across the phone, sometimes up or down it.
    private func randomEdge<G: RandomNumberGenerator>(using random: inout G) -> Edge {
        let roll = Double.random(in: 0..<1, using: &random)
        return roll < 0.35 ? .left : roll < 0.7 ? .right : roll < 0.85 ? .top : .bottom
    }

    /// A point just off an edge, along the part of it clear of the bars.
    private func offScreen<G: RandomNumberGenerator>(_ edge: Edge, using random: inout G) -> CGPoint {
        let low = area.top + length, high = max(area.top + length, height - area.bottom - length)
        switch edge {
        case .left: return CGPoint(x: -margin, y: CGFloat.random(in: low...high, using: &random))
        case .right: return CGPoint(x: width + margin, y: CGFloat.random(in: low...high, using: &random))
        case .top: return CGPoint(x: CGFloat.random(in: (width * 0.2)...(width * 0.8), using: &random), y: -margin)
        case .bottom: return CGPoint(x: CGFloat.random(in: (width * 0.2)...(width * 0.8), using: &random), y: height + margin)
        }
    }

    /// The point off an edge straight out from a point.
    private func beyond(_ edge: Edge, from point: CGPoint) -> CGPoint {
        switch edge {
        case .left: CGPoint(x: -margin, y: point.y)
        case .right: CGPoint(x: width + margin, y: point.y)
        case .top: CGPoint(x: point.x, y: -margin)
        case .bottom: CGPoint(x: point.x, y: height + margin)
        }
    }

    /// A curve that bends gently either side of the straight line, so a walk across takes
    /// seconds, not a tour of the screen.
    private func gentle<G: RandomNumberGenerator>(from: CGPoint, to: CGPoint, using random: inout G) -> WalkCurve {
        let line = CGVector(dx: to.x - from.x, dy: to.y - from.y)
        let across = CGVector(dx: -line.dy, dy: line.dx).unit
        let bend = { (random: inout G) in across.scaled(by: line.length * CGFloat.random(in: -0.25...0.25, using: &random)) }
        let first = bend(&random), second = bend(&random)
        return WalkCurve(start: from,
                         control1: from.offset(by: line, times: 1.0 / 3).offset(by: first, times: 1),
                         control2: from.offset(by: line, times: 2.0 / 3).offset(by: second, times: 1),
                         end: to)
    }

    /// A point well inside the screen, for the curves to bend toward.
    private func inside<G: RandomNumberGenerator>(using random: inout G) -> CGPoint {
        let top = area.top + length, bottom = max(top, height - area.bottom - length)
        return CGPoint(x: CGFloat.random(in: (width * 0.15)...(width * 0.85), using: &random),
                       y: CGFloat.random(in: top...bottom, using: &random))
    }

    /// In to a point, a loop round, and back out off the same edge. The two curves share their
    /// direction where they meet, so it turns without a jerk.
    private func turningBack<G: RandomNumberGenerator>(from: CGPoint, at edge: Edge, using random: inout G) -> [WalkCurve] {
        let turnPoint = inside(using: &random)
        let approach = inside(using: &random)
        var direction = CGVector(dx: turnPoint.x - approach.x, dy: turnPoint.y - approach.y)
        if direction.length < 1 { direction = edge.outward.scaled(by: -1) }
        direction = direction.unit
        let reach = length * 1.5
        let back = offScreen(edge, using: &random)
        return [
            WalkCurve(start: from, control1: approach, control2: turnPoint.offset(by: direction, times: -reach), end: turnPoint),
            WalkCurve(start: turnPoint, control1: turnPoint.offset(by: direction, times: reach),
                      control2: back.offset(by: edge.outward, times: -length * 2), end: back),
        ]
    }

    /// One or two pauses where it can be seen, clear of the bars and apart from each other.
    private func pauses<G: RandomNumberGenerator>(on path: VisitPath, using random: inout G) -> [Walk.Pause] {
        let wanted = Int.random(in: 1...2, using: &random)
        var found: [Walk.Pause] = []
        for _ in 0..<20 where found.count < wanted {
            let distance = CGFloat.random(in: (path.length * 0.2)...(path.length * 0.8), using: &random)
            guard isClear(path.point(at: distance)),
                  found.allSatisfy({ abs($0.distance - distance) > path.length * 0.15 }) else { continue }
            found.append(Walk.Pause(distance: distance, duration: Double.random(in: Self.pauseDurations, using: &random)))
        }
        return found.sorted { $0.distance < $1.distance }
    }

    /// Whether the whole earwig is on screen and clear of the bars at a point.
    func isClear(_ point: CGPoint) -> Bool {
        let half = length / 2
        return point.x > half && point.x < width - half && point.y > area.top + half && point.y < height - area.bottom - half
    }
}

/// The earwig's legs, body and antennae for a moment of a walk (plan 014, decision 2). Insects
/// walk on two alternating sets of three legs: the front and back legs of one side with the
/// middle leg of the other. Angles are in radians; a leg's is how far it has swung forward.
struct Gait {
    /// How far each leg swings either side of where the mark draws it, tuned on the phone.
    static let swing: CGFloat = 12 * .pi / 180
    /// How much the body yaws with each step.
    static let sway: CGFloat = 1.5 * .pi / 180
    /// The distance walked in one full step of both sets, as a share of the earwig's length.
    static let strideShare: CGFloat = 0.45

    struct Pose: Equatable, Sendable {
        /// Front, middle and back, for each side.
        var left: [CGFloat]
        var right: [CGFloat]
        var sway: CGFloat
        var leftAntenna: CGFloat
        var rightAntenna: CGFloat
    }

    /// The stance the mark is drawn in.
    static let still = Pose(left: [0, 0, 0], right: [0, 0, 0], sway: 0, leftAntenna: 0, rightAntenna: 0)

    /// The legs follow the distance walked; the antennae twitch on their own slow rhythm.
    static func pose(stepped: CGFloat, time: TimeInterval, length: CGFloat = WalkPlanner.length) -> Pose {
        let phase = 2 * .pi * stepped / (length * strideShare)
        let forward = swing * sin(phase)
        let t = CGFloat(time.truncatingRemainder(dividingBy: 3600))
        return Pose(left: [forward, -forward, forward],
                    right: [-forward, forward, -forward],
                    sway: sway * sin(phase),
                    leftAntenna: 0.09 * sin(t * 2.1) + 0.05 * sin(t * 5.3 + 1),
                    rightAntenna: 0.09 * sin(t * 1.7 + 2) + 0.05 * sin(t * 4.6))
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat { hypot(x - other.x, y - other.y) }

    func moved(toward other: CGPoint, by fraction: CGFloat) -> CGPoint {
        CGPoint(x: x + (other.x - x) * fraction, y: y + (other.y - y) * fraction)
    }

    func offset(by vector: CGVector, times scale: CGFloat) -> CGPoint {
        CGPoint(x: x + vector.dx * scale, y: y + vector.dy * scale)
    }
}

extension CGVector {
    var length: CGFloat { hypot(dx, dy) }
    var unit: CGVector { length > 0 ? CGVector(dx: dx / length, dy: dy / length) : self }
    func dot(_ other: CGVector) -> CGFloat { dx * other.dx + dy * other.dy }
    func scaled(by scale: CGFloat) -> CGVector { CGVector(dx: dx * scale, dy: dy * scale) }
}
