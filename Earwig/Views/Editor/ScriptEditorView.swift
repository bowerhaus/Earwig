import SwiftData
import SwiftUI

/// New, Edit and Edit a Copy (plan 015, decision 2): the script's text as it is, with Title, Step
/// and Cue under it and a line saying what it makes. Dictation is the keyboard's own.
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
                ScriptTextView(text: $editor.text, selection: editor.selection, controller: textView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(EarwigTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                // Our own bar, not a keyboard toolbar, which iOS 26 doesn't show in a sheet; it sits
                // just above the keyboard, and is there with it down too.
                HStack(spacing: 10) {
                    formatButton("Title", hint: "Goes to the script's title, or adds one at the top", ScriptEditor.titleChange)
                    formatButton("Step", hint: "Starts a new step here", ScriptEditor.stepChange)
                    formatButton("Cue", hint: "Puts square brackets here, for a cue", ScriptEditor.cueChange)
                    Spacer(minLength: 0)
                }
                // Three lines kept for it, so the bar above stays put when the hint gives way to
                // the count.
                Text(editor.summary)
                    .lineLimit(3, reservesSpace: true)
                    .font(.footnote)
                    .foregroundStyle(EarwigTheme.secondaryText)
                    .padding(.horizontal, 6)
            }
            .padding(16)
            .background(EarwigTheme.background)
            .navigationTitle(editor.heading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(EarwigTheme.background, for: .navigationBar)
            // White titles on the sky blue in the light scheme (plan 011, decision 16).
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { cancel() } label: { Text("Cancel").toolbarCapsule() }
                        .buttonStyle(.plain)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Text("Save").toolbarCapsule() }
                        .buttonStyle(.plain)
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

    private func formatButton(_ title: String, hint: String, _ change: @escaping (ScriptEditor.Edit) -> ScriptEditor.Change) -> some View {
        Button { textView.perform(change) } label: { Text(title).toolbarCapsule() }
            .buttonStyle(.plain)
            .accessibilityHint(hint)
    }

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

/// The question before a paste replaces changes made in Earwig (plan 015, decision 8).
enum ReplaceEdits {
    static let title = "Replace the changes made in Earwig?"
    static let message = "Changes made to this script in Earwig will be lost. Share it first to keep them."
}
