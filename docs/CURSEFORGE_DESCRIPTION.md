# ForeverRP

ForeverRP is a roleplaying profile and proximity-discovery addon built specifically for World of Warcraft Forever.

## Beta features

- Minimap-first interface with no automatic startup window
- Per-character local RP profile editor and read-only viewer
- Confirmed ForeverRP presence and conservative Nearby detection
- Scrollable Nearby browser with click-to-request remote profiles
- Runtime-only, bounded, sanitized remote profile transfers
- Configurable discovery radius, minimap count, pulse, sound, and chat feedback
- Visible, Friends/Guild Only, and Hidden privacy modes
- Concise player-tooltip integration for confirmed ForeverRP users

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

This beta targets Interface `11601`, verified against Forever beta client build `1.60.1.69913`.

## First-beta limitations

- The matching CurseForge game-version entry must be selected manually.
- Friend and guild verification depends on APIs and roster data available in the Forever client.
- Range choices map conservatively to supported interaction brackets rather than exact arbitrary yard measurements.

Issues and source: https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay

ForeverRP is released under the MIT License.
