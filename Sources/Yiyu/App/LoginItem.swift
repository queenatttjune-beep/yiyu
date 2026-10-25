import Foundation
import ServiceManagement

/// Opens the app when you log in, via the system's Login Items list.
@MainActor
enum LoginItem {
    private static let firstLaunchKey = "loginItemConfiguredOnFirstLaunch"

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// The panel is meant to always be there, so turn this on once; the menu can turn it off.
    static func enableOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard Bundle.main.bundleIdentifier != nil, !defaults.bool(forKey: firstLaunchKey) else { return }
        defaults.set(true, forKey: firstLaunchKey)
        do {
            try setEnabled(true)
        } catch {
            NSLog("Yiyu: adding the login item failed: %@", error.localizedDescription)
        }
    }
}
