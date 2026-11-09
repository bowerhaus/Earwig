import SwiftUI

/// Listen (plan 004, decision 13): a step played straight through, with the step's text and
/// the word the voice is saying highlighted, so the timings, the speed and the latency
/// allowance can be checked by ear against the screen.
struct ListenView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var preview: StepPreview
    let title: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(statusText)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(statusColour)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Speed", selection: $preview.speed) {
                    ForEach(StepPreview.speeds, id: \.self) { speed in
                        Text(String(format: "%g×", speed)).tag(speed)
                    }
                }
                .pickerStyle(.segmented)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(lines, id: \.self) { line in
                                Text(text(ofLine: line))
                                    .font(.title3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(line)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: currentLine) { _, line in
                        guard let line else { return }
                        withAnimation { proxy.scrollTo(line, anchor: .center) }
                    }
                }

                Button {
                    if preview.isPlaying {
                        preview.stop()
                    } else {
                        Task { await preview.start() }
                    }
                } label: {
                    AccentPill(title: preview.isPlaying ? "Stop" : "Play", systemImage: preview.isPlaying ? "stop.fill" : "play.fill", expands: true)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(EarwigTheme.background)
            .navigationTitle("Listen · \(title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(EarwigTheme.background, for: .navigationBar)
            // White titles on the sky blue in the light scheme (plan 011, decision 16).
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    DoneButton { dismiss() }
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .task { await preview.start() }
        .onDisappear { preview.stop() }
    }

    private var statusText: String {
        switch preview.status {
        case .idle: "Ready"
        case .preparing: "Preparing"
        case .slate: "Slate"
        case .tones: "Tones"
        case .speaking: "Speaking"
        case .finished: "Finished"
        case .failed(let message): message
        }
    }

    private var statusColour: Color {
        if case .failed = preview.status { return EarwigTheme.warning }
        return preview.status == .slate ? EarwigTheme.cue : EarwigTheme.text
    }

    /// The step's line indices, in order.
    private var lines: [Int] {
        var seen = Set<Int>()
        return preview.phraseList.phrases.map(\.line).filter { seen.insert($0).inserted }
    }

    private var currentLine: Int? {
        preview.phrase.map { preview.phraseList.phrases[$0].line }
    }

    /// A line's phrases: the voice's phrase in the accent, the word it is saying on the accent,
    /// cues in the cue colour.
    private func text(ofLine line: Int) -> AttributedString {
        var result = AttributedString()
        for (index, stepPhrase) in preview.phraseList.phrases.enumerated() where stepPhrase.line == line {
            if !result.characters.isEmpty { result += AttributedString(" ") }
            let isCurrent = index == preview.phrase
            if stepPhrase.kind == .cue {
                var part = AttributedString("[\(stepPhrase.phrase.text)]")
                part.foregroundColor = isCurrent ? EarwigTheme.accent : EarwigTheme.cue
                part.font = .title3.italic()
                result += part
                continue
            }
            let token = isCurrent ? currentToken(in: index) : nil
            for (tokenIndex, phraseToken) in stepPhrase.phrase.tokens.enumerated() {
                if tokenIndex > 0 { result += AttributedString(" ") }
                var part = AttributedString(phraseToken.text)
                if tokenIndex == token {
                    part.foregroundColor = EarwigTheme.onAccent
                    part.backgroundColor = EarwigTheme.accent
                    part.font = .title3.bold()
                } else {
                    part.foregroundColor = isCurrent ? EarwigTheme.accent : EarwigTheme.text
                }
                result += part
            }
        }
        return result
    }

    /// The token of a phrase holding the word the voice is saying.
    private func currentToken(in phrase: Int) -> Int? {
        guard let word = preview.word else { return nil }
        let inPhrase = word - preview.script.firstWord[phrase]
        let wordTokens = preview.phraseList.phrases[phrase].phrase.tokens.indices.filter { preview.phraseList.phrases[phrase].phrase.tokens[$0].word != nil }
        return wordTokens.indices.contains(inPhrase) ? wordTokens[inPhrase] : nil
    }
}
