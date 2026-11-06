@testable import Earwig
import Testing

struct PlainParserTests {

    @Test func blocksAreStepsWithShortTitles() {
        let script = ScriptParser.parse(Fixtures.plain)
        #expect(script.format == .plain)
        #expect(script.title == "The Ferry Crossing")
        #expect(script.titleIsStated)
        // The first block is one title-like line: the script's title, not a step.
        #expect(script.steps.map(\.title) == ["Boarding", "", ""])
        #expect(script.steps.map(\.number) == [1, 2, 3])
        #expect(script.steps[0].lines == ["The ferry leaves at ten past the hour.", "Find a seat on the left for the view."])
        // "Arriving." ends with a full stop, so it is a line.
        #expect(script.steps[2].lines == ["Arriving.", "That's the far shore."])
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

    @Test func aMarkdownTitleNamesTheScript() {
        let script = ScriptParser.parse("# The Pier\n\n## End of the pier\nIt is a long way out.\n\n   \n\nAnd back.")
        #expect(script.title == "The Pier")
        #expect(script.steps.count == 2)
        #expect(script.steps[0].title == "End of the pier")
        #expect(script.steps[1].lines == ["And back."])
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
