import Foundation
import Observation

/// Settings' Preview (plan 012, decision 2): the sample's first phrase in the presenter's voice at
/// the voice speed, through whatever the route is, rendered and played as a take plays its voice
/// (the renderer, then the voice channel's time-pitch node at the speed).
@MainActor
@Observable
final class VoicePreview {
    private(set) var isPlaying = false
    private(set) var problem: String?

    @ObservationIgnored private let session = AudioSessionManager()
    @ObservationIgnored private let audio = AudioEngineHost()
    /// Bumped by every `play` and `stop`, so a render finishing after Stop plays nothing.
    @ObservationIgnored private var generation = 0

    init() {
        session.onEvent = { Log.event($0) }
        audio.onEvent = { Log.event($0) }
    }

    func play(with renderer: ScriptRenderer, speed: Double) async {
        stop()
        generation += 1
        let generation = generation
        isPlaying = true
        problem = nil
        do {
            let rendered = try await renderer.renderPresenter(ListeningCheck.testPhrase)
            guard generation == self.generation else { return }
            try session.configure()
            audio.speed = speed
            Log.event("preview: \(renderer.voices?.presenter.displayName ?? "no voice") at \(speed)x on \(session.route.summary)")
            try audio.play(rendered.buffer, on: .voice, delay: 0) { [weak self] in
                // `.dataRendered` is before the earpiece has played the end: wait out the output
                // latency before stopping the engine, or the last word is clipped (review C2).
                guard let self, generation == self.generation else { return }
                let tail = self.audio.outputLatency + 0.2
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(tail))
                    guard let self, generation == self.generation else { return }
                    self.stop()
                }
            }
        } catch {
            guard generation == self.generation else { return }
            problem = error.localizedDescription
            Log.event("preview failed: \(error.localizedDescription)")
            stop()
        }
    }

    func stop() {
        generation += 1
        guard isPlaying else { return }
        isPlaying = false
        audio.stop()
        session.deactivate()
    }
}
