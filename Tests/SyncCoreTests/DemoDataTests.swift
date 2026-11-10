import XCTest
@testable import SyncCore

@MainActor
final class DemoDataTests: XCTestCase {
    func testAllGoodScenarioIsHealthy() async {
        let model = SyncAssistantModel(dependencies: .demo(.allGood))
        await model.syncNow()
        XCTAssertEqual(model.report?.overall, .good)
        XCTAssertEqual(model.serviceState(.safari), .on)
        XCTAssertEqual(model.lastRestart?.succeeded, true)
        XCTAssertNotNil(model.lastSyncDate)
    }

    func testNeedsAttentionScenarioShowsWarnings() async {
        let model = SyncAssistantModel(dependencies: .demo(.needsAttention))
        await model.runChecks()
        XCTAssertEqual(model.report?.overall, .warning)
        XCTAssertEqual(model.report?.result(for: .lowPowerMode)?.status, .warning)
        XCTAssertEqual(model.report?.result(for: .diskSpace)?.status, .warning)
        XCTAssertEqual(model.serviceState(.safari), .off)
    }

    func testDemoProbeAlwaysReachable() async throws {
        let code = try await DemoProbe().statusCode(for: ConnectivityCheck.iCloudURL)
        XCTAssertEqual(code, 200)
        XCTAssertEqual(DemoScenario(rawValue: "attention"), .needsAttention)
    }
}
