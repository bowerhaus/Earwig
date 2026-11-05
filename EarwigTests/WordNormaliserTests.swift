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

    @Test func keepsDigitsAsWritten() {
        #expect(WordNormaliser.words(in: "20 metres, 1,500") == ["20", "metres", "1500"])
    }

    @Test func leavesMixedTokensAlone() {
        #expect(WordNormaliser.words(in: "3pm") == ["3pm"])
    }
}
