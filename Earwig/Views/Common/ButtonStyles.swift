import SwiftUI

/// Every button look Earwig uses, beside `EarwigTheme`'s colours (plan 015, decision 12): views
/// never build a button's fill, shape or height themselves, so a look is changed here once and
/// two screens cannot drift apart, as the Scripts and Script toolbars had.
///
/// - **Toolbar:** an icon in a mid-blue circle (`toolbarCircle`) for Back, Settings and More, a
///   word in a mid-blue capsule (`toolbarCapsule`) for everything else. Never filled with the
///   accent.
/// - **Main action:** `AccentPill`, filled with the accent: Start Take, Next Take, Play.
/// - **Choice:** `choice(_:)`, on the accent when chosen: With Voice, Record, Hold.
/// - **Second action:** `secondAction()`, white on the mid-blue: Cancel, Done and Play Back by a
///   take.
/// - **Row action:** `rowAction()`, the accent's words on a card: Listen to Step 1.
/// - **Destructive:** `destructiveAction()`, in the warning colour.
enum EarwigButton {
    /// The corner of a card, a tile and a square control.
    static let corner: CGFloat = 16
    /// A toolbar button's height, and a circle's width.
    static let toolbarSize: CGFloat = 40
    /// A main or second action across a screen's foot.
    static let actionHeight: CGFloat = 52
    /// A main action on a row.
    static let rowPillHeight: CGFloat = 34
    /// A choice in a row of chips.
    static let chipHeight: CGFloat = 40
    /// A choice as a tile with an icon over its name.
    static let tileHeight: CGFloat = 76
    /// A control in the take's row.
    static let controlHeight: CGFloat = 56
    /// The least a row action is tall, for a finger.
    static let rowActionHeight: CGFloat = 32

    /// What a choice not chosen is filled with.
    enum Ground {
        /// On a card: white, faint.
        case card
        /// On the sky blue: the cards' mid-blue.
        case sky

        var fill: Color {
            switch self {
            case .card: EarwigTheme.control
            case .sky: EarwigTheme.surface
            }
        }
    }
}

extension View {
    // MARK: Toolbar

    /// An icon in a mid-blue circle: Back, Settings, More. iOS 26 draws each toolbar item on
    /// Liquid Glass; these hide that glass and draw their own background (plan 011, decision 14).
    func toolbarCircle(_ colour: Color = EarwigTheme.accent) -> some View {
        labelStyle(.iconOnly)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(colour)
            .frame(width: EarwigButton.toolbarSize, height: EarwigButton.toolbarSize)
            .background(EarwigTheme.surface, in: Circle())
            .contentShape(Circle())
    }

    /// A word in a mid-blue capsule: New, Paste, Edit, Done, Cancel, Save, and the editor's
    /// Title, Step and Cue.
    func toolbarCapsule() -> some View {
        font(.body.weight(.semibold))
            .lineLimit(1)
            // Its own width, or the toolbar cuts the word short on the phone ("D…").
            .fixedSize()
            .foregroundStyle(EarwigTheme.accent)
            .padding(.horizontal, 16)
            .frame(height: EarwigButton.toolbarSize)
            .background(EarwigTheme.surface, in: Capsule())
            .contentShape(Capsule())
    }

    // MARK: Choices

    /// One of several choices, or a control that is on or off: on the accent when chosen.
    func choice(_ chosen: Bool, on ground: EarwigButton.Ground = .card, minHeight: CGFloat, in shape: some Shape = Capsule()) -> some View {
        foregroundStyle(chosen ? EarwigTheme.onAccent : EarwigTheme.text)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(chosen ? EarwigTheme.accent : ground.fill, in: shape)
            .contentShape(shape)
    }

    // MARK: Actions

    /// A second action beside a main one: white on the mid-blue, as wide as it is let.
    func secondAction(_ font: Font = .headline, maxWidth: CGFloat = .infinity, minHeight: CGFloat = EarwigButton.actionHeight) -> some View {
        self.font(font)
            .foregroundStyle(EarwigTheme.text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: maxWidth, minHeight: minHeight)
            .background(EarwigTheme.surface, in: Capsule())
            .contentShape(Capsule())
    }

    /// An icon in a mid-blue circle outside the toolbar: Share after a take, the route's icons.
    func surfaceCircle(_ font: Font = .title3.bold(), colour: Color = EarwigTheme.text, size: CGFloat = EarwigButton.actionHeight) -> some View {
        self.font(font)
            .foregroundStyle(colour)
            .frame(width: size, height: size)
            .background(EarwigTheme.surface, in: Circle())
    }

    /// An action on a card, in the accent's words: Listen to Step 1.
    func rowAction() -> some View {
        font(.subheadline.bold())
            .foregroundStyle(EarwigTheme.accent)
            .frame(minHeight: EarwigButton.rowActionHeight)
    }

    /// An action that loses something, in the warning colour.
    func destructiveAction() -> some View {
        font(.body.weight(.semibold))
            .foregroundStyle(EarwigTheme.warning)
    }
}

/// The main action on a row, a sheet or a screen's foot: filled with the accent.
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
            .frame(maxWidth: expands ? .infinity : nil, minHeight: expands ? EarwigButton.actionHeight : EarwigButton.rowPillHeight)
            .padding(.horizontal, 14)
            .background(EarwigTheme.accent, in: Capsule())
            .contentShape(Capsule())
    }
}

/// A word in the toolbar: New, Paste, Edit, Done, Cancel, Save.
struct ToolbarWordButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) { Text(title).toolbarCapsule() }
            .buttonStyle(.plain)
    }
}
