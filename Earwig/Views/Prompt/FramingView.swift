import AVFoundation
import SwiftUI

/// A video take's framing (plan 010, decision 4): over the front camera's preview, full screen
/// and mirrored, the step and take at the top and Start at the foot. The take gets ready behind
/// it; Start is enabled once it is ready, and begins it. With the camera behind the text, the
/// step's opening words show as the take will show them, with a slider for how bright they are
/// over the picture (Andy, check 4b).
struct FramingView: View {
    let model: PromptViewModel
    let camera: CameraCapture?
    let onStart: () -> Void
    let onCancel: () -> Void

    @AppStorage(TakeSettings.textSizeKey) private var textSize = TakeSettings.defaultTextSize
    @AppStorage(TakeSettings.textOverCameraKey) private var textOverCamera = TakeSettings.defaultTextOverCamera

    var body: some View {
        ZStack {
            // The preview itself is behind this, drawn by the Prompt screen, so the same one
            // carries on behind the text once the take starts.
            if !model.recording.cameraReady || camera?.device == nil {
                Image(systemName: "video.slash")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(EarwigTheme.secondaryText)
                    .accessibilityLabel("No camera preview")
            }
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(model.stepText) · \(model.takeText)")
                            .font(.subheadline.bold())
                            .foregroundStyle(EarwigTheme.text)
                            .lineLimit(1)
                        Text(model.recording.readyToGo ? "Frame the shot, then Start" : "Getting ready")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(EarwigTheme.secondaryText)
                    }
                    Spacer(minLength: 8)
                }
                .padding(12)
                .background(EarwigTheme.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: EarwigButton.corner))
                if model.setup.cameraBehindText {
                    ScreenTextView(tokens: model.screenTokens, place: model.place, textSize: $textSize, resume: 0)
                        .opacity(textOverCamera)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    textBrightness
                } else {
                    Spacer()
                }
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel").secondAction(maxWidth: 120)
                    }
                    .buttonStyle(.plain)
                    Button(action: onStart) {
                        AccentPill(title: "Start", systemImage: "record.circle", expands: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.recording.readyToGo)
                    .opacity(model.recording.readyToGo ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

extension FramingView {
    /// How bright the text is over the camera, for this take and the ones after.
    private var textBrightness: some View {
        HStack(spacing: 12) {
            Image(systemName: "textformat")
                .font(.headline)
                .foregroundStyle(EarwigTheme.text)
                .accessibilityHidden(true)
            Slider(value: $textOverCamera, in: TakeSettings.textOverCameraRange, step: 0.05)
                .accessibilityLabel("Text brightness over the camera")
            Text("\(Int((textOverCamera * 100).rounded()))%")
                .font(.subheadline.monospacedDigit().bold())
                .foregroundStyle(EarwigTheme.text)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(EarwigTheme.surface.opacity(0.85), in: Capsule())
    }
}

/// The capture session's preview layer, turned with the phone so the horizon stays level. Also
/// behind the scrolling text during a video take.
struct CameraPreview: UIViewRepresentable {
    let camera: CameraCapture

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let device = camera.device { view.follow(device) }
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        // swiftlint:disable:next force_cast
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        private var rotation: AVCaptureDevice.RotationCoordinator?
        private var observation: NSKeyValueObservation?

        func follow(_ device: AVCaptureDevice) {
            let rotation = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
            self.rotation = rotation
            turn(to: rotation.videoRotationAngleForHorizonLevelPreview)
            observation = rotation.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] _, change in
                guard let angle = change.newValue else { return }
                Task { @MainActor in self?.turn(to: angle) }
            }
        }

        private func turn(to angle: CGFloat) {
            guard let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }
    }
}
