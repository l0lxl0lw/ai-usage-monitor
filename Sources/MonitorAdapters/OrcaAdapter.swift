import Foundation
import MonitorCore

public struct OrcaSnapshot {
    public var agents: [Agent]
    public var coverage: Coverage
    public var omittedHosts: Int
    public var runCount = 0
    public var workerCoverage: Coverage = .unsupported
    public static func decode(_ data: Data, profile: UUID) throws -> OrcaSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], root["ok"] as? Bool == true,
              let result = root["result"] as? [String: Any], let worktrees = result["worktrees"] as? [[String: Any]],
              let runtime = Privacy.identifier((root["_meta"] as? [String: Any])?["runtimeId"]) else { throw TransportError.malformed }
        let omitted = ((result["hostScope"] as? [String: Any])?["omittedHostIds"] as? [String])?.count ?? 0
        var agents: [Agent] = []
        for row in worktrees {
            guard let workspace = Privacy.identifier(row["worktreeId"]), let host = Privacy.identifier(row["hostId"]),
                  let instance = Privacy.identifier(row["worktreeInstanceId"]), let panes = row["agents"] as? [[String: Any]] else { continue }
            for pane in panes {
                guard let key = Privacy.identifier(pane["paneKey"]) else { continue }
                let repo = Privacy.identifier(row["repoId"]) ?? "unknown-repo"
                let id = AgentID(.orca, profile, "\(runtime):\(host):\(instance):\(repo)", "\(workspace):\(key)")
                let state: Activity = ["working": .working, "waiting": .waiting, "idle": .idle][pane["state"] as? String ?? ""] ?? .unknown
                agents.append(Agent(id: id, title: Privacy.title(pane["displayName"]), project: workspace, activity: state,
                                    relationship: "Workspace lineage / pane parent semantics not certified · parent unknown"))
            }
        }
        // Nonempty worker decoding is deliberately not invented; PTY metadata is partial.
        return OrcaSnapshot(agents: agents, coverage: .partial, omittedHosts: omitted)
    }
}

public final class OrcaAdapter {
    public init() {}
    public func read(executable: String, profile: UUID) throws -> OrcaSnapshot {
        let environment = TransportPolicy.orcaEnvironment(home: NSHomeDirectory(), temporary: NSTemporaryDirectory())
        func read(_ arguments: [String]) throws -> [String: Any] {
            let data = try ProcessTransport().run(executable: executable, arguments: arguments, environment: environment)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], root["ok"] as? Bool == true,
                  let result = root["result"] as? [String: Any] else { throw TransportError.malformed }
            return result
        }
        let data = try ProcessTransport().run(executable: executable, arguments: ["worktree", "ps", "--json"], environment: environment)
        var snapshot = try OrcaSnapshot.decode(data, profile: profile)
        // Only the verified lightweight run ID and empty worker schema are consumed.
        // Objectives, task bodies, dependencies and unknown nonempty workers are discarded.
        var cursor: String?, cursors: Set<String> = [], runs: Set<String> = []
        do {
            for _ in 0..<10 {
                let result = try read(["orchestration", "run-list", "--limit", "20", "--json"] + (cursor.map { ["--cursor", $0] } ?? []))
                guard let rows = result["runs"] as? [[String: Any]] else { throw TransportError.malformed }
                for row in rows {
                    guard let id = Privacy.identifier(row["id"]), runs.insert(id).inserted else { continue }
                    snapshot.runCount = runs.count
                    guard runs.count <= 20 else { return snapshot }
                    let workers = try read(["orchestration", "worker-list", "--run", id, "--limit", "100", "--json"])
                    if try Self.emptyWorkers(workers) { if snapshot.workerCoverage == .unsupported && runs.count == 1 { snapshot.workerCoverage = .empty } }
                    else { snapshot.workerCoverage = .unsupported; return snapshot }
                }
                guard let next = result["nextCursor"] as? String else { return snapshot }
                guard !next.isEmpty, next.utf8.count < 4096, cursors.insert(next).inserted else { return snapshot }
                cursor = next
            }
        } catch { snapshot.workerCoverage = .partial }
        return snapshot
    }
    public static func emptyWorkers(_ result: [String: Any]) throws -> Bool {
        guard let rows = result["workers"] as? [[String: Any]], let page = result["page"] as? [String: Any],
              let scope = result["scope"] as? [String: Any], scope["source"] as? String == "flag",
              let more = page["hasMore"] as? Bool, let total = page["total"] as? Int else { throw TransportError.malformed }
        return rows.isEmpty && !more && total == 0
    }
}
