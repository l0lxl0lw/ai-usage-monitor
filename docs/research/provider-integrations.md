# Provider integration evidence

Public-source research snapshot, reviewed 2026-10-28. This document records interfaces and limitations, not executed native-app verification or provider approval. The approved interface prototype is in `mock/`; it uses fictional data only.

## Codex subscription quotas

The official [app-server protocol](https://developers.openai.com/codex/app-server/) exposes `account/rateLimits/read`. A client initializes a JSONL stdio connection and sends `initialized` before account reads. Quota reads do not require creating a conversation or running a model turn.

Version-pinned public source for Codex 0.154.0, commit `6b9826e3aa83b1a5947db50f4332cb9c65f1b340`:

- [GetAccountRateLimitsParams](https://github.com/openai/codex/blob/6b9826e3aa83b1a5947db50f4332cb9c65f1b340/codex-rs/app-server-protocol/schema/typescript/v2/GetAccountRateLimitsParams.ts): `excludeResetCreditDetails` explicitly supports background polling; passive readers must not opt into `supportsLunaReserve` experiment behavior.
- [GetAccountRateLimitsResponse](https://github.com/openai/codex/blob/6b9826e3aa83b1a5947db50f4332cb9c65f1b340/codex-rs/app-server-protocol/schema/typescript/v2/GetAccountRateLimitsResponse.ts): backward-compatible quota, limit-ID bucket map, nullable account identity and ordinary-usage permission. Buckets are not accounts.
- [RateLimitWindow](https://github.com/openai/codex/blob/6b9826e3aa83b1a5947db50f4332cb9c65f1b340/codex-rs/app-server-protocol/schema/typescript/v2/RateLimitWindow.ts): `usedPercent`, nullable `windowDurationMins`, nullable `resetsAt` in Unix seconds.
- [RateLimitSnapshot](https://github.com/openai/codex/blob/6b9826e3aa83b1a5947db50f4332cb9c65f1b340/codex-rs/app-server-protocol/schema/typescript/v2/RateLimitSnapshot.ts): primary/secondary windows, credits, plan and spend-control fields are independently optional/nullable.
- [Account processor](https://github.com/openai/codex/blob/6b9826e3aa83b1a5947db50f4332cb9c65f1b340/codex-rs/app-server/src/request_processors/account_processor.rs#L1129-L1169): this is an authenticated backend operation, not an unauthenticated local counter.

Window slots must not be hardcoded as five-hour/weekly. [Current pricing documentation](https://developers.openai.com/codex/pricing/) says Pro plans have no five-hour limit. Missing data is not zero or unlimited; reaching a reset timestamp is not proof of renewed permission. Credit balances are strings and are not automatically dollars.

[Codex authentication](https://developers.openai.com/codex/auth/) documents `CODEX_HOME` and official credential-storage modes. Separate canonical homes isolate profiles; the official CLI owns its login and refresh lifecycle. A monitor must not copy refresh tokens between homes or change a user's default CLI account. An official helper may refresh credentials or write its own state even when the requested RPC is logically read-only.

## Codex activity is a separate integration

The [official lifecycle-hook documentation](https://developers.openai.com/codex/hooks.md) describes command hooks in `hooks.json` alongside configuration layers, including `~/.codex/hooks.json`. Matching sources merge. Non-managed definitions must be reviewed and trusted through `/hooks`; changed hashes are skipped until trusted. Never bypass hook trust for monitoring.

The same Codex 0.154.0 source revision contains [generated hook input schemas](https://github.com/openai/codex/tree/6b9826e3aa83b1a5947db50f4332cb9c65f1b340/codex-rs/hooks/schema/generated) for `SessionStart`, `SessionEnd`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PermissionRequest`, `Stop`, `Interrupt`, `SubagentStart` and `SubagentStop`.

Relevant projected fields are event kind, `session_id`, `turn_id` where present, child `agent_id`/`agent_type`, model slug, sanitized lifecycle categories and `stop_hook_active`. Prompts, transcript paths, assistant messages, tool arguments/results and inherited environment must not pass to monitoring storage or logs. These inputs do not provide a safe prompt-derived title fallback.

The hook documentation explicitly says subagent hooks use the parent **session** ID. That establishes session membership, not a reliable immediate-parent edge for every nested agent. Repeated starts can reactivate existing identities. Stop/interrupt events do not establish completion of a persistent session or its entire swarm. Missing, concurrent and out-of-order observations need conservative last-known/unknown states.

Pinned [stop-hook runtime handling](https://github.com/openai/codex/blob/6b9826e3aa83b1a5947db50f4332cb9c65f1b340/codex-rs/hooks/src/events/stop.rs#L250-L285) accepts exit code zero and empty stdout without a control decision. A telemetry relay must not emit model context, approvals, continuation requests or blocking output.

App-server `thread/loaded/list` and live thread status describe that server's runtime, not a machine-wide bus for independent CLI sessions. No arbitrary thread resume/attachment is justified merely to observe activity. Enabling hooks does not replay prior events.

## Claude Code quotas and lifecycle

[Statusline documentation](https://code.claude.com/docs/en/statusline) exposes `rate_limits.five_hour` and `rate_limits.seven_day`, each with `used_percentage` and `resets_at` in Unix seconds. Documented subscription fields apply to Pro/Max after a session's first API response. Windows may be independently absent. Re-running a statusline does not guarantee a fresh server quota measurement while idle.

[Authentication documentation](https://code.claude.com/docs/en/authentication) documents distinct `CLAUDE_CONFIG_DIR` profiles and macOS Keychain isolation by configuration directory. A credential-free statusline export can label an explicitly configured profile without moving subscription credentials into the monitor.

[Hook documentation](https://code.claude.com/docs/en/hooks) provides session and subagent lifecycle events, but child IDs on subagent events are not a documented universal immediate-parent-agent field. Starts can represent resumed work; Stop can coexist with continuations/background work. There is no durable replay or exactly-once delivery guarantee. Monitoring must preserve existing hook/statusline configuration and must not read referenced transcripts.

[Legal and credential-use documentation](https://code.claude.com/docs/en/legal-and-compliance#authentication-and-credential-use) restricts third-party Claude login and credential/session-token handling. Existing projects' OAuth/cookie implementations are not proof of permission. Credential-free opt-in lifecycle/statusline export avoids collecting subscription tokens, but is not a claim of legal certification.

## OpenCode V2 metadata

Sources: [V2 API](https://opencode.ai/v2/docs/api), [OpenAPI](https://opencode.ai/v2/openapi.json), [client](https://opencode.ai/v2/docs/build/client), [pairing/authentication](https://opencode.ai/v2/docs/cli/web).

- Explicit user pairing: `GET /auth/connect/{code}` with JSON acceptance returns `{token}` to use as Basic-auth password with username `opencode`. Pairing codes are single-use and short-lived; paired sessions are documented as lasting 30 days.
- This token has broad service authority, not a server-enforced metadata-only scope. A monitor must disclose that authority and enforce its own narrow GET allowlist. Deleting its local token is not server-side revocation.
- `GET /api/info` provides version/PID, not a durable server-instance UUID.
- `GET /api/session` is paginated with `cursor.next`; default inventory is bounded. Session `parentID`, fork provenance, prior outcome and current activity are different concepts.
- `GET /api/session/active` describes foreground execution owned by that process. Absence does not establish successful completion or complete background coverage.
- Pending permission/form reads may establish pending categories; retain only needed IDs/counts, not request contents.
- `GET /api/event` is live-only, with no replay or automatic reconnection. The published schema does not fully describe native payload objects; events can invalidate REST snapshots rather than drive invented reducers.
- Model/provider selection does not identify the subscription account that paid for a session.

Use an explicit loopback connection, private network session and app-owned Keychain token. Reject redirects and credential-bearing/non-loopback URLs. Do not inspect credential/config/message/context endpoints, private registration files or databases. `Service.discover()` is documented not to start a server; `Service.ensure()` and the default API CLI discovery path may do so and are not appropriate passive-monitor fallbacks.

## Orca observation boundary

The user-installed Orca CLI exposes read-only workspace and orchestration snapshots. Version-specific command help and `agent-context` define inputs, not a comprehensive output schema. A monitor must capability-check and normalize actual metadata shapes without collecting prompts, terminal previews, objectives, task specifications, tool inputs or messages.

Workspace summaries can expose agent state and per-pane identity alongside workspace identity, runtime metadata and partial-host/truncation indicators. Keep those observations separate from workspace parentage. A workspace parent, task dependency, supervised creator dispatch and immediate agent parent are not interchangeable relationships.

For supervised workers, documented `worker-list` paging uses `page.hasMore` and opaque `page.nextCursor`; use explicit Run scope. Agent liveness and PTY liveness are different. Missing observations must not become completed work. Unverified nonempty worker shapes must remain unsupported, not be filled in from assumptions.

Invoke only approved commands through an absolute executable and separate argument array. Use an explicit minimal child environment; exclude `ORCA_ENVIRONMENT`, `ORCA_PAIRING_CODE` and other unapproved inherited targeting/authentication selectors. No shell interpolation, mailbox consumption, terminal reads, returned action execution, or automatic runtime launch is needed.

## Existing tracker implementation precedents

These are source-level observations, not proof of runtime success or provider endorsement. All four repositories report MIT licensing; reused code requires appropriate attribution and license notices.

### CodexBar

Inspected revision `5f93dc3068b3bee3f8753f3772614cc2949c335d`:

- [Official CLI RPC fetch](https://github.com/steipete/CodexBar/blob/5f93dc3068b3bee3f8753f3772614cc2949c335d/Sources/CodexBarCore/UsageFetcher.swift#L1152-L1234) launches `codex -s read-only -a never app-server` and performs initialization plus account/quota reads without starting a thread or model turn. This is the selected standalone quota mechanism to validate, not code to copy blindly.
- [Source strategy resolver](https://github.com/steipete/CodexBar/blob/5f93dc3068b3bee3f8753f3772614cc2949c335d/Sources/CodexBarCore/Providers/Codex/CodexProviderDescriptor.swift#L152-L173) distinguishes PAT, OAuth and CLI paths. Auto mode is not a guarantee of credential-free operation or isolated-account behavior.
- [Agent model](https://github.com/steipete/CodexBar/blob/5f93dc3068b3bee3f8753f3772614cc2949c335d/Sources/CodexBarCore/AgentSession.swift#L22-L39) and [activity heuristic](https://github.com/steipete/CodexBar/blob/5f93dc3068b3bee3f8753f3772614cc2949c335d/Sources/CodexBarCore/AgentSession.swift#L83-L107) do not establish the explicit swarm ancestry and lifecycle certainty requested here.

### OpenUsage

Inspected revision `7129ab29aa5ff31bae93f86f13aff497c6bd5e0a`:

- [Architecture](https://github.com/robinebers/openusage/blob/7129ab29aa5ff31bae93f86f13aff497c6bd5e0a/docs/architecture.md#L44-L55) uses one runtime per account with independent credential ownership and refresh state. Its account-isolation pattern is useful even without adopting its authentication flow.
- [Codex client](https://github.com/robinebers/openusage/blob/7129ab29aa5ff31bae93f86f13aff497c6bd5e0a/Sources/OpenUsage/Providers/Codex/CodexUsageClient.swift#L53-L78) directly reads an authenticated backend endpoint. This is not the selected Relay credential-handling path.
- [CLI contract](https://github.com/robinebers/openusage/blob/7129ab29aa5ff31bae93f86f13aff497c6bd5e0a/docs/cli.md) exports cached `openusage.limits.v1` data, including per-account freshness, without refreshing, opening Keychain, signing in or launching the app. It is a possible optional companion-data source, not a required dependency in the approved standalone plan.

### Usage4Claude

Inspected revision `e0030f1ada6014eadce3c58c785ecb4039a74e52`:

- [Codex service](https://github.com/f-is-h/Usage4Claude/blob/e0030f1ada6014eadce3c58c785ecb4039a74e52/Usage4Claude/Services/CodexAPIService.swift#L379-L384) performs a direct authenticated usage request; other portions own OAuth/session-token refresh.
- [Account store](https://github.com/f-is-h/Usage4Claude/blob/e0030f1ada6014eadce3c58c785ecb4039a74e52/Usage4Claude/Models/AccountStore.swift#L29-L64) maintains selected account state. Storing multiple accounts is not by itself proof of simultaneous monitoring of all of them.

### Claude Usage Tracker

Inspected revision `588775e4540757443691fa1bcb33457315e05f86`:

- [Codex authentication service](https://github.com/hamed-elfayome/Claude-Usage-Tracker/blob/588775e4540757443691fa1bcb33457315e05f86/Claude%20Usage/Shared/Services/Providers/Codex/CodexAuthService.swift#L159-L177) reads/refreshes CLI credentials and discusses refresh-token rotation conflicts. Relay will not adopt that credential-extraction approach.

## Outstanding validation and release gates

No successful authenticated Codex quota read or native-app GUI result is established by this research. A real, authorized Codex read must precede implementation and must be verified again through the implemented app before delivery can pass. Source compatibility, trusted hook configuration and multi-account isolation need their own tests; mocks must not masquerade as live proof.

The [OpenAI app-server authentication notice](https://developers.openai.com/codex/app-server/#auth-endpoints) explicitly prohibits commercial/hosted usage and provides continuation language for existing local/open-source integrations. Its application to this exact new public monitor remains unsettled. [Sign in with ChatGPT](https://developers.openai.com/siwc/) documents inference access, not a demonstrated substitute for Codex-wide remaining-quota telemetry. Neither a successful request nor another tracker establishes provider approval.

Public binary distribution is separate: provider eligibility, signing/notarization, clean-Mac Gatekeeper, actual macOS 14 runtime, accessibility, architecture claims and broader live-source/multi-account certification remain release gates. No public binary release or automatic PR merge is part of the approved development delivery.
