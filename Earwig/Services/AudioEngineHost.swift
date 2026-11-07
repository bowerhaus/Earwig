import AVFoundation

/// Where a buffer plays (plan 004, decision 8).
enum AudioChannel: CaseIterable, Sendable {
    /// Phrases in the presenter's voice, through the time-pitch node at the engine's speed.
    case voice
    /// Cue phrases and the slate, at 1.0x.
    case cue
    /// The start tones, at 1.0x.
    case tone
}

/// The player's audio work, behind a protocol so the player's logic is tested with a fake
/// (plan 004, decision 9). The real one is `AudioEngineHost`.
@MainActor
protocol PlayerOutput: AnyObject {
    /// Plays a buffer from its start, `delay` seconds from now on the audio clock. `completion`
    /// runs when its last sample has gone to the output (heard the output latency later), unless
    /// the channel was stopped or given another buffer first.
    func play(_ buffer: AVAudioPCMBuffer, on channel: AudioChannel, delay: TimeInterval, completion: @escaping @MainActor () -> Void) throws
    func stop(_ channel: AudioChannel)
    /// Seconds of the channel's current buffer rendered so far, in the buffer's own time (before
    /// any speed change); `nil` when it is not playing.
    func position(of channel: AudioChannel) -> TimeInterval?
    /// The voice channel's speed; 1.0 is as rendered.
    var speed: Double { get set }
    /// How long after rendering a sample is heard: the route's output latency and IO buffer.
    var outputLatency: TimeInterval { get }
}

/// One `AVAudioEngine` for a take (PRD §7.2, "Player"): the voice through a time-pitch node, so
/// a change of speed keeps its pitch; the cue and tone nodes straight to the mixer; and the
/// built-in mic tapped for the listener on the same engine.
@MainActor
final class AudioEngineHost: PlayerOutput {
    private let engine = AVAudioEngine()
    private let nodes: [AudioChannel: AVAudioPlayerNode]
    private let timePitch = AVAudioUnitTimePitch()
    private var micTapInstalled = false
    private var micBlock: (@Sendable (AVAudioPCMBuffer, TimeInterval) -> Void)?
    /// Removed in `deinit`, which is not on the main actor.
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    /// Whether the engine should be running: started and not stopped. A configuration change
    /// stops it, and it is restarted if so, mic tap or not.
    private var wanted = false

    /// Called with a one-line description of engine events (configuration changes, restarts).
    var onEvent: ((String) -> Void)?
    /// Bumped on every `play` and `stop` of a channel, so a stale completion is ignored.
    private var tokens: [AudioChannel: Int] = [:]
    private(set) var outputLatency: TimeInterval = 0

