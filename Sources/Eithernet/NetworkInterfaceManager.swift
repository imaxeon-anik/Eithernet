import Foundation
import SwiftUI

extension Notification.Name {
    /// Posted when CoreWLAN reports Wi‑Fi power/state changes (Control Center, etc.).
    static let eithernetRequestInterfaceRefresh = Notification.Name("EithernetRequestInterfaceRefresh")
}

@MainActor
final class NetworkInterfaceManager: ObservableObject {
    @Published var interfaces: [NetworkInterface] = []
    @Published var primaryWiredIPv4: String?
    @Published private(set) var menuBarIcon: MenuBarIcon = .off
    @Published var isBusy = false
    @Published var statusMessage: String?

    private var backgroundMonitorTask: Task<Void, Never>?
    private var externalRefreshObserver: NSObjectProtocol?
    private var isRefreshing = false

    init() {
        externalRefreshObserver = NotificationCenter.default.addObserver(
            forName: .eithernetRequestInterfaceRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        startBackgroundMonitoring()
        refresh()
    }

    deinit {
        backgroundMonitorTask?.cancel()
    }

    var wiredInterfaces: [NetworkInterface] {
        interfaces.filter { $0.kind == .wired }
    }

    var wirelessInterfaces: [NetworkInterface] {
        interfaces.filter { $0.kind == .wireless }
    }

    var statusIcon: MenuBarIcon {
        let wiredOn = wiredInterfaces.contains(where: \.isEnabled)
        let wirelessOn = wirelessInterfaces.contains(where: \.isEnabled)
        switch (wirelessOn, wiredOn) {
        case (true, true):
            return .both
        case (false, true):
            return .wired
        case (true, false):
            return .wireless
        case (false, false):
            return .off
        }
    }

    func refresh() {
        Task {
            await refreshAsync()
        }
    }

    func refresh() async {
        await refreshAsync()
    }

    func setInterfaceEnabled(_ interface: NetworkInterface, enabled: Bool) {
        Task {
            isBusy = true
            let label = interface.name
            statusMessage = enabled ? "Enabling \(label)…" : "Disabling \(label)…"
            do {
                switch interface.kind {
                case .wireless:
                    try await runNetworkSetup([
                        "-setairportpower",
                        interface.device,
                        enabled ? "on" : "off",
                    ])
                case .wired:
                    try await runNetworkSetup([
                        "-setnetworkserviceenabled",
                        interface.serviceName,
                        enabled ? "on" : "off",
                    ])
                }
                await refreshAsync()
                statusMessage = nil
            } catch {
                statusMessage = error.localizedDescription
                await refreshAsync()
            }
            isBusy = false
        }
    }

    private func startBackgroundMonitoring() {
        backgroundMonitorTask?.cancel()
        backgroundMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { break }
                await self?.refreshAsync()
            }
        }
    }

    private func refreshAsync() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let hardware = try await runNetworkSetup(["-listallhardwareports"])
            let servicesOutput = try await runNetworkSetup(["-listallnetworkservices"])
            let serviceNames = parseServiceNames(servicesOutput)
            let ports = parseHardwarePorts(hardware)

            var discovered: [NetworkInterface] = []

            for port in ports {
                guard let kind = classify(portName: port.name) else { continue }
                guard let serviceName = resolveServiceName(portName: port.name, services: serviceNames) else {
                    continue
                }

                let isEnabled: Bool
                switch kind {
                case .wireless:
                    let power = try await runNetworkSetup(["-getairportpower", port.device])
                    isEnabled = power.lowercased().contains("on")
                case .wired:
                    let info = try await runNetworkSetup(["-getnetworkserviceenabled", serviceName])
                    isEnabled = info.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "enabled"
                }

                discovered.append(
                    NetworkInterface(
                        name: port.name,
                        device: port.device,
                        serviceName: serviceName,
                        kind: kind,
                        isEnabled: isEnabled
                    )
                )
            }

            interfaces = discovered.sorted { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind == .wired
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            primaryWiredIPv4 = interfaces
                .first(where: { $0.kind == .wired && $0.isEnabled })
                .flatMap { NetworkAddress.ipv4(for: $0.device) }
            menuBarIcon = statusIcon
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private struct HardwarePort {
        let name: String
        let device: String
    }

    private func parseHardwarePorts(_ output: String) -> [HardwarePort] {
        var ports: [HardwarePort] = []
        var currentPort: String?

        for line in output.split(whereSeparator: \.isNewline).map(String.init) {
            if line.hasPrefix("Hardware Port: ") {
                currentPort = String(line.dropFirst("Hardware Port: ".count))
            } else if line.hasPrefix("Device: "), let port = currentPort {
                let device = String(line.dropFirst("Device: ".count))
                ports.append(HardwarePort(name: port, device: device))
                currentPort = nil
            }
        }

        return ports
    }

    private func parseServiceNames(_ output: String) -> [String] {
        output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .compactMap { line in
                let name = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !name.hasPrefix("An asterisk") else { return nil }
                if name.hasPrefix("*") {
                    return String(name.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                return name
            }
    }

    private func classify(portName: String) -> NetworkInterfaceKind? {
        let lowered = portName.lowercased()

        if lowered.contains("wi-fi") || lowered.contains("wifi") || lowered.contains("airport") {
            return .wireless
        }

        // Skip virtual / non-connectivity ports that often appear in hardware lists.
        let skipTokens = ["bluetooth", "thunderbolt bridge", "iphone usb", "ipad usb", "loopback", "bridge"]
        if skipTokens.contains(where: { lowered.contains($0) }) {
            return nil
        }

        if lowered.contains("ethernet")
            || lowered.contains("lan")
            || lowered.contains("usb 10")
            || lowered.contains("thunderbolt ethernet")
            || lowered.contains("rj45")
        {
            return .wired
        }

        return nil
    }

    private func resolveServiceName(portName: String, services: [String]) -> String? {
        if let exact = services.first(where: { $0 == portName }) {
            return exact
        }

        // Some adapters use slightly different service vs hardware port names.
        return services.first { service in
            service.localizedCaseInsensitiveCompare(portName) == .orderedSame
                || service.localizedCaseInsensitiveContains(portName)
                || portName.localizedCaseInsensitiveContains(service)
        }
    }

}
