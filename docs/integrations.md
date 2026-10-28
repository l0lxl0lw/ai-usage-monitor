# Local integration setup

All setup is manual and opt-in. Review commands, preserve existing settings and
handlers, and use absolute paths. Relay never installs hooks, trusts definitions,
changes a default login, starts a source service or sends an agent control reply.

## Profiles and Codex quotas

Add each existing Codex or Claude home separately in the popover. Relay assigns a
stable UUID. Canonical home collisions within one source are rejected. Do not copy
credentials into Relay or switch CLI default logins to simulate multiple accounts.
Use an existing independently authenticated `CODEX_HOME` for each Codex profile.
The quota executable is the official `~/.local/bin/codex` 0.154.0; other versions
are refused until their wire contract is reviewed. The owned app-server helper
runs `-s read-only -a never app-server`, initializes stdio, reads account metadata
and `account/rateLimits/read` with `excludeResetCreditDetails: true`. It is stopped
and reaped afterwards. No reserve, models, threads, turns, login or logout requests.

Polling is single-flight per profile, no more than once a minute, with exponential
failure backoff up to one hour. Cancellation invalidates that profile generation.
Last-known values remain marked stale; passed resets never turn them into zero.
Multiple real-account certification remains a separate release gate.

## Codex future lifecycle observations

Pinned source: Codex 0.154.0, revision
`6b9826e3aa83b1a5947db50f4332cb9c65f1b340`, generated command hook input schemas.
The activity interface is separate from the quota app-server, not a global bus.

For each supported event below, append a command handler to that event's **existing**
handler list in the selected profile's hooks.json. Do not replace the file. Example
handler (replace the synthetic UUID and installation path):

```json
{
  "type": "command",
  "command": "'/Applications/Relay.app/Contents/MacOS/relay-bridge' codex 00000000-0000-0000-0000-000000000001 0.154.0"
}
```

Events: `SessionStart`, `SessionEnd`, `UserPromptSubmit`, `PreToolUse`,
`PostToolUse`, `PermissionRequest`, `Stop`, `Interrupt`, `SubagentStart`,
`SubagentStop`. Use the official `/hooks` UI to review and trust the exact handler
definition/hash. Changed, disabled, untrusted or managed-policy-blocked definitions
mean **Not collecting**. Never bypass trust. No existing-session replay/resume is
promised. The bridge emits no stdout/stderr/control output and always exits zero;
the pinned Stop contract accepts empty output. Unsupported versions drop collection.

SessionStart only registers observation. Turn and agent IDs correlate observations;
session membership does not establish immediate grandchild ancestry. Repeated starts
reactivate an observation; unmatched ends and Stop continuations leave uncertainty.
PermissionRequest records a category, never answers it. No hook event alone means
the whole session or swarm succeeded. Missing coverage remains partial.

## Claude hooks and ordinary-session statusline

Use documented Claude command hooks in the selected `CLAUDE_CONFIG_DIR`. Append
handlers alongside existing handlers, including existing matchers, not over them:

```json
{
  "type": "command",
  "command": "'/Applications/Relay.app/Contents/MacOS/relay-bridge' claude 00000000-0000-0000-0000-000000000002 documented"
}
```

Select only events supported by your installed version; SessionStart/SessionEnd,
UserPromptSubmit, PreToolUse/PostToolUse, PermissionRequest, Stop and
SubagentStart/SubagentStop are the reviewed lifecycle categories. Missing or
disabled hooks cannot be detected retroactively. No transcript discovery or raw
prompt-derived title fallback exists.

Claude quotas use optional ordinary-session statusline `rate_limits.five_hour`
and `rate_limits.seven_day`, `used_percentage` and epoch-second `resets_at` fields.
Absent fields mean unavailable, not zero; idle freshness is not guaranteed. Relay
does not read subscription credentials. In your **existing renderer**, after it
has read stdin into `original_bytes`, add a best-effort call like this while
leaving all original rendering/output code intact:

```python
try:
    subprocess.run(
        ['/Applications/Relay.app/Contents/MacOS/relay-bridge',
         'claude-statusline', '00000000-0000-0000-0000-000000000002', 'documented'],
        input=original_bytes, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        timeout=0.25, check=False)
except (OSError, subprocess.TimeoutExpired):
    pass
# Continue the existing renderer unchanged. Do not replace it with relay-bridge.
```

Import Python's `subprocess` in that renderer. Review this integration yourself;
Relay never edits it. Only the allowlisted quota fields enter IPC. The bridge's
150 ms monotonic deadline starts before stdin; frames are limited to 64 KiB.

## OpenCode V2

Start/choose your service yourself. In the popover, read and acknowledge the
disclosure **before** supplying the pairing link. The returned token has broad
authority, **not read-only scope**. Relay enforces its own narrow GET restriction.
Only explicit HTTP loopback IPs with ports are accepted; redirects, userinfo,
off-host addresses and malformed pairing paths are rejected. No ambient token/PAT.

Relay redeems `/auth/connect/{code}` with JSON Accept and stores only its own
connection token in Keychain (`WhenUnlockedThisDeviceOnly`). Subsequent Basic auth
is `opencode:token`. Allowed metadata GETs: `/api/info`, `/api/session`,
`/api/session/active`, `/api/event`, and known-ID `/api/session/{id}/permission`
and `/form`. No messages/context/config/provider/credentials or reply routes.
Pending payload contents are discarded; only presence affects Needs input.

REST pages own state; SSE only invalidates it and EOF marks observation stale.
Page/cursor bounds and generation checks prevent loops/late publication. Failed
later pages remain partial, absence means unknown, not success. Runtime identity
changes create a new namespace. The source is process-local, not universal history.
Re-pairing first disconnects the old connection. Cancel/disconnect, quit and next
launch delete **Relay's local** Keychain tokens, including leftovers from an
unclean exit under Relay's own service identifier. Connections are not restored
after restart: pair again manually. Cleanup failure is reported and blocks
replacement until retried; it is never reported as successful deletion. This does
not stop the service, delete server sessions or revoke server tokens. Keychain
denial/expiry pauses observation. No live-pair certification is claimed from
synthetic tests.

## Orca

Select an absolute local executable in the popover, then explicitly Observe.
Relay uses argv, not a shell: `worktree ps --json`, bounded
`orchestration run-list --limit 20 --json`, and explicit-run
`orchestration worker-list --run ID --limit 100 --json`.
Its child environment contains only HOME, TMPDIR, system PATH and LANG. Inherited
ORCA_ENVIRONMENT, ORCA_PAIRING_CODE and other selectors/authentication are excluded.
No server/runtime autostart fallback, terminal output, mailbox, task-body or action
commands are used. A missing runtime means unavailable.

Runtime, host, repository and workspace-instance identities namespace PTY metadata.
Workspace parents, task dependencies and unverified pane-parent semantics are not
agent edges. Run IDs are counted, objectives discarded. Only the verified **empty**
worker envelope is decoded; nonempty/unknown workers are explicitly unsupported,
not guessed or combined with PTY liveness. Omitted hosts and coverage stay partial.

## Privacy boundaries

The app-owned Unix relay uses a 0700 directory and 0600 socket, lstat ownership,
type/symlink and peer UID checks. No durable spool or autostart. Titles and history
are memory-only. Prompt/transcript paths, assistant text, arbitrary errors,
tool data and unknown content never enter projected relay messages. The app's
ring/dedup storage is bounded. No title/path/model-based cross-source identity merge.
