# Relay

A free, MIT-licensed native macOS menu-bar usage and agent monitor. Everything,
including connections and settings, stays inside one popover. No webview,
dashboard window, third-party production dependency or source-service autostart.

## Install the ready-built preview

**macOS 14+ on Apple Silicon. No Xcode, Homebrew or Python needed to install.**
The app is ad-hoc signed (no Developer ID) and **not notarized**. Gatekeeper may
block an internet-downloaded app; installation does not certify that it will launch
on a clean Mac. The installer does not launch it or bypass macOS security.

No preview tag/release has been published by this PR. Once this head's CI succeeds,
download its `Relay-v0.1.0-preview.1-<source SHA>-macos-arm64` artifact from the
[PR checks](https://github.com/l0lxl0lw/ai-usage-monitor/pull/2/checks) → CI → native
→ Artifacts. The artifact contains the ready-built ZIP and SHA256 sidecar, not a
DMG. Availability is conditional on that run completing; old-head artifacts are
not proof for this source. See [install details](docs/install.md) for checking it.

**Future tagged preview only:** after a separately authorized operator publishes
`v0.1.0-preview.1` and its assets, this one line downloads the complete tag-pinned
installer before running it. It is **not a working release-download route yet**:

```sh
/bin/sh -c 'set -eu; v=v0.1.0-preview.1; d=$(mktemp -d); cleanup() { rm -rf -- "$d"; }; trap cleanup 0; trap "exit 1" 1 2 15; (ulimit -f 1024; exec /usr/bin/curl --fail --location --proto =https --proto-redir =https --tlsv1.2 --connect-timeout 15 --max-time 120 --max-filesize 1048576 --output "$d/install-preview.sh" "https://raw.githubusercontent.com/l0lxl0lw/ai-usage-monitor/$v/scripts/install-preview.sh"); test "$(wc -c < "$d/install-preview.sh")" -le 1048576; /bin/sh "$d/install-preview.sh" "$v"'
```

It installs into `~/Applications/Relay.app` and refuses any existing `Relay.app`,
including a dangling symlink. There is no automatic update or overwrite. The ZIP
checksum checks bytes within the selected GitHub trust channel, not Apple identity.

## Build and check (developers)

Requires macOS, full Xcode selected with `xcode-select`, Swift 5.10+ and Python 3.
Node is used only for the preserved mock's JavaScript syntax checks.

```sh
python3 scripts/build-app.py --configuration release --output build/Relay.app
open build/Relay.app
python3 scripts/ci.py
```

The bundle is locally ad-hoc signed, **not notarized for public distribution**.
`scripts/ci.py` runs every command in `.opencode/workflow/checks.json`, the same
manifest used by delivery verification. XCTest evidence must match the committed
exact inventory; empty, skipped, missing or foreign-only tests cannot pass.
Tests use synthetic wire fixtures and real local process, HTTP and Unix transports;
they never connect to your provider accounts or start a source service.

## First use

Relay starts **Live-only**, empty until you explicitly save existing profiles.
There is no sample mode, hidden sample flag or automatic login discovery. Valid
saved Codex profiles refresh automatically at launch through the same bounded,
per-profile single-flight/backoff path as timer and manual reads. Claude remains
ordinary-session-driven; OpenCode pairing and Orca observation remain explicit.
Failed reads never fall back to synthetic data or fabricated zero allowance.
Use Connections & settings to add existing Codex/Claude profiles, manually wire
future lifecycle telemetry, explicitly pair OpenCode V2, or observe local Orca
metadata. No configuration outside Relay is edited automatically.

For a local source install, build as above and open that exact `build/Relay.app`.
Ready-built packaging and the stock-macOS installer are separate from source builds;
there is no DMG, notarized download or automatic launch/security bypass.

Developers can build `swift build -c release --product NativeHarness` and run
the resulting `NativeHarness --show` for synthetic-only UI checks. It shares
the exact production presentation library, uses no provider accounts/listener,
and is never linked or copied into Relay.app. Its observations/captures are not
Live-source certification. The production build selects only Relay/relay-bridge;
BUNDLE audits target dependencies, source/resource inventory and binary canaries.

Codex quota reads require the official `~/.local/bin/codex` **0.154.0** and an
already authenticated profile home. The official CLI owns its credentials and
may refresh its own state. Relay performs initialization, account metadata and
quota reads only, never an inference turn or login/logout. Profile homes and
stable IDs isolate accounts; quota buckets are not accounts. Claude quota
telemetry is credential-free and ordinary-session-driven, not idle polling.

Percentages mean **used**, not remaining. Missing is not zero or unlimited;
expired resets do not create allowance. Credits are not assumed to be dollars.
Source coverage is deliberately partial: instrumentation observes future events,
not transcripts or complete historical sessions. Stop, absence, PTYs and silence
never prove global success. Titles are tool-provided, local and memory-only.

See [integration setup](docs/integrations.md), [acceptance](docs/acceptance.md),
[release gates](docs/release-gates.md), and [public-source research](docs/research/provider-integrations.md).
The approved visual prototype is preserved in `mock/`; it is not shipped in the app.

## Privacy

No prompts, transcripts, tool contents, provider tokens or generated summaries are
collected. Observation history/titles have no persistence or export interface.
Only profile configuration/aliases persist in preferences; Relay's own broad-scope
OpenCode pairing token is stored in the macOS Keychain. Disconnect affects Relay
locally, not the server or its sessions. The short-lived hook bridge drops events
when the app is absent, never spools them or starts an app/agent.
