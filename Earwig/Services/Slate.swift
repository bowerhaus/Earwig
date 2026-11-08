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

    /// The slate for a step of a script.
    static func text(for step: Step, take: Int, cuesOn: Bool) -> String {
        let shows = step.directions.first { $0.kind == .shows }?.text ?? ""
        return text(number: step.number, shotID: step.shotID, take: take, directions: cuesOn ? [step.title, shows] : nil)
    }

    /// What the presenter says back in `.slateWithReply` (plan 005, decision 5), as the engine
    /// hears it: the step's number or shot ID, "take", the take number. "3 take 2"; a shot ID's
    /// letters and digits apart, "W 3 1 take 2".
    static func replyWords(number: Int, shotID: String?, take: Int) -> [ScriptWord] {
        let name = shotID.flatMap(spelled) ?? String(number)
        return ScriptWords.words(in: "\(name) take \(take)")
    }

    /// The reply words for a step of a script.
    static func replyWords(for step: Step, take: Int) -> [ScriptWord] {
        replyWords(number: step.number, shotID: step.shotID, take: take)
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
