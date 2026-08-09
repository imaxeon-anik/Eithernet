import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var networkManager: NetworkInterfaceManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Eithernet")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Divider()

            sectionHeader("Wired")
            interfaceList(networkManager.wiredInterfaces)

            Divider()
                .padding(.top, 4)

            sectionHeader("Wireless")
            interfaceList(networkManager.wirelessInterfaces)

            if let message = networkManager.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }

            Divider()
                .padding(.top, 6)

            Button("Refresh") {
                networkManager.refresh()
            }
            .keyboardShortcut("r")
            .padding(.horizontal, 4)

            Button("Quit Eithernet") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .frame(width: 260)
        .disabled(networkManager.isBusy)
        .onAppear {
            networkManager.refresh()
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    @ViewBuilder
    private func interfaceList(_ items: [NetworkInterface]) -> some View {
        if items.isEmpty {
            Text("None found")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        } else {
            ForEach(items) { interface in
                Toggle(
                    interface.name,
                    isOn: Binding(
                        get: {
                            networkManager.interfaces.first(where: { $0.id == interface.id })?.isEnabled
                                ?? interface.isEnabled
                        },
                        set: { networkManager.setInterfaceEnabled(interface, enabled: $0) }
                    )
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
    }
}
