import AVFoundation

/// A phrase rendered in one voice (PRD §3, "Rendering"): its audio in the player's format and
/// the start time of each of its tokens.
struct RenderedPhrase: @unchecked Sendable {
    let phraseIndex: Int
    let phrase: Phrase
    let voiceIdentifier: String
    /// Mono float audio at `VoiceRenderer.outputFormat`.
    let buffer: AVAudioPCMBuffer
    /// Seconds from the phrase's start to each token's start, from the synthesiser's word
    /// markers. `nil` for a token no marker named.
    let tokenStarts: [TimeInterval?]
    /// How the markers' `byteSampleOffset` had to be read to fall inside the audio.
    let markerUnit: MarkerUnit
    /// Where the word markers came from: the `write` marker callback, the `willSpeakMarker`
    /// delegate, both or neither. On the iOS 26.5 simulator only the delegate sends them.
    let markerSource: String
    let renderSeconds: TimeInterval
    let sourceFormat: String

    var duration: TimeInterval { Double(buffer.frameLength) / buffer.format.sampleRate }
    var realTimeFactor: Double { duration > 0 ? renderSeconds / duration : 0 }

    enum MarkerUnit: String, Sendable {
        case samples, bytes, none
    }
}

/// Renders phrases to audio with word timings through `AVSpeechSynthesizer.write`, one at a
/// time (PRD §4.2, §7.2). The audio is converted to one fixed format so the player never has
/// to reconnect when the voice changes.
@MainActor
final class VoiceRenderer: NSObject {
    nonisolated static let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!

    private let synthesizer = AVSpeechSynthesizer()
    private var job: RenderJob?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// The render in flight, so the next waits for it: the synthesiser and `job` are shared.
    private var tail: Task<Void, Never>?

    /// Renders one phrase. `rate` is an `AVSpeechUtterance` rate (0 to 1, default 0.5). Calls
    /// run one at a time, in order, whoever makes them.
    func render(_ phrase: Phrase, index: Int, voice: AVSpeechSynthesisVoice, rate: Float) async throws -> RenderedPhrase {
        let previous = tail
        let task = Task { @MainActor in
            await previous?.value
            return try await self.renderNow(phrase, index: index, voice: voice, rate: rate)
        }
        tail = Task { _ = await task.result }
        return try await task.value
    }

    private func renderNow(_ phrase: Phrase, index: Int, voice: AVSpeechSynthesisVoice, rate: Float) async throws -> RenderedPhrase {
        let utterance = AVSpeechUtterance(string: phrase.text)
        utterance.voice = voice
        utterance.rate = rate
        let job = RenderJob(utterance: utterance)
        self.job = job
        let started = Date()

        let chunks: [AVAudioPCMBuffer] = await withCheckedContinuation { continuation in
            job.onFinish = { continuation.resume(returning: $0) }
            synthesizer.write(utterance, toBufferCallback: { buffer in
                job.received(buffer)
            }, toMarkerCallback: { markers in
                job.received(markers)
            })
            job.armTimeout(seconds: 60)
        }
        let renderSeconds = Date().timeIntervalSince(started)
        if self.job === job { self.job = nil }

        guard let first = chunks.first else { throw RenderError.noAudio(phrase.text) }
        let sourceFormat = first.format
        let joined = try Self.concatenate(chunks)
        let converted = try Self.convert(joined)
        let sourceFrames = Double(joined.frameLength)
        let sourceRate = sourceFormat.sampleRate
        let bytesPerFrame = Double(sourceFormat.streamDescription.pointee.mBytesPerFrame)

        // Word markers: read the offset as samples if that fits the audio, else as bytes.
        let fromCallback = job.markers.filter { $0.mark == .word }
        let fromDelegate = job.delegateMarkers.filter { $0.mark == .word }
        let words = fromCallback.isEmpty ? fromDelegate : fromCallback
        let markerSource = switch (fromCallback.isEmpty, fromDelegate.isEmpty) {
        case (false, false): "both"
        case (false, true): "callback"
        case (true, false): "delegate"
        case (true, true): "none"
        }
        let maxOffset = Double(words.map(\.byteSampleOffset).max() ?? 0)
        let unit: RenderedPhrase.MarkerUnit = words.isEmpty ? .none : (maxOffset <= sourceFrames ? .samples : .bytes)
        var tokenStarts = [TimeInterval?](repeating: nil, count: phrase.tokens.count)
        for marker in words {
            guard let token = phrase.tokenIndex(containing: marker.textRange.location), tokenStarts[token] == nil else { continue }
            let frames = unit == .bytes ? Double(marker.byteSampleOffset) / max(bytesPerFrame, 1) : Double(marker.byteSampleOffset)
            tokenStarts[token] = frames / sourceRate
        }

        return RenderedPhrase(
            phraseIndex: index,
            phrase: phrase,
            voiceIdentifier: voice.identifier,
            buffer: converted,
            tokenStarts: tokenStarts,
            markerUnit: unit,
            markerSource: markerSource,
            renderSeconds: renderSeconds,
            sourceFormat: "\(Int(sourceRate)) Hz \(sourceFormat.channelCount) ch \(Self.describe(sourceFormat.commonFormat))"
        )
    }

