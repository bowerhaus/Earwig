import Foundation

/// How the editor shows the script's marks as it is typed (plan 015, decision 2, amended on the
/// phone: Andy found `##` and a new line "a little bit ugly"): the `#` and `##` faint, the title
/// bold and larger, a step's name bold, and cues in the cue colour. Only the look changes; the
/// text is stored as it is written. Ranges are UTF-16, as UIKit counts.
enum ScriptHighlight {
    enum Kind: Equatable {
        /// The `#` or `##` of a heading.
        case mark
        /// The title's line, `#` and all.
        case title
        /// A step's heading line, `##` and all.
        case step
        /// A cue, its brackets and all; to the line's end while it is still open.
        case cue
    }

    struct Style: Equatable {
        let kind: Kind
        let range: NSRange
    }

    /// The styles in `text`, a heading's line before its mark, so the mark keeps the line's size.
    /// The lines are the plain parser's: one `#` is the title, two to six a step.
    static func styles(in text: String) -> [Style] {
        var styles: [Style] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if let heading = line.prefixMatch(of: #/\s*(#{1,6})(?:\s|$)/#) {
                let hashes = heading.output.1
                styles.append(Style(kind: hashes.count == 1 ? .title : .step, range: NSRange(line.startIndex..<line.endIndex, in: text)))
                styles.append(Style(kind: .mark, range: NSRange(hashes.startIndex..<hashes.endIndex, in: text)))
                continue
            }
            for cue in line.matches(of: #/\[[^\]]*\]?/#) {
                styles.append(Style(kind: .cue, range: NSRange(cue.range, in: text)))
            }
        }
        return styles
    }
}
