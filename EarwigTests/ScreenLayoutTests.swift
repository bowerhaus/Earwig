@testable import Earwig
import CoreGraphics
import Testing

/// From a place in the script to a y on the screen (plan 008, decision 3).
struct ScreenLayoutTests {

    /// Two rows of 50-point lines: words 0 and 1 on the first (x 0–100, 100–200), word 2 on the
    /// second (x 0–100), a cue and word 3 in a new paragraph at y 130.
    private let words: [ScreenWord] = {
        let list = PhraseList(lines: ["One two three.", "[Look] Four."])
        return ScreenText.words(phraseList: list, firstWord: FollowScript(phraseList: list).firstWord)
    }()

    private var frames: [Int: CGRect] {
        [0: CGRect(x: 0, y: 0, width: 100, height: 50),
         1: CGRect(x: 100, y: 0, width: 100, height: 50),
         2: CGRect(x: 0, y: 50, width: 100, height: 50),
         3: CGRect(x: 0, y: 130, width: 80, height: 50),
         4: CGRect(x: 80, y: 130, width: 100, height: 50)]
    }

    @Test func beforeTheFirstWordIsTheFirstRow() {
        #expect(words.map(\.word) == [0, 1, 2, nil, 3])
        let layout = ScreenLayout(words: words, frames: frames)
        #expect(layout.y(at: -1) == 0)
    }

    @Test func alongARowTheYRisesByTheRowsShare() {
        let layout = ScreenLayout(words: words, frames: frames)
        #expect(layout.y(at: 0) == 0)
        #expect(layout.y(at: 0.5) == 12.5)
        #expect(layout.y(at: 1) == 25)
        // The end of the first row is the start of the second: no jump.
        #expect(abs(layout.y(at: 1.999) - 50) < 0.1)
        #expect(layout.y(at: 2) == 50)
    }

    @Test func aRowBeforeAParagraphReachesTheNextRowsTop() {
        let layout = ScreenLayout(words: words, frames: frames)
        // Row 2 (word 2 alone) runs from 50 to 130, the paragraph gap included.
        #expect(abs(layout.y(at: 2.999) - 130) < 0.2)
        // Word 3 sits after the cue on its row, x 80–180 of 0–180.
        #expect(abs(layout.y(at: 3) - (130 + 80.0 / 180 * 50)) < 0.01)
    }

    @Test func pastTheLastWordIsTheEndOfItsRow() {
        let layout = ScreenLayout(words: words, frames: frames)
        #expect(layout.y(at: 10) == 180)
    }

    @Test func aLayoutMissingAWordIsNotUsed() {
        var partial = frames
        partial[2] = nil
        let layout = ScreenLayout(words: words, frames: partial)
        #expect(layout.isEmpty)
        #expect(layout.y(at: 1) == 0)
    }
}
