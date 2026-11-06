@testable import Earwig
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
}
