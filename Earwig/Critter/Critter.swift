import Observation
import SwiftUI

// The critter: an earwig that now and then wanders across the screen, under the cards or over
// them, and runs from a tap (plan 014). A bit of fun, kept to this folder: this file draws it and
// puts it on a screen, CritterWalk.swift plans its walks, and CritterGeometry.swift is its shape,
// written by the icon script. A screen takes part with `critterVisits()` on its list and
// `critterCard()` on its cards' backgrounds; Settings has `Critter.SettingRow`.

/// The critter's types, kept out of the rest of the app.
enum Critter {}

extension View {
    /// Now and then the earwig walks across this screen (plan 014), under its cards or over
    /// them. Put it on the screen's list before the list's background, so the layer under the
    /// cards is between the background and the cards, and give the cards' backgrounds
    /// `critterCard()` so it knows where they are. `keepAway` stops a visit beginning, and sends
    /// one under way off as `leaving` says.
    func critterVisits(keepAway: Bool = false, leaving: Critter.Leaving = .vanishes) -> some View {
        modifier(Critter.VisitsModifier(keepAway: keepAway, leaving: leaving))
    }

    /// Marks a card's background (a list row's) for the earwig's walks, so it knows whether
    /// it would be under the card for long (plan 014, decision 6).
    func critterCard() -> some View {
        modifier(Critter.CardModifier())
    }
}

private struct CritterCardsKey: EnvironmentKey {
    static let defaultValue: Critter.Cards? = nil
}

extension EnvironmentValues {
    fileprivate var critterCards: Critter.Cards? {
        get { self[CritterCardsKey.self] }
        set { self[CritterCardsKey.self] = newValue }
    }
}

extension Critter {
    /// A stretch of one of the mark's outlines, in its 1024 box.
    enum Segment: Sendable {
        case move(CGPoint)
        case line(CGPoint)
        case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
        case close
    }

    /// A rounded rectangle of the mark's body.
    struct Plate: Sendable {
        let rect: CGRect
        let radius: CGFloat
    }

    /// One of the mark's strokes: a limb, which pivots on its first point, or a cut.
    struct Limb: Sendable {
        let segments: [Segment]
        let width: CGFloat

        var pivot: CGPoint {
            if case .move(let point) = segments.first { return point }
            return .zero
        }

        var path: Path {
            Path { path in
                for segment in segments {
                    switch segment {
                    case .move(let point): path.move(to: point)
                    case .line(let point): path.addLine(to: point)
                    case .curve(let to, let control1, let control2): path.addCurve(to: to, control1: control1, control2: control2)
                    case .close: path.closeSubpath()
                    }
                }
            }
        }
    }

    /// The mark, drawn in a pose (plan 014, decisions 1 and 2), upright and centred in a square
    /// `length` across: the body with its cuts as true gaps, as the mark image has them, and each
    /// leg and antenna turned about the point where it joins the body. White, as on the icon.
    struct Figure: View {
        var pose: Pose
        var length: CGFloat = Planner.length

        var body: some View {
            Canvas { context, size in
                let scale = size.width / Geometry.length
                context.translateBy(x: size.width / 2, y: size.height / 2)
                context.scaleBy(x: scale, y: scale)
                context.translateBy(x: -Geometry.centre.x, y: -Geometry.centre.y)
                let shading = GraphicsContext.Shading.color(EarwigTheme.text)

                context.drawLayer { layer in
                    layer.fill(Path(ellipseIn: Geometry.head), with: shading)
                    for plate in [Geometry.pronotum, Geometry.wingCases] {
                        layer.fill(Path(roundedRect: plate.rect, cornerRadius: plate.radius), with: shading)
                    }
                    layer.fill(Limb(segments: Geometry.abdomen, width: 0).path, with: shading)
                    layer.blendMode = .destinationOut
                    for cut in Geometry.cuts {
                        layer.stroke(cut.path, with: shading, style: Self.style(cut.width))
                    }
                }

                // The left side as drawn; the right side is the same drawing mirrored about the
                // middle, so a forward swing there turns the other way on screen, as it should.
                for isRight in [false, true] {
                    var half = context
                    if isRight {
                        half.translateBy(x: Geometry.box, y: 0)
                        half.scaleBy(x: -1, y: 1)
                    }
                    let legs = isRight ? pose.right : pose.left
                    let antenna = isRight ? pose.rightAntenna : pose.leftAntenna
                    Self.draw(Geometry.antenna, turned: antenna, in: half, with: shading)
                    for (leg, angle) in zip(Geometry.legs, legs) {
                        Self.draw(leg, turned: angle, in: half, with: shading)
                    }
                    Self.draw(Geometry.forceps, turned: 0, in: half, with: shading)
                }
            }
            .frame(width: length, height: length)
        }

