import Foundation

struct WiFiNetwork: Identifiable, Equatable, Sendable {
    var id: String { ssid.lowercased() }
    let ssid: String
    let rssi: Int
    let isSecure: Bool
    let isCurrent: Bool

    var signalBars: Int {
        // Rough mapping for UI bars (0...3)
        switch rssi {
        case -55...0: return 3
        case -70 ..< -55: return 2
        case -85 ..< -70: return 1
        default: return 0
        }
    }
}
