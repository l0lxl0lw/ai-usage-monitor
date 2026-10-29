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
   Rich persistent captures use the separate synthetic-only NativeHarness with
   the exact production presentation library, never a production sample route.
   Separately observe actual no-profile production launch and automatic saved
   Codex startup with no captures/identity persistence.
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

All Demo/manual-mode observations below are historical superseded-build evidence,
not acceptance of the revised Live-only startup. The original pre-implementation
receipt remains immutable private chronology; it is not new production proof.

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
   no credential rotation was appropriate for this synthetic value. The later
   expressly approved feature-only history cleanup supersedes that earlier
   no-rewrite decision; it does not change fixture authentication or scanner policy.
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

## Revised Live-only execution observations, 2026-10-29 UTC

These replace the historical Demo-mode proof for the revised plan. Observed on
macOS 26.6.2 (25G83), arm64, Xcode 27.1 (27A9275), approximately 03:05–03:13 UTC.
This remains local source-build evidence, not macOS 14 runtime, architecture,
accessibility or distribution certification. Base HEAD is
`f796cdf04c89aecf130037f08504f7883b376d8e` plus the revised-scope working tree;
the verification receipt binds its complete final source content.

### Build and provenance

- Production Relay SHA-256:
  `c54d961e1f9e62376f030b8cd37cf62ec5fd374cb7edeac09ddf4793bd890390`.
  Bridge SHA-256:
  `fe6203312e93772eacfd12cd9bb371c78a49f1876d1205bc25d8665af478e978`.
- Separate release NativeHarness SHA-256:
  `fb5d3aaa1f223105bf2f972055cfd572077f825924449db723328fbd94193467`.
  Its private locally signed wrapper uses a separate bundle ID/preferences and
  no startup listener/timer/Keychain cleanup. All data was synthetic. It links
  the **same** MonitorPresentation library: AppServices, PopoverController,
  PopoverRoot, SettingsViews and ScrollMemory, not copied view implementations.
  SyntheticFixtures/Harness live only under Tests/NativeHarness; Relay's target
  dependency closure cannot reach them. BUNDLE checks the positive source and
  dependency/resource inventory, exact signed bundle files, deployment target
  and distinctive fixture/flag/harness binary canaries. BUILD selects only the
  two shipped products. The preserved mock is unshipped.

### M-GUI: direct production and separate synthetic-only rich sequence

- Stopped the previously running historical test build before launching the new
  production executable. Privately backed up the complete existing preference
  domain (one explicitly saved Codex profile), temporarily removed only Relay's
  saved-profile key, then launched the actual production bundle. Observed Live,
  no Demo/Observation mode selector, zero accounts, no configured profiles, and
  Agents with zero matching observations and all four sources Not collecting.
  No source login discovery, pairing, Orca read or external config edit occurred.
  Quit through native Settings, restored the **entire** preference domain and
  independently compared it to the backup for equality before the saved launch.
  No Live screenshot was requested. A private recovery backup remains available.
- Rich navigation used only the separate synthetic harness (PID 17438, sole
  popover window 82634). Settled outer size 446 × 686 / 420 × 660 content; fixed
  header/footer and native scrolling. The 660-point cap fits the current screen;
  smaller-screen/macOS 14 certification is not claimed.
- Usage scroll set/read back 0.8; Codex/Work → Build menu-bar monitor → Menu-bar
  shell → Keyboard regression checks → reported Parent → Account. Six Escape
  backs traversed the reverse stack to Usage; native scroll restored to
  0.8003992015968064. Every route stayed in that same window.
- Agents visually ordered parent/child/grandchild, count 8. Collapse root hid
  descendants without changing count. Tab actually focused search; typed
  Keyboard produced one direct match with two ancestor context rows, despite
  collapse. Native state working yielded 0; stopped yielded 1. Project docs-site
  yielded 0; ai-usage-monitor yielded 1. Actual native menu AXPress selections
  were verified by fresh selected values/counts, not inferred keyboard delivery.
- Matching grandchild detail/Back and Settings/Back retained all three filters
  and count. Root Escape independently left zero windows; actual status-item
  AXPress reopened with Keyboard/ai-usage-monitor/stopped/count 1 and root focus.
  Root Close independently left zero windows; status-item AXPress again reopened
  with the same retained filters/count/focus.
