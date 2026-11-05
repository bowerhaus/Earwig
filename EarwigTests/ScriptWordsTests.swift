@testable import Earwig
import Testing

struct ScriptWordsTests {

    private func words(_ text: String) -> [ScriptWord] { ScriptWords.words(in: text) }
    private func texts(_ text: String) -> [String] { words(text).map(\.text) }
    private func numbers(_ text: String) -> [Int?] { words(text).map(\.number) }

    @Test func plainWordsAreNormalisedOneEach() {
        #expect(texts("There's a gull, on the post!") == ["theres", "a", "gull", "on", "the", "post"])
        #expect(numbers("the post") == [nil, nil])
    }

    @Test func contractionsAndCompoundsAreNotSplitOrJoined() {
        #expect(texts("there's the sea wall and the well-known seawall") == ["theres", "the", "sea", "wall", "and", "the", "wellknown", "seawall"])
    }

    @Test func digitsAreOneNumber() {
        #expect(words("1890") == [.number(1890)])
        #expect(words("1,500 people") == [.number(1500), ScriptWord(text: "people")])
        #expect(words("4 miles,") == [.number(4), ScriptWord(text: "miles")])
        #expect(words("the 21st") == [ScriptWord(text: "the"), .number(21)])
        #expect(words("£20") == [.number(20)])
    }

    @Test func mixedTokensAreNotNumbers() {
        #expect(words("3pm") == [ScriptWord(text: "3pm")])
    }

    @Test func cardinalsInWordsAreOneNumber() {
        #expect(words("three hundred feet") == [.number(300), ScriptWord(text: "feet")])
        #expect(numbers("one hundred and fifty") == [150])
        #expect(numbers("one hundred fifty") == [150])
        #expect(numbers("twenty one") == [21])
        #expect(numbers("twenty-one") == [21])
        #expect(numbers("four thousand") == [4000])
        #expect(numbers("two thousand and five") == [2005])
        #expect(numbers("one thousand two hundred and fifty") == [1250])
        #expect(numbers("fifteen") == [15])
        #expect(numbers("zero") == [0])
    }

    @Test func yearsSaidInPairsAreOneNumber() {
        #expect(numbers("eighteen ninety") == [1890])
        #expect(numbers("nineteen oh five") == [1905])
        #expect(numbers("nineteen hundred") == [1900])
        #expect(numbers("twenty twenty four") == [2024])
        #expect(numbers("twenty twenty-four") == [2024])
    }

    @Test func aCardinalIsPreferredUnlessTheYearIsLonger() {
        #expect(numbers("twenty five") == [25])
        #expect(numbers("one two three") == [1, 2, 3])
    }

    @Test func andOutsideANumberIsAWord() {
        #expect(words("three hundred and the rest") == [.number(300), ScriptWord(text: "and"), ScriptWord(text: "the"), ScriptWord(text: "rest")])
        #expect(texts("fish and chips") == ["fish", "and", "chips"])
    }

    @Test func groupsMapBackToTheirTokens() {
        let groups = ScriptWords.groups(["climb", "three", "hundred", "—", "feet"])
        #expect(groups.map(\.tokens) == [0...0, 1...2, 3...3, 4...4])
        #expect(groups[2].word == nil)
    }
}
