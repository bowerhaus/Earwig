import AVFoundation
@testable import Earwig
import Testing

@MainActor
struct VoiceRendererTests {

    @Test(.timeLimit(.minutes(1)))
    func rendersAPhraseWithWordTimings() async throws {
        let voice = try #require(AVSpeechSynthesisVoice(language: "en-GB") ?? AVSpeechSynthesisVoice(language: "en-US"))
        let phrase = try #require(PhraseSplitter().phrases(in: "The kettle is on, and the toast is nearly done.").first)
        let rendered = try await VoiceRenderer().render(phrase, index: 0, voice: voice, rate: AVSpeechUtteranceDefaultSpeechRate)

        #expect(rendered.buffer.format == VoiceRenderer.outputFormat)
        #expect(rendered.duration > 1 && rendered.duration < 10)
        let starts = rendered.tokenStarts.compactMap { $0 }
        #expect(starts.count == phrase.tokens.count)
        #expect(starts == starts.sorted())
        #expect((starts.last ?? 0) < rendered.duration)
    }
}
