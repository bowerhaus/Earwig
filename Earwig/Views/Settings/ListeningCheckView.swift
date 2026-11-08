import SwiftUI

/// The Listening check (PRD §8.5): the words heard live with their delay, interim words dimmed
/// until final, the input level, the route and the speech assets, and Say Test.
struct ListeningCheckView: View {
    @Environment(ScriptRenderer.self) private var renderer
    @State private var check = ListeningCheck()

    var body: some View {
        List {
            Section("Route") {
                routeRow("earbuds", title: "Output", value: outputs, good: !check.session.route.isHandsFree && !check.session.route.isSpeaker,
                         caution: check.session.route.isSpeaker)
                routeRow("mic.fill", title: "Input", value: inputs, good: check.session.route.inputIsBuiltInMic && !check.session.route.isHandsFree)
            }
            .listRowBackground(EarwigTheme.surface)

            Section("Listening") {
                LabeledContent("State", value: stateText)
                LabeledContent("Speech assets", value: "\(check.listener.localeIdentifier) · \(check.listener.assetStatus)")
                TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                    ProgressView(value: Double(check.listener.inputLevel))
                        .tint(EarwigTheme.accent)
                }
                if let problem = check.problem {
                    Text(problem)
                        .foregroundStyle(EarwigTheme.warning)
                }
            }
            .listRowBackground(EarwigTheme.surface)

            Section {
                Text(heardText)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                Button {
                    Task { await check.sayTest(with: renderer) }
                } label: {
                    AccentPill(title: check.isSayingTest ? "Saying…" : "Say Test", systemImage: "speaker.wave.2.fill", expands: true)
                }
                .buttonStyle(.plain)
                .disabled(check.isSayingTest)
                Button("Clear") { check.listener.clearWords() }
                    .foregroundStyle(EarwigTheme.accent)
            } header: {
                Text("Heard")
            } footer: {
                Text("Speak and the words appear with how late each was heard. Say Test plays a line in the voice through the earpiece: with the earpiece in, none of it should appear here.")
                    .foregroundStyle(EarwigTheme.secondaryText)
            }
            .listRowBackground(EarwigTheme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(EarwigTheme.background)
        .navigationTitle("Listening Check")
        .navigationBarTitleDisplayMode(.inline)
        .task { await check.start() }
        .onDisappear { Task { await check.stop() } }
    }

    private func routeRow(_ systemImage: String, title: String, value: String, good: Bool, caution: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(good ? EarwigTheme.good : caution ? EarwigTheme.caution : EarwigTheme.warning)
                .frame(width: 24)
            LabeledContent(title, value: value)
        }
    }

    private var outputs: String {
        let ports = check.session.route.outputs
        return ports.isEmpty ? "None" : ports.map { "\($0.name) (\(AudioRoute.label($0.type)))" }.joined(separator: ", ")
    }

    private var inputs: String {
        let ports = check.session.route.inputs
        return ports.isEmpty ? "None" : ports.map { "\($0.name) (\(AudioRoute.label($0.type)))" }.joined(separator: ", ")
    }

    private var stateText: String {
        switch check.listener.state {
        case .idle: "Not listening"
        case .preparing: "Preparing"
        case .downloading(let fraction): String(format: "Downloading %.0f%%", fraction * 100)
        case .listening: "Listening"
        case .failed(let message): "Failed: \(message)"
        }
    }

    /// The last words heard, each followed by its delay; interim words dimmed.
    private var heardText: AttributedString {
        var result = AttributedString()
        for word in check.listener.words.suffix(60) {
            var text = AttributedString(word.text + " ")
            text.foregroundColor = word.isFinal ? EarwigTheme.text : EarwigTheme.secondaryText
            var delay = AttributedString(String(format: "%.1f ", word.delay))
            delay.font = .caption2.monospacedDigit()
            delay.foregroundColor = EarwigTheme.cue
            result += text + delay
        }
        if result.characters.isEmpty {
            var placeholder = AttributedString("Nothing heard yet.")
            placeholder.foregroundColor = EarwigTheme.secondaryText
            return placeholder
        }
        return result
    }
}
