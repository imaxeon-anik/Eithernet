import SwiftUI

@main
struct EithernetApp: App {
    @StateObject private var networkManager = NetworkInterfaceManager()
    @StateObject private var wifiManager = WiFiManager()
    @StateObject private var panelState = MenuBarPanelState()
    @StateObject private var settingsLaunchState = SettingsLaunchState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                networkManager: networkManager,
                wifiManager: wifiManager,
                panelState: panelState,
                launchState: settingsLaunchState
            )
        } label: {
            MenuBarLabelView(networkManager: networkManager)
        }
        .menuBarExtraStyle(.window)
    }
}
