import AppKit
import SwiftUI

/// Presents `SettingsView` in a normal window. SwiftUI `Settings { }` + `showSettingsWindow:`
/// often fail for `LSUIElement` menu-bar-only apps.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show(
        networkManager: NetworkInterfaceManager,
        launchState: SettingsLaunchState
    ) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(
            rootView: SettingsView(networkManager: networkManager, launchState: launchState)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 340),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Eithernet Settings"
        window.identifier = NSUserInterfaceItemIdentifier("eithernet.settings")
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
