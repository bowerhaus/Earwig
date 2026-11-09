import SwiftUI

/// A stretch of one of the mark's outlines, in its 1024 box.
enum EarwigSegment: Sendable {
    case move(CGPoint)
    case line(CGPoint)
    case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
    case close
}

/// A rounded rectangle of the mark's body.
struct EarwigPlate: Sendable {
    let rect: CGRect
    let radius: CGFloat
}

/// One of the mark's strokes: a limb, which pivots on its first point, or a cut.
struct EarwigLimb: Sendable {
    let segments: [EarwigSegment]
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
struct EarwigFigure: View {
    var pose: Gait.Pose
    var length: CGFloat = WalkPlanner.length

    var body: some View {
        Canvas { context, size in
            let scale = size.width / EarwigGeometry.length
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -EarwigGeometry.centre.x, y: -EarwigGeometry.centre.y)
            let shading = GraphicsContext.Shading.color(EarwigTheme.text)

            context.drawLayer { layer in
                layer.fill(Path(ellipseIn: EarwigGeometry.head), with: shading)
                for plate in [EarwigGeometry.pronotum, EarwigGeometry.wingCases] {
                    layer.fill(Path(roundedRect: plate.rect, cornerRadius: plate.radius), with: shading)
                }
                layer.fill(EarwigLimb(segments: EarwigGeometry.abdomen, width: 0).path, with: shading)
                layer.blendMode = .destinationOut
                for cut in EarwigGeometry.cuts {
                    layer.stroke(cut.path, with: shading, style: Self.style(cut.width))
                }
            }

            // The left side as drawn; the right side is the same drawing mirrored about the
            // middle, so a forward swing there turns the other way on screen, as it should.
            for side in [Side.left, .right] {
                var half = context
                if side == .right {
                    half.translateBy(x: EarwigGeometry.box, y: 0)
                    half.scaleBy(x: -1, y: 1)
                }
                let legs = side == .left ? pose.left : pose.right
                let antenna = side == .left ? pose.leftAntenna : pose.rightAntenna
                Self.draw(EarwigGeometry.antenna, turned: antenna, in: half, with: shading)
                for (leg, angle) in zip(EarwigGeometry.legs, legs) {
                    Self.draw(leg, turned: angle, in: half, with: shading)
                }
                Self.draw(EarwigGeometry.forceps, turned: 0, in: half, with: shading)
            }
        }
        .frame(width: length, height: length)
    }

    private enum Side { case left, right }

    private static func style(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    private static func draw(_ limb: EarwigLimb, turned angle: CGFloat, in context: GraphicsContext, with shading: GraphicsContext.Shading) {
        var turned = context
        let pivot = limb.pivot
        turned.translateBy(x: pivot.x, y: pivot.y)
        turned.rotate(by: .radians(angle))
        turned.translateBy(x: -pivot.x, y: -pivot.y)
        turned.stroke(limb.path, with: shading, style: style(limb.width))
    }
}

#Preview("Walking on the spot") {
    TimelineView(.animation) { timeline in
        let time = timeline.date.timeIntervalSinceReferenceDate
        let pose = Gait.pose(stepped: CGFloat(time) * WalkPlanner.walkingSpeed, time: time, length: 200)
        EarwigFigure(pose: pose, length: 200)
            .rotationEffect(.radians(pose.sway))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EarwigTheme.background)
}
