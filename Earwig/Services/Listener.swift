import AVFoundation
import CoreMedia
import Observation
import Speech

/// A word the recogniser heard, with when it was said and when it was first reported.
struct HeardWord: Identifiable, Equatable, Sendable {
    let id = UUID()
    var text: String
    /// Start of the word on the analyser's timeline, seconds from the start of listening.
    let audioStart: TimeInterval
    /// Host-clock seconds at which the word was said, mapped from `audioStart`.
    let spokenAt: TimeInterval
    /// Host-clock seconds at which a result first contained this word.
    let firstHeardAt: TimeInterval
    var isFinal: Bool
    /// Host-clock seconds at which a final result first contained this word.
    var finalisedAt: TimeInterval?
    var confidence: Double?

    /// Seconds from saying the word to first seeing it.
    var delay: TimeInterval { firstHeardAt - spokenAt }

    /// Seconds from saying the word to its final result.
    var finalDelay: TimeInterval? { finalisedAt.map { $0 - spokenAt } }
}

/// Continuous on-device recognition of the presenter from the iPhone's mic (PRD §4.3, §7.2):
/// `SpeechAnalyzer` with a `SpeechTranscriber` in en-GB, volatile results on, word audio time
/// ranges on. Downloads the locale's assets through `AssetInventory` when they are missing.
@MainActor
@Observable
final class Listener {
    enum State: Equatable {
        case idle
        case preparing
        case downloading(Double)
        case listening
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var assetStatus = "unknown"
    private(set) var localeIdentifier = "en-GB"
    /// Every word heard since `start`, in the order spoken.
    private(set) var words: [HeardWord] = []
    /// Set once if volatile results arrived without word time ranges.
    private(set) var volatileWithoutTimes = false

    @ObservationIgnored var onWordsChanged: (([HeardWord]) -> Void)?
    @ObservationIgnored var onEvent: ((String) -> Void)?

    @ObservationIgnored private let audio: AudioEngineHost
    @ObservationIgnored private var analyzer: SpeechAnalyzer?
    @ObservationIgnored private var feeder: MicFeeder?
    @ObservationIgnored private var resultsTask: Task<Void, Never>?

    init(audio: AudioEngineHost) {
        self.audio = audio
    }

    /// The mic's level, 0 to 1, for a meter.
    var inputLevel: Float { feeder?.level ?? 0 }

    /// Checks the locale and its assets without starting, for showing their state.
    func checkAssets() async {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-GB")) else {
            assetStatus = "en-GB not supported"
            return
        }
        localeIdentifier = locale.identifier
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        assetStatus = Self.describe(await AssetInventory.status(forModules: [transcriber]))
    }

    /// Starts listening. `contextWords`, when given, are passed to the analyser as contextual
    /// strings (the script's vocabulary).
    func start(contextWords: [String]?, fastResults: Bool) async {
        guard state != .listening, state != .preparing else { return }
        state = .preparing
        words = []
        volatileWithoutTimes = false
        do {
            guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-GB")) else {
                throw ListenerError.unsupportedLocale
            }
            localeIdentifier = locale.identifier
            let transcriber = SpeechTranscriber(
                locale: locale,
                transcriptionOptions: [],
                reportingOptions: fastResults ? [.volatileResults, .fastResults] : [.volatileResults],
                attributeOptions: [.audioTimeRange, .transcriptionConfidence]
            )
            try await ensureAssets(for: transcriber, locale: locale)
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                throw ListenerError.noFormat
            }
            let analyzer = SpeechAnalyzer(modules: [transcriber], options: .init(priority: .userInitiated, modelRetention: .processLifetime))
            if let contextWords, !contextWords.isEmpty {
                let context = AnalysisContext()
                context.contextualStrings[.general] = contextWords
                try await analyzer.setContext(context)
            }
            try await analyzer.prepareToAnalyze(in: format)

            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream(bufferingPolicy: .unbounded)
            let feeder = MicFeeder(analyzerFormat: format, continuation: continuation)
            self.feeder = feeder
            self.analyzer = analyzer

