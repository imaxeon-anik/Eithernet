import SwiftUI

@main
struct EithernetApp: App {
    @StateObject private var networkManager = NetworkInterfaceManager()
    @StateObject private var wifiManager = WiFiManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(networkManager: networkManager, wifiManager: wifiManager)
        } label: {
            Image(nsImage: networkManager.statusIcon.nsImage)
                .renderingMode(.template)
                .frame(width: 20, height: 20)
                .accessibilityLabel("Eithernet")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(networkManager: networkManager)
        }
    }
}