- Reset native pickers and cleared search through focused Cmd+A/Backspace:
  count 8 and original collapse restored. Expanding restored descendants without
  count change. Browser regression checks showed unknown immediate parent/account;
  Session membership opened Repair mobile navigation. Two Escape backs returned
  Agents. Agents native scroll 0.7 survived detail/Back as 0.7014388489208633.
- Only synthetic harness captures were saved privately. Orca sometimes omitted
  native menu children or reported a closed-window error after a successful
  close; System Events AXPress and fresh snapshots/window lists established the
  actual outcomes. An attempted coordinate menu click did not change selection
  and was not counted as successful proof.

### M-CODEX: NEW automatic production saved-profile startup

At 03:07:41 UTC the newly launched actual production bundle (PID 15917) displayed
the existing explicitly saved authorized profile, private pseudonym A, with no
mode switch or manual quota action: **Weekly 28% used**, reset **Nov 3 at 23:00
local**, fresh measurement **Oct 28 at 20:07:27 local**, observed coverage and
official Codex 0.154.0/owned-helper-stopped source label. Process inspection found
**no owned child remaining** after the read. Official CLI version was 0.154.0,
SHA-256 `4f85982624b3898c8991cb80c0981b2aa71070e3537046c9a95950318a95afcc`.
Quit through actual native Settings. No raw identity/auth/payload, Live snapshot,
model turn, new login/logout, token extraction or provider configuration edit was
performed/persisted. The original successful pre-implementation receipt remains
unchanged private historical chronology, never substituted for this new proof.
Synthetic two-profile tests do not claim two-real-account release certification.

### M-SETUP, regressions and public boundary

Expanded the exact production native hook/pairing views in the separate harness:
preserve existing handlers/statusline; absolute shell-quoted bridge; official
exact-hash /hooks trust; future-only collection and unknown immediate ancestry;
broad token NOT read-only; Pair disabled before consent; Keychain ownership,
local cleanup/re-pair/restart/failure and unchanged-server semantics. Inspected
both unchanged manual snippets against the pinned schemas/research. No actual
pairing, hook installation or external settings mutation was attempted.

F1 accountId/same-email identity protection, F2 correlated child stops, F3 socket
ownership/crash recovery, F4 token replacement/cleanup/cancel ownership and F5
full current rich GUI proof remain regression obligations. The first four retain
their existing production tests; actual AppServices startup tests additionally
prove empty/malformed launch, valid/duplicate/canonical-collision/unsupported
profiles, mixed Codex/Claude, startup/timer/manual convergence, independent bounded
throttling, identity failure with stale retention, unsupported runtime, cancelled
late reads and empty observation restart. NAV now composes the actual native
root against these services, not solely an unrelated NavigationState instance.
Required ten manifest definitions remain unchanged; the runner verifies the
expanded exact 45-case XCTest inventory, without skips.

Author audit: only application source, test-only synthetic harness/fixtures,
inventory/check strengthening and truthful source-install/evidence documentation
are proposed. MIT/license, transport/privacy/scanner policies and exact synthetic
fixture authentication remain intact. Feature history above preserved main is
one approved owner-rewritten feature commit; this worker performed **no Git or
journal mutations** and was not exposed an actual Task session ID for claiming.
Owner must claim the returned Task ID, preserve same-key repair use **2/3**, obtain
fresh independent review, audit final publication/history and exact expected-old
remote OID, then perform only the approved guarded PR #2 update/current-head CI
and main-freshness gates. No remote CI success, review pass, PR merge, binary/DMG
upload, notarization or installer release is asserted by this execution.

## Preview ZIP extension and explicit proof reuse, 2026-10-29

