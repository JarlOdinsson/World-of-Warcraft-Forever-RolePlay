# ForeverRP

ForeverRP provides roleplaying profiles, automatic discovery of consenting ForeverRP users, and proximity notifications for World of Warcraft Forever.

## Current version

`0.1.1-beta.20` — build `profile-caret-20261016-20` (**same-layer beta baseline**).

This build restores the Beta 5 native discovery baseline for same-layer discovery
while preserving later privacy, identity, profile-transfer and combat fixes.
Directory advertisements, shared-channel recovery and layer inference are paused.
The menus retain their existing layout and explain the unavailable controls.

ForeverRP notices, command results, discovery text and enabled debug output now
appear in a dedicated local **ForeverRP** chat tab. The tab is reused on reload,
and creating it preserves your selected tab. No reports are sent to other players.
If chat slots are full or the chat API is unavailable, a one-time explanation and
reports appear in the main local chat window; free a tab and `/reload` to retry.

Beta 20 adds a visible blinking caret to the long profile text boxes and keeps
it in view while editing wrapped text. The current build was accepted by the
maintainer as the same-layer beta baseline on October 16, 2026.

This remains beta software. Client-specific limitations include conservative
range checks, positions unavailable for some units, and hidden dots during combat.
Directory and cross-layer networking remain disabled. For repeatable checks,
use the [two-player checklist](https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay/blob/main/docs/PHASE1_SAME_LAYER_TEST.md)
and [profile cursor retest](https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay/blob/main/docs/BETA20_PROFILE_CARET_RETEST.md).

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

Range choices use conservative interaction-distance brackets rather than exact yard measurements. The 20- and 25-yard settings use the available closer bracket conservatively. Real interaction checks run only when the client explicitly reports combat lockdown inactive. During lockdown, or when combat/range evidence is unavailable or restricted, range is Unknown and cannot qualify a player for Nearby. The normal ticker reevaluates after combat. Directory discovery is paused in Phase 1.

Notifications can pulse the minimap icon, play a sound, and print an optional chat message. Choose **Bing Bong**, **Drumroll** (legacy ready-check sound), or **None**. New installations default to the bundled spoken Bing Bong; upgrades preserve the legacy sound and existing channel/enable settings. **Test Sound** previews the selected **Master** (default) or **Sound Effects** channel. ForeverRP does not change global volume or silently switch channels. A failed or unconfirmed preview reports a limitation; actual loudness and Master routing still require client testing. Preview clicks are rate-limited and do not consume discovery cooldowns.

Automatic notifications retain the per-player cooldown (10 minutes by default). Changes between eligible range brackets do not trigger another entry alert. Presence expires after 15 minutes without renewal; eligible communications renew it conservatively.

Directory, cross-layer advertisements, shared-channel joins/recovery and layer
inference are unavailable in Phase 1. Existing experimental preferences remain
saved, but cannot enable these paths. The addon leaves an old `ForeverRPActivity`
subscription once on login and does not register or send its experimental prefix.
Native guild/party presence exchanges are retained; they establish neither
proximity nor layer membership. No layer number is inferred.

**Privacy** retains the current controls and their positions. Experimental Network,
Directory Participation, location sharing and subzone sharing explain their pause.
**RP Directory** stays in the menu with an empty, explanatory panel. Use **Nearby**
for local discovery. Profile permissions and approvals remain available.

**Minimap Markers** remains an independent local display toggle. Neutral dots use
fresh positions of confirmed, visible Nearby units only when the client exposes
safe coordinates. No position is stored or transmitted. Range, identity, privacy,
coordinate space, zoom and rotation are checked before display; missing or
restricted information and combat hide dots. Dots do not open or request profiles.
Some unit/context combinations may not expose positions: record those limitations
in the live test rather than substituting remote advertisements or guessed dots.
The paused location-sharing preference controls no outgoing traffic in this build.

## Profiles, Connections, and privacy

