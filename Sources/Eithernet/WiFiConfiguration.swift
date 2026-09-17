import CoreWLAN
import Foundation
import SecurityFoundation

enum WiFiConfiguration {
    nonisolated static func autoJoinEnabled(for ssid: String) throws -> Bool? {
        let interface = try wifiInterface()
        guard let profiles = interface.configuration()?.networkProfiles else { return nil }

        guard let profile = profile(matchingSSID: ssid, in: profiles) else { return nil }

        // CoreWLAN exposes auto-join via KVC on profile objects (not public API; may change between macOS releases).
        let disabled = (profile.value(forKey: "disabled") as? Bool) ?? false
        let temporarilyDisabled = (profile.value(forKey: "temporarilyDisabled") as? Bool) ?? false
        if temporarilyDisabled { return false }
        return !disabled
    }

    nonisolated static func setAutoJoinEnabled(_ enabled: Bool, for ssid: String) throws {
        let interface = try wifiInterface()
        guard let base = interface.configuration() else {
            throw NetworkCommandError.message("Couldn’t read Wi‑Fi configuration.")
        }
        guard let mutable = base.mutableCopy() as? CWMutableConfiguration else {
            throw NetworkCommandError.message("Couldn’t update Wi‑Fi configuration.")
        }

        let profiles = NSMutableOrderedSet(orderedSet: base.networkProfiles)
        guard
            let index = profiles.array.firstIndex(where: { element in
                guard let profile = element as? CWNetworkProfile else { return false }
                return profile.ssid == ssid
            }),
            let profile = profiles[index] as? CWNetworkProfile,
            let updated = profile.mutableCopy() as? CWNetworkProfile
        else {
            throw NetworkCommandError.message("“\(ssid)” isn’t a saved network.")
        }

        updated.setValue(!enabled, forKey: "disabled") // inverse of auto-join; see read path above
        profiles[index] = updated
        mutable.networkProfiles = profiles as NSOrderedSet

        let authorization = try administratorAuthorization()
        do {
            try interface.commitConfiguration(mutable, authorization: authorization)
        } catch {
            throw NetworkCommandError.message(
                "Couldn’t update auto‑join for “\(ssid)”. \(error.localizedDescription)"
            )
        }
    }

    nonisolated private static func wifiInterface() throws -> CWInterface {
        guard let interface = CWWiFiClient.shared().interface() else {
            throw NetworkCommandError.message("No Wi‑Fi interface available.")
        }
        return interface
    }

    nonisolated private static func profile(
        matchingSSID ssid: String,
        in profiles: NSOrderedSet
    ) -> CWNetworkProfile? {
        for case let profile as CWNetworkProfile in profiles {
            if profile.ssid == ssid { return profile }
        }
        return nil
    }

    nonisolated private static func administratorAuthorization() throws -> SFAuthorization? {
        guard let authorization = SFAuthorization() else { return nil }
        do {
            try authorization.obtain(
                withRight: "system.privilege.admin",
                flags: [.extendRights, .interactionAllowed]
            )
            return authorization
        } catch {
            throw NetworkCommandError.message(
                "Administrator permission is required to change auto‑join."
            )
        }
    }
}
