@testable import Earwig
import Testing

struct PhraseTimingTests {

    private func phrase(_ text: String) -> Phrase {
        Phrase(tokens: text.split(separator: " ").map(String.init))
    }

    @Test func eachScriptWordTakesItsTokensStart() {
        let timing = PhraseTiming(phrase: phrase("along the sea wall"), tokenStarts: [0, 0.4, 0.6, 0.9], duration: 1.5)
        #expect(timing.wordStarts == [0, 0.4, 0.6, 0.9])
        #expect(timing.duration == 1.5)
    }

    @Test func aDashIsTimedButHasNoScriptWord() {
        let timing = PhraseTiming(phrase: phrase("the path — steep"), tokenStarts: [0, 0.3, 0.7, 0.9], duration: 1.4)
        #expect(timing.wordStarts == [0, 0.3, 0.9])
    }

    @Test func aNumberInWordsIsOneWord() {
        let spoken = phrase("about three hundred feet")
        #expect(spoken.tokens.count == 3)
        let timing = PhraseTiming(phrase: spoken, tokenStarts: [0, 0.4, 1.1], duration: 1.6)
        #expect(timing.wordStarts == [0, 0.4, 1.1])
    }

    @Test func aMissingMarkerIsSpacedBetweenItsNeighbours() {
        let timing = PhraseTiming(phrase: phrase("one two three four five"), tokenStarts: [0, nil, nil, 0.9, 1.2], duration: 1.6)
        #expect(timing.wordStarts.count == 5)
        #expect(abs(timing.wordStarts[1] - 0.3) < 1e-9)
        #expect(abs(timing.wordStarts[2] - 0.6) < 1e-9)
        #expect(timing.wordStarts[3] == 0.9)
    }

    @Test func missingMarkersAtTheStartAndEnd() {
        let start = PhraseTiming(phrase: phrase("one two three"), tokenStarts: [nil, nil, 1.0], duration: 1.5)
        #expect(start.wordStarts == [0, 0.5, 1.0])
        let end = PhraseTiming(phrase: phrase("one two three"), tokenStarts: [0, 0.4, nil], duration: 1.2)
        #expect(abs(end.wordStarts[2] - 0.8) < 1e-9)
        let none = PhraseTiming(phrase: phrase("one two"), tokenStarts: [], duration: 1)
        #expect(none.wordStarts == [0, 0.5])
    }

    @Test func startsNeverGoBackwards() {
        let timing = PhraseTiming(phrase: phrase("one two three"), tokenStarts: [0, 0.6, 0.5], duration: 1)
        #expect(timing.wordStarts == [0, 0.6, 0.6])
    }

    @Test func theTimingsReachTheEngine() {
        let list = PhraseList(lines: ["Morning! [Wave] We're starting at the old harbour."])
        let follow = FollowScript(phraseList: list) { index in
            PhraseTiming(phrase: list.phrases[index].phrase, tokenStarts: list.phrases[index].phrase.tokens.indices.map { Double($0) * 0.3 }, duration: 2)
        }
        #expect(follow.phrases.map(\.kind) == [.spoken, .cue, .spoken])
        #expect(follow.phrases[2].wordStarts.count == 6)
        #expect(follow.phrases[2].wordStarts[1] == 0.3)
    }
}
