import Foundation
import MonitorCore

public enum ClaudeQuota {
    public static func project(_ data: Data, profile: UUID) throws -> ClaudeTelemetry {
        guard data.count <= UnixRelay.maxFrame,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw TransportError.malformed }
        return ClaudeTelemetry(profile: profile, windows: try decode(object), received: Date())
    }
    public static func decode(_ input: [String: Any]) throws -> [QuotaWindow] {
        guard let limits = input["rate_limits"] as? [String: Any] else { return [] }
        return try [("five_hour", "5-hour", 18000.0), ("seven_day", "Weekly", 604800.0)].compactMap { key, label, seconds in
            guard let row = limits[key] as? [String: Any] else { return nil }
            guard let used = Privacy.number(row["used_percentage"]) else { throw ModelError.invalidQuota }
            return try QuotaWindow(label: label, usedPercent: used, durationSeconds: seconds,
                                   resetsAt: Privacy.number(row["resets_at"]).map(Date.init(timeIntervalSince1970:)))
        }
    }
}

public struct ClaudeTelemetry: Codable {
    public let profile: UUID
    public let windows: [QuotaWindow]
    public let received: Date
    public func validated() throws -> ClaudeTelemetry {
        guard windows.count <= 2, abs(received.timeIntervalSinceNow) < 60 else { throw TransportError.malformed }
        for window in windows {
            _ = try QuotaWindow(label: window.label, usedPercent: window.usedPercent, durationSeconds: window.durationSeconds, resetsAt: window.resetsAt)
            guard ["5-hour", "Weekly"].contains(window.label) else { throw TransportError.malformed }
        }
        return self
    }
}

public enum RelayMessage: Codable {
    case hook(HookEvent)
    case claudeQuota(ClaudeTelemetry)
}

public struct HookEvent: Codable {
    public var source: Source
    public var profile: UUID
    public var session: String
    public var agent: String?
    public var turn: String?
    public var kind: String
    public var stopActive: Bool
    public var relayID: UUID
    public var received: Date
    public init(source: Source, profile: UUID, session: String, agent: String?, turn: String?, kind: String, stopActive: Bool = false, relayID: UUID = UUID(), received: Date = Date()) {
        self.source = source; self.profile = profile; self.session = session; self.agent = agent; self.turn = turn
        self.kind = kind; self.stopActive = stopActive; self.relayID = relayID; self.received = received
    }
}

public enum HookProjection {
    public static let events: Set<String> = ["SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop", "Interrupt", "SubagentStart", "SubagentStop"]
    public static func project(_ data: Data, source: Source, profile: UUID, version: String) throws -> HookEvent {
        guard data.count <= 65536, source == .claude || source == .codex,
              source != .codex || version == "0.154.0",
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = object["hook_event_name"] as? String, events.contains(kind),
              let session = Privacy.identifier(object["session_id"]) else { throw TransportError.malformed }
        let agent = Privacy.identifier(object["agent_id"])
        if kind.hasPrefix("Subagent"), agent == nil { throw TransportError.malformed }
        return HookEvent(source: source, profile: profile, session: session, agent: agent,
                         turn: Privacy.identifier(object["turn_id"]), kind: kind, stopActive: object["stop_hook_active"] as? Bool ?? false)
    }
    public static func apply(_ event: HookEvent, store: MonitorStore, runtime: String) {
        let session = AgentID(event.source, event.profile, runtime, event.session)
        let id = event.agent.map { AgentID(event.source, event.profile, runtime, "\(event.session):\($0)") } ?? session
        var value = store.agents[id] ?? Agent(id: id, memberOf: event.agent == nil ? nil : session,
                                             relationship: event.agent == nil ? nil : "Reported session membership · immediate parent unknown", account: event.profile)
        guard event.received >= value.observedAt || store.agents[id] == nil else { return }
        value.observedAt = event.received
        switch event.kind {
        case "UserPromptSubmit", "PreToolUse", "PostToolUse", "SubagentStart":
            value.activity = .working; value.turn = event.turn
        case "PermissionRequest": value.activity = .waiting
        case "Stop", "Interrupt":
            // Uncorrelated ends/continuations cannot end a newer turn or a swarm.
            if let turn = event.turn, turn == value.turn, !event.stopActive { value.activity = event.kind == "Interrupt" ? .interrupted : .idle }
            else { value.activity = .unknown }
        case "SubagentStop":
            // A delayed stop from an older turn (or a continuing stop hook)
            // cannot terminate a reactivated child. Missing correlation is unknown.
            if let turn = event.turn, turn == value.turn, !event.stopActive { value.activity = .stopped }
            else if store.agents[id] == nil { value.activity = .unknown }
        case "SessionEnd": value.activity = .unknown
        default: value.activity = .unknown
        }
        value.events.append(event.kind)
        store.upsert(value, event: event.relayID)
    }
}
