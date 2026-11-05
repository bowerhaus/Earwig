@testable import Earwig
import Testing

/// Tests for the spike's stand-in follower; deleted with the spike.
struct SpikeFollowerTests {

    private let script = WordNormaliser.words(in: "The tide comes in twice a day, and the causeway closes for about four hours each time.")

    private func follow(_ text: String) -> SpikeFollower.Result {
        SpikeFollower(script: script).follow(WordNormaliser.words(in: text))
    }

    @Test func cleanReadMatchesEveryWord() {
        let result = follow("the tide comes in twice a day and the causeway closes")
        #expect(result.position == 10)
        #expect(result.accuracy == 1)
    }

    @Test func missedWordsLowerAccuracyButKeepPosition() {
        let result = follow("the tide comes twice day and the causeway")
        #expect(result.position == 9)
        #expect(result.accuracy == 8.0 / 10.0)
    }

    @Test func offScriptWordsAreIgnored() {
        let result = follow("the tide comes in sorry dog barking twice a day")
        #expect(result.position == 6)
    }

    @Test func restartStepsBack() {
        let result = follow("the tide comes in twice a day the tide comes")
        #expect(result.position == 2)
    }

    @Test func longJumpNeedsConfirmation() {
        // "closes" alone is too far ahead to trust; "closes for" is a run.
        #expect(follow("the tide closes").position == 1)
        #expect(follow("the tide closes for").position == 11)
    }

    @Test func nearMissesOfLongWordsMatch() {
        #expect(SpikeFollower.matches("causway", "causeway"))
        #expect(!SpikeFollower.matches("tid", "tide"))
    }

    @Test func lostPresenterIsFoundByARunOfThree() {
        let heard = "the tide um er so where was i yes four hours each time"
        let result = follow(heard)
        #expect(result.position == script.count - 1)
    }
}
