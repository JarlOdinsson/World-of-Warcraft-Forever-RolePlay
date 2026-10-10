# beta.8 architecture, audit repairs and readiness

Version: **0.1.1-beta.8**. Build: **directory-consent-20261010-8**.
Target: Forever Beta 1.60.1, Interface 16001. This is a controlled test build.
No deployment, commit, push, tag or publication is part of this work.

## Architecture audit and reuse

The working pipeline remains client unit observation → bounded directed/social
HELLO/ACK → identity/privacy acceptance → confirmed Presence → associated unit →
conservative range → Nearby → existing notification. A directory record alone
cannot pass the unit/range checks. Existing multiword-name resolution and raw
transport recipients remain separate from canonical lookup keys.

One runtime player store, `Presence.players`, now holds optional `.activity`
metadata. Directory and minimap markers consume that metadata; Nearby consumes
the same confirmed presence with its stricter physical eligibility rules. There
is no parallel Activity peer database. Legacy HELLO/ACK records retain priority:
broad metadata may use free cache slots but cannot evict existing legacy peers.
The existing one-second Nearby timer services authorization and activity too.
The profile-transfer scheduler and existing communication lifecycle remain.

Reused modules: Presence normalization/expiry, Privacy relationships, Communication
registration/send adapters, ProfileTransfer and RemoteProfiles, Connections,
NearbyUI's explicit profile action, native dropdown/buttons/fonts/scroll frames,
existing Profile status controls and notification cooldowns. The prior uncommitted
Activity panel becomes RP Directory; Nearby is not replaced and no additional
directory window is created. Existing minimap launcher code is untouched. The
user's MingleBar Settings dropdown spacing of 8 is retained.

New modules in the combined update are Activity (metadata scheduling/parsing),
ProfileAuthorization (explicit disclosure enforcement), DiscoveryOptions (privacy
controls), ActivityUI (the reused directory panel) and PlayerMarkers (pooled pins).
No new libraries are introduced. Existing MSP work is unchanged and remains
unverified on Forever.

## Implemented functionality and settings

| Setting | Default / scope | Behavior |
| --- | --- | --- |
| Existing discovery visibility | Preserved | Visible, Friends/Guild Only, Hidden remain authoritative |
| Profile disclosure | Public / character | Approval Required or explicitly granted Connections Only |
| Connection approvals | Empty / character | Remember or Favorite alone never grants access |
| Experimental networking | OFF / account | Enables optional metadata transport, not a claim of cross-layer support |
| Directory participation | OFF / account | Independent opt-in; does not enable networking or reveal location |
| Location | Hidden / account | Hidden, zone only, or precise coordinates |
| Share subzone | OFF / account | Only sent when location permits a zone |
| Minimap markers | OFF / account | Local rendering toggle, independent of publishing coordinates |
| Sound choice | Bing Bong on new installs / account | Existing users retain legacy Drumroll or an already selected option |
| Sound channel / enable / cooldown | Preserved | Master default, SFX supported; no global volume changes |

Directory search and zone/status filters operate locally. IC and LF RP are shown
by default; OOC/AFK require the expanded filter. DND is excluded even under All.
Client AFK/DND flags do not overwrite chosen RP state. Legacy AFK/DND profile
values remain usable. LF RP maps to IC in the existing full-profile wire schema
so older readers can deserialize it; the new metadata carries LF RP explicitly.

Directory rows show character identity, allowed location, continent or Unknown,
status, and an explicit profile action with pending/unavailable handling. Character
search preserves spaces. No RP display name or biography is broadcast; optional
authorized RP display-name presentation is deferred. Region means a continent
found in a bounded client map-hierarchy walk, never a server region or layer.

## Protocol and traffic limits

The legacy FOREVERRP protocol/version and HELLO/ACK layout are unchanged. Optional
metadata uses prefix `FOREVERRPX1`, visible shared channel `ForeverRPActivity`,
and eligible existing group/guild routes. The shared channel is joined only when
Visible and explicitly enabled. Restricted mode uses eligible social routes and
does not join the shared channel. Hidden advertises nothing. There is no roster
scan, server-wide search, relay or automatic full-profile download.

Compact metadata, capped at 200 bytes:

`A2|version|revision|disclosure|zone|space|x|y|directory|status|availability|continent|encodedSubzone`

