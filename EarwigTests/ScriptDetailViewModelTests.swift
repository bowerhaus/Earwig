@testable import Earwig
import Foundation
import SwiftData
import Testing

@MainActor
struct ScriptDetailViewModelTests {

    /// Held for as long as its context is used (CLAUDE.md).
    private let container = ModelContainerFactory.inMemory()
    private let fake = FakeRenderer()

    @Test func theRowShowsTheRenderOfThisScriptsStartStepOnly() async throws {
        let context = container.mainContext
        let script = try ScriptImporter(context: context).paste(SampleScript.harbourWalk).script
        let other = try ScriptImporter(context: context).paste(Fixtures.rosie).script
        let renderer = ScriptRenderer(renderer: fake, voices: ScriptRendererTests.voices)
        let model = ScriptDetailViewModel(script: script)

        model.appeared(in: context, renderer: renderer)
        await renderer.finished()
        #expect(model.renderState(renderer) == .ready(step: 0))

        // Picking another step: the old step's state is not shown for it.
        model.select(step: 1, in: context, renderer: renderer)
        #expect(model.renderState(renderer) == .idle)
        await renderer.finished()
        #expect(model.renderState(renderer) == .ready(step: 1))

        // Picking the start step again renders nothing.
        let calls = fake.calls.count
        model.select(step: 1, in: context, renderer: renderer)
        await renderer.finished()
        #expect(fake.calls.count == calls)

        // Another script's render is not this one's.
        ScriptDetailViewModel(script: other).appeared(in: context, renderer: renderer)
        #expect(model.renderState(renderer) == .idle)
    }

    @Test func startOpensATakeNumberedAfterTheStepsLast() async throws {
        let context = container.mainContext
        let script = try ScriptImporter(context: context).paste(SampleScript.harbourWalk).script
        let renderer = ScriptRenderer(renderer: fake, voices: ScriptRendererTests.voices)
        let model = ScriptDetailViewModel(script: script)
        model.appeared(in: context, renderer: renderer)
        await renderer.finished()
        let earlier = Take(stepIndex: 0, number: 4)
        context.insert(earlier)
        earlier.script = script

        model.startTake(with: renderer, in: context, mode: .ear)
        let setup = try #require(model.take?.setup)
        #expect(setup.take == 5)
        #expect(setup.slateText.hasSuffix("take 5."))
        #expect(setup.slateWords.last == .number(5))
        #expect(setup.script.phrases.count == setup.phraseList.phrases.count)

        // Closed while getting ready: nothing is recorded.
        model.endTake()
        #expect(model.take == nil)
        #expect(script.takes(forStep: 0).count == 1)
    }

    @Test func onTheScreenAloneATakeStartsWithNothingRendered() throws {
        let context = container.mainContext
        let script = try ScriptImporter(context: context).paste(SampleScript.harbourWalk).script
        let renderer = ScriptRenderer(renderer: fake, voices: ScriptRendererTests.voices)
        let model = ScriptDetailViewModel(script: script)
        #expect(model.renderState(renderer) == .idle)

        model.startTake(with: renderer, in: context, mode: .screen)
        let setup = try #require(model.take?.setup)
        #expect(setup.mode == .screen)
        #expect(!setup.engineSettings.voiced)
        #expect(setup.audio.phrases.isEmpty)
        #expect(setup.script.phrases.count == setup.phraseList.phrases.count)
        #expect(setup.script.words.count == setup.phraseList.spoken.flatMap(\.phrase.scriptWords).count)

        // Next Take keeps the take's mode, whatever the setting.
        let stored = AppSettings.take.mode
        AppSettings.take.mode = .ear
        defer { AppSettings.take.mode = stored }
        model.nextTake(with: renderer, in: context)
        #expect(model.take?.setup.mode == .screen)
        model.endTake()
    }

    @Test func withAVoiceATakeStillNeedsTheRendering() throws {
        let context = container.mainContext
        let script = try ScriptImporter(context: context).paste(SampleScript.harbourWalk).script
        let renderer = ScriptRenderer(renderer: fake, voices: ScriptRendererTests.voices)
        let model = ScriptDetailViewModel(script: script)
        model.startTake(with: renderer, in: context, mode: .both)
        #expect(model.take == nil)
        #expect(model.error == "The step is not rendered yet.")
    }

    @Test func withCuesOffATakeHasNoCuePhrases() async throws {
        let context = container.mainContext
        let script = try ScriptImporter(context: context).paste(SampleScript.harbourWalk).script
        script.cuesOn = false
        let renderer = ScriptRenderer(renderer: fake, voices: ScriptRendererTests.voices)
        let model = ScriptDetailViewModel(script: script)
        model.appeared(in: context, renderer: renderer)
        await renderer.finished()
        #expect(model.startStep?.phraseList.phrases.contains { $0.kind == .cue } == true)

        model.startTake(with: renderer, in: context, mode: .ear)
        let setup = try #require(model.take?.setup)
        #expect(setup.phraseList.phrases.allSatisfy { $0.kind == .spoken })
        #expect(setup.audio.phrases.count == setup.phraseList.phrases.count)
        model.endTake()
    }

    @Test func aTakeIsRecordedAtItsSlateAndFinishedAtItsEnd() throws {
        let context = container.mainContext
        let script = try ScriptImporter(context: context).paste(SampleScript.harbourWalk).script
        let recorder = ScriptTakeRecorder(script: script, stepIndex: 1, number: 3, context: context)
        recorder.started(at: Date())
        #expect(script.takes(forStep: 1).map(\.number) == [3])
        #expect(script.takes(forStep: 1).first?.outcome == .stopped)
        #expect(script.nextTakeNumber(forStep: 1) == 4)
        #expect(script.nextTakeNumber(forStep: 0) == 1)

        recorder.finished(duration: 42.5, outcome: .completed)
        #expect(script.takes(forStep: 1).first?.outcome == .completed)
        #expect(script.takes(forStep: 1).first?.duration == 42.5)
    }
}
