import AVFoundation
import UIKit

/// What a take's recording left behind (plan 010).
struct RecordingResult: Equatable, Sendable {
    var url: URL
    var video: Bool
    /// Seconds into the recording at which the video stopped early, and why (decision 9).
    var videoStoppedAt: TimeInterval?
    var videoStopReason: String?
    /// Seconds recorded.
    var duration: TimeInterval
    var droppedAudio = 0
    var droppedVideo = 0
    /// How long after it was taken the camera delivered its last frame, in seconds.
    var frameDelay: TimeInterval?
}

/// A take's recording as the take uses it: `TakeRecording`, or a fake in tests.
@MainActor
protocol TakeCapture: AnyObject {
    var video: Bool { get }
    /// The video stopped early and will not resume, with why; the sound carries on (decision 9).
    var onVideoStopped: ((String) -> Void)? { get set }
    /// Recording failed and has stopped, with why; the take carries on (decision 6).
    var onFailed: ((String) -> Void)? { get set }
    /// Gets the camera ready, for video; `nil` when ready, otherwise why not.
    func prepare() async -> String?
    /// Starts recording from this host time: the take's slate (decision 3).
    func start(at hostTime: TimeInterval)
    /// Records on for `RecordingWriter.tail` after the take, then finishes the file; `nil` when
    /// nothing was recorded.
    func finish() async -> RecordingResult?
    /// The camera, for the framing preview; `nil` for sound.
    var camera: CameraCapture? { get }
}

/// Records a take (plan 010, decisions 2 and 3): the sound from the mic tap the listener already
/// has, as the tap's second consumer, and for video the front camera's frames, written by one
/// `AVAssetWriter` on the host clock.
@MainActor
final class TakeRecording: TakeCapture {
    let video: Bool
    private let quality: VideoQuality
    private let url: URL
    private let audio: AudioEngineHost
    private let log: (String) -> Void
    private let queue = DispatchQueue(label: "com.bowerhaus.Earwig.recording", qos: .userInitiated)
    let camera: CameraCapture?
    private var writer: RecordingWriter?
    private var thermalObserver: NSObjectProtocol?
    private var finished = false
    /// No camera to film with: the simulator. The take records its sound alone.
    private var cameraMissing = false

    var onVideoStopped: ((String) -> Void)?
    var onFailed: ((String) -> Void)?

    init(url: URL, video: Bool, quality: VideoQuality, audio: AudioEngineHost, log: @escaping (String) -> Void = Log.event) {
        self.url = url
        self.video = video
        self.quality = quality
        self.audio = audio
        self.log = log
        camera = video ? CameraCapture(queue: queue) : nil
        camera?.onEvent = log
        camera?.onInterrupted = { [weak self] in self?.stopVideo($0) }
    }

    func prepare() async -> String? {
        guard let camera else { return nil }
        guard await CameraCapture.requestAccess() else {
            return "Earwig needs the camera to film the take. Allow it in Settings › Privacy & Security › Camera."
        }
        do {
            try camera.configure(quality: quality)
        } catch CameraCapture.CameraError.noCamera {
            #if targetEnvironment(simulator)
            log("recording: no camera in the simulator; sound only")
            cameraMissing = true
            return nil
            #else
            return CameraCapture.CameraError.noCamera.localizedDescription
            #endif
        } catch {
            return error.localizedDescription
        }
        await camera.startRunning()
        return nil
    }

