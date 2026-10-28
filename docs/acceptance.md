# Acceptance and evidence boundaries

Automated checks are defined in `.opencode/workflow/checks.json`. BUILD and BUNDLE
prove a reproducible locally signed accessory bundle/deployment target, not runtime
certification. CORE/QUOTA/ADAPTERS/POLICY/PRIVACY/NAV exercise conservative state,
profile isolation, quotas, navigation and the process/HTTP/Unix transports using
synthetic fixtures. RUNNER rejects false XCTest success; MOCK syntax-checks the
preserved prototype. All checks must pass with no skipped/missing required proof.

The exact approved plan and runner receipt on issue #1 are the delivery evidence;
this document does not assert manual acceptance before it has been observed.

Required manual scenarios on the current built source:

1. M-GUI: one status item/popover; Usage/account/Agents/details and reported
   parent/child/account crosslinks; search/project/state/collapse matching counts;
   backstack and scroll/focus; Escape/back/close/reopen; height constrained to screen.
   Persistent captures may contain synthetic demo data only.
2. M-CODEX: approved official binary/version/hash and privately pseudonymized
   existing profile; usable real quota/reset read before native implementation,
   repeated through built adapter and Live UI; no inference/login/token extraction;
   owned helper stopped/reaped. No raw response, identity or token in public proof.
3. M-SETUP: inspect native disclosure before pairing and both manual telemetry
   snippets; preserve existing handlers/rendering and official trust, no external
   settings mutation or control replies. Broad token authority and local-only
   disconnect semantics must be explicit.
4. M-PUBLIC: inspect the complete proposed public source/CI/license/docs, exclude
   private captures/probes/config/local skills and false release claims. Fresh
   independent review remains required before publication.

The runner binds source/environment/log fingerprints; manually observed external
state must be described separately and never fabricated from compilation/fixtures.

## Historical native observations, 2026-10-28 (before repair 1)

Observed locally on macOS 26.6.2 (25G83), Xcode 27.1 (27A9275), arm64.
This is not macOS 14, Intel/Universal or accessibility certification.
The observed release executable SHA-256 was
`9517097804ed5df5bfaaed56ee1811a99b105f15714dd844dd5add54b21f74c0`;
bridge SHA-256
`d6a916aaecf8f40d1ee592d356fa0be1ec3caa0d0f587ba8443a5de371170343`.

- **M-GUI:** one status item and one popover; outer native surface 446 × 686
  (420 × 660 content), within the current screen's 1320-point available height.
  Observed Usage → Codex/Work → root → child → grandchild → reported parent →
  account; six Escape steps restored Usage's native scroll fraction from 0.8 to
  approximately 0.799. Agents displayed parent before child before grandchild.
  Collapse hid descendants without changing the matching count. Searching
  “Keyboard” yielded one match with two ancestor-context rows, even while the
  ancestor was collapsed. The working-state intersection yielded zero, stopped
  yielded one, and selecting docs-site yielded zero. Detail/Back and
  settings/Back retained the filters. Tab focused search; Escape closed the
  root; Close left no product window; status-item reopen retained filters.
  Private persistent captures contain synthetic Demo data only.
- **M-CODEX, repeated current proof:** an existing local profile (pseudonym A),
  official Codex 0.154.0, binary SHA-256
  `4f85982624b3898c8991cb80c0981b2aa71070e3537046c9a95950318a95afcc`.
  The repeated initialized/account/quota preflight succeeded at 20:41 UTC and
  reaped its owned helper. The final built Live UI at approximately 21:04 UTC
  displayed a provider-reported weekly window, 21% used, reset Nov 3 at 23:00
  local time, reported credits 0 with no currency assumption, measurement time
  and official-source label. Process inspection after the read found no child
  left under Relay. On restart the configured profile initially showed missing,
  not recovered quota/history, before a fresh read. Live inspection used no
  screenshots, and no raw identity, credentials or wire payload were persisted.
  This repeated proof does not retroactively establish the original
  **pre-implementation** gate: the delivery coordinator must retain/check that
  initial execution receipt separately.
- **M-SETUP:** native onboarding showed the broad-token/not-read-only warning,
  a disabled Pair button before consent, Keychain ownership and local-only
  disconnect. The native hook instructions explicitly preserved existing
  handlers/statusline rendering and official `/hooks` trust. Manual snippets
  in `docs/integrations.md` were inspected against the pinned source contracts.
