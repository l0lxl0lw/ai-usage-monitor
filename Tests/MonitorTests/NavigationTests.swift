import XCTest
import MonitorCore

final class NavigationTests: XCTestCase {
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