    func start(at hostTime: TimeInterval) {
        guard writer == nil, !finished else { return }
        let sampleRate = audio.micFormat.sampleRate > 0 ? audio.micFormat.sampleRate : 48_000
        let angle = camera?.rotationAngle ?? 0
        do {
            let writer = try RecordingWriter(url: url, queue: queue, video: video ? camera?.videoSettings : nil,
                                             rotation: angle, clock: camera?.clock, sampleRate: sampleRate)
            writer.onFailure = { [weak self] message in
                Task { @MainActor in self?.failed(message) }
            }
            self.writer = writer
            writer.begin(at: hostTime)
            audio.setMicRecorder { buffer, host in writer.appendAudio(buffer, hostTime: host) }
            camera?.setSink { sample in writer.appendVideo(sample) }
            if cameraMissing { writer.stopVideo(reason: "there is no camera") }
        } catch {
            failed("the recording could not start: \(error.localizedDescription)")
            return
        }
        UIDevice.current.isBatteryMonitoringEnabled = true
        log("recording: started \(video ? "video \(quality.label), rotation \(Int(angle))°" : "sound"), mic \(Int(sampleRate)) Hz, \(Self.conditions()), to \(url.lastPathComponent)")
        thermalObserver = NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.log("recording: \(Self.conditions())") }
        }
    }

    func finish() async -> RecordingResult? {
        guard !finished else { return nil }
        finished = true
        if let thermalObserver { NotificationCenter.default.removeObserver(thermalObserver) }
        thermalObserver = nil
        // The sound and the frames keep coming until the writer has what it needs: the camera
        // delivers a frame well after it is taken (stabilisation), so the end would be cut off.
        let result = await writer?.finish(at: HostClock.now + RecordingWriter.tail)
        audio.setMicRecorder(nil)
        camera?.setSink(nil)
        await camera?.stopRunning()
        writer = nil
        guard var result else {
            log("recording: nothing recorded")
            return nil
        }
        result.droppedVideo += camera?.droppedFrames ?? 0
        log(String(format: "recording: finished %.1f s, %@, dropped %d audio buffers and %d frames%@%@, %@",
                   result.duration, url.lastPathComponent, result.droppedAudio, result.droppedVideo,
                   result.frameDelay.map { String(format: ", frames %.0f ms late", $0 * 1000) } ?? "",
                   result.videoStoppedAt.map { String(format: ", video stopped at %.1f s", $0) } ?? "", Self.conditions()))
        return result
    }

    private func stopVideo(_ reason: String) {
        guard video, let writer, !finished else { return }
        camera?.setSink(nil)
        writer.stopVideo(reason: reason)
        log("recording: video stopped: \(reason)")
        onVideoStopped?(reason)
    }

    private func failed(_ message: String) {
        guard !finished else { return }
        log("recording: failed: \(message)")
        audio.setMicRecorder(nil)
        camera?.setSink(nil)
        onFailed?(message)
    }

    /// The thermal state and battery, for the console (decision 10).
    static func conditions() -> String {
        let thermal: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "nominal"
        case .fair: thermal = "fair"
        case .serious: thermal = "serious"
        case .critical: thermal = "critical"
        @unknown default: thermal = "unknown"
        }
        let battery = UIDevice.current.batteryLevel
        return "thermal \(thermal), battery \(battery < 0 ? "unknown" : "\(Int(battery * 100))%")"
    }
}

/// The writer behind a take's recording (decisions 2 and 3). Everything after `init` runs on its
/// queue: the mic's buffers are copied on the audio thread and handed to it, the camera delivers
/// its frames on it. Sound and frames are stamped on the host clock. The file starts on the first
/// frame at or after the start (sound alone, on the first buffer), and sound before that is
/// trimmed by the writer.
final class RecordingWriter: @unchecked Sendable {
    /// Seconds recorded after the take ends, so its last word is not cut off (device check 1c).
    static let tail: TimeInterval = 1
    /// The longest the end waits for the camera's frames to reach the end time.
    static let endWait: TimeInterval = 3

    private let writer: AVAssetWriter
    private let audioInput: AVAssetWriterInput
    private let videoInput: AVAssetWriterInput?
    private let queue: DispatchQueue
    private let clock: CMClock?
    private let sampleRate: Double
    /// Mono, 32-bit float, at the mic's rate: what the mic's buffers are copied into.
    let audioFormat: AVAudioFormat

    /// Called once, on the writer's queue, when writing fails.
    var onFailure: (@Sendable (String) -> Void)?

    private var startHost: TimeInterval?
    private var sessionStart: CMTime?
    /// The next audio buffer's time, when it follows on from the last.
    private var audioNext: (pts: CMTime, host: TimeInterval)?
    /// Sound that arrived before the first frame, held until the file starts.
    private var pending: [(buffer: AVAudioPCMBuffer, host: TimeInterval)] = []
    private var lastAudioEnd: CMTime?
    private var lastVideo: CMTime?
    private var videoEnded = false
    private var videoStoppedAt: TimeInterval?
    private var videoStopReason: String?
    private var done = false
    /// The end once asked for: host seconds, and what to call when it is reached.
    private var stopHost: TimeInterval?
    private var ending: CheckedContinuation<RecordingResult?, Never>?
    private var frameDelay: TimeInterval?
    private var failed = false
    private var droppedAudio = 0
    private var droppedVideo = 0

