import Darwin
import Foundation

enum NetworkAddress {
    /// Best-effort IPv4 for a BSD interface name (e.g. `en0`).
    static func ipv4(for interfaceName: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }

            let name = String(cString: current.pointee.ifa_name)
            guard name == interfaceName else { continue }
            guard let addr = current.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else { continue }
            let ip = hostname.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
            guard let value = String(bytes: ip, encoding: .utf8), value != "0.0.0.0" else {
                continue
            }
            return value
        }
        return nil
    }
}
