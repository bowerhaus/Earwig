import SwiftUI
import UIKit

/// The editor's text view (plan 015, decision 2): UIKit's, so the buttons' edits go through the
/// keyboard's input system. SwiftUI's `TextEditor` lost an edit made in code while the keyboard
/// held a word it was still suggesting for, as it does while dictating, and its cursor landed
/// short of the edit.
struct ScriptTextView: UIViewRepresentable {
    /// A button on the bar above the keyboard: Title, Step or Cue.
    struct Tool {
        let title: String
        let systemImage: String
        let hint: String
        let change: (ScriptEditor.Edit) -> ScriptEditor.Change
    }

    @Binding var text: String
    /// Where the cursor starts, in characters.
    let selection: Range<Int>
    let controller: ScriptTextController
    let tools: [Tool]

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
        view.inputAccessoryView = Self.toolBar(tools, controller: controller)
        view.delegate = context.coordinator
        controller.textView = view
        controller.onChange = { context.coordinator.changed(view) }
        ScriptTextController.select(selection, in: view)
        return view
    }

    /// The tools in one glass capsule floating just above the keyboard, as iOS 26 shows its
    /// own editing tools (plan 015, decision 2, amended: Andy found pills under the text dated).
    /// It is the text view's own, so it shows in the sheet, where SwiftUI's keyboard toolbar
    /// didn't, and it goes with the keyboard.
    private static func toolBar(_ tools: [Tool], controller: ScriptTextController) -> UIView {
        let bar = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 58))
        bar.autoresizingMask = .flexibleWidth
        bar.backgroundColor = .clear
        let glass = UIVisualEffectView(effect: UIGlassEffect())
        glass.cornerConfiguration = .capsule()
        glass.translatesAutoresizingMaskIntoConstraints = false
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        var buttons: [UIButton] = []
        for (index, tool) in tools.enumerated() {
            if index > 0 { row.addArrangedSubview(divider()) }
            var look = UIButton.Configuration.plain()
            look.title = tool.title
            look.image = UIImage(systemName: tool.systemImage)
            look.imagePadding = 6
            look.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .body)
            look.baseForegroundColor = UIColor(EarwigTheme.surface)
            look.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = .preferredFont(forTextStyle: .body).withWeight(.semibold)
                return attributes
            }
            let button = UIButton(configuration: look, primaryAction: UIAction { _ in controller.perform(tool.change) })
            button.accessibilityHint = tool.hint
            row.addArrangedSubview(button)
            buttons.append(button)
        }
        for button in buttons.dropFirst() { button.widthAnchor.constraint(equalTo: buttons[0].widthAnchor).isActive = true }
        glass.contentView.addSubview(row)
        bar.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            glass.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            glass.topAnchor.constraint(equalTo: bar.topAnchor, constant: 4),
            glass.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor, constant: -8),
            row.topAnchor.constraint(equalTo: glass.contentView.topAnchor),
            row.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor),
        ])
        return bar
    }

    /// A hairline between two tools.
    private static func divider() -> UIView {
        let line = UIView()
        line.backgroundColor = .separator
        // A point wide: the system's separator colour is faint enough for a hairline.
        line.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.widthAnchor.constraint(equalToConstant: 1),
            line.heightAnchor.constraint(equalToConstant: 22),
        ])
        return line
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

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: pointSize, weight: weight)
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
