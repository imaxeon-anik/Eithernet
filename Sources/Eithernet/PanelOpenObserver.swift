import AppKit
import SwiftUI

/// Calls `onOpen` each time the hosting window becomes key, i.e. every time the menu-bar panel is
/// opened. `MenuBarExtra` keeps its window alive between opens, so SwiftUI's `onAppear` is not a
/// reliable "panel opened" signal.
struct PanelOpenObserver: NSViewRepresentable {
    var onOpen: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> ObservingView {
        let view = ObservingView()
        view.coordinator = context.coordinator
        context.coordinator.onOpen = onOpen
        return view
    }

    func updateNSView(_ nsView: ObservingView, context: Context) {
        context.coordinator.onOpen = onOpen
    }

    @MainActor
    final class Coordinator {
        var onOpen: (@MainActor () -> Void)?
        private var observer: NSObjectProtocol?
        private weak var window: NSWindow?

        func attach(to newWindow: NSWindow?) {
            guard newWindow !== window else { return }
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            window = newWindow
            guard let newWindow else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: newWindow,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.onOpen?() }
            }
        }
    }

    final class ObservingView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.attach(to: window)
        }
    }
}
