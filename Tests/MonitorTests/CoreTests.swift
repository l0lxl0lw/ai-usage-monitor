import XCTest
import MonitorCore
import MonitorAdapters
@testable import MonitorPresentation

private actor StartupReads {
    private var pending: [UUID: [CheckedContinuation<CodexQuota, Error>]] = [:]
    private var calls: [UUID: Int] = [:]
    func read(_ profile: Profile) async throws -> CodexQuota {
        calls[profile.id, default: 0] += 1
        return try await withCheckedThrowingContinuation { pending[profile.id, default: []].append($0) }
    }
    func count(_ id: UUID) -> Int { calls[id, default: 0] }
    func finish(_ id: UUID, identity: String = "synthetic-A", error: Error? = nil) throws {
        let continuation = pending[id]!.removeFirst()
        if let error { continuation.resume(throwing: error) }
        else { continuation.resume(returning: try CodexQuota.decode(Data("{\"accountId\":\"\(identity)\",\"rateLimits\":{\"primary\":{\"usedPercent\":12.5}}}".utf8))) }
    }
}

final class CoreTests: XCTestCase {
    @MainActor private func preferences(_ profiles: [Profile]? = nil) throws -> UserDefaults {
        let name = "Relay.StartupTests.\(UUID())", defaults = UserDefaults(suiteName: name)!
        if let profiles { defaults.set(try JSONEncoder().encode(profiles), forKey: "Relay.profiles") }
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
    @MainActor private func settle() async { for _ in 0..<100 { await Task.yield() }; try? await Task.sleep(for: .milliseconds(20)) }

    @MainActor func testProductionStartupEmptyAndMalformedPreferencesNeverDiscoverLogins() async throws {
        for malformed in [false, true] {
            let defaults = try preferences(), reads = StartupReads()
            if malformed { defaults.set(Data("invalid".utf8), forKey: "Relay.profiles") }
            let app = AppServices(defaults: defaults, startInfrastructure: false, quotaRead: { try await reads.read($0) })
            await settle()
            XCTAssertTrue(app.profiles.isEmpty); XCTAssertTrue(app.store.accounts.isEmpty); XCTAssertTrue(app.store.agents.isEmpty)
            XCTAssertTrue(app.store.sourceCoverage.isEmpty); XCTAssertEqual(app.navigation.route, .usage)
            app.shutdown()
        }
    }
    @MainActor func testProductionStartupRestoresOnlyValidSavedProfilesAndReadsCodexOnce() async throws {
        let a = Profile(source: .codex, alias: "A", home: "/synthetic/a")
        let b = Profile(source: .codex, alias: "B", home: "/synthetic/b")
        let c = Profile(source: .claude, alias: "C", home: "/synthetic/a")
        let invalid = [a, a, Profile(source: .codex, alias: "Collision", home: "/synthetic/x/../a"),
                       Profile(source: .orca, alias: "Unsupported", home: "/synthetic/o"),
                       Profile(source: .claude, alias: "", home: "/synthetic/empty"),
                       Profile(source: .codex, alias: "Relative", home: "relative"), b, c]
        let defaults = try preferences(invalid), reads = StartupReads()
        let app = AppServices(defaults: defaults, startInfrastructure: false, quotaRead: { try await reads.read($0) })
        XCTAssertEqual(app.profiles, [a,b,c]); XCTAssertEqual(app.store.accounts.count, 3)
        app.refreshDue(); app.refresh(a); app.refresh(c)
        await settle()
        let counts = await [reads.count(a.id), reads.count(b.id), reads.count(c.id)]
        XCTAssertEqual(counts, [1,1,0])
        try await reads.finish(a.id); try await reads.finish(b.id)
        await settle()
        XCTAssertEqual(app.store.accounts[a.id]?.windows.first?.usedPercent, 12.5)
        XCTAssertEqual(app.store.accounts[b.id]?.coverage, .observed)
        XCTAssertEqual(app.store.accounts[c.id]?.coverage, .missing)
        XCTAssertTrue(app.store.agents.isEmpty)
        // Restore does not rewrite the user's saved data or recover observations.
        XCTAssertEqual(try JSONDecoder().decode([Profile].self, from: defaults.data(forKey: "Relay.profiles")!), invalid)
        app.shutdown()
    }
    @MainActor func testProductionStartupIndependentBackoffIdentityAndNoFallback() async throws {
        let a = Profile(source: .codex, alias: "A", home: "/synthetic/a"), b = Profile(source: .codex, alias: "B", home: "/synthetic/b")
        let defaults = try preferences([a,b]), reads = StartupReads()
        var clock = Date(timeIntervalSince1970: 1000)
        let app = AppServices(defaults: defaults, startInfrastructure: false, now: { clock }, quotaRead: { try await reads.read($0) })
        await settle()
        try await reads.finish(a.id, error: TransportError.throttled(999999)); try await reads.finish(b.id)
        await settle()
        XCTAssertTrue(app.store.accounts[a.id]!.windows.isEmpty)
        XCTAssertEqual(app.store.accounts[b.id]?.coverage, .observed)
        clock.addTimeInterval(61); app.refreshDue(); await settle()
        var counts = await [reads.count(a.id), reads.count(b.id)]
        XCTAssertEqual(counts, [1,2])
        try await reads.finish(b.id, identity: "synthetic-changed"); await settle()
        XCTAssertEqual(app.store.accounts[b.id]?.coverage, .stale)
        XCTAssertEqual(app.store.accounts[b.id]?.observedAt, Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(app.store.accounts[b.id]?.windows.first?.usedPercent, 12.5)
        clock.addTimeInterval(3600); app.refreshDue(); await settle()
        counts = await [reads.count(a.id), reads.count(b.id)]
        XCTAssertEqual(counts, [2,3]) // huge retry hint was bounded, per-profile schedule independent
        try await reads.finish(a.id); try await reads.finish(b.id, error: TransportError.unsupported)
        await settle()
        XCTAssertEqual(app.store.accounts[a.id]?.coverage, .observed)
        XCTAssertEqual(app.store.accounts[b.id]?.coverage, .unsupported)
        XCTAssertTrue(app.store.agents.isEmpty)
        app.shutdown()
        let restarted = AppServices(defaults: defaults, startInfrastructure: false, quotaRead: { _ in throw TransportError.denied })
        await settle()
        XCTAssertTrue(restarted.store.accounts.values.allSatisfy { $0.windows.isEmpty && $0.observedAt == nil })
        XCTAssertTrue(restarted.store.agents.isEmpty); restarted.shutdown()
    }
    @MainActor func testProductionStartupCancellationRejectsLateReadWithoutAffectingOtherProfile() async throws {
        let a = Profile(source: .codex, alias: "A", home: "/synthetic/a"), b = Profile(source: .codex, alias: "B", home: "/synthetic/b")
        let reads = StartupReads(), app = AppServices(defaults: try preferences([a,b]), startInfrastructure: false, quotaRead: { try await reads.read($0) })
        await settle(); app.cancel(a)
        try await reads.finish(a.id); try await reads.finish(b.id); await settle()
        XCTAssertTrue(app.store.accounts[a.id]!.windows.isEmpty)
        XCTAssertEqual(app.store.accounts[b.id]?.coverage, .observed)
        app.refresh(a); app.refreshDue(); await settle()
        let counts = await [reads.count(a.id), reads.count(b.id)]
        XCTAssertEqual(counts, [2,1])
        try await reads.finish(a.id); await settle()
        XCTAssertEqual(app.store.accounts[a.id]?.coverage, .observed); app.shutdown()
    }
    func testMissingSnapshotAndMeasurementAgeDoNotInventSuccess() throws {
        let store = MonitorStore(), p = UUID(), id = AgentID(.orca, p, "runtime", "local")
        store.upsert(Agent(id: id, activity: .working))
        store.reconcile([], source: .orca, profile: p)
        XCTAssertEqual(store.agents[id]?.activity, .unknown)
        var account = Account(id: p, source: .claude, alias: "Synthetic")
        account.windows = [try QuotaWindow(label: "Weekly", usedPercent: 50)]
        account.coverage = .observed; account.observedAt = Date(timeIntervalSince1970: 1)
        store.update(account); store.expireMeasurements(before: Date())
        XCTAssertEqual(store.accounts[p]?.coverage, .stale); XCTAssertEqual(store.accounts[p]?.windows.first?.usedPercent, 50)
    }
    func testNamespacesAndNoTitleDeduplication() {
        let store = MonitorStore(), profile = UUID()
        for source in Source.allCases { store.upsert(Agent(id: AgentID(source, profile, "runtime", "same"), title: "Same title", project: "same")) }
        XCTAssertEqual(store.agents.count, 4)
    }
    func testDuplicateDisorderAndGeneration() {
        let store = MonitorStore(), profile = UUID(), event = UUID(), now = Date()
        let id = AgentID(.codex, profile, "r", "one"), generation = store.restart(profile)
        store.upsert(Agent(id: id, activity: .working, observedAt: now), generation: generation, event: event)
        store.upsert(Agent(id: id, activity: .stopped, observedAt: now.addingTimeInterval(10)), generation: generation, event: event)
        store.upsert(Agent(id: id, activity: .idle, observedAt: now.addingTimeInterval(-10)), generation: generation)
        XCTAssertEqual(store.agents[id]?.activity, .working)
        _ = store.restart(profile)
        store.upsert(Agent(id: id), generation: generation)
        XCTAssertTrue(store.agents.isEmpty)
    }
    func testCycleAndCrossNamespaceParentsRejected() {
        let store = MonitorStore(), p = UUID()
        let a = AgentID(.codex,p,"r","a"), b = AgentID(.codex,p,"r","b")
        store.upsert(Agent(id: a, parent: b)); store.upsert(Agent(id: b, parent: a))
        XCTAssertNil(store.agents[b]?.parent)
        store.upsert(Agent(id: a, parent: AgentID(.claude,p,"r","a")))
        XCTAssertNil(store.agents[a]?.parent)
    }
    func testLiveFailureAndRestartHaveNoDemoFallback() {
        let live = MonitorStore(), demo = MonitorStore(), p = UUID()
        demo.upsert(Agent(id: AgentID(.codex,p,"demo","one"), title: "Demo only"))
        var account = Account(id: p, source: .codex, alias: "Test")
        account.windows = [try! QuotaWindow(label: "Weekly", usedPercent: 12)]; account.observedAt = Date()
        live.update(account); live.markFailure(p)
        XCTAssertEqual(live.accounts[p]?.coverage, .stale)
        XCTAssertEqual(live.accounts[p]?.windows.first?.usedPercent, 12)
        XCTAssertTrue(live.agents.isEmpty); XCTAssertTrue(MonitorStore().accounts.isEmpty)
    }
    func testFilteredCountsExcludeAncestors() {
        let store = MonitorStore(), p = UUID(), root = AgentID(.codex,UUID(),"r","a")
        let child = AgentID(.codex,root.profile,"r","b")
        store.upsert(Agent(id: root, title: "Coordinator", activity: .working))
        store.upsert(Agent(id: child, title: "Needle", activity: .waiting, parent: root))
        let result = store.filtered(query: "needle", project: nil, state: .waiting)
        XCTAssertEqual(result.matches, [child]); XCTAssertEqual(result.context, [root,child]); XCTAssertNotEqual(p, root.profile)
    }
    func testProfilesCanonicalHomesAndIdentityChanges() throws {
        let p = Profile(source: .codex, alias: "A", home: "/synthetic/home")
        let registry = try ProfileRegistry([p])
        XCTAssertThrowsError(try registry.add(Profile(source: .codex, alias: "B", home: "/synthetic/other/../home")))
        try registry.add(Profile(source: .claude, alias: "B", home: "/synthetic/home"))
        try registry.checkIdentity("synthetic-account-A", profile: p.id)
        XCTAssertThrowsError(try registry.checkIdentity("synthetic-account-B", profile: p.id))
        XCTAssertThrowsError(try registry.checkIdentity(nil, profile: p.id))
    }
}
