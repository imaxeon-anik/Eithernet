import Foundation
import SwiftUI

@MainActor
final class MenuBarPanelState: ObservableObject {
    @Published var password = ""
    /// Connected network detail (auto-join, forget) opened from the ⓘ control on the current row.
    @Published var networkDetailSSID: String?
    /// Toggle display for the detail pane; re-synced from the system after failed auto-join changes.
    @Published var detailAutoJoinEnabled = false
    /// Menu bar panel window is on screen (MenuBarExtra `.window`).
    @Published var isMenuPanelVisible = false
    /// Inline forget confirmation (AppKit sheets mis-anchor on MenuBarExtra windows).
    @Published var ssidPendingForget: String?
    /// When the panel last triggered an open-time refresh (de-dupes onAppear + window-key events).
    var lastOpenRefresh: Date?

    func syncDetailAutoJoin(from wifi: WiFiManager) {
        detailAutoJoinEnabled = wifi.currentAutoJoinEnabled ?? false
    }

    func openNetworkDetail(ssid: String, wifi: WiFiManager) {
        networkDetailSSID = ssid
        syncDetailAutoJoin(from: wifi)
    }
}
