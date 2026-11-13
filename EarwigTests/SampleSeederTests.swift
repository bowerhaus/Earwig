import Foundation
@testable import Earwig
import SwiftData
import Testing

/// The built-in samples (plan 011, decisions 2 to 6).
@MainActor
struct SampleSeederTests {

    // Held: a context outlived by its container crashes.
    private let container = ModelContainerFactory.inMemory()
    private var context: ModelContext { container.mainContext }
    private var seeder: SampleSeeder { SampleSeeder(context: context) }
    private var scripts: [Script] { (try? context.fetch(FetchDescriptor<Script>())) ?? [] }

    private func addTake(to script: Script) {
        let take = Take(stepIndex: 0)
        context.insert(take)
        take.script = script
    }

    @Test func eachSampleIsInTheDocumentedFormatWithWordsInEveryStep() {
        let steps = ["harbour-walk": 3, "weekend-loaf": 4, "old-watermill": 7, "seaside-pier": 3]
        for sample in SampleScript.all {
            let parsed = ScriptParser.parse(sample.text)
            #expect(parsed.format == .plain, "\(sample.id)")
            #expect(parsed.steps.count == steps[sample.id], "\(sample.id)")
            #expect(parsed.titleIsStated, "\(sample.id)")
            #expect(parsed.steps.allSatisfy { !PhraseList(lines: $0.lines).spoken.isEmpty }, "\(sample.id)")
        }
    }

    /// Plan 015, decision 13: the same steps in the same order, so takes kept by step stay right,
    /// and Cutaway's `Shows:` is the cue at the top of each step.
    @Test func theHarbourWalkSaysWhatItSaidInCutawaysFormat() {
        let documented = ScriptParser.parse(SampleScript.harbourWalk)
        let cutaway = ScriptParser.parse(Fixtures.harbourWalk)
        #expect(documented.title == cutaway.title)
        #expect(documented.steps.map(\.title) == cutaway.steps.map(\.title))
        #expect(documented.steps.map(\.lines) == cutaway.steps.map(\.lines))
        #expect(documented.steps.map { $0.directions.filter { $0.kind == .cue }.map(\.text) }
            == cutaway.steps.map { $0.directions.filter { $0.kind == .shows }.map { String($0.text.dropLast()) } })
    }

    @Test func theSeasidePiersStepsAreNamed() {
        #expect(ScriptParser.parse(SampleScript.seasidePier).steps.map(\.title) == ["The entrance", "Halfway out", "The end of the pier"])
    }

    @Test func aFreshStoreGetsTheFourSamplesInOrder() throws {
        try seeder.seed()
        #expect(scripts.count == 4)
        #expect(SampleSeeder.ordered(scripts).map(\.title) == ["The Harbour Walk", "The Weekend Loaf", "The Old Watermill", "The Seaside Pier"])
        #expect(scripts.allSatisfy { $0.isSample })
    }

    @Test func seedingAgainChangesNothing() throws {
        try seeder.seed()
        try seeder.seed()
        #expect(scripts.count == 4)
    }

    @Test func aChangedSampleTextReplacesTheStoredTextAndKeepsItsTakes() throws {
        let old = SampleScript.Sample(id: "harbour-walk", text: SampleScript.harbourWalk.components(separatedBy: "## Up the cliff path")[0])
        try seeder.seed([old])
        let walk = try #require(scripts.first)
        addTake(to: walk)
        walk.lastStep = 1
        walk.cuesOn = false
        let updatedAt = walk.updatedAt
        try seeder.seed([SampleScript.all[0]])
        #expect(scripts.count == 1)
        #expect(walk.sourceHash == ScriptImporter.hash(SampleScript.harbourWalk))
        #expect(walk.orderedSteps.count == 3)
        #expect(walk.takes?.count == 1)
        #expect(walk.lastStep == 1)
        #expect(!walk.cuesOn)
        #expect(walk.updatedAt == updatedAt)
    }

    @Test func aPastedCopyOfASampleIsAdoptedWithItsTakes() throws {
        let pasted = try ScriptImporter(context: context).paste(SampleScript.oldWatermill).script
        addTake(to: pasted)
        try seeder.seed()
        #expect(scripts.count == 4)
        #expect(pasted.sampleID == "old-watermill")
        #expect(pasted.takes?.count == 1)
    }

    @Test func anEditedCopyIsNotAdoptedAndStaysThePresentersOwn() throws {
        let edited = SampleScript.weekendLoaf.replacingOccurrences(of: "white loaf", with: "brown loaf")
        let pasted = try ScriptImporter(context: context).paste(edited).script
        try seeder.seed()
        #expect(scripts.count == 5)
        #expect(!pasted.isSample)
        #expect(pasted.title == "The Weekend Loaf")
    }

    @Test func aPasteTitledLikeASampleIsANewScriptOfTheirOwn() throws {
        try seeder.seed()
        let shorter = SampleScript.harbourWalk.components(separatedBy: "## Up the cliff path")[0]
        let result = try ScriptImporter(context: context).paste(shorter)
        #expect(result.outcome == .added)
        #expect(!result.script.isSample)
        #expect(scripts.count == 5)
        let sample = try #require(scripts.first { $0.sampleID == "harbour-walk" })
        #expect(sample.orderedSteps.count == 3)
    }

    @Test func aPasteOfASamplesTextOpensTheSample() throws {
        try seeder.seed()
        let result = try ScriptImporter(context: context).paste(SampleScript.seasidePier)
        #expect(result.outcome == .unchanged)
        #expect(result.script.sampleID == "seaside-pier")
        #expect(scripts.count == 4)
    }

    /// An edited sample is the presenter's to keep until Reset Sample (plan 015, decision 7).
    @Test func anEditedSampleIsLeftAloneByALaterBuild() throws {
        let old = SampleScript.Sample(id: "harbour-walk", text: SampleScript.harbourWalk.components(separatedBy: "## Up the cliff path")[0])
        try seeder.seed([old])
        let walk = try #require(scripts.first)
        let edited = old.text.replacingOccurrences(of: "Morning!", with: "Hello!")
        _ = try ScriptImporter(context: context).edit(walk, with: edited)
        try seeder.seed([SampleScript.all[0]])
        #expect(walk.sourceHash == ScriptImporter.hash(ScriptImporter.cleaned(edited)))
        #expect(walk.isEditedSample)
    }

    @Test func aSwipeResetsOnlyAnEditedSample() throws {
        try seeder.seed()
        let walk = try #require(scripts.first { $0.sampleID == "harbour-walk" })
        let model = ScriptsViewModel()
        model.askToReset(walk)
        #expect(model.pendingReset == nil)
        _ = try ScriptImporter(context: context).edit(walk, with: SampleScript.harbourWalk.replacingOccurrences(of: "Morning!", with: "Hello!"))
        model.askToReset(walk)
        #expect(model.pendingReset === walk)
        model.confirmReset(of: walk, in: context)
        #expect(model.pendingReset == nil)
        #expect(walk.sourceHash == ScriptImporter.hash(SampleScript.harbourWalk))
        #expect(!walk.isEditedSample)
    }

    @Test func samplesAreNotDeleted() throws {
        try seeder.seed()
        let own = try ScriptImporter(context: context).paste(Fixtures.plain).script
        let model = ScriptsViewModel()
        for script in scripts {
            model.askToDelete(script)
            // A sample is never asked about, and never deleted if it were.
            #expect((model.pendingDeletion == nil) == script.isSample)
            model.confirmDeletion(of: script, in: context)
        }
        #expect(scripts.count == 4)
        #expect(!scripts.contains { $0 === own })
    }
}
