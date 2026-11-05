import Foundation

/// One word as the follow engine matches it (PRD §5.1): its normalised text and, for a
/// number, its value. A number is one word however it is written or said, so "1890",
/// "eighteen ninety" and the recogniser's digits are each one word worth 1890.
struct ScriptWord: Codable, Equatable, Hashable, Sendable {
    /// The normalised form. A number's is its value in digits.
    var text: String
    var number: Int?

    init(text: String, number: Int? = nil) {
        self.text = text
        self.number = number
    }

    static func number(_ value: Int) -> ScriptWord {
        ScriptWord(text: String(value), number: value)
    }
}

/// Reads written words (whitespace-separated tokens, as a phrase holds them) into script
/// words. Each token is one word, except that a run of number words is one word with its
/// value: cardinals ("three hundred", "twenty-one", "one hundred and fifty") and years said
/// as two pairs ("eighteen ninety", "nineteen oh five", "twenty twenty-four"). A run has one
/// reading, as Cutaway's normaliser: the longest, a year only when it is longer than the
/// cardinal. A token with no letters or digits ("—") is no word.
enum ScriptWords {

    /// A script word and the tokens it was read from, `tokens` as indices into the input.
    struct Group: Equatable, Sendable {
        let tokens: ClosedRange<Int>
        let word: ScriptWord?
    }

    /// Script words for a stretch of text, split on whitespace.
    static func words(in text: String) -> [ScriptWord] {
        groups(text.split(whereSeparator: \.isWhitespace).map(String.init)).compactMap(\.word)
    }

    /// One group per script word, plus one with no word for each token that has none.
    static func groups(_ tokens: [String]) -> [Group] {
        // Each token as normalised parts: one part, or a hyphenated number's pieces.
        var parts: [(token: Int, text: String)] = []
        var empty: [Int] = []
        for (index, token) in tokens.enumerated() {
            let pieces = token.split(whereSeparator: { "-‐‑".contains($0) }).compactMap { WordNormaliser.normalise(String($0)) }
            if pieces.count > 1, pieces.allSatisfy(isNumberWord) {
                parts += pieces.map { (index, $0) }
            } else if let whole = WordNormaliser.normalise(token) {
                parts.append((index, whole))
            } else {
                empty.append(index)
            }
        }

        var groups: [Group] = []
        let texts = parts.map(\.text)
        var i = 0
        while i < parts.count {
            if let (value, length) = readNumber(texts, at: i) {
                groups.append(Group(tokens: parts[i].token...parts[i + length - 1].token, word: .number(value)))
                i += length
            } else {
                groups.append(Group(tokens: parts[i].token...parts[i].token, word: ScriptWord(text: texts[i])))
                i += 1
            }
        }
        groups += empty.map { Group(tokens: $0...$0, word: nil) }
        return groups.sorted { $0.tokens.lowerBound < $1.tokens.lowerBound }
    }

    // MARK: - Numbers

    /// A number starting at `index`, as its value and how many parts it takes.
    static func readNumber(_ words: [String], at index: Int) -> (Int, Int)? {
        if let value = digits(words[index]) { return (value, 1) }
        let cardinal = readCardinal(words, at: index)
        let year = readYear(words, at: index)
        switch (cardinal, year) {
        case let (c?, y?): return y.1 > c.1 ? y : c
        case let (c?, nil): return c
        case let (nil, y?): return y
        default: return nil
        }
    }

    /// A number in digits, with thousands commas (already dropped by the normaliser) and an
    /// ordinal ending allowed: "1890", "1500", "21st".
    private static func digits(_ word: String) -> Int? {
        var body = Substring(word)
        for suffix in ["st", "nd", "rd", "th"] where body.hasSuffix(suffix) && body.count > 2 {
            body = body.dropLast(2)
            break
        }
        guard !body.isEmpty, body.count <= 9, body.allSatisfy(\.isASCII), body.allSatisfy(\.isNumber) else { return nil }
        return Int(body)
    }

    private static func isNumberWord(_ word: String) -> Bool {
        units[word] != nil || tens[word] != nil || word == "hundred" || word == "thousand"
    }

    /// 0 to 99 in words: "seven", "fifteen", "forty", "forty five".
    private static func readBelowHundred(_ words: [String], at index: Int) -> (Int, Int)? {
        guard index < words.count else { return nil }
        if let ten = tens[words[index]] {
            if index + 1 < words.count, let unit = units[words[index + 1]], (1...9).contains(unit) {
                return (ten + unit, 2)
            }
            return (ten, 1)
        }
        if let unit = units[words[index]] { return (unit, 1) }
        return nil
    }

    /// 0 to 999: "three hundred", "three hundred and twenty", "one hundred fifty".
    private static func readBelowThousand(_ words: [String], at index: Int) -> (Int, Int)? {
        guard index < words.count else { return nil }
        if let unit = units[words[index]], (1...9).contains(unit),
           index + 1 < words.count, words[index + 1] == "hundred" {
            let value = unit * 100
            let next = index + 2
            if next < words.count, words[next] == "and", let rest = readBelowHundred(words, at: next + 1), rest.0 > 0 {
                return (value + rest.0, 3 + rest.1)
            }
            if let rest = readBelowHundred(words, at: next), rest.0 > 0 {
                return (value + rest.0, 2 + rest.1)
            }
            return (value, 2)
        }
        return readBelowHundred(words, at: index)
    }

    /// Below a million: "four thousand", "two thousand and five", "one thousand two hundred".
    private static func readCardinal(_ words: [String], at index: Int) -> (Int, Int)? {
        guard let head = readBelowThousand(words, at: index) else { return nil }
        let next = index + head.1
        guard head.0 > 0, next < words.count, words[next] == "thousand" else { return head }
        let value = head.0 * 1000
        let after = next + 1
        if after < words.count, words[after] == "and", let rest = readBelowHundred(words, at: after + 1), rest.0 > 0 {
            return (value + rest.0, head.1 + 2 + rest.1)
        }
        if let rest = readBelowThousand(words, at: after), rest.0 > 0 {
            return (value + rest.0, head.1 + 1 + rest.1)
        }
        return (value, head.1 + 1)
    }

    /// A year said as two pairs: "eighteen ninety" (1890), "nineteen oh five" (1905),
    /// "nineteen hundred" (1900), "twenty twenty four" (2024).
    private static func readYear(_ words: [String], at index: Int) -> (Int, Int)? {
        guard let century = readBelowHundred(words, at: index), (10...99).contains(century.0) else { return nil }
        let next = index + century.1
        guard next < words.count else { return nil }
        if words[next] == "oh" || words[next] == "o",
           next + 1 < words.count, let unit = units[words[next + 1]], (1...9).contains(unit) {
            return (century.0 * 100 + unit, century.1 + 2)
        }
        if words[next] == "hundred", century.0 >= 11 {
            return (century.0 * 100, century.1 + 1)
        }
        if let pair = readBelowHundred(words, at: next), (10...99).contains(pair.0) {
            return (century.0 * 100 + pair.0, century.1 + pair.1)
        }
        return nil
    }

    private static let units: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
        "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
        "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
    ]

    private static let tens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70,
        "eighty": 80, "ninety": 90,
    ]
}
