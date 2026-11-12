@testable import Earwig
import Testing

struct SlateTests {

    @Test func theStepNumberAndTake() {
        #expect(Slate.text(number: 3, shotID: nil, take: 2, directions: nil) == "Step 3, take 2.")
    }

    @Test func aShotIDIsSpelledOut() {
        #expect(Slate.text(number: 3, shotID: "W31", take: 1, directions: nil) == "W 3 1, take 1.")
        #expect(Slate.spelled("B-12a") == "B 1 2 a")
        #expect(Slate.spelled("--") == nil)
        #expect(Slate.text(number: 4, shotID: "--", take: 1, directions: nil) == "Step 4, take 1.")
    }

    @Test func withCuesOnTheDirectionsComeFirst() {
        let text = Slate.text(number: 3, shotID: nil, take: 2, directions: ["Rosie up ahead", "Rosie trots far ahead up the long track"])
        #expect(text == "Step 3. Rosie up ahead. Rosie trots far ahead up the long track. Step 3, take 2.")
    }

    @Test func aStepWithNoTitleOrShows() {
        #expect(Slate.text(number: 1, shotID: nil, take: 1, directions: ["", "  "]) == "Step 1. Step 1, take 1.")
        #expect(Slate.text(number: 1, shotID: nil, take: 1, directions: ["Ready?"]) == "Step 1. Ready? Step 1, take 1.")
    }

    @Test func theSlateForAStoredStep() {
        let step = Step(sortOrder: 0, number: 2, title: "The sea wall")
        step.directions = [Direction(kind: .footage, text: "0004 18.0"), Direction(kind: .shows, text: "Walking shot along the wall.")]
        #expect(Slate.text(for: step, take: 3, cuesOn: true) == "Step 2. The sea wall. Walking shot along the wall. Step 2, take 3.")
        #expect(Slate.text(for: step, take: 3, cuesOn: false) == "Step 2, take 3.")
    }

    @Test func aStepsOpeningCuesAreReadAfterItsTitle() {
        let step = Step(sortOrder: 0, number: 1, title: "The entrance")
        step.directions = [Direction(kind: .cue, text: "At the pier gates")]
        #expect(Slate.text(for: step, take: 1, cuesOn: true) == "Step 1. The entrance. At the pier gates. Step 1, take 1.")
        #expect(Slate.text(for: step, take: 1, cuesOn: false) == "Step 1, take 1.")
    }

    /// Plan 015, decision 14: before the tones alone, the cues with no slate.
    @Test func tonesOnlyReadsTheCuesAlone() {
        let step = Step(sortOrder: 0, number: 1, title: "The entrance")
        step.directions = [Direction(kind: .cue, text: "At the pier gates")]
        #expect(Slate.text(for: step, take: 1, cuesOn: true, start: .tonesOnly) == "The entrance. At the pier gates.")
        #expect(Slate.text(for: step, take: 1, cuesOn: false, start: .tonesOnly) == "")
        #expect(Slate.text(for: Step(sortOrder: 0, number: 1, title: ""), take: 1, cuesOn: true, start: .tonesOnly) == "")
        #expect(Slate.text(for: step, take: 1, cuesOn: true, start: .slate) == "Step 1. The entrance. At the pier gates. Step 1, take 1.")
    }

    @Test func theReplyIsTheNumberTakeAndTakeNumber() {
        #expect(Slate.replyWords(number: 3, shotID: nil, take: 2) == [.number(3), ScriptWord(text: "take"), .number(2)])
    }

    @Test func aShotIDsReplyHasItsLettersAndDigitsApart() {
        let words = Slate.replyWords(number: 3, shotID: "W31", take: 2)
        #expect(words.map(\.text) == ["w", "3", "1", "take", "2"])
        #expect(Slate.replyWords(number: 4, shotID: "--", take: 1) == [.number(4), ScriptWord(text: "take"), .number(1)])
    }

    @Test func theReplyForAStoredStep() {
        let step = Step(sortOrder: 0, number: 12, title: "The sea wall")
        #expect(Slate.replyWords(for: step, take: 10) == [.number(12), ScriptWord(text: "take"), .number(10)])
    }
}
