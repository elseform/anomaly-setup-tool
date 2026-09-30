import SwiftUI
import AppKit

/// SwiftUI has no close-veto callback. Put a delegate in front of the one
/// SwiftUI installed: it asks `shouldClose`, and hands every other delegate
/// message to SwiftUI's own delegate so the scene keeps working.
struct WindowCloseGuard: NSViewRepresentable {
    let shouldClose: @MainActor (NSWindow) -> Bool

    func makeNSView(context: Context) -> GuardView { GuardView(shouldClose: shouldClose) }
    func updateNSView(_ nsView: GuardView, context: Context) {}

    final class GuardView: NSView {
        private let proxy: CloseProxy

        init(shouldClose: @escaping @MainActor (NSWindow) -> Bool) {
            proxy = CloseProxy(shouldClose: shouldClose)
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, window.delegate !== proxy else { return }
            proxy.original = window.delegate
            window.delegate = proxy
        }
    }

    @MainActor
    final class CloseProxy: NSObject, NSWindowDelegate {
        weak var original: NSWindowDelegate?
        private let shouldClose: @MainActor (NSWindow) -> Bool

        init(shouldClose: @escaping @MainActor (NSWindow) -> Bool) {
            self.shouldClose = shouldClose
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            (original?.windowShouldClose?(sender) ?? true) && shouldClose(sender)
        }

        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || original?.responds(to: selector) == true
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            original?.responds(to: selector) == true ? original : super.forwardingTarget(for: selector)
        }
    }
}
