import XCTest
import MonitorCore
import MonitorAdapters

final class AdapterTests: XCTestCase {
    func testPinnedRawHookProjectionAndMembership() throws {
        let profile = UUID(), store = MonitorStore()
        let bytes = Data(#"{"hook_event_name":"SubagentStart","session_id":"synthetic-session","turn_id":"t1","agent_id":"child","agent_type":"worker","model":"synthetic","cwd":"/private-canary","transcript_path":"secret-canary","prompt":"prompt-canary"}"#.utf8)
        let event = try HookProjection.project(bytes, source: .codex, profile: profile, version: "0.154.0")
        HookProjection.apply(event, store: store, runtime: "r")
        let value = try XCTUnwrap(store.agents.values.first)
        XCTAssertNil(value.parent); XCTAssertNotNil(value.memberOf); XCTAssertEqual(value.activity, .working)
        let encoded = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
        XCTAssertFalse(encoded.contains("canary")); XCTAssertThrowsError(try HookProjection.project(bytes, source: .codex, profile: profile, version: "future"))
        // Concurrent profiles and siblings/grandchildren cannot fabricate immediate edges.
        for source in [Source.codex, .claude] {
            for p in [profile, UUID()] {
                for agent in ["child", "sibling", "grandchild"] {
                    let event = try HookProjection.project(JSONSerialization.data(withJSONObject: ["hook_event_name": "SubagentStart", "session_id": "synthetic-session", "agent_id": agent]), source: source, profile: p, version: source == .codex ? "0.154.0" : "documented")
                    HookProjection.apply(event, store: store, runtime: "r")
                }
            }
        }
        XCTAssertEqual(store.agents.count, 12)
        XCTAssertTrue(store.agents.values.allSatisfy { $0.parent == nil && $0.memberOf != nil })
        XCTAssertThrowsError(try HookProjection.project(Data(#"{"hook_event_name":"SubagentStart","session_id":"s"}"#.utf8), source: .claude, profile: profile, version: "documented"))
    }
    func testContinuationsUnmatchedStopsAndRepeatedStarts() throws {
        let p = UUID(), store = MonitorStore(), now = Date()
        func apply(_ kind: String, _ turn: String?, _ offset: Double, _ active: Bool = false) {
            HookProjection.apply(HookEvent(source: .codex, profile: p, session: "s", agent: nil, turn: turn, kind: kind, stopActive: active, received: now.addingTimeInterval(offset)), store: store, runtime: "r")
        }
        apply("UserPromptSubmit", "new", 0); apply("Stop", "old", 1)
        XCTAssertEqual(store.agents.values.first?.activity, .unknown)
        apply("UserPromptSubmit", "new", 2); apply("Stop", "new", 3, true)
        XCTAssertNotEqual(store.agents.values.first?.activity, .stopped)
        apply("UserPromptSubmit", "new", 4); apply("Interrupt", "new", 5)
        XCTAssertEqual(store.agents.values.first?.activity, .interrupted)
        apply("UserPromptSubmit", "newer", 6); XCTAssertEqual(store.agents.values.first?.activity, .working)
    }
    func testOpenCodePageActualEnvelopeAndNoBillingInference() throws {
        let p = UUID(), rows: [String: Any] = ["data": [["id": "ses-child", "title": "Synthetic title", "parentID": "ses-parent", "model": ["providerID": "codex"], "projectID": "proj-test", "prompt": "secret"]], "cursor": ["next": NSNull()]]
        let (agents, cursor) = try OpenCodeProjection.page(rows, profile: p, runtime: "r", active: ["ses-child"])
        XCTAssertNil(cursor); XCTAssertEqual(agents[0].activity, .working); XCTAssertNil(agents[0].account)
        XCTAssertEqual(agents[0].parent?.local, "ses-parent"); XCTAssertEqual(agents[0].title, "Synthetic title")
        XCTAssertThrowsError(try OpenCodeProjection.page(["data": [], "cursor": ["next": 3]], profile: p, runtime: "r", active: []))
    }
    func testChildStopsRequireCurrentTurnAndNoContinuation() throws {
        for source in [Source.codex, .claude] {
            let profile = UUID(), store = MonitorStore(), now = Date()
            let child = AgentID(source, profile, "r", "s:child")
            func apply(_ kind: String, _ turn: String?, _ offset: Double, _ active: Bool = false, agent: String = "child") {
                HookProjection.apply(HookEvent(source: source, profile: profile, session: "s", agent: agent, turn: turn, kind: kind, stopActive: active, received: now.addingTimeInterval(offset)), store: store, runtime: "r")
            }
            apply("SubagentStart", "old", 0)
            apply("SubagentStop", "old", 1)
            XCTAssertEqual(store.agents[child]?.activity, .stopped)
            apply("SubagentStart", "new", 2)
            apply("SubagentStop", "old", 3) // received later, belongs to older turn
            XCTAssertEqual(store.agents[child]?.activity, .working)
            apply("SubagentStop", "new", 4, true)
            XCTAssertEqual(store.agents[child]?.activity, .working)
            apply("SubagentStop", nil, 5)
            XCTAssertEqual(store.agents[child]?.activity, .working)
            apply("SubagentStop", "new", 6)
            XCTAssertEqual(store.agents[child]?.activity, .stopped)
            apply("SubagentStart", "newer", 7)
            apply("SubagentStop", "new", 6.5) // receive timestamp disorder too
            XCTAssertEqual(store.agents[child]?.activity, .working)
            apply("SubagentStop", "unknown", 8, agent: "unmatched")
            XCTAssertEqual(store.agents[AgentID(source, profile, "r", "s:unmatched")]?.activity, .unknown)
            XCTAssertNil(store.agents[AgentID(source, profile, "r", "s")])
        }
    }
    func testProductionCodexSnapshotIdentityChangeWithSameEmail() throws {
        let executable = try Fixtures.helper(); defer { try? FileManager.default.removeItem(at: executable) }
        let source = try String(contentsOf: executable, encoding: .utf8)
        let registry = try ProfileRegistry(), profile = Profile(source: .codex, alias: "Synthetic", home: "/synthetic/identity")
        try registry.add(profile)
        for account in ["account-A", "account-A", "account-B"] {
            try source.replacingOccurrences(of: "result = {'rateLimits':", with: "result = {'accountId': '\(account)', 'rateLimits':").write(to: executable, atomically: false, encoding: .utf8)
            let rpc = try CodexRPC(executable: executable.path, home: profile.home)
            let quota = try rpc.read(); rpc.stop(); XCTAssertTrue(rpc.reaped)
            XCTAssertEqual(quota.identity, "chatgpt-account:\(account)")
            if account == "account-B" { XCTAssertThrowsError(try registry.checkIdentity(quota.identity, profile: profile.id)) }
            else { XCTAssertNoThrow(try registry.checkIdentity(quota.identity, profile: profile.id)) }
        }
        // Explicit absence may fall back to official account metadata, but cannot
        // silently replace a previously observed backend account association.
        try source.write(to: executable, atomically: false, encoding: .utf8)
        let rpc = try CodexRPC(executable: executable.path, home: profile.home)
        defer { rpc.stop() }
        XCTAssertThrowsError(try registry.checkIdentity(rpc.read().identity, profile: profile.id))
    }
    @MainActor func testApplicationConnectionReplacementRestartAndCleanupFailure() async throws {
        let fixture = try HTTPFixture(), vault = MemoryVault()
        let owner = OpenCodeConnection(vault: vault)
        try owner.disconnect() // same startup cleanup used by AppServices
        try await owner.pair(link: fixture.base + "/auth/connect/synthetic-code")
        let first = try XCTUnwrap(owner.adapter)
        XCTAssertEqual(vault.tokens.count, 1)
        try await owner.pair(link: fixture.base + "/auth/connect/synthetic-code")
        let second = try XCTUnwrap(owner.adapter)
        XCTAssertFalse(first === second); XCTAssertNil(vault.tokens[first.profile])
        XCTAssertEqual(Set(vault.tokens.keys), [second.profile])
        // Simulate process loss, including UUIDs from the earlier implementation.
        vault.tokens[UUID()] = "synthetic-legacy-token"
        let restarted = OpenCodeConnection(vault: vault)
        XCTAssertNil(restarted.adapter)
        vault.denied = true
        XCTAssertThrowsError(try restarted.disconnect())
        XCTAssertEqual(vault.tokens.count, 2)
        do { try await restarted.pair(link: fixture.base + "/auth/connect/synthetic-code"); XCTFail("Cannot pair over failed cleanup") } catch {}
        XCTAssertEqual(vault.tokens.count, 2)
        vault.denied = false
        try restarted.disconnect(); XCTAssertTrue(vault.tokens.isEmpty)
        try await restarted.pair(link: fixture.base + "/auth/connect/synthetic-code")
        vault.denied = true
        XCTAssertThrowsError(try restarted.disconnect())
        XCTAssertNotNil(restarted.adapter); XCTAssertEqual(vault.tokens.count, 1)
        vault.denied = false
        try restarted.disconnect(); XCTAssertNil(restarted.adapter); XCTAssertTrue(vault.tokens.isEmpty)
        XCTAssertTrue(fixture.process.isRunning) // no server-side revocation or stop
    }
    @MainActor func testApplicationCancelledPairCannotOrphanOrDeleteNewToken() async throws {
        let slow = try HTTPFixture("slowpair"), normal = try HTTPFixture(), vault = MemoryVault()
        let owner = OpenCodeConnection(vault: vault)
        let old = Task { try await owner.pair(link: slow.base + "/auth/connect/synthetic-code") }
        try await Task.sleep(for: .milliseconds(100))
        try owner.disconnect(); old.cancel()
        try await owner.pair(link: normal.base + "/auth/connect/synthetic-code")
        let current = try XCTUnwrap(owner.adapter)
        do { try await old.value; XCTFail("Cancelled pair cannot publish") } catch {}
        XCTAssertTrue(owner.adapter === current)
        XCTAssertEqual(Set(vault.tokens.keys), [current.profile])
        try owner.disconnect(); XCTAssertTrue(vault.tokens.isEmpty)
    }
    func testOrcaKnownMetadataKeepsNamespacesAndPartialCoverage() throws {
        let wire = Data(#"{"ok":true,"result":{"worktrees":[{"worktreeId":"w","hostId":"h","worktreeInstanceId":"i","parentWorktreeId":"not-an-agent-parent","agents":[{"paneKey":"p","parentPaneKey":"unverified","state":"idle","displayName":"Synthetic worker","prompt":"secret-canary"}]}],"truncated":true,"hostScope":{"hostIds":["h"],"omittedHostIds":["missing"]}},"_meta":{"runtimeId":"r"}}"#.utf8)
        let snapshot = try OrcaSnapshot.decode(wire, profile: UUID())
        XCTAssertEqual(snapshot.coverage, .partial); XCTAssertEqual(snapshot.omittedHosts, 1)
        XCTAssertEqual(snapshot.agents.count, 1); XCTAssertNil(snapshot.agents[0].parent)
        XCTAssertTrue(snapshot.agents[0].id.runtime.contains("r:h:i")); XCTAssertEqual(snapshot.agents[0].activity, .idle)
    }
    func testActualProcessLauncherEnvironmentAndTimeout() throws {
        let env = TransportPolicy.orcaEnvironment(home: "/synthetic", temporary: NSTemporaryDirectory())
        let data = try ProcessTransport().run(executable: "/usr/bin/env", arguments: [], environment: env)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("HOME=/synthetic")); XCTAssertFalse(text.contains("ORCA_"))
        XCTAssertThrowsError(try ProcessTransport().run(executable: "/bin/sleep", arguments: ["5"], environment: env, timeout: 0.02))
        let helper = try Fixtures.helper(); defer { try? FileManager.default.removeItem(at: helper) }
        let start = Date()
        XCTAssertThrowsError(try ProcessTransport().run(executable: helper.path, arguments: ["hang-after-eof"], environment: env, timeout: 0.1))
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
    }
    func testProductionCodexRPCHandshakeAndOwnedHelperTermination() throws {
        let executable = try Fixtures.helper(); defer { try? FileManager.default.removeItem(at: executable) }
        let client = try CodexRPC(executable: executable.path, home: "/synthetic/profile-a")
        let quota = try client.read()
        XCTAssertEqual(quota.identity, "chatgpt:synthetic@example.invalid")
        XCTAssertEqual(quota.windows.first?.usedPercent, 12.25)
        XCTAssertEqual(quota.windows.first?.durationSeconds, 18000)
        client.stop(); XCTAssertTrue(client.reaped)
        let source = try String(contentsOf: executable, encoding: .utf8)
        try source.replacingOccurrences(of: "codex-cli 0.154.0", with: "codex-cli 99.0.0").write(to: executable, atomically: false, encoding: .utf8)
        do { _ = try CodexRPC(executable: executable.path, home: "/synthetic/profile-a"); XCTFail("Unsupported version must not collect") }
        catch TransportError.unsupported {} catch { XCTFail("Wrong version failure: \(error)") }
    }
    func testProductionOrcaRunAndEmptyWorkerObservationWithPoisonedEnvironment() throws {
        let executable = try Fixtures.helper(); defer { try? FileManager.default.removeItem(at: executable) }
        setenv("ORCA_ENVIRONMENT", "must-not-inherit", 1); setenv("ORCA_PAIRING_CODE", "must-not-inherit", 1)
        defer { unsetenv("ORCA_ENVIRONMENT"); unsetenv("ORCA_PAIRING_CODE") }
        let result = try OrcaAdapter().read(executable: executable.path, profile: UUID())
        XCTAssertEqual(result.runCount, 1); XCTAssertEqual(result.workerCoverage, .empty); XCTAssertEqual(result.coverage, .partial)
        XCTAssertTrue(result.agents.isEmpty)
        XCTAssertFalse(try OrcaAdapter.emptyWorkers(["workers": [["unknown": "private-canary"]], "page": ["hasMore": false, "total": 1], "scope": ["source": "flag"]]))
    }
    func testProductionHTTPPairPaginationSSEAndLocalDisconnect() async throws {
        let fixture = try HTTPFixture(), vault = MemoryVault(), profile = UUID()
        let adapter = try OpenCodeAdapter(base: fixture.base, profile: profile, keychain: vault)
        try await adapter.pair(link: fixture.base + "/auth/connect/synthetic-code")
        let result = try await adapter.reconcile()
        XCTAssertEqual(result.agents.count, 2); XCTAssertEqual(result.coverage, .observed)
        XCTAssertEqual(result.agents.first(where: { $0.id.local == "ses-child" })?.parent?.local, "ses-parent")
        let invalidated = expectation(description: "SSE invalidates, never projects content")
        do { try await adapter.events { invalidated.fulfill() }; XCTFail("EOF must pause observation") } catch {}
        await fulfillment(of: [invalidated], timeout: 2)
        let generation = adapter.generation
        try adapter.disconnect(); XCTAssertTrue(vault.tokens.isEmpty); XCTAssertNotEqual(adapter.generation, generation)
        // The fixture server remains running: disconnect is local, not a service action.
        XCTAssertTrue(fixture.process.isRunning)
    }
    func testProductionHTTPRepeatedCursorAndLaterPageFailureArePartial() async throws {
        for mode in ["loop", "laterfail"] {
            let fixture = try HTTPFixture(mode), vault = MemoryVault()
            let adapter = try OpenCodeAdapter(base: fixture.base, profile: UUID(), keychain: vault)
            try await adapter.pair(link: fixture.base + "/auth/connect/synthetic-code")
            let result = try await adapter.reconcile()
            XCTAssertEqual(result.coverage, .partial); XCTAssertFalse(result.agents.isEmpty)
            try adapter.disconnect()
        }
    }
    func testProductionHTTPRedirectAuthenticationThrottlingAndDeniedVault() async throws {
        for mode in ["redirect", "401", "429"] {
            let fixture = try HTTPFixture(mode)
            do {
                _ = try await LocalHTTP().get(URL(string: fixture.base + "/api/info")!)
                XCTFail("Must reject \(mode)")
            } catch TransportError.throttled(let retry) { XCTAssertEqual(retry, 600) }
            catch TransportError.authentication { XCTAssertEqual(mode, "401") }
            catch { XCTAssertEqual(mode, "redirect") }
        }
        let fixture = try HTTPFixture(), vault = MemoryVault(); vault.denied = true
        let adapter = try OpenCodeAdapter(base: fixture.base, profile: UUID(), keychain: vault)
        do { try await adapter.pair(link: fixture.base + "/auth/connect/synthetic-code"); XCTFail("Denied Keychain must fail") } catch {}
        XCTAssertTrue(vault.tokens.isEmpty)
        let oldService = try HTTPFixture("unsupported"), oldVault = MemoryVault()
        let oldAdapter = try OpenCodeAdapter(base: oldService.base, profile: UUID(), keychain: oldVault)
        try await oldAdapter.pair(link: oldService.base + "/auth/connect/synthetic-code")
        do { _ = try await oldAdapter.reconcile(); XCTFail("V1 cannot be observed as V2") }
        catch TransportError.unsupported {} catch { XCTFail("Wrong version failure") }
        try oldAdapter.disconnect()
    }
    func testProductionHTTPCancellationRejectsLateSnapshot() async throws {
        let fixture = try HTTPFixture("slow"), vault = MemoryVault()
        let adapter = try OpenCodeAdapter(base: fixture.base, profile: UUID(), keychain: vault)
        try await adapter.pair(link: fixture.base + "/auth/connect/synthetic-code")
        let job = Task { try await adapter.reconcile() }
        try await Task.sleep(for: .milliseconds(100))
        try adapter.disconnect(); job.cancel()
        do { _ = try await job.value; XCTFail("Disconnected generation cannot publish") } catch {}
        XCTAssertTrue(vault.tokens.isEmpty)
    }
}
