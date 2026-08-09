import CoreLocation
import CoreWLAN
import Foundation

@MainActor
final class WiFiManager: NSObject, ObservableObject {
    @Published var networks: [WiFiNetwork] = []
    @Published var currentSSID: String?
    @Published var isScanning = false
    @Published var isConnecting = false
    @Published var statusMessage: String?
    @Published var locationDenied = false
    @Published var pendingPasswordSSID: String?

    private let locationManager = CLLocationManager()
    private var didRequestLocation = false

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func prepareAndScan() {
        ensureLocationAccess()
        scan()
    }

    func scan() {
        Task {
            await scanAsync()
        }
    }

    func connect(to network: WiFiNetwork) {
        if network.isCurrent { return }

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
        pendingPasswordSSID = nil
        Task {
            await connectAsync(ssid: ssid, password: password)
        }
    }

    func cancelPasswordPrompt() {
        pendingPasswordSSID = nil
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

    private func scanAsync() async {
        isScanning = true
        defer { isScanning = false }

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try Self.scanNetworks()
            }.value
            currentSSID = result.currentSSID
            networks = result.networks
            if locationDenied == false {
                statusMessage = nil
            }
        } catch {
            statusMessage = error.localizedDescription
            networks = []
        }
    }

    private func connectAsync(ssid: String, password: String?) async {
        isConnecting = true
        statusMessage = "Connecting to \(ssid)…"
        defer { isConnecting = false }

        do {
            try await Task.detached(priority: .userInitiated) {
                try Self.associate(ssid: ssid, password: password)
            }.value
            statusMessage = "Connected to \(ssid)"
            await scanAsync()
        } catch {
            statusMessage = error.localizedDescription
            await scanAsync()
        }
    }

    nonisolated private static func wifiInterface() throws -> CWInterface {
        guard let interface = CWWiFiClient.shared().interface() else {
            throw NetworkCommandError.message("No Wi‑Fi interface available.")
        }
        return interface
    }

    nonisolated private static func scanNetworks() throws -> (currentSSID: String?, networks: [WiFiNetwork]) {
        let interface = try wifiInterface()
        let current = interface.ssid()
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

        return (current, networks)
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
            scan()
        case .denied, .restricted:
            locationDenied = true
            statusMessage = "Location access is required to list Wi‑Fi networks."
        default:
            break
        }
    }
}
