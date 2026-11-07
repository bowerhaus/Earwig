import Foundation

/// What the cue voice says at the start of a take (PRD §4.2, §4.5; plan 004, decision 6):
/// with cues on, the step's number or shot ID, its title and its `Shows:` text; then the slate,
/// "Step 3, take 2." The synthesiser reads digits as words. A shot ID is spelled out so it is
/// said as letters and numbers: "W31" is "W 3 1".
enum Slate {
    /// `directions` are the step's title and `Shows:` text, read first; `nil` with cues off.
    static func text(number: Int, shotID: String?, take: Int, directions: [String]?) -> String {
        let name = shotID.flatMap(spelled) ?? "Step \(number)"
        let slate = "\(name), take \(take)."
        guard let directions else { return slate }
        let spoken = ([name] + directions)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(sentence)
        return (spoken + [slate]).joined(separator: " ")
    }

    /// The slate for a step of a script. With cues on and inline directions chimed, the step's
    /// inline directions are read too, before the take, since the chime only marks the point.
    static func text(for step: Step, take: Int, cuesOn: Bool, inline: InlineDirections) -> String {
        let shows = step.directions.first { $0.kind == .shows }?.text ?? ""
        let ahead = inline == .chime ? inlineDirections(in: step.phraseList) : []
        return text(number: step.number, shotID: step.shotID, take: take, directions: cuesOn ? [step.title, shows] + ahead : nil)
    }

    /// Words of the line to place a direction by.
    static let placeWords = 4

    /// Each inline direction of a step, told where it falls: "At “Most of these boats”, gesture
    /// to the boats." by the words after it, or "After “…”" by the words before it at a line's end.
    static func inlineDirections(in list: PhraseList) -> [String] {
        list.phrases.indices.compactMap { index in
            let cue = list.phrases[index]
            guard cue.kind == .cue else { return nil }
            let direction = lowercasedFirst(cue.phrase.text.trimmingCharacters(in: .whitespacesAndNewlines))
            guard !direction.isEmpty else { return nil }
            let line = list.phrases.indices.filter { list.phrases[$0].line == cue.line && list.phrases[$0].kind == .spoken }
            if let next = line.first(where: { $0 > index }) {
                return "At “\(words(of: list.phrases[next].phrase, first: true))”, \(direction)."
            }
            if let previous = line.last(where: { $0 < index }) {
                return "After “\(words(of: list.phrases[previous].phrase, first: false))”, \(direction)."
            }
            return sentence(direction.prefix(1).uppercased() + direction.dropFirst())
        }
    }

    private static func words(of phrase: Phrase, first: Bool) -> String {
        let tokens = phrase.text.split(whereSeparator: \.isWhitespace)
        let picked = first ? tokens.prefix(placeWords) : tokens.suffix(placeWords)
        return picked.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?…"))
    }

    /// Lower case at the start, as it follows a comma. Only heard, never shown, so a name lowered
    /// is said the same.
    private static func lowercasedFirst(_ text: String) -> String {
        text.prefix(1).lowercased() + text.dropFirst()
    }

    /// Each letter and digit apart, anything else dropped; `nil` when nothing is left.
    static func spelled(_ shotID: String) -> String? {
        let characters = shotID.filter { $0.isLetter || $0.isNumber }.map(String.init)
        return characters.isEmpty ? nil : characters.joined(separator: " ")
    }

    /// Ends with a full stop unless it already ends a sentence.
    private static func sentence(_ text: String) -> String {
        guard let last = text.last else { return text }
        return ".!?…".contains(last) ? text : text + "."
    }
}
