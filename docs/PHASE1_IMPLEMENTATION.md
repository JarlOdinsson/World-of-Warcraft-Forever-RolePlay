# Phase 1 candidate record — 2026-10-14

Version: `0.1.1-beta.18`.
Build: `same-layer-phase1-20261014-18`.
Status: packaged test candidate; live exit gate remains open.

## Preservation and reference

- Original base commit: `bad93ed142c9dc254b9624318e09df840c16019b` on `main`.
- Original working-tree build: `0.1.1-beta.17` / `ordered-directory-20261011-17`.
- Complete local snapshot: `build/phase1-beta17-preserved-20261014/workspace/`.
  All 114 tracked/untracked non-ignored files were copied and SHA-256 checked
  before edits. Existing ignored artifacts remain in place.
- Beside the snapshot: `PRESERVATION.txt`, `base-commit.txt`, `git-status.txt`,
  `uncommitted.patch` (binary-capable tracked diff), `sha256.csv`, original Beta 17
  ZIP, and logs of all 21 pre-change suites. Recover untracked files from
  `workspace/`, not from the tracked patch alone. No reset/stash/checkout occurred.
- Beta 17 ZIP SHA-256:
  `CA11AA2DDEA2AD991764E281EADD66C570A11EDEEAA3D7A42F3F1D111FF07B29`.
- Source archive for ongoing review: `experiments/beta17/`. Its four modules
  hash-match the snapshot and are excluded from the installable addon.
- Actual Beta 5 source: commit `87c309e84b40d3830dd6f72332fd1fd682458f02`,
  `0.1.1-beta.5` / `discovery-sound-20261009-5`, extracted to
  `build/phase1-beta5-reference-87c309e/` (also retained as a Git archive ZIP).
  All 51 addon files match the saved installation in
  `D:\my build wow addons\ForeverRP\Backups\ForeverRP-before-beta.8-20261010-052850`
  after normalizing text line endings. This confirms the local source reference;
  it is not a byte-for-byte verification of the CurseForge download.

## Runtime decisions

Beta 5's observed-unit HELLO/ACK and Nearby qualification logic were already
present in Beta 17. They are retained, including later fixes that preserve raw
client recipients, complete multiword names/realms, bounded retries, profile
source separation and per-chunk privacy checks. The native guild/party presence
lifecycle is retained, but presence alone never creates Nearby or a dot.
`Range.lua` keeps the post-Beta-5 combat/restricted-value guards unchanged.

The experimental Activity engine is replaced with a non-networking compatibility
object for the existing UI and privacy setters. Directory queries are empty;
saved experimental settings cannot enable it. Experimental sends are rejected
at both communication entry points, ingress is ignored, and metadata cannot
create presence. The custom channel is left once if still subscribed at login.
There are no custom-channel joins, prefix-registration retries, advertisements,
probes, ordering/recovery queues or layer inference. Layer-only events and
observation calls are removed from current Events; LayerEvidence is absent from
the TOC and addon directory. Historical event wiring remains in the archive.

The same menu panels and positions remain. Network/listing/subzone/location
controls and Directory filters explain the temporary pause and are disabled.
Profile permissions and explicit approvals remain active. Personal profiles,
Connections/notes, MingleBar, tooltip and notification code are preserved;
their unchanged files can be verified against the snapshot hash manifest.

Dots keep the existing neutral appearance, pool, zoom and rotating-minimap
projection. Their input is now a fresh local position of a confirmed Nearby
unit, with identity, visibility, privacy, range, coordinate-space and combat
checks. All valid associated units are tried if one token lacks a position.
No coordinates are cached or sent. The existing one-second lifecycle refreshes
dots after reevaluating Nearby. Unsupported/secret positions, token reuse,
expired presence, Unknown range and combat hide them. This changes the source
of dots: the client must expose safe positions for the unit/context. Live dot
availability, especially for ungrouped targets/nameplates, remains a blocker
to claiming the old dot coverage has been preserved in game.

The native protocol and SavedVariables schema are unchanged. No automatic
presence-withdrawal protocol was added. A peer can retain prior presence for
15 minutes after someone goes Hidden; prior profile data follows revocation
and the five-minute cache lease. The test guide calls out these existing limits.

## Validation

- Before edits: all 21 existing suites passed.
- Candidate: all 22 suites passed, 3,076 checks in total. This includes archived
  experimental-module tests as well as current native tests.
- New Phase 1 suite: 11 cases / 187 checks using current native modules,
  mocked startup/events/timers, transport, positions and widgets. Covers
  no experimental traffic with saved opt-ins, native matching/discovery,
  notifications/expiry, dots and restricted APIs, requests/tooltip behavior,
  approvals/Connections grants, privacy changes and modeled reload persistence.
- Existing experimental assertions were retained; only their source imports
  point to `experiments/beta17/`. Two build-label assertions were updated to
  the new build. Historical results are not evidence of enabled Phase 1 traffic.
- Lua 5.1 syntax: 74 files passed (45 runtime, 25 test/helper, 4 archived).
- `git diff --check` passed.
- Logs/results: `build/phase1-validation/`. `changes-from-beta17.json` identifies
  modified pre-existing files separately from pre-existing uncommitted work.

## Package and remaining gate

Package: `dist/ForeverRP-v0.1.1-beta.18.zip`, generated with `tools/package.ps1`.
The addon remains rooted at `ForeverRP/`. The package excludes the source
archive, tests, development tools and SavedVariables. ZIP verification results
and checksum are recorded in `build/phase1-validation/package.json`.

No installation or publication was performed. No in-game or multiplayer test
was performed in this implementation session. Follow
[the two-player steps](PHASE1_SAME_LAYER_TEST.md) for discovery, dots, explicit
profiles, moving out of range, privacy, reload/relog, expiry and combat; also
verify unchanged menus, Connections, tooltip/audio and MingleBar on the client.
Actual delivery, unit-position availability, client taint/restrictions, visual
layout and audio are the remaining gates. Do not publish as stable until they pass.
