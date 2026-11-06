@testable import Earwig
import Testing

struct WordNormaliserTests {

    @Test func lowercasesAndStripsPunctuation() {
        #expect(WordNormaliser.normalise("World!") == "world")
        #expect(WordNormaliser.normalise("“stop.”") == "stop")
    }

    @Test func dropsApostrophesStraightAndCurly() {
        #expect(WordNormaliser.normalise("Don’t") == "dont")
        #expect(WordNormaliser.normalise("can't") == "cant")
    }

    @Test func foldsDiacritics() {
        #expect(WordNormaliser.normalise("Café") == "cafe")
        #expect(WordNormaliser.normalise("naïve") == "naive")
    }

    @Test func punctuationAloneIsNoWord() {
        #expect(WordNormaliser.normalise("—") == nil)
        #expect(WordNormaliser.normalise("…") == nil)
    }
}
