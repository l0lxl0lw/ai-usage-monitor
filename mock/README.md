# Relay popover mock

Browser-hosted design prototype of a **menu-bar-only macOS app**. There is no dashboard, separate activity window, or external settings page. Relay is a working name.

## Run

From the repository root:

```sh
python3 -m http.server 5173 --bind 127.0.0.1 --directory mock
```

Open <http://127.0.0.1:5173>. No build dependencies. Inter loads from Google Fonts, with a system-font fallback.

## Navigate

- **Usage:** independent account windows, reset labels, and stale measurement indicators. Click an account for details and associated sample agents.
- **Agents:** project groups, collapsible reported parent/child links, search by name/source, and project/state filters. Select an agent to replace the list with its details.
- **Details:** navigate to parents, children, or associated accounts without leaving the popover. Back restores the previous view, filters, and scroll position.
- **Settings:** connection capability notes, completed-agent visibility, and offline/empty demo scenarios, all inside the same popover.
- **Advance demo:** simulated state changes only. No approvals or real agent actions.
- Escape goes back inside nested views, then closes at a root tab. The simulated menu-bar item reopens the same view.

`data.js` contains four fictional accounts, three projects, three root sessions, and ten agents. All titles, links, states, timestamps, quotas, and reset labels are frozen fixtures. Some agents explicitly have an unknown account or unknown immediate parent. Cross-tool links illustrate explicit orchestrator provenance, not automatic universal discovery.

No credentials, local processes, transcripts, CLI settings, or provider endpoints are accessed. Nothing is persisted. This is not yet a native application or a validated live adapter.

## Checks

```sh
node --check mock/app.js
node --check mock/data.js
node .agents/skills/design-taste-frontend/scripts/lint.mjs --app mock
```

Execute `test-browser.js` as an expression in the preview browser to check navigation, ancestry, counts, filters, stale/empty states, and popover containment. It restores the initial fixtures. It is not loaded by the app.

Use the relevant Orca workspace's embedded browser for preview/acceptance checks. The standalone Taste inspector opens a separate browser, so do not run it under the current browser preferences without specific approval. Its earlier screenshot reports are historical, not current acceptance evidence.

Design: Taste Skill **True-black flat**, seed **1698869751**, no redraw. The centered empty desktop around the mock is deliberate: it frames the actual 420px popover, not a missing dashboard. Compact metadata is 11–12px; native accessibility testing remains a release requirement.
