# Preview installation

Recipients need macOS 14+ and Apple Silicon, using only stock macOS tools.
There is no Python, Xcode, Homebrew, `gh`, sudo, DMG, separate validator download
or background updater in the installer. Intel/Universal support is not claimed.

## PR artifact, available after CI

On the exact source head's successful CI run, download the artifact named in the
README. GitHub wraps the two files in an artifact download; unpack that wrapper
into a fresh folder, then check the payload there:

```sh
shasum -a 256 -c Relay-v0.1.0-preview.1-macos-arm64.zip.sha256
```

The sidecar must contain exactly one lowercase SHA256, two spaces, the exact ZIP
basename and a newline. The payload ZIP contains only `Relay.app`, four directories
and four regular files. This artifact is not a published GitHub Release and does
not make the future tagged one-line command usable. You may inspect the validated
artifact app in a fresh private folder; do not replace an existing app implicitly.
CI artifact-download verification for the final PR head is a delivery-owner gate,
not something a local packaging test can claim.

## Future tagged installer

The README command is deliberately tag-pinned and fully downloads a bounded script
before executing it. The script accepts `vX.Y.Z-preview.N` and an optional absolute
Applications parent, for example `/bin/sh install-preview.sh v0.1.0-preview.1 "$HOME/Applications"`.
It never accepts arbitrary repositories, URLs, tokens or a `latest` selector.
Tags/assets must first exist; this PR does not publish them.

Every download has HTTPS-only redirects, TLS minimums and time limits. A dedicated
curl-only shell enforces a kernel file-size limit even with older curl versions;
post-download byte limits and exact checksums remain mandatory. Maximum archive:
256 MiB; per regular member: 256 MiB; total expansion: 512 MiB; ratio: 200:1.

Before any extraction, a small fixed embedded JXA `NSFileHandle` reader validates
bounded raw ZIP headers: exact eight canonical names/types, local/central agreement,
only stored/deflate and optional UTF8/signed standard descriptors, known bounded
Unix/timestamp extras, no unsupported flags (including bit14), ZIP64, links,
overlaps, gaps or trailing records. It reads only metadata, never decompresses.
Stock `unzip -t` then checks payload integrity; stock `ditto` extracts privately.
Inventory, plist/tag version, ad-hoc signatures and full file hashes are checked.

The selected Applications parent and its components cannot be symlinks or unsafe
writable directories; the selected parent must be user-owned. A fresh mode-0700
stage is on the same filesystem. Only a completely validated app is promoted by
stock osascript calling `renamex_np(source, destination, RENAME_EXCL=4)` with argv.
There is no `mv`, copy-to-final or fallback: concurrent file/directory/dangling-link
creation makes the syscall fail without nesting or overwrite. Success additionally
requires the source gone, identical device/inode and the same inventory/hashes.
Failure/interruption removes only owned staging, never the final app. After a
successful rename, interruption may leave a complete app but cannot print verified
success without postconditions. Malicious same-UID owner compromise/parent swapping
is outside this boundary; the installer is not a sandbox against its own user.

No launch, provider request, login, preference edit, quarantine stripping, signing,
Gatekeeper bypass or clean-Mac certification occurs. The app is ad-hoc signed,
unnotarized and may be blocked by macOS. The checksum is not Developer ID authenticity.

## Future release operator gate (not performed here)

Before creating a preview tag, a separately authorized security operator must set
full inherited ACTIVE tag rules restricting update **and** deletion, with zero
bypass actors, no exclusions, and an include of `refs/tags/v*-preview.*`, the exact
validated full tag ref, or `~ALL`. Creation must remain allowed. Unsupported,
inactive/evaluate, partial/unreadable or bypass-bearing policies fail closed.
Trusted repository-security administrators remain outside this threat model.
GitHub [withholds bypass actors without sufficient ruleset access](https://docs.github.com/en/rest/repos/rules#get-a-repository-ruleset).
If the workflow token cannot read that full detail, publication stops; the workflow
does not broaden its permissions, infer an empty bypass list or change policy.
Any future access/policy setup needs separate operator authorization. Unsupported
inherited condition shapes also stop publication rather than guessing a matcher.

The future workflow accepts explicit preview-tag pushes only, checks tag object,
peeled build commit and fetched main ancestry, runs all twelve checks on an actual
arm64 host/both actual binaries, and matches the real tag against the plist. Build
has read-only permissions; only the isolated publisher has contents-write. It never
executes the app or installer. Tag-specific serialized publication rechecks full
policy and identities immediately before/after every release/asset write and before
no-op success. It creates a prerelease with `--verify-tag --latest=false`. Only an
exact complete published prerelease with matching asset bytes is a retry no-op.
Draft/stable/partial/extra/missing/mismatched results fail with no overwrite, deletion
or rollback. ZIP rebuilds are not assumed byte-reproducible. No policy, tag, release
or merge operation is authorized by merely adding this workflow.
