import SwiftUI
import UIKit

/// The toolbar's Back and Done; the buttons' looks are in `ButtonStyles.swift`.
extension View {
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
        ToolbarWordButton("Done", action: action)
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
