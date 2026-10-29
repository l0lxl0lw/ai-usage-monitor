import Foundation
import Darwin
import MonitorCore

public enum UnixRelay {
    public static let maxFrame = 65536
    public static var directory: String { NSHomeDirectory() + "/Library/Application Support/Relay/bridge" }
    public static var socketPath: String { directory + "/events.sock" }
    public static func validate(_ path: String, type: mode_t, mode: mode_t, uid: uid_t = getuid()) -> Bool {
        var info = stat()
        return lstat(path, &info) == 0 && info.st_uid == uid && (info.st_mode & S_IFMT) == type && (info.st_mode & 0o777) == mode
    }
    static func address(_ path: String) throws -> sockaddr_un {
        var address = sockaddr_un(); address.sun_family = sa_family_t(AF_UNIX)
        guard path.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else { throw TransportError.denied }
        withUnsafeMutableBytes(of: &address.sun_path) { target in
            for (i, value) in (Array(path.utf8) + [0]).enumerated() { target[i] = value }
        }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size); return address
    }
    static func sameUser(_ fd: Int32) -> Bool {
        var uid: uid_t = 0, gid: gid_t = 0
        return getpeereid(fd, &uid, &gid) == 0 && uid == getuid()
    }
    /// Deadline is monotonic and established by the bridge before the first stdin byte.
    public static func boundedRead(fd: Int32, deadline: UInt64) throws -> Data {
        var result = Data()
        while DispatchTime.now().uptimeNanoseconds < deadline {
            var item = pollfd(fd: fd, events: Int16(POLLIN | POLLHUP), revents: 0)
            if poll(&item, 1, 5) > 0 {
                var bytes = [UInt8](repeating: 0, count: 4096)
                let count = Darwin.read(fd, &bytes, bytes.count)
                if count == 0 { return result }
                if count > 0 { result.append(contentsOf: bytes.prefix(count)); if result.count > maxFrame { throw TransportError.oversized } }
            }
        }
        throw TransportError.timeout
    }
    public static func send(_ data: Data, path: String = socketPath, deadline: UInt64) throws {
        let directory = (path as NSString).deletingLastPathComponent
        guard data.count <= maxFrame, validate(directory, type: S_IFDIR, mode: 0o700), validate(path, type: S_IFSOCK, mode: 0o600) else { throw TransportError.denied }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0); guard fd >= 0 else { throw TransportError.unavailable }; defer { close(fd) }
        var noSignal: Int32 = 1; setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal)))
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        var address = try address(path)
        let connected = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        guard connected == 0, sameUser(fd) else { throw TransportError.unavailable }
        var sent = 0
        while sent < data.count && DispatchTime.now().uptimeNanoseconds < deadline {
            let count = data.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!.advanced(by: sent), data.count - sent) }
            if count > 0 { sent += count } else if errno != EAGAIN { throw TransportError.unavailable }
        }
        guard sent == data.count else { throw TransportError.timeout }
        shutdown(fd, SHUT_WR)
    }
}

