import SwiftData
import SwiftUI
import UIKit

/// The scripts (PRD §8.1): the presenter's own at the top, swipe to delete, and the built-in
/// samples below them, which cannot be deleted but can be edited and reset (plans 011 and 015).
/// Paste from the clipboard, or New to write one; tap to open, swipe to edit.
struct ScriptsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Script.updatedAt, order: .reverse) private var scripts: [Script]
    @State private var model = ScriptsViewModel()
    @State private var showingSettings = false
    #if DEBUG
    @State private var openedDemo = false
    #endif

    private var own: [Script] { scripts.filter { !$0.isSample } }
    private var samples: [Script] { SampleSeeder.ordered(scripts) }

    var body: some View {
        NavigationStack(path: $model.path) {
            list
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Between the sky blue and the cards, so a walk under them shows in the gaps; none
                // while Settings is up over the list (plan 014).
                .critterVisits(keepAway: showingSettings || model.editor != nil)
                .background(EarwigTheme.background)
                .navigationTitle("Scripts")
                // No bar background of its own: the screen's sky blue is behind it, and setting one
                // makes iOS ignore the white large title set in `EarwigApp` (plan 011, decision 16).
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingSettings = true } label: {
                            Label("Settings", systemImage: "gearshape").toolbarCircle()
                        }
                        .buttonStyle(.plain)
                    }
                    .sharedBackgroundVisibility(.hidden)
                    // While there are none of their own, the paste row has the buttons. Words in
                    // the toolbar's capsules, as on every screen (plan 015, decision 12).
                    if !own.isEmpty {
                        ToolbarItem(placement: .primaryAction) { ToolbarWordButton("New") { model.newScript() } }
                            // No glass capsule around it (iOS 26 draws one for every item).
                            .sharedBackgroundVisibility(.hidden)
                        ToolbarItem(placement: .primaryAction) { ToolbarWordButton("Paste") { paste() } }
                            .sharedBackgroundVisibility(.hidden)
                    }
                }
                .navigationDestination(for: Script.self) { script in
                    ScriptDetailView(script: script)
                }
                .sheet(isPresented: $showingSettings) { SettingsView() }
                // New opens what it saved; Edit from a swipe stays on the list.
                .sheet(item: $model.editor) { editor in
                    ScriptEditorView(editor: editor) { saved in
                        if case .new = editor.mode { model.open(saved) }
                    }
                }
                // A paste over changes made in Earwig asks first (plan 015, decision 8).
                .confirmationDialog(
                    ReplaceEdits.title,
                    isPresented: Binding(get: { model.pendingPaste != nil }, set: { if !$0 { model.cancelPaste() } }),
                    titleVisibility: .visible,
                    presenting: model.pendingPaste
                ) { pending in
                    Button("Replace", role: .destructive) { model.confirmPaste(pending, in: context) }
                } message: { _ in
                    Text(ReplaceEdits.message)
                }
                .alert("Can't paste that", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(model.error ?? "")
                }
                // The same question as Delete Script on the Script screen (#35).
                .confirmationDialog(
                    "Delete \(model.pendingDeletion?.title ?? "")?",
                    isPresented: Binding(get: { model.pendingDeletion != nil }, set: { if !$0 { model.cancelDeletion() } }),
                    titleVisibility: .visible,
                    presenting: model.pendingDeletion
                ) { script in
                    Button("Delete Script", role: .destructive) { model.confirmDeletion(of: script, in: context) }
                } message: { _ in
                    Text("Its takes go with it.")
                }
                .confirmationDialog(
                    "Reset \(model.pendingReset?.title ?? "")?",
                    isPresented: Binding(get: { model.pendingReset != nil }, set: { if !$0 { model.cancelReset() } }),
                    titleVisibility: .visible,
                    presenting: model.pendingReset
                ) { script in
                    Button("Reset Sample", role: .destructive) { model.confirmReset(of: script, in: context) }
                } message: { _ in
                    Text(ResetSample.message)
                }
                #if DEBUG
                .task(id: samples.count) {
                    // `-EarwigDemo YES` opens the Harbour Walk sample, for simulator screenshots,
                    // once the list has loaded it.
                    guard UserDefaults.standard.bool(forKey: "EarwigDemo"), !openedDemo,
                          let walk = samples.first(where: { $0.sampleID == "harbour-walk" }) else { return }
                    openedDemo = true
                    // A path set in the first instant after launch can be dropped by the stack.
                    try? await Task.sleep(for: .milliseconds(400))
                    model.open(walk)
                }
                .task {
                    // `-EarwigNew YES` opens New, for the simulator (plan 015).
                    guard UserDefaults.standard.bool(forKey: "EarwigNew") else { return }
                    try? await Task.sleep(for: .seconds(1))
                    model.newScript()
                }
                #endif
        }
    }

    private var list: some View {
        List {
            Section {
                if own.isEmpty {
                    pasteHint
                } else {
                    ForEach(own) { script in
                        NavigationLink(value: script) {
                            ScriptRow(script: script)
                        }
                        // Not `.onDelete`, which deletes at once, nor a destructive role or a
                        // full swipe, which slide the row away before the question is answered
                        // (plan 012, decision 14).
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button { model.askToDelete(script) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(EarwigTheme.warning)
                            editAction(script)
                        }
                    }
                }
            }
            .listRowBackground(EarwigTheme.surface.critterCard())
            Section {
                ForEach(samples) { script in
                    NavigationLink(value: script) {
                        ScriptRow(script: script)
                    }
                    // Edit, as on the Script screen, and Reset once edited (plan 015, decision 7).
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if script.isEditedSample {
                            Button { model.askToReset(script) } label: {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                            }
                            .tint(EarwigTheme.warning)
                        }
                        editAction(script)
                    }
                }
            } header: {
                Text("Samples")
                    .foregroundStyle(EarwigTheme.secondaryText)
            }
            .listRowBackground(EarwigTheme.surface.critterCard())
        }
        .scrollContentBackground(.hidden)
    }

    /// Edit from a swipe: a shortcut to the Script screen's Edit (plan 015, decision 12).
    private func editAction(_ script: Script) -> some View {
        Button { model.edit(script) } label: {
            Label("Edit", systemImage: "square.and.pencil")
        }
        .tint(EarwigTheme.surface)
    }

    /// In place of the presenter's own scripts while there are none.
    private var pasteHint: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste a script you've copied, or write a new one.")
                .font(.body)
                .foregroundStyle(EarwigTheme.text)
            HStack(spacing: 10) {
                pasteButton
                newButton
            }
        }
        .padding(.vertical, 8)
    }

    /// New: the editor on an empty script (plan 015, decision 1).
    private var newButton: some View {
        Button { model.newScript() } label: {
            AccentPill(title: "New", systemImage: "square.and.pencil")
        }
        .buttonStyle(.plain)
    }

    /// Our own button, not SwiftUI's `PasteButton`: iOS darkens a `PasteButton`'s tint to keep
    /// its white text legible, which turned the accent gold-brown. Reading the clipboard ourselves
    /// asks "Allow Paste?" until Settings › Apps › Earwig › Paste from Other Apps is Allow.
    private var pasteButton: some View {
        Button { paste() } label: {
            AccentPill(title: "Paste", systemImage: "doc.on.clipboard")
        }
        .buttonStyle(.plain)
    }

    private func paste() {
        model.paste(UIPasteboard.general.string, in: context)
    }
}

private struct ScriptRow: View {
    let script: Script

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(script.title)
                .font(.headline)
                .foregroundStyle(EarwigTheme.text)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(EarwigTheme.secondaryText)
        }
        .padding(.vertical, 4)
    }

    private var detail: String {
        let steps = script.steps?.count ?? 0
        let stepText = steps == 1 ? "1 step" : "\(steps) steps"
        let take = script.lastTake.map { "last take \($0.startedAt.formatted(.relative(presentation: .named)))" } ?? "no takes yet"
        // No format label: users see one format (plan 015, decision 5).
        return "\(stepText) · \(take)"
    }
}

#Preview {
    let container = ModelContainerFactory.inMemory()
    try? SampleSeeder(context: container.mainContext).seed()
    return ScriptsView()
        .modelContainer(container)
        .environment(ScriptRenderer.live())
        .tint(EarwigTheme.accent)
        .preferredColorScheme(EarwigTheme.scheme)
}
