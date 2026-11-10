import XCTest
@testable import SyncCore

final class AccountReaderTests: XCTestCase {
    private func plistData(_ object: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)
    }

    func testParsesSignedInAccountAndServices() throws {
        let services: [[String: Any]] = [
            ["Name": "MOBILE_DOCUMENTS", "Enabled": true],
            ["Name": "CONTACTS", "Enabled": false],
            ["Name": "NO_FLAG"],
        ]
        let account: [String: Any] = [
            "AccountID": "alex@icloud.com",
            "DisplayName": "Alex Doe",
            "LoggedIn": true,
            "Services": services,
        ]
        let snapshot = try XCTUnwrap(AccountReader.parse(try plistData(["Accounts": [account]])))
        XCTAssertTrue(snapshot.isLoggedIn)
        XCTAssertEqual(snapshot.label, "Alex Doe")
        XCTAssertEqual(snapshot.state(for: .drive), .on)
        XCTAssertEqual(snapshot.state(for: .contacts), .off)
        XCTAssertEqual(snapshot.state(for: .photos), .unknown)
        XCTAssertNil(snapshot.serviceStates["NO_FLAG"])
    }

    func testPrefersLoggedInAccount() throws {
        let accounts: [[String: Any]] = [
            ["AccountID": "old@icloud.com", "LoggedIn": false],
            ["AccountID": "new@icloud.com", "LoggedIn": true],
        ]
        let snapshot = try XCTUnwrap(AccountReader.parse(try plistData(["Accounts": accounts])))
        XCTAssertEqual(snapshot.accountID, "new@icloud.com")
        XCTAssertEqual(snapshot.label, "new@icloud.com")
    }

    func testSignedOutAccount() throws {
        let accounts: [[String: Any]] = [["LoggedIn": false]]
        let snapshot = try XCTUnwrap(AccountReader.parse(try plistData(["Accounts": accounts])))
        XCTAssertFalse(snapshot.isLoggedIn)
        XCTAssertEqual(snapshot.label, "your Apple Account")
    }

    func testRejectsGarbageAndEmpty() throws {
        let noAccounts: [[String: Any]] = []
        XCTAssertNil(AccountReader.parse(Data("not a plist".utf8)))
        XCTAssertNil(AccountReader.parse(try plistData(["Accounts": noAccounts])))
        XCTAssertNil(AccountReader.parse(try plistData(["Other": 1])))
    }

    func testReadFromFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".plist")
        defer { try? FileManager.default.removeItem(at: url) }
        let accounts: [[String: Any]] = [["AccountID": "a@icloud.com"]]
        try plistData(["Accounts": accounts]).write(to: url)

        XCTAssertEqual(AccountReader.read(from: url)?.accountID, "a@icloud.com")
        XCTAssertNil(AccountReader.read(from: url.appendingPathExtension("missing")))
        XCTAssertTrue(AccountReader.defaultPlistURL.path.hasSuffix("Library/Preferences/MobileMeAccounts.plist"))
    }
}

final class DriveScannerTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nested = root.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        for name in ["a.txt", "b.txt", "Folder/c.txt", ".hidden"] {
            try Data("x".utf8).write(to: root.appendingPathComponent(name))
        }
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    func testScanCountsFilesSkippingFoldersAndHidden() throws {
        let summary = try XCTUnwrap(DriveScanner.scan(root: root) { url in
            url.lastPathComponent == "a.txt" ? ItemSyncState(isUploading: true) : ItemSyncState()
        })
        XCTAssertEqual(summary.scanned, 3)
        XCTAssertEqual(summary.uploading, 1)
        XCTAssertFalse(summary.reachedLimit)
        XCTAssertTrue(summary.hasSyncInfo)
    }

    func testScanStopsAtLimit() throws {
        let summary = try XCTUnwrap(DriveScanner.scan(root: root, limit: 2) { _ in ItemSyncState() })
        XCTAssertEqual(summary.scanned, 2)
        XCTAssertTrue(summary.reachedLimit)
    }

    func testScanMissingFolderReturnsNil() {
        XCTAssertNil(DriveScanner.scan(root: root.appendingPathComponent("nope")))
    }

    func testLiveStateIsNilOutsideICloud() throws {
        XCTAssertNil(DriveScanner.liveState(for: root.appendingPathComponent("a.txt")))
        let summary = try XCTUnwrap(DriveScanner.scan(root: root))
        XCTAssertEqual(summary.unknown, summary.scanned)
        XCTAssertFalse(summary.hasSyncInfo)
    }

    func testSummaryRecordsEveryState() {
        var summary = DriveSummary()
        summary.record(ItemSyncState(isUploading: true, isDownloading: true, isDownloaded: false, hasError: true))
        summary.record(nil)
        XCTAssertEqual(summary.scanned, 2)
        XCTAssertEqual(summary.transferring, 2)
        XCTAssertEqual(summary.cloudOnly, 1)
        XCTAssertEqual(summary.errors, 1)
        XCTAssertEqual(summary.unknown, 1)
    }

    func testICloudDrivePath() {
        XCTAssertTrue(DriveScanner.iCloudDriveURL.path.hasSuffix("Library/Mobile Documents/com~apple~CloudDocs"))
    }
}

