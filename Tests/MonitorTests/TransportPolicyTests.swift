import XCTest
import MonitorAdapters

final class TransportPolicyTests: XCTestCase {
    func testEndpointValidationAndGetAllowlist() throws {
        _ = try TransportPolicy.localURL("http://127.0.0.1:4096")
        for value in ["http://example.com:4096", "http://127.0.0.1.evil:4096", "http://user:secret@127.0.0.1:4096", "https://127.0.0.1:4096", "http://localhost:4096", "http://127.0.0.1:4096/#fragment"] {
            XCTAssertThrowsError(try TransportPolicy.localURL(value), value)
        }
        XCTAssertTrue(TransportPolicy.allowGET("/api/session/ses-a/permission", sessionIDs: ["ses-a"]))
        XCTAssertFalse(TransportPolicy.allowGET("/api/session/../permission", sessionIDs: [".."]))
        for path in ["/api/config", "/api/credential", "/api/session/ses-b/permission", "/api/session/ses-a/message", "/api/session/ses-a/form/reply", "/api/session/../config"] {
            XCTAssertFalse(TransportPolicy.allowGET(path, sessionIDs: ["ses-a"]))
        }
    }
    func testOrcaPoisonedSelectorsNotInherited() {
        setenv("ORCA_ENVIRONMENT", "synthetic-poison", 1); setenv("ORCA_PAIRING_CODE", "synthetic-poison", 1)
        defer { unsetenv("ORCA_ENVIRONMENT"); unsetenv("ORCA_PAIRING_CODE") }
        let env = TransportPolicy.orcaEnvironment(home: "/synthetic", temporary: "/synthetic-tmp")
        XCTAssertNil(env["ORCA_ENVIRONMENT"]); XCTAssertNil(env["ORCA_PAIRING_CODE"])
        XCTAssertEqual(Set(env.keys), ["HOME", "TMPDIR", "PATH", "LANG"])
    }
    func testRelativeProcessDenied() {
        XCTAssertThrowsError(try ProcessTransport().run(executable: "orca", arguments: [], environment: [:]))
    }
}