        private static func style(_ width: CGFloat) -> StrokeStyle {
            StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        }

        private static func draw(_ limb: Limb, turned angle: CGFloat, in context: GraphicsContext, with shading: GraphicsContext.Shading) {
            var turned = context
            let pivot = limb.pivot
            turned.translateBy(x: pivot.x, y: pivot.y)
            turned.rotate(by: .radians(angle))
            turned.translateBy(x: -pivot.x, y: -pivot.y)
            turned.stroke(limb.path, with: shading, style: style(limb.width))
        }
    }

    /// Where the cards of one screen are, in global coordinates, reported by the cards, and how
    /// far its list has scrolled. Kept by the screen's visits, read on every frame of a walk and
    /// never observed, so a card moving while the list scrolls redraws nothing.
    @MainActor
    final class Cards {
        var frames: [UUID: CGRect] = [:]
        /// The list's scroll, and what it was when the walk under way set off from where it is.
        var scroll: CGFloat = 0
        var anchor: CGFloat = 0

        /// How far the list has scrolled since then: the walk moves with it, as if on the page
        /// (Andy, device check 3).
        var drift: CGFloat { scroll - anchor }

        /// A walk sets off from here, on the screen as it is now.
        func setOff() { anchor = scroll }
    }

    fileprivate struct CardModifier: ViewModifier {
        @Environment(\.critterCards) private var cards
        @State private var id = UUID()

        func body(content: Content) -> some View {
            content
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { cards?.frames[id] = $0 }
                .onDisappear { cards?.frames[id] = nil }
        }
    }

    fileprivate struct VisitsModifier: ViewModifier {
        let keepAway: Bool
        let leaving: Leaving

        private let visits = Visits.shared
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var walk: Walk?
        @State private var area = Area.zero
        /// Where the walks' layers are on screen, to bring the cards' frames into them.
        @State private var origin = CGPoint.zero
        @State private var cards = Cards()
        /// `keepAway` or Reduce Motion as they are now. A visit waiting to begin reads this, not the
        /// copies it was started with, which would still say what they said when the screen appeared.
        @State private var held = false

        private static let space = "critter"

        func body(content: Content) -> some View {
            content
                .environment(\.critterCards, cards)
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in cards.scroll = y }
                .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { insets in
                    area.top = insets.top
                    area.bottom = insets.bottom
                }
                .background { layer(.behind) }
                .overlay { layer(.inFront) }
                .task { await visit() }
                .task(id: walk?.id) { await clear() }
                .onDisappear { leave(.vanishes) }
                .onChange(of: keepAway || reduceMotion, initial: true) { _, hold in held = hold }
                .onChange(of: keepAway) { _, away in
                    if away { leave(leaving) }
                }
                .onChange(of: reduceMotion) { _, reduced in
                    if reduced { leave(.vanishes) }
                }
        }

