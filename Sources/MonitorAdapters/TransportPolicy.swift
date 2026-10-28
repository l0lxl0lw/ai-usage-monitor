import Foundation
import Darwin
import MonitorCore

public enum TransportError: Error { case denied, timeout, oversized, malformed, unavailable, unsupported, authentication, throttled(Double?) }
public enum TransportPolicy {
    public static func localURL(_ value: String) throws -> URL {
        guard let url = URL(string: value), let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "http", ["127.0.0.1", "[::1]", "::1"].contains(parts.host ?? ""),
              parts.user == nil, parts.password == nil, parts.fragment == nil,
              let port = parts.port, (1...65535).contains(port) else { throw TransportError.denied }
        return url
    }
    public static func allowGET(_ path: String, sessionIDs: Set<String>) -> Bool {
        if ["/api/info", "/api/session", "/api/session/active", "/api/event"].contains(path) { return true }
        let parts = path.split(separator: "/").map(String.init)
        return parts.count == 4 && parts[0] == "api" && parts[1] == "session" && Privacy.identifier(parts[2]) != nil && sessionIDs.contains(parts[2]) && ["permission", "form"].contains(parts[3])
    }
    public static func orcaEnvironment(home: String, temporary: String) -> [String: String] {
        ["HOME": home, "TMPDIR": temporary, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8"]
    }
}

/// A bounded child, with arguments and environment explicitly selected by the caller.
/// Raw stdout is returned only to in-memory decoders; stderr is never captured/logged.
public final class ProcessTransport {
    public init() {}
    public func run(executable: String, arguments: [String], environment: [String: String], timeout: Double = 10) throws -> Data {
        guard executable.hasPrefix("/"), timeout > 0 else { throw TransportError.denied }
        let process = Process(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        process.environment = environment; process.standardOutput = output; process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        try process.run()
        defer {
            if process.isRunning { process.terminate() }
            let reapDeadline = DispatchTime.now().uptimeNanoseconds + 200_000_000
            while process.isRunning && DispatchTime.now().uptimeNanoseconds < reapDeadline { usleep(1000) }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
        }
        let fd = output.fileHandleForReading.fileDescriptor
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(timeout * 1_000_000_000); var result = Data()
        var eof = false
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if eof {
                if !process.isRunning { guard process.terminationStatus == 0 else { throw TransportError.unavailable }; return result }
                usleep(1000); continue
            }
            var poller = pollfd(fd: fd, events: Int16(POLLIN | POLLHUP), revents: 0)
            if poll(&poller, 1, 20) > 0 {
                var bytes = [UInt8](repeating: 0, count: 8192)
                let count = Darwin.read(fd, &bytes, bytes.count)
                if count > 0 { result.append(contentsOf: bytes.prefix(count)); if result.count > 1_048_576 { throw TransportError.oversized } }
                else if count == 0 { eof = true }
            }
        }
        throw TransportError.timeout
    }
}
