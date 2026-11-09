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
}