    /// `video` is the writer's video settings, or `nil` for sound alone (`.m4a`). `rotation` is in
    /// degrees, written as the file's transform. `clock` is the frames' clock, if not the host's.
    init(url: URL, queue: DispatchQueue, video: [String: Any]?, rotation: CGFloat, clock: CMClock?, sampleRate: Double) throws {
        self.queue = queue
        self.clock = clock
        self.sampleRate = sampleRate
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw RecordingError.format
        }
        audioFormat = format
        writer = try AVAssetWriter(outputURL: url, fileType: video == nil ? .m4a : .mov)
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000
        ])
        audioInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(audioInput) else { throw RecordingError.input }
        writer.add(audioInput)
        if let video {
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: video)
            input.expectsMediaDataInRealTime = true
            input.transform = CGAffineTransform(rotationAngle: rotation * .pi / 180)
            guard writer.canAdd(input) else { throw RecordingError.input }
            writer.add(input)
            videoInput = input
        } else {
            videoInput = nil
        }
    }

    /// Starts writing; the file begins at `hostTime` or the first frame after it.
    func begin(at hostTime: TimeInterval) {
        queue.async { [self] in
            startHost = hostTime
            guard writer.startWriting() else { return fail() }
        }
    }

    /// From the mic tap, on the audio thread: the buffer is copied here and written on the queue.
    func appendAudio(_ buffer: AVAudioPCMBuffer, hostTime: TimeInterval) {
        guard let copy = Self.monoCopy(buffer, into: audioFormat) else { return }
        queue.async { [self] in writeAudio(copy, host: hostTime) }
    }

    /// From the camera, on the queue.
    func appendVideo(_ sample: CMSampleBuffer) {
        dispatchPrecondition(condition: .onQueue(queue))
        writeVideo(sample)
    }

    /// The video ends here; the sound carries on to the end (decision 9).
    func stopVideo(reason: String) {
        queue.async { [self] in
            guard !videoEnded else { return }
            videoEnded = true
            videoStopReason = reason
            if let sessionStart {
                videoStoppedAt = ((lastVideo ?? sessionStart) - sessionStart).seconds
                videoInput?.markAsFinished()
            }
        }
    }

    /// Finishes the file at `hostTime`, once the sound and (for video) the frames have reached it,
    /// or after `endWait` at most; `nil` when nothing was written.
    func finish(at hostTime: TimeInterval) async -> RecordingResult? {
        await withCheckedContinuation { (continuation: CheckedContinuation<RecordingResult?, Never>) in
            queue.async { [self] in
                guard !done, ending == nil else { return continuation.resume(returning: nil) }
                stopHost = hostTime
                ending = continuation
                endIfReached()
                queue.asyncAfter(deadline: .now() + max(0, hostTime - HostClock.now) + Self.endWait) { [self] in end() }
            }
        }
    }

    /// Ends once the sound and the picture have both reached the end time.
    private func endIfReached() {
        guard let stopHost, ending != nil else { return }
        let stop = CMTime(seconds: stopHost, preferredTimescale: 1_000_000_000)
        let soundThere = (lastAudioEnd ?? .zero) >= stop
        let pictureThere = videoInput == nil || videoEnded || (lastVideo ?? .zero) >= stop
        if soundThere && pictureThere { end() }
    }

    private func end() {
        guard let continuation = ending, !done else { return }
        ending = nil
        done = true
        guard !failed, writer.status == .writing, let sessionStart else {
            if writer.status == .writing { writer.cancelWriting() }
            return continuation.resume(returning: nil)
        }
        audioInput.markAsFinished()
        if !videoEnded { videoInput?.markAsFinished() }
        let last = [lastAudioEnd, lastVideo].compactMap { $0 }.max() ?? sessionStart
        let stop = stopHost.map { min(last, CMTime(seconds: $0, preferredTimescale: 1_000_000_000)) } ?? last
        let endTime = max(stop, sessionStart)
        writer.endSession(atSourceTime: endTime)
        let result = RecordingResult(url: writer.outputURL, video: videoInput != nil,
                                     videoStoppedAt: videoStoppedAt, videoStopReason: videoStopReason,
                                     duration: (endTime - sessionStart).seconds,
                                     droppedAudio: droppedAudio, droppedVideo: droppedVideo, frameDelay: frameDelay)
        writer.finishWriting { [writer] in
            continuation.resume(returning: writer.status == .completed ? result : nil)
        }
    }

    // MARK: - On the queue

    private func writeAudio(_ buffer: AVAudioPCMBuffer, host: TimeInterval) {
        guard !done, !failed, let startHost, writer.status == .writing else { return }
        let length = Double(buffer.frameLength) / sampleRate
        guard host + length > startHost, stopHost.map({ host < $0 }) ?? true else { return }
        if sessionStart == nil {
            if videoInput != nil, !videoEnded {
                // Held until the first frame starts the file; a couple of seconds at most.
                pending.append((buffer, host))
                if pending.count > 100 { pending.removeFirst() }
                return
            }
            start(at: CMTime(seconds: max(host, startHost), preferredTimescale: 1_000_000_000))
        }
        appendAudio(buffer, host: host)
    }

    private func appendAudio(_ buffer: AVAudioPCMBuffer, host: TimeInterval) {
        guard let sessionStart else { return }
        let frames = Int64(buffer.frameLength)
        let scale = CMTimeScale(sampleRate)
        // Each buffer follows on from the last by its sample count, unless the tap's times have
        // moved on (a dropped buffer, an engine restart), so the encoder sees no jitter.
        let pts: CMTime
        if let next = audioNext, abs(host - next.host) < 0.02 {
            pts = next.pts
        } else {
            pts = CMTime(value: Int64((host * sampleRate).rounded()), timescale: scale)
        }
        let end = pts + CMTime(value: frames, timescale: scale)
        audioNext = (end, host + Double(frames) / sampleRate)
        guard end > sessionStart else { return }
        guard let sample = Self.sampleBuffer(buffer, pts: pts) else {
            droppedAudio += 1
            return
        }
        guard audioInput.isReadyForMoreMediaData else {
            droppedAudio += 1
            return
        }
        if !audioInput.append(sample) { return fail() }
        lastAudioEnd = end
        endIfReached()
    }

    private func writeVideo(_ sample: CMSampleBuffer) {
        guard !done, !failed, !videoEnded, let videoInput, let startHost, writer.status == .writing else { return }
        var sample = sample
        var pts = CMSampleBufferGetPresentationTimeStamp(sample)
        let host = CMClockGetHostTimeClock()
        if let clock, !CFEqual(clock, host) {
            pts = CMSyncConvertTime(pts, from: clock, to: host)
            var timing = CMSampleTimingInfo(duration: CMSampleBufferGetDuration(sample), presentationTimeStamp: pts, decodeTimeStamp: .invalid)
            var retimed: CMSampleBuffer?
            guard CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sample, sampleTimingEntryCount: 1,
                                                        sampleTimingArray: &timing, sampleBufferOut: &retimed) == noErr, let retimed else { return }
            sample = retimed
        }
        guard pts.seconds >= startHost, stopHost.map({ pts.seconds <= $0 + 0.05 }) ?? true else { return }
        if sessionStart == nil {
            start(at: pts)
            let held = pending
            pending = []
            for (buffer, host) in held { appendAudio(buffer, host: host) }
        }
        guard videoInput.isReadyForMoreMediaData else {
            droppedVideo += 1
            return
        }
        if !videoInput.append(sample) { return fail() }
        lastVideo = pts
        frameDelay = HostClock.now - pts.seconds
        endIfReached()
    }

    private func start(at time: CMTime) {
        writer.startSession(atSourceTime: time)
        sessionStart = time
    }

    private func fail() {
        guard !failed else { return }
        failed = true
        onFailure?(writer.error?.localizedDescription ?? "the file could not be written")
    }

    // MARK: - Buffers

    /// The buffer's first channel as mono float, or `nil` if it is not float audio.
    static func monoCopy(_ buffer: AVAudioPCMBuffer, into format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = Int(buffer.frameLength)
        guard frames > 0, let source = buffer.floatChannelData,
              let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameLength),
              let target = copy.floatChannelData else { return nil }
        copy.frameLength = buffer.frameLength
        let stride = buffer.stride
        if stride == 1 {
            target[0].update(from: source[0], count: frames)
        } else {
            for index in 0..<frames { target[0][index] = source[0][index * stride] }
        }
        return copy
    }

    /// A sample buffer of the audio at `pts`.
    static func sampleBuffer(_ buffer: AVAudioPCMBuffer, pts: CMTime) -> CMSampleBuffer? {
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: pts.timescale), presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil, refcon: nil,
                                   formatDescription: buffer.format.formatDescription, sampleCount: CMItemCount(buffer.frameLength),
                                   sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil,
                                   sampleBufferOut: &sample) == noErr, let sample else { return nil }
        guard CMSampleBufferSetDataBufferFromAudioBufferList(sample, blockBufferAllocator: kCFAllocatorDefault, blockBufferMemoryAllocator: kCFAllocatorDefault,
                                                             flags: 0, bufferList: buffer.audioBufferList) == noErr else { return nil }
        return sample
    }

    enum RecordingError: LocalizedError {
        case format
        case input

        var errorDescription: String? {
            switch self {
            case .format: "The recording's sound format could not be made."
            case .input: "The recording could not be set up."
            }
        }
    }
}