        /// One of the two layers. Both follow the walk and each draws it only while it is on that
        /// layer's side of the cards, so it can go under one card and over the next.
        private func layer(_ layer: Layer) -> some View {
            GeometryReader { _ in
                if let walk {
                    TimelineView(.animation) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        let drift = cards.drift
                        if let place = walk.place(at: time), walk.layer(at: place.walked, cards: cardFrames(drift)) == layer {
                            let pose = Gait.pose(stepped: place.stepped, time: time)
                            Figure(pose: pose)
                                .contentShape(Ellipse().scale(x: 0.6, y: 1))
                                .rotationEffect(.radians(place.heading + pose.sway))
                                .position(x: place.position.x, y: place.position.y - drift)
                                .onTapGesture(coordinateSpace: .named(Self.space)) { location in
                                    run(awayFrom: location)
                                }
                        }
                    }
                }
            }
            .coordinateSpace(.named(Self.space))
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                area.size = frame.size
                origin = frame.origin
            }
            .ignoresSafeArea()
            // Under the cards the list takes every tap, so only the one over them can be caught.
            .allowsHitTesting(layer == .inFront)
            .accessibilityHidden(true)
        }

        /// The cards' frames in the walk's coordinates: the layers', as they were when it set off.
        private func cardFrames(_ drift: CGFloat) -> [CGRect] {
            cards.frames.values.map { $0.offsetBy(dx: -origin.x, dy: drift - origin.y) }
        }

        /// Rolls for a visit a moment after the screen appears, and again every so often while it
        /// stays (decision 8, amended at device check 2), beginning one whenever the roll comes up.
        private func visit() async {
            walk = nil
            var random = SystemRandomNumberGenerator()
            var wait = Schedule.delay(for: Frequency.current(), using: &random)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(wait))
                wait = Schedule.again
                let frequency = Frequency.current()
                let now = Date.now.timeIntervalSinceReferenceDate
                guard !Task.isCancelled, walk == nil, !held, area.size.width > 0,
                      Schedule.visits(frequency, roll: Double.random(in: 0..<1, using: &random), at: now,
                                           lastVisit: visits.lastVisit) else { continue }
                let next = Planner(area: area).visit(start: now, using: &random)
                guard visits.begin(next) else { continue }
                cards.setOff()
                Log.event("earwig visits, \(String(format: "%.1f", next.duration)) s, \(cards.frames.count) cards, scrolled \(Int(cards.scroll))")
                walk = next
            }
        }

        /// Takes the walk away once it has gone off screen.
        private func clear() async {
            guard let walk else { return }
            let left = walk.end - Date.now.timeIntervalSinceReferenceDate
            try? await Task.sleep(for: .seconds(max(0, left)))
            guard !Task.isCancelled, self.walk?.id == walk.id else { return }
            self.walk = nil
        }

        private func run(awayFrom tap: CGPoint) {
            let now = Date.now.timeIntervalSinceReferenceDate
            guard let current = walk, !current.isRun, var place = current.place(at: now) else { return }
            // From where it is on the screen now, the list's scroll and all.
            place.position.y -= cards.drift
            let run = Planner(area: area).run(from: place, awayFrom: tap, pace: current.speed, start: now)
            cards.setOff()
            visits.ran(run)
            walk = run
        }

        private func leave(_ how: Leaving) {
            guard let current = walk else { return }
            let now = Date.now.timeIntervalSinceReferenceDate
            let next = Planner(area: area).leaving(current, how, at: now, drift: cards.drift)
            if let next {
                if next.id != current.id {
                    cards.setOff()
                    visits.ran(next)
                }
            } else {
                visits.ended(at: now)
            }
            walk = next
        }
    }

    /// The app's visits, shared by the screens (plan 014, decisions 8 and 9): when the last began,
    /// so the rest applies across them, and whether one is under way, so there is only ever one.
    /// There is none under the splash: the first comes at least two seconds after a screen appears.
    @MainActor
    @Observable
    final class Visits {
        /// The one the screens share.
        static let shared = Visits()

        private(set) var lastVisit: TimeInterval?
        /// When the walk under way ends.
        private(set) var busyUntil: TimeInterval = 0

        /// Claims a walk for a screen, or refuses one while another is under way.
        func begin(_ walk: Walk) -> Bool {
            guard walk.start >= busyUntil else { return false }
            lastVisit = walk.start
            busyUntil = walk.end
            return true
        }

        /// A run replaces the walk it came from; its end is the visit's end.
        func ran(_ run: Walk) {
            busyUntil = run.end
        }

        /// The walk has gone before its end, taken away or left with its screen.
        func ended(at time: TimeInterval) {
            busyUntil = min(busyUntil, time)
        }
    }

    /// Critter's row in Settings' Screen group (plan 014, decision 10): how often it comes, Off to
    /// All the Time.
    struct SettingRow: View {
        @AppStorage(Frequency.key) private var frequency: Frequency = .standard

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Critter", value: frequency.title)
                Slider(value: steps, in: 0...Double(Frequency.allCases.count - 1), step: 1)
                    .accessibilityLabel("Critter")
                    .accessibilityValue(frequency.title)
            }
        }

        private var steps: Binding<Double> {
            Binding(get: { Double(frequency.rawValue) },
                    set: { frequency = Frequency(rawValue: Int($0.rounded())) ?? .standard })
        }
    }
}

#Preview("Walking on the spot") {
    TimelineView(.animation) { timeline in
        let time = timeline.date.timeIntervalSinceReferenceDate
        let pose = Critter.Gait.pose(stepped: CGFloat(time) * Critter.Planner.walkingSpeed, time: time, length: 200)
        Critter.Figure(pose: pose, length: 200)
            .rotationEffect(.radians(pose.sway))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EarwigTheme.background)
}
