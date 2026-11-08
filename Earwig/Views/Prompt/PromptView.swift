import SwiftUI
import UIKit

/// The Prompt screen (PRD §8.3; plan 008, decision 9): while the take gets ready and runs, one
/// row of the step, the status and the route, the scrolling text, and the controls as one row of
/// icons, down the side in landscape, with the voice or without it. Finished and Can't start
/// (plan 005, decision 7): the step, the take and the route at the top, the outcome large, and
/// Next Take and Done. The screen stays awake while it is up.
struct PromptView: View {
    let host: TakeHost
    let onNextTake: () -> Void
    let onDone: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage(TakeSettings.textSizeKey) private var textSize = TakeSettings.defaultTextSize
    /// Counts Back, Forward and Restart, so the text follows again at once after a drag.
    @State private var moves = 0

    var body: some View {
        let model = PromptViewModel(host: host)
        Group {
            if !model.isOver {
                screen(model)
            } else {
                VStack(spacing: 20) {
                    top(model)
                    middle(model)
                    bottom(model)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
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

    private func routeIcon(_ systemImage: String, state: PromptViewModel.RouteState, label: String, size: CGFloat = 44) -> some View {
        Image(systemName: systemImage)
            .font(size < 44 ? .body : .title2)
            .foregroundStyle(colour(state))
            .frame(width: size, height: size)
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
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    // MARK: - The take

    private func screen(_ model: PromptViewModel) -> some View {
        Group {
            if verticalSizeClass == .compact {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        screenTop(model)
                        screenText(model)
                    }
                    screenControls(model, vertical: true)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    screenTop(model)
                    screenText(model)
                    screenControls(model, vertical: false)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func screenTop(_ model: PromptViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.stepText) · \(model.takeText)")
                        .font(.subheadline.bold())
                        .foregroundStyle(EarwigTheme.text)
                        .lineLimit(1)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(model.status)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(statusColour(model))
                        Text(model.setup.mode.label)
                            .font(.caption2.bold())
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(EarwigTheme.secondaryText)
                    }
                }
                Spacer(minLength: 8)
                routeIcon("earbuds", state: model.earpiece, label: "Earpiece", size: 34)
                routeIcon("mic.fill", state: model.mic, label: "Microphone", size: 34)
            }
            if let note = model.routeNote {
                Text(note)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.earpiece == .wrong || model.mic == .wrong ? EarwigTheme.warning : EarwigTheme.caution)
            }
            if let instruction = model.instruction {
                Text(instruction)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(EarwigTheme.secondaryText)
            }
            if case .gettingReady = model.phase {
                ProgressView(value: model.downloadProgress)
                    .tint(EarwigTheme.accent)
            }
            if let diagnostics = model.diagnostics {
                Text(diagnostics)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(EarwigTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private func screenText(_ model: PromptViewModel) -> some View {
        ScreenTextView(tokens: model.screenTokens, place: model.place, confident: model.confident, textSize: $textSize,
                       blocksMark: !model.setup.mode.voiced, resume: moves)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture {
                if model.tapStarts { host.control(.tap) }
            }
    }

    @ViewBuilder
    private func screenControls(_ model: PromptViewModel, vertical: Bool) -> some View {
        if model.canCancel {
            Button(action: onDone) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundStyle(EarwigTheme.text)
                    .frame(maxWidth: vertical ? 88 : .infinity, minHeight: 48)
                    .background(EarwigTheme.surface, in: Capsule())
            }
            .buttonStyle(.plain)
        } else {
            let layout = vertical ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                IconControl(title: "Back", systemImage: "backward.end.fill", enabled: model.backEnabled) { move(.back) }
                IconControl(title: model.isHeld ? "Release" : "Hold", systemImage: model.isHeld ? "play.fill" : "pause.fill",
                            lit: model.isHeld, enabled: model.holdEnabled) { host.control(.hold) }
                IconControl(title: "Forward", systemImage: "forward.end.fill", enabled: model.forwardEnabled) { move(.forward) }
                IconControl(title: "Restart", systemImage: "arrow.counterclockwise", enabled: model.restartEnabled) { move(.restart) }
                IconControl(title: "Stop", systemImage: "stop.fill", enabled: model.stopEnabled) { host.control(.stop) }
            }
            .frame(width: vertical ? 64 : nil)
        }
    }

    private func move(_ event: FollowEvent) {
        moves += 1
        host.control(event)
    }

    // MARK: - Bottom

    /// Next Take and Done, once the take is over or could not start.
    private func bottom(_ model: PromptViewModel) -> some View {
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
    }
}

/// A control in Screen mode's row: an icon, its name for VoiceOver only, lit while on (Hold).
private struct IconControl: View {
    let title: String
    let systemImage: String
    var lit = false
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.bold())
                .foregroundStyle(lit ? EarwigTheme.onAccent : EarwigTheme.text)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(lit ? EarwigTheme.accent : EarwigTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(title)
    }
}
