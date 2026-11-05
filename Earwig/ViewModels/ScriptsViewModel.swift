import Foundation
import Observation
import SwiftData

/// The Scripts screen (PRD §8.1): paste, the sample, delete, and which script is open.
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

    func addSample(in context: ModelContext) {
        paste(SampleScript.harbourWalk, in: context)
    }

    func delete(_ scripts: [Script], in context: ModelContext) {
        for script in scripts { context.delete(script) }
        try? context.save()
    }
}
