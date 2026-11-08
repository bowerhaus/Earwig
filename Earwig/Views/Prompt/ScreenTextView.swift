import SwiftUI

/// The scrolling text of Screen mode (PRD §4.6; plan 008, decisions 2 to 5, 8): the take's step
/// in large type, kept with the presenter's place at a reading line a third of the way down. The
/// place is smoothed by `ScreenPlace` and turned into a y by `ScreenLayout` every frame, so the
/// text rises continuously as the presenter reads. A drag moves it by hand for a while; a pinch
/// sizes it.
struct ScreenTextView: View {
    let tokens: [PromptViewModel.ScreenToken]
    /// The engine's estimate and confident word.
    let place: Double
    let confident: Int
    @Binding var textSize: Double
    /// Changed by the Prompt screen on Back, Forward and Restart: the text follows again at once.
    let resume: Int

    /// Where the reading line is, as a share of the height.
    static let readingLine = 1.0 / 3
    @State private var follower = ScreenFollower()
    @State private var layout = ScreenLayout(words: [], frames: [:])
    @State private var pinchBase: Double?

    var body: some View {
        GeometryReader { geometry in
            let readingY = geometry.size.height * Self.readingLine
            TimelineView(.animation) { context in
                let y = follower.y(at: context.date.timeIntervalSinceReferenceDate, place: place, confident: confident, layout: layout)
                WordColumn(tokens: tokens, mark: follower.mark, size: textSize, width: geometry.size.width)
                    .equatable()
                    .offset(y: readingY - y)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
            .contentShape(Rectangle())
            .onPreferenceChange(WordFrames.self) { frames in
                let words = tokens.map(\.word)
                Task { @MainActor in layout = ScreenLayout(words: words, frames: frames) }
            }
            .gesture(drag)
            .simultaneousGesture(pinch)
        }
        .onChange(of: resume) { follower.moved() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Script")
        .accessibilityValue(accessibilityValue)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { follower.drag(by: $0.translation.height) }
            .onEnded { _ in follower.endDrag(at: Date.timeIntervalSinceReferenceDate) }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = pinchBase ?? textSize
                pinchBase = base
                textSize = TakeSettings.clampTextSize(base * value.magnification)
            }
            .onEnded { _ in pinchBase = nil }
    }

    private var accessibilityValue: String {
        guard let mark = tokens.firstIndex(where: { $0.isMark(follower.mark) }) else { return "" }
        return tokens[mark...].prefix(12).map(\.word.text).joined(separator: " ")
    }
}

/// The step's words, wrapped, each reporting its frame. Equatable, so the frame-by-frame offset
/// does not rebuild three hundred words.
private struct WordColumn: View, Equatable {
    let tokens: [PromptViewModel.ScreenToken]
    /// The presenter's place, as the screen shows it.
    let mark: Int?
    let size: Double
    let width: CGFloat

    var body: some View {
        WordFlow(paragraphSpacing: size * 0.6) {
            ForEach(tokens, id: \.word.id) { token in
                WordView(token: token, isMark: token.isMark(mark), isPassed: token.isPassed(mark: mark), size: size)
                    .layoutValue(key: StartsParagraph.self, value: token.word.startsParagraph)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(key: WordFrames.self, value: [token.word.id: proxy.frame(in: .named(WordColumn.space))])
                        }
                    }
            }
        }
        .coordinateSpace(.named(Self.space))
        .frame(width: width, alignment: .topLeading)
        // Room below the last line, so it can reach the reading line.
        .padding(.bottom, 600)
    }

    static let space = "screenText"
}

/// One word: dimmed once passed or before following, the voice's phrase on a faint accent and
/// its word on the accent, the presenter's place underlined, a cue in the cue colour.
private struct WordView: View {
    let token: PromptViewModel.ScreenToken
    let isMark: Bool
    let isPassed: Bool
    let size: Double

    var body: some View {
        Text(token.word.text)
            .font(.system(size: size, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .foregroundStyle(foreground)
            .padding(.horizontal, size * 0.12)
            .padding(.vertical, size * 0.1)
            .background(background)
            .overlay(alignment: .bottom) {
                if isMark {
                    Capsule()
                        .fill(EarwigTheme.accent)
                        .frame(height: max(3, size * 0.08))
                        .padding(.horizontal, size * 0.12)
                }
            }
    }

    private var foreground: Color {
        if token.word.isCue { return EarwigTheme.cue }
        if token.isVoiceWord { return EarwigTheme.onAccent }
        if token.isWaiting || isPassed { return EarwigTheme.secondaryText }
        return EarwigTheme.text
    }

    private var background: Color {
        if token.isVoiceWord { return EarwigTheme.accent }
        if token.inVoicePhrase { return EarwigTheme.voiceHighlight }
        return .clear
    }
}

/// Each word's frame in the column, by screen word id.
private struct WordFrames: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct StartsParagraph: LayoutValueKey {
    static let defaultValue = false
}

/// Words left to right, wrapping at the width, a new line with a gap for each paragraph.
private struct WordFlow: Layout {
    var paragraphSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let frames = arrange(subviews, width: width)
        let height = frames.map(\.maxY).max() ?? 0
        return CGSize(width: width.isFinite ? width : (frames.map(\.maxX).max() ?? 0), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrange(subviews, width: bounds.width)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [CGRect] {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            // A word wider than the column is offered the column, and scales down to fit (review C4).
            var size = subview.sizeThatFits(.unspecified)
            if size.width > width { size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
            let newParagraph = subview[StartsParagraph.self] && !frames.isEmpty
            if newParagraph || (x > 0 && x + size.width > width) {
                y += rowHeight + (newParagraph ? paragraphSpacing : 0)
                x = 0
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
        return frames
    }
}
