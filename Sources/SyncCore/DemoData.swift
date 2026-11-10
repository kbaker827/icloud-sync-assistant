import Foundation

/// Canned data used to render README screenshots without touching a real iCloud account.
public enum DemoScenario: String, CaseIterable, Sendable {
    case allGood = "good"
    case needsAttention = "attention"
}

/// A probe that always reports iCloud as reachable.
public struct DemoProbe: ReachabilityProbe {
    public init() {}

    public func statusCode(for url: URL) async throws -> Int { 200 }
}

extension SyncDependencies {
    public static func demo(_ scenario: DemoScenario) -> SyncDependencies {
        let isAllGood = scenario == .allGood
        let services: [String: Bool] = [
            "CLOUD_PHOTOS": true,
            "MESSAGES": true,
            "NOTES": true,
            "CONTACTS": true,
            "CALENDAR": true,
            "REMINDERS": true,
            "BOOKMARKS": isAllGood,
            "KEYCHAIN_SYNC": true,
            "MOBILE_DOCUMENTS": true,
        ]
        let drive: DriveSummary = {
            var summary = DriveSummary()
            summary.scanned = 1_284
            summary.cloudOnly = 312
            summary.uploading = isAllGood ? 0 : 3
            summary.downloading = isAllGood ? 0 : 1
            return summary
        }()
        // The classic Apple demo time, so screenshots look the same on every run.
        let demoDate = Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: Date()) ?? Date()

        return SyncDependencies(
            probe: DemoProbe(),
            readAccount: {
                AccountSnapshot(accountID: "jamie@icloud.com", displayName: "Jamie Appleseed",
                                isLoggedIn: true, serviceStates: services)
            },
            driveFolderExists: { true },
            scanDrive: { drive },
            availableDiskBytes: { isAllGood ? 214_000_000_000 : 6_400_000_000 },
            isLowPowerMode: { !isAllGood },
            restartServices: { RestartOutcome(restarted: SyncServices.daemons, notRunning: [], failed: []) },
            now: { demoDate }
        )
    }
}
