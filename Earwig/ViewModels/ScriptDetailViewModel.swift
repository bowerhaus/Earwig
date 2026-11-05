import Foundation
import Observation
import SwiftData

/// The Script screen (PRD §8.2): the start step, the cues switch, a new version, delete.
@MainActor
@Observable
final class ScriptDetailViewModel {
    let script: Script
    var error: String?
    /// Set after Paste new version, for a short confirmation.
    var notice: String?

    init(script: Script) {
        self.script = script
    }

    /// Rebuilds the steps if they came from an older parser.
    func appeared(in context: ModelContext) {
        if ScriptImporter(context: context).refreshIfStale(script) { try? context.save() }
    }

    func select(step index: Int, in context: ModelContext) {
        script.lastStep = index
        try? context.save()
    }

    func setCues(_ on: Bool, in context: ModelContext) {
        script.cuesOn = on
        try? context.save()
    }

    func pasteNewVersion(_ text: String?, in context: ModelContext) {
        guard let text, !text.isEmpty else {
            error = ScriptImporter.ImportError.noSteps.localizedDescription
            return
        }
        do {
            let result = try ScriptImporter(context: context).replace(script, with: text)
            try context.save()
            notice = result.outcome == .unchanged ? "That is the version already here." : "Updated to the new version."
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(in context: ModelContext) {
        context.delete(script)
        try? context.save()
    }
}
