import CoreLocation
import CoreWLAN
import Foundation

/// Serializes CoreWLAN scans (panel refresh, connect, forget, auto-join).
private actor WLANScanGate {
    func perform<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
        try await operation()
    }
}

@MainActor
final class WiFiManager: NSObject, ObservableObject {
    @Published var networks: [WiFiNetwork] = []
    @Published var currentSSID: String?
    @Published var currentIPv4: String?
    @Published var isScanning = false
    @Published var isConnecting = false
    @Published var statusMessage: String?
    @Published var locationDenied = false
    @Published var pendingPasswordSSID: String?
    @Published var isForgetting = false
    @Published var isUpdatingAutoJoin = false
    /// `nil` when the current SSID isn’t in the saved (preferred) network list.
    @Published var currentAutoJoinEnabled: Bool?

    private let locationManager = CLLocationManager()
    private var didRequestLocation = false
    private var panelRefreshInFlight = false
    /// Latest radio state requested while a panel refresh was already running.
    private var pendingPanelWifiRadioOn: Bool?
    /// Bumped when a panel refresh runs; used to skip redundant post-toggle fallbacks.
    private var panelRefreshGeneration = 0
    private let wlanScanGate = WLANScanGate()

    /// True when macOS allows CoreWLAN to scan (Location permission granted).
    var canScanForNetworks: Bool {
        switch locationManager.authorizationStatus {
        case .authorized, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        let wifiClient = CWWiFiClient.shared()
        wifiClient.delegate = self
        try? wifiClient.startMonitoringEvent(with: .powerDidChange)
    }

    /// CoreWLAN radio state (matches Control Center / in-app toggle after power events).
    static func wiFiRadioOn() -> Bool {
        CWWiFiClient.shared().interface()?.powerOn() ?? false
    }

    /// Scan for the menu panel: respects radio state, skips until Location is granted, retries once if empty.
    func refreshNetworksForPanel(wifiRadioOn: Bool) async {
        if panelRefreshInFlight {
            pendingPanelWifiRadioOn = wifiRadioOn
            return
        }
        panelRefreshInFlight = true
        panelRefreshGeneration += 1
        defer {
            panelRefreshInFlight = false
            if let pending = pendingPanelWifiRadioOn {
                pendingPanelWifiRadioOn = nil
                Task { await refreshNetworksForPanel(wifiRadioOn: pending) }
            }
        }

        ensureLocationAccess()

        if !wifiRadioOn {
            networks = []
            currentSSID = nil
            currentIPv4 = nil
            currentAutoJoinEnabled = nil
            return
        }

        guard canScanForNetworks else { return }

        await scanAsync()
        guard networks.isEmpty, canScanForNetworks, !locationDenied else { return }

        try? await Task.sleep(for: .seconds(1.5))
        await scanAsync(clearStatusOnSuccess: false)
    }

    /// If CoreWLAN doesn’t emit a power event after `networksetup`, refresh the open panel once.
    func scheduleDeferredPanelRefreshIfVisible(_ panelVisible: Bool) {
        guard panelVisible else { return }
        let snapshot = panelRefreshGeneration
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard snapshot == panelRefreshGeneration else { return }
            await refreshNetworksForPanel(wifiRadioOn: Self.wiFiRadioOn())
        }
    }

    func connect(to network: WiFiNetwork) {
        if network.isCurrent { return }
        guard !isConnecting, !isForgetting, !isUpdatingAutoJoin else { return }

        if network.isSecure {
            pendingPasswordSSID = network.ssid
            return
        }

        Task {
            await connectAsync(ssid: network.ssid, password: nil)
        }
    }

    func connectWithPassword(_ password: String) {
        guard let ssid = pendingPasswordSSID else { return }
        guard !isConnecting, !isForgetting, !isUpdatingAutoJoin else { return }
        pendingPasswordSSID = nil
        Task {
            await connectAsync(ssid: ssid, password: password)
        }
    }

    func cancelPasswordPrompt() {
        pendingPasswordSSID = nil
    }

    func forgetNetwork(_ ssid: String, device: String? = nil) {
        guard !isConnecting, !isForgetting, !isUpdatingAutoJoin else { return }
        Task {
            await forgetNetworkAsync(ssid: ssid, device: device)
        }
    }

    func setAutoJoin(_ enabled: Bool, for ssid: String) {
        guard !isConnecting, !isForgetting, !isUpdatingAutoJoin else { return }
        Task {
            await setAutoJoinAsync(enabled: enabled, ssid: ssid)
        }
    }

    private func ensureLocationAccess() {
        locationDenied = false
        switch locationManager.authorizationStatus {
        case .authorized, .authorizedAlways:
            return
        case .denied, .restricted:
            locationDenied = true
            statusMessage = "Location access is required to list Wi‑Fi networks."
        case .notDetermined:
            if !didRequestLocation {
                didRequestLocation = true
                locationManager.requestWhenInUseAuthorization()
            }
        @unknown default:
            break
        }
    }

    private func scanAsync(clearStatusOnSuccess: Bool = true) async {
        ensureLocationAccess()
        guard canScanForNetworks, !locationDenied else { return }

        isScanning = true
        defer { isScanning = false }

        do {
            let result = try await wlanScanGate.perform {
                try await Task.detached(priority: .userInitiated) {
                    try Self.scanNetworks()
                }.value
            }
            currentSSID = result.currentSSID
            currentIPv4 = result.ipv4
            currentAutoJoinEnabled = result.currentAutoJoinEnabled
            networks = result.networks
            if locationDenied == false, clearStatusOnSuccess {
                statusMessage = nil
            }
        } catch {
            statusMessage = error.localizedDescription
            networks = []
            currentIPv4 = nil
            currentAutoJoinEnabled = nil
        }
    }

