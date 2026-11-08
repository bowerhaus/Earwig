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
    private var canStart: Bool { model.startStep != nil && (isReady || !mode.voiced) }

    private var content: some View {
        List {
            Section {
                startCard
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

    /// The start card (Andy, device check 1 of plan 008): the step and take a take will be, the
    /// two modes as tiles that only choose (the same value as Settings), Listen once the step is
    /// rendered, and the rendering itself only while it runs or if it failed. Start Take is on
    /// the start step's own card.
    private var startCard: some View {
        let state = model.renderState(renderer)
        let stepNumber = model.startStep?.number ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            Text("Step \(stepNumber) · take \(model.nextTakeNumber)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EarwigTheme.secondaryText)
            if model.startStep != nil {
                HStack(spacing: 10) {
                    ForEach(TakeMode.allCases, id: \.self) { option in
                        ModeTile(mode: option, selected: option == mode) { mode = option }
                    }
                }
            }
            renderStatus(state, step: stepNumber)
            if isReady {
                Button { model.listen(with: renderer) } label: {
                    Label("Listen to Step \(stepNumber)", systemImage: "headphones")
                        .font(.subheadline.bold())
                        .foregroundStyle(EarwigTheme.accent)
                        .frame(minHeight: 32)
                }
                .buttonStyle(.borderless)
            }
            if let voices = renderer.voices, !voices.presenterIsPreferred {
                Text("\(VoiceCatalogue.preferredName) (Enhanced) isn't on this iPhone, so the voice is \(voices.presenter.displayName). \(VoiceCatalogue.downloadHint)")
                    .font(.footnote)
                    .foregroundStyle(EarwigTheme.caution)
            }
        }
        .padding(.vertical, 4)
    }

    /// The rendering, shown only while it runs, when it failed, or when the voice needs it and
    /// it has not started.
    @ViewBuilder
    private func renderStatus(_ state: ScriptRenderer.State, step: Int) -> some View {
        switch state {
        case .rendering(_, let done, let total):
            VStack(alignment: .leading, spacing: 6) {
                Label("Rendering step \(step): \(done) of \(total)", systemImage: "waveform.badge.ellipsis")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(EarwigTheme.secondaryText)
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .tint(EarwigTheme.accent)
            }
        case .failed(_, let message):
            renderProblem("Step \(step) could not be rendered: \(message)", colour: EarwigTheme.warning)
        case .idle:
            if mode.voiced { renderProblem("Step \(step) is not rendered yet.", colour: EarwigTheme.secondaryText) }
        case .ready:
            EmptyView()
        }
    }

    private func renderProblem(_ text: String, colour: Color) -> some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(colour)
            Spacer(minLength: 8)
            Button { model.renderStartStep(with: renderer) } label: {
                AccentPill(title: "Render", systemImage: "waveform")
            }
            .buttonStyle(.borderless)
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
/// A mode as a large tile on the start card: its icon and name, on the accent when chosen.
/// It only chooses; Start Take is on the start step's card.
private struct ModeTile: View {
    let mode: TakeMode
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // One height for both icons, so the names line up.
                Image(systemName: mode.systemImage)
                    .font(.title2.weight(.semibold))
                    .frame(height: 30)
                Text(mode.label)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? EarwigTheme.onAccent : EarwigTheme.text)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(selected ? EarwigTheme.accent : EarwigTheme.control, in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        // Borderless, so each tile in the row takes its own tap.
        .buttonStyle(.borderless)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct AccentPill: View {
    let title: String
    let systemImage: String
    var expands = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(expands ? .title3.bold() : .subheadline.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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
