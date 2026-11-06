import AVFoundation
@testable import Earwig
import Testing

/// A silent buffer of a length, in the player's format.
func silence(seconds: TimeInterval) -> AVAudioPCMBuffer {
    let format = VoiceRenderer.outputFormat
    let frames = AVAudioFrameCount(max(seconds * format.sampleRate, 1))
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = frames
    return buffer
}

/// Renders instantly, a word a third of a second, and records what it was asked for.
@MainActor
final class FakeRenderer: PhraseRendering {
    var calls: [(text: String, voice: String)] = []
    var failOn: String?
    /// Runs after each render, before it returns: a hook for cancelling mid-render.
    var afterRender: (() -> Void)?

    func render(_ phrase: Phrase, voiceIdentifier: String, rate: Float) async throws -> RenderedPhrase {
        calls.append((phrase.text, voiceIdentifier))
        if let failOn, phrase.text.contains(failOn) { throw VoiceRenderer.RenderError.noAudio(phrase.text) }
        await Task.yield()
        afterRender?()
        let starts = phrase.tokens.indices.map { Double($0) / 3 }
        return RenderedPhrase(phraseIndex: 0, phrase: phrase, voiceIdentifier: voiceIdentifier,
                              buffer: silence(seconds: Double(phrase.tokens.count) / 3 + 0.2),
                              tokenStarts: starts, markerUnit: .bytes, markerSource: "fake", renderSeconds: 0, sourceFormat: "fake")
    }
}

@MainActor
struct ScriptRendererTests {

    static let voices = VoiceChoice(
        presenter: VoiceInfo(identifier: "stephanie", name: "Stephanie", language: "en-GB", quality: .enhanced, gender: .female),
        cue: VoiceInfo(identifier: "jamie", name: "Jamie", language: "en-GB", quality: .premium, gender: .male),
        presenterIsPreferred: true
    )

    private let fake = FakeRenderer()
    private let parsed = ScriptParser.parse(SampleScript.harbourWalk)

    private func list(_ step: Int) -> PhraseList { PhraseList(lines: parsed.steps[step].lines) }

    private func renderer() -> ScriptRenderer { ScriptRenderer(renderer: fake, voices: Self.voices) }

    @Test func rendersAStepInOrderSpokenAndCuesInTheirVoices() async throws {
        let renderer = renderer()
        let phrases = list(0)
        await renderer.render(script: "a", step: 0, phrases: phrases)
        #expect(renderer.state == .ready(step: 0))
        #expect(fake.calls.map(\.text) == phrases.phrases.map(\.phrase.text))
        let cue = try #require(phrases.phrases.firstIndex { $0.kind == .cue })
        #expect(fake.calls[cue].voice == "jamie")
        #expect(fake.calls.enumerated().filter { $0.offset != cue }.allSatisfy { $0.element.voice == "stephanie" })
        let rendered = try #require(renderer.rendered(phrases))
        #expect(rendered.count == phrases.phrases.count)
    }

    @Test func aStepAlreadyRenderedRendersNothing() async {
        let renderer = renderer()
        await renderer.render(script: "a", step: 0, phrases: list(0))
        await renderer.render(script: "a", step: 1, phrases: list(1))
        let count = fake.calls.count
        await renderer.render(script: "a", step: 0, phrases: list(0))
        #expect(fake.calls.count == count)
        #expect(renderer.state == .ready(step: 0))
        #expect(renderer.rendered(list(1)) != nil)
    }

    @Test func aRepasteRendersOnlyTheChangedLine() async {
        let renderer = renderer()
        await renderer.render(script: "a", step: 1, phrases: list(1))
        fake.calls = []
        var lines = parsed.steps[1].lines
        lines[1] = "You can still see the marks, if you know where to look."
        await renderer.render(script: "a", step: 1, phrases: PhraseList(lines: lines))
        #expect(fake.calls.map(\.text) == ["You can still see the marks, if you know where to look."])
    }

