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

    /// Seconds from starting to say the word to first seeing it. Exact once the word is
    /// final; before that `spokenAt` is an estimate spread across the interim block.
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
    @ObservationIgnored private var volatileCount = 0
    @ObservationIgnored private var finalCount = 0
    @ObservationIgnored private var lastResultAt: TimeInterval?
    @ObservationIgnored private var lastFastResults = true
    @ObservationIgnored private var lastContextWords: [String]?
    @ObservationIgnored private var restartedAt: TimeInterval?
    /// Added to the analyser's times so words heard after a restart (whose timeline starts
    /// again at zero) sort after the words before it.
    @ObservationIgnored private var audioOffset: TimeInterval = 0
    @ObservationIgnored private var carryOffset: TimeInterval = 0
    /// When each word of the current interim block, by its place in the block, first
    /// appeared. Shifted along as finals take words off the front.
    @ObservationIgnored private var segmentFirstSeen: [TimeInterval] = []

    @ObservationIgnored var onWordsChanged: (([HeardWord]) -> Void)?
    @ObservationIgnored var onEvent: ((String) -> Void)?

    @ObservationIgnored private let audio: AudioEngineHost
    @ObservationIgnored private var analyzer: SpeechAnalyzer?
    @ObservationIgnored private var feeder: MicFeeder?
    @ObservationIgnored private var resultsTask: Task<Void, Never>?

    init(audio: AudioEngineHost) {
        self.audio = audio
    }

    /// Seconds of audio heard since `start`, on the same timeline as `HeardWord.audioStart`.
    var currentAudioTime: TimeInterval { (feeder?.fed.seconds ?? 0) + audioOffset }

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
        volatileCount = 0
        finalCount = 0
        lastResultAt = nil
        lastFastResults = fastResults
        lastContextWords = contextWords
        audioOffset = carryOffset
        carryOffset = 0
        segmentFirstSeen = []
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
                    await self?.recover()
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

    /// One line on whether audio is flowing and results are arriving, for the log.
    var healthLine: String {
        guard let feeder else { return "listener: \(state)" }
        let fed = feeder.fed
        let since = lastResultAt.map { String(format: "%.1f s ago", HostClock.now - $0) } ?? "never"
        return String(format: "health: engine %@, fed %d buffers (%.1f s audio), results %d volatile / %d final, last %@, words %d",
                      audio.isRunning ? "running" : "STOPPED", fed.buffers, fed.seconds, volatileCount, finalCount, since, words.count)
    }

    /// Restarts listening after the results stream failed, at most once every ten seconds.
    private func recover() async {
        guard state == .listening else { return }
        if let restartedAt, HostClock.now - restartedAt < 10 {
            onEvent?("not restarting again so soon; listening stopped")
            await tearDown()
            state = .failed("results ended; restarted too recently")
            return
        }
        restartedAt = HostClock.now
        let kept = words
        carryOffset = (kept.last?.audioStart ?? audioOffset) + 1
        await tearDown()
        state = .idle
        onEvent?("restarting listening")
        await start(contextWords: lastContextWords, fastResults: lastFastResults)
        words = kept + words
        onWordsChanged?(words)
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
        let offset = audioOffset
        let rangeStart = result.range.start.seconds + offset
        let rangeEnd = CMTimeRangeGetEnd(result.range).seconds + offset
        let isFinal = result.isFinal
        lastResultAt = receivedAt
        if isFinal { finalCount += 1 } else { volatileCount += 1 }

        let (incoming, runLog) = incomingWords(in: result, offset: offset, isFinal: isFinal)
        // Console only: the shape of each result, to see how words are timed.
        print(String(format: "result %@ %.2f–%.2f at +%.2f s: ", isFinal ? "final" : "volatile", rangeStart - offset, rangeEnd - offset, receivedAt - (feeder.firstHostTime ?? receivedAt)) + runLog.joined(separator: " | "))

        // Interim results are one block from the end of the last final to now, rewritten
        // each time; finals time every word but come only at pauses (plan 001 Results).
        // So a word's first appearance is tracked by its place in the current block, and
        // its exact spoken time comes from the final.
        if incoming.count > segmentFirstSeen.count {
            segmentFirstSeen += Array(repeating: receivedAt, count: incoming.count - segmentFirstSeen.count)
        }

        // Replace what this result covers. A volatile result replaces every interim word
        // after its start; a final replaces every interim word before its end, as the
        // interim block starts earlier than the final's first word.
        let replaced = words.filter { word in
            if word.isFinal { return word.audioStart >= rangeStart - 0.001 && word.audioStart < rangeEnd }
            return isFinal ? word.audioStart < rangeEnd : word.audioStart >= rangeStart - 0.001
        }
        let replacedIDs = Set(replaced.map(\.id))
        var kept = words.filter { !replacedIDs.contains($0.id) }
        for (index, item) in incoming.enumerated() {
            kept.append(HeardWord(
                text: item.text,
                audioStart: item.start,
                spokenAt: feeder.hostTime(forAnalyzerTime: item.start - offset),
                firstHeardAt: index < segmentFirstSeen.count ? segmentFirstSeen[index] : receivedAt,
                isFinal: isFinal,
                finalisedAt: isFinal ? receivedAt : nil,
                confidence: item.confidence
            ))
        }
        if isFinal {
            segmentFirstSeen.removeFirst(min(incoming.count, segmentFirstSeen.count))
        }
        kept.sort { $0.audioStart < $1.audioStart }
        words = kept
        onWordsChanged?(words)
    }

    private struct Incoming {
        let text: String
        let start: TimeInterval
        let confidence: Double?
    }

    /// A result's words in order with their estimated or exact start times (offset onto
    /// this listening's timeline), and a description of its runs for the console.
    private func incomingWords(in result: SpeechTranscriber.Result, offset: TimeInterval, isFinal: Bool) -> ([Incoming], [String]) {
        let rangeStart = result.range.start.seconds + offset
        let rangeEnd = CMTimeRangeGetEnd(result.range).seconds + offset
        var incoming: [Incoming] = []
        var untimed: [String] = []
        var runLog: [String] = []
        for run in result.text.runs {
            let text = String(result.text[run.range].characters)
            let pieces = text.split(whereSeparator: \.isWhitespace).map(String.init)
            guard !pieces.isEmpty else { continue }
            guard let timeRange = run.audioTimeRange else {
                runLog.append("“\(text)” untimed")
                untimed += pieces
                continue
            }
            // An interim run covers several words with one time range. Spread its words
            // across the range by letter count; finals have one run per word.
            let total = Double(pieces.reduce(0) { $0 + $1.count })
            var before = 0.0
            for piece in pieces {
                let start = timeRange.start.seconds + timeRange.duration.seconds * (total > 0 ? before / total : 0)
                incoming.append(Incoming(text: piece, start: start + offset, confidence: run.transcriptionConfidence))
                before += Double(piece.count)
            }
            runLog.append(String(format: "“%@” %.2f–%.2f", text, timeRange.start.seconds, CMTimeRangeGetEnd(timeRange).seconds))
        }
        if !untimed.isEmpty {
            if !isFinal, !volatileWithoutTimes {
                volatileWithoutTimes = true
                onEvent?("volatile results arrive without word times; spreading them over the result's range")
            }
            let step = max(rangeEnd - rangeStart, 0) / Double(untimed.count)
            for (index, piece) in untimed.enumerated() {
                incoming.append(Incoming(text: piece, start: rangeStart + step * Double(index), confidence: nil))
            }
        }
        return (incoming, runLog)
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
    private var buffersFed = 0
    private var firstHost: TimeInterval?
    private var finished = false

    init(analyzerFormat: AVAudioFormat, continuation: AsyncStream<AnalyzerInput>.Continuation) {
        self.analyzerFormat = analyzerFormat
        self.continuation = continuation
    }

    var level: Float { lock.withLock { currentLevel } }

    /// Buffers and seconds of audio fed to the analyser so far.
    var fed: (buffers: Int, seconds: TimeInterval) {
        lock.withLock { (buffersFed, Double(framesFed) / analyzerFormat.sampleRate) }
    }

    func feed(_ buffer: AVAudioPCMBuffer, hostTime: TimeInterval) {
        let level = Self.rms(buffer)
        guard let output = convert(buffer) else {
            lock.withLock { currentLevel = level }
            return
        }
        let isFinished: Bool = lock.withLock {
            currentLevel = level
            if firstHost == nil { firstHost = hostTime }
            anchors.append((Double(framesFed) / analyzerFormat.sampleRate, hostTime))
            buffersFed += 1
            if anchors.count > 4000 { anchors.removeFirst(anchors.count - 4000) }
            framesFed += AVAudioFramePosition(output.frameLength)
            return finished
        }
        guard !isFinished else { return }
        // No timestamp: the analyser then takes the audio as contiguous, which it is, and
        // its timeline matches `framesFed`. Stamping each buffer risked "audio input
        // timestamp overlaps or precedes prior audio input", which ends the results.
        continuation.yield(AnalyzerInput(buffer: output))
    }

    func finish() {
        lock.withLock { finished = true }
        continuation.finish()
    }

    /// Host time of the first buffer fed.
    var firstHostTime: TimeInterval? { lock.withLock { firstHost } }

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
