import XCTest
@testable import SyncCore

final class ChecksTests: XCTestCase {
    // MARK: Internet

    func testInternetGoodForSuccessAndClientCodes() {
        XCTAssertEqual(Checks.internet(statusCode: 200).status, .good)
        XCTAssertEqual(Checks.internet(statusCode: 301).status, .good)
        XCTAssertEqual(Checks.internet(statusCode: 405).status, .good)
    }

    func testInternetWarningForServerError() {
        let result = Checks.internet(statusCode: 503)
        XCTAssertEqual(result.status, .warning)
        XCTAssertTrue(result.detail.contains("503"))
    }

    func testInternetProblemWhenRequestFails() {
        let result = Checks.internet(statusCode: nil)
        XCTAssertEqual(result.status, .problem)
        XCTAssertEqual(result.kind, .internet)
    }

    // MARK: Account

    func testAccountUnknownWhenUnreadable() {
        XCTAssertEqual(Checks.account(nil).status, .unknown)
    }

    func testAccountProblemWhenSignedOut() {
        let snapshot = AccountSnapshot(accountID: "a@icloud.com", displayName: nil, isLoggedIn: false, serviceStates: [:])
        XCTAssertEqual(Checks.account(snapshot).status, .problem)
    }

    func testAccountGoodShowsName() {
        let snapshot = AccountSnapshot(accountID: "a@icloud.com", displayName: "Alex", isLoggedIn: true, serviceStates: [:])
        let result = Checks.account(snapshot)
        XCTAssertEqual(result.status, .good)
        XCTAssertTrue(result.detail.contains("Alex"))
    }

    // MARK: iCloud Drive

    func testDriveGoodWhenFolderExists() {
        XCTAssertEqual(Checks.iCloudDrive(folderExists: true, driveEnabled: .unknown).status, .good)
        XCTAssertEqual(Checks.iCloudDrive(folderExists: true, driveEnabled: .on).status, .good)
    }

    func testDriveWarningWhenMissingOrOff() {
        XCTAssertEqual(Checks.iCloudDrive(folderExists: false, driveEnabled: .unknown).status, .warning)
        XCTAssertEqual(Checks.iCloudDrive(folderExists: true, driveEnabled: .off).status, .warning)
    }

    // MARK: Pending files

    func testPendingUnknownWhenNoDrive() {
        XCTAssertEqual(Checks.pendingFiles(nil, folderExists: false).status, .unknown)
        XCTAssertEqual(Checks.pendingFiles(nil, folderExists: true).status, .unknown)
    }

    func testPendingUnknownWhenPermissionRefused() {
        var summary = DriveSummary()
        summary.readErrors = 1
        let result = Checks.pendingFiles(summary, folderExists: true)
        XCTAssertEqual(result.status, .unknown)
        XCTAssertTrue(result.detail.contains("Allow"))
    }

    func testPendingGoodWhenEmpty() {
        let result = Checks.pendingFiles(DriveSummary(), folderExists: true)
        XCTAssertEqual(result.status, .good)
        XCTAssertTrue(result.detail.contains("empty"))
    }

    func testPendingUnknownWithoutSyncInfo() {
        var summary = DriveSummary()
        summary.record(nil)
        XCTAssertEqual(Checks.pendingFiles(summary, folderExists: true).status, .unknown)
    }

    func testPendingWarningOnErrors() {
        var summary = DriveSummary()
        summary.record(ItemSyncState(hasError: true))
        let result = Checks.pendingFiles(summary, folderExists: true)
        XCTAssertEqual(result.status, .warning)
        XCTAssertTrue(result.detail.hasPrefix("1 file "))
    }

    func testPendingReportsTransfersCloudOnlyAndLimit() {
        var summary = DriveSummary()
        summary.record(ItemSyncState(isUploading: true))
        summary.record(ItemSyncState(isDownloading: true, isDownloaded: false))
        summary.record(ItemSyncState(isDownloaded: false))
        summary.reachedLimit = true
        let result = Checks.pendingFiles(summary, folderExists: true)
        XCTAssertEqual(result.status, .good)
        XCTAssertTrue(result.detail.contains("1 file uploading"))
        XCTAssertTrue(result.detail.contains("1 file downloading"))
        XCTAssertTrue(result.detail.contains("2 files are kept in iCloud only"))
        XCTAssertTrue(result.detail.contains("Checked the first 3 files"))
    }

    func testPendingUpToDate() {
        var summary = DriveSummary()
        summary.record(ItemSyncState())
        summary.record(ItemSyncState(isDownloaded: false))
        let result = Checks.pendingFiles(summary, folderExists: true)
        XCTAssertTrue(result.detail.hasPrefix("Everything checked is up to date."))
        XCTAssertTrue(result.detail.contains("1 file is kept in iCloud only"))
    }

    // MARK: Disk space

    func testDiskSpaceThresholds() {
        XCTAssertEqual(Checks.diskSpace(availableBytes: nil).status, .unknown)
        XCTAssertEqual(Checks.diskSpace(availableBytes: 1_000_000_000).status, .problem)
        XCTAssertEqual(Checks.diskSpace(availableBytes: 5_000_000_000).status, .warning)
        XCTAssertEqual(Checks.diskSpace(availableBytes: 50_000_000_000).status, .good)
    }

    // MARK: Low Power Mode

    func testLowPowerMode() {
        XCTAssertEqual(Checks.lowPowerMode(isEnabled: true).status, .warning)
        XCTAssertEqual(Checks.lowPowerMode(isEnabled: false).status, .good)
    }

    func testPlural() {
        XCTAssertEqual(Checks.plural(0, "file"), "0 files")
        XCTAssertEqual(Checks.plural(1, "file"), "1 file")
        XCTAssertEqual(Checks.plural(2, "file"), "2 files")
    }
}
