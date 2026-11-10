import SwiftData
import SwiftUI
import UIKit

/// One script, step by step (PRD §8.2): lines, directions in the cue colour, the rendering
/// state, and the step a take will start from.
struct ScriptDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ScriptRenderer.self) private var renderer
    @AppStorage(TakeSettings.modeKey) private var mode: TakeMode = TakeSettings.defaultMode
    @AppStorage(TakeSettings.recordingKey) private var recording: TakeRecordingMode = .off
    @State private var model: ScriptDetailViewModel
    @State private var confirmingDelete = false
    /// Opens another script: the copy Edit a Copy saved (plan 015, decision 7).
    private let open: (Script) -> Void

    init(script: Script, open: @escaping (Script) -> Void = { _ in }) {
        _model = State(initialValue: ScriptDetailViewModel(script: script))
        self.open = open
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
            .listRowBackground(EarwigTheme.surface.critterCard())

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
                .listRowBackground(rowBackground(isStart: index == script.lastStep).critterCard())
            }

            // A sample's text is the app's, not the presenter's, and a sample is never deleted
            // (plan 011, decisions 5, 6 and 15).
            if !script.isSample {
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
                .listRowBackground(EarwigTheme.surface.critterCard())
                Section {
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("Delete Script", systemImage: "trash")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(EarwigTheme.warning)
                    }
                }
                .listRowBackground(EarwigTheme.surface.critterCard())
            }
        }
        .scrollContentBackground(.hidden)
        // White labels, pale headers and values, in the light scheme (plan 011, decision 16).
        .foregroundStyle(EarwigTheme.text, EarwigTheme.secondaryText)
        // Never during a take or while Listen is open; one walking goes at once (plan 014, decision 9).
        .critterVisits(keepAway: model.take != nil || model.preview != nil || model.editor != nil)
        .background(EarwigTheme.background)
        .navigationTitle(script.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(EarwigTheme.background, for: .navigationBar)
        // White titles on the sky blue in the light scheme (plan 011, decision 16).
        .toolbarColorScheme(.dark, for: .navigationBar)
        .earwigBackButton()
        .toolbar {
            // Share, the way back to the Mac, and Edit, or Edit a Copy for a sample (plan 015).
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: ScriptText(title: script.title, text: script.sourceText), preview: SharePreview(script.title)) {
                    Label("Share", systemImage: "square.and.arrow.up").toolbarCircle()
                }
                .buttonStyle(.plain)
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                // An icon, as Share is, so the title keeps its room; the sheet says Edit a Copy.
                Button { model.startEditing() } label: {
                    Label(script.isSample ? "Edit a Copy" : "Edit", systemImage: "square.and.pencil").toolbarCircle()
                }
                .buttonStyle(.plain)
            }
            .sharedBackgroundVisibility(.hidden)
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
        .task {
            // `-EarwigEdit YES` opens Edit, or Edit a Copy on a sample, for the simulator (plan 015).
            guard UserDefaults.standard.bool(forKey: "EarwigEdit"), model.editor == nil else { return }
            try? await Task.sleep(for: .seconds(1))
            model.startEditing()
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
        .sheet(item: $model.editor) { editor in
            ScriptEditorView(editor: editor) { saved in
                if saved === script { model.edited(with: renderer) } else { open(saved) }
            }
        }
        // Paste New Version over changes made in Earwig asks first (plan 015, decision 8).
        .confirmationDialog(
            ReplaceEdits.title,
            isPresented: Binding(get: { model.pendingNewVersion != nil }, set: { if !$0 { model.pendingNewVersion = nil } }),
            titleVisibility: .visible,
            presenting: model.pendingNewVersion
        ) { text in
            Button("Replace", role: .destructive) { model.confirmNewVersion(text, in: context, renderer: renderer) }
        } message: { _ in
            Text(ReplaceEdits.message)
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
                VStack(alignment: .leading, spacing: 6) {
                    Text("Record")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EarwigTheme.secondaryText)
                    HStack(spacing: 8) {
                        ForEach(TakeRecordingMode.allCases, id: \.self) { option in
                            RecordChip(recording: option, selected: option == recording) { recording = option }
                        }
                    }
                }
            }
            // Per script, so here by Start rather than in Settings (plan 011, decision 15): the
            // step's name and Shows in the slate, and its directions in the take.
            Toggle(isOn: Binding(get: { script.cuesOn }, set: { model.setCues($0, in: context) })) {
                Text("Read Cues")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EarwigTheme.secondaryText)
            }
            .tint(EarwigTheme.accent)
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
}

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

/// Off, Sound or Video on the start card (plan 010, decision 1): the same value as Settings.
private struct RecordChip: View {
    let recording: TakeRecordingMode
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(recording.label, systemImage: recording.systemImage)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(selected ? EarwigTheme.onAccent : EarwigTheme.text)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(selected ? EarwigTheme.accent : EarwigTheme.control, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Record \(recording.label)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A filled accent capsule with dark text, for the main action on a row or a sheet.
struct AccentPill: View {
    let title: String
    let systemImage: String
    var expands = false

    var body: some View {
        Label(title, systemImage: systemImage)
            // The word too in a toolbar, which shows a label's icon alone, so New and Paste are
            // told apart (plan 015).
            .labelStyle(.titleAndIcon)
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