public final class HookListener {
    private var fd: Int32 = -1
    private var lockFD: Int32 = -1
    private var ownedInode: ino_t?
    private let queue = DispatchQueue(label: "Relay.bridge")
    private let directory: String
    private var path: String { directory + "/events.sock" }
    public init(directory: String = UnixRelay.directory) { self.directory = directory }
    deinit { stop() }
    public func start(receive: @escaping (RelayMessage) -> Void) throws {
        guard fd < 0, lockFD < 0 else { throw TransportError.denied }
        let parent = (directory as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard UnixRelay.validate(parent, type: S_IFDIR, mode: 0o700) else { throw TransportError.denied }
        if mkdir(directory, 0o700) != 0 && errno != EEXIST { throw TransportError.denied }
        guard UnixRelay.validate(directory, type: S_IFDIR, mode: 0o700) else { throw TransportError.denied }
        // Serialize recovery and bind, including the bind-before-listen interval.
        // The lock holds no events and is automatically released after a crash.
        let lock = open(directory + "/listener.lock", O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard lock >= 0 else { throw TransportError.denied }
        var lockInfo = stat()
        guard fstat(lock, &lockInfo) == 0, lockInfo.st_uid == getuid(), lockInfo.st_nlink == 1,
              (lockInfo.st_mode & S_IFMT) == S_IFREG, (lockInfo.st_mode & 0o777) == 0o600,
              flock(lock, LOCK_EX | LOCK_NB) == 0 else { close(lock); throw TransportError.denied }
        lockFD = lock
        do { try recoverStaleSocket() } catch { stop(); throw error }
        do { _ = try UnixRelay.address(path) } catch { stop(); throw error }
        fd = socket(AF_UNIX, SOCK_STREAM, 0); guard fd >= 0 else { stop(); throw TransportError.unavailable }
        var address = try UnixRelay.address(path)
        let bound = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        if bound == 0 { var info = stat(); if lstat(path, &info) == 0 { ownedInode = info.st_ino } }
        guard bound == 0, chmod(path, 0o600) == 0, listen(fd, 8) == 0 else { stop(); throw TransportError.unavailable }
        let listener = fd
        queue.async {
            while self.fd == listener {
                var readiness = pollfd(fd: listener, events: Int16(POLLIN), revents: 0)
                guard poll(&readiness, 1, 100) > 0 else { continue }
                let child = accept(listener, nil, nil); guard child >= 0 else { continue }
                defer { close(child) }
                guard UnixRelay.sameUser(child), let data = try? UnixRelay.boundedRead(fd: child, deadline: DispatchTime.now().uptimeNanoseconds + 100_000_000),
                      let message = try? JSONDecoder().decode(RelayMessage.self, from: data) else { continue }
                switch message {
                case .hook(let event):
                    guard (event.source == .codex || event.source == .claude), HookProjection.events.contains(event.kind),
                          Privacy.identifier(event.session) != nil,
                          event.agent == nil || Privacy.identifier(event.agent) != nil,
                          event.turn == nil || Privacy.identifier(event.turn) != nil,
                          abs(event.received.timeIntervalSinceNow) < 60 else { continue }
                case .claudeQuota(let telemetry): guard (try? telemetry.validated()) != nil else { continue }
                }
                receive(message)
            }
        }
    }
    private func recoverStaleSocket() throws {
        var before = stat()
        if lstat(path, &before) != 0 {
            guard errno == ENOENT else { throw TransportError.denied }; return
        }
        guard UnixRelay.validate(path, type: S_IFSOCK, mode: 0o600) else { throw TransportError.denied }
        let probe = socket(AF_UNIX, SOCK_STREAM, 0)
        guard probe >= 0 else { throw TransportError.unavailable }; defer { close(probe) }
        _ = fcntl(probe, F_SETFL, O_NONBLOCK)
        var address = try UnixRelay.address(path)
        let connected = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(probe, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        // Only a refused connection proves a stale endpoint. Success, backlog
        // pressure and all other errors leave it untouched.
        guard connected != 0, errno == ECONNREFUSED else { throw TransportError.denied }
        var after = stat()
        guard lstat(path, &after) == 0, before.st_dev == after.st_dev, before.st_ino == after.st_ino,
              UnixRelay.validate(path, type: S_IFSOCK, mode: 0o600), unlink(path) == 0 else { throw TransportError.denied }
    }
    public func stop() {
        if fd >= 0 {
            let old = fd; fd = -1; close(old)
            var info = stat()
            if let ownedInode, lstat(path, &info) == 0, info.st_ino == ownedInode,
               UnixRelay.validate(path, type: S_IFSOCK, mode: 0o600) { unlink(path) }
            ownedInode = nil
        }
        if lockFD >= 0 { close(lockFD); lockFD = -1 }
    }
}
