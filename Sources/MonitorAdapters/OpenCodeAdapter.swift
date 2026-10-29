import Foundation
import Security
import MonitorCore

public protocol TokenVault {
    func save(_ token: String, id: UUID) throws
    func read(_ id: UUID) throws -> String
    func delete(_ id: UUID) throws
    /// Delete only this application's OpenCode service entries, including tokens
    /// left by an earlier process whose in-memory connection UUID was lost.
    func deleteAll() throws
}
public final class RelayKeychain: TokenVault {
    private let service = "org.relay.monitor.opencode"
    public init() {}
    private func query(_ id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: id.uuidString]
    }
    public func save(_ token: String, id: UUID) throws {
        try delete(id)
        var item = query(id); item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw TransportError.authentication }
    }
    public func read(_ id: UUID) throws -> String {
        var item = query(id); item[kSecReturnData as String] = true; item[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        guard SecItemCopyMatching(item as CFDictionary, &value) == errSecSuccess, let data = value as? Data,
              let token = String(data: data, encoding: .utf8) else { throw TransportError.authentication }
        return token
    }
    public func delete(_ id: UUID) throws {
        let status = SecItemDelete(query(id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw TransportError.authentication }
    }
    public func deleteAll() throws {
        let status = SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw TransportError.authentication }
    }
}

/// Application-level ownership of the single explicit connection. No endpoint,
/// token address or observation history has to be persisted: startup clears all
/// Relay-owned service entries before pairing is allowed again.
@MainActor public final class OpenCodeConnection {
    public private(set) var adapter: OpenCodeAdapter?
    private let vault: TokenVault
    private var generation = UUID()
    public init(vault: TokenVault = RelayKeychain()) { self.vault = vault }
    public func pair(link: String) async throws {
        try disconnect() // replacement must finish cleanup before redeeming a link
        let current = generation
        let url = try TransportPolicy.localURL(link)
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        parts.path = ""; parts.query = nil
        let next = try OpenCodeAdapter(base: parts.url!.absoluteString, profile: UUID(), keychain: vault)
        do {
            try await next.pair(link: link)
            guard !Task.isCancelled, current == generation else { throw CancellationError() }
            adapter = next
        } catch {
            // A cancelled older attempt must never delete a newer connection.
            try next.disconnect()
            throw error
        }
    }
    public func disconnect() throws {
        generation = UUID()
        // Retain the adapter if deletion fails so cleanup can be retried.
        try adapter?.disconnect()
        try vault.deleteAll()
        adapter = nil
    }
}

private final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

public final class LocalHTTP {
    private let delegate = NoRedirect()
    private let session: URLSession
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCache = nil; configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 10; configuration.timeoutIntervalForResource = 30
        configuration.connectionProxyDictionary = [:]
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
    public func cancel() { session.invalidateAndCancel() }
    public func get(_ url: URL, token: String? = nil) async throws -> [String: Any] {
        _ = try TransportPolicy.localURL(url.absoluteString)
        var request = URLRequest(url: url); request.httpMethod = "GET"; request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Basic " + Data("opencode:\(token)".utf8).base64EncodedString(), forHTTPHeaderField: "Authorization") }
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw TransportError.malformed }
        if response.statusCode == 401 { throw TransportError.authentication }
        if response.statusCode == 429 { throw TransportError.throttled(response.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)) }
        guard response.statusCode == 200 else { throw TransportError.unavailable }
        var data = Data()
        for try await byte in bytes { try Task.checkCancellation(); data.append(byte); if data.count > 1_048_576 { throw TransportError.oversized } }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw TransportError.malformed }; return object
    }
    public func events(_ url: URL, token: String, invalidated: @escaping () -> Void) async throws {
        _ = try TransportPolicy.localURL(url.absoluteString)
        guard url.path == "/api/event" else { throw TransportError.denied }
        var request = URLRequest(url: url); request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Basic " + Data("opencode:\(token)".utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
        let (bytes, response) = try await session.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw TransportError.unavailable }
        // Contents never become application state; events only invalidate REST truth.
        var lineBytes = 0; var last = Date.distantPast
        for try await byte in bytes {
            try Task.checkCancellation()
            lineBytes += 1; guard lineBytes < 65536 else { throw TransportError.oversized }
            if byte == 10 { lineBytes = 0; if Date().timeIntervalSince(last) > 1 { last = Date(); invalidated() } }
        }
        throw TransportError.unavailable // EOF is not success or evidence of completion.
    }
}

