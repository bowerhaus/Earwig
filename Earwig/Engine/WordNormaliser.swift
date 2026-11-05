import Foundation

/// Turns script words and heard words into one comparable form (PRD §5.1): lower case,
/// diacritics and punctuation stripped, apostrophes dropped, and whole numbers written out,
/// so "20" heard matches "twenty" in the script.
///
/// British and American spelling folding (Cutaway's `pipeline/script.py`) is for stage 3.
enum WordNormaliser {

    /// The normalised words in a stretch of text, split on whitespace and dashes. A number
    /// becomes as many words as it takes to say it.
    static func words(in text: String) -> [String] {
        text
            .components(separatedBy: separators)
            .flatMap(normaliseToken)
    }

    /// One token normalised. Usually one word, but a number written in digits expands to
    /// several ("120" is "one hundred and twenty") and pure punctuation gives none.
    static func normaliseToken(_ token: String) -> [String] {
        let folded = token
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_GB"))
            .lowercased()
        let digitsOnly = folded.filter { $0.isNumber || $0 == "," }
        if !digitsOnly.isEmpty, digitsOnly.allSatisfy({ $0.isASCII }),
           folded.trimmingCharacters(in: .punctuationCharacters) == digitsOnly.trimmingCharacters(in: .punctuationCharacters),
           let value = Int(digitsOnly.replacingOccurrences(of: ",", with: "")) {
            return spelledOut(value)
        }
        let kept = String(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
        return kept.isEmpty ? [] : [kept]
    }

    /// A non-negative whole number in British English words, below a million.
    static func spelledOut(_ value: Int) -> [String] {
        guard value >= 0, value < 1_000_000 else { return [String(value)] }
        if value == 0 { return ["zero"] }
        var words: [String] = []
        let thousands = value / 1000
        let rest = value % 1000
        if thousands > 0 {
            words += belowThousand(thousands) + ["thousand"]
            if rest > 0, rest < 100 { words.append("and") }
        }
        if rest > 0 { words += belowThousand(rest) }
        return words
    }

    private static func belowThousand(_ value: Int) -> [String] {
        var words: [String] = []
        let hundreds = value / 100
        let rest = value % 100
        if hundreds > 0 {
            words += [units[hundreds], "hundred"]
            if rest > 0 { words.append("and") }
        }
        if rest > 0 { words += belowHundred(rest) }
        return words
    }

    private static func belowHundred(_ value: Int) -> [String] {
        if value < 20 { return [units[value]] }
        let ten = tens[value / 10]
        return value % 10 == 0 ? [ten] : [ten, units[value % 10]]
    }

    private static let separators = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: "-‐‑‒–—/"))

    private static let units = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen",
    ]

    private static let tens = [
        "", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety",
    ]
}
