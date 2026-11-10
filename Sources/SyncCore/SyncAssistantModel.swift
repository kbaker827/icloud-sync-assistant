import Combine
import Foundation

/// Everything the dashboard needs from the outside world, so tests can swap in fakes.
public struct SyncDependencies: Sendable {
    public var probe: any ReachabilityProbe
    public var readAccount: @Sendable () -> AccountSnapshot?
    public var driveFolderExists: @Sendable () -> Bool
    public var scanDrive: @Sendable () -> DriveSummary?
    public var availableDiskBytes: @Sendable () -> Int64?
    public var isLowPowerMode: @Sendable () -> Bool
    public var restartServices: @Sendable () -> RestartOutcome
    public var now: @Sendable () -> Date

    public init(
        probe: any ReachabilityProbe,
        readAccount: @escaping @Sendable () -> AccountSnapshot?,
        driveFolderExists: @escaping @Sendable () -> Bool,
        scanDrive: @escaping @Sendable () -> DriveSummary?,
        availableDiskBytes: @escaping @Sendable () -> Int64?,
        isLowPowerMode: @escaping @Sendable () -> Bool,
        restartServices: @escaping @Sendable () -> RestartOutcome,
        now: @escaping @Sendable () -> Date
    ) {
        self.probe = probe
        self.readAccount = readAccount
        self.driveFolderExists = driveFolderExists
        self.scanDrive = scanDrive
        self.availableDiskBytes = availableDiskBytes
        self.isLowPowerMode = isLowPowerMode
        self.restartServices = restartServices
        self.now = now
    }

    public static let live = SyncDependencies(
        probe: URLSessionProbe(),
        readAccount: { AccountReader.read() },
        driveFolderExists: { FileManager.default.fileExists(atPath: DriveScanner.iCloudDriveURL.path) },
        scanDrive: { DriveScanner.scan(root: DriveScanner.iCloudDriveURL) },
        availableDiskBytes: { DiskSpace.availableBytes() },
        isLowPowerMode: { ProcessInfo.processInfo.isLowPowerModeEnabled },
        restartServices: { SyncServices.restart(using: ProcessRunner()) },
        now: { Date() }
    )
}

/// Drives the dashboard: runs the checks and the Sync Now sequence.
@MainActor
public final class SyncAssistantModel: ObservableObject {
    public enum Phase: Equatable, Sendable {
        case idle
        case restartingServices
        case checking
        case finished
    }

    @Published public private(set) var phase: Phase = .idle
    @Published public private(set) var report: HealthReport?
    @Published public private(set) var account: AccountSnapshot?
    @Published public private(set) var lastRestart: RestartOutcome?
    @Published public private(set) var lastSyncDate: Date?

    private let dependencies: SyncDependencies

    public init(dependencies: SyncDependencies = .live) {
        self.dependencies = dependencies
    }

    public var isBusy: Bool {
        phase == .restartingServices || phase == .checking
    }

    public var statusMessage: String {
        switch phase {
        case .idle: return "Press Sync Now to wake up iCloud and check everything."
        case .restartingServices: return "Waking up iCloud…"
        case .checking: return "Checking your iCloud connection…"
        case .finished: return report?.headline ?? "Done"
        }
    }

    public func serviceState(_ service: ICloudService) -> ServiceState {
        account?.state(for: service) ?? .unknown
    }

    /// Runs the health checks without restarting anything.
    public func runChecks() async {
        guard !isBusy else { return }
        phase = .checking
        await refreshReport()
        phase = .finished
    }

    /// Restarts iCloud's background sync, then re-runs every check.
    public func syncNow() async {
        guard !isBusy else { return }
        phase = .restartingServices
        let deps = dependencies
        lastRestart = await Task.detached(priority: .userInitiated) { deps.restartServices() }.value
        phase = .checking
        await refreshReport()
        lastSyncDate = deps.now()
        phase = .finished
    }

    private func refreshReport() async {
        let deps = dependencies
        async let internet = ConnectivityCheck.run(probe: deps.probe)
        let local = await Task.detached(priority: .userInitiated) { LocalSnapshot.capture(deps) }.value
        let internetResult = await internet
        account = local.account
        report = HealthReport(results: [internetResult] + local.results, date: deps.now())
    }
}

/// The checks that only look at this Mac. Runs off the main thread because scanning
/// iCloud Drive can take a moment.
struct LocalSnapshot: Sendable {
    let account: AccountSnapshot?
    let results: [CheckResult]

    static func capture(_ deps: SyncDependencies) -> LocalSnapshot {
        let account = deps.readAccount()
        let driveExists = deps.driveFolderExists()
        let summary = driveExists ? deps.scanDrive() : nil
        let driveState = account?.state(for: .drive) ?? .unknown

        return LocalSnapshot(account: account, results: [
            Checks.account(account),
            Checks.iCloudDrive(folderExists: driveExists, driveEnabled: driveState),
            Checks.pendingFiles(summary, folderExists: driveExists),
            Checks.diskSpace(availableBytes: deps.availableDiskBytes()),
            Checks.lowPowerMode(isEnabled: deps.isLowPowerMode()),
        ])
    }
}