    private func setAutoJoinAsync(enabled: Bool, ssid: String) async {
        isUpdatingAutoJoin = true
        statusMessage = enabled
            ? "Enabling auto‑join for “\(ssid)”…"
            : "Disabling auto‑join for “\(ssid)”…"
        defer { isUpdatingAutoJoin = false }

        do {
            try await wlanScanGate.perform {
                try await Task.detached(priority: .userInitiated) {
                    try WiFiConfiguration.setAutoJoinEnabled(enabled, for: ssid)
                }.value
            }
            await scanAsync(clearStatusOnSuccess: false)
            let applied = currentAutoJoinEnabled ?? enabled
            statusMessage = applied
                ? "Will auto‑join “\(ssid)”"
                : "Won’t auto‑join “\(ssid)”"
        } catch {
            await scanAsync(clearStatusOnSuccess: false)
            statusMessage = error.localizedDescription
        }
    }

    private func forgetNetworkAsync(ssid: String, device: String?) async {
        isForgetting = true
        statusMessage = "Forgetting “\(ssid)”…"
        defer { isForgetting = false }

        do {
            try await wlanScanGate.perform {
                try await Task.detached(priority: .userInitiated) {
                    try Self.removePreferredNetwork(ssid: ssid, device: device)
                }.value
            }
            await scanAsync(clearStatusOnSuccess: false)
            statusMessage = "Forgot “\(ssid)”"
        } catch {
            await scanAsync(clearStatusOnSuccess: false)
            statusMessage = error.localizedDescription
        }
    }

    private func connectAsync(ssid: String, password: String?) async {
        guard !isForgetting else { return }
        isConnecting = true
        statusMessage = "Connecting to \(ssid)…"
        defer { isConnecting = false }

        do {
            try await wlanScanGate.perform {
                try await Task.detached(priority: .userInitiated) {
                    try Self.associate(ssid: ssid, password: password)
                }.value
            }
            await scanAsync(clearStatusOnSuccess: false)
            statusMessage = "Connected to \(ssid)"
        } catch {
            await scanAsync(clearStatusOnSuccess: false)
            statusMessage = error.localizedDescription
        }
    }

    nonisolated private static func wifiInterface() throws -> CWInterface {
        guard let interface = CWWiFiClient.shared().interface() else {
            throw NetworkCommandError.message("No Wi‑Fi interface available.")
        }
        return interface
    }

    nonisolated private static func scanNetworks() throws -> (
        currentSSID: String?,
        ipv4: String?,
        currentAutoJoinEnabled: Bool?,
        networks: [WiFiNetwork]
    ) {
        let interface = try wifiInterface()
        let current = interface.ssid()
        let deviceName = interface.interfaceName
        let ipv4 = deviceName.flatMap { NetworkAddress.ipv4(for: $0) }
        let scanned = try interface.scanForNetworks(withName: nil)

        var bySSID: [String: CWNetwork] = [:]
        for network in scanned {
            guard let ssid = network.ssid, !ssid.isEmpty else { continue }
            if let existing = bySSID[ssid] {
                if network.rssiValue > existing.rssiValue {
                    bySSID[ssid] = network
                }
            } else {
                bySSID[ssid] = network
            }
        }

        let networks = bySSID.values.map { network -> WiFiNetwork in
            let ssid = network.ssid ?? "Unknown"
            return WiFiNetwork(
                ssid: ssid,
                rssi: network.rssiValue,
                isSecure: network.supportsSecurity(.none) == false,
                isCurrent: ssid == current
            )
        }
        .sorted { lhs, rhs in
            if lhs.isCurrent != rhs.isCurrent { return lhs.isCurrent }
            if lhs.rssi != rhs.rssi { return lhs.rssi > rhs.rssi }
            return lhs.ssid.localizedCaseInsensitiveCompare(rhs.ssid) == .orderedAscending
        }

        let autoJoin = current.flatMap { try? WiFiConfiguration.autoJoinEnabled(for: $0) }

        return (current, ipv4, autoJoin, networks)
    }

    nonisolated private static func removePreferredNetwork(ssid: String, device: String?) throws {
        let interface = try wifiInterface()
        let deviceName = device ?? interface.interfaceName
        guard let deviceName, !deviceName.isEmpty else {
            throw NetworkCommandError.message("No Wi‑Fi device name.")
        }

        if interface.ssid() == ssid {
            interface.disassociate()
        }

        _ = try runNetworkSetupSync([
            "-removepreferredwirelessnetwork",
            deviceName,
            ssid,
        ])
    }

    nonisolated private static func associate(ssid: String, password: String?) throws {
        let interface = try wifiInterface()
        let scanned = try interface.scanForNetworks(withName: ssid)
        guard let target = scanned.first(where: { $0.ssid == ssid }) ?? scanned.first else {
            throw NetworkCommandError.message("Network “\(ssid)” not found.")
        }

        do {
            try interface.associate(to: target, password: password)
        } catch {
            throw NetworkCommandError.message(
                "Couldn’t connect to “\(ssid)”. Check the password or try again."
            )
        }
    }
}

extension WiFiManager: CWEventDelegate {
    nonisolated func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .eithernetRequestInterfaceRefresh, object: nil)
            let wifiOn = CWWiFiClient.shared().interface()?.powerOn() ?? false
            await refreshNetworksForPanel(wifiRadioOn: wifiOn)
        }
    }
}

extension WiFiManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            handleAuthorizationStatus(status)
        }
    }

    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorized, .authorizedAlways:
            locationDenied = false
            Task {
                await refreshNetworksForPanel(wifiRadioOn: Self.wiFiRadioOn())
            }
        case .denied, .restricted:
            locationDenied = true
            statusMessage = "Location access is required to list Wi‑Fi networks."
        default:
            break
        }
    }
}
