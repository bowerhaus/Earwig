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
}
