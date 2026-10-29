import Foundation
import Darwin
import MonitorCore

public struct CodexQuota {
    public var identity: String?
    public var windows: [QuotaWindow]
    public var credits: String?
    public static func decode(_ data: Data) throws -> CodexQuota {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw TransportError.malformed }
        var windows: [QuotaWindow] = []
        // Buckets are quota products, not separate user accounts.
        let buckets = object["rateLimitsByLimitId"] as? [String: [String: Any]]
        let snapshots: [(String, [String: Any])] = buckets?.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
            ?? (object["rateLimits"] as? [String: Any]).map { [("Quota", $0)] } ?? []
        var credits: String?
        for (bucket, snapshot) in snapshots {
            for slot in ["primary", "secondary"] {
                guard let row = snapshot[slot] as? [String: Any] else { continue }
                guard let used = Privacy.number(row["usedPercent"]) else { throw ModelError.invalidQuota }
                let minutes = Privacy.number(row["windowDurationMins"])
                let reset = Privacy.number(row["resetsAt"])
                let label = minutes.map { $0 == 10080 ? "Weekly" : "\($0.formatted()) min" } ?? "\(bucket) · \(slot)"
                windows.append(try QuotaWindow(label: label, usedPercent: used, durationSeconds: minutes.map { $0 * 60 }, resetsAt: reset.map(Date.init(timeIntervalSince1970:))))
            }
            if let value = (snapshot["credits"] as? [String: Any])?["balance"] as? String,
               value.utf8.count <= 128, let numeric = Double(value), numeric.isFinite, numeric >= 0 { credits = value }
        }
        return CodexQuota(identity: object["accountId"] as? String, windows: windows, credits: credits)
    }
}

public final class CodexRPC {
    private let process = Process()
    private let input = Pipe(), output = Pipe()
    private var buffer = Data()
    private var launched = false
    public private(set) var reaped = false
    public init(executable: String, home: String) throws {
        guard executable.hasPrefix("/"), home.hasPrefix("/") else { throw TransportError.denied }
        let version = try ProcessTransport().run(executable: executable, arguments: ["--version"], environment: TransportPolicy.orcaEnvironment(home: NSHomeDirectory(), temporary: NSTemporaryDirectory()), timeout: 5)
        guard String(decoding: version, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) == "codex-cli 0.154.0" else { throw TransportError.unsupported }
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["-s", "read-only", "-a", "never", "app-server"]
        process.environment = ["HOME": NSHomeDirectory(), "CODEX_HOME": home,
                               "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "TMPDIR": NSTemporaryDirectory()]
        process.standardInput = input; process.standardOutput = output; process.standardError = FileHandle.nullDevice
        try process.run()
        launched = true
        _ = fcntl(output.fileHandleForReading.fileDescriptor, F_SETFL, O_NONBLOCK)
    }
    deinit { stop() }
    public func stop() {
        guard launched, !reaped else { return }
        try? input.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }
        let deadline = Date().addingTimeInterval(1)
        while process.isRunning && Date() < deadline { usleep(10000) }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        process.waitUntilExit(); reaped = true
    }
    private func send(_ value: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: value); data.append(10)
        try input.fileHandleForWriting.write(contentsOf: data)
    }
    private func rpc(_ id: Int, _ method: String, _ params: [String: Any]) throws -> [String: Any] {
        try send(["jsonrpc": "2.0", "id": id, "method": method, "params": params])
        let deadline = Date().addingTimeInterval(30), fd = output.fileHandleForReading.fileDescriptor
        while Date() < deadline {
            if Task.isCancelled { throw CancellationError() }
            while let newline = buffer.firstIndex(of: 10) {
                let line = buffer.prefix(upTo: newline); buffer.removeSubrange(...newline)
                guard let object = try JSONSerialization.jsonObject(with: line) as? [String: Any] else { throw TransportError.malformed }
                if object["id"] as? Int == id {
                    if let error = object["error"] as? [String: Any] {
                        if error["code"] as? Int == 429 { throw TransportError.throttled(nil) }
                        throw TransportError.unavailable
                    }
                    guard let result = object["result"] as? [String: Any] else { throw TransportError.malformed }; return result
                }
            }
            var state = pollfd(fd: fd, events: Int16(POLLIN | POLLHUP), revents: 0)
            if poll(&state, 1, 20) > 0 {
                var bytes = [UInt8](repeating: 0, count: 8192); let count = Darwin.read(fd, &bytes, bytes.count)
                if count == 0 { throw TransportError.unavailable }
                if count > 0 { buffer.append(contentsOf: bytes.prefix(count)); if buffer.count > 1_048_576 { throw TransportError.oversized } }
            }
        }
        throw TransportError.timeout
    }
    public func read() throws -> CodexQuota {
        _ = try rpc(1, "initialize", ["clientInfo": ["name": "relay", "version": "0.1.0"], "capabilities": ["experimentalApi": false]])
        try send(["jsonrpc": "2.0", "method": "initialized"])
        let account = try rpc(2, "account/read", ["refreshToken": false])
        guard let identity = account["account"] as? [String: Any], identity["type"] as? String == "chatgpt" else { throw TransportError.authentication }
        let value = try rpc(3, "account/rateLimits/read", ["excludeResetCreditDetails": true])
        var quota = try CodexQuota.decode(JSONSerialization.data(withJSONObject: value))
        // The quota response's accountId identifies this usage snapshot. Email is
        // only a fallback for older responses that omit it, never an override.
        if let accountID = quota.identity {
            guard !accountID.isEmpty, accountID.utf8.count <= 512 else { throw TransportError.authentication }
            quota.identity = "chatgpt-account:\(accountID)"
        } else {
            quota.identity = (identity["email"] as? String).flatMap { $0.isEmpty ? nil : "chatgpt:\($0)" }
        }
        guard quota.identity != nil, !quota.windows.isEmpty else { throw TransportError.authentication }
        return quota
    }
}
