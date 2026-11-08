@testable import Earwig
import Foundation
import Testing

struct HeardEventsTests {

    /// Analyser time to host time: listening started at host 1000 s.
    private func host(_ time: TimeInterval) -> TimeInterval { 1000 + time }

    @Test func aVolatileResultIsItsWholeTextAsOneInterim() {
        let runs = [HeardRun("We follow the ", start: 2, duration: 1.2), HeardRun("footpath  down", start: 3.2, duration: 0.8)]
        let event = HeardEvents.event(for: runs, isFinal: false, resultStart: 2, resultEnd: 4, hostTime: host)
        #expect(event == .interim("We follow the footpath down"))
    }

    @Test func aFinalsWordsCarryTheirHostClockStarts() {
        let runs = [HeardRun("We", start: 2.0, duration: 0.2), HeardRun(" follow", start: 2.3, duration: 0.4), HeardRun(" the", start: 2.8, duration: 0.1)]
        let event = HeardEvents.event(for: runs, isFinal: true, resultStart: 2, resultEnd: 3, hostTime: host)
        #expect(event == .final([
            FinalWord(text: "We", start: 1002.0),
            FinalWord(text: "follow", start: 1002.3),
            FinalWord(text: "the", start: 1002.8),
        ]))
    }

    @Test func numbersAndCompoundsAreKeptAsWritten() {
        let runs = [HeardRun("about", start: 1, duration: 0.3), HeardRun(" 20", start: 1.4, duration: 0.3), HeardRun(" twenty-one", start: 1.8, duration: 0.5), HeardRun(" footpath", start: 2.4, duration: 0.4)]
        let event = HeardEvents.event(for: runs, isFinal: true, resultStart: 1, resultEnd: 3, hostTime: host)
        #expect(event == .final([
            FinalWord(text: "about", start: 1001),
            FinalWord(text: "20", start: 1001.4),
            FinalWord(text: "twenty-one", start: 1001.8),
            FinalWord(text: "footpath", start: 1002.4),
        ]))
    }

    @Test func anEmptyResult() {
        #expect(HeardEvents.event(for: [], isFinal: true, resultStart: 0, resultEnd: 0, hostTime: host) == .final([]))
        #expect(HeardEvents.event(for: [HeardRun("  ")], isFinal: false, resultStart: 0, resultEnd: 0, hostTime: host) == .interim(""))
    }

    @Test func aRunOfSeveralWordsIsSpreadByLetters() {
        let (words, untimed) = HeardEvents.words(in: [HeardRun("ab cd", start: 10, duration: 2)], resultStart: 10, resultEnd: 12)
        #expect(!untimed)
        #expect(words.map(\.start) == [10, 11])
    }

    @Test func wordsWithNoTimesAreSpreadOverTheResult() {
        let (words, untimed) = HeardEvents.words(in: [HeardRun("one two three four")], resultStart: 4, resultEnd: 6)
        #expect(untimed)
        #expect(words.map(\.text) == ["one", "two", "three", "four"])
        #expect(words.map(\.start) == [4, 4.5, 5, 5.5])
    }
}