    init() {
        nodes = Dictionary(uniqueKeysWithValues: AudioChannel.allCases.map { ($0, AVAudioPlayerNode()) })
        let format = VoiceRenderer.outputFormat
        for node in nodes.values { engine.attach(node) }
        engine.attach(timePitch)
        engine.connect(nodes[.voice]!, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
        engine.connect(nodes[.cue]!, to: engine.mainMixerNode, format: format)
        engine.connect(nodes[.tone]!, to: engine.mainMixerNode, format: format)
        let centre = NotificationCenter.default
        // The engine stops itself when the hardware configuration changes (a route change,
        // a sample-rate change). Restart it and the mic tap, or listening goes silent.
        observers.append(centre.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.configurationChanged() }
        })
        observers.append(centre.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.readLatency() }
        })
        readLatency()
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    private func configurationChanged() {
        let wasRunning = engine.isRunning
        readLatency()
        guard let micBlock, micTapInstalled else {
            // Playback alone: restart the engine so the next buffer plays. A buffer cut off by
            // the change is not resumed; in a take the engine re-anchors (stage 5).
            guard wanted else {
                onEvent?("engine configuration changed (running \(wasRunning)); not wanted, left stopped")
                return
            }
            do {
                try start()
                onEvent?("engine configuration changed (running \(wasRunning)); restarted for playback")
            } catch {
                onEvent?("engine configuration changed; restart failed: \(error.localizedDescription)")
            }
            return
        }
        do {
            try installMicTap(micBlock)
            onEvent?("engine configuration changed (running \(wasRunning)); restarted with mic \(Int(micFormat.sampleRate)) Hz")
        } catch {
            onEvent?("engine configuration changed; restart failed: \(error.localizedDescription)")
        }
    }

    /// The output latency as the session reports it for the current route (decision 10).
    private func readLatency(always: Bool = false) {
        let session = AVAudioSession.sharedInstance()
        let latency = session.outputLatency + session.ioBufferDuration
        guard always || abs(latency - outputLatency) > 0.000_5 else { return }
        outputLatency = latency
        let output = session.currentRoute.outputs.map { "\($0.portName) (\(AudioRoute.label($0.portType.rawValue)))" }.joined(separator: ", ")
        onEvent?(String(format: "output latency %.0f ms (%.0f ms route + %.0f ms buffer) on %@",
                        latency * 1000, session.outputLatency * 1000, session.ioBufferDuration * 1000, output))
    }

    var isRunning: Bool { engine.isRunning }

    var speed: Double {
        get { Double(timePitch.rate) }
        set { timePitch.rate = Float(newValue) }
    }

    func start() throws {
        wanted = true
        guard !engine.isRunning else { return }
        engine.prepare()
        try engine.start()
        readLatency(always: true)
    }

    func stop() {
        wanted = false
        for channel in AudioChannel.allCases { stop(channel) }
        removeMicTap()
        engine.stop()
    }

    func play(_ buffer: AVAudioPCMBuffer, on channel: AudioChannel, delay: TimeInterval, completion: @escaping @MainActor () -> Void) throws {
        try start()
        let node = nodes[channel]!
        node.stop()
        let token = (tokens[channel] ?? 0) + 1
        tokens[channel] = token
        // `.dataRendered`: the end is when the last sample has gone to the output, not when it
        // is heard. The next buffer then follows it with no gap in the ear, as both reach the
        // earpiece the same output latency later; `.dataPlayedBack` waited out the latency
        // (356 ms on the SK18) and added it between every two phrases (device check 2).
        node.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataRendered) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.tokens[channel] == token else { return }
                completion()
            }
        }
        if delay > 0 {
            node.play(at: AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: delay)))
        } else {
            node.play()
        }
    }

    func stop(_ channel: AudioChannel) {
        tokens[channel] = (tokens[channel] ?? 0) + 1
        nodes[channel]?.stop()
    }

    func position(of channel: AudioChannel) -> TimeInterval? {
        guard let node = nodes[channel], node.isPlaying,
              let nodeTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: nodeTime) else { return nil }
        return max(0, Double(playerTime.sampleTime) / playerTime.sampleRate)
    }

    // MARK: - Microphone

    var micFormat: AVAudioFormat { engine.inputNode.outputFormat(forBus: 0) }

    /// Taps the input node. The block runs on the audio thread with each buffer and the host
    /// time in seconds of its first sample.
    func installMicTap(_ block: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void) throws {
        removeMicTap()
        // The input node joins the graph on first use; restart so its format is current.
        for channel in AudioChannel.allCases { stop(channel) }
        engine.stop()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, when in
            let host = when.isHostTimeValid ? AVAudioTime.seconds(forHostTime: when.hostTime) : HostClock.now
            block(buffer, host)
        }
        micTapInstalled = true
        micBlock = block
        try start()
    }

    func removeMicTap() {
        guard micTapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        micTapInstalled = false
        micBlock = nil
    }
}

/// Host time in seconds, the clock the audio engine stamps buffers with and the follow
/// engine's clock (plan 004, decision 11).
enum HostClock {
    static var now: TimeInterval { AVAudioTime.seconds(forHostTime: mach_absolute_time()) }
}
