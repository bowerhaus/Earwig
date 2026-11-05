import Foundation
@testable import Earwig
import SwiftData
import Testing

@MainActor
struct ScriptImporterTests {

    // Held: a context outlived by its container crashes.
    private let container = ModelContainerFactory.inMemory()
    private var context: ModelContext { container.mainContext }
    private var importer: ScriptImporter { ScriptImporter(context: context) }
    private var count: Int { (try? context.fetchCount(FetchDescriptor<Script>())) ?? -1 }

    @Test func aNewPasteAddsAScript() throws {
        let result = try importer.paste(SampleScript.harbourWalk)
        #expect(result.outcome == .added)
        #expect(result.script.title == "The Harbour Walk")
        #expect(result.script.format == .cutaway)
        #expect(result.script.orderedSteps.count == 3)
        #expect(result.script.phraseCount > 13)
        #expect(count == 1)
    }

    @Test func theSameTextAgainAddsNothing() throws {
        let first = try importer.paste(SampleScript.harbourWalk).script
        let messy = SampleScript.harbourWalk.replacingOccurrences(of: "\n", with: "  \r\n") + "\n\n"
        let again = try importer.paste(messy)
        #expect(again.outcome == .unchanged)
        #expect(again.script === first)
        #expect(count == 1)
    }

    @Test func theSameTitleWithNewTextReplacesAndKeepsTakes() throws {
        let script = try importer.paste(SampleScript.harbourWalk).script
        script.cuesOn = false
        script.lastStep = 2
        let take = Take(stepIndex: 1)
        context.insert(take)
        take.script = script

        let shorter = SampleScript.harbourWalk.components(separatedBy: "## 3.")[0]
        let result = try importer.paste(shorter)
        #expect(result.outcome == .replaced)
        #expect(result.script === script)
        #expect(count == 1)
        #expect(script.orderedSteps.count == 2)
        #expect(try context.fetchCount(FetchDescriptor<Step>()) == 2)
        #expect(script.takes?.count == 1)
        #expect(!script.cuesOn)
        #expect(script.lastStep == 1)
    }

    @Test func anotherTitleIsANewScript() throws {
        _ = try importer.paste(SampleScript.harbourWalk)
        _ = try importer.paste(Fixtures.rosie)
        #expect(count == 2)
    }

    @Test func pasteNewVersionReplacesWhateverTheTitle() throws {
        let script = try importer.paste(SampleScript.harbourWalk).script
        let result = try importer.replace(script, with: Fixtures.rosie)
        #expect(result.outcome == .replaced)
        #expect(script.title == "Rosie's Walk")
        #expect(count == 1)
        #expect(try importer.replace(script, with: Fixtures.rosie).outcome == .unchanged)
    }

    @Test func emptyOrWordlessTextIsRefused() {
        #expect(throws: ScriptImporter.ImportError.noSteps) { try importer.paste("   \n ") }
        #expect(throws: ScriptImporter.ImportError.noWords) { try importer.paste("## 1. Quiet\nShows: a view\nSays: nothing") }
        #expect(count == 0)
    }

    @Test func staleStepsAreRebuiltFromTheSourceText() throws {
        let script = try importer.paste(SampleScript.harbourWalk).script
        let step = try #require(script.orderedSteps.first)
        step.phraseList = PhraseList(parserVersion: 0)
        #expect(importer.refreshIfStale(script))
        #expect(script.orderedSteps.allSatisfy { $0.phraseList.isCurrent })
        #expect(script.orderedSteps.first?.phraseList.spoken.isEmpty == false)
        #expect(!importer.refreshIfStale(script))
    }

    @Test func hashIgnoresLineEndingsAndTrailingSpace() {
        #expect(ScriptImporter.hash("a\r\nb  \n") == ScriptImporter.hash("a\nb"))
        #expect(ScriptImporter.hash("a\nb") != ScriptImporter.hash("a\nc"))
    }
}
