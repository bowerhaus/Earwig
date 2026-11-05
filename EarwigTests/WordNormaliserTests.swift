@testable import Earwig
import Testing

struct WordNormaliserTests {

    @Test func lowercasesAndStripsPunctuation() {
        #expect(WordNormaliser.words(in: "Hello, World!") == ["hello", "world"])
    }

    @Test func dropsApostrophesAndCurlyQuotes() {
        #expect(WordNormaliser.words(in: "Don’t say “can't”") == ["dont", "say", "cant"])
    }

    @Test func foldsDiacritics() {
        #expect(WordNormaliser.words(in: "Café naïve") == ["cafe", "naive"])
    }

    @Test func splitsOnDashesAndSlashes() {
        #expect(WordNormaliser.words(in: "well-known up/down — then") == ["well", "known", "up", "down", "then"])
    }

    @Test func purePunctuationGivesNoWords() {
        #expect(WordNormaliser.words(in: "… — !") == [])
    }

    @Test func spellsOutNumbers() {
        #expect(WordNormaliser.words(in: "20 metres") == ["twenty", "metres"])
        #expect(WordNormaliser.words(in: "120,") == ["one", "hundred", "and", "twenty"])
        #expect(WordNormaliser.words(in: "1,005") == ["one", "thousand", "and", "five"])
        #expect(WordNormaliser.words(in: "3,400") == ["three", "thousand", "four", "hundred"])
        #expect(WordNormaliser.words(in: "0") == ["zero"])
        #expect(WordNormaliser.words(in: "45") == ["forty", "five"])
    }

    @Test func leavesMixedTokensAlone() {
        #expect(WordNormaliser.words(in: "3pm") == ["3pm"])
    }
}
