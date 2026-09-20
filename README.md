# ForeverRP

ForeverRP is planned as a roleplaying profile and proximity-based RP discovery addon for World of Warcraft Forever.

## Current status

Version `0.1.0-beta` provides local RP profiles, a minimap-first interface, a live Nearby browser, configurable discovery feedback, bounded profile exchange, account-wide discovery privacy, and player-tooltip integration. Remote profiles remain runtime-only.

## Supported client

ForeverRP targets World of Warcraft Forever only. Interface `11601` was verified against Forever beta client build `1.60.1.69913` and Forever-specific project TOCs. The matching CurseForge game-version identifier still requires confirmation. No compatibility with Retail, Classic Era, Cataclysm, TBC, or other client flavors is claimed.

## Installation

Release archives contain one top-level `ForeverRP/` folder. Extract it into the client's `Interface/AddOns` directory and verify that `Interface/AddOns/ForeverRP/ForeverRP.toc` exists.

Developers can run `tools/install-local.ps1` to sync a validated package to a configurable local AddOns directory.

## Usage and slash commands

Available commands:

- `/frp` - open the main window to Home
- `/frp help` - show concise help
- `/frp settings` - open the main window to Settings
- `/frp profile` - open the local character's Profile editor
- `/frp view` - open the local Profile Viewer
- `/frp hello` - send one development presence announcement
- `/frp presence` - list confirmed ForeverRP users known this session
- `/frp nearby` - list confirmed, detectable ForeverRP users qualifying under the selected radius
- `/frp request <Name-Realm>` - request a profile from a confirmed ForeverRP user
- `/frp version` - show addon, protocol, and database versions
- `/frp debug` - show debug status
- `/frp debug on` - enable persistent debug logging
- `/frp debug off` - disable persistent debug logging

`/foreverrp` is an alias for `/frp`. The minimap button toggles the main window with a left-click, opens Settings with a right-click, and can be dragged around the minimap perimeter.

The minimap button is the primary graphical entry point. No main window opens automatically. The Profile section stores plain-text RP details separately for each character, while Profile Viewer provides a read-only local preview.

The Nearby panel lists current qualifying ForeverRP users. Selecting a row opens an already cached profile or requests it through the existing protocol and opens the same read-only Profile Viewer when the transfer completes.

Confirmed ForeverRP players receive concise additions to player tooltips. Cached profiles can show RP name, title, status, and profile availability. Tooltip display never requests a profile.

Presence means only that another character recently exchanged a valid ForeverRP protocol message through a shared party, raid, instance, or guild channel. It does not indicate physical proximity and expires after 15 minutes without another valid message.

Nearby additionally requires a detectable player unit and a conservative supported range check. The 10-yard option uses the duel interaction bracket, 15/20/25 use the approximately 11-yard trade bracket conservatively, and 30 uses the approximately 28-yard inspect/follow bracket. ForeverRP does not claim exact arbitrary yard measurements.

### Developer and debug commands

With debug mode enabled, `/frp sim` provides local protocol diagnostics using the same parser, dispatcher, and presence cache as real addon traffic:

- `/frp sim hello`
- `/frp sim ack`
- `/frp sim malformed`
- `/frp sim incompatible`
- `/frp sim clear`
- `/frp sim status`
- `/frp sim range 10|15|20|25|30|out|unknown`
- `/frp sim notify on|off|reset|status`
- `/frp sim profile`
- `/frp sim profile malformed`
- `/frp sim profile oversized`
- `/frp sim profile clear`
- `/frp sim privacy visible`
- `/frp sim privacy restricted friend|guild|unknown`
- `/frp sim privacy hidden`

Simulated players are runtime-only, visibly marked in debug presence output, and excluded from normal presence queries.

Profile transfers use the existing confirmed-presence transport, a fixed field schema, bounded chunks, and strict profile limits. Received profiles are sanitized and cached for the current session only. They can be displayed read-only in Profile Viewer and never overwrite the local character profile.

## Privacy modes

- Visible permits normal presence, discovery, and profile exchange.
- Friends/Guild Only accepts verified friends and guild members. Unknown relationships are denied conservatively.
- Hidden suppresses presence advertisement, discovery responses, and profile responses while leaving local profile tools available.

## Privacy and discovery

The local profile is transmitted only in response to an explicit request from a confirmed and privacy-qualified ForeverRP user. Presence, Nearby, relationship trust, notification, transfer, and remote-profile caches are runtime-only. Player-authored profile content remains data and is never executable code.

Discovery feedback can pulse the minimap icon, play a subtle Blizzard sound, and optionally print a chat message. Per-character notification cooldown state is session-only; notification preferences persist account-wide.

## Development and releases

`ForeverRP/ForeverRP.toc` is the authoritative addon-version source. The addon version, future protocol version, and future database schema version are separate concepts.

Run `powershell -ExecutionPolicy Bypass -File tools/package.ps1` from the repository root to create a validated beta archive in `dist/`. Generated archives are not committed.

Development and public-test artifacts default to Beta. Alpha builds use an `-alpha` suffix; stable releases have no suffix and must not be used for untested builds.

The initial goal is zero external libraries. Future dependencies must be license-reviewed and documented as embedded, required, or optional before distribution.

## Known limitations

- The CurseForge game-version identifier and project ID are unknown.
- The project license has not been selected by the owner.
- First-beta client validation and two-client network testing remain required.

## License

ForeverRP is released under the MIT License. See `LICENSE`.

## Issues and source

Report issues and view source at https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay.
