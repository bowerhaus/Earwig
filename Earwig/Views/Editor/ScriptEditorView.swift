import SwiftData
import SwiftUI

/// New, Edit and Edit a Copy (plan 015, decision 2): the script's text as it is, with Title, Step
/// and Cue above the keyboard and a line under the text saying what it makes. Dictation is the
/// keyboard's own.
struct ScriptEditorView: View {
    @State var editor: ScriptEditor
    /// Called with the saved script once the sheet has gone.
    let onSaved: (Script) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @FocusState private var focused: Bool
    @State private var confirmingDiscard = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                TextEditor(text: $editor.text, selection: selection)
                    .focused($focused)
                    .font(.body)
                    .foregroundStyle(EarwigTheme.text)
                    .tint(EarwigTheme.accent)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(EarwigTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Script")
                Text(editor.summary)
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
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Title") { editor.addTitle() }
                        .accessibilityHint("Goes to the script's title, or adds one at the top")
                    Button("Step") { editor.addStep() }
                        .accessibilityHint("Starts a new step here")
                    Button("Cue") { editor.addCue() }
                        .accessibilityHint("Puts square brackets here, for a cue")
                    Spacer()
                }
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
        .onAppear { focused = true }
    }

    /// The editor's character offsets as SwiftUI's selection, kept inside the text.
    private var selection: Binding<TextSelection?> {
        Binding {
            let text = editor.text
            let range = ScriptEditor.clamped(editor.selection, in: text)
            let lower = text.index(text.startIndex, offsetBy: range.lowerBound)
            let upper = text.index(text.startIndex, offsetBy: range.upperBound)
            return TextSelection(range: lower..<upper)
        } set: { selection in
            guard case .selection(let range) = selection?.indices else { return }
            let text = editor.text
            guard range.lowerBound >= text.startIndex, range.upperBound <= text.endIndex else { return }
            editor.selection = text.distance(from: text.startIndex, to: range.lowerBound)..<text.distance(from: text.startIndex, to: range.upperBound)
        }
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
    static let message = "Changes made to this script in Earwig will be lost. Share it first to keep them."
}
