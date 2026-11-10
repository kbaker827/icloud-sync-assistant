import AppKit
import SyncCore

/// Opens apps, folders and settings panes. None of these change any settings.
enum SystemActions {
    static let systemStatusURL = URL(string: "https://www.apple.com/support/systemstatus/")

    /// The Apple Account pane in System Settings (macOS 13+).
    static let appleAccountSettingsURL = URL(string: "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings")

    static func open(_ service: ICloudService) {
        if service == .drive {
            openICloudDrive()
            return
        }
        let workspace = NSWorkspace.shared
        for identifier in service.bundleIdentifiers {
            if let appURL = workspace.urlForApplication(withBundleIdentifier: identifier) {
                workspace.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                return
            }
        }
        // The app isn't installed (for example, Passwords before macOS 15).
        openAppleAccountSettings()
    }

    static func openICloudDrive() {
        let driveURL = DriveScanner.iCloudDriveURL
        if FileManager.default.fileExists(atPath: driveURL.path) {
            _ = NSWorkspace.shared.open(driveURL)
        } else {
            openAppleAccountSettings()
        }
    }

    static func openAppleAccountSettings() {
        guard let url = appleAccountSettingsURL else { return }
        _ = NSWorkspace.shared.open(url)
    }

    static func openSystemStatus() {
        guard let url = systemStatusURL else { return }
        _ = NSWorkspace.shared.open(url)
    }
}
