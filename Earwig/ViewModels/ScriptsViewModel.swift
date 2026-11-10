import Foundation
import Observation
import SwiftData

/// The Scripts screen (PRD §8.1): paste, New, delete, and which script is open.
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
            if result.outcome == .wouldReplaceEdits {
                pendingPaste = PendingPaste(text: text, script: result.script)
                return
            }
            try context.save()
            path = [result.script]
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// A paste that would replace changes made in Earwig, waiting for the question to be
    /// answered (plan 015, decision 8).
    struct PendingPaste {
        let text: String
        let script: Script
    }

    private(set) var pendingPaste: PendingPaste?

    /// Replace was chosen: the paste is made, replacing the changes.
    func confirmPaste(_ pending: PendingPaste, in context: ModelContext) {
        pendingPaste = nil
        do {
            let result = try ScriptImporter(context: context).paste(pending.text, replacingEdits: true)
            try context.save()
            path = [result.script]
        } catch {
            self.error = error.localizedDescription
        }
    }

    func cancelPaste() {
        pendingPaste = nil
    }

    /// The editor while New's sheet is up (plan 015).
    var editor: ScriptEditor?

    func newScript() {
        editor = ScriptEditor(mode: .new)
    }

    func open(_ script: Script?) {
        if let script { path = [script] }
    }

    /// The script a swipe asked to delete, waiting for the question to be answered (#35).
    private(set) var pendingDeletion: Script?

    /// A swipe asks first, as Delete Script does (plan 012, decision 14). A sample is never
    /// asked about, since it is never deleted (plan 011, decision 5).
    func askToDelete(_ script: Script) {
        guard !script.isSample else { return }
        pendingDeletion = script
    }

    /// Deletes the script the question was about, with its takes. The script is passed in, not
    /// read from `pendingDeletion`, which the dialog's binding may clear first (review C1).
    func confirmDeletion(of script: Script, in context: ModelContext) {
        pendingDeletion = nil
        guard !script.isSample else { return }
        context.delete(script)
        try? context.save()
    }

    func cancelDeletion() {
        pendingDeletion = nil
    }
}
