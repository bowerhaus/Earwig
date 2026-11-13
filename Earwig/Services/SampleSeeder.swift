import Foundation
import SwiftData

/// Puts the built-in samples in the store at launch (plan 011, decisions 3 and 4): each sample
/// is a stored script with its `sampleID`, added if missing, given the new text if a later build
/// changed it, and left alone otherwise. A sample edited in Earwig is left alone too, until
/// Reset Sample (plan 015, decision 7). A script of the presenter's own with exactly a sample's
/// text becomes that sample, keeping its takes, so a sample pasted before this plan is not
/// listed twice.
@MainActor
struct SampleSeeder {
    let context: ModelContext

    func seed(_ samples: [SampleScript.Sample] = SampleScript.all) throws {
        let importer = ScriptImporter(context: context)
        for sample in samples {
            let scripts = try context.fetch(FetchDescriptor<Script>())
            let hash = ScriptImporter.hash(sample.text)
            if let stored = scripts.first(where: { $0.sampleID == sample.id }) {
                if stored.sourceHash != hash, !stored.editedInEarwig {
                    let updatedAt = stored.updatedAt
                    _ = try importer.replace(stored, with: sample.text, replacingEdits: true)
                    stored.updatedAt = updatedAt
                }
            } else if let own = scripts.first(where: { !$0.isSample && $0.sourceHash == hash }) {
                own.sampleID = sample.id
            } else {
                try importer.add(sample.text).sampleID = sample.id
            }
        }
        try context.save()
    }

    /// The samples' scripts in the order of `SampleScript.all`, from those given.
    static func ordered(_ scripts: [Script]) -> [Script] {
        let order = Dictionary(uniqueKeysWithValues: SampleScript.all.enumerated().map { ($1.id, $0) })
        return scripts.filter(\.isSample).sorted { (order[$0.sampleID ?? ""] ?? .max) < (order[$1.sampleID ?? ""] ?? .max) }
    }
}
