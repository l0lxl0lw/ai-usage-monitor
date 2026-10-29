# Separate public-release gates

This repository targets macOS 14+ using standard Apple frameworks. A deployment
target is not runtime certification. Local ad-hoc signing is not Developer ID
signing or notarization. No stable/public-certified binary release or automatic updates are shipped.

Before stable/public-certified binary distribution, require:

- Provider eligibility clarification; official CLI interoperability is not vendor
  endorsement or provider approval.
- Developer ID signing, notarization and clean-Mac Gatekeeper validation.
- Actual macOS 14 runtime and accessibility certification (keyboard, VoiceOver,
  contrast, reduced motion and available-height cases).
- Tested architecture builds; do not call an arm64 build Intel/Universal certified.
- Appropriate live-source/version proof, including two independently authenticated
  real accounts and Claude/OpenCode/Orca coverage. Synthetic transport tests do not
  certify these source services.

Delivery itself still requires current-build native GUI observation and real
Codex adapter/Live UI quota proof; those are not waived by this release checklist.
For the revised Live-only contract this means direct empty production startup,
automatic quota display for an explicitly saved existing Codex profile, and the
full rich GUI sequence in a separate synthetic-only exact-view harness. The
harness and historical Demo captures never certify live sources. Source install
instructions alone do not authorize publication; the narrow experimental PR artifact
exception below does not waive these certification gates.

## Preview packaging boundary

The ready-built app-only ZIP, checksum, PR CI artifact and stock-shell installer
are a narrow preview distribution path; see [install](install.md). This delivery
does not publish a tag/release, mutate tag policy or merge the PR. Future protected
tag automation is tested synthetically, not an observed release. Local real ZIP
roundtrip/install proof is separate from the final-head PR artifact download and
from clean-Mac internet/Gatekeeper testing. Ad-hoc signatures are not Developer ID
or notarization; macOS14 deployment is not macOS14 runtime/accessibility certification.