- **M-PUBLIC, author audit:** proposed public paths contain source, synthetic
  fixtures, manifest-aligned CI, MIT license and bounded release claims; no
  private captures, machine configuration or provider credentials are intended
  for Git. Independent review and final staged-diff audit belong to the next
  delivery stages, not this author verification.

Orca's GUI helper reports an accessibility error when a Close/Escape action
successfully removes the last window; separate window-list observations confirmed
the closed state. Native popover window accessibility is explicitly registered.

## Repair 1 observations, 2026-10-28

These observations supersede the earlier build only for the scenarios explicitly
repeated below. The detailed historical filter/scroll/collapse sequence above was
not repeated in full and is not represented as current-build proof. Navigation,
scroll and popover implementations were unchanged by this repair.

Current release executable SHA-256:
`453e340c93b309d8a776ea6f0b7563945220388d5d0dc6a154d04f95bf96dc59`;
bridge SHA-256:
`1e19324be8913ec1d68cd5ede488fe67d97f382ec94ab59ac33b73f75e46eea0`.
Observed on the same macOS 26.6.2 arm64/Xcode 27.1 environment, approximately
21:20–21:27 UTC. This remains local ad-hoc build evidence, not release certification.

- **M-GUI current smoke:** the synthetic Demo showed one 446 × 686 native
  popover. Repeated Usage → Codex/Work → root → child → grandchild → reported
  parent → account, then six Escape steps back to Usage, in the same popover.
  Agents → search “Keyboard” displayed one matching agent with ancestor context.
  Tab focused search; native text entry updated the filter (accessibility-only
  value assignment did not itself notify SwiftUI). Settings stayed in that surface.
  Only synthetic Demo screenshots were captured. The historical full scroll,
  project/state intersection and collapse observations are not claimed as rerun.
- **M-CODEX current:** the existing profile, private pseudonym A, was read by the
  built adapter using official Codex 0.154.0 (binary SHA-256 unchanged from above).
  At 21:22 UTC Live showed a measured weekly window, 22% used, reset Nov 3 at
  23:00 local time, reported credits 0 without a currency assumption, measurement
  time and the official-source label. No child process remained under Relay after
  the read. No inference, login/logout, credential extraction or external settings
  changes were performed; no Live screenshots or raw provider payloads were saved.
  This is repeated implementation proof, not a replacement for the original
  pre-implementation chronology independently confirmed by the prior review.
- **M-SETUP current:** before consent, native onboarding displayed the broad-token
  warning and disabled Pair. The revised disclosure explained replacement cleanup,
  cleanup on quit/next launch, manual re-pair after restart, reported cleanup failure,
  and no server-side revocation. With no service paired, Disconnect reported local
  deletion after the application cleanup path returned. Real pairing/Keychain
  failure behavior is not claimed from this observation: injected-vault tests
  exercise pair twice, legacy-token startup cleanup, denial/retry and cancelled
  older pairing versus a newer token. Manual hook snippets remain unchanged.
- **F3 current restart:** force-exited only this newly launched test app after the
  quota read. Its owned 0600 socket remained. Relaunch replaced the stale socket
  with a different inode, same-user 0600 ownership, and a successful local connection.
  No external hooks/settings were edited. Final normal app quit removed the socket.
  Synthetic tests additionally reject active listeners (with or without Relay's
  lock), unsafe modes and symlinks without replacing those endpoints.
- **M-PUBLIC repair audit:** repair files contain production source, synthetic
  fixtures/tests, inventory and bounded integration/evidence documentation only.
  Build outputs, GUI captures and private workflow evidence remain outside public
  paths. Independent re-review and the owner's staged-diff/CI gates still follow.

Required finding dispositions for this execution: **F1 fixed** (snapshot accountId
takes precedence over same-email fallback; production RPC/registry regression),
**F2 fixed** (only a correlated non-continuing child stop becomes terminal; both
hook sources tested), **F3 fixed** (locked, validated refused-socket recovery and
current-app crash/relaunch), **F4 fixed** (application connection owner plus
service-scoped owned-token cleanup, replacement/cancellation/restart/denial tests).
No required finding is disputed or knowingly unresolved by the author; this is
verification evidence, not an independent acceptance verdict.

## CI repair 2 observations, 2026-10-28

