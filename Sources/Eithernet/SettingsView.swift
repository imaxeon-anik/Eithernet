import SwiftUI

struct SettingsView: View {
    @ObservedObject var networkManager: NetworkInterfaceManager

    var body: some View {
        Form {
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
        .frame(width: 380, height: 280)
        .onAppear {
            networkManager.refresh()
        }
    }

    private func statusText(for interface: NetworkInterface) -> String {
        let power = interface.isEnabled ? "On" : "Off"
        return "\(power) · \(interface.device)"
    }
}
