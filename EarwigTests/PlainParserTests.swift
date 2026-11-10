@testable import Earwig
import Testing

struct PlainParserTests {

    @Test func paragraphsAreStepsWithNoNamesGuessed() {
        let script = ScriptParser.parse(Fixtures.plain)
        #expect(script.format == .plain)
        #expect(script.title == "The Ferry Crossing")
        #expect(script.titleIsStated)
        // The first paragraph is one title-like line: the script's title, not a step. A step's
        // short first line is spoken, never taken as its name (plan 015, decision 4).
        #expect(script.steps.map(\.title) == ["", "", ""])
        #expect(script.steps.map(\.number) == [1, 2, 3])
        #expect(script.steps[0].lines == ["Boarding", "The ferry leaves at ten past the hour.", "Find a seat on the left for the view."])
        #expect(script.steps[2].lines == ["Arriving.", "That's the far shore."])
    }

    @Test func headingsMakeStepsAndBlankLinesInsideAreSpacing() {
        let script = ScriptParser.parse("""
            # The Pier

            ## The entrance
            It opened in 1899.

            It runs out a third of a mile.

            ## The end
            And here we are.
            """)
        #expect(script.title == "The Pier")
        #expect(script.steps.map(\.title) == ["The entrance", "The end"])
        #expect(script.steps[0].lines == ["It opened in 1899.", "It runs out a third of a mile."])
        #expect(script.steps[1].lines == ["And here we are."])
        // A line of spaces is a blank line too.
        #expect(ScriptParser.parse("## A\nOne.\n   \nTwo.").steps.map(\.lines) == [["One.", "Two."]])
    }

    @Test func textBeforeTheFirstHeadingIsAStep() {
        // A short first line with no full stop is not taken as a title once `#` has given one.
        let script = ScriptParser.parse("# The Pier\n\nHello everyone\n\nWelcome to the pier.\n\n## The end\nAnd here we are.")
        #expect(script.steps.map(\.title) == ["", "The end"])
        #expect(script.steps[0].lines == ["Hello everyone", "Welcome to the pier."])
    }

    @Test func aLoneShortFirstLineBeforeTheHeadingsIsTheTitle() {
        let script = ScriptParser.parse("The Pier\n\n## The entrance\nIt opened in 1899.")
        #expect(script.title == "The Pier")
        #expect(script.titleIsStated)
        #expect(script.steps.map(\.title) == ["The entrance"])
    }

    @Test func aHeadingWithNothingToSayIsNotAStep() {
        let script = ScriptParser.parse("## Empty\n\n## Full\nSomething to say.")
        #expect(script.steps.map(\.title) == ["Full"])
        #expect(script.steps.map(\.number) == [1])
    }

    @Test func aBareHeadingStartsAStepWithNoName() {
        let script = ScriptParser.parse("##\nFirst part.\n##\nSecond part.")
        #expect(script.title == "First part.")
        #expect(script.steps.map(\.title) == ["", ""])
        // New's bare `#`, with no title typed, names nothing (review C1).
        #expect(ScriptParser.parse("#\n\n##\nHello.").title == "Hello.")
        #expect(ScriptParser.parse("#\n\n##").title == "Untitled script")
        #expect(script.steps.map(\.lines) == [["First part."], ["Second part."]])
    }

    @Test func aBracketedLineAtTheTopOfAStepIsItsCue() {
        let script = ScriptParser.parse("""
            ## The entrance
            [At the pier gates, the sea behind]
            It opened in 1899.
            [Gesture along the boards]
            It runs out a third of a mile.
            """)
        let step = script.steps[0]
        #expect(step.directions == [Direction(kind: .cue, text: "At the pier gates, the sea behind")])
        // Further down, a bracketed line stays a cue in the lines, chimed or spoken there.
        #expect(step.lines == ["It opened in 1899.", "[Gesture along the boards]", "It runs out a third of a mile."])
        // An empty `[]`, as Cue leaves it, is dropped.
        #expect(ScriptParser.parse("[]\nHello.").steps[0].directions.isEmpty)
    }

    @Test func aCueAloneIsNotAStep() {
        let script = ScriptParser.parse("[Walk to the end]\n\nAnd here we are.")
        #expect(script.steps.count == 1)
        #expect(script.steps[0].lines == ["And here we are."])
    }

    @Test func squareBracketsAreDirectionsInsideALine() {
        let line = ScriptParser.parse(Fixtures.plain).steps[1].lines[0]
        #expect(LineText.segments(of: line) == [
            .spoken("The crossing takes twenty minutes."),
            .direction("Look out to sea"),
            .spoken("On a good day you'll see dolphins."),
        ])
        #expect(LineText.spoken(line) == "The crossing takes twenty minutes. On a good day you'll see dolphins.")
    }

    @Test func roundBracketsAreSpoken() {
        #expect(LineText.segments(of: "The path (the old one) is shut.") == [.spoken("The path (the old one) is shut.")])
    }

    @Test func anUnclosedBracketIsSpoken() {
        #expect(LineText.segments(of: "Mind the [gap") == [.spoken("Mind the [gap")])
    }

    @Test func aLoneTitleLineWithNothingElseIsStillAStep() {
        let script = ScriptParser.parse("Just a title")
        #expect(script.title == "Just a title")
        #expect(script.steps.count == 1)
    }

    @Test func noBlankLinesIsOneStep() {
        let script = ScriptParser.parse("First line here.\nSecond line here.")
        #expect(script.steps.count == 1)
        #expect(script.steps[0].lines.count == 2)
    }

    @Test func aLongFirstLineIsCutForTheTitle() {
        let script = ScriptParser.parse("This is a rather long first line that runs well past forty characters.")
        #expect(script.title == "This is a rather long first line that…")
        #expect(!script.titleIsStated)
        #expect(script.title.count <= PlainParser.maxScriptTitleLength + 1)
    }

    @Test func titleRule() {
        #expect(PlainParser.isTitle("The sea wall"))
        #expect(!PlainParser.isTitle("The sea wall."))
        #expect(!PlainParser.isTitle("one two three four five six seven eight nine"))
    }

    @Test func emptyTextHasNoSteps() {
        let script = ScriptParser.parse("  \n\n ")
        #expect(script.steps.isEmpty)
        #expect(!script.hasSpokenWords)
    }
}
