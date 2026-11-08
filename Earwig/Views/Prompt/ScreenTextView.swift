import SwiftUI

/// The scrolling text of every take (PRD §4.6; plan 008, decisions 2 to 5, 8): the take's step
/// in large type, kept with the presenter's place at an eyeline a third of the way down. The
/// place is smoothed by `ScreenPlace` and turned into a y by `ScreenLayout` every frame, so the
/// text rises continuously as the presenter reads. A drag moves it by hand for a while; a pinch
/// sizes it.
struct ScreenTextView: View {
    let tokens: [PromptViewModel.ScreenToken]
    /// The engine's place for the screen: the word after the last one heard.
    let place: Double
    @Binding var textSize: Double
    /// Changed by the Prompt screen on Back, Forward and Restart: the text follows again at once.
    let resume: Int

    /// Where the eyeline is, as a share of the height.
    static let readingLine = 1.0 / 3
    @State private var follower = ScreenFollower()
    @State private var layout = ScreenLayout(words: [], frames: [:])
    @State private var pinchBase: Double?
    /// While pinching, the text is scaled as a picture about the eyeline, and laid out again at
    /// the new size only when the pinch ends: laying out every word at each step of the pinch
    /// made it jumpy (device check 5 of plan 008).
    @State private var pinchScale = 1.0
    /// A state change as a drag starts and ends, so a paused redraw starts again for it.
    @State private var dragging = false
    /// Whether the last frame found the text at rest. The follower is not observed, so without
    /// a state change as it comes to rest the body would not run again and the redraw would
    /// never pause: the snapshot is published only when it changes (review C1 of plan 008).
    @State private var resting = false

    var body: some View {
        GeometryReader { geometry in
            let readingY = geometry.size.height * Self.readingLine
            // Redrawn every frame only while the text is moving, so a take in a pocket costs
            // little more than a still screen.
            TimelineView(.animation(minimumInterval: nil, paused: resting && follower.isStill(toward: place) && !dragging)) { context in
                let y = frameY(at: context.date)
                WordColumn(tokens: tokens, heard: follower.mark, size: textSize, width: geometry.size.width)
                    .equatable()
                    .offset(y: readingY - y)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .scaleEffect(pinchScale, anchor: UnitPoint(x: 0, y: Self.readingLine))
            .clipped()
            .contentShape(Rectangle())
            .onPreferenceChange(WordFrames.self) { frames in
                let words = tokens.map(\.word)
                Task { @MainActor in layout = ScreenLayout(words: words, frames: frames) }
            }
            .gesture(drag)
            .simultaneousGesture(pinch)
        }
        .onChange(of: resume) {
            follower.moved()
            resting = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Script")
        .accessibilityValue(accessibilityValue)
    }

    /// The text's y this frame, noting whether it has come to rest, so the redraw pauses.
    private func frameY(at date: Date) -> CGFloat {
        let y = follower.y(at: date.timeIntervalSinceReferenceDate, place: place, layout: layout)
        let still = follower.isStill(toward: place)
        if still != resting { Task { @MainActor in resting = still } }
        return y
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged {
                if !dragging { dragging = true }
                follower.drag(by: $0.translation.height)
            }
            .onEnded { _ in
                follower.endDrag(at: Date.timeIntervalSinceReferenceDate)
                dragging = false
            }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = pinchBase ?? textSize
                pinchBase = base
                pinchScale = TakeSettings.clampTextSize(base * value.magnification) / base
            }
            .onEnded { value in
                let base = pinchBase ?? textSize
                textSize = TakeSettings.clampTextSize(base * value.magnification)
                pinchScale = 1
                pinchBase = nil
            }
    }

    private var accessibilityValue: String {
        let next = tokens.firstIndex { !$0.word.isCue && !$0.isHeard(before: follower.mark) } ?? 0
        return tokens[next...].prefix(12).map(\.word.text).joined(separator: " ")
    }
}

/// The step's words, wrapped, each reporting its frame. Equatable, so the frame-by-frame offset
/// does not rebuild three hundred words.
private struct WordColumn: View, Equatable {
    let tokens: [PromptViewModel.ScreenToken]
    /// The word after the last one heard, as the screen shows it: the words before it are dimmed.
    let heard: Int?
    let size: Double
    let width: CGFloat

    var body: some View {
        WordFlow(paragraphSpacing: size * 0.6) {
            ForEach(tokens, id: \.word.id) { token in
                WordView(token: token, isHeard: token.isHeard(before: heard), size: size)
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
        // Room below the last line, so it can reach the eyeline.
        .padding(.bottom, 600)
    }

    static let space = "screenText"
}

/// One word: dimmed once heard or before following, the voice's phrase on the mid-blue and its
/// word on the accent, a cue in the cue colour.
private struct WordView: View {
    let token: PromptViewModel.ScreenToken
    let isHeard: Bool
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
    }

    private var foreground: Color {
        if token.word.isCue { return EarwigTheme.cue }
        if token.isVoiceWord { return EarwigTheme.onAccent }
        if isHeard { return EarwigTheme.heardText }
        if token.isWaiting { return EarwigTheme.secondaryText }
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
