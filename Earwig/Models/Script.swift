import Foundation
import SwiftData

/// A text imported into Earwig (PRD §3, §6.1).
@Model
final class Script {
    var title: String = ""
    /// The text as pasted, with line endings made `\n` and trailing spaces trimmed.
    var sourceText: String = ""
    var formatRaw: String = ScriptFormat.plain.rawValue
    /// SHA-256 of `sourceText`, so a re-paste of the same text is recognised.
    var sourceHash: String = ""
    /// Cutaway text before the first step.
    var preamble: String?
    var importedAt: Date = Date()
    var updatedAt: Date = Date()
    /// Whether step directions and inline directions are read in the cue voice.
    var cuesOn: Bool = true
    /// The step a take starts from, as an index into `orderedSteps`.
    var lastStep: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \Step.script)
    var steps: [Step]? = []
    @Relationship(deleteRule: .cascade, inverse: \Take.script)
    var takes: [Take]? = []
    @Relationship(deleteRule: .cascade, inverse: \Rendering.script)
    var renderings: [Rendering]? = []

    init(title: String = "", sourceText: String = "", format: ScriptFormat = .plain, sourceHash: String = "") {
        self.title = title
        self.sourceText = sourceText
        self.formatRaw = format.rawValue
        self.sourceHash = sourceHash
    }

    var format: ScriptFormat {
        get { ScriptFormat(rawValue: formatRaw) ?? .plain }
        set { formatRaw = newValue.rawValue }
    }

    var orderedSteps: [Step] { (steps ?? []).sorted { $0.sortOrder < $1.sortOrder } }

    var phraseCount: Int { (steps ?? []).reduce(0) { $0 + $1.phraseList.spoken.count } }

    /// The takes of the step at `index` in `orderedSteps`, newest first.
    func takes(forStep index: Int) -> [Take] {
        (takes ?? []).filter { $0.stepIndex == index }.sorted { $0.startedAt > $1.startedAt }
    }

    var lastTake: Take? { (takes ?? []).max { $0.startedAt < $1.startedAt } }
}
