import SwiftData
import SwiftUI
import UIKit

/// The imported scripts (PRD §8.1). Paste from the clipboard, swipe to delete, tap to open.
struct ScriptsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Script.updatedAt, order: .reverse) private var scripts: [Script]
    @State private var model = ScriptsViewModel()

    var body: some View {
        NavigationStack(path: $model.path) {
            Group {
                if scripts.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(EarwigTheme.background)
            .navigationTitle("Scripts")
            .toolbarBackground(EarwigTheme.background, for: .navigationBar)
            .toolbar {
                if !scripts.isEmpty {
                    ToolbarItem(placement: .primaryAction) { pasteButton }
                }
            }
            .navigationDestination(for: Script.self) { script in
                ScriptDetailView(script: script)
            }
            .alert("Can't paste that", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.error ?? "")
            }
            #if DEBUG
            .task {
                // `-EarwigDemo YES` adds the sample and opens it, for simulator screenshots.
                if UserDefaults.standard.bool(forKey: "EarwigDemo") { model.addSample(in: context) }
            }
            #endif
        }
    }

    private var list: some View {
        List {
            ForEach(scripts) { script in
                NavigationLink(value: script) {
                    ScriptRow(script: script)
                }
                .listRowBackground(EarwigTheme.surface)
            }
            .onDelete { offsets in
                model.delete(offsets.map { scripts[$0] }, in: context)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var empty: some View {
        VStack(spacing: 20) {
            Image(systemName: "ear")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(EarwigTheme.accent)
            Text("No scripts yet")
                .font(.title2.bold())
                .foregroundStyle(EarwigTheme.text)
            Text("Copy a script on your Mac, a Cutaway script.md or plain text, then paste it here.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(EarwigTheme.secondaryText)
            pasteButton
                .controlSize(.large)
            Button("Try the sample") { model.addSample(in: context) }
                .foregroundStyle(EarwigTheme.accent)
        }
        .padding(32)
        .frame(maxWidth: 420)
    }

    /// Our own button, not SwiftUI's `PasteButton`: iOS darkens a `PasteButton`'s tint to keep
    /// its white text legible, which turned the accent gold-brown. Reading the clipboard ourselves
    /// asks "Allow Paste?" until Settings › Apps › Earwig › Paste from Other Apps is Allow.
    private var pasteButton: some View {
        Button { model.paste(UIPasteboard.general.string, in: context) } label: {
            AccentPill(title: "Paste", systemImage: "doc.on.clipboard")
        }
        .buttonStyle(.plain)
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
        return "\(stepText) · \(script.format.label) · \(take)"
    }
}

#Preview {
    let container = ModelContainerFactory.inMemory()
    _ = try? ScriptImporter(context: container.mainContext).paste(SampleScript.harbourWalk)
    return ScriptsView()
        .modelContainer(container)
        .environment(ScriptRenderer.live())
        .tint(EarwigTheme.accent)
        .preferredColorScheme(EarwigTheme.scheme)
}
