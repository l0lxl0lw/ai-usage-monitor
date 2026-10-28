import Foundation
import SwiftUI
import MonitorCore
import MonitorAdapters

@MainActor final class AppServices: ObservableObject {
    @Published var mode: Mode = .demo
    @Published var revision = 0
    @Published var navigation = NavigationState()
    @Published var message = ""
    @Published var profiles: [Profile] = []
    @Published var showStopped = true
    let demo = MonitorStore(), live = MonitorStore()
    private let registry = try! ProfileRegistry()
    private let listener = HookListener()
    private var polling: [UUID: PollSchedule] = [:]
    private var jobs: [UUID: Task<CodexQuota, Error>] = [:]
    private var timer: Timer?
    private let hookRuntime = UUID().uuidString
    private let openCodeConnection = OpenCodeConnection()
    private var openCode: OpenCodeAdapter? { openCodeConnection.adapter }
    private var openCodeJob: Task<Void, Never>?
    private var eventsJob: Task<Void, Never>?
    private var orcaJob: Task<Void, Never>?
    private var connectionGeneration = UUID()
    var store: MonitorStore { mode == .demo ? demo : live }
    init() {
        DemoFixtures.populate(demo)
        do { try openCodeConnection.disconnect() }
        catch { message = "Keychain cleanup failed; retry Disconnect before pairing. No connection restored." }
        if let data = UserDefaults.standard.data(forKey: "Relay.profiles"), let saved = try? JSONDecoder().decode([Profile].self, from: data) {
            for profile in saved { try? addProfile(profile, persist: false) }
        }
        do {
            try listener.start { [weak self] message in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch message {
                    case .hook(let event):
                        guard self.profiles.contains(where: { $0.id == event.profile && $0.source == event.source }) else { return }
                        HookProjection.apply(event, store: self.live, runtime: self.hookRuntime)
                        self.live.sourceCoverage[event.source] = .partial
                    case .claudeQuota(let telemetry):
                        guard let profile = self.profiles.first(where: { $0.id == telemetry.profile && $0.source == .claude }) else { return }
                        var account = Account(id: profile.id, source: .claude, alias: profile.alias)
                        account.windows = telemetry.windows; account.observedAt = telemetry.received
                        account.coverage = telemetry.windows.isEmpty ? .missing : .observed
                        account.note = "Ordinary-session statusline · no idle polling; hooks are separate"
                        self.live.update(account)
                    }
                    self.revision += 1
                }
            }
        } catch { message = "Hook relay unavailable · no events collected" }
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshDue() }
        }
    }
    func addProfile(_ profile: Profile, persist: Bool = true) throws {
        guard profile.home.hasPrefix("/"), !profile.alias.isEmpty else { throw ModelError.invalidInput }
        try registry.add(profile); profiles = registry.profiles
        live.update(Account(id: profile.id, source: profile.source, alias: profile.alias))
        live.sourceCoverage[profile.source] = .notCollecting
        if persist { UserDefaults.standard.set(try JSONEncoder().encode(profiles), forKey: "Relay.profiles") }
        revision += 1
    }
    func changeMode(_ next: Mode) { mode = next; navigation = NavigationState(); revision += 1 }
    func refreshDue() {
        guard mode == .live else { return }
        live.expireMeasurements(before: Date().addingTimeInterval(-180))
        for profile in profiles where profile.source == .codex { refresh(profile) }
    }
    func refresh(_ profile: Profile) {
        var schedule = polling[profile.id] ?? PollSchedule()
        guard schedule.begin(now: Date()) else { message = "Refresh is single-flight and limited to once per minute (longer after failures)."; return }
        polling[profile.id] = schedule
        let generation = live.generations[profile.id] ?? live.restart(profile.id)
        let executable = NSString(string: "~/.local/bin/codex").expandingTildeInPath
        let task = Task.detached { () throws -> CodexQuota in
            let client = try CodexRPC(executable: executable, home: profile.canonicalHome)
            defer { client.stop() }
            return try client.read()
        }
        jobs[profile.id] = task
        Task {
            do {
                let quota = try await task.value
                guard live.generations[profile.id] == generation else { return }
                try registry.checkIdentity(quota.identity, profile: profile.id)
                var account = Account(id: profile.id, source: .codex, alias: profile.alias)
                account.windows = quota.windows; account.credits = quota.credits; account.observedAt = Date()
                account.coverage = .observed; account.note = "Official Codex 0.154.0 app-server · owned helper stopped"
                live.update(account); live.sourceCoverage[.codex] = .partial
                polling[profile.id]?.finish(now: Date(), success: true)
                message = "Codex quota measured. Activity requires separately trusted hooks."
            } catch {
                guard live.generations[profile.id] == generation else { return }
                var retryAfter: Double?
                if case TransportError.throttled(let hint) = error { retryAfter = hint }
                live.markFailure(profile.id); polling[profile.id]?.finish(now: Date(), success: false, retryAfter: retryAfter)
                message = "Codex read unavailable or identity changed. Last-known values are not renewed allowance."
                if case TransportError.unsupported = error, var account = live.accounts[profile.id] {
                    account.coverage = .unsupported; account.note = "Unsupported CLI version · requires reviewed Codex 0.154.0 wire contract"
                    live.update(account); live.sourceCoverage[.codex] = .unsupported
                }
            }
            jobs[profile.id] = nil; revision += 1
        }
    }
    func cancel(_ profile: Profile) {
        jobs[profile.id]?.cancel(); jobs[profile.id] = nil; polling[profile.id]?.cancel()
        _ = live.restart(profile.id); live.markFailure(profile.id); revision += 1
    }
    func pair(link: String) {
        guard openCodeJob == nil else { return }
        eventsJob?.cancel(); eventsJob = nil; openCodeNext = .distantPast
        let generation = UUID(); connectionGeneration = generation
        openCodeJob = Task { [self] in
            defer { if connectionGeneration == generation { openCodeJob = nil }; revision += 1 }
            do {
                try await openCodeConnection.pair(link: link)
                guard !Task.isCancelled, connectionGeneration == generation, let adapter = openCode else { throw CancellationError() }
                await reconcileOpenCode()
                guard connectionGeneration == generation, openCode === adapter, !Task.isCancelled else { return }
                eventsJob = Task {
                    while !Task.isCancelled && connectionGeneration == generation {
                        do { try await adapter.events { [weak self] in Task { @MainActor [weak self] in await self?.reconcileOpenCode() } } }
                        catch { if connectionGeneration == generation { live.sourceCoverage[.opencode] = .stale; revision += 1 } }
                        try? await Task.sleep(for: .seconds(10))
                        if !Task.isCancelled && connectionGeneration == generation { await reconcileOpenCode() }
                    }
                }
            } catch { if connectionGeneration == generation { live.sourceCoverage[.opencode] = .notCollecting; message = "OpenCode pairing unavailable or cancelled · cleanup may need Disconnect retry · no service started" } }
        }
    }
    private var reconciling = false
    private var openCodeNext = Date.distantPast
    func reconcileOpenCode() async {
        guard let adapter = openCode, !reconciling, Date() >= openCodeNext else { return }; reconciling = true
        defer { reconciling = false; revision += 1 }
        do {
            let snapshot = try await adapter.reconcile()
            guard openCode === adapter else { return }
            live.reconcile(snapshot.agents, source: .opencode, profile: adapter.profile)
            live.sourceCoverage[.opencode] = snapshot.coverage
            openCodeNext = Date().addingTimeInterval(1)
            message = "OpenCode metadata observed · coverage is process-local"
        } catch {
            if openCode === adapter {
                if case TransportError.throttled(let hint) = error { openCodeNext = Date().addingTimeInterval(min(3600, max(60, hint ?? 60))) }
                if case TransportError.unsupported = error { live.sourceCoverage[.opencode] = .unsupported }
                else { live.sourceCoverage[.opencode] = .stale }
            }
        }
    }
    func disconnect() {
        connectionGeneration = UUID()
        openCodeNext = .distantPast
        openCodeJob?.cancel(); openCodeJob = nil; eventsJob?.cancel(); eventsJob = nil
        do { try openCodeConnection.disconnect(); message = "Relay tokens deleted locally. Server and server-side session are unchanged." }
        catch { message = "Keychain deletion failed; disconnect cleanup is incomplete." }
        live.sourceCoverage[.opencode] = .notCollecting; revision += 1
    }
    private let orcaProfile = UUID()
    func observeOrca(executable: String) {
        guard orcaJob == nil else { return }
        let profile = orcaProfile
        orcaJob = Task {
            defer { orcaJob = nil; revision += 1 }
            do {
                let snapshot = try await Task.detached { try OrcaAdapter().read(executable: executable, profile: profile) }.value
                live.reconcile(snapshot.agents, source: .orca, profile: profile)
                live.sourceCoverage[.orca] = snapshot.coverage; message = "Orca metadata · \(snapshot.runCount) runs · \(snapshot.workerCoverage.rawValue) worker coverage; omitted hosts: \(snapshot.omittedHosts)"
            } catch { live.sourceCoverage[.orca] = .failed; message = "Orca metadata unavailable · no runtime was started" }
        }
    }
    func shutdown() {
        timer?.invalidate(); jobs.values.forEach { $0.cancel() }; openCodeJob?.cancel(); eventsJob?.cancel(); orcaJob?.cancel(); listener.stop()
        do { try openCodeConnection.disconnect() }
        catch { message = "Keychain cleanup incomplete; Relay will retry its owned-token cleanup at next launch." }
    }
}