    func cancel() {
        synthesizer.stopSpeaking(at: .immediate)
        job?.finish()
    }

    enum RenderError: LocalizedError {
        case noAudio(String)
        case conversion

        var errorDescription: String? {
            switch self {
            case .noAudio(let text): "The voice produced no audio for “\(text)”."
            case .conversion: "The rendered audio could not be converted."
            }
        }
    }

    // MARK: - Audio plumbing

    nonisolated static func concatenate(_ chunks: [AVAudioPCMBuffer]) throws -> AVAudioPCMBuffer {
        let format = chunks[0].format
        let total = chunks.reduce(0) { $0 + $1.frameLength }
        guard let joined = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(total, 1)) else { throw RenderError.conversion }
        let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
        var offset = 0
        let destination = UnsafeMutableAudioBufferListPointer(joined.mutableAudioBufferList)
        for chunk in chunks where chunk.format == format {
            let source = UnsafeMutableAudioBufferListPointer(chunk.mutableAudioBufferList)
            let bytes = Int(chunk.frameLength) * bytesPerFrame
            for (index, buffer) in source.enumerated() where index < destination.count {
                guard let from = buffer.mData, let to = destination[index].mData else { continue }
                memcpy(to.advanced(by: offset), from, bytes)
            }
            offset += bytes
        }
        joined.frameLength = total
        return joined
    }

    nonisolated private static func convert(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        if buffer.format == outputFormat { return buffer }
        guard let converter = AVAudioConverter(from: buffer.format, to: outputFormat) else { throw RenderError.conversion }
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { throw RenderError.conversion }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .endOfStream
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }
        if status == .error || error != nil { throw error ?? RenderError.conversion }
        return output
    }

    nonisolated private static func describe(_ format: AVAudioCommonFormat) -> String {
        switch format {
        case .pcmFormatFloat32: "float32"
        case .pcmFormatInt16: "int16"
        case .pcmFormatInt32: "int32"
        case .pcmFormatFloat64: "float64"
        default: "other"
        }
    }
}

extension VoiceRenderer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeak marker: AVSpeechSynthesisMarker, utterance: AVSpeechUtterance) {
        MainActor.assumeIsolated {
            guard let job, job.utterance === utterance else { return }
            job.delegateMarkers.append(marker)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        MainActor.assumeIsolated {
            guard let job, job.utterance === utterance else { return }
            // The zero-length buffer is the real end of a write; this is the fallback.
            job.finish(after: 0.5)
        }
    }
}

/// The state of one `write` call. Buffer and marker callbacks may arrive on any thread.
private final class RenderJob: @unchecked Sendable {
    let utterance: AVSpeechUtterance
    var onFinish: (([AVAudioPCMBuffer]) -> Void)?
    var delegateMarkers: [AVSpeechSynthesisMarker] = []

    private let lock = NSLock()
    private var chunks: [AVAudioPCMBuffer] = []
    private var collectedMarkers: [AVSpeechSynthesisMarker] = []
    private var finished = false

    init(utterance: AVSpeechUtterance) {
        self.utterance = utterance
    }

    var markers: [AVSpeechSynthesisMarker] {
        lock.withLock { collectedMarkers }
    }

    func received(_ buffer: AVAudioBuffer) {
        guard let pcm = buffer as? AVAudioPCMBuffer else { return }
        if pcm.frameLength == 0 {
            finish()
            return
        }
        // Copy: the synthesiser may reuse its buffer between callbacks.
        guard let copy = try? VoiceRenderer.concatenate([pcm]) else { return }
        lock.withLock { chunks.append(copy) }
    }

    func received(_ markers: [AVSpeechSynthesisMarker]) {
        lock.withLock { collectedMarkers += markers }
    }

    func armTimeout(seconds: TimeInterval) {
        finish(after: seconds)
    }

    func finish(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.finish() }
    }

    func finish() {
        let result: [AVAudioPCMBuffer]? = lock.withLock {
            guard !finished else { return nil }
            finished = true
            return chunks
        }
        guard let result else { return }
        DispatchQueue.main.async { [onFinish] in onFinish?(result) }
    }
}
