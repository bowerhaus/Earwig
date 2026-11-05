import AVFoundation

/// One `AVAudioEngine` for a take (PRD §7.2, "Player"): rendered phrases play through a
/// time-pitch node, so a change of speed keeps the voice's pitch, and the built-in mic is
/// tapped for the listener on the same engine.
@MainActor
final class AudioEngineHost {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private var micTapInstalled = false
    /// Bumped on every `play` and `stopPhrase`, so a stale completion is ignored.
    private var playToken = 0

    init() {
        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: VoiceRenderer.outputFormat)
        engine.connect(timePitch, to: engine.mainMixerNode, format: VoiceRenderer.outputFormat)
    }

    var isRunning: Bool { engine.isRunning }

    /// Playback speed, 1.0 is as rendered. The time-pitch node keeps the pitch.
    var speed: Float {
        get { timePitch.rate }
        set { timePitch.rate = newValue }
    }

    func start() throws {
        guard !engine.isRunning else { return }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        stopPhrase()
        removeMicTap()
        engine.stop()
    }

    /// Plays one buffer from its start. `completion` runs on the main actor when it has been
    /// heard to the end, unless another phrase was started or playback stopped first.
    func play(_ buffer: AVAudioPCMBuffer, completion: @escaping @MainActor () -> Void) throws {
        try start()
        player.stop()
        playToken += 1
        let token = playToken
        player.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playToken == token else { return }
                completion()
            }
        }
        player.play()
    }

    func stopPhrase() {
        playToken += 1
        player.stop()
    }

    /// Seconds of the current phrase's source audio played so far (before the speed change),
    /// for mapping to the rendered word timings.
    var phrasePosition: TimeInterval? {
        guard player.isPlaying,
              let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else { return nil }
        return max(0, Double(playerTime.sampleTime) / playerTime.sampleRate)
    }

    // MARK: - Microphone

    var micFormat: AVAudioFormat { engine.inputNode.outputFormat(forBus: 0) }

    /// Taps the input node. The block runs on the audio thread with each buffer and the host
    /// time in seconds of its first sample.
    func installMicTap(_ block: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void) throws {
        removeMicTap()
        // The input node joins the graph on first use; restart so its format is current.
        stopPhrase()
        engine.stop()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, when in
            let host = when.isHostTimeValid ? AVAudioTime.seconds(forHostTime: when.hostTime) : HostClock.now
            block(buffer, host)
        }
        micTapInstalled = true
        try start()
    }

    func removeMicTap() {
        guard micTapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        micTapInstalled = false
    }
}

/// Host time in seconds, the clock the audio engine stamps buffers with.
enum HostClock {
    static var now: TimeInterval { AVAudioTime.seconds(forHostTime: mach_absolute_time()) }
}
