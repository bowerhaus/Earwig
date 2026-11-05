import Foundation

/// Turns one written or heard word into a comparable form (PRD §5.1): lower case, diacritics
/// and width folded, and everything but letters and digits dropped, so "There's," is
/// "theres" and "Café" is "cafe".
///
/// Numbers are grouped and read by `ScriptWords`, which uses this. Folding British and
/// American spellings, compounds and contractions is the matcher's (stage 3).
enum WordNormaliser {

    /// The normalised words in a stretch of text, split on whitespace, dashes and slashes.
    static func words(in text: String) -> [String] {
        text
            .components(separatedBy: separators)
            .compactMap(normalise)
    }

    /// One token normalised, or `nil` when it has no letters or digits ("—", "…").
    static func normalise(_ token: String) -> String? {
        let folded = token
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_GB"))
            .lowercased()
        let kept = String(String.UnicodeScalarView(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
        return kept.isEmpty ? nil : kept
    }

    private static let separators = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: "-‐‑‒–—/"))
}
