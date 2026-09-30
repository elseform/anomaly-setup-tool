import SwiftUI
import AppKit

/// SwiftUI has no close-veto callback. Keep the window open if saving fails.
struct WindowCloseGuard: NSViewRepresentable {
    let delegate: AppDelegate

    func makeNSView(context: Context) -> GuardView { GuardView(delegate: delegate) }
    func updateNSView(_ nsView: GuardView, context: Context) {}

    final class GuardView: NSView {
        weak var closeDelegate: AppDelegate?

        init(delegate: AppDelegate) {
            closeDelegate = delegate
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.delegate = closeDelegate
        }
    }
}
