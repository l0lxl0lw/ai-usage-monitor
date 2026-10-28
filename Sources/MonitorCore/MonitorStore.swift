import Foundation

/// Observation state has deliberately no Codable/export surface. Titles and history are RAM-only.
public final class MonitorStore {
    public private(set) var agents: [AgentID: Agent] = [:]
    public private(set) var accounts: [UUID: Account] = [:]
    public private(set) var generations: [UUID: UUID] = [:]
    public var sourceCoverage: [Source: Coverage] = [:]
    private var seen: Set<UUID> = []
    private var order: [UUID] = []
    public init() {}
    @discardableResult public func restart(_ profile: UUID) -> UUID {
        let generation = UUID(); generations[profile] = generation
        for key in agents.keys where key.profile == profile { agents[key] = nil }
        return generation
    }
    public func upsert(_ value: Agent, generation: UUID? = nil, event: UUID = UUID()) {
        if let generation, generations[value.id.profile] != generation { return }
        guard !seen.contains(event) else { return }
        seen.insert(event); order.append(event)
        if order.count > 2048 { seen.remove(order.removeFirst()) }
        if let previous = agents[value.id], previous.observedAt > value.observedAt { return }
        var value = value
        // Cycles and cross-namespace ancestry never enter the tree.
        if let parent = value.parent {
            if parent.source != value.id.source || parent.profile != value.id.profile || parent.runtime != value.id.runtime || ancestry(parent).contains(value.id) || parent == value.id {
                value.parent = nil; value.relationship = "Invalid reported ancestry · unknown"
            }
        }
        value.events = Array(value.events.suffix(12))
        agents[value.id] = value
        if agents.count > 2048, let oldest = agents.values.min(by: { $0.observedAt < $1.observedAt }) { agents[oldest.id] = nil }
    }
    public func ancestry(_ id: AgentID) -> Set<AgentID> {
        var result: Set<AgentID> = []; var next: AgentID? = id
        while let item = next, result.count < 128, result.insert(item).inserted { next = agents[item]?.parent }
        return result
    }
    public func orderedAgents() -> [Agent] {
        let sorted = agents.values.sorted { ($0.displayTitle, $0.id.description) < ($1.displayTitle, $1.id.description) }
        var result: [Agent] = [], visited: Set<AgentID> = []
        func visit(_ value: Agent) {
            guard visited.insert(value.id).inserted else { return }
            result.append(value)
            for child in sorted where child.parent == value.id { visit(child) }
        }
        for value in sorted where value.parent == nil || agents[value.parent!] == nil { visit(value) }
        for value in sorted { visit(value) }
        return result
    }
    public func update(_ account: Account) { accounts[account.id] = account }
    public func expireMeasurements(before date: Date) {
        for (id, var account) in accounts where account.coverage == .observed && (account.observedAt ?? .distantPast) < date {
            account.coverage = .stale; accounts[id] = account
        }
    }
    public func reconcile(_ values: [Agent], source: Source, profile: UUID) {
        let present = Set(values.map(\.id))
        for (id, var agent) in agents where id.source == source && id.profile == profile && !present.contains(id) {
            agent.activity = .unknown; agent.relationship = "Not in latest snapshot · last observation retained; outcome unknown"
            agents[id] = agent
        }
        for agent in values { upsert(agent) }
    }
    public func markFailure(_ id: UUID) {
        guard var account = accounts[id] else { return }
        account.coverage = account.observedAt == nil ? .failed : .stale
        account.note = "Read unavailable · no synthetic fallback"; accounts[id] = account
    }
    public func filtered(query: String, project: String?, state: Activity?, showStopped: Bool = true) -> (matches: Set<AgentID>, context: Set<AgentID>) {
        let direct = agents.values.filter { agent in
            (project == nil || agent.project == project) && (state == nil || agent.activity == state) &&
            (showStopped || agent.activity != .stopped) &&
            (query.isEmpty || "\(agent.displayTitle) \(agent.id.source.rawValue) \(agent.project)".localizedCaseInsensitiveContains(query))
        }
        let matches = Set(direct.map(\.id)); var context = matches
        for agent in direct { context.formUnion(ancestry(agent.id)) }
        return (matches, context)
    }
}

public struct PollSchedule {
    public private(set) var inFlight = false
    public private(set) var failures = 0
    public private(set) var next = Date.distantPast
    public init() {}
    public mutating func begin(now: Date) -> Bool {
        guard !inFlight, now >= next else { return false }; inFlight = true; return true
    }
    public mutating func finish(now: Date, success: Bool, retryAfter: Double? = nil) {
        inFlight = false; failures = success ? 0 : min(8, failures + 1)
        let delay = success ? 60.0 : min(3600, 30 * pow(2, Double(failures)))
        next = now.addingTimeInterval(max(delay, min(3600, max(0, retryAfter ?? 0))))
    }
    public mutating func cancel() { inFlight = false }
}
