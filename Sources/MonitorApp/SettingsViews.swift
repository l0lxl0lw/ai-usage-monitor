import SwiftUI
import MonitorCore

struct SettingsViews: View {
    @ObservedObject var services: AppServices
    @State private var provider: Source = .codex
    @State private var alias = "Personal"
    @State private var home = NSString(string: "~/.codex").expandingTildeInPath
    @State private var pairing = ""
    @State private var consent = false
    @State private var orcaPath = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Local connections").font(.headline)
            Text("Demo and Live are separate. No source service, login, model turn, hook or external setting is started or changed automatically.").font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Codex / Claude account profiles") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Provider", selection: $provider) { Text("Codex").tag(Source.codex); Text("Claude").tag(Source.claude) }
                    TextField("Alias", text: $alias)
                    TextField("Existing absolute profile home", text: $home)
                    Text("Codex uses ~/.local/bin/codex (official 0.154.0) and the selected CODEX_HOME. Claude uses the selected CLAUDE_CONFIG_DIR for manual telemetry setup. Canonical home collisions are rejected; default logins are never swapped.").font(.caption)
                    Button("Add existing profile") {
                        do { try services.addProfile(Profile(source: provider, alias: alias, home: home)); services.message = "Profile added. Switch to Live and refresh Codex, or manually enable hooks." }
                        catch { services.message = "Invalid profile or duplicate canonical home" }
                    }
                    ForEach(services.profiles) { profile in
                        Text("\(profile.source.rawValue) / \(profile.alias)").fontWeight(.medium)
                        Text("Profile ID: \(profile.id.uuidString)").font(.caption).textSelection(.enabled)
                        if profile.source == .codex { Button("Read \(profile.alias) quota") { services.refresh(profile) } }
                        Text("Manual bridge: relay-bridge \(profile.source.rawValue) \(profile.id.uuidString) \(profile.source == .codex ? "0.154.0" : "documented")").font(.system(.caption2, design: .monospaced)).textSelection(.enabled)
                    }
                }.padding(.top, 8)
            }
            DisclosureGroup("Manual hooks and Claude statusline") {
                Text("Append command handlers alongside existing hooks; never replace settings. Select the bridge bundled in Relay.app/Contents/MacOS using its absolute, shell-quoted path. Codex 0.154.0 hooks.json definitions must be reviewed and trusted with the official /hooks UI. Changed hashes, disabled, untrusted or managed-policy-blocked hooks mean Not collecting. No trust bypass. See docs/integrations.md for events and reviewed snippets.").font(.caption)
                Text("Only future instrumentation is observed. Parent-session membership is not immediate nested ancestry. Claude quotas need an ordinary session's reported statusline rate_limits; idle freshness is not promised. Existing statusline rendering must be preserved. Relay never reads transcripts or subscription credentials.").font(.caption)
            }
            DisclosureGroup("OpenCode V2 explicit pairing") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Important: the paired token has broad service authority, NOT a read-only scope. Relay enforces a narrow metadata GET allowlist in its own code. Relay stores only its own token in Keychain. The already-running loopback server is not started by Relay.").font(.caption)
                    Toggle("I understand the token's broad authority", isOn: $consent)
                    SecureField("Loopback pairing link", text: $pairing)
                    Button("Pair to existing service") { services.pair(link: pairing); pairing = "" }.disabled(!consent)
                    Button("Cancel / disconnect") { services.disconnect(); pairing = "" }
                    Text("Re-pairing first disconnects the old connection. Disconnect, quit and next launch delete Relay's local tokens only, including leftovers from a prior exit. Connections are not restored after restart; pair again manually. Failed Keychain cleanup is reported and blocks replacement until retried. This does not stop the server, delete sessions or revoke the server-side token. No messages, context, config or credentials are read; no approvals are answered.").font(.caption)
                }.padding(.top, 8)
            }
            DisclosureGroup("Orca local metadata") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Absolute selected Orca executable", text: $orcaPath)
                    Button("Observe local metadata once") { services.observeOrca(executable: orcaPath) }
                    Text("Minimal local child environment; no ORCA_ENVIRONMENT or ORCA_PAIRING_CODE inheritance. PTY observations are partial, not task success. Workspace parents are not agent parents. Unverified nonempty workers remain unsupported.").font(.caption)
                }.padding(.top, 8)
            }
            Toggle("Show observed stopped agents", isOn: $services.showStopped)
            Text(services.message).font(.caption).foregroundStyle(.secondary)
            Text("Free and MIT-licensed · macOS 14+ build target. Runtime/accessibility, Intel/Universal, signing/notarization and provider eligibility are separate release gates; no release certification is claimed.").font(.caption2).foregroundStyle(.secondary)
            Button("Quit Relay") { services.shutdown(); NSApplication.shared.terminate(nil) }
        }.textFieldStyle(.roundedBorder)
    }
}
