# Beta 20 release record — October 16, 2026

Version: `0.1.1-beta.20`
Build: `profile-caret-20261016-20`
Scope: same-layer beta baseline; runtime code unchanged from the installed Beta 20 cursor test build.

The maintainer reported that the build seemed stable again and explicitly asked
to lock it in, update the local addon, and push the source to GitHub. This is the
release decision. Local chat-pane and sound operation were explicitly reported;
individual results for every two-player/cursor checklist step were not supplied.
No assistant-run multiplayer testing or complete manual-checklist pass is claimed.

## Preservation and release files

- Prior Beta 20 candidate ZIP and pre-release documentation:
  `build/beta20-release-20261016-preserved/`.
- Original candidate ZIP SHA256:
  `7FB9D38FA5A161E7C10AEBC457D91BAF9654711E0A67DF4F7E501FD47E1E0AE1`.
- Publication ZIP: `dist/ForeverRP-v0.1.1-beta.20.zip`.
- Release notes: `docs/BETA20_RELEASE_NOTES.md`.
- Final package hashes, installed-file verification, backup location and source
  snapshot are recorded under `build/beta20-release-validation/`.
- Existing Beta 17, Beta 18 and Beta 19 archives/backups remain preserved.
  SavedVariables are not changed. The source and documentation are committed
  together for a reproducible GitHub baseline; generated ZIPs remain ignored.

## Publication destination

GitHub repository: [World-of-Warcraft-Forever-RolePlay](https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay),
branch `main`. The commit containing this record identifies the source baseline.
Remote commit verification is recorded in `build/beta20-release-validation/`.
CurseForge publication is not part of this task.

## Experimental status

Disabled: cross-layer discovery; Directory advertisements/listings; layer
inference; experimental custom-channel joins/recovery; zone, precise-coordinate
and subzone sharing. Saved settings cannot enable the archived implementation.
Nearby-only position sharing is agreed future work and is not implemented.

Active: existing privacy and profile approvals, native Nearby discovery, local
minimap dots where coordinates are available, local chat output, profile tools,
Connections, MingleBar and notifications. No new network behavior was added for
this release.
