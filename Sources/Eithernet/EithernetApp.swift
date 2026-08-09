import SwiftUI

@main
struct EithernetApp: App {
    @StateObject private var networkManager = NetworkInterfaceManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(networkManager: networkManager)
        } label: {
            Label("Eithernet", systemImage: networkManager.statusSymbolName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(networkManager: networkManager)
        }
    }
}
