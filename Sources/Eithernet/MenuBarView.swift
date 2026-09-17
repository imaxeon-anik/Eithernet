import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var networkManager: NetworkInterfaceManager
    @ObservedObject var wifiManager: WiFiManager
    @ObservedObject var panelState: MenuBarPanelState

    private let panelWidth: CGFloat = 320
    private let panelHeight: CGFloat = 548
    private let networkListHeight: CGFloat = 200

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
                                    set: { enabled in
                                        networkManager.setInterfaceEnabled(wifi, enabled: enabled)
                                        wifiManager.scheduleDeferredPanelRefreshIfVisible(
                                            panelState.isMenuPanelVisible
                                        )
                                    }
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
                    } else if let ssid = panelState.networkDetailSSID {
                        networkDetailPanel(for: ssid)
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

            Button(action: openWiFiSettings) {
                settingsRow(title: "Wi‑Fi Settings…", systemImage: "wifi")
            }
            .buttonStyle(.plain)

            SettingsLink {
                settingsRow(title: "Eithernet Settings…", systemImage: "gearshape")
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button {
                    Task { await refreshInterfacesAndPanelNetworks() }
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
        .confirmationDialog(
            "Forget this network?",
            isPresented: Binding(
                get: { panelState.ssidPendingForget != nil },
                set: { if !$0 { panelState.ssidPendingForget = nil } }
            ),
            titleVisibility: .visible,
            presenting: panelState.ssidPendingForget
        ) { ssid in
            Button("Forget “\(ssid)”", role: .destructive) {
                let device = networkManager.wirelessInterfaces.first?.device
                wifiManager.forgetNetwork(ssid, device: device)
                panelState.ssidPendingForget = nil
                panelState.networkDetailSSID = nil
            }
            Button("Cancel", role: .cancel) {
                panelState.ssidPendingForget = nil
            }
        } message: { ssid in
            Text(
                "Removes “\(ssid)” from saved networks and deletes the stored password. You’ll need to enter the password again to rejoin."
            )
        }
        .onChange(of: wifiManager.currentSSID) { _, newSSID in
            guard let detail = panelState.networkDetailSSID else { return }
            if detail != newSSID {
                panelState.networkDetailSSID = nil
            }
        }
        .onChange(of: wifiManager.isUpdatingAutoJoin) { _, updating in
            if !updating {
                panelState.syncDetailAutoJoin(from: wifiManager)
            }
        }
        .onChange(of: wifiManager.currentAutoJoinEnabled) { _, _ in
            if panelState.networkDetailSSID != nil {
                panelState.syncDetailAutoJoin(from: wifiManager)
            }
        }
        .onAppear {
            // MenuBarExtra windows dismiss easily if the app isn’t active.
            NSApp.activate(ignoringOtherApps: true)
            panelState.isMenuPanelVisible = true
            Task { await refreshInterfacesAndPanelNetworks() }
        }
        .onDisappear {
            panelState.isMenuPanelVisible = false
        }
    }

    private func refreshInterfacesAndPanelNetworks() async {
        await networkManager.refresh()
        await wifiManager.refreshNetworksForPanel(wifiRadioOn: WiFiManager.wiFiRadioOn())
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: networkManager.menuBarIcon.nsImage)
                .renderingMode(.template)
                .foregroundStyle(.primary)
                .frame(
                    width: networkManager.menuBarIcon.traySize.width,
                    height: networkManager.menuBarIcon.traySize.height
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("Eithernet")
                    .font(.system(.headline, design: .rounded))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if wifiManager.isScanning || wifiManager.isConnecting || wifiManager.isForgetting
                || wifiManager.isUpdatingAutoJoin || networkManager.isBusy
            {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var subtitle: String {
        if let ssid = wifiManager.pendingPasswordSSID {
            return "Password for \(ssid)"
        }
        if let ssid = panelState.networkDetailSSID {
            return "Details for \(ssid)"
        }
        if let ssid = wifiManager.currentSSID, !ssid.isEmpty {
            if let ip = wifiManager.currentIPv4 {
                return "Connected to \(ssid) · \(ip)"
            }
            return "Connected to \(ssid)"
        }
        if networkManager.wiredInterfaces.contains(where: \.isEnabled) {
            if let ip = networkManager.primaryWiredIPv4 {
                return "Wired · \(ip)"
            }
            return "Wired active"
        }
        return "Choose a network"
    }

    @ViewBuilder
    private var networksList: some View {
        if !WiFiManager.wiFiRadioOn() {
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
                } else if !wifiManager.canScanForNetworks {
                    Text("Waiting for Location permission to scan…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        networkListRow(network)
                    }
                }
                .padding(.trailing, 2)
            }
            .scrollIndicators(.visible)
            .frame(height: networkListHeight)
            .frame(maxWidth: .infinity)
        }
    }

    private var networkRowInteractionDisabled: Bool {
        wifiManager.isConnecting || wifiManager.isForgetting || wifiManager.isUpdatingAutoJoin
    }

    @ViewBuilder
    private func networkListRow(_ network: WiFiNetwork) -> some View {
        HStack(spacing: 4) {
            Button {
                wifiManager.connect(to: network)
            } label: {
                networkRow(network)
            }
            .buttonStyle(.plain)
            .disabled(network.isCurrent || networkRowInteractionDisabled)

            if network.isCurrent {
                Button {
                    panelState.openNetworkDetail(ssid: network.ssid, wifi: wifiManager)
                } label: {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Network details")
                .disabled(networkRowInteractionDisabled)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(network.isCurrent ? Color.accentColor.opacity(0.14) : .clear)
        )
    }

    private func networkDetailPanel(for ssid: String) -> some View {
        let isSaved = wifiManager.currentAutoJoinEnabled != nil

        return VStack(alignment: .leading, spacing: 12) {
            Text("“\(ssid)”")
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            if isSaved {
                Toggle(isOn: detailAutoJoinBinding(for: ssid)) {
                    Text("Automatically join this network")
                        .font(.callout)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(networkRowInteractionDisabled)
            } else {
                Text("This network isn’t saved on your Mac. Joining with a password will add it to saved networks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isSaved {
                Button(role: .destructive) {
                    panelState.ssidPendingForget = ssid
                } label: {
                    Label("Forget This Network", systemImage: "trash")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(networkRowInteractionDisabled)
            }

            HStack {
                Button("Back") {
                    panelState.networkDetailSSID = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, minHeight: networkListHeight, alignment: .topLeading)
        .onAppear {
            panelState.syncDetailAutoJoin(from: wifiManager)
        }
    }

    private func detailAutoJoinBinding(for ssid: String) -> Binding<Bool> {
        Binding(
            get: { panelState.detailAutoJoinEnabled },
            set: { newValue in
                guard newValue != panelState.detailAutoJoinEnabled else { return }
                panelState.detailAutoJoinEnabled = newValue
                wifiManager.setAutoJoin(newValue, for: ssid)
            }
        )
    }

    private func passwordPanel(for ssid: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Join “\(ssid)”")
                .font(.subheadline.weight(.semibold))
            SecureField("Password", text: $panelState.password)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submitPassword)
            HStack {
                Button("Cancel") {
                    wifiManager.cancelPasswordPrompt()
                    panelState.password = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Join") {
                    submitPassword()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(panelState.password.isEmpty || wifiManager.isConnecting)
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
        let value = panelState.password
        panelState.password = ""
        wifiManager.connectWithPassword(value)
    }

    private func openWiFiSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Network-Settings.extension?Wi-Fi",
            "x-apple.systempreferences:com.apple.wifi-settings-extension",
            "x-apple.systempreferences:com.apple.preference.network?Wi-Fi",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func settingsRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 4)
            Image(systemName: "arrow.up.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }
}
