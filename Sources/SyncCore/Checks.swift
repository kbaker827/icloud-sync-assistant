import Foundation

/// Turns raw facts about the Mac into plain-language check results.
/// Every function here is pure so it can be tested without a real Mac setup.
public enum Checks {
    public static let lowDiskWarningBytes: Int64 = 10_000_000_000
    public static let lowDiskProblemBytes: Int64 = 2_000_000_000

    /// `statusCode` is `nil` when the request failed entirely.
    public static func internet(statusCode: Int?) -> CheckResult {
        let title = "Connection to iCloud"
        guard let statusCode else {
            return CheckResult(kind: .internet, title: title, status: .problem,
                               detail: "This Mac can't reach iCloud. Check that Wi-Fi is connected, then try again.")
        }
        if (200..<500).contains(statusCode) {
            return CheckResult(kind: .internet, title: title, status: .good,
                               detail: "This Mac can reach iCloud.")
        }
        return CheckResult(kind: .internet, title: title, status: .warning,
                           detail: "iCloud gave an unusual answer (code \(statusCode)). Apple may be having problems. Check Apple System Status below.")
    }

    public static func account(_ snapshot: AccountSnapshot?) -> CheckResult {
        let title = "Apple Account"
        guard let snapshot else {
            return CheckResult(kind: .account, title: title, status: .unknown,
                               detail: "Couldn't read the iCloud account details. Use Apple Account Settings below to make sure you're signed in.")
        }
        guard snapshot.isLoggedIn else {
            return CheckResult(kind: .account, title: title, status: .problem,
                               detail: "This Mac isn't signed in to iCloud. Open Apple Account Settings below to sign in.")
        }
        return CheckResult(kind: .account, title: title, status: .good,
                           detail: "Signed in as \(snapshot.label).")
    }

    public static func iCloudDrive(folderExists: Bool, driveEnabled: ServiceState) -> CheckResult {
        let title = "iCloud Drive"
        if folderExists && driveEnabled != .off {
            return CheckResult(kind: .iCloudDrive, title: title, status: .good,
                               detail: "iCloud Drive is set up on this Mac.")
        }
        return CheckResult(kind: .iCloudDrive, title: title, status: .warning,
                           detail: "iCloud Drive is turned off on this Mac, so files won't sync. Turn it on in Apple Account Settings > iCloud.")
    }

    public static func pendingFiles(_ summary: DriveSummary?, folderExists: Bool) -> CheckResult {
        let title = "Files waiting to sync"
        guard folderExists else {
            return CheckResult(kind: .pendingFiles, title: title, status: .unknown,
                               detail: "iCloud Drive isn't set up, so there are no files to check.")
        }
        guard let summary else {
            return CheckResult(kind: .pendingFiles, title: title, status: .unknown,
                               detail: "Couldn't look inside iCloud Drive.")
        }
        if summary.scanned == 0 && summary.readErrors > 0 {
            return CheckResult(kind: .pendingFiles, title: title, status: .unknown,
                               detail: "Couldn't look inside iCloud Drive. If macOS asked for permission, click Allow and press Sync Now again.")
        }
        if summary.scanned == 0 {
            return CheckResult(kind: .pendingFiles, title: title, status: .good,
                               detail: "iCloud Drive is empty, so nothing is waiting.")
        }
        guard summary.hasSyncInfo else {
            return CheckResult(kind: .pendingFiles, title: title, status: .unknown,
                               detail: "macOS didn't report file-by-file progress. Open iCloud Drive and look for cloud icons next to files.")
        }
        if summary.errors > 0 {
            return CheckResult(kind: .pendingFiles, title: title, status: .warning,
                               detail: "\(plural(summary.errors, "file")) couldn't sync. Open iCloud Drive in Finder and look for files with a warning icon.")
        }

        var detail: String
        if summary.transferring > 0 {
            detail = "\(plural(summary.uploading, "file")) uploading and \(plural(summary.downloading, "file")) downloading right now. Keep the Mac awake and online until they finish."
        } else {
            detail = "Everything checked is up to date."
        }
        if summary.cloudOnly > 0 {
            detail += " \(plural(summary.cloudOnly, "file")) \(summary.cloudOnly == 1 ? "is" : "are") kept in iCloud only to save space, which is normal."
        }
        if summary.reachedLimit {
            detail += " (Checked the first \(summary.scanned) files.)"
        }
        return CheckResult(kind: .pendingFiles, title: title, status: .good, detail: detail)
    }

    public static func diskSpace(availableBytes: Int64?) -> CheckResult {
        let title = "Free storage"
        guard let availableBytes else {
            return CheckResult(kind: .diskSpace, title: title, status: .unknown,
                               detail: "Couldn't check how much space is free.")
        }
        let amount = ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file)
        if availableBytes < lowDiskProblemBytes {
            return CheckResult(kind: .diskSpace, title: title, status: .problem,
                               detail: "Only \(amount) free. iCloud needs room to download. Free up some space on this Mac.")
        }
        if availableBytes < lowDiskWarningBytes {
            return CheckResult(kind: .diskSpace, title: title, status: .warning,
                               detail: "\(amount) free. Syncing can pause when space runs low.")
        }
        return CheckResult(kind: .diskSpace, title: title, status: .good, detail: "\(amount) free.")
    }

    public static func lowPowerMode(isEnabled: Bool) -> CheckResult {
        let title = "Low Power Mode"
        if isEnabled {
            return CheckResult(kind: .lowPowerMode, title: title, status: .warning,
                               detail: "Low Power Mode is on, which can pause iCloud syncing. Turn it off in System Settings > Battery.")
        }
        return CheckResult(kind: .lowPowerMode, title: title, status: .good, detail: "Low Power Mode is off.")
    }

    static func plural(_ count: Int, _ noun: String) -> String {
        "\(count) \(count == 1 ? noun : noun + "s")"
    }
}
