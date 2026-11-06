import Foundation

/// How well a heard word matches a script word. An exact match beats a near one.
enum MatchStrength: Int, Comparable, Sendable {
    /// Within the edit distance, or digits still building up to the script's number.
    case near = 1
    /// The same form, the same number, a spelling pair, a compound or a contraction.
    case exact = 2

    static func < (a: MatchStrength, b: MatchStrength) -> Bool { a.rawValue < b.rawValue }
}

/// The folds the matcher makes between what is heard and what is written (PRD §5.1, plan 003
/// decision 5): numbers by value, British and American spellings, compounds and contractions.
/// Every form here is already normalised (lower case, no punctuation, apostrophes dropped).
enum WordFolding {

    /// Whether one heard word matches one script word. `allowPrefix` lets digits that are
    /// still arriving ("18" on the way to "1890") match, for the last word of an interim result.
    static func match(_ heard: ScriptWord, _ script: ScriptWord, allowPrefix: Bool = false) -> MatchStrength? {
        if let value = script.number {
            guard let heardValue = heard.number else { return nil }
            if heardValue == value { return .exact }
            if allowPrefix, heard.text.count < script.text.count, script.text.hasPrefix(heard.text) { return .near }
            return nil
        }
        guard heard.number == nil else { return nil }
        if heard.text == script.text || spellingKey(heard.text) == spellingKey(script.text) { return .exact }
        let length = min(heard.text.count, script.text.count)
        guard length >= 5 else { return nil }
        let limit = length >= 8 ? 2 : 1
        return editDistance(heard.text, script.text, limit: limit) <= limit ? .near : nil
    }

    /// Whether one word stands for two on the other side: a compound written or heard joined
    /// ("seawall" for "sea wall") or a contraction ("theres" for "there is"). Symmetric in use:
    /// the matcher asks it both ways.
    static func matchesPair(_ single: ScriptWord, _ first: ScriptWord, _ second: ScriptWord) -> Bool {
        guard single.number == nil, first.number == nil, second.number == nil else { return false }
        if single.text == first.text + second.text { return true }
        return contractions[single.text]?.contains([first.text, second.text]) == true
    }

    /// The edit distance between two words with adjacent transpositions counted as one, or
    /// more than `limit` when it is over it.
    static func editDistance(_ a: String, _ b: String, limit: Int) -> Int {
        let a = Array(a), b = Array(b)
        if abs(a.count - b.count) > limit { return limit + 1 }
        if a.isEmpty || b.isEmpty { return max(a.count, b.count) }
        var previous2 = [Int](repeating: 0, count: b.count + 1)
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            var rowMin = current[0]
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                var value = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    value = min(value, previous2[j - 2] + 1)
                }
                current[j] = value
                rowMin = min(rowMin, value)
            }
            if rowMin > limit { return limit + 1 }
            (previous2, previous, current) = (previous, current, previous2)
        }
        return previous[b.count]
    }

    // MARK: - Tables

    /// One form for both spellings of a pair the edit distance does not catch (too short, or
    /// too far apart). Most British and American pairs ("colour", "realise", "centre") are
    /// within it.
    private static func spellingKey(_ word: String) -> String { spellings[word] ?? word }

    private static let spellings: [String: String] = {
        let pairs = [
            ("gray", "grey"), ("tire", "tyre"), ("tires", "tyres"), ("curb", "kerb"), ("plow", "plough"),
            ("aluminum", "aluminium"), ("mom", "mum"), ("ax", "axe"), ("odor", "odour"), ("odors", "odours"),
            ("donut", "doughnut"), ("donuts", "doughnuts"), ("sulfur", "sulphur"), ("maneuver", "manoeuvre"),
            ("pajamas", "pyjamas"), ("program", "programme"), ("catalog", "catalogue"), ("dialog", "dialogue"),
            ("mold", "mould"), ("cozy", "cosy"), ("jewelry", "jewellery"), ("cannot", "cant"),
        ]
        var table: [String: String] = [:]
        for (american, british) in pairs { table[american] = british }
        return table
    }()

    /// Contractions with apostrophes dropped, and what they stand for.
    static let contractions: [String: [[String]]] = [
        "theres": [["there", "is"], ["there", "has"]],
        "its": [["it", "is"], ["it", "has"]],
        "thats": [["that", "is"]],
        "whats": [["what", "is"]],
        "heres": [["here", "is"]],
        "wheres": [["where", "is"]],
        "whos": [["who", "is"]],
        "hows": [["how", "is"]],
        "hes": [["he", "is"], ["he", "has"]],
        "shes": [["she", "is"], ["she", "has"]],
        "lets": [["let", "us"]],
        "im": [["i", "am"]],
        "ive": [["i", "have"]],
        "id": [["i", "would"], ["i", "had"]],
        "ill": [["i", "will"]],
        "youre": [["you", "are"]],
        "youve": [["you", "have"]],
        "youll": [["you", "will"]],
        "youd": [["you", "would"], ["you", "had"]],
        "were": [["we", "are"]],
        "weve": [["we", "have"]],
        "well": [["we", "will"]],
        "wed": [["we", "would"], ["we", "had"]],
        "theyre": [["they", "are"]],
        "theyve": [["they", "have"]],
        "theyll": [["they", "will"]],
        "theyd": [["they", "would"], ["they", "had"]],
        "dont": [["do", "not"]],
        "doesnt": [["does", "not"]],
        "didnt": [["did", "not"]],
        "cant": [["can", "not"]],
        "wont": [["will", "not"]],
        "isnt": [["is", "not"]],
        "arent": [["are", "not"]],
        "wasnt": [["was", "not"]],
        "werent": [["were", "not"]],
        "havent": [["have", "not"]],
        "hasnt": [["has", "not"]],
        "hadnt": [["had", "not"]],
        "wouldnt": [["would", "not"]],
        "shouldnt": [["should", "not"]],
        "couldnt": [["could", "not"]],
        "mustnt": [["must", "not"]],
    ]
}
