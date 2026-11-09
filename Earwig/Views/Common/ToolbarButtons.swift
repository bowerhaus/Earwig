import SwiftUI
import UIKit

/// Toolbar buttons on the cards' mid-blue (plan 011, decision 14). iOS 26 draws each toolbar item
/// on Liquid Glass, which the app's dark scheme turns near-black on the phone; these hide that
/// glass and draw their own background, as the Paste pill does.
extension View {
    /// An icon in a mid-blue circle.
    func toolbarCircle(_ colour: Color = EarwigTheme.accent) -> some View {
        labelStyle(.iconOnly)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(colour)
            .frame(width: 40, height: 40)
            .background(EarwigTheme.surface, in: Circle())
            .contentShape(Circle())
    }

    /// A word ("Done") in a mid-blue capsule.
    func toolbarCapsule() -> some View {
        font(.body.weight(.semibold))
            .lineLimit(1)
            // Its own width, or the toolbar cuts the word short on the phone ("D…").
            .fixedSize()
            .foregroundStyle(EarwigTheme.accent)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(EarwigTheme.surface, in: Capsule())
            .contentShape(Capsule())
    }

    /// Our own back button in place of iOS's, which cannot be restyled. The edge swipe still goes
    /// back (`UINavigationController` below).
    func earwigBackButton() -> some View {
        navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { BackButton() }
                    .sharedBackgroundVisibility(.hidden)
            }
    }
}

/// The Done button of a sheet.
struct DoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) { Text("Done").toolbarCapsule() }
            .buttonStyle(.plain)
    }
}

private struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Label("Back", systemImage: "chevron.left").toolbarCircle(EarwigTheme.text)
        }
        .buttonStyle(.plain)
    }
}

/// Hiding iOS's back button also turns off the swipe from the left edge; this turns it back on
/// whenever there is a screen to go back to.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === interactivePopGestureRecognizer && viewControllers.count > 1
    }
}
