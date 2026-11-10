import SwiftUI
import UIKit

/// The editor's text view (plan 015, decision 2): UIKit's, so the buttons' edits go through the
/// keyboard's input system. SwiftUI's `TextEditor` lost an edit made in code while the keyboard
/// held a word it was still suggesting for, as it does while dictating, and its cursor landed
/// short of the edit.
struct ScriptTextView: UIViewRepresentable {
    @Binding var text: String
    /// Where the cursor starts, in characters.
    let selection: Range<Int>
    let controller: ScriptTextController

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.backgroundColor = .clear
        view.textColor = UIColor(EarwigTheme.text)
        view.tintColor = UIColor(EarwigTheme.accent)
        view.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        view.keyboardDismissMode = .interactive
        view.accessibilityLabel = "Script"
        view.text = text
        view.delegate = context.coordinator
        controller.textView = view
        controller.onChange = { context.coordinator.changed(view) }
        ScriptTextController.select(selection, in: view)
        return view
    }

    /// Takes the text only when it changed from outside. An update a keystroke behind the text
    /// view would otherwise put back the text from before the newest character.
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.text = $text
        if text != context.coordinator.known {
            view.text = text
            context.coordinator.known = text
        }
    }

    /// All the space it is given, never its text's height, or the bar under it moves down a line
    /// at a time as the first lines are typed.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 320, height: 200))
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        /// The text as the text view last had it, or as last given to it.
        var known: String

        init(text: Binding<String>) {
            self.text = text
            known = text.wrappedValue
        }

        func textViewDidChange(_ textView: UITextView) {
            changed(textView)
        }

        /// Puts a capital at the start of a title, a step's name or a cue, for typing and
        /// dictation alike. Text the keyboard is still composing is left to it.
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText inserted: String) -> Bool {
            let text = textView.text ?? ""
            guard textView.markedTextRange == nil,
                  let capital = ScriptEditor.capitalised(inserted, at: ScriptTextController.characters(range.location, in: text), in: text),
                  let from = textView.position(from: textView.beginningOfDocument, offset: range.location),
                  let to = textView.position(from: from, offset: range.length),
                  let textRange = textView.textRange(from: from, to: to) else { return true }
            textView.replace(textRange, withText: capital)
            changed(textView)
            return false
        }

        func changed(_ view: UITextView) {
            known = view.text
            if text.wrappedValue != view.text { text.wrappedValue = view.text }
        }
    }
}

/// Makes the buttons' edits in the text view, and focuses it.
@MainActor
final class ScriptTextController {
    fileprivate weak var textView: UITextView?
    fileprivate var onChange: (() -> Void)?

    /// Makes a button's edit at the cursor, through the input system, so it can be undone, and
    /// puts the cursor where the edit leaves it.
    func perform(_ change: (ScriptEditor.Edit) -> ScriptEditor.Change) {
        guard let view = textView else { return }
        // A word the keyboard is still suggesting for, or dictation still coming in, is finished
        // first, and the keyboard is told of the change, or it puts its suggestion back over the
        // edit with positions from before it (seen in the simulator: the step's heading lost).
        view.unmarkText()
        view.inputDelegate?.selectionWillChange(view)
        view.inputDelegate?.textWillChange(view)
        defer {
            view.inputDelegate?.textDidChange(view)
            view.inputDelegate?.selectionDidChange(view)
        }
        let text = view.text ?? ""
        let selected = view.selectedRange
        let selection = Self.characters(selected.location, in: text)..<Self.characters(selected.location + selected.length, in: text)
        let made = change(ScriptEditor.Edit(text: text, selection: selection))
        let start = Self.utf16(made.range.lowerBound, in: text)
        let end = Self.utf16(made.range.upperBound, in: text)
        if let from = view.position(from: view.beginningOfDocument, offset: start),
           let to = view.position(from: view.beginningOfDocument, offset: end),
           let range = view.textRange(from: from, to: to), !(made.text.isEmpty && start == end) {
            view.replace(range, withText: made.text)
        }
        Self.select(made.cursor..<made.cursor, in: view)
        onChange?()
    }

    func focus() {
        textView?.becomeFirstResponder()
    }

    fileprivate static func select(_ range: Range<Int>, in view: UITextView) {
        let text = view.text ?? ""
        let range = ScriptEditor.clamped(range, in: text)
        let start = utf16(range.lowerBound, in: text)
        view.selectedRange = NSRange(location: start, length: utf16(range.upperBound, in: text) - start)
    }

    /// A character offset as UTF-16 units, as UIKit counts.
    private static func utf16(_ characters: Int, in text: String) -> Int {
        text.index(text.startIndex, offsetBy: min(characters, text.count)).utf16Offset(in: text)
    }

    /// UTF-16 units as a character offset.
    fileprivate static func characters(_ utf16: Int, in text: String) -> Int {
        let index = String.Index(utf16Offset: min(utf16, text.utf16.count), in: text)
        return text.distance(from: text.startIndex, to: index)
    }
}
