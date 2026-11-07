import AVFoundation

/// The three start tones (PRD §4.5; plan 004, decision 7): one buffer, so the beats are
/// sample-exact, padded with silence to the fourth beat, where phrase 1 starts.
enum Tones {
    static let beats = 3
    static let frequency = 1_000.0
    static let beepLength = 0.12
    /// From the start of one beep to the next, and from the last to phrase 1.
    static let spacing = 0.6
    /// Fade in and out, so a beep does not click.
    static let fade = 0.005
    /// About −12 dBFS.
    static let amplitude: Float = 0.25

    /// The whole of the tones: three beats of `spacing`.
    static var duration: TimeInterval { Double(beats) * spacing }

    static func samples(sampleRate: Double) -> [Float] {
        let total = Int((duration * sampleRate).rounded())
        let beepFrames = Int((beepLength * sampleRate).rounded())
        let fadeFrames = max(Int((fade * sampleRate).rounded()), 1)
        var samples = [Float](repeating: 0, count: total)
        for beat in 0..<beats {
            let start = Int((Double(beat) * spacing * sampleRate).rounded())
            for frame in 0..<beepFrames where start + frame < total {
                let envelope = min(1, Double(frame) / Double(fadeFrames), Double(beepFrames - 1 - frame) / Double(fadeFrames))
                let phase = 2 * Double.pi * frequency * Double(frame) / sampleRate
                samples[start + frame] = amplitude * Float(envelope * sin(phase))
            }
        }
        return samples
    }

    /// The chime for an inline direction in `.chime` mode (device check 2: "an elongated low
    /// ping or pong"): a low, soft bell that rings on under the next line. The voice waits only
    /// `hold` for it, so the take is not held up for its length.
    enum Chime {
        static let length = 0.8
        /// How long after the chime starts the voice carries on.
        static let hold = 0.25
        /// D4 and two partials, falling away.
        static let frequencies = [293.7, 587.3, 880.0]
        /// About −14 dBFS at its peak: louder than first tried (device check: "slightly louder").
        static let amplitude: Float = 0.2
        static let attack = 0.006
        /// The decay's time constant.
        static let decay = 0.22

        static func samples(sampleRate: Double) -> [Float] {
            let total = Int((length * sampleRate).rounded())
            let attackFrames = max(Int((attack * sampleRate).rounded()), 1)
            let fadeFrames = max(Int((Tones.fade * sampleRate).rounded()), 1)
            let weights = frequencies.indices.map { 1 / Double($0 * $0 + 1) }
            let totalWeight = weights.reduce(0, +)
            return (0..<total).map { frame in
                let time = Double(frame) / sampleRate
                let envelope = min(1, Double(frame) / Double(attackFrames), Double(total - 1 - frame) / Double(fadeFrames)) * exp(-time / decay)
                let tone = zip(frequencies, weights).reduce(0.0) { sum, partial in
                    sum + partial.1 * sin(2 * Double.pi * partial.0 * time)
                } / totalWeight
                return amplitude * Float(envelope * tone)
            }
        }

        static func buffer(format: AVAudioFormat = VoiceRenderer.outputFormat) -> AVAudioPCMBuffer? {
            Tones.buffer(samples(sampleRate: format.sampleRate), format: format)
        }

        /// Silence as long as `hold`: what the voice waits for, in place of the direction.
        static func holdBuffer(format: AVAudioFormat = VoiceRenderer.outputFormat) -> AVAudioPCMBuffer? {
            Tones.buffer([Float](repeating: 0, count: Int((hold * format.sampleRate).rounded())), format: format)
        }
    }

    /// The tones in the player's format.
    static func buffer(format: AVAudioFormat = VoiceRenderer.outputFormat) -> AVAudioPCMBuffer? {
        buffer(samples(sampleRate: format.sampleRate), format: format)
    }

    private static func buffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channels = buffer.floatChannelData else { return nil }
        for channel in 0..<Int(format.channelCount) {
            samples.withUnsafeBufferPointer { source in
                channels[channel].update(from: source.baseAddress!, count: samples.count)
            }
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        return buffer
    }
}
