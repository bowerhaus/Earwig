import Foundation

/// Where the step's words sit on the screen, and from that the y a place in the script is at
/// (plan 008, decision 3). Built from the word frames the text's layout reports, whenever they
/// change (a new width or text size); the y of a place is then looked up every frame. Plain
/// values, so it is tested without views.
struct ScreenLayout: Equatable, Sendable {
    struct Row: Equatable, Sendable {
        var minY: CGFloat
        /// From this row's top to the next row's, so a place moving along a row moves the text
        /// on by exactly one row by its end.
        var pitch: CGFloat
        var minX: CGFloat
        var maxX: CGFloat
    }

    struct Placed: Equatable, Sendable {
        var row: Int
        var minX: CGFloat
        var width: CGFloat
    }

    private(set) var rows: [Row] = []
    /// By script word, the row it is in and where.
    private(set) var placed: [Placed] = []

    /// `frames` by screen word id, in the text's own coordinates.
    init(words: [ScreenWord], frames: [Int: CGRect]) {
        let tops = Set(frames.values.map { ($0.minY * 2).rounded() / 2 }).sorted()
        guard !tops.isEmpty else { return }
        var rowOf: [CGFloat: Int] = [:]
        for (index, top) in tops.enumerated() { rowOf[top] = index }
        var rows = tops.map { Row(minY: $0, pitch: 0, minX: .infinity, maxX: -.infinity) }
        for frame in frames.values {
            guard let row = rowOf[(frame.minY * 2).rounded() / 2] else { continue }
            rows[row].minX = min(rows[row].minX, frame.minX)
            rows[row].maxX = max(rows[row].maxX, frame.maxX)
            rows[row].pitch = max(rows[row].pitch, frame.height)
        }
        for index in rows.indices.dropLast() { rows[index].pitch = rows[index + 1].minY - rows[index].minY }
        self.rows = rows
        let wordCount = (words.compactMap(\.word).max() ?? -1) + 1
        var placed = [Placed](repeating: Placed(row: 0, minX: 0, width: 0), count: wordCount)
        var seen = Set<Int>()
        for word in words {
            guard let index = word.word, let frame = frames[word.id], let row = rowOf[(frame.minY * 2).rounded() / 2] else { continue }
            placed[index] = Placed(row: row, minX: frame.minX, width: frame.width)
            seen.insert(index)
        }
        // A layout missing a word is not used.
        self.placed = seen.count == wordCount ? placed : []
    }

    var isEmpty: Bool { rows.isEmpty || placed.isEmpty }

    /// The y of a place in the script: the top of its word's row, plus the share of that row
    /// before the place, times the row's pitch. Before the first word, the first row's top; past
    /// the last, the end of its row.
    func y(at place: Double) -> CGFloat {
        guard !isEmpty else { return 0 }
        guard place >= 0 else { return rows[0].minY }
        let index = min(Int(place.rounded(.down)), placed.count - 1)
        let within = index == placed.count - 1 && place >= Double(placed.count) ? 1 : place - Double(index)
        let word = placed[index]
        let row = rows[word.row]
        let x = word.minX + CGFloat(min(max(within, 0), 1)) * word.width
        let share = row.maxX > row.minX ? (x - row.minX) / (row.maxX - row.minX) : 0
        return row.minY + min(max(share, 0), 1) * row.pitch
    }
}
