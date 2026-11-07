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
        #expect(Slate.text(for: step, take: 3, cuesOn: true, inline: .spoken) == "Step 2. The sea wall. Walking shot along the wall. Step 2, take 3.")
        #expect(Slate.text(for: step, take: 3, cuesOn: false, inline: .chime) == "Step 2, take 3.")
    }

    @Test func chimedDirectionsAreReadInTheSlateByWhereTheyFall() {
        let step = Step(sortOrder: 0, number: 1, title: "Setting off")
        step.phraseList = PhraseList(lines: [
            "[Gesture to the boats] Most of these boats go out at first light.",
            "And that is the harbour. [Turn to the path]",
        ])
        let text = Slate.text(for: step, take: 1, cuesOn: true, inline: .chime)
        #expect(text == "Step 1. Setting off. At “Most of these boats”, gesture to the boats. After “that is the harbour”, turn to the path. Step 1, take 1.")
        // Spoken in place, they are not read ahead.
        #expect(Slate.text(for: step, take: 1, cuesOn: true, inline: .spoken) == "Step 1. Setting off. Step 1, take 1.")
    }
}
