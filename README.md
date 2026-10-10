# ForeverRP

ForeverRP provides roleplaying profiles, automatic discovery of consenting ForeverRP users, and proximity notifications for World of Warcraft Forever.

## Current version

`0.1.1-beta.6` — build `public-cleanup-20261010-6`.

This beta includes player detection, profile requests and viewing, private Connections, configurable discovery notifications, and the optional MingleBar RP action bar. Live testers have confirmed detection and profile retrieval. Broader testing across client settings, combat, crowded areas, and layers continues.

## Installation

ForeverRP targets World of Warcraft Forever only (`## Interface: 16001`). Compatibility with Retail or other Classic clients is not claimed.

Extract the release's `ForeverRP` folder into your Forever installation's `Interface/AddOns` directory. The resulting path should be `Interface/AddOns/ForeverRP/ForeverRP.toc`, with no extra nested addon folder. Enable ForeverRP in the character-selection AddOns list. Restart the client for a first installation; use `/reload` after updating an existing installation.

## Getting started

1. Open ForeverRP with `/frp` or left-click its minimap button.
2. Open **Profile** to write and save your character's RP information. **Profile Viewer** previews your own profile.
3. Open **Settings** to choose your discovery radius, privacy mode, and notifications.
4. Look in **Nearby** for confirmed ForeverRP users who qualify under the configured range. Select a player to view a cached profile or request their profile.
5. Use **Remember** to save a player to **Connections**. Favorite remembered players and add private notes there. Saved Connections can request a fresh profile when existing communications confirm the player is reachable; otherwise the profile action shows unavailable.

Right-click the minimap button to open Settings. Drag the button around the minimap to reposition it.

## Discovery and notifications

ForeverRP observes player identities through target, mouseover, focus, nameplates, and group units. Independently observed target, mouseover, and nameplate players can receive a bounded directed discovery handshake. Group and guild announcements provide additional routes for establishing presence.

A visible player is not automatically a ForeverRP user. A valid ForeverRP exchange must confirm presence before that player can appear in Nearby. Nearby also requires a matching, usable player unit and a passing range check. Missing or unknown range never qualifies as nearby.

Detection without a shared party or guild depends on the client exposing an observable unit and delivering the directed handshake. Friendly nameplate settings and visibility can affect automatic pass-by coverage. ForeverRP cannot enumerate every roleplayer on the server or guarantee detection of every passing player.

Range choices use conservative interaction-distance brackets rather than exact yard measurements. The 20- and 25-yard settings use the available closer bracket conservatively.

Notifications can pulse the minimap icon, play a ready-check alert, and print an optional chat message. **Test Sound** previews the alert using the selected **Master** (default) or **Sound Effects** channel. ForeverRP does not change global volume. Preview clicks are rate-limited and do not consume discovery cooldowns.

Automatic notifications retain the per-player cooldown (10 minutes by default). Changes between eligible range brackets do not trigger another entry alert. Presence expires after 15 minutes without renewal; eligible communications renew it conservatively.

Cross-layer discovery and reliable layer identification remain under investigation. Receiving an addon message does not establish physical proximity or a shared layer.

## Profiles, Connections, and privacy

Your own profiles are saved separately per character. Connections and their private notes are saved account-wide. Notes are preserved through refreshes and selection changes, and are never sent to another player. Received remote profiles are cached for the current session and do not overwrite your own profile.

Privacy modes:

- **Visible:** permits normal discovery and profile exchange.
- **Friends/Guild Only:** permits verified friends and guild members; unknown relationships are denied.
- **Hidden:** suppresses presence advertisements and discovery/profile responses while keeping local profile tools available.

ForeverRP profiles are sent only in response to a request from a confirmed, privacy-qualified peer. Requests, responses, and retries are bounded. Profile text is validated and displayed as plain text.

Player tooltips can show concise information for confirmed ForeverRP users. Tooltip display itself does not request a profile.

## MingleBar

The optional RP action bar provides 1–12 configurable actions, including Blizzard emote presets and custom `/e` text. Position, scale, lock state, and slot configuration persist. Actions run only when clicked; the bar never performs them automatically.

## Commands

`/foreverrp` is an alias for `/frp`.

| Command | Action |
| --- | --- |
| `/frp` | Open the main window |
| `/frp help` | Show command help |
| `/frp settings` | Open Settings |
| `/frp profile` | Edit your own profile |
| `/frp view` | Preview your own profile |
| `/frp nearby` | List currently qualifying nearby users in chat |
| `/frp request <Name-Realm>` | Request a confirmed user's profile; retain the full character name, including spaces |
| `/frp version` | Show version, build, protocol, and database identifiers |

Developer debug, diagnostic, manual HELLO/presence, and simulation slash commands are not available in this public build.

## Experimental external-profile compatibility

An isolated MSP reader and its required libraries are embedded, so a second RP addon is not required locally. The initial implementation requests external profiles for observed target/mouseover players, applies ForeverRP privacy and request limits, and labels imported profiles **MSP** in the existing viewer.

Live Total RP 3/MyRolePlay interoperability on Forever is not yet verified, and further MSP feature work is paused while discovery is stabilized. External profiles remain separate runtime data: they do not create ForeverRP presence, overwrite your own profile, or change Connections notes. Nearby integration and publishing ForeverRP profiles over MSP are not implemented.

## Testing and development

See [tests/README.md](https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay/blob/main/tests/README.md) in the source repository for offline regression suites. Offline mocks do not establish live delivery, visual layout, actual sound volume, or cross-layer compatibility.

`ForeverRP/ForeverRP.toc` is the authoritative version source. From the repository root, `powershell -ExecutionPolicy Bypass -File tools/package.ps1` creates a validated beta ZIP in `dist/`. Generated packages are not committed. Before a local deployment, back up the existing addon outside the destination and verify installed files against source; leave `WTF` and SavedVariables untouched.

## License and support

ForeverRP is MIT-licensed. Embedded libraries retain their own licenses and notices under `ForeverRP/Libs/MSP` in the source repository (`Libs/MSP` inside the installed addon).

Report bugs at [GitHub Issues](https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay/issues). Include your `/frp version` output, reproduction steps, privacy mode, and any Lua error. Do not include private notes or personal profile contents.
