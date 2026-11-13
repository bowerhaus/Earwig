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
        let result = try importer.paste(Fixtures.harbourWalk)
        #expect(result.outcome == .added)
        #expect(result.script.title == "The Harbour Walk")
        #expect(result.script.format == .cutaway)
        #expect(result.script.orderedSteps.count == 3)
        // 26 since plan 009: "The path climbs … half a mile." is no longer cut in two.
        #expect(result.script.phraseCount == 26)
        #expect(count == 1)
    }

    @Test func theSameTextAgainAddsNothing() throws {
        let first = try importer.paste(Fixtures.harbourWalk).script
        let messy = Fixtures.harbourWalk.replacingOccurrences(of: "\n", with: "  \r\n") + "\n\n"
        let again = try importer.paste(messy)
        #expect(again.outcome == .unchanged)
        #expect(again.script === first)
        #expect(count == 1)
    }

    @Test func theSameTitleWithNewTextReplacesAndKeepsTakesAndRenderings() throws {
        let script = try importer.paste(Fixtures.harbourWalk).script
        script.cuesOn = false
        script.lastStep = 2
        let take = Take(stepIndex: 1)
        let rendering = Rendering(scriptHash: script.sourceHash, voiceIdentifier: "v")
        context.insert(take)
        context.insert(rendering)
        take.script = script
        rendering.script = script

        // Shorter, and with the title in another case.
        let shorter = Fixtures.harbourWalk.components(separatedBy: "## 3.")[0]
            .replacingOccurrences(of: "# The Harbour Walk", with: "# the harbour walk")
        let result = try importer.paste(shorter)
        #expect(result.outcome == .replaced)
        #expect(result.script === script)
        #expect(count == 1)
        #expect(script.orderedSteps.count == 2)
        #expect(try context.fetchCount(FetchDescriptor<Step>()) == 2)
        #expect(script.takes?.count == 1)
        #expect(script.renderings?.count == 1)
        #expect(!script.cuesOn)
        #expect(script.lastStep == 1)
    }

    @Test func aTitleTakenFromTheFirstLineNeverReplacesAnotherScript() throws {
        _ = try importer.paste("Morning, everyone.\nWe start at the harbour.")
        let second = try importer.paste("Morning, everyone.\nWe start at the station.")
        #expect(second.outcome == .added)
        #expect(count == 2)
    }

    @Test func anotherTitleIsANewScript() throws {
        _ = try importer.paste(Fixtures.harbourWalk)
        _ = try importer.paste(Fixtures.rosie)
        #expect(count == 2)
    }

    @Test func pasteNewVersionReplacesWhateverTheTitle() throws {
        let script = try importer.paste(Fixtures.harbourWalk).script
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
        let script = try importer.paste(Fixtures.harbourWalk).script
        let step = try #require(script.orderedSteps.first)
        step.phraseList = PhraseList(parserVersion: 0)
        let updatedAt = script.updatedAt
        #expect(importer.refreshIfStale(script))
        #expect(script.updatedAt == updatedAt)
        #expect(script.orderedSteps.allSatisfy { $0.phraseList.isCurrent })
        #expect(script.orderedSteps.first?.phraseList.spoken.isEmpty == false)
        #expect(!importer.refreshIfStale(script))
    }

    // MARK: Written in Earwig (plan 015)

    @Test func newNeverReplacesAScriptByItsTitle() throws {
        let pasted = try importer.paste("# The Pier\n\nIt opened in 1899.").script
        let written = try importer.create("# The Pier\n\nIt is a long way out.")
        #expect(written.outcome == .added)
        #expect(written.script !== pasted)
        #expect(written.script.editedInEarwig)
        #expect(!pasted.editedInEarwig)
        #expect(count == 2)
    }

    @Test func newWithAStoredScriptsTextOpensIt() throws {
        let pasted = try importer.paste(Fixtures.harbourWalk).script
        let written = try importer.create(Fixtures.harbourWalk + "\n")
        #expect(written.outcome == .unchanged)
        #expect(written.script === pasted)
        #expect(count == 1)
    }

    @Test func anEditKeepsTakesAndTheStartStepAndIsMarked() throws {
        let script = try importer.paste(Fixtures.harbourWalk).script
        script.lastStep = 1
        let take = Take(stepIndex: 1)
        context.insert(take)
        take.script = script
        let edited = Fixtures.harbourWalk.replacingOccurrences(of: "built in 1890", with: "built in 1891")
        let result = try importer.edit(script, with: edited)
        #expect(result.outcome == .replaced)
        #expect(script.editedInEarwig)
        #expect(script.takes?.count == 1)
        #expect(script.lastStep == 1)
        #expect(script.orderedSteps[1].lines[0].contains("1891"))
        #expect(try importer.edit(script, with: edited).outcome == .unchanged)
    }

    @Test func aPasteOverAnEditAsksFirst() throws {
        let script = try importer.paste(Fixtures.harbourWalk).script
        _ = try importer.edit(script, with: Fixtures.harbourWalk.replacingOccurrences(of: "Morning!", with: "Hello!"))
        let newer = Fixtures.harbourWalk.replacingOccurrences(of: "Morning!", with: "Good morning!")

        // By title on the Scripts screen.
        let asked = try importer.paste(newer)
        #expect(asked.outcome == .wouldReplaceEdits)
        #expect(asked.script === script)
        #expect(script.orderedSteps[0].lines[0].hasPrefix("Hello!"))
        let replaced = try importer.paste(newer, replacingEdits: true)
        #expect(replaced.outcome == .replaced)
        #expect(!script.editedInEarwig)
        #expect(count == 1)

        // By Paste New Version on the Script screen.
        _ = try importer.edit(script, with: Fixtures.harbourWalk)
        #expect(try importer.replace(script, with: Fixtures.rosie).outcome == .wouldReplaceEdits)
        #expect(try importer.replace(script, with: Fixtures.rosie, replacingEdits: true).outcome == .replaced)
        #expect(!script.editedInEarwig)
    }

    @Test func aPasteOfTheSameTextOverAnEditOpensIt() throws {
        let script = try importer.paste(Fixtures.harbourWalk).script
        let edited = Fixtures.harbourWalk.replacingOccurrences(of: "Morning!", with: "Hello!")
        _ = try importer.edit(script, with: edited)
        #expect(try importer.paste(edited).outcome == .unchanged)
        #expect(try importer.replace(script, with: edited).outcome == .unchanged)
    }

    /// Samples are edited as any script is, and Reset Sample puts the text back, keeping the
    /// takes (plan 015, decision 7).
    @Test func aSampleIsEditedAndResetKeepingItsTakes() throws {
        let sample = try importer.add(SampleScript.seasidePier)
        sample.sampleID = "seaside-pier"
        let take = Take(stepIndex: 0)
        context.insert(take)
        take.script = sample
        #expect(try importer.edit(sample, with: "# The Seaside Pier\n\nNew words.").outcome == .replaced)
        #expect(sample.isEditedSample)
        #expect(sample.orderedSteps.count == 1)
        #expect(try importer.reset(sample)?.outcome == .replaced)
        #expect(!sample.isEditedSample)
        #expect(sample.sourceHash == ScriptImporter.hash(SampleScript.seasidePier))
        #expect(sample.orderedSteps.count == 3)
        #expect(sample.takes?.count == 1)
    }

    @Test func onlyASampleIsReset() throws {
        let own = try importer.paste("# The Pier\n\nHello.").script
        #expect(try importer.reset(own) == nil)
        #expect(own.title == "The Pier")
    }

    @Test func checkSaysWhyTextCannotBeSaved() {
        #expect(throws: Never.self) { try ScriptImporter.check("# The Pier\n\nIt opened in 1899.").get() }
        #expect(ScriptImporter.check("# ").failure == .noSteps)
        #expect(ScriptImporter.check("#\n\nHello.").map(\.title) == .success("Hello."))
        #expect(ScriptImporter.check("## Quiet\n[A view]").failure == .noSteps)
        #expect(ScriptImporter.check("[A view] [Another]").failure == .noWords)
    }

    @Test func hashIgnoresLineEndingsAndTrailingSpace() {
        #expect(ScriptImporter.hash("a\r\nb  \n") == ScriptImporter.hash("a\nb"))
        #expect(ScriptImporter.hash("a\nb") != ScriptImporter.hash("a\nc"))
    }
}

private extension Swift.Result {
    var failure: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
