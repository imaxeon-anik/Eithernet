import AppKit
import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        #if DEBUG
        // Avoid polluting Login Items while iterating with `swift run` / debug builds.
        if enabled {
            throw LaunchAtLoginError.debugBuildsDisabled
        }
        #endif

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openLoginItemsSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.general",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}

enum LaunchAtLoginError: LocalizedError {
    case debugBuildsDisabled

    var errorDescription: String? {
        switch self {
        case .debugBuildsDisabled:
            return "Launch at Login is only available in the packaged app (not debug builds)."
        }
    }
}
