import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var networkManager: NetworkInterfaceManager
    @ObservedObject var wifiManager: WiFiManager
    @State private var password = ""

    private let panelWidth: CGFloat = 320
    private let panelHeight: CGFloat = 460
    private let networkListHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Wired")
                    interfaceList(networkManager.wiredInterfaces)
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        sectionLabel("Wireless")
                        Spacer()
                        if let wifi = networkManager.wirelessInterfaces.first {
                            Toggle(
                                "Wi‑Fi",
                                isOn: Binding(
                                    get: {
                                        networkManager.interfaces
                                            .first(where: { $0.id == wifi.id })?
                                            .isEnabled ?? wifi.isEnabled
                                    },
                                    set: { networkManager.setInterfaceEnabled(wifi, enabled: $0) }
                                )
                            )
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .controlSize(.mini)
                            .help("Turn Wi‑Fi radio on/off")
                        }
                    }

                    if wifiManager.locationDenied {
                        Text("Allow Location access to list nearby networks.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open System Settings") {
                            if let url = URL(
                                string:
                                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Location"
                            ) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else if let ssid = wifiManager.pendingPasswordSSID {
                        passwordPanel(for: ssid)
                    } else {
                        networksList
                    }
                }
            }

            if let message = networkManager.statusMessage ?? wifiManager.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Button {
                    networkManager.refresh()
                    wifiManager.scan()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: panelWidth, height: panelHeight, alignment: .top)
        .background(GlassBackdrop())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.20), lineWidth: 0.8)
        )
        // Keep toggles usable while a join is in flight; only block network rows.
        .onAppear {
            // MenuBarExtra windows dismiss easily if the app isn’t active.
            NSApp.activate(ignoringOtherApps: true)
            networkManager.refresh()
            wifiManager.prepareAndScan()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: networkManager.statusIcon.nsImage)
                .renderingMode(.template)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 1) {
                Text("Eithernet")
                    .font(.system(.headline, design: .rounded))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if wifiManager.isScanning || wifiManager.isConnecting || networkManager.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var subtitle: String {
        if let ssid = wifiManager.pendingPasswordSSID {
            return "Password for \(ssid)"
        }
        if let ssid = wifiManager.currentSSID, !ssid.isEmpty {
            return "Connected to \(ssid)"
        }
        if networkManager.wiredInterfaces.contains(where: \.isEnabled) {
            return "Wired active"
        }
        return "Choose a network"
    }

    @ViewBuilder
    private var networksList: some View {
        let wifiOn = networkManager.wirelessInterfaces.contains(where: \.isEnabled)
        if !wifiOn {
            Text("Turn Wi‑Fi on to see networks.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, minHeight: networkListHeight, alignment: .topLeading)
        } else if wifiManager.networks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if wifiManager.isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Scanning for networks…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No networks found")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: networkListHeight, alignment: .topLeading)
        } else {
            // Fixed height is required — ScrollView collapses inside VStack/MenuBarExtra otherwise.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(wifiManager.networks.prefix(16)) { network in
                        Button {
                            wifiManager.connect(to: network)
                        } label: {
                            networkRow(network)
                        }
                        .buttonStyle(.plain)
                        .disabled(network.isCurrent || wifiManager.isConnecting)
                    }
                }
                .padding(.trailing, 2)
            }
            .scrollIndicators(.visible)
            .frame(height: networkListHeight)
            .frame(maxWidth: .infinity)
        }
    }

    private func passwordPanel(for ssid: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Join “\(ssid)”")
                .font(.subheadline.weight(.semibold))
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submitPassword)
            HStack {
                Button("Cancel") {
                    wifiManager.cancelPasswordPrompt()
                    password = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Join") {
                    submitPassword()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(password.isEmpty || wifiManager.isConnecting)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, minHeight: networkListHeight, alignment: .topLeading)
    }

    private func networkRow(_ network: WiFiNetwork) -> some View {
        HStack(spacing: 8) {
            Image(systemName: network.isCurrent ? "checkmark.circle.fill" : "wifi")
                .foregroundStyle(network.isCurrent ? Color.accentColor : .secondary)
                .frame(width: 16)

            Text(network.ssid)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer(minLength: 4)

            if network.isSecure {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            signalIcon(bars: network.signalBars)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(network.isCurrent ? Color.accentColor.opacity(0.14) : .clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func signalIcon(bars: Int) -> some View {
        Image(systemName: {
            switch bars {
            case 3: return "wifi"
            case 2: return "wifi"
            case 1: return "wifi.exclamationmark"
            default: return "wifi.slash"
            }
        }())
        .font(.caption)
        .opacity(bars == 0 ? 0.45 : bars == 1 ? 0.65 : 1)
    }

    @ViewBuilder
    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.4)
    }

    @ViewBuilder
    private func interfaceList(_ items: [NetworkInterface]) -> some View {
        if items.isEmpty {
            Text("None found")
                .font(.callout)
                .foregroundStyle(.tertiary)
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
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
    }

    private func submitPassword() {
        let value = password
        password = ""
        wifiManager.connectWithPassword(value)
    }
}
