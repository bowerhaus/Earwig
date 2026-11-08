@testable import Earwig
import Testing

/// The step's words for the screen (plan 008, decision 4).
struct ScreenTextTests {

    private func words(_ lines: [String], cuesOn: Bool = true) -> [ScreenWord] {
        let all = PhraseList(lines: lines)
        let list = PhraseList(parserVersion: all.parserVersion, phrases: all.phrases.filter { cuesOn || $0.kind == .spoken })
        return ScreenText.words(phraseList: list, firstWord: FollowScript(phraseList: list).firstWord)
    }

    @Test func eachWordKnowsItsScriptWord() {
        let shown = words(["We follow the footpath. Down to the sea."])
        #expect(shown.map(\.text) == ["We", "follow", "the", "footpath.", "Down", "to", "the", "sea."])
        #expect(shown.map(\.word) == [0, 1, 2, 3, 4, 5, 6, 7])
        #expect(shown.map(\.phrase) == [0, 0, 0, 0, 1, 1, 1, 1])
        #expect(shown.map(\.id) == Array(0..<8))
    }

    @Test func eachScriptLineStartsAParagraph() {
        let shown = words(["The tide is out.", "Gulls wheel over."])
        #expect(shown.filter(\.startsParagraph).map(\.text) == ["The", "Gulls"])
        #expect(shown.map(\.line) == [0, 0, 0, 0, 1, 1, 1])
    }

    @Test func aCueIsItsWordsInBracketsWithNoScriptWord() {
        let shown = words(["We follow the footpath. [Point at the sea] Down to the sea."])
        let cue = shown.filter { $0.isCue }
        #expect(cue.map(\.text) == ["[Point", "at", "the", "sea]"])
        #expect(cue.allSatisfy { $0.word == nil && $0.phrase == 1 })
        #expect(words(["We go. [Point] Down."]).filter { $0.isCue }.map(\.text) == ["[Point]"])
        // The word after the cue goes on counting from the one before it.
        #expect(shown.first { $0.text == "Down" }?.word == 4)
    }

    @Test func aCueStartingALineStartsItsParagraph() {
        let shown = words(["The tide is out.", "[Look up] Gulls wheel over."])
        #expect(shown.filter(\.startsParagraph).map(\.text) == ["The", "[Look"])
    }

    @Test func aNumberSaidInWordsIsOneWord() {
        let shown = words(["Down to three hundred boats."])
        #expect(shown.map(\.text) == ["Down", "to", "three hundred", "boats."])
        #expect(shown.map(\.word) == [0, 1, 2, 3])
    }

    @Test func withCuesOffThereAreNoCues() {
        let shown = words(["We follow the footpath. [Point] Down to the sea."], cuesOn: false)
        #expect(!shown.contains { $0.isCue })
        #expect(shown.count == 8)
    }
}
