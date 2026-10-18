import Foundation
import ServiceManagement

/// Starting at login, through macOS's own login items (System Settings → General → Login Items).
@MainActor
enum LoginItem {
    static let decidedKey = "loginItemDecided"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Turns it on or off and returns whether it's on now.
    @discardableResult
    static func set(_ on: Bool) -> Bool {
        UserDefaults.standard.set(true, forKey: decidedKey)
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            complain("couldn't \(on ? "add" : "remove") the login item: \(error.localizedDescription)")
        }
        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        return isEnabled
    }

    /// For `install.sh --uninstall` (`--remove-login-item`): takes it out of login items, if it's there.
    static func remove() {
        guard [.enabled, .requiresApproval].contains(SMAppService.mainApp.status) else { return }
        do { try SMAppService.mainApp.unregister() } catch {
            complain("couldn't remove the login item: \(error.localizedDescription)")
        }
    }

    /// The first launch from an Applications folder turns it on; after that it's left to
    /// the switch on the settings page. Not from a build folder, which would be the wrong copy.
    static func enableOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: decidedKey), isInstalled else { return }
        set(true)
    }

    static var isInstalled: Bool {
        func path(_ url: URL) -> String {
            url.standardizedFileURL.path(percentEncoded: false).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        let folders = [URL(filePath: "/Applications"), FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications")]
        return folders.map(path).contains(path(Bundle.main.bundleURL.deletingLastPathComponent()))
    }
}
