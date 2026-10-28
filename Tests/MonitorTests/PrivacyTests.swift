import XCTest
import Darwin
import MonitorCore
@testable import MonitorAdapters

final class PrivacyTests: XCTestCase {
    func testCanariesNeverEnterHookProjection() throws {
        let object: [String: Any] = ["hook_event_name": "SessionStart", "session_id": "synthetic", "title": "title-canary", "prompt": "secret-canary", "last_assistant_message": "assistant-canary", "tool_input": ["secret": "tool-canary"], "cwd": "/path-canary"]
        let event = try HookProjection.project(JSONSerialization.data(withJSONObject: object), source: .claude, profile: UUID(), version: "documented")
        let text = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
        XCTAssertFalse(text.contains("canary")); XCTAssertNil(Privacy.identifier("../../attack"))
        XCTAssertNil(Privacy.title("title\ncontrol")); XCTAssertEqual(Privacy.title("Synthetic title"), "Synthetic title")
    }
    func testSocketOwnershipSymlinksAndAbsentAppDrop() throws {
        let root = NSTemporaryDirectory() + UUID().uuidString
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(atPath: root) }
        XCTAssertTrue(UnixRelay.validate(root, type: S_IFDIR, mode: 0o700))
        XCTAssertFalse(UnixRelay.validate(root, type: S_IFDIR, mode: 0o700, uid: getuid() + 1))
        let link = root + "/link"; try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: root)
        XCTAssertFalse(UnixRelay.validate(link, type: S_IFDIR, mode: 0o700))
        XCTAssertThrowsError(try UnixRelay.send(Data("{}".utf8), path: root + "/absent.sock", deadline: DispatchTime.now().uptimeNanoseconds + 100_000_000))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root + "/absent.sock"))
    }
    func testStalledStdinAndOversizeHaveEndToEndBound() throws {
        var fds: [Int32] = [0,0]; XCTAssertEqual(pipe(&fds), 0)
        defer { close(fds[0]); close(fds[1]) }
        let start = Date()
        XCTAssertThrowsError(try UnixRelay.boundedRead(fd: fds[0], deadline: DispatchTime.now().uptimeNanoseconds + 20_000_000))
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5)
        XCTAssertThrowsError(try HookProjection.project(Data(repeating: 32, count: 65537), source: .codex, profile: UUID(), version: "0.154.0"))
    }
    func testProfilesPersistNoObservedTitlesOrIdentities() throws {
        let profile = Profile(source: .codex, alias: "Synthetic", home: "/synthetic")
        let encoded = String(decoding: try JSONEncoder().encode(profile), as: UTF8.self)
        XCTAssertFalse(encoded.contains("title")); XCTAssertFalse(encoded.contains("identity")); XCTAssertFalse(encoded.contains("token"))
        XCTAssertTrue(MonitorStore().agents.isEmpty)
    }
    func testProductionUnixListenerCarriesOnlyProjectedClaudeQuota() throws {
        let root = NSTemporaryDirectory() + UUID().uuidString
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(atPath: root) }
        let profile = UUID(), listener = HookListener(directory: root + "/b")
        let received = expectation(description: "credential-free quota reaches app listener")
        try listener.start { message in
            if case .claudeQuota(let telemetry) = message {
                XCTAssertEqual(telemetry.profile, profile); XCTAssertEqual(telemetry.windows.first?.usedPercent, 23.5)
                received.fulfill()
            } else { XCTFail("Wrong message") }
        }
        defer { listener.stop() }
        let raw = Data(#"{"rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1900000000}},"transcript_path":"private-canary","model":{"display_name":"title-canary"},"prompt":"prompt-canary"}"#.utf8)
        let message = RelayMessage.claudeQuota(try ClaudeQuota.project(raw, profile: profile))
        let encoded = try JSONEncoder().encode(message)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("canary"))
        try UnixRelay.send(encoded, path: root + "/b/events.sock", deadline: DispatchTime.now().uptimeNanoseconds + 150_000_000)
        wait(for: [received], timeout: 2)
        XCTAssertTrue(UnixRelay.validate(root + "/b/events.sock", type: S_IFSOCK, mode: 0o600))
    }
    func testActualBridgeStalledStdinHasNoOutputAndExitsZero() throws {
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let process = Process(), input = Pipe(), output = Pipe(), error = Pipe()
        process.executableURL = repository.appendingPathComponent(".build/debug/relay-bridge")
        process.arguments = ["claude-statusline", UUID().uuidString, "documented"]
        process.standardInput = input; process.standardOutput = output; process.standardError = error
        let start = Date(); try process.run()
        // Keep stdin open without a byte: the deadline must begin before stdin.
        let deadline = Date().addingTimeInterval(2)
        while process.isRunning && Date() < deadline { usleep(1000) }
        if process.isRunning { process.terminate(); XCTFail("Bridge stalled") }
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0); XCTAssertLessThan(Date().timeIntervalSince(start), 1)
        XCTAssertTrue(output.fileHandleForReading.readDataToEndOfFile().isEmpty)
        XCTAssertTrue(error.fileHandleForReading.readDataToEndOfFile().isEmpty)
    }
    func testCrashedListenerRecoversWithoutReplacingActiveOrUnsafeSockets() throws {
        let root = NSTemporaryDirectory() + String(UUID().uuidString.prefix(12))
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(atPath: root) }
        let directory = root + "/bridge", path = directory + "/events.sock"
        _ = try ProcessTransport().run(executable: "/usr/bin/python3", arguments: [Fixtures.directory.appendingPathComponent("crashed-listener.py").path, directory], environment: TransportPolicy.orcaEnvironment(home: NSHomeDirectory(), temporary: NSTemporaryDirectory()))
        XCTAssertTrue(UnixRelay.validate(path, type: S_IFSOCK, mode: 0o600))
        // Unsafe mode on an otherwise stale socket must not be repaired/unlinked.
        XCTAssertEqual(chmod(path, 0o666), 0)
        XCTAssertThrowsError(try HookListener(directory: directory).start { _ in })
        XCTAssertTrue(UnixRelay.validate(path, type: S_IFSOCK, mode: 0o666))
        XCTAssertEqual(chmod(path, 0o600), 0)
        let listener = HookListener(directory: directory)
        let received = expectation(description: "recovered listener receives fresh projected events")
        try listener.start { _ in received.fulfill() }
        defer { listener.stop() }
        var original = stat(); XCTAssertEqual(lstat(path, &original), 0)
        let competitor = HookListener(directory: directory)
        XCTAssertThrowsError(try competitor.start { _ in XCTFail("Must not replace active listener") })
        competitor.stop()
        var retained = stat(); XCTAssertEqual(lstat(path, &retained), 0)
        XCTAssertEqual(original.st_ino, retained.st_ino)
        let message = RelayMessage.hook(HookEvent(source: .codex, profile: UUID(), session: "synthetic", agent: nil, turn: "t", kind: "UserPromptSubmit"))
        try UnixRelay.send(JSONEncoder().encode(message), path: path, deadline: DispatchTime.now().uptimeNanoseconds + 150_000_000)
        wait(for: [received], timeout: 2)
        listener.stop()
        try FileManager.default.createSymbolicLink(atPath: path, withDestinationPath: root)
        XCTAssertThrowsError(try HookListener(directory: directory).start { _ in })
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: path), root)
        try FileManager.default.removeItem(atPath: path)
        // A live same-user endpoint not holding our lock is still never removed.
        let external = socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(external, 0); defer { close(external) }
        var address = try UnixRelay.address(path)
        let bound = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(external, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        XCTAssertEqual(bound, 0); XCTAssertEqual(chmod(path, 0o600), 0); XCTAssertEqual(listen(external, 8), 0)
        var active = stat(); XCTAssertEqual(lstat(path, &active), 0)
        XCTAssertThrowsError(try HookListener(directory: directory).start { _ in })
        var unchanged = stat(); XCTAssertEqual(lstat(path, &unchanged), 0)
        XCTAssertEqual(active.st_ino, unchanged.st_ino)
    }
}
