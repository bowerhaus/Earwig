import SwiftUI

/// How a walk under way goes when its screen asks it to keep away (plan 014, decision 9).
enum VisitLeaving {
    /// Taken away at once: a take, or Listen.
    case vanishes
    /// Runs off: Preview in Settings.
    case runsOff
}

extension View {
    /// Now and then the earwig walks across this screen (plan 014), behind its cards or over
    /// them. Put it on the screen's list before the list's background, so a walk behind is
    /// between the background and the cards. `keepAway` stops a visit beginning, and sends one
    /// under way off as `leaving` says.
    func earwigVisits(keepAway: Bool = false, leaving: VisitLeaving = .vanishes) -> some View {
        modifier(EarwigVisitsModifier(keepAway: keepAway, leaving: leaving))
    }
}

private struct EarwigVisitsModifier: ViewModifier {
    let keepAway: Bool
    let leaving: VisitLeaving

    /// Optional, so a preview or a test without it simply has no visits.
    @Environment(EarwigVisits.self) private var visits: EarwigVisits?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var walk: Walk?
    @State private var area = VisitArea.zero

    private static let space = "earwigVisit"

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { insets in
                area.top = insets.top
                area.bottom = insets.bottom
            }
            .background { layer(.behind) }
            .overlay { layer(.inFront) }
            .task { await visit() }
            .task(id: walk?.id) { await clear() }
            .onDisappear { leave(.vanishes) }
            .onChange(of: keepAway) { _, away in
                if away { leave(leaving) }
            }
            .onChange(of: reduceMotion) { _, reduced in
                if reduced { leave(.vanishes) }
            }
    }

    private func layer(_ layer: VisitLayer) -> some View {
        GeometryReader { _ in
            if let walk, walk.layer == layer {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    if let place = walk.place(at: time) {
                        let pose = Gait.pose(stepped: place.stepped, time: time)
                        EarwigFigure(pose: pose)
                            .contentShape(Ellipse().scale(x: 0.6, y: 1))
                            .rotationEffect(.radians(place.heading + pose.sway))
                            .position(place.position)
                            .onTapGesture(coordinateSpace: .named(Self.space)) { location in
                                run(awayFrom: location)
                            }
                    }
                }
            }
        }
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGSize.self) { $0.size } action: { area.size = $0 }
        .ignoresSafeArea()
        // Behind the cards the list takes every tap, so only the one in front can be caught.
        .allowsHitTesting(layer == .inFront)
        .accessibilityHidden(true)
    }

    /// Rolls for a visit when the screen appears, and begins one after a moment if it comes up.
    private func visit() async {
        walk = nil
        guard let visits, !reduceMotion else { return }
        let frequency = VisitFrequency.current()
        guard frequency != .never else { return }
        var random = SystemRandomNumberGenerator()
        let roll = Double.random(in: 0..<1, using: &random)
        try? await Task.sleep(for: .seconds(VisitSchedule.delay(for: frequency, using: &random)))
        let now = Date.now.timeIntervalSinceReferenceDate
        guard !Task.isCancelled, !keepAway, !reduceMotion, area.size.width > 0,
              VisitSchedule.visits(frequency, roll: roll, at: now, lastVisit: visits.lastVisit) else { return }
        let layer: VisitLayer = Bool.random(using: &random) ? .behind : .inFront
        let next = WalkPlanner(area: area).visit(layer: layer, start: now, using: &random)
        guard visits.begin(next) else { return }
        Log.event("earwig visits, \(layer == .behind ? "behind" : "in front"), \(String(format: "%.1f", next.duration)) s")
        walk = next
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
        guard let current = walk, !current.isRun, let place = current.place(at: now) else { return }
        let run = WalkPlanner(area: area).run(from: place, awayFrom: tap, layer: current.layer, start: now)
        visits?.ran(run)
        walk = run
    }

    private func leave(_ how: VisitLeaving) {
        guard let current = walk else { return }
        let now = Date.now.timeIntervalSinceReferenceDate
        if how == .runsOff, !current.isRun, let place = current.place(at: now) {
            // Straight on, as if it had heard something.
            let behind = place.position.offset(by: Heading.direction(place.heading), times: -10)
            let run = WalkPlanner(area: area).run(from: place, awayFrom: behind, layer: current.layer, start: now)
            visits?.ran(run)
            walk = run
        } else if how == .vanishes {
            visits?.ended(at: now)
            walk = nil
        }
    }
}