    @Test func theKeyIsTheVoiceTheRateAndTheText() {
        let renderer = renderer()
        let phrases = list(0).phrases
        let spoken = phrases[0]
        let key = renderer.key(for: spoken)
        #expect(key == ScriptRenderer.Key(voice: "stephanie", rate: 0.5, text: spoken.phrase.text))
        // Another line with the same text has the same key.
        #expect(renderer.key(for: StepPhrase(line: 9, kind: .spoken, phrase: spoken.phrase)) == key)
        #expect(renderer.key(for: StepPhrase(line: 0, kind: .cue, phrase: spoken.phrase))?.voice == "jamie")
        let faster = ScriptRenderer(renderer: fake, voices: Self.voices, rate: 0.55)
        #expect(faster.key(for: spoken) != key)
    }

    @Test func anotherScriptLetsTheFirstGo() async {
        let renderer = renderer()
        await renderer.render(script: "a", step: 0, phrases: list(0))
        #expect(renderer.cachedCount == list(0).phrases.count)
        await renderer.render(script: "b", step: 1, phrases: list(1))
        #expect(renderer.cachedCount == list(1).phrases.count)
        #expect(renderer.rendered(list(0)) == nil)
    }

    @Test func progressIsReportedAndAFailureShown() async {
        let renderer = renderer()
        var seen: [ScriptRenderer.State] = []
        fake.afterRender = { seen.append(renderer.state) }
        fake.failOn = "breakfast"
        await renderer.render(script: "a", step: 0, phrases: list(0))
        #expect(seen.first == .rendering(step: 0, done: 0, total: list(0).phrases.count))
        #expect(seen.contains(.rendering(step: 0, done: 1, total: list(0).phrases.count)))
        guard case .failed(0, let message) = renderer.state else {
            Issue.record("expected a failure, got \(renderer.state)")
            return
        }
        #expect(message.contains("breakfast"))
        // Render again once it would succeed: only the rest is rendered.
        fake.failOn = nil
        fake.afterRender = nil
        let succeeded = seen.count
        let before = fake.calls.count
        await renderer.render(script: "a", step: 0, phrases: list(0))
        #expect(renderer.state == .ready(step: 0))
        #expect(fake.calls.count - before == list(0).phrases.count - succeeded)
    }

    @Test func cancelStopsARenderUnderWay() async {
        let renderer = renderer()
        fake.afterRender = { [renderer] in renderer.cancel() }
        await renderer.render(script: "a", step: 0, phrases: list(0))
        #expect(fake.calls.count == 1)
        #expect(renderer.state == .idle)
        #expect(renderer.cachedCount == 0)
    }

    @Test func withNoVoiceItFails() async {
        let renderer = ScriptRenderer(renderer: fake, voices: nil)
        await renderer.render(script: "a", step: 0, phrases: list(0))
        guard case .failed(0, let message) = renderer.state else {
            Issue.record("expected a failure")
            return
        }
        #expect(message.contains("No English voice"))
        await #expect(throws: ScriptRenderer.RenderFailure.self) { _ = try await renderer.renderCue("Step 1, take 1.") }
    }

    @Test func theSlateIsRenderedInTheCueVoiceAndNotKept() async throws {
        let renderer = renderer()
        let slate = try await renderer.renderCue("Step 2, take 1.")
        #expect(slate.phrase.text == "Step 2, take 1.")
        #expect(fake.calls.last?.voice == "jamie")
        #expect(renderer.cachedCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func theRealVoiceRendersAStep() async throws {
        let choice = try #require(VoiceCatalogue.choose(from: VoiceCatalogue.installed()))
        let renderer = ScriptRenderer(renderer: VoiceRenderer(), voices: choice)
        let phrases = PhraseList(lines: ["The kettle is on.", "[Point at the toast] And the toast is nearly done."])
        await renderer.render(script: "a", step: 0, phrases: phrases)
        #expect(renderer.state == .ready(step: 0))
        let rendered = try #require(renderer.rendered(phrases))
        #expect(rendered.allSatisfy { $0.duration > 0.3 && $0.buffer.format == VoiceRenderer.outputFormat })
    }
}
