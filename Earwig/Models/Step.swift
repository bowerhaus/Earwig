import Foundation
import SwiftData

/// A numbered section of a script (PRD §3, §6.1). Directions, lines and phrases are Codable
/// values stored as JSON.
@Model
final class Step {
    /// Its place in the script, from 0.
    var sortOrder: Int = 0
    /// As the script numbers it.
    var number: Int = 0
    var title: String = ""
    /// A shot ID said in the slate instead of the step number, when the script has one.
    var shotID: String?
    var directionsData: Data = Data()
    var linesData: Data = Data()
    var phrasesData: Data = Data()
    var script: Script?

    init(sortOrder: Int = 0, number: Int = 0, title: String = "") {
        self.sortOrder = sortOrder
        self.number = number
        self.title = title
    }

    var directions: [Direction] {
        get { ModelJSON.decode([Direction].self, from: directionsData) ?? [] }
        set { directionsData = ModelJSON.encode(newValue) }
    }

    /// Spoken lines as written, `[directions]` included.
    var lines: [String] {
        get { ModelJSON.decode([String].self, from: linesData) ?? [] }
        set { linesData = ModelJSON.encode(newValue) }
    }

    /// The stored phrases. Version 0 when none are stored, so it reads as stale.
    var phraseList: PhraseList {
        get { ModelJSON.decode(PhraseList.self, from: phrasesData) ?? PhraseList(parserVersion: 0) }
        set { phrasesData = ModelJSON.encode(newValue) }
    }

    /// The title, or "Step 3" when it has none.
    var heading: String { title.isEmpty ? "Step \(number)" : title }
}
