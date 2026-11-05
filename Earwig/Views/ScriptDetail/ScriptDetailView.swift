import SwiftData
import SwiftUI

/// One script, step by step (PRD §8.2): lines, directions in the cue colour, the rendering
/// state, and the step a take will start from.
struct ScriptDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var model: ScriptDetailViewModel
    @State private var confirmingDelete = false

    init(script: Script) {
        _model = State(initialValue: ScriptDetailViewModel(script: script))
    }

    private var script: Script { model.script }

    var body: some View {
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
                    Button {
                        model.select(step: index, in: context)
                    } label: {
                        StepView(step: step, isStart: index == script.lastStep, takes: script.takes(forStep: index))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Starts takes from this step")
                }
                .listRowBackground(EarwigTheme.surface)
            }

            Section {
                PasteButton(payloadType: String.self) { strings in
                    Task { @MainActor in model.pasteNewVersion(strings.first, in: context) }
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
                .tint(EarwigTheme.accent)
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
        .onAppear { model.appeared(in: context) }
        .confirmationDialog("Delete \(script.title)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Script", role: .destructive) {
                model.delete(in: context)
                dismiss()
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

    private var renderingRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .foregroundStyle(EarwigTheme.secondaryText)
            VStack(alignment: .leading, spacing: 2) {
                Text("Not rendered")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EarwigTheme.text)
                Text("\(script.phraseCount) phrases · \(script.format.label)")
                    .font(.footnote)
                    .foregroundStyle(EarwigTheme.secondaryText)
            }
        }
    }

    private var menu: some View {
        Menu {
            Toggle("Read Cues", isOn: Binding(get: { script.cuesOn }, set: { model.setCues($0, in: context) }))
            Button("Delete Script", systemImage: "trash", role: .destructive) { confirmingDelete = true }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }
}

#Preview {
    let container = ModelContainerFactory.inMemory()
    let script = try! ScriptImporter(context: container.mainContext).paste(SampleScript.harbourWalk).script
    return NavigationStack { ScriptDetailView(script: script) }
        .modelContainer(container)
        .tint(EarwigTheme.accent)
        .preferredColorScheme(EarwigTheme.scheme)
}
