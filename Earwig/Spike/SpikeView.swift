import SwiftUI

/// The throwaway spike screen for plan 001: voices, render, play, route, listen, mark, gate.
struct SpikeView: View {
    @State private var model = SpikeModel()
    @State private var showPhrases = false

    var body: some View {
        NavigationStack {
            List {
                routeSection
                voiceSection
                scriptSection
                takeSection
                listenSection
                logSection
            }
            .navigationTitle("Earwig spike")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { markBar }
            .scrollDismissesKeyboard(.interactively)
        }
        .task { await model.onAppear() }
    }

    // MARK: - Route

    private var routeSection: some View {
        Section("Route") {
            let route = model.session.route
            Label(route.outputs.map { "\($0.name) · \(AudioRoute.label($0.type))" }.joined(separator: ", ").ifEmpty("No output"), systemImage: "earbuds")
                .foregroundStyle(route.isHandsFree ? EarwigTheme.warning : (route.isBluetoothA2DP ? EarwigTheme.good : EarwigTheme.caution))
            Label(route.inputs.map { "\($0.name) · \(AudioRoute.label($0.type))" }.joined(separator: ", ").ifEmpty("No input"), systemImage: "mic")
                .foregroundStyle(route.inputIsBuiltInMic ? EarwigTheme.good : EarwigTheme.warning)
            if route.isHandsFree {
                Label("The earpiece is in the hands-free profile: telephone quality and its own mic.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(EarwigTheme.warning)
                    .font(.callout.bold())
            } else if !route.inputIsBuiltInMic {
                Label("The input is not the iPhone's built-in mic.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(EarwigTheme.warning)
                    .font(.callout.bold())
            }
            if let started = model.watchStartedAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = Int(context.date.timeIntervalSince(started))
                    Text("Watching \(elapsed / 60)m \(elapsed % 60)s · changes \(model.routeChanges) · ever hands-free \(model.everHandsFree ? "YES" : "no") · ever off built-in mic \(model.everNotBuiltInMic ? "YES" : "no")")
                        .font(.caption)
                        .foregroundStyle(model.everHandsFree || model.everNotBuiltInMic ? EarwigTheme.warning : EarwigTheme.muted)
                }
                Button("Reset route watch") { model.resetWatch() }
            }
            if let error = model.session.lastError {
                Text(error).font(.caption).foregroundStyle(EarwigTheme.warning)
            }
        }
    }

    // MARK: - Voice

    private var voiceSection: some View {
        Section {
            HStack {
                Text("Personal Voice: \(model.personalVoiceStatus)")
                Spacer()
                Button("Ask") { Task { await model.requestPersonalVoice() } }
            }
            Toggle("All languages", isOn: $model.showAllLanguages)
            Picker("Voice", selection: $model.selectedVoiceID) {
                ForEach(model.voices) { voice in
                    Text("\(voice.name) · \(voice.quality) · \(voice.language)").tag(Optional(voice.id))
                }
            }
            .pickerStyle(.navigationLink)
            VStack(alignment: .leading) {
                Text(String(format: "Rate %.2f (render time)", model.rate))
                Slider(value: $model.rate, in: 0.35...0.65, step: 0.01)
            }
        } header: {
            Text("Voice")
        } footer: {
            Text("Download Enhanced and Premium voices in Settings › Accessibility › Spoken Content › Voices. Personal Voice is made in Settings › Accessibility › Personal Voice, with “Allow Apps to Request to Use” on.")
        }
    }

    // MARK: - Script

