import SwiftUI
import AppKit
import MonitorCore

struct PopoverRoot: View {
    @ObservedObject var services: AppServices
    let close: () -> Void
    @FocusState private var focused: Bool
    private var nav: Binding<NavigationState> { $services.navigation }
    private var agents: [Agent] { services.store.orderedAgents() }
    private var accounts: [Account] { services.store.accounts.values.sorted { "\($0.source)\($0.alias)" < "\($1.source)\($1.alias)" } }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                if !services.navigation.stack.isEmpty {
                    Button { _ = services.navigation.back() } label: { Image(systemName: "chevron.left") }.help("Back").accessibilityLabel("Back")
                } else { Image(systemName: "circle.hexagongrid.fill").foregroundStyle(.teal) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text("Local observations · coverage may be partial").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button { services.navigation.push(.settings) } label: { Image(systemName: "gearshape") }.accessibilityLabel("Connections and settings")
            }.padding(16)
            if services.navigation.route == .usage || services.navigation.route == .agents {
                HStack {
                    Button("Usage") { services.navigation.tab(.usage) }.buttonStyle(.borderedProminent).tint(services.navigation.route == .usage ? .teal : .gray)
                    Button("Agents · \(agents.count)") { services.navigation.tab(.agents) }.buttonStyle(.borderedProminent).tint(services.navigation.route == .agents ? .teal : .gray)
                    Spacer()
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    switch services.navigation.route {
                    case .usage: usage
                    case .agents: agentList
                    case .account(let id): if let account = services.store.accounts[id] { accountDetail(account) } else { Text("Account unavailable") }
                    case .agent(let id): if let agent = services.store.agents[id] { agentDetail(agent) } else { Text("Observation unavailable") }
                    case .settings: SettingsViews(services: services)
                    }
                }.padding(16)
                .background(ScrollMemory(route: services.navigation.route, offsets: $services.navigation.offsets))
            }
            .onChange(of: services.navigation.route) { _, _ in focused = true }
            Divider()
            HStack {
                Circle().fill(.teal).frame(width: 6, height: 6)
                Text("Live · observed, not complete history").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("Close", action: close).font(.caption2)
            }.padding(12)
        }
        .frame(width: 420).frame(maxHeight: .infinity)
        .background(.background)
        .focusable().focused($focused)
        .onAppear { focused = true }
        .onExitCommand { if !services.navigation.back() { close() } }
    }
    private var title: String {
        switch services.navigation.route {
        case .usage, .agents: return "Relay"
        case .settings: return "Settings"
        case .account(let id): return services.store.accounts[id].map { "\($0.source.rawValue.capitalized) / \($0.alias)" } ?? "Account"
        case .agent(let id): return services.store.agents[id]?.displayTitle ?? "Agent"
        }
    }
    private var usage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(accounts.count) accounts · percent used").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("View agents →") { services.navigation.tab(.agents) }.font(.caption)
            }
            if accounts.isEmpty { Text("No configured profiles. Add an existing account in Connections & settings. No login or service is started.").foregroundStyle(.secondary) }
            ForEach(accounts) { account in
                VStack(alignment: .leading, spacing: 12) {
                    Button { services.navigation.push(.account(account.id)) } label: {
                        HStack { Text("\(account.source.rawValue.capitalized) / \(account.alias)").fontWeight(.semibold); Spacer(); Image(systemName: "chevron.right") }
                    }.buttonStyle(.plain)
                    quota(account)
                }.padding(14).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12)).id(account.id.uuidString)
            }
            Button("Connections & settings →") { services.navigation.push(.settings) }
            Text("Usage is account-wide, not per agent. Missing windows are not zero or unlimited.").font(.caption).foregroundStyle(.secondary)
        }.scrollTargetLayout()
    }
    @ViewBuilder private func quota(_ account: Account) -> some View {
        if account.windows.isEmpty { Text("Quota unavailable · \(account.coverage.rawValue)").foregroundStyle(.secondary) }
        ForEach(Array(account.windows.enumerated()), id: \.offset) { _, window in
            VStack(alignment: .leading, spacing: 5) {
                HStack { Text(window.label); Spacer(); Text("\(window.usedPercent.formatted())%").fontWeight(.semibold) }.font(.caption)
                ProgressView(value: window.usedPercent, total: 100).tint(window.usedPercent >= 85 ? .orange : .teal)
                    .accessibilityLabel("\(window.label) percent used")
                Text(window.resetDescription()).font(.caption2).foregroundStyle(.secondary)
            }
        }
        if let credits = account.credits { Text("Reported credits: \(credits) · currency not assumed").font(.caption) }
        Text("\(account.coverage.rawValue) · \(account.note)").font(.caption2).foregroundStyle(.secondary)
        if let date = account.observedAt { Text("Measured \(date.formatted(date: .abbreviated, time: .standard))").font(.caption2).foregroundStyle(.secondary) }
    }
    private var agentList: some View {
        let filtered = services.store.filtered(query: services.navigation.query, project: services.navigation.project, state: services.navigation.state, showStopped: services.showStopped)
        return VStack(alignment: .leading, spacing: 12) {
            TextField("Find an agent or source", text: $services.navigation.query).textFieldStyle(.roundedBorder).accessibilityLabel("Find an agent or source")
            HStack {
                Picker("Project", selection: $services.navigation.project) {
                    Text("All projects").tag(nil as String?)
                    ForEach(Array(Set(agents.map(\.project))).sorted(), id: \.self) { Text($0).tag(Optional($0)) }
                }
                Picker("State", selection: $services.navigation.state) {
                    Text("All states").tag(nil as Activity?)
                    ForEach(Activity.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                }
            }
            Text("\(filtered.matches.count) matching agents · ancestor context retained").font(.caption).foregroundStyle(.secondary)
            if filtered.matches.isEmpty { Text("No sessions observed or matching filters. Enable an integration to observe future activity; Relay does not launch agents.").foregroundStyle(.secondary) }
            ForEach(Array(Set(agents.filter { filtered.context.contains($0.id) }.map(\.project))).sorted(), id: \.self) { project in
                Text(project).font(.headline).id("project:\(project)")
                ForEach(agents.filter { $0.project == project && filtered.context.contains($0.id) && visible($0, context: filtered.context) }) { agent in
                    HStack(spacing: 5) {
                        if agents.contains(where: { $0.parent == agent.id }) {
                            Button { services.navigation.toggle(agent.id) } label: { Image(systemName: services.navigation.collapsed.contains(agent.id) ? "chevron.right" : "chevron.down") }
                                .buttonStyle(.plain).accessibilityLabel("\(services.navigation.collapsed.contains(agent.id) ? "Expand" : "Collapse") \(agent.displayTitle)")
                        }
                        Button { services.navigation.push(.agent(agent.id)) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(agent.displayTitle).font(.system(size: 13, weight: .medium))
                                    Text("\(agent.id.source.rawValue) · \(agent.memberOf == nil ? "reported observation" : "parent unknown · session member")").font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 2); activity(agent.activity)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }.padding(.vertical, 7).padding(.leading, CGFloat(max(0, services.store.ancestry(agent.id).count - 1)) * 12).id(agent.id.description)
                }
            }
            Text("Lines mean reported links, never inferred ancestry. Stop, absence and silence do not establish global success.").font(.caption).foregroundStyle(.secondary)
            ForEach(Source.allCases, id: \.self) { source in Text("\(source.rawValue): \((services.store.sourceCoverage[source] ?? .notCollecting).rawValue)").font(.caption2) }
        }.scrollTargetLayout()
    }
    private func visible(_ agent: Agent, context: Set<AgentID>) -> Bool {
        guard services.navigation.query.isEmpty, services.navigation.state == nil else { return true }
        return services.store.ancestry(agent.id).subtracting([agent.id]).isDisjoint(with: services.navigation.collapsed)
    }
    private func activity(_ value: Activity) -> some View {
        Text(value == .waiting ? "Needs input" : value.rawValue.capitalized).font(.caption2).foregroundStyle(value == .waiting ? .orange : .secondary)
    }
    private func accountDetail(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            quota(account)
            if let profile = services.profiles.first(where: { $0.id == account.id }), profile.source == .codex {
                HStack { Button("Refresh quota") { services.refresh(profile) }; Button("Cancel this profile") { services.cancel(profile) } }
            }
            Text("Associated observed agents").font(.headline)
            ForEach(agents.filter { $0.account == account.id }) { agent in
                Button(agent.displayTitle) { services.navigation.push(.agent(agent.id)) }
            }
            Text("Model/provider names never establish billing identity. Unattributed sessions remain in Agents.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func agentDetail(_ agent: Agent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            activity(agent.activity)
            Text("Source: \(agent.id.source.rawValue)")
            Text("Project: \(agent.project)")
            if let parent = agent.parent, let item = services.store.agents[parent] {
                Button("Parent: \(item.displayTitle)") { services.navigation.push(.agent(parent)) }
            } else { Text("Immediate parent: unknown / not reported") }
            if let member = agent.memberOf, let item = services.store.agents[member] {
                Button("Session membership: \(item.displayTitle)") { services.navigation.push(.agent(member)) }
            }
            if let provenance = agent.relationship { Text(provenance).font(.caption).foregroundStyle(.secondary) }
            if let id = agent.account, let account = services.store.accounts[id] {
                Button("Account: \(account.source.rawValue) / \(account.alias)") { services.navigation.push(.account(id)) }
            } else { Text("Account: unknown · model is not billing identity").font(.caption) }
            Text("Reported links").font(.headline)
            ForEach(agents.filter { $0.parent == agent.id || $0.memberOf == agent.id }) { child in
                Button(child.displayTitle) { services.navigation.push(.agent(child.id)) }
            }
            Text("Latest observed lifecycle categories").font(.headline)
            ForEach(Array(agent.events.enumerated()), id: \.offset) { _, event in Text(event).font(.caption) }
            Text("Observed \(agent.observedAt.formatted()). Titles and observations are memory-only and disappear on restart.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
