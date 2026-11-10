import CryptoKit
import Foundation
import SwiftData

/// Pasted or written text into stored scripts (PRD §4.1, Flow 4): a new script, the same one
/// again, or a new version of one, keeping its takes, renderings, cues setting and start step.
/// Text written in Earwig's editor comes in by `create(_:)` and `edit(_:with:)` (plan 015).
@MainActor
struct ScriptImporter {
    let context: ModelContext

    enum Outcome: Equatable {
        case added, unchanged, replaced
        /// Nothing done: the paste would replace text written or changed in Earwig, so it asks
        /// first and is made again with `replacingEdits` (plan 015, decision 8).
        case wouldReplaceEdits
    }

    struct Result {
        let script: Script
        let outcome: Outcome
    }

    enum ImportError: LocalizedError, Equatable {
        case noSteps, noWords

        var errorDescription: String? {
            switch self {
            case .noSteps: "There is no script on the clipboard."
            case .noWords: "The script on the clipboard has nothing to say."
            }
        }
    }

    /// Paste on the Scripts screen: the same text opens its script, the same stated title
    /// replaces that script's text, anything else is a new script. A title taken from a first
    /// line or first step never replaces another script, and a sample's text is never replaced
    /// by a paste (plan 011, decision 6).
    func paste(_ text: String, replacingEdits: Bool = false) throws -> Result {
        let cleaned = Self.cleaned(text)
        let parsed = try Self.parsed(cleaned)
        let hash = Self.hash(cleaned)
        let scripts = try context.fetch(FetchDescriptor<Script>())
        if let same = scripts.first(where: { $0.sourceHash == hash }) {
            return Result(script: same, outcome: .unchanged)
        }
        if parsed.titleIsStated,
           let named = scripts.first(where: { !$0.isSample && $0.title.caseInsensitiveCompare(parsed.title) == .orderedSame }) {
            if named.editedInEarwig, !replacingEdits { return Result(script: named, outcome: .wouldReplaceEdits) }
            apply(parsed, text: cleaned, hash: hash, to: named)
            named.editedInEarwig = false
            return Result(script: named, outcome: .replaced)
        }
        let script = Script()
        context.insert(script)
        apply(parsed, text: cleaned, hash: hash, to: script)
        return Result(script: script, outcome: .added)
    }

    /// A new script from the text, matching nothing stored: for the samples' seeder (plan 011).
    func add(_ text: String) throws -> Script {
        let cleaned = Self.cleaned(text)
        let parsed = try Self.parsed(cleaned)
        let script = Script()
        context.insert(script)
        apply(parsed, text: cleaned, hash: Self.hash(cleaned), to: script)
        return script
    }

    /// New in the editor (plan 015, decision 3): always a new script, never replacing one by its
    /// title. Text identical to a stored script's opens that script, as a paste does.
    func create(_ text: String) throws -> Result {
        let cleaned = Self.cleaned(text)
        let parsed = try Self.parsed(cleaned)
        let hash = Self.hash(cleaned)
        if let same = try context.fetch(FetchDescriptor<Script>()).first(where: { $0.sourceHash == hash }) {
            return Result(script: same, outcome: .unchanged)
        }
        let script = Script()
        context.insert(script)
        apply(parsed, text: cleaned, hash: hash, to: script)
        script.editedInEarwig = true
        return Result(script: script, outcome: .added)
    }

    /// Paste new version on the Script screen, whatever the new text's title.
    func replace(_ script: Script, with text: String, replacingEdits: Bool = false) throws -> Result {
        let cleaned = Self.cleaned(text)
        let parsed = try Self.parsed(cleaned)
        let hash = Self.hash(cleaned)
        if hash == script.sourceHash { return Result(script: script, outcome: .unchanged) }
        if script.editedInEarwig, !replacingEdits { return Result(script: script, outcome: .wouldReplaceEdits) }
        apply(parsed, text: cleaned, hash: hash, to: script)
        script.editedInEarwig = false
        return Result(script: script, outcome: .replaced)
    }

    /// Edit in the editor (plan 015, decision 3): as Paste New Version, keeping the takes,
    /// renderings, cues setting and start step, and marking the script as changed in Earwig.
    /// A sample is never edited; Edit a Copy makes a new script by `create(_:)`.
    func edit(_ script: Script, with text: String) throws -> Result {
        guard !script.isSample else { return Result(script: script, outcome: .unchanged) }
        let cleaned = Self.cleaned(text)
        let parsed = try Self.parsed(cleaned)
        let hash = Self.hash(cleaned)
        if hash == script.sourceHash { return Result(script: script, outcome: .unchanged) }
        apply(parsed, text: cleaned, hash: hash, to: script)
        script.editedInEarwig = true
        return Result(script: script, outcome: .replaced)
    }

    /// Whether the text could be saved, and why not: for the editor's line (plan 015, decision 2).
    static func check(_ text: String) -> Swift.Result<ParsedScript, ImportError> {
        do { return .success(try parsed(cleaned(text))) } catch let error as ImportError { return .failure(error) } catch {
            return .failure(.noSteps)
        }
    }

    /// Rebuilds the steps from the stored source text when they came from an older parser
    /// (plan 002, decision 6). Returns whether it did.
    @discardableResult
    func refreshIfStale(_ script: Script) -> Bool {
        let steps = script.steps ?? []
        guard steps.isEmpty || steps.contains(where: { !$0.phraseList.isCurrent }) else { return false }
        let parsed = ScriptParser.parse(script.sourceText)
        let updatedAt = script.updatedAt
        apply(parsed, text: script.sourceText, hash: script.sourceHash, to: script)
        script.updatedAt = updatedAt
        return true
    }

    private func apply(_ parsed: ParsedScript, text: String, hash: String, to script: Script) {
        for step in script.steps ?? [] { context.delete(step) }
        script.steps = []
        script.title = parsed.title
        script.sourceText = text
        script.sourceHash = hash
        script.format = parsed.format
        script.preamble = parsed.preamble
        script.updatedAt = Date()
        for (index, parsedStep) in parsed.steps.enumerated() {
            let step = Step(sortOrder: index, number: parsedStep.number, title: parsedStep.title)
            step.directions = parsedStep.directions
            step.lines = parsedStep.lines
            step.phraseList = PhraseList(lines: parsedStep.lines)
            context.insert(step)
            step.script = script
        }
        script.lastStep = min(script.lastStep, max(parsed.steps.count - 1, 0))
    }

    private static func parsed(_ text: String) throws -> ParsedScript {
        let parsed = ScriptParser.parse(text)
        guard !parsed.steps.isEmpty else { throw ImportError.noSteps }
        guard parsed.hasSpokenWords else { throw ImportError.noWords }
        return parsed
    }

    /// Line endings made `\n`, trailing whitespace trimmed from each line and from the end.
    static func cleaned(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { line in
                var line = Substring(line)
                while let last = line.last, last.isWhitespace { line = line.dropLast() }
                return String(line)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(cleaned(text).utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
