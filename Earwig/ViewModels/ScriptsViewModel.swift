import Foundation
import Observation
import SwiftData

/// The Scripts screen (PRD §8.1): paste, delete, and which script is open.
@MainActor
@Observable
final class ScriptsViewModel {
    /// The navigation stack: the open script, if any.
    var path: [Script] = []
    /// Shown in an alert when a paste is refused.
    var error: String?

    func paste(_ text: String?, in context: ModelContext) {
        guard let text, !text.isEmpty else {
            error = ScriptImporter.ImportError.noSteps.localizedDescription
            return
        }
        do {
            let result = try ScriptImporter(context: context).paste(text)
            try context.save()
            path = [result.script]
        } catch {
            self.error = error.localizedDescription
        }
    }

    func open(_ script: Script?) {
        if let script { path = [script] }
    }

    /// The script a swipe asked to delete, waiting for the question to be answered (#35).
    var pendingDeletion: Script?

    /// A swipe asks first, as Delete Script does (plan 012, decision 14). A sample is never
    /// asked about, since it is never deleted (plan 011, decision 5).
    func askToDelete(_ script: Script) {
        guard !script.isSample else { return }
        pendingDeletion = script
    }

    /// Deletes the script waiting, with its takes.
    func confirmDeletion(in context: ModelContext) {
        guard let script = pendingDeletion else { return }
        pendingDeletion = nil
        guard !script.isSample else { return }
        context.delete(script)
        try? context.save()
    }

    func cancelDeletion() {
        pendingDeletion = nil
    }
}
