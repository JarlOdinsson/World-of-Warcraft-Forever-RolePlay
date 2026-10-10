# ForeverRP

ForeverRP provides roleplaying profiles, automatic discovery of consenting ForeverRP users, and proximity notifications for World of Warcraft Forever.

## Current version

`0.1.1-beta.10` — build `privacy-clarity-20261010-10` (controlled multiplayer test build).

Beta.9 fixes the bundled Chomp login/Battle.net parser for Forever multiword names and its related MSP recipient corruption. It adds bounded debug-only tracing of actual whisper recipients. The yellow player-not-found error has a reproducible MSP corruption path, but actual delivery still needs retesting; no speculative discovery address rewrite is included. See [the Beta.9 retest guide](https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay/blob/main/docs/BETA9_TRANSPORT_RETEST.md), including shared-library load-order limitations and login/reload tests.

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

Notifications can pulse the minimap icon, play a sound, and print an optional chat message. Choose **Bing Bong**, **Drumroll** (legacy ready-check sound), or **None**. New installations default to the bundled spoken Bing Bong; upgrades preserve the legacy sound and existing channel/enable settings. **Test Sound** previews the selected **Master** (default) or **Sound Effects** channel. ForeverRP does not change global volume or silently switch channels. A failed or unconfirmed preview reports a limitation; actual loudness and Master routing still require client testing. Preview clicks are rate-limited and do not consume discovery cooldowns.

Automatic notifications retain the per-player cooldown (10 minutes by default). Changes between eligible range brackets do not trigger another entry alert. Presence expires after 15 minutes without renewal; eligible communications renew it conservatively.

Cross-layer delivery remains unverified. **Privacy** contains an experimental network toggle, off by default. When Visible and opted in, it joins `ForeverRPActivity` and sends compact addon metadata over available group/guild/shared-channel routes. This is a transport prototype, not a verified server-wide discovery service. Friends/Guild Only uses eligible social routes and does not join the shared channel. Hidden sends no activity advertisements. No messages are relayed.

The Privacy panel shows Discovery Visibility (changed in Settings) and whether the saved Experimental Network preference is paused. Hidden visibility or disabled discovery blocks directory networking. Directory Participation OFF stops listing your character while still allowing browsing; withholding location also allows browsing when networking is otherwise enabled.

Choose **Don't share my location** (default), **Share zone only**, or **Share precise location**. Optional **Subzone sharing** is off by default and requires zone or precise sharing. Optional minimap markers require valid precise coordinates received within 125 seconds, in your current zone and coordinate space. All markers are neutral and noninteractive; layer status is always **Unknown** because no reliable layer identifier is available. Markers do not request or open profiles and do not establish Nearby eligibility. Cross-layer markers, world-wide channel coverage, and map projection need live validation.

**RP Directory** reuses the experimental Activity panel and the existing Presence cache. **Directory participation** is an independent, explicit opt-in in Privacy; it does not enable networking, reveal your location, or grant full-profile access. Both clients must enable experimental networking to exchange directory metadata. Default listings include IC and LF RP users; OOC and AFK require the expanded filter, and DND is always excluded. Search and zone/status filters use cached data without sending requests. Region means continent when the client map hierarchy supplies it, otherwise Unknown. Select **Request Profile** explicitly to use the existing transfer/approval workflow. Character identities are displayed; RP display names and biographies are not broadcast in directory packets.

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

Developer commands are restored for testing: `/frp debug on|off`, `/frp diag [Name-Realm]`, `/frp hello`, `/frp presence`, and `/frp sim`. Simulation requires debug mode. `/frp network` prints aggregate traffic/expiry/denial counters without profile contents or coordinates. `/frp privacy` opens disclosure and experimental settings; `/frp directory` opens RP Directory (`/frp activity` remains an alias). Diagnostic output includes character identities; review captures before sharing.

## Experimental external-profile compatibility

An isolated MSP reader and its required libraries are embedded, so a second RP addon is not required locally. The initial implementation requests external profiles for observed target/mouseover players, applies ForeverRP privacy and request limits, and labels imported profiles **MSP** in the existing viewer.

Live Total RP 3/MyRolePlay interoperability on Forever is not yet verified, and further MSP feature work is paused while discovery is stabilized. External profiles remain separate runtime data: they do not create ForeverRP presence, overwrite your own profile, or change Connections notes. Nearby integration and publishing ForeverRP profiles over MSP are not implemented.

## Testing and development

See [tests/README.md](https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay/blob/main/tests/README.md) in the source repository for offline regression suites and [the guild checklist](https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay/blob/main/docs/DIRECTORY_GUILD_TESTING.md) for client validation. These source documents accompany beta.8 and may not be on GitHub until explicitly pushed. Offline mocks do not establish live delivery, visual layout, actual sound volume, or cross-layer compatibility. The earlier beta.7 test ZIP is superseded following audit findings; use beta.8 for the next controlled retest.

`ForeverRP/ForeverRP.toc` is the authoritative version source. From the repository root, `powershell -ExecutionPolicy Bypass -File tools/package.ps1` creates a validated beta ZIP in `dist/`. Generated packages are not committed. Before a local deployment, back up the existing addon outside the destination and verify installed files against source; leave `WTF` and SavedVariables untouched.

## License and support

ForeverRP software is MIT-licensed. Embedded libraries retain their own licenses and notices under `ForeverRP/Libs/MSP` in the source repository (`Libs/MSP` inside the installed addon). The supplied Bing Bong recording has separate redistribution permission; see `Media/Sounds/NOTICE.md`. The software license does not license the recording.

Report bugs at [GitHub Issues](https://github.com/JarlOdinsson/World-of-Warcraft-Forever-RolePlay/issues). Include your `/frp version` output, reproduction steps, privacy mode, and any Lua error. Do not include private notes or personal profile contents.