This is new current-build evidence, not reuse of the repair 1 smoke or a replacement
for the pre-implementation chronology independently confirmed by prior reviews.
Observed approximately 21:53–22:04 UTC on macOS 26.6.2 (25G83), arm64, Xcode 27.1
(27A9275), using this worktree's release bundle. Relay SHA-256:
`0f40b0bfbce1798a41d7aca121889e17a861d36cf6120e47afed6a3c00011cad`;
bridge SHA-256 remains
`1e19324be8913ec1d68cd5ede488fe67d97f382ec94ab59ac33b73f75e46eea0`.

- **CI attribution:** run 40774607147 failed BUILD at AppServices.swift's Timer
  callback: an actor-isolated Task referenced the outer mutable weak capture.
  Explicit inner weak capture lists now cover Timer, hook-listener and SSE
  callback-to-Task boundaries. They preserve weak ownership and main-actor work;
  shutdown still invalidates the timer/cancels jobs/stops the listener. Other weak
  callbacks do not cross this nested Task boundary. The older CI compiler is not
  installed locally; its actual rerun remains the owner's current-head CI gate.
- **Synthetic scanner finding:** check 123120675562 identified the fixture's literal
  Base64 Basic header, representing only `opencode:synthetic-token`. The fixture
  now computes that exact expected header from visibly synthetic input. A real
  loopback check accepted the exact header and rejected wrong-token, wrong-scheme
  and empty headers. No auth assertion, scanner policy or ignore rule was weakened;
  no credential rotation or history rewrite is appropriate for this synthetic value.
- **M-GUI full current repeat:** one actual status item and sole popover (window
  82421), settled outer dimensions 446 × 686, with fixed header/footer and scrollable
  content. Actual screen visible frame was 3440 × 1320; the source's 660-point
  content cap fit that screen. No smaller-screen/macOS 14/Intel certification is
  claimed. Usage scroll was set to 0.8, then Codex/Work → Build menu-bar monitor →
  Menu-bar shell → Keyboard regression checks → reported Parent → Account;
  six Escape keys traversed the reverse stack and restored Usage scroll to
  0.799249530956848. Agents visually showed parent/child/grandchild order and count
  8. Collapsing the root hid descendants without changing count. Tab actually
  focused search; typing Keyboard yielded one match plus its two ancestor-context
  rows despite collapse. Native state selection working yielded zero, stopped one;
  project docs-site yielded zero, ai-usage-monitor one. Matching detail/Back and
  Settings/Back retained query/project/state/count. Resetting both native pickers
  and clearing search through focused keyboard input restored count 8 and prior
  collapse; expanding restored descendants without changing count. Browser
  regression checks showed unknown immediate parent/account; Session membership
  opened Repair mobile navigation, with two Escape steps restoring Agents. Agents
  scroll 0.7 survived another detail/Back. Root Escape removed all product windows;
  actual status-item AXPress reopened with query/count/focus retained. Root Close
  likewise produced an independently observed empty window list; status-item
  reopen retained Keyboard/ai-usage-monitor/stopped/count 1. Native picker choices
  were performed by AXPress and verified by fresh selected values/counts, not
  inferred from unasserted keyboard delivery. Intermittent closed-window/AX errors
  required reopen and fresh snapshots; granted permissions were independently
  checked. Only synthetic Demo screenshots were saved in private tool storage.
- **M-CODEX current:** at 22:04:19 UTC the implemented adapter/native Live Usage
  showed an actual weekly window, 24% used, reset Nov 3 at 23:00 local time,
  credits 0 without currency assumption, current measurement and official Codex
  source label. The existing profile remains private pseudonym A. Official Codex
  0.154.0 SHA-256 remains
  `4f85982624b3898c8991cb80c0981b2aa71070e3537046c9a95950318a95afcc`.
  No owned child process remained under Relay after the read. Returned to Demo;
  no Live screenshot, raw identity/payload, token extraction, inference, login or
  external setting edit occurred. This repeats implementation proof only.
- **M-SETUP current:** expanded native hook and pairing disclosures in the same
  popover: preserve existing handlers/statusline, exact official hook trust,
  future-only collection; broad token NOT read-only, disabled Pair before consent,
  local-token cleanup/re-pair/restart/failure and unchanged-server semantics.
  No actual pairing or external hooks/settings edits were attempted.
- **Regression/public boundary:** F1–F5 remain resolved subject to fresh independent
  review; the full required suites carry their regressions. Public delta is only
  capture semantics, the synthetic fixture representation and this evidence.
  Private GUI helpers/captures and provider data are not repository additions.
  No commit, push, PR mutation, scanner suppression or workflow-policy change was
  performed by this worker. Independent review and actual CI still follow.