    private var scriptSection: some View {
        Section("Script") {
            TextEditor(text: $model.scriptText)
                .frame(minHeight: 120)
                .font(.callout)
            HStack {
                PasteButton(payloadType: String.self) { strings in
                    if let text = strings.first { model.scriptText = text }
                }
                .labelStyle(.titleAndIcon)
                Button("Clear", role: .destructive) { model.scriptText = "" }
                    .buttonStyle(.borderless)
                    .disabled(model.scriptText.isEmpty)
                Spacer()
                if model.renderProgress != nil {
                    Button("Cancel", role: .cancel) { model.cancelRender() }
                } else {
                    Button("Render") { model.render() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            if let progress = model.renderProgress {
                ProgressView(value: progress) { Text("Rendering \(model.renders.count + 1) of \(model.phrases.count)") }
            }
            if !model.renderSummary.isEmpty {
                Text(model.renderSummary).font(.caption)
            }
            if !model.renders.isEmpty {
                DisclosureGroup("Phrases (\(model.renders.count))", isExpanded: $showPhrases) {
                    ForEach(model.renders, id: \.phraseIndex) { render in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(render.phraseIndex + 1). \(render.phrase.text)").font(.callout)
                            Text(String(format: "%.2f s render, %.2f s audio, RTF %.2f, markers %@ (%@)", render.renderSeconds, render.duration, render.realTimeFactor, render.markerSource, render.markerUnit.rawValue))
                                .font(.caption2)
                                .foregroundStyle(EarwigTheme.muted)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Take

    private var takeSection: some View {
        Section {
            Picker("Mode", selection: $model.mode) {
                ForEach(SpikeModel.Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Loop take until Stop", isOn: $model.loopTake)
            Stepper(value: $model.lead, in: 0...10) {
                Text("Lead \(model.lead) words\(model.secondsPerWord.map { String(format: " ≈ %.1f s", Double(model.lead) * $0) } ?? "")")
            }
            VStack(alignment: .leading) {
                Text(String(format: "Speed %.2fx", model.speed))
                Slider(value: $model.speed, in: 0.8...1.25, step: 0.05)
            }
            HStack {
                Button("Start take") { Task { await model.startTake() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canStart)
                Spacer()
                Button("Release") { model.releaseGate() }
                    .disabled(!isWaiting)
                Spacer()
                Button("Stop", role: .destructive) { model.stop() }
                    .disabled(model.playState == .idle)
            }
            .buttonStyle(.bordered)
            Text(stateText).font(.headline)
            if model.playState != .idle {
                Text("Voice word \(model.voicePosition + 1) · heard word \(model.heardPosition + 1) · voice ahead by \(model.voicePosition - model.heardPosition)")
                    .font(.caption)
                    .monospacedDigit()
            }
        } header: {
            Text("Take")
        } footer: {
            Text("Gated: the next phrase starts when the heard position is within the lead of the end of the current phrase.")
        }
    }

    private var loopText: String {
        model.loopTake && model.loopCount > 0 ? " · loop \(model.loopCount + 1)" : ""
    }

    private var isWaiting: Bool {
        if case .waiting = model.playState { return true }
        return false
    }

    private var stateText: String {
        switch model.playState {
        case .idle: "Idle"
        case .speaking(let index): "Speaking phrase \(index + 1) of \(model.renders.count)\(loopText)"
        case .waiting(let index): "Waiting after phrase \(index + 1)\(loopText)"
        case .finished: "Finished"
        }
    }

    // MARK: - Listen

    private var listenSection: some View {
        Section("Listen") {
            Toggle("Fast results", isOn: $model.fastResults)
            Toggle("Script words as context", isOn: $model.scriptAsContext)
            HStack {
                Text(listenStateText)
                Spacer()
                if model.listener.state == .listening {
                    Button("Stop") { Task { await model.stopListening() } }
                } else {
                    Button("Listen") { Task { await model.startListening() } }
                }
            }
            Text("Assets \(model.listener.localeIdentifier): \(model.listener.assetStatus)").font(.caption)
            ProgressView(value: Double(model.inputLevel)) { Text("Mic level").font(.caption) }
            Text(statsText).font(.caption).monospacedDigit()
            ForEach(model.heardTail) { word in
                HStack {
                    Text(word.text).fontWeight(word.isFinal ? .regular : .light).italic(!word.isFinal)
                    Spacer()
                    Text(String(format: "%.2f s", word.delay)).monospacedDigit()
                    if let final = word.finalDelay {
                        Text(String(format: "final %.2f s", final)).monospacedDigit().foregroundStyle(EarwigTheme.muted)
                    }
                }
                .font(.callout)
            }
            ForEach(model.marks, id: \.self) { Text($0).font(.caption) }
        }
    }

    private var listenStateText: String {
        switch model.listener.state {
        case .idle: "Not listening"
        case .preparing: "Preparing…"
        case .downloading(let progress): String(format: "Downloading speech assets %.0f%%", progress * 100)
        case .listening: "Listening"
        case .failed(let message): "Failed: \(message)"
        }
    }

    private var statsText: String {
        let fmt: (Double?) -> String = { $0.map { String(format: "%.2f s", $0) } ?? "–" }
        return "Heard \(model.heardCount) · median \(fmt(model.medianDelay)) · p90 \(fmt(model.p90Delay)) · to final \(fmt(model.medianFinalDelay)) · accuracy \(model.accuracy.map { String(format: "%.0f%%", $0 * 100) } ?? "–")"
    }

    // MARK: - Log

    private var logSection: some View {
        Section("Log (\(model.log.count) lines)") {
            HStack {
                ShareLink(item: model.logText) { Label("Share log", systemImage: "square.and.arrow.up") }
                Spacer()
                Button("Clear", role: .destructive) { model.clearLog() }
            }
            ForEach(Array(model.log.suffix(30).reversed().enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption2.monospaced()).textSelection(.enabled)
            }
        }
    }

    // MARK: - Mark

    private var markBar: some View {
        Button {
            model.mark()
        } label: {
            Text("Mark: tap as you say a word")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .padding(.bottom, 4)
        .background(.bar)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}

#Preview {
    SpikeView()
}
