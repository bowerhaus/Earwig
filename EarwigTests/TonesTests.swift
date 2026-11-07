@testable import Earwig
import Testing

struct TonesTests {

    private let rate = 48_000.0

    @Test func threeBeepsPaddedToTheFourthBeat() {
        let samples = Tones.samples(sampleRate: rate)
        #expect(samples.count == Int((Tones.duration * rate).rounded()))
        #expect(abs(Tones.duration - 1.8) < 1e-9)
        // Sound inside each beep, silence between them and after the last.
        for beat in 0..<3 {
            let start = Int(Double(beat) * Tones.spacing * rate)
            let beep = samples[start..<(start + Int(Tones.beepLength * rate))]
            #expect(beep.map(abs).max()! > 0.2)
            let gap = samples[(start + Int(Tones.beepLength * rate) + 1)..<(start + Int(Tones.spacing * rate))]
            #expect(gap.allSatisfy { $0 == 0 })
        }
        #expect(samples.map(abs).max()! <= Tones.amplitude)
    }

    @Test func eachBeepFadesInAndOut() {
        let samples = Tones.samples(sampleRate: rate)
        let beepFrames = Int(Tones.beepLength * rate)
        let fadeFrames = Int(Tones.fade * rate)
        for beat in 0..<3 {
            let start = Int(Double(beat) * Tones.spacing * rate)
            #expect(samples[start] == 0)
            #expect(abs(samples[start + beepFrames - 1]) < 1e-6)
            // Within the fade the level never exceeds the envelope.
            #expect((0..<fadeFrames).allSatisfy { abs(samples[start + $0]) <= Tones.amplitude * Float($0) / Float(fadeFrames) + 1e-6 })
        }
    }

    @Test func theChimeIsShortSoftAndClickFree() throws {
        let samples = Tones.Chime.samples(sampleRate: rate)
        #expect(samples.count == Int((Tones.Chime.length * rate).rounded()))
        #expect(samples.first == 0)
        #expect(abs(samples.last!) < 1e-6)
        let peak = samples.map(abs).max()!
        #expect(peak > 0.05 && peak <= Tones.Chime.amplitude)
        #expect(try #require(Tones.Chime.buffer()).format == VoiceRenderer.outputFormat)
    }

    @Test func theBufferIsInThePlayersFormat() throws {
        let buffer = try #require(Tones.buffer())
        #expect(buffer.format == VoiceRenderer.outputFormat)
        #expect(Int(buffer.frameLength) == Int((Tones.duration * VoiceRenderer.outputFormat.sampleRate).rounded()))
    }
}
