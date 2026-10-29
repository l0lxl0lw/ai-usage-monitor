import XCTest
import MonitorCore
import SwiftUI
@testable import MonitorPresentation

final class NavigationTests: XCTestCase {
    @MainActor func testProductionViewCompositionUsesLiveServicesAndAllNativeRoutes() {
        let name = "Relay.NavigationTests.\(UUID())", defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let app = AppServices(defaults: defaults, startInfrastructure: false)
        defer { app.shutdown() }
        let account = Account(id: UUID(), source: .codex, alias: "Synthetic navigation")
        let id = AgentID(.codex, account.id, "synthetic", "child")
        app.store.update(account); app.store.upsert(Agent(id: id, account: account.id))
        var closed = false
        let root = PopoverRoot(services: app, close: { closed = true })
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 420, height: 660)
        for route in [Route.agents, .account(account.id), .agent(id), .settings] {
            app.navigation.push(route); _ = root.body; host.layoutSubtreeIfNeeded()
            XCTAssertEqual(app.navigation.route, route)
            XCTAssertTrue(app.navigation.back())
        }
        XCTAssertEqual(app.navigation.route, .usage); XCTAssertFalse(closed)
        XCTAssertTrue(root.services === app)
    }
    func testTreeOrderPlacesParentBeforeAlphabeticallyEarlierGrandchild() {
        var navigation = NavigationState()
        navigation.offsets[.usage] = 320; navigation.offsets[.agents] = 125
        navigation.push(.settings); XCTAssertTrue(navigation.back())
        XCTAssertEqual(navigation.offsets[.usage], 320); XCTAssertEqual(navigation.offsets[.agents], 125)
        let store = MonitorStore(), parent = AgentID(.codex, UUID(), "r", "root")
        let child = AgentID(.codex, parent.profile, "r", "child"), grandchild = AgentID(.codex, parent.profile, "r", "grandchild")
        store.upsert(Agent(id: parent, title: "Root"))
        store.upsert(Agent(id: child, title: "Z child", parent: parent))
        store.upsert(Agent(id: grandchild, title: "A grandchild", parent: child))
        XCTAssertEqual(store.orderedAgents().map(\.id), [parent, child, grandchild])
    }
    func testNestedCrosslinksBackstackFiltersAndScrollRestoration() {
        var nav = NavigationState(); let account = UUID(), agent = AgentID(.codex,account,"r","synthetic")
        nav.query = "needle"; nav.state = .waiting; nav.scroll[.usage] = "account-two"
        nav.push(.account(account)); nav.scroll[.account(account)] = "agent-three"
        nav.push(.agent(agent)); nav.push(.account(account))
        XCTAssertTrue(nav.back()); XCTAssertEqual(nav.route, .agent(agent))
        XCTAssertTrue(nav.back()); XCTAssertEqual(nav.scroll[nav.route], "agent-three")
        XCTAssertTrue(nav.back()); XCTAssertEqual(nav.scroll[nav.route], "account-two")
        XCTAssertEqual(nav.query, "needle"); XCTAssertEqual(nav.state, .waiting); XCTAssertFalse(nav.back())
    }
    func testCollapseAndTabPreserveIndependentScroll() {
        var nav = NavigationState(); let id = AgentID(.codex,UUID(),"r","a")
        nav.toggle(id); XCTAssertTrue(nav.collapsed.contains(id)); nav.toggle(id); XCTAssertFalse(nav.collapsed.contains(id))
        nav.scroll[.agents] = "third"; nav.push(.settings); nav.tab(.agents)
        XCTAssertTrue(nav.stack.isEmpty); XCTAssertEqual(nav.scroll[.agents], "third")
    }
}
