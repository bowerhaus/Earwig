import AVFoundation
import Observation

/// Renders one phrase in one voice: `VoiceRenderer`, or a fake in tests.
@MainActor
protocol PhraseRendering: AnyObject {
    func render(_ phrase: Phrase, voiceIdentifier: String, rate: Float) async throws -> RenderedPhrase
}

extension VoiceRenderer: PhraseRendering {
    func render(_ phrase: Phrase, voiceIdentifier: String, rate: Float) async throws -> RenderedPhrase {
        guard let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) else {
            throw ScriptRenderer.RenderFailure.voiceMissing(voiceIdentifier)
        }
        return try await render(phrase, index: 0, voice: voice, rate: rate)
    }
}

/// Renders the step a take will start from, in memory, and keeps what it rendered while the
/// app runs (plan 004, decisions 1 to 3). Nothing is saved: with the downloaded voices a step
/// renders in a few seconds.
@MainActor
@Observable
final class ScriptRenderer {

    /// What the rendering row shows.
    enum State: Equatable {
        case idle
        case rendering(step: Int, done: Int, total: Int)
        case ready(step: Int)
        case failed(step: Int, message: String)
    }

    /// A rendered phrase is found again by its voice, rate and text, so an unchanged phrase is
    /// never rendered twice, whatever step or version of the script it is in.
    struct Key: Hashable {
        var voice: String
        var rate: Float
        var text: String
    }

    enum RenderFailure: LocalizedError {
        case noVoice
        case voiceMissing(String)

        var errorDescription: String? {
            switch self {
            case .noVoice: "No English voice is downloaded. \(VoiceCatalogue.downloadHint)"
            case .voiceMissing(let identifier): "The voice \(identifier) is no longer on this iPhone. \(VoiceCatalogue.downloadHint)"
            }
        }
    }

    private(set) var state: State = .idle
    /// The script the state is for, set as soon as a render is asked for.
    private(set) var target: AnyHashable?
    /// The voices in use, `nil` when there is no English voice.
    private(set) var voices: VoiceChoice?
    let rate: Float

    @ObservationIgnored private let renderer: PhraseRendering
    @ObservationIgnored private var cache: [Key: RenderedPhrase] = [:]
    @ObservationIgnored private var script: AnyHashable?
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Bumped by every `prepare` and `cancel`, so a superseded render stops.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored var onEvent: ((String) -> Void)?

    init(renderer: PhraseRendering, voices: VoiceChoice?, rate: Float = VoiceCatalogue.rate) {
        self.renderer = renderer
        self.voices = voices
        self.rate = rate
    }

    /// The app's renderer: `VoiceRenderer` with the default voices.
    static func live() -> ScriptRenderer {
        let installed = VoiceCatalogue.installed()
        let renderer = ScriptRenderer(renderer: VoiceRenderer(), voices: VoiceCatalogue.choose(from: installed, presenterID: AppSettings.presenterVoiceID))
        renderer.onEvent = { Log.event($0) }
        for voice in installed where voice.language.hasPrefix("en-GB") || voice.isPersonal {
            Log.event("voice: \(voice.displayName), \(voice.language), \(voice.gender), \(voice.identifier)")
        }
        Log.event("voices: presenter \(renderer.voices?.presenter.displayName ?? "none"), cue \(renderer.voices?.cue.displayName ?? "none")")
        return renderer
    }

    /// Changes the voices. What was rendered in the old ones is kept, by its key, for a change back.
    func use(_ voices: VoiceChoice?) {
        guard voices != self.voices else { return }
        self.voices = voices
        state = .idle
        onEvent?("voices: presenter \(voices?.presenter.displayName ?? "none"), cue \(voices?.cue.displayName ?? "none")")
    }

    /// Waits for the render `prepare` started, for tests.
    func finished() async {
        await task?.value
    }

    /// Phrases held in memory, for tests and the log.
    var cachedCount: Int { cache.count }

    /// The key a phrase of a kind is rendered under, or `nil` with no voice.
    func key(for stepPhrase: StepPhrase) -> Key? {
        guard let voices else { return nil }
        let voice = stepPhrase.kind == .cue ? voices.cue : voices.presenter
        return Key(voice: voice.identifier, rate: rate, text: stepPhrase.phrase.text)
    }

    /// Starts rendering a step of a script in the background, replacing any render under way.
    /// Opening another script lets the previous one's phrases go.
    func prepare(script id: AnyHashable, step: Int, phrases: PhraseList) {
        if target != id { state = .idle }
        target = id
        task?.cancel()
        task = Task { await render(script: id, step: step, phrases: phrases) }
    }

