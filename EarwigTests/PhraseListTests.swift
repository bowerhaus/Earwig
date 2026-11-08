import Foundation
@testable import Earwig
import Testing

struct PhraseListTests {

    private let harbour = ScriptParser.parse(SampleScript.harbourWalk)

    @Test func inlineDirectionsAreCuePhrasesInPlace() {
        let list = PhraseList(lines: harbour.steps[0].lines)
        let lastLine = list.phrases.filter { $0.line == 3 }
        #expect(lastLine.first?.kind == .cue)
        #expect(lastLine.first?.phrase.text == "Gesture to the boats")
        #expect(lastLine.dropFirst().allSatisfy { $0.kind == .spoken })
        #expect(lastLine.dropFirst().first?.phrase.text.hasPrefix("Most of these boats") == true)
    }

    @Test func phrasesKnowTheirLinesInOrder() {
        let list = PhraseList(lines: harbour.steps[1].lines)
        let lines = list.phrases.map(\.line)
        #expect(lines == lines.sorted())
        #expect(Set(lines) == [0, 1, 2, 3])
        #expect(list.phrases.allSatisfy { $0.phrase.tokens.count <= 12 })
    }

    @Test func cueWordsAreNotScriptWords() {
        let list = PhraseList(lines: ["[Point] Look there."])
        #expect(list.scriptWords.map(\.text) == ["look", "there"])
    }

    @Test func aYearIsOneScriptWord() {
        let list = PhraseList(lines: harbour.steps[1].lines)
        let first = list.spoken[0].phrase.scriptWords
        #expect(first.map(\.text).prefix(6) == ["the", "sea", "wall", "was", "built", "in"])
        #expect(first[6] == .number(1890))
    }

    @Test func roundTripsThroughModelJSON() {
        let list = PhraseList(lines: harbour.steps[2].lines)
        #expect(ModelJSON.decode(PhraseList.self, from: ModelJSON.encode(list)) == list)
    }

    @Test func versionDecidesWhetherItIsCurrent() {
        #expect(PhraseList(lines: ["Hello."]).isCurrent)
        #expect(!PhraseList(parserVersion: 0).isCurrent)
        #expect(ModelJSON.decode(PhraseList.self, from: Data()) == nil)
    }
}

struct PhraseListSentenceTests {

    private let list = PhraseList(lines: [
        "Morning! The plan is simple: along the sea wall, up the cliff path, and back through the village for a late breakfast.",
        "[Point] Look there.",
    ])

    @Test func aSentenceRunsAcrossItsPhrases() {
        // 0 "Morning!", 1 and 2 the long sentence, 3 the cue, 4 "Look there."
        #expect(list.phrases.count == 5)
        #expect(list.sentence(containing: 0) == 0...0)
        #expect(list.sentence(containing: 1) == 1...2)
        #expect(list.sentence(containing: 2) == 1...2)
    }

    @Test func aCueBelongsToTheSentenceAfterItAndALineEndsOne() {
        #expect(list.sentence(containing: 4) == 3...4)
        #expect(list.sentence(containing: 3) == 3...4)
        #expect(list.sentence(containing: 9) == 9...9)
    }
}
