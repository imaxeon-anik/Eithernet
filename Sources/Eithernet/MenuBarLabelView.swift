import AppKit
import SwiftUI

/// Tray icon label — kept separate so SwiftUI reliably redraws when `menuBarIcon` changes.
struct MenuBarLabelView: View {
    @ObservedObject var networkManager: NetworkInterfaceManager

    var body: some View {
        Image(nsImage: networkManager.menuBarIcon.nsImage)
            .renderingMode(.template)
            .frame(
                width: networkManager.menuBarIcon.traySize.width,
                height: networkManager.menuBarIcon.traySize.height
            )
            .accessibilityLabel("Eithernet")
            .id(networkManager.menuBarIcon)
            .onReceive(
                NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            ) { _ in
                networkManager.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)) { _ in
                networkManager.refresh()
            }
    }
}
