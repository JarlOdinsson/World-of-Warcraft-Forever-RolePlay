# ForeverRP

ForeverRP is a roleplaying profile and proximity-discovery addon built specifically for World of Warcraft Forever.

## Beta features

- Same-layer beta baseline: `0.1.1-beta.20` / `profile-caret-20261016-20`
- Minimap-first interface with no automatic startup window
- Per-character local RP profile editor and read-only viewer
- Confirmed ForeverRP presence and conservative Nearby detection
- Scrollable Nearby browser with click-to-request remote profiles
- Runtime-only, bounded, sanitized remote profile transfers
- Configurable discovery radius, minimap count, pulse, sound, and chat feedback
- Visible, Friends/Guild Only, and Hidden privacy modes
- Concise player-tooltip integration for confirmed ForeverRP users
- Local Connections with favorites and private notes, plus the optional MingleBar
- Dedicated local ForeverRP tab for addon notices and command output
- Visible blinking cursor in the long profile text boxes
- Local minimap dots when independently verified Nearby units expose safe positions

Remote profiles, Nearby state, presence, transfer buffers, and notification cooldowns are session-only. Remote data never overwrites the local profile and is never executed as Lua.

## Installation and usage

Extract the release so the path is `Interface/AddOns/ForeverRP/ForeverRP.toc`. Use the minimap button to open ForeverRP. `/frp`, `/frp profile`, `/frp view`, `/frp nearby`, and `/frp settings` remain available as fallback access.

## Privacy

- Visible allows normal discovery and profile exchange.
- Friends/Guild Only conservatively accepts verified friends and guild members.
- Hidden suppresses discovery and profile responses while preserving local profile tools.

Profiles are sent only after an explicit request from a confirmed, privacy-qualified ForeverRP user. Hovering a tooltip never requests profile data.

## Supported client

World of Warcraft Forever is the sole intended target. Compatibility with other WoW flavors is not claimed.

This beta targets Interface `16001`, CurseForge flavor **Forever**, game version **1.60.1**.

## Paused experimental features and beta limitations

- Cross-layer discovery, RP Directory advertisements, layer inference, and custom-channel joins/recovery are disabled.
- Zone, precise-position and subzone sharing are disabled. Sharing positions only between independently verified Nearby players is future work, not included in this version.
- Minimap dots use local unit positions only; missing/restricted positions and combat hide dots. No layer is inferred from coordinates or message receipt.
- The ForeverRP chat tab is local addon output, not a shared channel for player conversation.
- Friend and guild verification depends on APIs and roster data available in the Forever client.
- Range choices map conservatively to supported interaction brackets rather than exact arbitrary yard measurements.

Issues and source: https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay

ForeverRP is released under the MIT License.
