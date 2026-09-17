import Foundation

@MainActor
final class SettingsLaunchState: ObservableObject {
    @Published var launchAtLogin = LaunchAtLogin.isEnabled
    @Published var launchAtLoginMessage: String?

    func syncFromSystem() {
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}