Hidden location uses zone/continent 0, no coordinates/subzone. Optional subzone
is percent-encoded, checked for controls/pipes and bounded to 64 decoded bytes;
it is omitted if encoding would exceed the packet cap. Older A1 metadata is
accepted without implicitly granting directory participation. `OFF` withdraws
metadata, not independent legacy Nearby presence. No unverified layer ID is sent.

New content-free `PROFILE_STATUS` messages carry pending/denied/revoked/busy.
Older clients may ignore those statuses and time out normally. Approval decisions
are transfer-specific; pending decisions expire after 25 seconds, permits after
30. Access is checked before serialization and every outgoing chunk.

| Limit | Value |
| --- | --- |
| Shared Presence records | 250, metadata uses free slots only |
| Activity metadata freshness | 150 seconds |
| Marker freshness | 125 seconds; same zone/space and within minimap radius |
| Marker frames | 64 pooled, neutral, mouse-disabled |
| Metadata moving/useful-change interval | 30–40 seconds; movement threshold 10 world units |
| Stationary metadata heartbeat | 90–110 seconds |
| Routes / pending metadata | At most 3 per announcement |
| Metadata send budget | 1 token/sec, burst 3; queue attempts at least 1 second apart |
| Failed metadata route | At most 2 attempts, 10 seconds between failures |
| Prefix recovery | At most 3 registration attempts, 10 seconds apart |
| Metadata receive budget | At most 100 attempts/sec per client |
| Per-peer metadata update / identical duplicate | 5 seconds / 30 seconds, privacy withdrawals bypass the update wait |
| Authorization prompts | At most 8 pending; 20 admitted requests/min; peer cooldown 10 seconds |
| Authorization recent peers / history | 100 / 300 seconds |
| Served recipient / revocation history | At most 100; oldest served recipient evicted predictably |
| Revocation transport | At most 1 attempt/sec, 3 attempts per notice |
| Remote profile lease | 5 minutes, runtime only |

Stationary traffic on one route is roughly 6–7 announcements per ten minutes;
continuous movement is roughly 15–20. Multiple routes multiply sends by at most
three, before bounded failure retries. The mocked movement test records 18 attempts
over ten minutes on one route. Legacy handshakes, full-profile responses and cache
revocations have separate existing bounds and must also be included in live load
measurements. Filter edits send nothing. Under saturated receive/cache limits,
records may be dropped and discovery coverage can be incomplete. CPU work is
bounded by these caps but no real-client CPU or bandwidth benchmark is claimed.

## Confirmed audit failures repaired

1. Historical GUILD activity could re-establish relationship trust after leaving
   a guild. Expiry rechecks current WHISPER privacy; old transport provenance is
   never replayed as evidence. Queued profiles remain subject to chunk-time checks.
2. The earlier independent activity cache could evict legacy confirmed presence.
   Unified optional metadata cannot displace existing peers at capacity; legacy
   ingress evicts metadata-only records before legacy records.
3. Large approved responses could expire while waiting behind other responses.
   Admission estimates queued chunks at the real 0.1-second cadence, with a
   3-second margin inside the 30-second window. Excess work returns busy. Accepted
   responses have an explicit deadline and bounded failure cleanup. Throttling
   can still exhaust a deadline; acceptance is not a delivery guarantee.
4. Revocations could grow for unserved saved contacts or arrive after fresh
   authorized data. Only served peers qualify, history is capped at 100, and
   fresh authorization/data cancels obsolete notices. Raw transport addresses
   survive Hidden clearing the Presence cache. Older evicted recipients rely on
   the five-minute lease rather than an immediate notice.
5. Stationary markers expired after 45 seconds despite 90–110-second heartbeats.
   Freshness is now 125 seconds; projection tests cover rotation and zoom. Lost
   withdrawal packets can leave a marker for that bounded interval.
6. Optional prefix registration had no recovery. It now retries at most three
   times; toggling the optional network starts a new bounded lifecycle.

## Privacy and security review

Visibility, directory consent, location permission and full-profile disclosure
are independent. Hidden suppresses metadata and new full-profile sends. Approval
or a saved Connection alone cannot bypass existing friend/guild restrictions.
Connections Only requires both Remember and an explicit owner grant. Forget
removes that grant. No received packet writes own profiles or private notes.