public struct OpenCodeSnapshot {
    public var agents: [Agent]
    public var coverage: Coverage
}
public enum OpenCodeProjection {
    public static func page(_ object: [String: Any], profile: UUID, runtime: String, active: Set<String>) throws -> ([Agent], String?) {
        guard let rows = object["data"] as? [[String: Any]], let cursors = object["cursor"] as? [String: Any] else { throw TransportError.malformed }
        let next: String?
        if let value = cursors["next"] as? String { guard !value.isEmpty, value.utf8.count <= 4096 else { throw TransportError.malformed }; next = value }
        else if cursors["next"] == nil || cursors["next"] is NSNull { next = nil } else { throw TransportError.malformed }
        let agents = try rows.map { row -> Agent in
            guard let local = Privacy.identifier(row["id"]) else { throw TransportError.malformed }
            let id = AgentID(.opencode, profile, runtime, local)
            let parent = Privacy.identifier(row["parentID"]).map { AgentID(.opencode, profile, runtime, $0) }
            return Agent(id: id, title: Privacy.title(row["title"]), project: Privacy.identifier(row["projectID"]) ?? "Unspecified project",
                         activity: active.contains(local) ? .working : (["succeeded": Activity.succeeded, "failed": .failed, "interrupted": .interrupted][row["outcome"] as? String ?? ""] ?? .unknown), parent: parent,
                         relationship: parent == nil ? nil : "OpenCode parentID · reported session link", events: [])
        }
        return (agents, next)
    }
}

public final class OpenCodeAdapter {
    public let profile: UUID
    public let base: URL
    private let http = LocalHTTP()
    private let keychain: TokenVault
    public private(set) var generation = UUID()
    private var runtime: String = UUID().uuidString
    private var serverIdentity: String?
    private var ids: Set<String> = []
    public init(base: String, profile: UUID, keychain: TokenVault = RelayKeychain()) throws {
        let url = try TransportPolicy.localURL(base)
        guard url.path.isEmpty || url.path == "/", url.query == nil else { throw TransportError.denied }
        self.base = url; self.profile = profile; self.keychain = keychain
    }
    @MainActor public func pair(link: String) async throws {
        let url = try TransportPolicy.localURL(link)
        let pieces = url.path.split(separator: "/")
        guard url.host == base.host, url.port == base.port, pieces.count == 3, pieces[0] == "auth", pieces[1] == "connect",
              Privacy.identifier(String(pieces[2])) != nil, url.query == nil else { throw TransportError.denied }
        let result = try await http.get(url)
        try Task.checkCancellation()
        guard let token = result["token"] as? String, !token.isEmpty, token.utf8.count < 8192 else { throw TransportError.authentication }
        try keychain.save(token, id: profile)
        if Task.isCancelled { try? keychain.delete(profile); throw CancellationError() }
    }
    public func disconnect() throws { generation = UUID(); http.cancel(); try keychain.delete(profile); ids = [] }
    private func get(_ path: String, query: [URLQueryItem] = []) async throws -> [String: Any] {
        guard TransportPolicy.allowGET(path, sessionIDs: ids) else { throw TransportError.denied }
        var parts = URLComponents(url: base, resolvingAgainstBaseURL: false)!; parts.path = path; parts.queryItems = query.isEmpty ? nil : query
        return try await http.get(parts.url!, token: keychain.read(profile))
    }
    public func reconcile() async throws -> OpenCodeSnapshot {
        let current = generation
        let info = try await get("/api/info")
        guard let version = info["version"] as? String, let pid = info["pid"] as? Int else { throw TransportError.malformed }
        guard version.hasPrefix("2.") else { throw TransportError.unsupported }
        let identity = "\(version):\(pid)"
        if serverIdentity != identity { serverIdentity = identity; runtime = UUID().uuidString }
        let active = try await get("/api/session/active")
        guard let activeRows = active["data"] as? [String: Any] else { throw TransportError.malformed }
        var cursor: String?, seen: Set<String> = [], rows: [AgentID: Agent] = [:], coverage: Coverage = .observed
        for page in 0..<20 {
            let object: [String: Any]
            do { object = try await get("/api/session", query: [URLQueryItem(name: "limit", value: "100")] + (cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? [])) }
            catch { if page == 0 { throw error }; coverage = .partial; break }
            let (agents, next) = try OpenCodeProjection.page(object, profile: profile, runtime: runtime, active: Set(activeRows.keys))
            for agent in agents {
                if rows[agent.id] != nil { coverage = .partial }
                rows[agent.id] = agent
            }
            guard let next else { cursor = nil; break }
            guard seen.insert(next).inserted else { coverage = .partial; break }
            cursor = next
            if page == 19 { coverage = .partial }
        }
        guard current == generation else { throw CancellationError() }
        ids = Set(rows.keys.map(\.local))
        if ids.count > 100 { coverage = .partial }
        // Pending content is discarded; only counts/categories affect display.
        for id in ids.sorted().prefix(100) {
            for type in ["permission", "form"] {
                do {
                    let response = try await get("/api/session/\(id)/\(type)")
                    if let pending = response["data"] as? [[String: Any]], !pending.isEmpty,
                       let key = rows.keys.first(where: { $0.local == id }) { rows[key]?.activity = .waiting }
                } catch TransportError.throttled(let hint) { throw TransportError.throttled(hint) }
                catch { coverage = .partial }
            }
        }
        guard current == generation else { throw CancellationError() }
        return OpenCodeSnapshot(agents: Array(rows.values), coverage: rows.isEmpty && coverage == .observed ? .empty : coverage)
    }
    public func events(invalidated: @escaping () -> Void) async throws {
        try await http.events(base.appendingPathComponent("api/event"), token: keychain.read(profile), invalidated: invalidated)
    }
}
