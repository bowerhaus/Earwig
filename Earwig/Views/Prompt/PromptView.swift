import SwiftUI
import UIKit

/// The Prompt screen in Ear mode (PRD §8.3; plan 005, decision 7): the step, the take and the
/// route at the top; the status, what to do and the voice's phrase in the middle, where a tap
/// starts the take from the slate; the manual controls at the bottom. The screen stays awake
/// while it is up.
struct PromptView: View {
    let host: TakeHost
    let onNextTake: () -> Void
    let onDone: () -> Void

    var body: some View {
        let model = PromptViewModel(host: host)
        VStack(spacing: 20) {
            top(model)
            middle(model)
            bottom(model)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(EarwigTheme.background.ignoresSafeArea())
        .task(id: ObjectIdentifier(host)) { await host.start() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: - Top

    private func top(_ model: PromptViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.stepText)
                        .font(.headline)
                        .foregroundStyle(EarwigTheme.text)
                        .lineLimit(1)
                    Text(model.takeText)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(EarwigTheme.accent)
                        .monospacedDigit()
                }
                Spacer(minLength: 12)
                routeIcon("earbuds", state: model.earpiece, label: "Earpiece")
                routeIcon("mic.fill", state: model.mic, label: "Microphone")
            }
            if let note = model.routeNote {
                Text(note)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(model.earpiece == .wrong || model.mic == .wrong ? EarwigTheme.warning : EarwigTheme.caution)
            }
        }
    }

    private func routeIcon(_ systemImage: String, state: PromptViewModel.RouteState, label: String) -> some View {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(colour(state))
            .frame(width: 44, height: 44)
            .background(EarwigTheme.surface, in: Circle())
            .accessibilityLabel("\(label) \(Self.describe(state))")
    }

    private static func describe(_ state: PromptViewModel.RouteState) -> String {
        switch state {
        case .unknown: "not in use"
        case .good: "good"
        case .caution: "on the speaker"
        case .wrong: "wrong"
        }
    }

    private func colour(_ state: PromptViewModel.RouteState) -> Color {
        switch state {
        case .unknown: EarwigTheme.secondaryText
        case .good: EarwigTheme.good
        case .caution: EarwigTheme.caution
        case .wrong: EarwigTheme.warning
        }
    }

    // MARK: - Middle

    private func middle(_ model: PromptViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.status)
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(statusColour(model))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let instruction = model.instruction {
                Text(instruction)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(failed(model) ? EarwigTheme.warning : EarwigTheme.secondaryText)
            }
            if case .gettingReady = model.phase {
                ProgressView(value: model.downloadProgress)
                    .tint(EarwigTheme.accent)
            }
            if !model.phrase.isEmpty {
                Text(phraseText(model))
                    .font(.system(size: 30, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            Spacer(minLength: 0)
            if let diagnostics = model.diagnostics {
                Text(diagnostics)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(EarwigTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture {
            if model.tapStarts { host.control(.tap) }
        }
    }

    private func failed(_ model: PromptViewModel) -> Bool {
        if case .failed = model.phase { return true }
        return false
    }

    private func statusColour(_ model: PromptViewModel) -> Color {
        if failed(model) { return EarwigTheme.warning }
        guard model.phase == .running else { return EarwigTheme.text }
        switch model.snapshot.status {
        case .slate: return EarwigTheme.cue
        case .lost, .held: return EarwigTheme.caution
        default: return EarwigTheme.text
        }
    }

    /// The voice's phrase, or while it waits the sentence it stopped in: the word it is saying on
    /// the accent, what it has given white, what it has yet to give dimmer, cues in the cue colour.
    private func phraseText(_ model: PromptViewModel) -> AttributedString {
        var result = AttributedString()
        for (index, token) in model.phrase.enumerated() {
            if index > 0 { result += AttributedString(" ") }
            var part = AttributedString(token.text)
            if token.isVoiceWord {
                part.foregroundColor = EarwigTheme.onAccent
                part.backgroundColor = EarwigTheme.accent
            } else if token.isCue {
                part.foregroundColor = EarwigTheme.cue
            } else {
                part.foregroundColor = token.isAhead ? EarwigTheme.secondaryText : EarwigTheme.text
            }
            result += part
        }
        return result
    }

    // MARK: - Bottom

    @ViewBuilder
    private func bottom(_ model: PromptViewModel) -> some View {
        if model.isOver {
            VStack(spacing: 12) {
                if model.canTakeAgain {
                    Button(action: onNextTake) {
                        AccentPill(title: "Next Take", systemImage: "arrow.forward.circle.fill", expands: true)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onDone) {
                    Text("Done")
                        .font(.title3.bold())
                        .foregroundStyle(EarwigTheme.text)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(EarwigTheme.surface, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        } else if model.canCancel {
            Button(action: onDone) {
                Text("Cancel")
                    .font(.title3.bold())
                    .foregroundStyle(EarwigTheme.text)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(EarwigTheme.surface, in: Capsule())
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ControlButton(title: "Back", systemImage: "backward.end.fill", enabled: model.backEnabled) { host.control(.back) }
                    ControlButton(title: model.isHeld ? "Release" : "Hold", systemImage: model.isHeld ? "play.fill" : "pause.fill",
                                  lit: model.isHeld, enabled: model.holdEnabled) { host.control(.hold) }
                    ControlButton(title: "Forward", systemImage: "forward.end.fill", enabled: model.forwardEnabled) { host.control(.forward) }
                }
                HStack(spacing: 12) {
                    ControlButton(title: "Restart", systemImage: "arrow.counterclockwise", enabled: model.restartEnabled) { host.control(.restart) }
                    ControlButton(title: "Stop", systemImage: "stop.fill", enabled: model.stopEnabled) { host.control(.stop) }
                }
            }
        }
    }
}

/// A large control for the Prompt screen, lit on the accent while on (Hold).
private struct ControlButton: View {
    let title: String
    let systemImage: String
    var lit = false
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title2.bold())
                Text(title)
                    .font(.footnote.bold())
            }
            .foregroundStyle(lit ? EarwigTheme.onAccent : EarwigTheme.text)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(lit ? EarwigTheme.accent : EarwigTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
