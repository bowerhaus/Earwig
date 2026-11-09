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
    /// The engine's line under the status, off unless Settings shows it (#36).
    /// Set on the preview, where the text is shown over the camera (Andy, check 4b).
    @AppStorage(TakeSettings.textOverCameraKey) private var textOverCamera = TakeSettings.defaultTextOverCamera
    /// Counts Back, Forward and Restart, so the text follows again at once after a drag.
    @State private var moves = 0
    @State private var playing: Playback?

    var body: some View {
        let model = PromptViewModel(host: host)
        // A ZStack, not a Group: a Group's modifiers go to each of its children, so a camera
        // behind a Group was built again at Start, a second preview layer that held the main
        // thread for seven seconds (check 4b). Here it is one view for the whole take.
        ZStack {
            camera(model)
            if model.isFraming {
                FramingView(model: model, camera: host.camera, onStart: { host.go() }, onCancel: onDone)
            } else if !model.isOver {
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
        .sheet(item: $playing) { playback in
            PlaybackView(playback: playback, title: "\(model.stepText) · \(model.takeText)")
        }
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
            if let note = model.recordingText {
                Text(note)
                    .font(.headline)
                    .foregroundStyle(EarwigTheme.caution)
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

    /// The camera's preview, one for the whole take: behind framing, then behind the text if
    /// Settings says so, at its own brightness, with the text faded over it. Never a second preview layer on the running session, which
    /// held the main thread for seven seconds (check 4b, 2026-11-09).
    @ViewBuilder
    private func camera(_ model: PromptViewModel) -> some View {
        if model.showsCamera, let camera = host.camera, camera.device != nil {
            CameraPreview(camera: camera)
                .ignoresSafeArea()
            .accessibilityHidden(true)
        }
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
                        if model.showsRecordingDot, let since = model.recording.since {
                            recordingDot(since: since, soundOnly: model.recordingSoundOnly)
                        }
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
        }
    }

    /// The dot and the time recorded (plan 010, decision 5); a waveform once only sound is.
    private func recordingDot(since: TimeInterval, soundOnly: Bool) -> some View {
        let start = Date().addingTimeInterval(since - HostClock.now)
        return HStack(spacing: 4) {
            Image(systemName: soundOnly ? "waveform" : "circle.fill")
                .font(.caption2.bold())
                .foregroundStyle(EarwigTheme.recording)
            Text(timerInterval: start...Date.distantFuture, countsDown: false)
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(EarwigTheme.text)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(soundOnly ? "Recording sound" : "Recording")
    }

    private func screenText(_ model: PromptViewModel) -> some View {
        ScreenTextView(tokens: model.screenTokens, place: model.place,
                       textSize: $textSize,
                       resume: moves)
            .opacity(model.showsCameraBehindText ? textOverCamera : 1)
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
            recordingButtons(model)
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
            // Held, as Next Take is, while the file is saved: the take still has the mic, the
            // camera and the session, and a take started now would overlap it (review C1).
            .disabled(model.isSavingRecording)
            .opacity(model.isSavingRecording ? 0.5 : 1)
        }
    }
}

extension PromptView {
    /// Play Video, Play Sound and Share once the take's file is finished, or that it is being
    /// saved (plan 010, decision 7).
    @ViewBuilder
    fileprivate func recordingButtons(_ model: PromptViewModel) -> some View {
        if model.isSavingRecording {
            HStack(spacing: 8) {
                ProgressView().tint(EarwigTheme.accent)
                Text("Saving the recording…")
                    .font(.headline)
                    .foregroundStyle(EarwigTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        } else if let result = model.recording.result {
            HStack(spacing: 10) {
                if model.canPlayVideo {
                    playButton("Play Video", systemImage: "play.rectangle.fill") { playing = Playback(url: result.url, soundOnly: false) }
                    playButton("Play Sound", systemImage: "waveform") { playing = Playback(url: result.url, soundOnly: true) }
                } else {
                    playButton("Play Back", systemImage: "play.fill") { playing = Playback(url: result.url, soundOnly: true) }
                }
                ShareLink(item: result.url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3.bold())
                        .foregroundStyle(EarwigTheme.text)
                        .frame(width: 52, height: 52)
                        .background(EarwigTheme.surface, in: Circle())
                }
                .accessibilityLabel("Share")
            }
        }
    }

    private func playButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(EarwigTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(EarwigTheme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A control in the take's row: an icon, its name for VoiceOver only, lit while on (Hold).
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
