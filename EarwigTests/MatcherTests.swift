@testable import Earwig
import Testing

struct MatcherTests {

    /// "The sea wall was built in 1890, after a storm took half the cottages on the front. You
    /// can still see the marks …" as script words.
    private let script = ScriptWords.words(in: """
        The sea wall was built in 1890, after a storm took half the cottages on the front.
        You can still see the marks where the old ones stood, if you know where to look.
        On a calm day like this it's an easy stroll, but in winter the spray comes right over the top.
        """)

    private var matcher: Matcher { Matcher(words: script, settings: FollowSettings()) }

    /// Heard words from text, one every 0.4 s from `start`.
    private func heard(_ text: String, from start: Double = 0) -> [HeardScriptWord] {
        ScriptWords.words(in: text).enumerated().map { HeardScriptWord(word: $1, heardAt: start + Double($0) * 0.4) }
    }

    @Test func aCleanReadIsConfidentToTheEnd() {
        let state = matcher.align(heard("the sea wall was built in 1890 after a storm"), from: MatchState(), prefixLast: false)
        #expect(state.confident == 9)
        #expect(state.run == 10)
        #expect(!state.lost)
    }

    @Test func aCommonWordAloneMovesNothingConfidently() {
        let state = matcher.align(heard("the"), from: MatchState(), prefixLast: false)
        #expect(state.last == 0)
        #expect(state.confident == -1)
    }

    @Test func numbersAndCompoundsAsTheRecogniserWritesThem() {
        let state = matcher.align(heard("the seawall was built in 1890"), from: MatchState(), prefixLast: false)
        #expect(state.confident == 6)
        // Digits still building up at the end of an interim block.
        let building = matcher.align(heard("the sea wall was built in 18"), from: MatchState(), prefixLast: true)
        #expect(building.confident == 6)
        let notYet = matcher.align(heard("the sea wall was built in 18"), from: MatchState(), prefixLast: false)
        #expect(notYet.confident == 5)
    }

    @Test func contractionsHeardExpanded() {
        // Script: "… like this it's an easy stroll"; heard "it is".
        let state = matcher.align(heard("like this it is an easy stroll"), from: MatchState(last: 37, confident: 37, run: 2), prefixLast: false)
        #expect(script[40] == ScriptWord(text: "its"))
        #expect(state.confident == 43)
    }

    @Test func oneDroppedScriptWordKeepsTheRun() {
        // "to" dropped from "where to look".
        let state = matcher.align(heard("if you know where look"), from: MatchState(last: 27, confident: 27, run: 3), prefixLast: false)
        #expect(state.confident == 33)
    }

    @Test func oneMisheardWordKeepsTheRun() {
        let state = matcher.align(heard("the sea wall was built of 1890 after"), from: MatchState(), prefixLast: false)
        #expect(state.confident == 7)
        #expect(state.run == 7)
    }

    @Test func anInsertedWordBreaksTheRun() {
        var state = matcher.align(heard("the sea wall um was"), from: MatchState(), prefixLast: false)
        #expect(state.confident == 2)
        #expect(state.run == 1)
        state = matcher.align(heard("the sea wall um was built"), from: MatchState(), prefixLast: false)
        #expect(state.confident == 4)
    }

    @Test func aRewrittenBlockIsReAlignedFromItsBase() {
        let base = matcher.align(heard("the sea wall was built"), from: MatchState(), prefixLast: false)
        let first = matcher.align(heard("in 1890 after a stone", from: 2), from: base, prefixLast: true)
        let rewritten = matcher.align(heard("in 1890 after a storm took", from: 2), from: base, prefixLast: true)
        #expect(first.confident == 8)
        #expect(rewritten.confident == 10)
        #expect(rewritten == matcher.align(heard("the sea wall was built") + heard("in 1890 after a storm took", from: 2), from: MatchState(), prefixLast: true))
    }

    @Test func sixUnmatchedWordsAreLost() {
        let base = matcher.align(heard("the sea wall was built"), from: MatchState(), prefixLast: false)
        let five = matcher.align(heard("rosie come back here girl", from: 2), from: base, prefixLast: false)
        #expect(!five.lost)
        let six = matcher.align(heard("rosie come back here girl biscuit", from: 2), from: base, prefixLast: false)
        #expect(six.lost)
        #expect(six.confident == 4)
    }

    @Test func fourSecondsOfUnmatchedSpeechAreLost() {
        let base = matcher.align(heard("the sea wall was built"), from: MatchState(), prefixLast: false)
        let words = ["rosie", "biscuit", "squirrel"].enumerated().map { HeardScriptWord(word: ScriptWord(text: $1), heardAt: 2 + Double($0) * 2) }
        #expect(matcher.align(Array(words.prefix(2)), from: base, prefixLast: false).lost == false)
        #expect(matcher.align(words, from: base, prefixLast: false).lost)
    }

    @Test func aStrayCommonWordDoesNotKeepThePresenterFound() {
        let base = matcher.align(heard("the sea wall was built"), from: MatchState(), prefixLast: false)
        let state = matcher.align(heard("rosie the dog the squirrel the biscuit the girl sorry folks", from: 2), from: base, prefixLast: false)
        #expect(state.lost)
    }

    @Test func lostNeedsARunOfThreeAnywhereInTheStep() {
        let lost = MatchState(last: 4, confident: 4, unmatched: 6, lost: true)
        let two = matcher.align(heard("spray comes"), from: lost, prefixLast: false)
        #expect(two.lost)
        #expect(two.confident == 4)
        let three = matcher.align(heard("spray comes right"), from: lost, prefixLast: false)
        #expect(!three.lost)
        #expect(three.confident == 50)
    }

    @Test func aRestartBehindIsMatchedWhereThePresenterIs() {
        let base = matcher.align(heard("you can still see the marks where the old"), from: MatchState(last: 16, confident: 16, run: 3), prefixLast: false)
        #expect(base.confident == 25)
        let restarted = matcher.align(heard("you can still see", from: 5), from: base, prefixLast: false)
        #expect(restarted.confident == 20)
    }

    @Test func theNearestCandidateWins() {
        // "the" is at 12 and 15; expected 14 takes 15, the nearer.
        let state = matcher.align(heard("the"), from: MatchState(last: 13, confident: 13), prefixLast: false)
        #expect(state.last == 15)
        // Expected 10: the "the" at 12 is confirmed by "cottages" after it.
        let ahead = matcher.align(heard("the cottages"), from: MatchState(last: 9, confident: 9, run: 2), prefixLast: false)
        #expect(ahead.confident == 13)
    }

    @Test func exactBeatsNearAndAheadBeatsBehind() {
        let words = ScriptWords.words(in: "the coats and the boats on the quay")
        let matcher = Matcher(words: words, settings: FollowSettings())
        // "boats" is one edit from "coats" (nearer) but exactly "boats".
        let exact = matcher.align([HeardScriptWord(word: ScriptWord(text: "boats"), heardAt: 0)], from: MatchState(last: 0), prefixLast: false)
        #expect(exact.last == 4)
        // Expected at "sat" (2): "the" at 0 and 4 are both two away; ahead wins.
        let tie = Matcher(words: ScriptWords.words(in: "the cat sat on the mat"), settings: FollowSettings())
        let ahead = tie.align([HeardScriptWord(word: ScriptWord(text: "the"), heardAt: 0)], from: MatchState(last: 1), prefixLast: false)
        #expect(ahead.last == 4)
    }
}
