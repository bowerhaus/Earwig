import Foundation
@testable import Earwig
import SwiftData
import Testing

/// Swipe to delete asks first (#35; plan 012, decision 14).
@MainActor
struct ScriptsViewModelTests {

    // Held: a context outlived by its container crashes.
    private let container = ModelContainerFactory.inMemory()
    private var context: ModelContext { container.mainContext }
    private var scripts: [Script] { (try? context.fetch(FetchDescriptor<Script>())) ?? [] }
    private var takes: [Take] { (try? context.fetch(FetchDescriptor<Take>())) ?? [] }

    private func ownScript() throws -> Script {
        let script = try ScriptImporter(context: context).paste("The Allotment\n\nThe gate\nThe beans are up at last.").script
        let take = Take(stepIndex: 0)
        context.insert(take)
        take.script = script
        try context.save()
        return script
    }

    @Test func aScriptAskedToBeDeletedIsStillThereUntilConfirmed() throws {
        let script = try ownScript()
        let model = ScriptsViewModel()
        model.askToDelete(script)
        #expect(model.pendingDeletion == script)
        #expect(scripts.count == 1)
        #expect(takes.count == 1)
        model.confirmDeletion(of: script, in: context)
        #expect(model.pendingDeletion == nil)
        #expect(scripts.isEmpty)
        #expect(takes.isEmpty)
    }

    @Test func cancellingKeepsTheScriptAndItsTakes() throws {
        let script = try ownScript()
        let model = ScriptsViewModel()
        model.askToDelete(script)
        model.cancelDeletion()
        #expect(model.pendingDeletion == nil)
        #expect(scripts.count == 1)
        #expect(takes.count == 1)
    }

    // MARK: A paste over changes made in Earwig (plan 015, decision 8)

    @Test func aPasteOverAnEditAsksThenReplacesOrKeeps() throws {
        let script = try ownScript()
        _ = try ScriptImporter(context: context).edit(script, with: "The Allotment\n\nThe beans are up.")
        let model = ScriptsViewModel()

        model.paste("The Allotment\n\nThe peas are up.", in: context)
        let pending = try #require(model.pendingPaste)
        #expect(pending.script === script)
        #expect(model.path.isEmpty)
        model.cancelPaste()
        #expect(model.pendingPaste == nil)
        #expect(script.orderedSteps[0].lines == ["The beans are up."])

        model.paste("The Allotment\n\nThe peas are up.", in: context)
        model.confirmPaste(try #require(model.pendingPaste), in: context)
        #expect(model.pendingPaste == nil)
        #expect(model.path == [script])
        #expect(script.orderedSteps[0].lines == ["The peas are up."])
        #expect(!script.editedInEarwig)
    }
}
