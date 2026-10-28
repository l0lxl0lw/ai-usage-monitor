import Foundation

public enum Source: String, Codable, CaseIterable { case codex, claude, opencode, orca }
public enum Coverage: String, Codable { case observed, empty, missing, stale, partial, unsupported, notCollecting, failed }
public enum Activity: String, Codable, CaseIterable { case working, waiting, idle, stopped, interrupted, succeeded, failed, unknown }
public enum Mode: String, CaseIterable { case demo = "Demo", live = "Live" }

public struct AgentID: Hashable, Codable, CustomStringConvertible {
    public let source: Source
    public let profile: UUID
    public let runtime: String
    public let local: String
    public init(_ source: Source, _ profile: UUID, _ runtime: String, _ local: String) {
        self.source = source; self.profile = profile; self.runtime = runtime; self.local = local
    }
    public var description: String { "\(source.rawValue):\(profile):\(runtime):\(local)" }
}

public struct Agent: Identifiable, Equatable {
    public let id: AgentID
    public var title: String?
    public var project: String
    public var activity: Activity
    public var observedAt: Date
    public var parent: AgentID?
    public var memberOf: AgentID?
    public var relationship: String?
    public var account: UUID?
    public var turn: String?
    public var events: [String]
    public init(id: AgentID, title: String? = nil, project: String = "Unspecified project", activity: Activity = .unknown,
                observedAt: Date = Date(), parent: AgentID? = nil, memberOf: AgentID? = nil,
                relationship: String? = nil, account: UUID? = nil, turn: String? = nil, events: [String] = []) {
        self.id = id; self.title = title; self.project = project; self.activity = activity; self.observedAt = observedAt
        self.parent = parent; self.memberOf = memberOf; self.relationship = relationship; self.account = account
        self.turn = turn; self.events = events
    }
    public var displayTitle: String { title ?? "\(id.source.rawValue.capitalized) · \(String(id.local.suffix(12)))" }
}

public struct QuotaWindow: Equatable, Codable {
    public var label: String
    public var usedPercent: Double
    public var durationSeconds: Double?
    public var resetsAt: Date?
    public init(label: String, usedPercent: Double, durationSeconds: Double? = nil, resetsAt: Date? = nil) throws {
        guard usedPercent.isFinite, (0...100).contains(usedPercent),
              durationSeconds == nil || (durationSeconds!.isFinite && durationSeconds! > 0),
              resetsAt == nil || resetsAt!.timeIntervalSince1970.isFinite else { throw ModelError.invalidQuota }
        self.label = label; self.usedPercent = usedPercent; self.durationSeconds = durationSeconds; self.resetsAt = resetsAt
    }
    public func resetDescription(now: Date = Date()) -> String {
        guard let resetsAt else { return "Reset not reported" }
        return resetsAt <= now ? "Reset passed · awaiting a new measurement" : "Resets \(resetsAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
public enum ModelError: Error { case invalidQuota, duplicateHome, identityMismatch, invalidInput }

public struct Account: Identifiable {
    public let id: UUID
    public let source: Source
    public var alias: String
    public var windows: [QuotaWindow] = []
    public var credits: String?
    public var observedAt: Date?
    public var coverage: Coverage = .missing
    public var note: String = "Not measured"
    public init(id: UUID, source: Source, alias: String) { self.id = id; self.source = source; self.alias = alias }
}

public struct Profile: Codable, Identifiable, Equatable {
    public let id: UUID
    public var source: Source
    public var alias: String
    public var home: String
    public init(id: UUID = UUID(), source: Source, alias: String, home: String) {
        self.id = id; self.source = source; self.alias = alias; self.home = home
    }
    public var canonicalHome: String { URL(fileURLWithPath: home).standardizedFileURL.resolvingSymlinksInPath().path }
}