Remote text is validated and escaped at display. Inaccessible client values
produce no location/region or conservative availability. No protected values
are unwrapped or reconstructed. Metadata parser/caches/prompts/queues are bounded;
malformed packets cannot add arbitrary fields. Debug/network counters contain no
biographies, notes or precise-location payloads. Existing per-peer diagnostics
do contain character identities and should be reviewed before sharing.

Revocation clears compliant caches and stops future chunks; it cannot retract
copied data. Old or modified clients can retain what they received. Setting
visibility Hidden cannot conceal a character visible in the game world. The
visible shared-channel membership itself is not anonymous. Metadata is asserted
by the direct sender, not authenticated proof of physical location or layer.

## Forever API and license investigation

The [Forever UI source branch](https://github.com/Gethe/wow-ui-source/tree/forever)
provides generated [chat signatures](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua),
[sound signatures](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua),
[map hierarchy](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua),
and [minimap view radius](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MinimapDocumentation.lua).
These establish inspected signatures, not current client delivery, decoding or
audio volume. Known boolean/enum registration/send adapters are retained; success
means accepted for enqueueing. Channel scope, guild delivery across layers,
joining/delivery on a custom addon channel, UnitPosition coordinate semantics,
continent data and Master routing remain live validation items.

All five requested implementation references were reviewed; none was copied:

| Reference | Review outcome |
| --- | --- |
| [MinimapTracking](https://github.com/isfir/MinimapTracking) | GPL-3.0 project, Vanilla 1.12/VanillaHelpers assumptions; not embedded |
| [SimpleMapCoordinates](https://github.com/kemayo/wow-simplemapcoordinates/blob/main/minimap.lua) | View-radius/coordinate update patterns; license not confirmed in this review, no code copied |
| [CartoMapper](https://github.com/Zendevve/CartoMapper/blob/main/LICENSE) | Explicit proprietary restrictions; no implementation reused |
| [WowHousingDecor UI](https://github.com/dmcdelite/wow-housing-decor/blob/main/WowHousingDecor_UI.lua) | Large custom UI not appropriate for this minimal extension; license not confirmed, no code copied |
| [HereBeDragons Pins in HerbTimer](https://github.com/keymaster-hub/HerbTimer/blob/main/HereBeDragons-Pins-2.0.lua) | Projection/rotation/pooling lifecycle reference; vendored licensing not verified, no code copied |

Our small pooled marker renderer uses client APIs and independently tested
coordinate math; it does not embed these projects or add their dependencies.
All markers remain neutral Unknown. Same/Different Layer colors are deliberately
not enabled: no reliable evidence or actual cross-layer test establishes them.
Verified cross-layer integration remains deferred behind the disabled flag.

The exact supplied `Media/Sounds/nyc-bing-bong.mp3` is 15,690 bytes, SHA-256
`6FA6698B8B224CC6C72D74A1A0A57E812BED7075D4C429CB1DB793FF17A7BA86`.
Original bytes are retained with the owner's redistribution permission and a
separate notice. The asset is not relicensed under MIT. No YouTube audio was
downloaded. Master/SFX arguments, success/failure, None, preview and overlap limits
are mocked; actual MP3 decoding, loudness and Master-channel repair are unverified.

## Automated validation

Run all eleven suites listed in [tests/README.md](../tests/README.md). They exercise
the actual modules under Lua 5.1 mocks, including:

- Original communication, Connections notes/timestamps, restricted values,
  privacy/cache/queue audit fixes, MSP isolation, discovery diagnostics, observed
  discovery, notification settings, commands and enhanced consent regressions.
- Exact Linea Aspera/Ravisholan Ruefield split-name returns in the combined new
  lifecycle, legacy HELLO/ACK, usable units/range and notification suppression.
- Explicit directory opt-in/out, local filters, DND/AFK/OOC, map/subzone permissions,
  260-peer pressure, bounded prefixes, raw-address revocation and stale-notice races.
- Actual delayed timers with 218-chunk profiles: first approval completes all
  chunks in 21.7 seconds; second/third are rejected as busy rather than partly sent.
- Real directory UI callbacks using mock widgets, explicit profile request/pending
  state, marker freshness/rotation/zoom and preserved SavedVariables defaults.

Final validation on 2026-10-10: all **11 suites / 1,279 checks** passed. The new
directory suite contains 16 cases / 336 checks, including rejection counters and forced expired-response
cleanup to prevent recursive removal and overdue sends. `luac -p` passed for all
45 runtime Lua files plus 12 test/helper Lua files. `git diff --check` and the
untracked-source whitespace check passed.

`tools/package.ps1` produced `dist/ForeverRP-v0.1.1-beta.8.zip` (142,112 bytes).
All 58 packaged files match their development inputs by SHA-256, including every
runtime Lua file, TOC/build identifier and exact MP3 path. The packager intentionally
uses the repository-root README/LICENSE; verification honors those existing
overrides. Root and addon LICENSE text agree but have different line endings.
No packaging script or license file was modified. Archive SHA-256:
`DB768B78E2CC7C81FB66DA7C590671E68A4FB5163C2AFDD489F74213BF9E4063`.

Mocks do not emulate the secret-value engine, rendering,
game sound mixer, actual multiplayer transport, layering or client shutdown.
Existing MingleBar and launcher preservation is checked through source scope,
not a substitute for the live regression checklist.

## Release readiness and remaining work

**Suitable for controlled guild testing after local smoke testing; not approved
as a verified public or cross-layer release.** The earlier beta.7 ZIP is held and
superseded. Use only the version/build above for the next retest.

Required client checks: discovery without shared group/guild; phase/layer transport;
marker axes, rotation, zoom and stale removal; sound decoding and Master/SFX;
UI fit/scrolling; reload persistence; approval/revocation with real throttling;
moderate/high population responsiveness. Follow [the guild guide](DIRECTORY_GUILD_TESTING.md).

Unimplemented intentionally: verified Same/Different Layer evidence/colors,
guaranteed server-wide coverage, automatic profiles, unrestricted relays, remote
RP-name broadcast, expanded MSP functionality and global audio adjustments.

## Exact change inventory

Relative paths are against the repository root. Includes the earlier uncommitted
enhanced update plus this request; no unrelated source changes were discarded.

Modified runtime files: `ForeverRP/Core.lua`, `ForeverRP/Core/Commands.lua`,
`ForeverRP/Core/Constants.lua`, `ForeverRP/Core/Database.lua`,
`ForeverRP/Core/DiscoveryDiagnostics.lua`, `ForeverRP/Core/Events.lua`,
`ForeverRP/Discovery/Communication.lua`, `ForeverRP/Discovery/NearbyPlayers.lua`,
`ForeverRP/Discovery/Presence.lua`, `ForeverRP/Discovery/ProfileTransfer.lua`,
`ForeverRP/ForeverRP.toc`, `ForeverRP/Localization/enUS.lua`,
`ForeverRP/Modules/Connections.lua`, `ForeverRP/Profile/RemoteProfiles.lua`,
`ForeverRP/UI/MainWindow.lua`, `ForeverRP/UI/Notifications.lua`,
`ForeverRP/UI/Settings.lua`.

New runtime modules/assets: `ForeverRP/Discovery/Activity.lua`,
`ForeverRP/Discovery/ProfileAuthorization.lua`, `ForeverRP/UI/Activity.lua`,
`ForeverRP/UI/DiscoveryOptions.lua`, `ForeverRP/UI/PlayerMarkers.lua`,
`ForeverRP/Media/Sounds/nyc-bing-bong.mp3`, `ForeverRP/Media/Sounds/NOTICE.md`.

Modified documentation/tests: `README.md`, `ForeverRP/README.md`, `CHANGELOG.md`,
`tests/README.md`, `tests/discovery_diagnostics.lua`, `tests/notifications.lua`,
`tests/public_commands.lua`.

New documentation/tests: `docs/ENHANCED_DISCOVERY_PLAN.md`,
`docs/ENHANCED_DISCOVERY_REPORT.md`, `docs/ENHANCED_DISCOVERY_TESTING.md`,
`docs/DIRECTORY_UPDATE_REPORT.md`, `docs/DIRECTORY_GUILD_TESTING.md`,
`tests/enhanced_discovery.lua`, `tests/directory.lua`,
`tests/helpers/client_fixture.lua`.
