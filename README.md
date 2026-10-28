# Relay

A free, MIT-licensed native macOS menu-bar usage and agent monitor. Everything,
including connections and settings, stays inside one popover. No webview,
dashboard window, third-party production dependency or source-service autostart.

## Build and check

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

Relay starts in **Demo**, visibly labeled synthetic. Live is a separate, initially
empty in-memory store and never falls back to demo data after a failed read.
Use Connections & settings to add existing Codex/Claude profiles, manually wire
future lifecycle telemetry, explicitly pair OpenCode V2, or observe local Orca
metadata. No configuration outside Relay is edited automatically.

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
