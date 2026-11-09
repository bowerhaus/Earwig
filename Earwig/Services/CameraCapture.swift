import AVFoundation

/// The front camera for a video take (plan 010, decision 2): a capture session with the camera
/// as its only input and a video data output, frames delivered on the recording's queue. It is
/// never given a microphone and never configures the audio session, so the session, the A2DP
/// route and the audio engine stay as the take set them.
@MainActor
final class CameraCapture {
    /// Started and stopped on `sessionQueue`, configured on the main actor before it runs.
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let output = AVCaptureVideoDataOutput()
    private let frames = FrameDelegate()
    private let queue: DispatchQueue
    private let sessionQueue = DispatchQueue(label: "com.bowerhaus.Earwig.camera")
    /// The front camera once configured, for the framing preview's rotation.
    private(set) var device: AVCaptureDevice?
    private var rotation: AVCaptureDevice.RotationCoordinator?
    /// Removed in `deinit`, which is not on the main actor.
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    /// The session was interrupted (Earwig left the screen, the phone locked) or failed, with why.
    var onInterrupted: ((String) -> Void)?
    var onEvent: ((String) -> Void)?

    /// `queue` is where frames are delivered: the recording's own queue.
    init(queue: DispatchQueue) {
        self.queue = queue
        let centre = NotificationCenter.default
        observers.append(centre.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: .main) { [weak self] note in
            let reason = (note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int).flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
            MainActor.assumeIsolated { self?.interrupted(reason) }
        })
        observers.append(centre.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main) { [weak self] note in
            let error = note.userInfo?[AVCaptureSessionErrorKey] as? Error
            MainActor.assumeIsolated {
                self?.onEvent?("camera runtime error: \(error?.localizedDescription ?? "unknown")")
                self?.onInterrupted?("the camera stopped")
            }
        })
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    /// Sets up the front camera at the quality, 30 frames a second. Throws when there is no front
    /// camera or it cannot be used.
    func configure(quality: VideoQuality) throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CameraError.noCamera
        }
        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // Never let the capture session touch the audio session: it has no microphone, and the
        // take's session is Earwig's own (plan 010, decision 2).
        session.automaticallyConfiguresApplicationAudioSession = false
        let preset: AVCaptureSession.Preset = quality == .uhd4K ? .hd4K3840x2160 : .hd1920x1080
        session.sessionPreset = session.canSetSessionPreset(preset) ? preset : .hd1920x1080
        guard session.canAddInput(input) else { throw CameraError.cannotUse }
        session.addInput(input)
        output.alwaysDiscardsLateVideoFrames = false
        output.setSampleBufferDelegate(frames, queue: queue)
        guard session.canAddOutput(output) else { throw CameraError.cannotUse }
        session.addOutput(output)
        if let connection = output.connection(with: .video) {
            // Written as the camera sees it; the framing preview mirrors it.
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
            if connection.isVideoStabilizationSupported { connection.preferredVideoStabilizationMode = .auto }
        }
        try device.lockForConfiguration()
        let thirty = CMTime(value: 1, timescale: 30)
        if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }) {
            device.activeVideoMinFrameDuration = thirty
            device.activeVideoMaxFrameDuration = thirty
        }
        device.unlockForConfiguration()
        self.device = device
        rotation = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        onEvent?("camera configured: front, \(dimensions.width)x\(dimensions.height), preset \(session.sessionPreset.rawValue)")
    }

    func startRunning() async {
        let box = SessionBox(session: session)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                box.session.startRunning()
                continuation.resume()
            }
        }
        onEvent?("camera running: \(session.isRunning)")
    }

    func stopRunning() async {
        setSink(nil)
        let box = SessionBox(session: session)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                if box.session.isRunning { box.session.stopRunning() }
                continuation.resume()
            }
        }
    }

    /// The angle to turn the camera's frames by so the horizon is level, for how the phone is
    /// held now; read at the take's start and fixed for it (decision 9).
    var rotationAngle: CGFloat { rotation?.videoRotationAngleForHorizonLevelCapture ?? 90 }

    /// The writer's settings for HEVC at the session's size.
    var videoSettings: [String: Any]? {
        output.recommendedVideoSettings(forVideoCodecType: .hevc, assetWriterOutputFileType: .mov)
    }

    /// The clock the frames are stamped on.
    var clock: CMClock? { session.synchronizationClock }

    /// Each frame, on the recording's queue, until set to `nil`.
    func setSink(_ sink: (@Sendable (CMSampleBuffer) -> Void)?) {
        frames.set(sink)
    }

    /// Frames the camera dropped before delivering them.
    var droppedFrames: Int { frames.dropped }

    private func interrupted(_ reason: AVCaptureSession.InterruptionReason?) {
        let why: String
        switch reason {
        // iOS reports the phone locked and Earwig sent to the background alike.
        case .videoDeviceNotAvailableInBackground: why = "the phone was locked or Earwig left the screen"
        case .videoDeviceInUseByAnotherClient: why = "another app took the camera"
        case .videoDeviceNotAvailableDueToSystemPressure: why = "the phone was too hot"
        case .videoDeviceNotAvailableWithMultipleForegroundApps: why = "another app was on screen"
        default: why = "the camera was interrupted"
        }
        onEvent?("camera interrupted: \(why)")
        onInterrupted?(why)
    }

    enum CameraError: LocalizedError {
        case noCamera
        case cannotUse

        var errorDescription: String? {
            switch self {
            case .noCamera: "This iPhone has no front camera Earwig can use."
            case .cannotUse: "The front camera could not be set up."
            }
        }
    }
}

/// The capture session, carried to its own queue to start and stop it there, as Apple asks.
private struct SessionBox: @unchecked Sendable {
    let session: AVCaptureSession
}

/// Passes the camera's frames on, read on the recording's queue and set on the main actor.
private final class FrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var sink: (@Sendable (CMSampleBuffer) -> Void)?
    private var droppedCount = 0

    func set(_ sink: (@Sendable (CMSampleBuffer) -> Void)?) {
        lock.withLock { self.sink = sink }
    }

    var dropped: Int { lock.withLock { droppedCount } }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let sink = lock.withLock { self.sink }
        sink?(sampleBuffer)
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        lock.withLock {
            if sink != nil { droppedCount += 1 }
        }
    }
}
