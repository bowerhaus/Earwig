import Foundation
import SwiftData

/// A phrase's rendered audio file and its word start times (PRD §6.1).
struct RenderedPhraseFile: Codable, Equatable, Sendable {
    /// File name in Application Support/Renderings/<script hash>/<voice>/.
    var file: String
    /// Seconds from the phrase's start to each token's start; `nil` where no marker came.
    var wordStarts: [Double?]
}

/// A script's phrases rendered in one voice at one rate (PRD §4.2, §6.1). Made from stage 4.
@Model
final class Rendering {
    var scriptHash: String = ""
    var voiceIdentifier: String = ""
    var rate: Double = 0.5
    var createdAt: Date = Date()
    /// `[String: RenderedPhraseFile]`, keyed by a phrase's identity (stage 4 defines it).
    var phrasesData: Data = Data()
    var script: Script?

    init(scriptHash: String = "", voiceIdentifier: String = "", rate: Double = 0.5) {
        self.scriptHash = scriptHash
        self.voiceIdentifier = voiceIdentifier
        self.rate = rate
    }

    var phrases: [String: RenderedPhraseFile] {
        get { ModelJSON.decode([String: RenderedPhraseFile].self, from: phrasesData) ?? [:] }
        set { phrasesData = ModelJSON.encode(newValue) }
    }
}
