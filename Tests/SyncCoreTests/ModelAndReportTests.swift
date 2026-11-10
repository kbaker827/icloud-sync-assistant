import XCTest
@testable import SyncCore

final class HealthReportTests: XCTestCase {
    private func result(_ status: CheckStatus, _ kind: CheckResult.Kind = .internet) -> CheckResult {
        CheckResult(kind: kind, title: "t", status: status, detail: "d")
    }

    func testOverallIsWorstStatus() {
        let report = HealthReport(results: [result(.good), result(.warning, .account), result(.unknown, .diskSpace)], date: Date())
        XCTAssertEqual(report.overall, .warning)
    }

    func testOverallUnknownWhenEmpty() {
        XCTAssertEqual(HealthReport(results: [], date: Date()).overall, .unknown)
    }

    func testHeadlineForEveryStatus() {
        let headlines = CheckStatus.allCases.map { HealthReport(results: [result($0)], date: Date()).headline }
        XCTAssertEqual(Set(headlines).count, CheckStatus.allCases.count)
    }

    func testLookupByKind() {
        let report = HealthReport(results: [result(.good, .diskSpace)], date: Date())
        XCTAssertNotNil(report.result(for: .diskSpace))
        XCTAssertNil(report.result(for: .account))
        XCTAssertEqual(report.results.first?.id, .diskSpace)
    }
}

private struct StubProbe: ReachabilityProbe {
    let code: Int?
    func statusCode(for url: URL) async throws -> Int {
        guard let code else { throw URLError(.notConnectedToInternet) }
        return code
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() { lock.lock(); value += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
}

final class ConnectivityTests: XCTestCase {
    func testReachable() async {
        let result = await ConnectivityCheck.run(probe: StubProbe(code: 200))
        XCTAssertEqual(result.status, .good)
    }

    func testUnreachable() async {
        let result = await ConnectivityCheck.run(probe: StubProbe(code: nil))
        XCTAssertEqual(result.status, .problem)
    }
}

@MainActor
final class SyncAssistantModelTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDependencies(restarts: Counter = Counter(), lowPower: Bool = false) -> SyncDependencies {
        let date = fixedDate
        return SyncDependencies(
            probe: StubProbe(code: 200),
            readAccount: {
                AccountSnapshot(accountID: "a@icloud.com", displayName: "Alex", isLoggedIn: true,
                                serviceStates: ["MOBILE_DOCUMENTS": true, "NOTES": false])
            },
            driveFolderExists: { true },
            scanDrive: {
                var summary = DriveSummary()
                summary.record(ItemSyncState())
                return summary
            },
            availableDiskBytes: { 100_000_000_000 },
            isLowPowerMode: { lowPower },
            restartServices: {
                restarts.increment()
                return RestartOutcome(restarted: ["bird", "cloudd"], notRunning: [], failed: [])
            },
            now: { date }
        )
    }

    func testStartsIdle() {
        let model = SyncAssistantModel(dependencies: makeDependencies())
        XCTAssertEqual(model.phase, .idle)
        XCTAssertFalse(model.isBusy)
        XCTAssertNil(model.report)
        XCTAssertFalse(model.statusMessage.isEmpty)
        XCTAssertEqual(model.serviceState(.drive), .unknown)
    }

    func testRunChecksBuildsReportInOrderWithoutRestarting() async {
        let restarts = Counter()
        let model = SyncAssistantModel(dependencies: makeDependencies(restarts: restarts))
        await model.runChecks()

        XCTAssertEqual(model.phase, .finished)
        XCTAssertEqual(restarts.count, 0)
        XCTAssertNil(model.lastSyncDate)
        XCTAssertEqual(model.report?.results.map(\.kind),
                       [.internet, .account, .iCloudDrive, .pendingFiles, .diskSpace, .lowPowerMode])
        XCTAssertEqual(model.report?.overall, .good)
        XCTAssertEqual(model.statusMessage, "Everything looks good")
        XCTAssertEqual(model.serviceState(.drive), .on)
        XCTAssertEqual(model.serviceState(.notes), .off)
        XCTAssertEqual(model.serviceState(.photos), .unknown)
    }

    func testSyncNowRestartsServicesAndRecordsDate() async {
        let restarts = Counter()
        let model = SyncAssistantModel(dependencies: makeDependencies(restarts: restarts, lowPower: true))
        await model.syncNow()

        XCTAssertEqual(restarts.count, 1)
        XCTAssertEqual(model.lastSyncDate, fixedDate)
        XCTAssertEqual(model.lastRestart?.succeeded, true)
        XCTAssertEqual(model.report?.overall, .warning)
        XCTAssertEqual(model.phase, .finished)
    }

    func testDriveSkippedWhenFolderMissing() {
        var deps = makeDependencies()
        deps.driveFolderExists = { false }
        deps.scanDrive = {
            XCTFail("Should not scan a missing drive")
            return nil
        }
        let snapshot = LocalSnapshot.capture(deps)
        XCTAssertEqual(snapshot.results.first { $0.kind == .pendingFiles }?.status, .unknown)
    }
}
