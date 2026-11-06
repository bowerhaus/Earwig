import Foundation
import Observation
import SwiftData

/// The Script screen (PRD §8.2): the start step and its rendering, the cues switch, Listen, a
/// new version, delete.
@MainActor
@Observable
final class ScriptDetailViewModel {
    let script: Script
    var error: String?
    /// Set after Paste new version, for a short confirmation.
    var notice: String?
    /// The play-through behind Listen, while its sheet is up.
    var preview: StepPreview?

    init(script: Script) {
        self.script = script
    }

    /// Rebuilds the steps if they came from an older parser, then renders the start step.
    func appeared(in context: ModelContext, renderer: ScriptRenderer) {
        if ScriptImporter(context: context).refreshIfStale(script) { try? context.save() }
        renderStartStep(with: renderer)
    }

    func select(step index: Int, in context: ModelContext, renderer: ScriptRenderer) {
        guard index != script.lastStep else { return }
        script.lastStep = index
        try? context.save()
        renderStartStep(with: renderer)
    }

    func setCues(_ on: Bool, in context: ModelContext) {
        script.cuesOn = on
        try? context.save()
    }

    /// The step a take starts from, if the script has it.
    var startStep: Step? {
        let steps = script.orderedSteps
        return steps.indices.contains(script.lastStep) ? steps[script.lastStep] : steps.first
    }

    /// Renders the start step's missing phrases (plan 004, decision 2).
    func renderStartStep(with renderer: ScriptRenderer) {
        guard let step = startStep else { return }
        renderer.prepare(script: script.persistentModelID, step: script.lastStep, phrases: step.phraseList)
    }

    /// The rendering state for this script's start step.
    func renderState(_ renderer: ScriptRenderer) -> ScriptRenderer.State {
        guard renderer.target == AnyHashable(script.persistentModelID) else { return .idle }
        return switch renderer.state {
        case .rendering(let step, _, _), .ready(let step), .failed(let step, _):
            step == script.lastStep ? renderer.state : .idle
        case .idle:
            .idle
        }
    }

    /// Opens Listen on the start step, with the next take's slate (no take is recorded).
    func listen(with renderer: ScriptRenderer) {
        guard let step = startStep else { return }
        let take = script.takes(forStep: script.lastStep).count + 1
        preview = StepPreview(
            phraseList: step.phraseList,
            renderer: renderer,
            slateText: Slate.text(for: step, take: take, cuesOn: script.cuesOn),
            cuesOn: script.cuesOn
        )
    }

    func pasteNewVersion(_ text: String?, in context: ModelContext, renderer: ScriptRenderer) {
        guard let text, !text.isEmpty else {
            error = ScriptImporter.ImportError.noSteps.localizedDescription
            return
        }
        do {
            let result = try ScriptImporter(context: context).replace(script, with: text)
            try context.save()
            notice = result.outcome == .unchanged ? "That is the version already here." : "Updated to the new version."
            renderStartStep(with: renderer)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(in context: ModelContext) {
        context.delete(script)
        try? context.save()
    }
}
