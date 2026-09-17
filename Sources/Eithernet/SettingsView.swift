import SwiftUI

struct SettingsView: View {
    @ObservedObject var networkManager: NetworkInterfaceManager
    @ObservedObject var launchState: SettingsLaunchState

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
                if LaunchAtLogin.needsApproval {
                    Text("Pending approval in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Login Items…") {
                        LaunchAtLogin.openLoginItemsSettings()
                    }
                }
                if let launchAtLoginMessage = launchState.launchAtLoginMessage {
                    Text(launchAtLoginMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Wired") {
                if networkManager.wiredInterfaces.isEmpty {
                    Text("None found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(networkManager.wiredInterfaces) { interface in
                        LabeledContent(interface.name, value: statusText(for: interface))
                    }
                }
            }

            Section("Wireless") {
                if networkManager.wirelessInterfaces.isEmpty {
                    Text("None found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(networkManager.wirelessInterfaces) { interface in
                        LabeledContent(interface.name, value: statusText(for: interface))
                    }
                }
            }

            Section("About") {
                LabeledContent("App", value: "Eithernet")
                Text("Toggle interfaces and join Wi‑Fi networks from the menu bar. Location access is required to list nearby networks.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 340)
        .onAppear {
            launchState.syncFromSystem()
            networkManager.refresh()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchState.launchAtLogin },
            set: { newValue in
                do {
                    try LaunchAtLogin.setEnabled(newValue)
                    launchState.launchAtLogin = LaunchAtLogin.isEnabled
                    launchState.launchAtLoginMessage = LaunchAtLogin.needsApproval
                        ? "Turned on — approve Eithernet under Login Items if prompted."
                        : nil
                } catch {
                    launchState.launchAtLogin = LaunchAtLogin.isEnabled
                    launchState.launchAtLoginMessage = error.localizedDescription
                }
            }
        )
    }

    private func statusText(for interface: NetworkInterface) -> String {
        let power = interface.isEnabled ? "On" : "Off"
        return "\(power) · \(interface.device)"
    }
}