The preview extension starts at `da98e21241ae9a7310da24f084c1e6da21e04520`,
under Plan [6504140949](https://github.com/l0lxl0lw/ai-usage-monitor/issues/1#issuecomment-6504140949).
The selected original main and F1–F5/history-cleanup chronology above remain intact.
No production source, test/harness source, Package.swift, Resources/Info.plist,
existing builder or BUNDLE/check implementation is changed by this extension.
The original ten manifest definitions are preserved exactly; ZIP and INSTALL are
appended, and the final verification receipt must run all twelve without skips.

### M-GUI / M-CODEX / M-SETUP: conditional reuse made explicit

Reuse the complete observations at lines 221–325, not the earlier historical Demo
proof. Directly rechecked production Relay SHA256 `c54d961e1f9e62376f030b8cd37cf62ec5fd374cb7edeac09ddf4793bd890390`,
bridge `fe6203312e93772eacfd12cd9bb371c78a49f1876d1205bc25d8665af478e978`,
the private signed exact-view harness `fb5d3aaa1f223105bf2f972055cfd572077f825924449db723328fbd94193467`,
and official Codex binary `4f85982624b3898c8991cb80c0981b2aa71070e3537046c9a95950318a95afcc`.
The same macOS 26.6.2 (25G83), arm64, Xcode 27.1 (27A9275) environment is present;
both production binaries actually report only arm64 via lipo. Source/component
equality is checked against the unchanged prior reviewed source, not filenames.
That covers the full native route/filter/count/collapse/focus/scroll/close/reopen
sequence, empty production Live launch, 03:07:41 UTC automatic authorized saved
Codex startup/owned-helper termination, and unchanged setup disclosure wiring.
This is explicit fingerprint-matched reuse of observed historical measurements,
not a new GUI observation, new current quota measurement or provider request.
No account/credential/preference/configuration mutation or new Live capture is
needed for packaging; broader account/version/macOS14/accessibility gates remain.

### M-PREVIEW: new real package/install proof, never reused from a source build

First executed the real `/usr/bin/ditto -c -k --norsrc --keepParent` producer and
real extraction, with exactly eight members. Directly confirmed directory flags0,
regular flags8/method8, zero local CRC/sizes, signed16-byte PK0708 descriptors and
Unix5855 central8/local12 extras. Extracted four-file hashes were equal. The actual
embedded production JXA accepts that producer form before testing hostile input.

ZIP records actual OS/toolchain/host and both binary architectures, exact member
names/types/sizes, canonical ZIP checksum and original/extracted four hashes.
INSTALL executes the actual stock-shell installer through a private curl/tool
boundary, never a runtime insecure URL option. It installs into an isolated,
user-owned Applications parent containing spaces, quotes and shell metacharacters;
the actual native rename receives argv paths. Real final device/inode equality,
source disappearance, complete inventory/four hashes/ad-hoc signatures and repeat
install refusal are asserted. Nothing launches; provider/preferences are untouched.

The final receipt's private logs bind results to source, not these descriptions:
98 raw EOCD/central/local/flag/descriptor/extra mutations (including every unknown
flag bit locally, centrally and together), accepted optional UTF8/stored/deflate
forms, sparse exact-limit/+1 archive/file/total/ratio cases, malformed inventories,
CRC corruption, checksum/transport/old-curl OS-bound/bootstrap/nonexecution faults,
reader short-read/output/time faults, unsafe parents and preexisting destinations.
Hostile archives receive recomputed valid outer checksums and cannot invoke
extraction. Reader per-request/aggregate caps are additionally dominated by eight
finite records and name/extra caps, not attacker-sized reads or a decompressor.

Immediately-pre-syscall real directory/file/dangling-link collisions must preserve
the injected inode and sentinel/link without nesting. Before/after-rename signal
cases, binding/syscall failures and source/identity/inventory/hash postcondition
faults must be nonzero. No fallback is allowed; after promotion a complete final
app is never deleted on uncertainty. Cleanup removes only owned staging. Same-UID
owner compromise/parent swapping is explicitly outside the boundary.

### M-PUBLIC: local scope versus still-pending owner publication gates

README leads with the ready-built/no-Xcode route and marks the tagged one-line
download unavailable until separately authorized assets exist. CI uploads only
the exact validated ZIP/sidecar after all twelve checks, with version/arm64/source
SHA in the artifact name. New future-tag automation is tested against synthetic
Git/GitHub responses, including complete inherited active zero-bypass policies,
tag/main/build identity, each pre/postwrite guard, exact retry no-op and partial/
mismatched failures. Only the isolated publisher grants contents-write; it never
executes app/installer code, overwrites/deletes assets or changes policy/tags.

This local evidence is not a real release/download run, current-head remote CI,
an actual PR artifact download or clean-Mac Gatekeeper certification. The owner
must obtain fresh independent review, publish to the same open PR #2, verify
current-head required CI/main freshness, and download/hash that exact PR artifact.
No actual tag, release, merge, policy change, new history rewrite or signing secret
is authorized here; the same-key repair count remains 2/3. The worker performs no
commit/push/journal transition and the owner records its actual returned Task ID.
