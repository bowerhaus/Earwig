import Foundation
@testable import Earwig
import SwiftData
import Testing

@MainActor
struct ModelTests {

    @Test func stepsComeBackInOrder() throws {
        let container = ModelContainerFactory.inMemory()
        let context = container.mainContext
        let script = Script(title: "Order")
        context.insert(script)
        for order in [2, 0, 1] {
            let step = Step(sortOrder: order, number: order + 1, title: "S\(order)")
            context.insert(step)
            step.script = script
        }
        try context.save()
        #expect(script.orderedSteps.map(\.sortOrder) == [0, 1, 2])
    }

    @Test func deletingAScriptDeletesItsStepsTakesAndRenderings() throws {
        let container = ModelContainerFactory.inMemory()
        let context = container.mainContext
        let script = try ScriptImporter(context: context).paste(SampleScript.harbourWalk).script
        let take = Take(stepIndex: 0)
        let rendering = Rendering(scriptHash: script.sourceHash, voiceIdentifier: "v")
        context.insert(take)
        context.insert(rendering)
        take.script = script
        rendering.script = script
        try context.save()

        context.delete(script)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Script>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Step>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Take>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Rendering>()) == 0)
    }

    @Test func typedAccessorsPersist() throws {
        let container = ModelContainerFactory.inMemory()
        let context = container.mainContext
        let script = Script(title: "Typed", format: .cutaway)
        let step = Step(sortOrder: 0, number: 1, title: "One")
        step.directions = [Direction(kind: .shows, text: "A view")]
        step.lines = ["Hello there."]
        step.phraseList = PhraseList(lines: step.lines)
        let take = Take(stepIndex: 0, number: 2)
        take.outcome = .completed
        let rendering = Rendering()
        rendering.phrases = ["p0": RenderedPhraseFile(file: "0.caf", wordStarts: [0, nil])]
        context.insert(script)
        for model in [step, take, rendering] as [any PersistentModel] { context.insert(model) }
        step.script = script
        take.script = script
        rendering.script = script
        try context.save()

        let fresh = ModelContext(container)
        let stored = try #require(try fresh.fetch(FetchDescriptor<Script>()).first)
        #expect(stored.format == .cutaway)
        let storedStep = try #require(stored.orderedSteps.first)
        #expect(storedStep.directions == [Direction(kind: .shows, text: "A view")])
        #expect(storedStep.lines == ["Hello there."])
        #expect(storedStep.phraseList.scriptWords.map(\.text) == ["hello", "there"])
        #expect(stored.takes?.first?.outcome == .completed)
        #expect(stored.renderings?.first?.phrases["p0"]?.wordStarts == [0, nil])
    }

    @Test func takesAreFoundPerStepNewestFirst() throws {
        let container = ModelContainerFactory.inMemory()
        let context = container.mainContext
        let script = Script(title: "Takes")
        context.insert(script)
        let start = Date(timeIntervalSince1970: 1_000)
        for (step, minutes) in [(0, 0), (1, 5), (0, 10)] {
            let take = Take(stepIndex: step, startedAt: start.addingTimeInterval(Double(minutes) * 60))
            context.insert(take)
            take.script = script
        }
        try context.save()
        #expect(script.takes(forStep: 0).map(\.startedAt) == [start.addingTimeInterval(600), start])
        #expect(script.takes(forStep: 2).isEmpty)
        #expect(script.lastTake?.startedAt == start.addingTimeInterval(600))
    }

    @Test func headingFallsBackToTheNumber() {
        #expect(Step(number: 3, title: "Rosie up ahead").heading == "Rosie up ahead")
        #expect(Step(number: 2).heading == "Step 2")
    }
}
