import XCTest
import MonitorCore
import MonitorAdapters

final class CoreTests: XCTestCase {
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
