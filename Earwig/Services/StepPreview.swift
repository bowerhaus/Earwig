import Foundation
import Observation

/// Listen: plays a step straight through, never waiting, so the renderer, the player, the cue
/// voice, the slate and the tones can be heard together before anything listens (plan 004,
/// decision 13). The word the voice is saying is tracked from the player's progress, as the
/// engine will see it.
@MainActor
@Observable
final class StepPreview: Identifiable {
    enum Status: Equatable {
        case idle
        case preparing
        case slate
        case tones
        case speaking
        case finished
        case failed(String)
    }

    static let speeds = [0.85, 1.0, 1.2]

    private(set) var status: Status = .idle
    /// The phrase the voice is in, and the word it is saying as a flat index.
    private(set) var phrase: Int?
    private(set) var word: Int?
    /// The voice's speed; a change applies at once.
    var speed = 1.0 {
        didSet { player?.handle(.setSpeed(speed)) }
    }

    let phraseList: PhraseList
    private(set) var script: FollowScript

    @ObservationIgnored private let renderer: ScriptRenderer
    @ObservationIgnored private let slateText: String
    /// With cues off, inline directions are not read (PRD §4.2).
    @ObservationIgnored private let cuesOn: Bool
    @ObservationIgnored private let session = AudioSessionManager()
    @ObservationIgnored private let host = AudioEngineHost()
    @ObservationIgnored private var player: Player?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    /// When the current phrase was started, for the gap log.
    @ObservationIgnored private var phraseStartedAt: TimeInterval = 0
    @ObservationIgnored private var lastEndedAt: TimeInterval?

    init(phraseList: PhraseList, renderer: ScriptRenderer, slateText: String, cuesOn: Bool) {
        self.phraseList = phraseList
        self.renderer = renderer
        self.slateText = slateText
        self.cuesOn = cuesOn
        script = FollowScript(phraseList: phraseList)
    }

    var isPlaying: Bool {
        switch status {
        case .preparing, .slate, .tones, .speaking: true
        default: false
        }
    }

    func start() async {
        guard !isPlaying else { return }
        status = .preparing
        phrase = nil
        word = nil
        session.onEvent = { Log.event($0) }
        host.onEvent = { Log.event($0) }
        guard let rendered = renderer.rendered(phraseList) else {
            status = .failed("The step is not rendered yet.")
            return
        }
        do {
            try session.configure()
            try host.start()
            let slate = try await renderer.renderCue(slateText)
            // Stopped (or the sheet dismissed) while the slate rendered.
            guard status == .preparing else { return }
            guard let tones = Tones.buffer() else { throw VoiceRenderer.RenderError.conversion }
            script = FollowScript(phraseList: phraseList) { index in
                PhraseTiming(phrase: rendered[index].phrase, tokenStarts: rendered[index].tokenStarts, duration: rendered[index].duration)
            }
            let audio = TakeAudio(
                phrases: zip(phraseList.phrases, rendered).map { TakeAudio.Phrase(kind: $0.kind, buffer: $1.buffer) },
                slate: slate.buffer,
                tones: tones
            )
            let player = Player(output: host, audio: audio)
            player.onEvent = { [weak self] in self?.handle($0) }
            player.onLog = { Log.event($0) }
            self.player = player
            Log.event("listen: \(phraseList.phrases.count) phrases at \(speed)x, slate “\(slateText)”")
            status = .slate
            player.handle(.playCue(.slate))
            startTicking()
        } catch {
            status = .failed(error.localizedDescription)
            Log.event("listen failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard player != nil || status == .preparing else { return }
        ticker?.cancel()
        ticker = nil
        player?.stopAll()
        player = nil
        host.stop()
        session.deactivate()
        if isPlaying { status = .idle }
        phrase = nil
        word = nil
    }

    private func handle(_ event: FollowEvent) {
        switch event {
        case .cueEnded:
            status = .tones
            player?.handle(.playTones)
        case .tonesEnded:
            if let first = next(after: -1) { play(first) } else { finish() }
        case .phraseEnded(let ended):
            let now = HostClock.now
            let expected = script.phrases[ended].duration / (script.phrases[ended].kind == .cue ? 1 : speed)
            Log.event(String(format: "listen: phrase %d ended %.0f ms after its length (%.2f s)", ended + 1, (now - phraseStartedAt - expected) * 1000, expected))
            lastEndedAt = now
            if let next = next(after: ended) { play(next) } else { finish() }
        default:
            break
        }
    }

    /// The next phrase to play: every one in order, cues only when they are on.
    private func next(after index: Int) -> Int? {
        script.phrases.indices.first { $0 > index && (cuesOn || script.phrases[$0].kind == .spoken) }
    }

    private func finish() {
        status = .finished
        ticker?.cancel()
        phrase = nil
        word = nil
        Log.event("listen: finished")
    }

    private func play(_ index: Int) {
        status = .speaking
        phrase = index
        word = script.phrases[index].kind == .cue ? nil : script.firstWord[index]
        phraseStartedAt = HostClock.now
        if let lastEndedAt {
            Log.event(String(format: "listen: phrase %d started %.1f ms after the last ended", index + 1, (phraseStartedAt - lastEndedAt) * 1000))
        }
        player?.handle(.play(phrase: index, speed: speed))
    }

    /// Polls the player about twenty times a second, as the take host will tick the engine.
    private func startTicking() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self else { return }
                if case .voiceProgress(let phrase, let offset)? = self.player?.progress() {
                    self.phrase = phrase
                    self.word = self.script.word(in: phrase, at: offset)
                }
            }
        }
    }
}
