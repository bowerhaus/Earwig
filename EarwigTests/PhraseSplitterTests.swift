import Foundation
@testable import Earwig
import Testing

struct PhraseSplitterTests {

    private let splitter = PhraseSplitter(maxWords: 12)

    private func texts(_ text: String) -> [String] {
        splitter.phrases(in: text).map(\.text)
    }

    @Test func shortSentencesAreOnePhraseEach() {
        #expect(texts("The tide is out. The sand is hard!") == ["The tide is out.", "The sand is hard!"])
    }

    @Test func lineBreaksEndPhrases() {
        #expect(texts("A gull on the post\nwatching the boats") == ["A gull on the post", "watching the boats"])
    }

    @Test func shortSentenceWithCommasIsNotSplit() {
        #expect(texts("First, the kettle, then the toast.") == ["First, the kettle, then the toast."])
    }

    @Test func longSentenceSplitsAtClauseBreaksPackingWhatFits() {
        let text = "On a clear morning, with the wind behind you, the walk along the cliff path takes an hour."
        #expect(texts(text) == [
            "On a clear morning, with the wind behind you,",
            "the walk along the cliff path takes an hour.",
        ])
    }

    @Test func prefersASemicolonToAComma() {
        let text = "The car park fills early, so come before nine; the café opens at ten, not before."
        #expect(texts(text) == [
            "The car park fills early, so come before nine;",
            "the café opens at ten, not before.",
        ])
    }

    @Test func dashesStartANewClause() {
        let text = "We packed the van the night before — tent, stove, two chairs and far too many biscuits."
        #expect(texts(text) == [
            "We packed the van the night before",
            "— tent, stove, two chairs and far too many biscuits.",
        ])
    }

    @Test func clauseLongerThanTheLimitIsCutEvenly() {
        let words = (1...20).map { "w\($0)" }.joined(separator: " ")
        let phrases = splitter.phrases(in: words + ".")
        #expect(phrases.map(\.tokens.count) == [10, 10])
    }

    @Test func closingQuotesDoNotHideASentenceEnd() {
        #expect(texts("She said “stop.” Then we went.") == ["She said “stop.”", "Then we went."])
    }

    @Test func tokensCarryRangesAndScriptWords() {
        let phrase = splitter.phrases(in: "Walk 20 metres, then stop.")[0]
        #expect(phrase.tokens.map(\.text) == ["Walk", "20", "metres,", "then", "stop."])
        #expect(phrase.tokens[1].range == NSRange(location: 5, length: 2))
        #expect(phrase.scriptWords.map(\.text) == ["walk", "20", "metres", "then", "stop"])
        #expect(phrase.scriptWords[1].number == 20)
        #expect(phrase.tokenIndex(containing: 8) == 2)
        #expect(phrase.tokenIndex(containing: 7) == 1)
    }

    @Test func aNumberInWordsIsOneTokenOverItsWords() {
        let phrase = splitter.phrases(in: "It climbs three hundred feet — steeply.")[0]
        #expect(phrase.tokens.map(\.text) == ["It", "climbs", "three hundred", "feet", "—", "steeply."])
        #expect(phrase.tokens[2].range == NSRange(location: 10, length: 13))
        #expect(phrase.tokens[2].word == .number(300))
        #expect(phrase.tokens[4].word == nil)
        #expect(phrase.scriptWords.count == 5)
        #expect(phrase.tokenIndex(containing: 16) == 2)
    }

    @Test func phrasesRoundTripThroughJSON() throws {
        let phrase = splitter.phrases(in: "The sea wall was built in 1890.")[0]
        let decoded = try JSONDecoder().decode(Phrase.self, from: JSONEncoder().encode(phrase))
        #expect(decoded == phrase)
    }
}
