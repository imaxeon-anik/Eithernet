import Foundation

enum NetworkInterfaceKind: String, Sendable {
    case wired
    case wireless
}

struct NetworkInterface: Identifiable, Equatable, Sendable {
    var id: String { device }
    let name: String
    let device: String
    let serviceName: String
    let kind: NetworkInterfaceKind
    var isEnabled: Bool
}