            resultsTask = Task { [weak self] in
                do {
                    for try await result in transcriber.results {
                        let receivedAt = HostClock.now
                        self?.handle(result, receivedAt: receivedAt)
                    }
                } catch {
                    self?.onEvent?("results ended with error: \(error.localizedDescription)")
                }
            }
            try audio.installMicTap { buffer, host in feeder.feed(buffer, hostTime: host) }
            try await analyzer.start(inputSequence: stream)
            state = .listening
            onEvent?("listening: \(locale.identifier), analyser format \(Int(format.sampleRate)) Hz, mic \(Int(audio.micFormat.sampleRate)) Hz, fast results \(fastResults ? "on" : "off"), context \(contextWords == nil ? "off" : "on")")
        } catch {
            state = .failed(error.localizedDescription)
            onEvent?("listener failed to start: \(error.localizedDescription)")
            await tearDown()
        }
    }

    func stop() async {
        guard analyzer != nil else {
            state = .idle
            return
        }
        audio.removeMicTap()
        feeder?.finish()
        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            onEvent?("finalise failed: \(error.localizedDescription)")
        }
        await tearDown()
        state = .idle
        onEvent?("listening stopped")
    }

    func clearWords() {
        words = []
        onWordsChanged?(words)
    }

    private func tearDown() async {
        audio.removeMicTap()
        feeder?.finish()
        feeder = nil
        if let analyzer { await analyzer.cancelAndFinishNow() }
        analyzer = nil
        resultsTask?.cancel()
        resultsTask = nil
    }

    private func ensureAssets(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        let status = await AssetInventory.status(forModules: [transcriber])
        assetStatus = Self.describe(status)
        guard status != .installed else { return }
        guard status != .unsupported else { throw ListenerError.unsupportedLocale }
        if !(await AssetInventory.reservedLocales).contains(where: { $0.identifier == locale.identifier }) {
            _ = try? await AssetInventory.reserve(locale: locale)
        }
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else { return }
        onEvent?("downloading speech assets for \(locale.identifier)")
        state = .downloading(0)
        let progress = request.progress
        let poll = Task { [weak self] in
            while !Task.isCancelled {
                self?.state = .downloading(progress.fractionCompleted)
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        defer { poll.cancel() }
        try await request.downloadAndInstall()
        assetStatus = Self.describe(await AssetInventory.status(forModules: [transcriber]))
        onEvent?("speech assets: \(assetStatus)")
    }

    // MARK: - Results

    private func handle(_ result: SpeechTranscriber.Result, receivedAt: TimeInterval) {
        guard let feeder else { return }
        let rangeStart = result.range.start.seconds
        let rangeEnd = CMTimeRangeGetEnd(result.range).seconds
        let isFinal = result.isFinal

        struct Incoming {
            let text: String
            let start: TimeInterval
            let confidence: Double?
        }
        var incoming: [Incoming] = []
        var untimed: [String] = []
        for run in result.text.runs {
            let text = String(result.text[run.range].characters)
            let pieces = text.split(whereSeparator: \.isWhitespace).map(String.init)
            guard !pieces.isEmpty else { continue }
            if let timeRange = run.audioTimeRange {
                for piece in pieces { incoming.append(Incoming(text: piece, start: timeRange.start.seconds, confidence: run.transcriptionConfidence)) }
            } else {
                untimed += pieces
            }
        }
        if !untimed.isEmpty {
            if !isFinal, !volatileWithoutTimes {
                volatileWithoutTimes = true
                onEvent?("volatile results arrive without word times; spreading them over the result's range")
            }
            let step = untimed.isEmpty ? 0 : max(rangeEnd - rangeStart, 0) / Double(untimed.count)
            for (index, piece) in untimed.enumerated() {
                incoming.append(Incoming(text: piece, start: rangeStart + step * Double(index), confidence: nil))
            }
        }

        // Replace what this result covers. A volatile result also replaces any earlier
        // volatile words after its start, as its hypothesis may be shorter than the last.
        let replaced = words.filter { word in
            (word.audioStart >= rangeStart - 0.001 && word.audioStart < rangeEnd) || (!isFinal && !word.isFinal && word.audioStart >= rangeStart)
        }
        let replacedIDs = Set(replaced.map(\.id))
        var kept = words.filter { !replacedIDs.contains($0.id) }
        for item in incoming {
            let earlier = replaced.min { abs($0.audioStart - item.start) < abs($1.audioStart - item.start) }
            let sameWord = earlier.map { abs($0.audioStart - item.start) < 0.25 } ?? false
            kept.append(HeardWord(
                text: item.text,
                audioStart: item.start,
                spokenAt: feeder.hostTime(forAnalyzerTime: item.start),
                firstHeardAt: sameWord ? earlier!.firstHeardAt : receivedAt,
                isFinal: isFinal,
                finalisedAt: isFinal ? ((sameWord ? earlier!.finalisedAt : nil) ?? receivedAt) : nil,
                confidence: item.confidence
            ))
        }
        kept.sort { $0.audioStart < $1.audioStart }
        words = kept
        onWordsChanged?(words)
    }

    private static func describe(_ status: AssetInventory.Status) -> String {
        switch status {
        case .unsupported: "unsupported"
        case .supported: "not installed"
        case .downloading: "downloading"
        case .installed: "installed"
        @unknown default: "unknown"
        }
    }

    enum ListenerError: LocalizedError {
        case unsupportedLocale
        case noFormat

        var errorDescription: String? {
            switch self {
            case .unsupportedLocale: "On-device transcription does not support en-GB on this iPhone."
            case .noFormat: "The speech analyser offered no audio format."
            }
        }
    }
}

/// Converts mic buffers to the analyser's format on the audio thread, stamps each with its
/// place on the analyser's timeline, and remembers which host time each place was captured
/// at, so a word's audio time maps back to when it was said.
private final class MicFeeder: @unchecked Sendable {
    private let analyzerFormat: AVAudioFormat
    private let continuation: AsyncStream<AnalyzerInput>.Continuation
    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var framesFed: AVAudioFramePosition = 0
    private var anchors: [(analyzer: TimeInterval, host: TimeInterval)] = []
    private var currentLevel: Float = 0
    private var finished = false

    init(analyzerFormat: AVAudioFormat, continuation: AsyncStream<AnalyzerInput>.Continuation) {
        self.analyzerFormat = analyzerFormat
        self.continuation = continuation
    }

    var level: Float { lock.withLock { currentLevel } }

    func feed(_ buffer: AVAudioPCMBuffer, hostTime: TimeInterval) {
        let level = Self.rms(buffer)
        guard let output = convert(buffer) else {
            lock.withLock { currentLevel = level }
            return
        }
        let start: TimeInterval = lock.withLock {
            currentLevel = level
            let start = Double(framesFed) / analyzerFormat.sampleRate
            anchors.append((start, hostTime))
            if anchors.count > 4000 { anchors.removeFirst(anchors.count - 4000) }
            framesFed += AVAudioFramePosition(output.frameLength)
            return start
        }
        guard !lock.withLock({ finished }) else { return }
        let time = CMTime(seconds: start, preferredTimescale: CMTimeScale(analyzerFormat.sampleRate))
        continuation.yield(AnalyzerInput(buffer: output, bufferStartTime: time))
    }

    func finish() {
        lock.withLock { finished = true }
        continuation.finish()
    }

    func hostTime(forAnalyzerTime time: TimeInterval) -> TimeInterval {
        lock.withLock {
            guard let anchor = anchors.last(where: { $0.analyzer <= time }) ?? anchors.first else { return time }
            return anchor.host + (time - anchor.analyzer)
        }
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if buffer.format == analyzerFormat { return buffer }
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: analyzerFormat)
        }
        guard let converter else { return nil }
        let ratio = analyzerFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return nil }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, error == nil, output.frameLength > 0 else { return nil }
        return output
    }

    private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) { sum += data[index] * data[index] }
        return min(1, (sum / Float(buffer.frameLength)).squareRoot() * 4)
    }
}
