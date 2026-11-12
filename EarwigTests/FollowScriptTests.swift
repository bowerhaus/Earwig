@testable import Earwig
import Testing

struct FollowScriptTests {

    /// Phrases: 0 "alpha bravo charlie", 1 a cue, 2 "delta echo", 3 "foxtrot".
    private let script = FollowScript(phrases: [
        FollowPhrase(kind: .spoken, words: ScriptWords.words(in: "alpha bravo charlie"), wordStarts: [0, 0.4, 0.8], duration: 1.4),
        .cue(duration: 1),
        FollowPhrase(kind: .spoken, words: ScriptWords.words(in: "delta echo"), wordStarts: [0, 0.4], duration: 1),
        FollowPhrase(kind: .spoken, words: ScriptWords.words(in: "foxtrot"), wordStarts: [0], duration: 0.6),
    ])

    @Test func wordsAreIndexedAcrossTheTake() {
        #expect(script.words.count == 6)
        #expect(script.firstWord == [0, 3, 3, 5])
        #expect(script.range(of: 1).isEmpty)
        #expect(script.lastWord(of: 2) == 4)
        #expect(script.lastWord(of: 1) == nil)
        #expect(script.phrase(containing: 4) == 2)
        #expect(script.lastSpokenWord == 5)
    }

    @Test func theNextPhraseThePresenterHasNotBegun() {
        #expect(script.firstPhrase(after: -1) == 0)
        #expect(script.firstPhrase(after: 0) == 1)
        #expect(script.firstPhrase(after: 3) == 3)
        #expect(script.firstPhrase(after: 5) == nil)
    }

    @Test func aPhraseIsGatedByTheSpokenPhraseBeforeIt() {
        #expect(script.gatingPhrase(before: 0) == nil)
        #expect(script.gatingPhrase(before: 1) == 0)
        #expect(script.gatingPhrase(before: 2) == 0)
        #expect(script.gatingPhrase(before: 3) == 2)
    }

    @Test func anOffsetMapsToTheWordBeingSaid() {
        #expect(script.word(in: 0, at: 0) == 0)
        #expect(script.word(in: 0, at: 0.5) == 1)
        #expect(script.word(in: 0, at: 9) == 2)
        #expect(script.word(in: 2, at: 0.4) == 4)
        #expect(script.word(in: 1, at: 0.5) == nil)
    }

    @Test func theSampleStepBecomesTheEnginesInput() {
        let parsed = ScriptParser.parse(Fixtures.harbourWalk)
        let list = PhraseList(lines: parsed.steps[0].lines)
        let follow = FollowScript(phraseList: list)
        #expect(follow.phrases.count == list.phrases.count)
        #expect(follow.words == list.scriptWords)
        #expect(follow.phrases.map { $0.kind == .cue } == list.phrases.map { $0.kind == .cue })
        #expect(follow.phrases[0].wordStarts == [0])
        let timed = FollowScript(phraseList: list) { $0 == 0 ? PhraseTiming(wordStarts: [0.1], duration: 0.9) : nil }
        #expect(timed.phrases[0].wordStarts == [0.1])
        #expect(timed.phrases[0].duration == 0.9)
        // A rendering whose word count differs from the phrase's keeps even spacing.
        let mismatched = FollowScript(phraseList: list) { $0 == 0 ? PhraseTiming(wordStarts: [0.1, 0.2], duration: 0.9) : nil }
        #expect(mismatched.phrases[0].wordStarts == [0])
    }
}
