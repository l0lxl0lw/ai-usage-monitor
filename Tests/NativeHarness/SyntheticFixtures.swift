import Foundation
import MonitorCore

enum SyntheticFixtures {
    static func populate(_ store: MonitorStore) {
        let claude = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let codex = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let claudeWork = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let codexPersonal = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        for (id, source, alias, values) in [(claude, Source.claude, "Personal", [72.0,48]), (codex,.codex,"Work",[21]), (claudeWork,.claude,"Work",[91,67]), (codexPersonal,.codex,"Personal",[38,64])] {
            var account = Account(id: id, source: source, alias: alias)
            account.windows = values.enumerated().map { index, value in try! QuotaWindow(label: values.count == 1 || index == 1 ? "Weekly" : "5-hour", usedPercent: value, resetsAt: Date().addingTimeInterval(5040)) }
            account.observedAt = Date().addingTimeInterval(id == claudeWork ? -720 : -18)
            account.coverage = id == claudeWork ? .stale : .observed
            account.note = "Synthetic frozen sample · not a real account"
            store.update(account)
        }
        let root = AgentID(.codex, codex, "synthetic", "root"), child = AgentID(.codex, codex, "synthetic", "shell")
        let nodes = [
            Agent(id: root, title: "Build menu-bar monitor", project: "ai-usage-monitor", activity: .working, account: codex, events: ["Synthetic session started"]),
            Agent(id: child, title: "Menu-bar shell", project: "ai-usage-monitor", activity: .working, parent: root, relationship: "Synthetic reported parent", account: codex),
            Agent(id: AgentID(.codex,codex,"synthetic","review"), title: "Privacy & permissions", project: "ai-usage-monitor", activity: .waiting, parent: root, relationship: "Synthetic reported parent", account: codex),
            Agent(id: AgentID(.codex,codex,"synthetic","test"), title: "Keyboard regression checks", project: "ai-usage-monitor", activity: .stopped, parent: child, relationship: "Synthetic reported parent", account: codex),
            Agent(id: AgentID(.claude,claudeWork,"synthetic","docs"), title: "Repair mobile navigation", project: "docs-site", activity: .idle, account: claudeWork),
            Agent(id: AgentID(.claude,claudeWork,"synthetic","docs-test"), title: "Browser regression checks", project: "docs-site", activity: .stopped, memberOf: AgentID(.claude,claudeWork,"synthetic","docs"), relationship: "Synthetic session membership · immediate parent unknown"),
            Agent(id: AgentID(.opencode,claude,"synthetic","provider"), title: "Provider adapters", project: "ai-usage-monitor", activity: .working),
            Agent(id: AgentID(.orca,claude,"synthetic","orchestrator"), title: "Documentation review", project: "release-cli", activity: .unknown)
        ]
        nodes.forEach { store.upsert($0) }
    }
}
