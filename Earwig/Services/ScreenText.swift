import Foundation

/// One word of the take's step as the Prompt screen shows it in Screen mode (plan 008,
/// decision 4): a script word, or a bracketed cue, which is shown but never followed.
struct ScreenWord: Equatable, Sendable, Identifiable {
    /// Its place on the screen, from 0.
    let id: Int
    let text: String
    /// The flat index of the script word it is, as the engine counts them; `nil` for a token
    /// with no letters or digits, and for a cue.
    let word: Int?
    let phrase: Int
    let line: Int
    let isCue: Bool
    /// The first word of a script line, which starts a new paragraph.
    let startsParagraph: Bool
}

/// The take's step as words for the screen, from its phrases (plan 008, decision 4). A number
/// said in words is one word, as the engine counts it; a cue is its words, in brackets.
enum ScreenText {
    static func words(phraseList: PhraseList, firstWord: [Int]) -> [ScreenWord] {
        var words: [ScreenWord] = []
        var line: Int?
        for (index, stepPhrase) in phraseList.phrases.enumerated() {
            let starts = { () -> Bool in
                defer { line = stepPhrase.line }
                return line != stepPhrase.line
            }
            if stepPhrase.kind == .cue {
                // A word at a time, so a long direction wraps; the brackets on its first and last.
                let parts = stepPhrase.phrase.text.split(whereSeparator: \.isWhitespace).map(String.init)
                for (place, part) in parts.enumerated() {
                    let text = (place == 0 ? "[" : "") + part + (place == parts.count - 1 ? "]" : "")
                    words.append(ScreenWord(id: words.count, text: text, word: nil, phrase: index, line: stepPhrase.line,
                                            isCue: true, startsParagraph: starts()))
                }
                continue
            }
            var word = firstWord.indices.contains(index) ? firstWord[index] : 0
            for token in stepPhrase.phrase.tokens {
                var flat: Int?
                if token.word != nil {
                    flat = word
                    word += 1
                }
                words.append(ScreenWord(id: words.count, text: token.text, word: flat, phrase: index, line: stepPhrase.line,
                                        isCue: false, startsParagraph: starts()))
            }
        }
        return words
    }
}
