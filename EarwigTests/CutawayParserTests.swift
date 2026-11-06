@testable import Earwig
import Testing

struct CutawayParserTests {

    @Test func detectsTheFormat() {
        #expect(ScriptParser.detectFormat(SampleScript.harbourWalk) == .cutaway)
        #expect(ScriptParser.detectFormat(Fixtures.rosie) == .cutaway)
        #expect(ScriptParser.detectFormat(Fixtures.plain) == .plain)
        #expect(ScriptParser.detectFormat("## A heading\nBut no lines field.") == .plain)
    }

    @Test func parsesTheHarbourWalk() {
        let script = ScriptParser.parse(SampleScript.harbourWalk)
        #expect(script.format == .cutaway)
        #expect(script.title == "The Harbour Walk")
        #expect(script.preamble == nil)
        #expect(script.steps.map(\.number) == [1, 2, 3])
        #expect(script.steps.map(\.title) == ["Setting off", "The sea wall", "Up the cliff path"])
        #expect(script.steps.map(\.lines.count) == [4, 4, 5])
        #expect(script.steps[0].directions == [Direction(kind: .shows, text: "Presenter at the harbour wall, boats behind.")])
        #expect(script.steps[0].lines[3].hasPrefix("[Gesture to the boats] Most of these boats"))
        #expect(script.hasSpokenWords)
    }

    @Test func stripsTheScriptPrefixTheSourceSpanAndKeepsOpen() {
        let script = ScriptParser.parse(Fixtures.rosie)
        #expect(script.title == "Rosie's Walk")
        let step = script.steps[0]
        #expect(step.number == 3)
        #expect(step.title == "Rosie up ahead")
        #expect(step.lines == [
            "Rosie's off up ahead, about 20 metres, sniffing away.",
            "We follow the footpath down to the end of the fields.",
        ])
        #expect(step.directions == [
            Direction(kind: .shows, text: "Rosie trots far ahead up the long track across the fields"),
            Direction(kind: .footage, text: "0004 18.0-26.0"),
            Direction(kind: .open, text: "two takes of this; which one?"),
        ])
    }

    @Test func withoutATitleLineTheFirstStepNamesItButDoesNotStateIt() {
        let named = ScriptParser.parse("## 1. At the gate\nSays:\n- Hello.")
        #expect(named.title == "At the gate")
        #expect(!named.titleIsStated)
        #expect(ScriptParser.parse("## 1.\nSays:\n- Hello.").title == "Untitled script")
        #expect(ScriptParser.parse(Fixtures.rosie).titleIsStated)
    }

    @Test func readsTheOddCorners() {
        let script = ScriptParser.parse(Fixtures.corners)
        #expect(script.title == "The Allotment")
        #expect(script.preamble == "Draft for the autumn shoot.")
        #expect(script.steps.count == 3)

        let gate = script.steps[0]
        #expect(gate.lines == [
            "Welcome to the allotment, where everything grows except what I planted.",
            "It's been a wet year.",
        ])
        #expect(gate.directions == [
            Direction(kind: .shows, text: "The gate, the shed behind it, and the bean rows."),
            Direction(kind: .notes, text: "check the light\n  before noon"),
            Direction(kind: .unknown, text: "A stray line nobody meant."),
        ])

        let leaving = script.steps[1]
        #expect(leaving.number == 2)
        #expect(leaving.title == "Leaving")
        #expect(leaving.lines.isEmpty)

        let compost = script.steps[2]
        #expect(compost.number == 7)
        #expect(compost.lines == ["Inline lines count too."])
    }

    @Test func windowsLineEndingsParseTheSame() {
        let crlf = SampleScript.harbourWalk.replacingOccurrences(of: "\n", with: "\r\n")
        #expect(ScriptParser.parse(crlf) == ScriptParser.parse(SampleScript.harbourWalk))
    }

    @Test func noStepsMeansNoWords() {
        let script = ScriptParser.parse("# Title only\n\n## 1. Empty\nShows: nothing said\nSays: none yet")
        #expect(script.steps.count == 1)
        #expect(!script.hasSpokenWords)
    }
}
