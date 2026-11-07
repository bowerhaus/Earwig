import AVFoundation

/// A take's audio, loaded before it starts: the step's phrases by phrase index, the slate and
/// the tones (plan 004, decision 9).
struct TakeAudio {
    struct Phrase {
        var kind: PhraseKind
        var buffer: AVAudioPCMBuffer
        /// A sound started with the phrase on the tone channel and left to ring on past its end:
        /// the chime for a direction, whose `buffer` is then the short hold the voice waits for.
        var ring: AVAudioPCMBuffer? = nil
    }

    var phrases: [Phrase]
    var slate: AVAudioPCMBuffer?
    var tones: AVAudioPCMBuffer
}

/// Turns the follow engine's commands into sound and sound back into its events (PRD §5.2,
/// §7.2; plan 004, decisions 8 to 10). A spoken phrase plays on the voice channel at the
/// engine's speed; a cue phrase and the slate on the cue channel at 1.0x; the tones on their own.
/// Progress is reported where the presenter hears the voice, the output latency allowed for.
@MainActor
final class Player {
    /// How far ahead on the audio clock the tones are scheduled, so the first is not clipped.
    static let toneLeadIn: TimeInterval = 0.05

    private let output: PlayerOutput
    private let audio: TakeAudio
    /// The phrase playing and its channel, if any.
    private(set) var current: (phrase: Int, channel: AudioChannel)?

    /// Events for the engine: a phrase's end, the slate's, the tones', each when its last sample
    /// has gone to the output, so what follows plays on with no gap in the ear.
    var onEvent: ((FollowEvent) -> Void)?
    /// One-line descriptions for the console.
    var onLog: ((String) -> Void)?

    init(output: PlayerOutput, audio: TakeAudio) {
        self.output = output
        self.audio = audio
    }

    func handle(_ commands: [FollowCommand]) {
        for command in commands { handle(command) }
    }

    func handle(_ command: FollowCommand) {
        switch command {
        case .play(let phrase, let speed):
            play(phrase: phrase, speed: speed)
        case .setSpeed(let speed):
            output.speed = speed
        case .stopVoice:
            stopVoice()
        case .playCue(.slate):
            stopVoice()
            guard let slate = audio.slate else {
                onEvent?(.cueEnded)
                return
            }
            start(slate, on: .cue) { [weak self] in self?.onEvent?(.cueEnded) }
        case .playTones:
            output.stop(.tone)
            start(audio.tones, on: .tone, delay: Self.toneLeadIn) { [weak self] in self?.onEvent?(.tonesEnded) }
        case .finished:
            break
        }
    }

    /// Stops everything, tones included: the take is over.
    func stopAll() {
        stopVoice()
        output.stop(.tone)
    }

    /// Where the voice is as the presenter hears it, for the engine's tick: the rendered offset
    /// less the output latency at the current speed, never below zero. `nil` with no phrase.
    func progress() -> FollowEvent? {
        guard let current, let rendered = output.position(of: current.channel) else { return nil }
        let speed = current.channel == .voice ? output.speed : 1
        return .voiceProgress(phrase: current.phrase, offset: max(0, rendered - output.outputLatency * speed))
    }

    private func play(phrase: Int, speed: Double) {
        guard audio.phrases.indices.contains(phrase) else {
            onLog?("player: no audio for phrase \(phrase)")
            return
        }
        stopVoice()
        let item = audio.phrases[phrase]
        let channel: AudioChannel = item.kind == .cue ? .cue : .voice
        if channel == .voice { output.speed = speed }
        if let ring = item.ring {
            output.stop(.tone)
            start(ring, on: .tone) {}
        }
        current = (phrase, channel)
        start(item.buffer, on: channel) { [weak self] in
            guard let self else { return }
            if self.current?.phrase == phrase { self.current = nil }
            self.onEvent?(.phraseEnded(phrase))
        }
    }

    private func stopVoice() {
        output.stop(.voice)
        output.stop(.cue)
        current = nil
    }

    private func start(_ buffer: AVAudioPCMBuffer, on channel: AudioChannel, delay: TimeInterval = 0, completion: @escaping @MainActor () -> Void) {
        do {
            try output.play(buffer, on: channel, delay: delay, completion: completion)
        } catch {
            onLog?("player: \(channel) failed to play: \(error.localizedDescription)")
        }
    }
}
