# Changelog

All notable user-facing changes to ForeverRP will be documented here.

## 0.1.0-beta

### Added

- Initial CurseForge-compatible repository and release scaffolding.
- Validated PowerShell packaging and local installation workflows.
- Initial ForeverRP runtime bootstrap and startup lifecycle.
- Defensive account and character SavedVariables initialization.
- `/frp` and `/foreverrp` command handling for help, version, and debug settings.
- Optional account-wide debug logging, disabled by default.
- Native main window with Home and Settings navigation.
- Synchronized debug and minimap visibility settings.
- Draggable minimap button with persistent angle and localized tooltip.
- `/frp` window access and `/frp settings` navigation.
- Per-character local RP profile storage and editing.
- Plain-text single-line and scrollable multiline profile fields with limits.
- RP status selection for IC, OOC, AFK, and DND.
- Confirmed profile reset that preserves account settings.
- Profile completion count and `/frp profile` navigation.
- Minimap-first access with no automatically displayed main window.
- Read-only local Profile Viewer and `/frp view` navigation.
- ForeverRP addon communication protocol foundation.
- HELLO/ACK presence handshake over supported social addon channels.
- Session-only presence cache with 15-minute expiry.
- `/frp hello` and `/frp presence` testing commands.
- Debug-only protocol simulation commands for solo parser, handshake, validation, and presence-cache testing.
- Event-driven player-unit detection for nameplates, target, mouseover, focus, party, and raid units.
- Conservative range abstraction and configurable 10/15/20/25/30-yard discovery setting.
- Session-only Nearby qualification cache and `/frp nearby` diagnostics.
- Solo synthetic range simulation through the production Nearby logic.
- Nearby count badge attached to the existing minimap button.
- Configurable minimap pulse, subtle sound, and optional chat discovery feedback.
- Session-only per-character notification cooldown and duplicate suppression.
- Explicit simulator notification mode and cooldown reset commands.
- Safe PROFILE_REQUEST and chunked PROFILE_DATA protocol messages.
- Strict remote-profile schema validation, sanitization, and session-only caching.
- Read-only remote profiles in Profile Viewer and `/frp request <Name-Realm>`.
- Solo profile-transfer simulations for valid, malformed, oversized, and cleared data.
- Live Nearby panel with cached RP names, statuses, profile availability, and click-to-request viewing.
- Account-wide Visible, Friends/Guild Only, and Hidden discovery privacy modes.
- Centralized relationship checks for presence and profile transport, with conservative unknown handling.
- Debug simulator controls for privacy modes and simulated friend/guild relationships.
- Concise, duplicate-safe player tooltip details for confirmed ForeverRP users with cached profiles.
- First-beta documentation, command, persistence, protocol-boundary, and package-structure audit.
- MIT License for public source and addon distribution.

### Notes

- Prepared and validated the `0.1.0-beta` CurseForge archive.
- Interface `11601` verified against Forever beta client build `1.60.1.69913` and installed Forever-specific addon metadata.
- The CurseForge game-version identifier, project ID, and final in-game test pass remain release prerequisites.
