@testable import Earwig
import Testing

struct WordFoldingTests {

    private func word(_ text: String) -> ScriptWord {
        let words = ScriptWords.words(in: text)
        precondition(words.count == 1, "\(text) is \(words.count) words")
        return words[0]
    }

    @Test func equalFormsAreExact() {
        #expect(WordFolding.match(word("Harbour,"), word("harbour")) == .exact)
        #expect(WordFolding.match(word("tide"), word("time")) == nil)
    }

    @Test func numbersMatchByValue() {
        #expect(WordFolding.match(word("1890"), word("eighteen ninety")) == .exact)
        #expect(WordFolding.match(word("300"), word("three hundred")) == .exact)
        #expect(WordFolding.match(word("4"), word("four")) == .exact)
        #expect(WordFolding.match(word("1891"), word("1890")) == nil)
        #expect(WordFolding.match(word("for"), word("four")) == nil)
    }

    @Test func digitsStillArrivingMatchOnlyWhenAllowed() {
        #expect(WordFolding.match(word("18"), word("1890"), allowPrefix: true) == .near)
        #expect(WordFolding.match(word("189"), word("1890"), allowPrefix: true) == .near)
        #expect(WordFolding.match(word("18"), word("1890")) == nil)
        #expect(WordFolding.match(word("19"), word("1890"), allowPrefix: true) == nil)
    }

    @Test func nearSpellingsFromFiveLetters() {
        #expect(WordFolding.match(word("harbor"), word("harbour")) == .near)
        #expect(WordFolding.match(word("center"), word("centre")) == .near)
        #expect(WordFolding.match(word("color"), word("colour")) == .near)
        #expect(WordFolding.match(word("realize"), word("realise")) == .near)
        #expect(WordFolding.match(word("organization"), word("organisation")) == .near)
        // Under five letters, nothing is near: "boat" is not "coat".
        #expect(WordFolding.match(word("boat"), word("coat")) == nil)
        // Eight letters or more allow two edits; five to seven allow one.
        #expect(WordFolding.match(word("walking"), word("talkink")) == nil)
        #expect(WordFolding.match(word("lighthouse"), word("lightouses")) == .near)
    }

    @Test func theSpellingTableCoversTheRest() {
        #expect(WordFolding.match(word("gray"), word("grey")) == .exact)
        #expect(WordFolding.match(word("tire"), word("tyre")) == .exact)
        #expect(WordFolding.match(word("program"), word("programme")) == .exact)
        #expect(WordFolding.match(word("can't"), word("cannot")) == .exact)
    }

    @Test func compoundsFoldBothWays() {
        #expect(WordFolding.matchesPair(word("seawall"), word("sea"), word("wall")))
        #expect(WordFolding.matchesPair(word("sea-wall"), word("sea"), word("wall")))
        #expect(!WordFolding.matchesPair(word("seaside"), word("sea"), word("wall")))
    }

    @Test func contractionsFoldBothWays() {
        #expect(WordFolding.matchesPair(word("there's"), word("there"), word("is")))
        #expect(WordFolding.matchesPair(word("it's"), word("it"), word("has")))
        #expect(WordFolding.matchesPair(word("we're"), word("we"), word("are")))
        #expect(WordFolding.match(word("were"), word("were")) == .exact)
        #expect(!WordFolding.matchesPair(word("there's"), word("there"), word("was")))
    }

    @Test func editDistanceCountsATranspositionAsOne() {
        #expect(WordFolding.editDistance("ab", "ba", limit: 3) == 1)
        #expect(WordFolding.editDistance("kitten", "sitting", limit: 5) == 3)
        #expect(WordFolding.editDistance("kitten", "sitting", limit: 1) == 2)
        #expect(WordFolding.editDistance("", "abc", limit: 5) == 3)
    }
}
