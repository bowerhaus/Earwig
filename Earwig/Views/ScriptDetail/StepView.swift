import SwiftUI

/// A step on the Script screen: its title, directions in the cue colour, its lines with any
/// inline direction in the cue colour, and its takes.
struct StepView: View {
    let step: Step
    let isStart: Bool
    let takes: [Take]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                // The slate: the step number large, as it is said at the start of a take.
                Text(String(step.number))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(EarwigTheme.accent)
                    .monospacedDigit()
                Text(step.heading)
                    .font(.title3.bold())
                    .foregroundStyle(EarwigTheme.text)
                Spacer(minLength: 8)
                if isStart {
                    Label("Start", systemImage: "play.fill")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(EarwigTheme.onAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(EarwigTheme.accent, in: Capsule())
                }
            }

            ForEach(Array(step.directions.enumerated()), id: \.offset) { _, direction in
                Text(directionText(direction))
                    .font(.subheadline)
                    .foregroundStyle(EarwigTheme.cue)
            }

            ForEach(Array(step.lines.enumerated()), id: \.offset) { _, line in
                Text(lineText(line))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(takesText)
                .font(.footnote)
                .foregroundStyle(EarwigTheme.secondaryText)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func directionText(_ direction: Direction) -> AttributedString {
        guard let label = direction.label else { return AttributedString(direction.text) }
        var labelText = AttributedString(label.uppercased() + "  ")
        labelText.font = .caption.weight(.bold)
        labelText.tracking = 1.2
        return labelText + AttributedString(direction.text)
    }

    private func lineText(_ line: String) -> AttributedString {
        var result = AttributedString()
        for segment in LineText.segments(of: line) {
            if !result.characters.isEmpty { result += AttributedString(" ") }
            switch segment {
            case .spoken(let text):
                var part = AttributedString(text)
                part.foregroundColor = EarwigTheme.text
                result += part
            case .direction(let text):
                var part = AttributedString("[\(text)]")
                part.foregroundColor = EarwigTheme.cue
                part.font = .body.italic()
                result += part
            }
        }
        return result
    }

    private var takesText: String {
        guard let latest = takes.first else { return "No takes yet" }
        let count = takes.count == 1 ? "1 take" : "\(takes.count) takes"
        return "\(count) · last \(latest.startedAt.formatted(.relative(presentation: .named)))"
    }
}