private struct FakeRunner: CommandRunning {
    let results: [String: Int32]
    func run(_ executablePath: String, arguments: [String]) throws -> Int32 {
        guard let name = arguments.last, let code = results[name] else {
            throw CocoaError(.executableNotLoadable)
        }
        return code
    }
}

private final class RecordingRunner: CommandRunning, @unchecked Sendable {
    private(set) var calls: [(String, [String])] = []
    func run(_ executablePath: String, arguments: [String]) throws -> Int32 {
        calls.append((executablePath, arguments))
        return 0
    }
}

final class SyncServicesTests: XCTestCase {
    func testSortsOutcomesByExitCode() {
        let runner = FakeRunner(results: ["ok": 0, "idle": 1, "bad": 2])
        let outcome = SyncServices.restart(["ok", "idle", "bad", "throws"], userName: "me", using: runner)
        XCTAssertEqual(outcome.restarted, ["ok"])
        XCTAssertEqual(outcome.notRunning, ["idle"])
        XCTAssertEqual(outcome.failed, ["bad", "throws"])
        XCTAssertFalse(outcome.succeeded)
    }

    func testOnlyTargetsCurrentUsersProcesses() {
        let runner = RecordingRunner()
        _ = SyncServices.restart(userName: "alex", using: runner)
        XCTAssertEqual(runner.calls.count, SyncServices.daemons.count)
        XCTAssertEqual(runner.calls.first?.0, "/usr/bin/killall")
        XCTAssertEqual(runner.calls.first?.1, ["-u", "alex", "bird"])
    }

    func testSummaries() {
        XCTAssertTrue(RestartOutcome(restarted: ["bird"], notRunning: [], failed: []).summary.contains("Restarted"))
        XCTAssertTrue(RestartOutcome(restarted: [], notRunning: ["bird"], failed: []).summary.contains("wasn't running"))
        XCTAssertTrue(RestartOutcome(restarted: [], notRunning: [], failed: ["cloudd"]).summary.contains("cloudd"))
    }

    func testProcessRunnerReportsExitCodes() throws {
        let runner = ProcessRunner()
        XCTAssertEqual(try runner.run("/usr/bin/true", arguments: []), 0)
        XCTAssertEqual(try runner.run("/usr/bin/false", arguments: []), 1)
        XCTAssertThrowsError(try runner.run("/nonexistent/tool", arguments: []))
    }
}

final class ServiceAndDiskTests: XCTestCase {
    func testEveryServiceIsFullyDescribed() {
        XCTAssertEqual(ICloudService.allCases.count, 9)
        for service in ICloudService.allCases {
            XCTAssertFalse(service.displayName.isEmpty)
            XCTAssertFalse(service.symbolName.isEmpty)
            XCTAssertFalse(service.macTip.isEmpty)
            XCTAssertFalse(service.iPhoneTip.isEmpty)
            XCTAssertFalse(service.accountServiceNames.isEmpty)
            XCTAssertEqual(service.id, service.rawValue)
            XCTAssertEqual(service.bundleIdentifiers.isEmpty, service == .drive)
        }
    }

    func testDiskSpaceReadsAVolume() {
        let bytes = DiskSpace.availableBytes(at: FileManager.default.temporaryDirectory)
        XCTAssertGreaterThan(bytes ?? 1, 0)
    }

    func testURLSessionProbeDefaults() {
        XCTAssertEqual(URLSessionProbe().timeout, 10)
        XCTAssertEqual(ConnectivityCheck.iCloudURL.host, "www.icloud.com")
    }
}