    /// Renders what a step is missing, in order, and returns when it is done, failed or was
    /// superseded.
    func render(script id: AnyHashable, step: Int, phrases: PhraseList) async {
        if target != id { state = .idle }
        target = id
        generation += 1
        let generation = generation
        if script != id {
            cache.removeAll()
            script = id
        }
        guard voices != nil else {
            state = .failed(step: step, message: RenderFailure.noVoice.localizedDescription)
            return
        }
        var seen = Set<Key>()
        let missing = phrases.phrases.compactMap { phrase -> (StepPhrase, Key)? in
            guard let key = key(for: phrase), cache[key] == nil, seen.insert(key).inserted else { return nil }
            return (phrase, key)
        }
        guard !missing.isEmpty else {
            state = .ready(step: step)
            return
        }
        state = .rendering(step: step, done: 0, total: missing.count)
        let started = HostClock.now
        var audioSeconds = 0.0
        var timed = 0
        var words = 0
        for (index, (phrase, key)) in missing.enumerated() {
            do {
                let rendered = try await renderer.render(phrase.phrase, voiceIdentifier: key.voice, rate: key.rate)
                guard generation == self.generation, !Task.isCancelled else { return }
                cache[key] = rendered
                audioSeconds += rendered.duration
                let wordTokens = zip(phrase.phrase.tokens, rendered.tokenStarts).filter { $0.0.word != nil }
                words += wordTokens.count
                timed += wordTokens.filter { $0.1 != nil }.count
                if index == 0 { onEvent?("render: markers from \(rendered.markerSource), \(rendered.sourceFormat)") }
                let quiet = Self.silence(in: rendered.buffer)
                onEvent?(String(format: "render: phrase %d silence %.0f ms before, %.0f ms after, of %.2f s: “%@”",
                                index + 1, quiet.lead * 1000, quiet.tail * 1000, rendered.duration, phrase.phrase.text))
            } catch {
                guard generation == self.generation else { return }
                state = .failed(step: step, message: error.localizedDescription)
                onEvent?("render failed: \(error.localizedDescription)")
                return
            }
            state = .rendering(step: step, done: index + 1, total: missing.count)
        }
        state = .ready(step: step)
        onEvent?(String(format: "render: step %d, %d phrases, %.1f s of audio in %.2f s, %d of %d words timed, %d phrases held",
                        step + 1, missing.count, audioSeconds, HostClock.now - started, timed, words, cache.count))
    }

    /// The silence at a buffer's start and end, in seconds: samples below about −50 dBFS.
    static func silence(in buffer: AVAudioPCMBuffer, threshold: Float = 0.003) -> (lead: TimeInterval, tail: TimeInterval) {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return (0, 0) }
        let count = Int(buffer.frameLength)
        let rate = buffer.format.sampleRate
        let first = (0..<count).first { abs(samples[$0]) > threshold } ?? count
        let last = (0..<count).last { abs(samples[$0]) > threshold } ?? -1
        return (Double(first) / rate, Double(count - 1 - max(last, first - 1)) / rate)
    }

    /// Stops a render under way. The row goes back to idle.
    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        state = .idle
    }

    /// A step's rendered phrases by phrase index, or `nil` if any is not rendered.
    func rendered(_ phrases: PhraseList) -> [RenderedPhrase]? {
        var result: [RenderedPhrase] = []
        for phrase in phrases.phrases {
            guard let key = key(for: phrase), let rendered = cache[key] else { return nil }
            result.append(rendered)
        }
        return result
    }

    /// Renders text now in the presenter's voice, without keeping it: the Listening check's
    /// Say Test (plan 005, decision 12).
    func renderPresenter(_ text: String) async throws -> RenderedPhrase {
        guard let voices else { throw RenderFailure.noVoice }
        return try await renderer.render(Phrase(tokens: text.split(whereSeparator: \.isWhitespace).map(String.init)), voiceIdentifier: voices.presenter.identifier, rate: rate)
    }

    /// Renders a cue now, in the cue voice, without keeping it: the slate (decision 6).
    func renderCue(_ text: String) async throws -> RenderedPhrase {
        guard let voices else { throw RenderFailure.noVoice }
        return try await renderer.render(Phrase(tokens: text.split(whereSeparator: \.isWhitespace).map(String.init)), voiceIdentifier: voices.cue.identifier, rate: rate)
    }
}

/// One-line events for the console, read live from the phone with `devicectl --console`, each
/// with the seconds since the first event, so the device check can time what happened.
enum Log {
    private static let start = HostClock.now

    static func event(_ text: String) {
        print(String(format: "Earwig: %8.2f ", HostClock.now - start) + text)
    }
}
