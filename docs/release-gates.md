# Separate public-release gates

This repository targets macOS 14+ using standard Apple frameworks. A deployment
target is not runtime certification. Local ad-hoc signing is not Developer ID
signing or notarization. No public binary release or automatic updates are shipped.

Before public binary distribution, require:

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
instructions do not authorize a binary/DMG/installer upload.
