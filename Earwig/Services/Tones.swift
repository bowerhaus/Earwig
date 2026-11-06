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

    /// The tones in the player's format.
    static func buffer(format: AVAudioFormat = VoiceRenderer.outputFormat) -> AVAudioPCMBuffer? {
        let samples = samples(sampleRate: format.sampleRate)
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
