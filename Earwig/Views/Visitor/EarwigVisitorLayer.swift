import SwiftUI

extension View {
    /// Now and then the earwig walks across this screen (plan 014), under its cards or over
    /// them. Put it on the screen's list before the list's background, so the layer under the
    /// cards is between the background and the cards, and give the cards' backgrounds
    /// `earwigCard()` so it knows where they are. `keepAway` stops a visit beginning, and sends
    /// one under way off as `leaving` says.
    func earwigVisits(keepAway: Bool = false, leaving: VisitLeaving = .vanishes) -> some View {
        modifier(EarwigVisitsModifier(keepAway: keepAway, leaving: leaving))
    }

    /// Marks a card's background (a list row's) for the earwig's walks, so it knows whether
    /// it would be under the card for long (plan 014, decision 6).
    func earwigCard() -> some View {
        modifier(EarwigCardModifier())
    }
}

/// Where the cards of one screen are, in global coordinates, kept by the screen's visits and
/// reported by the cards. Read on every frame of a walk and never observed, so a card moving
/// while the list scrolls redraws nothing.
@MainActor
final class VisitCards {
    var frames: [UUID: CGRect] = [:]
}

private struct VisitCardsKey: EnvironmentKey {
    static let defaultValue: VisitCards? = nil
}

extension EnvironmentValues {
    fileprivate var visitCards: VisitCards? {
        get { self[VisitCardsKey.self] }
        set { self[VisitCardsKey.self] = newValue }
    }
}

private struct EarwigCardModifier: ViewModifier {
    @Environment(\.visitCards) private var cards
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { cards?.frames[id] = $0 }
            .onDisappear { cards?.frames[id] = nil }
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
    /// Where the walks' layers are on screen, to bring the cards' frames into them.
    @State private var origin = CGPoint.zero
    @State private var cards = VisitCards()
    /// `keepAway` or Reduce Motion as they are now. A visit waiting to begin reads this, not the
    /// copies it was started with, which would still say what they said when the screen appeared.
    @State private var held = false

    private static let space = "earwigVisit"

    func body(content: Content) -> some View {
        content
            .environment(\.visitCards, cards)
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
    private func layer(_ layer: VisitLayer) -> some View {
        GeometryReader { _ in
            if let walk {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    if let place = walk.place(at: time), walk.layer(at: place.walked, cards: cardFrames) == layer {
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
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            area.size = frame.size
            origin = frame.origin
        }
        .ignoresSafeArea()
        // Under the cards the list takes every tap, so only the one over them can be caught.
        .allowsHitTesting(layer == .inFront)
        .accessibilityHidden(true)
    }

    /// The cards' frames in the layers' coordinates.
    private var cardFrames: [CGRect] {
        cards.frames.values.map { $0.offsetBy(dx: -origin.x, dy: -origin.y) }
    }

    /// Rolls for a visit a moment after the screen appears, and again every so often while it
    /// stays (decision 8, amended at device check 2), beginning one whenever the roll comes up.
    private func visit() async {
        walk = nil
        guard let visits else { return }
        var random = SystemRandomNumberGenerator()
        var wait = VisitSchedule.delay(for: VisitFrequency.current(), using: &random)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(wait))
            wait = VisitSchedule.again
            let frequency = VisitFrequency.current()
            let now = Date.now.timeIntervalSinceReferenceDate
            guard !Task.isCancelled, walk == nil, !held, area.size.width > 0,
                  VisitSchedule.visits(frequency, roll: Double.random(in: 0..<1, using: &random), at: now,
                                       lastVisit: visits.lastVisit) else { continue }
            let next = WalkPlanner(area: area).visit(start: now, using: &random)
            guard visits.begin(next) else { continue }
            Log.event("earwig visits, \(String(format: "%.1f", next.duration)) s, \(cards.frames.count) cards")
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
        guard let current = walk, !current.isRun, let place = current.place(at: now) else { return }
        let run = WalkPlanner(area: area).run(from: place, awayFrom: tap, start: now)
        visits?.ran(run)
        walk = run
    }

    private func leave(_ how: VisitLeaving) {
        guard let current = walk else { return }
        let now = Date.now.timeIntervalSinceReferenceDate
        let next = WalkPlanner(area: area).leaving(current, how, at: now)
        if let next {
            if next.id != current.id { visits?.ran(next) }
        } else {
            visits?.ended(at: now)
        }
        walk = next
    }
}
