# First beta release checklist

## Release metadata

- [x] Confirm version `0.1.0-beta` in `ForeverRP/ForeverRP.toc` and `CHANGELOG.md`.
- [x] Set Interface `11601`, verified from beta client build `1.60.1.69913` and Forever-specific TOCs.
- [x] Verify title, notes, author, and SavedVariables declarations.
- [ ] Verify the matching CurseForge game version.
- [x] Select and approve the MIT License for public distribution.
- [ ] Verify the CurseForge project ID and choose release type `beta`.

## Clean-client test

- [ ] Start with no ForeverRP SavedVariables and log in without Lua errors.
- [ ] Run `/reload`; confirm no window or launcher opens automatically.
- [ ] Confirm only the minimap button remains in the normal closed state.
- [ ] Confirm minimap visibility/position, discovery settings, notification settings, and privacy mode persist after `/reload`.
- [ ] Confirm local profile editing, saving, reset, and local Profile Viewer behavior.
- [ ] Confirm Home, Nearby, Profile, Profile Viewer, and Settings navigation.
- [ ] Confirm `/frp help` and every documented non-debug command.
- [ ] Confirm simulator commands are rejected until debug mode is enabled.

## Discovery and profile test

- [ ] With two clients, verify HELLO/ACK, presence expiry, Nearby entry/exit, minimap count, and duplicate-notification cooldown.
- [ ] Request a remote profile from Nearby; confirm one read-only viewer opens and no Edit button appears.
- [ ] Confirm malformed, oversized, conflicting, unsolicited, and incomplete profile transfers are rejected or expire safely.
- [ ] Confirm `/reload` clears presence, Nearby, notifications, pending transfers, relationship trust, and remote profiles.
- [ ] Confirm no runtime discovery or remote-profile tables appear in account or character SavedVariables.

## Privacy and tooltip test

- [ ] Verify Visible permits normal presence, discovery, and profile exchange.
- [ ] Verify Friends/Guild Only accepts verified friends/guild members and rejects unknown relationships.
- [ ] Verify Hidden suppresses HELLO/ACK discovery and profile responses while local profile tools still work.
- [ ] Hover a confirmed player repeatedly; confirm concise ForeverRP lines appear once.
- [ ] Confirm cached RP name, title, status, and Profile Available render safely.
- [ ] Confirm NPC, item, and spell tooltips are unchanged.
- [ ] Confirm tooltip hover never sends a profile request.

## Package and upload

- [x] Run `powershell -ExecutionPolicy Bypass -File tools/package.ps1` and require a successful validator result.
- [x] Inspect the ZIP and confirm `ForeverRP/ForeverRP.toc` exists.
- [x] Confirm the ZIP has one top-level `ForeverRP/` directory and no loose root files.
- [x] Confirm no `.git`, tools, build output, SavedVariables, WTF, Cache, logs, credentials, or prior ZIPs are included.
- [x] Install the exact validated ZIP into the configured beta-client AddOns directory.
- [ ] Repeat `/reload` smoke testing with the exact packaged build.
- [x] Prepare the CurseForge changelog from `CHANGELOG.md`; do not publish until all blockers above are resolved.

Never commit API tokens, credentials, project secrets, or generated archives. Publishing credentials must come from environment variables or repository secrets.
