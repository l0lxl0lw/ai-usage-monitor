import XCTest
import MonitorCore
import MonitorAdapters

final class QuotaTests: XCTestCase {
    func testFractionalWeeklyOnlyAndNullableResets() throws {
        let data = Data(#"{"rateLimits":{"primary":null,"secondary":{"usedPercent":12.25,"windowDurationMins":10080,"resetsAt":null},"credits":{"balance":"17.5"}}}"#.utf8)
        let quota = try CodexQuota.decode(data)
        XCTAssertEqual(quota.windows.count, 1); XCTAssertEqual(quota.windows[0].usedPercent, 12.25)
        XCTAssertEqual(quota.windows[0].durationSeconds, 604800); XCTAssertNil(quota.windows[0].resetsAt)
        XCTAssertEqual(quota.credits, "17.5")
    }
    func testMissingIsNotZeroAndBucketsAreNotAccounts() throws {
        XCTAssertTrue(try CodexQuota.decode(Data("{}".utf8)).windows.isEmpty)
        let quota = try CodexQuota.decode(Data(#"{"rateLimitsByLimitId":{"synthetic":{"primary":{"usedPercent":50.5,"resetsAt":1700000000}}}}"#.utf8))
        XCTAssertNil(quota.identity); XCTAssertEqual(quota.windows[0].resetsAt?.timeIntervalSince1970, 1700000000)
        XCTAssertNil(quota.windows[0].durationSeconds)
    }
    func testInvalidQuotaAndPastReset() throws {
        XCTAssertThrowsError(try CodexQuota.decode(Data(#"{"rateLimits":{"primary":{"usedPercent":true}}}"#.utf8)))
        XCTAssertThrowsError(try ClaudeQuota.decode(["rate_limits": ["five_hour": ["used_percentage": true]]]))
        for number in [-1.0, 100.1, Double.infinity, Double.nan] { XCTAssertThrowsError(try QuotaWindow(label: "Test", usedPercent: number)) }
        XCTAssertThrowsError(try QuotaWindow(label: "Test", usedPercent: 0, durationSeconds: -1))
        let window = try QuotaWindow(label: "Test", usedPercent: 87, resetsAt: Date(timeIntervalSince1970: 1))
        XCTAssertTrue(window.resetDescription().contains("awaiting")); XCTAssertEqual(window.usedPercent, 87)
    }
    func testClaudeOrdinarySessionTelemetry() throws {
        let object: [String: Any] = ["rate_limits": ["seven_day": ["used_percentage": 20.5, "resets_at": 1700000000]]]
        let windows = try ClaudeQuota.decode(object)
        XCTAssertEqual(windows.count, 1); XCTAssertEqual(windows[0].durationSeconds, 604800)
        XCTAssertEqual(windows[0].usedPercent, 20.5); XCTAssertTrue(try ClaudeQuota.decode([:]).isEmpty)
    }
    func testPollingSingleFlightIndependentBackoffAndCancellation() {
        let now = Date(); var a = PollSchedule(), b = PollSchedule()
        XCTAssertTrue(a.begin(now: now)); XCTAssertFalse(a.begin(now: now)); XCTAssertTrue(b.begin(now: now))
        a.finish(now: now, success: false, retryAfter: 600)
        XCTAssertFalse(a.begin(now: now.addingTimeInterval(599)))
        XCTAssertTrue(a.begin(now: now.addingTimeInterval(600)))
        b.cancel(); XCTAssertTrue(b.begin(now: now))
    }
}
