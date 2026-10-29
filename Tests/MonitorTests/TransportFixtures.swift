import Foundation
import Darwin
import MonitorAdapters

enum Fixtures {
    static var directory: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures") }
    static func helper() throws -> URL {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: directory.appendingPathComponent("metadata-helper.py"), to: destination)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: destination.path)
        return destination
    }
}

final class MemoryVault: TokenVault {
    var tokens: [UUID: String] = [:]
    var denied = false
    func save(_ token: String, id: UUID) throws { if denied { throw TransportError.authentication }; tokens[id] = token }
    func read(_ id: UUID) throws -> String { guard !denied, let value = tokens[id] else { throw TransportError.authentication }; return value }
    func delete(_ id: UUID) throws { if denied { throw TransportError.authentication }; tokens[id] = nil }
    func deleteAll() throws { if denied { throw TransportError.authentication }; tokens.removeAll() }
}

final class HTTPFixture {
    let process = Process()
    let base: String
    init(_ mode: String = "normal") throws {
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [Fixtures.directory.appendingPathComponent("http-source.py").path, mode]
        process.standardInput = FileHandle.nullDevice; process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        try process.run()
        let fd = pipe.fileHandleForReading.fileDescriptor
        var port = Data()
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            var state = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            if poll(&state, 1, 20) > 0 {
                var byte: UInt8 = 0
                guard Darwin.read(fd, &byte, 1) == 1 else { throw TransportError.unavailable }
                if byte == 10 { break }; port.append(byte)
            }
        }
        guard let number = Int(String(decoding: port, as: UTF8.self)), number > 0 else { process.terminate(); throw TransportError.timeout }
        base = "http://127.0.0.1:\(number)"
    }
    deinit { if process.isRunning { process.terminate() }; process.waitUntilExit() }
}
