import SwiftData
import SwiftUI
import UIKit

/// One script, step by step (PRD §8.2): lines, directions in the cue colour, the rendering
/// state, and the step a take will start from.
struct ScriptDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ScriptRenderer.self) private var renderer
    @AppStorage(AppSettings.inlineDirectionsKey) private var inlineDirections: InlineDirections = .chime
    @AppStorage(TakeSettings.modeKey) private var mode: TakeMode = TakeSettings.defaultMode
    @State private var model: ScriptDetailViewModel
    @State private var confirmingDelete = false

    init(script: Script) {
        _model = State(initialValue: ScriptDetailViewModel(script: script))
    }

    private var script: Script { model.script }

    var body: some View {
        // A deleted script must not be read while the screen pops away (SwiftData).
        if script.isDeleted || script.modelContext == nil {
            EarwigTheme.background.ignoresSafeArea()
        } else {
            content
        }
    }

    /// Whether the start step is rendered.
    private var isReady: Bool {
        if case .ready = model.renderState(renderer) { return true }
        return false
    }

    /// Whether a take can start: rendered, or on the screen alone, which needs no rendering
    /// (plan 008, decision 7).
    private var canStart: Bool { model.startStep != nil && (isReady || !mode.ear) }

    private var content: some View {
        List {
            Section {
                renderingRow
                if let preamble = script.preamble {
                    Text(preamble)
                        .font(.footnote)
                        .foregroundStyle(EarwigTheme.cue)
                }
            }
            .listRowBackground(EarwigTheme.surface)

            ForEach(Array(script.orderedSteps.enumerated()), id: \.element.persistentModelID) { index, step in
                Section {
                    if index == script.lastStep {
                        // The start step: its Start button starts a take; the card itself is not
                        // a button, so the two never nest.
                        StepView(step: step, isStart: true, takes: script.takes(forStep: index), nextTake: script.nextTakeNumber(forStep: index),
                                 start: canStart ? { model.startTake(with: renderer, in: context) } : nil)
                    } else {
                        Button {
                            model.select(step: index, in: context, renderer: renderer)
                        } label: {
                            StepView(step: step, isStart: false, takes: script.takes(forStep: index), nextTake: script.nextTakeNumber(forStep: index))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Starts takes from this step")
                    }
                }
                .listRowBackground(rowBackground(isStart: index == script.lastStep))
            }

            Section {
                // Our own button, as on the Scripts screen, so it is the accent yellow.
                Button { model.pasteNewVersion(UIPasteboard.general.string, in: context, renderer: renderer) } label: {
                    AccentPill(title: "Paste New Version", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.plain)
            } footer: {
                Text("Paste a new version of this script. Its takes are kept.")
                    .foregroundStyle(EarwigTheme.secondaryText)
            }
            .listRowBackground(EarwigTheme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(EarwigTheme.background)
        .navigationTitle(script.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(EarwigTheme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { menu }
        }
        .onAppear { model.appeared(in: context, renderer: renderer) }
        #if DEBUG
        .task {
            // `-EarwigScreen YES` starts a take on the screen alone, which needs no rendering
            // (plan 008); with `-EarwigReads YES` it hears the step read.
            guard UserDefaults.standard.bool(forKey: "EarwigScreen"), model.take == nil else { return }
            try? await Task.sleep(for: .seconds(1))
            model.startTake(with: renderer, in: context, mode: .screen)
        }
        .onChange(of: model.renderState(renderer)) { _, state in
            // `-EarwigListen YES` opens Listen once the start step is ready, for the simulator.
            // After a moment, as a sheet asked for during the navigation push is dropped.
            if case .ready = state, UserDefaults.standard.bool(forKey: "EarwigListen"), model.preview == nil {
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    model.listen(with: renderer)
                }
            }
            // `-EarwigTake YES` starts a take once the start step is ready.
            if case .ready = state, UserDefaults.standard.bool(forKey: "EarwigTake"), model.take == nil {
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    model.startTake(with: renderer, in: context)
                }
            }
        }
        #endif
        .fullScreenCover(isPresented: Binding(get: { model.take != nil }, set: { if !$0 { model.endTake() } })) {
            if let take = model.take {
                PromptView(
                    host: take,
                    onNextTake: { model.nextTake(with: renderer, in: context) },
                    onDone: { model.endTake() }
                )
            }
        }
        .sheet(item: $model.preview) { preview in
            ListenView(preview: preview, title: model.startStep.map { "Step \($0.number)" } ?? "Listen")
        }
        .confirmationDialog("Delete \(script.title)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Script", role: .destructive) {
                dismiss()
                model.delete(in: context)
            }
        } message: {
            Text("Its takes go with it.")
        }
        .alert("Can't paste that", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.error ?? "")
        }
        .alert(model.notice ?? "", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    /// The surface, with an accent bar down the leading edge of the start step.
    private func rowBackground(isStart: Bool) -> some View {
        HStack(spacing: 0) {
            if isStart { EarwigTheme.accent.frame(width: 5) }
            EarwigTheme.surface
        }
    }

    private var renderingRow: some View {
        let state = model.renderState(renderer)
        let stepNumber = model.startStep?.number ?? 1
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: renderIcon(state))
                    .foregroundStyle(renderIconColour(state))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(renderTitle(state, step: stepNumber))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EarwigTheme.text)
                    Text(renderDetail(state))
                        .font(.footnote)
                        .foregroundStyle(EarwigTheme.secondaryText)
                }
                Spacer(minLength: 8)
                renderAction(state)
            }
            if case .rendering(_, let done, let total) = state {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .tint(EarwigTheme.accent)
            }
            if model.startStep != nil {
                // Ear, Screen or both, chosen before the take (plan 008, decision 6): the same
                // value as Settings.
                Picker("Mode", selection: $mode) {
                    ForEach(TakeMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Take mode")
            }
            if canStart {
                // Start, not a tap on a step: a take started by accident while scrolling is
                // worse than one more tap (plan 005, decision 8).
                HStack(spacing: 12) {
                    if isReady {
                        Button { model.listen(with: renderer) } label: {
                            Label("Listen", systemImage: "headphones")
                                .font(.subheadline.bold())
                                .frame(minHeight: 34)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(EarwigTheme.accent)
                    }
                    Button { model.startTake(with: renderer, in: context) } label: {
                        AccentPill(title: "Start Take \(model.nextTakeNumber)", systemImage: "play.fill", expands: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let voices = renderer.voices, !voices.presenterIsPreferred {
                Text("\(VoiceCatalogue.preferredName) (Enhanced) isn't on this iPhone, so the voice is \(voices.presenter.displayName). \(VoiceCatalogue.downloadHint)")
                    .font(.footnote)
                    .foregroundStyle(EarwigTheme.caution)
            }
        }
    }

    private func renderIcon(_ state: ScriptRenderer.State) -> String {
        switch state {
        case .ready: "waveform"
        case .failed: "exclamationmark.triangle.fill"
        case .rendering, .idle: "waveform.badge.ellipsis"
        }
    }

    private func renderIconColour(_ state: ScriptRenderer.State) -> Color {
        switch state {
        case .ready: EarwigTheme.good
        case .failed: EarwigTheme.warning
        case .rendering, .idle: EarwigTheme.secondaryText
        }
    }

    private func renderTitle(_ state: ScriptRenderer.State, step: Int) -> String {
        switch state {
        case .idle: "Step \(step) not rendered"
        case .rendering(_, let done, let total): "Rendering step \(step): \(done) of \(total)"
        case .ready: "Step \(step) ready in \(renderer.voices?.presenter.name ?? "the voice")"
        case .failed: "Step \(step) could not be rendered"
        }
    }

    private func renderDetail(_ state: ScriptRenderer.State) -> String {
        if case .failed(_, let message) = state { return message }
        let phrases = model.startStep?.phraseList.phrases.count ?? 0
        return "\(phrases) phrases · \(script.format.label)"
    }

    @ViewBuilder
    private func renderAction(_ state: ScriptRenderer.State) -> some View {
        switch state {
        case .ready:
            EmptyView()
        case .failed, .idle:
            Button("Render") { model.renderStartStep(with: renderer) }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(EarwigTheme.accent)
        case .rendering:
            EmptyView()
        }
    }

    private var menu: some View {
        Menu {
            Toggle("Read Cues", isOn: Binding(get: { script.cuesOn }, set: { model.setCues($0, in: context) }))
            // App settings, here until the Settings screen (stage 7).
            Picker("Voice", systemImage: "person.wave.2", selection: Binding(
                get: { renderer.voices?.presenter.identifier ?? "" },
                set: { model.usePresenter($0, renderer: renderer) }
            )) {
                ForEach(model.presenterOptions, id: \.identifier) { Text($0.displayName).tag($0.identifier) }
            }
            .pickerStyle(.menu)
            // Listed again once Personal Voice has been allowed.
            .id(model.personalVoiceAsked)
            if model.canAskForPersonalVoice {
                Button("Allow Personal Voice", systemImage: "person.crop.circle.badge.checkmark") {
                    Task { await model.askForPersonalVoice() }
                }
            }
            Picker("Directions in a Line", systemImage: "bell", selection: $inlineDirections) {
                ForEach(InlineDirections.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            Button("Delete Script", systemImage: "trash", role: .destructive) { confirmingDelete = true }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }
}

/// A filled accent capsule with dark text, for the main action on a row or a sheet.
struct AccentPill: View {
    let title: String
    let systemImage: String
    var expands = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(expands ? .title3.bold() : .subheadline.bold())
            .foregroundStyle(EarwigTheme.onAccent)
            .frame(maxWidth: expands ? .infinity : nil, minHeight: expands ? 52 : 34)
            .padding(.horizontal, 14)
            .background(EarwigTheme.accent, in: Capsule())
            .contentShape(Capsule())
    }
}

#Preview {
    let container = ModelContainerFactory.inMemory()
    let script = try! ScriptImporter(context: container.mainContext).paste(SampleScript.harbourWalk).script
    return NavigationStack { ScriptDetailView(script: script) }
        .modelContainer(container)
        .environment(ScriptRenderer.live())
        .tint(EarwigTheme.accent)
        .preferredColorScheme(EarwigTheme.scheme)
}
