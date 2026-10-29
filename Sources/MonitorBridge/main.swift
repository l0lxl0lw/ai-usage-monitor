import Foundation
import MonitorCore
import MonitorAdapters

// Hooks must never delay or control the agent. No diagnostics or model-control output.
let deadline = DispatchTime.now().uptimeNanoseconds + 150_000_000
do {
    let args = CommandLine.arguments
    guard args.count == 4, let profile = UUID(uuidString: args[2]) else { exit(0) }
    let raw = try UnixRelay.boundedRead(fd: STDIN_FILENO, deadline: deadline)
    let message: RelayMessage
    if args[1] == "claude-statusline", args[3] == "documented" {
        message = .claudeQuota(try ClaudeQuota.project(raw, profile: profile))
    } else {
        guard let source = Source(rawValue: args[1]) else { exit(0) }
        message = .hook(try HookProjection.project(raw, source: source, profile: profile, version: args[3]))
    }
    try UnixRelay.send(JSONEncoder().encode(message), deadline: deadline)
} catch { /* bounded drop; never log payloads and never autostart the app */ }
exit(0)