Your own profiles are saved separately per character. Connections and their private notes are saved account-wide. Notes are preserved through refreshes and selection changes, and are never sent to another player. Received ForeverRP profiles are cached at runtime for up to five minutes and do not overwrite your own profile. MSP data remains separate.

Privacy modes:

- **Visible:** permits normal discovery and profile exchange.
- **Friends/Guild Only:** permits verified friends and guild members; unknown relationships are denied.
- **Hidden:** suppresses presence advertisements and discovery/profile responses while keeping local profile tools available.

ForeverRP profiles are sent only in response to a request from a confirmed, privacy-qualified peer. Requests, responses, and retries are bounded. Profile text is validated and displayed as plain text.

Full-profile disclosure is a separate per-character setting in **Privacy**:

- **Public** preserves existing privacy-qualified profile requests.
- **Approval Required** queues a request for up to 25 seconds. Open Privacy and explicitly Approve or Deny it. Approval covers that transfer only.
- **Connections Only** requires Remember plus an explicit owner grant in Privacy. Favorite and Remember alone do not grant access. Grants are not mutual; Forget removes your grant.

Restrictions are checked before serialization and each outgoing chunk. Changes cancel disallowed transfers and send bounded, content-free cache-revocation notices to previously served peers, including when entering Hidden. Compliant updated clients clear revoked caches; lost notices fall back to the five-minute cache lease. The served-recipient history is capped at 100, so older recipients also rely on that lease. Large concurrent transfers may report busy and require a later explicit retry. Legacy clients may keep previously received data. No addon can retract copied information or prevent a modified client from retaining it.

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

Developer commands remain available for testing: `/frp debug on|off`, `/frp diag [Name-Realm]`, `/frp diag profile`, `/frp hello`, `/frp presence`, and `/frp sim`. Simulation requires debug mode. `/frp network` prints native counters and the Phase 1 pause; channel/probe/trace commands explain the pause and cannot activate experimental traffic. `/frp privacy` opens permissions and saved settings; `/frp directory` opens the paused Directory (`/frp activity` remains an alias). Diagnostic output includes character identities; review captures before sharing.

## Experimental external-profile compatibility

An isolated MSP reader and its required libraries are embedded, so a second RP addon is not required locally. The initial implementation requests external profiles for observed target/mouseover players, applies ForeverRP privacy and request limits, and labels imported profiles **MSP** in the existing viewer.

Live Total RP 3/MyRolePlay interoperability on Forever is not yet verified, and further MSP feature work is paused while discovery is stabilized. External profiles remain separate runtime data: they do not create ForeverRP presence, overwrite your own profile, or change Connections notes. Nearby integration and publishing ForeverRP profiles over MSP are not implemented.

## Testing and development

Use [the Phase 1 two-player checklist](https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay/blob/main/docs/PHASE1_SAME_LAYER_TEST.md) for the release gate and [tests/README.md](https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay/blob/main/tests/README.md) for automated checks. Offline tests do not establish multiplayer delivery, unit-position availability, client taint behavior, visual layout or audio. Historical experimental tests load the Beta 17 archive outside the installable addon; they do not represent enabled Phase 1 behavior.

`ForeverRP/ForeverRP.toc` is the authoritative version source. From the repository root, `powershell -ExecutionPolicy Bypass -File tools/package.ps1` creates a validated ZIP in `dist/`. Generated packages are not committed. Back up the existing addon before replacing its folder; leave `WTF` and SavedVariables untouched.

## License and support

ForeverRP software is MIT-licensed. Embedded libraries retain their own licenses and notices under `ForeverRP/Libs/MSP` in the source repository (`Libs/MSP` inside the installed addon). The supplied Bing Bong recording has separate redistribution permission; see `Media/Sounds/NOTICE.md`. The software license does not license the recording.

Report bugs at [GitHub Issues](https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay/issues). Include your `/frp version` output, reproduction steps, privacy mode, and any Lua error. Do not include private notes or personal profile contents.
