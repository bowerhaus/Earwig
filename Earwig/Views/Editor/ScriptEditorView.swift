import SwiftData
import SwiftUI

/// New and Edit (plan 015, decision 2): the script's text as it is, with Title, Step
/// and Cue on a bar above the keyboard and a line under the text saying what it makes.
/// Dictation is the keyboard's own.
struct ScriptEditorView: View {
    @State var editor: ScriptEditor
    /// Called with the saved script once the sheet has gone.
    let onSaved: (Script) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var confirmingDiscard = false
    @State private var error: String?
    @State private var textView = ScriptTextController()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                ScriptTextView(text: $editor.text, selection: editor.selection, cursor: $editor.cursor, controller: textView, tools: Self.tools)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(EarwigTheme.surface, in: RoundedRectangle(cornerRadius: EarwigButton.corner))
                // Three lines kept for it, so the text above stays put when the hint gives way to
                // the count.
                Text(editor.summary)
                    .lineLimit(3, reservesSpace: true)
                    .font(.footnote)
                    .foregroundStyle(EarwigTheme.secondaryText)
                    .padding(.horizontal, 6)
            }
            .padding(16)
            // Under the keyboard too, so the tools' glass floats on the sky blue, not on white.
            .background(EarwigTheme.background.ignoresSafeArea())
            .navigationTitle(editor.heading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(EarwigTheme.background, for: .navigationBar)
            // White titles on the sky blue in the light scheme (plan 011, decision 16).
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarWordButton("Cancel") { cancel() }
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarWordButton("Save") { save() }
                        .disabled(!editor.canSave)
                        .opacity(editor.canSave ? 1 : 0.4)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .confirmationDialog("Discard your changes?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
            }
            .alert("Can't save that", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
        }
        // A swipe down would lose the changes without asking.
        .interactiveDismissDisabled(editor.hasChanges)
        // Once the sheet is up, or the keyboard doesn't come.
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            textView.focus()
        }
    }

    /// Title, Step and Cue, on a bar above the keyboard (plan 015, decision 2).
    private static let tools: [ScriptTextView.Tool] = [
        .init(title: "Title", systemImage: "textformat.size", hint: "Goes to the script's title, or adds one at the top", change: ScriptEditor.titleChange),
        .init(title: "Step", systemImage: "list.number", hint: "Starts a new step, ready for its name", change: ScriptEditor.stepChange),
        .init(title: "Cue", systemImage: "text.bubble", hint: "Starts a cue in square brackets, or ends the one the cursor is in", change: ScriptEditor.cueChange),
    ]

    private func cancel() {
        if editor.hasChanges { confirmingDiscard = true } else { dismiss() }
    }

    private func save() {
        do {
            let script = try editor.save(in: context)
            dismiss()
            onSaved(script)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// The question before Reset Sample (plan 015, decision 7).
enum ResetSample {
    static let message = "Your changes to it will be lost. Its takes are kept."
}

/// The question before a paste replaces changes made in Earwig (plan 015, decision 8).
enum ReplaceEdits {
    static let title = "Replace the changes made in Earwig?"
    static let message = "Changes made to this script in Earwig will be lost. Share it first to keep them."
}
