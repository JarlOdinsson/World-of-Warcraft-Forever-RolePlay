# Enhanced discovery test build report

**Historical beta.7 report: superseded after the follow-up audit. Do not distribute
the beta.7 ZIP.** See [the beta.8 report](DIRECTORY_UPDATE_REPORT.md) for the shared
Presence implementation, repaired audit defects and current validation limits.

Version **0.1.1-beta.7**, build **discovery-consent-20261010-7**. Source remains
uncommitted. No deployment, push, tag, release or publication was performed.

## Implementation and preserved behavior

The baseline audit and API references are in [the plan](ENHANCED_DISCOVERY_PLAN.md).
The existing guarded unit identity → directed/social HELLO/ACK → presence → unit
association → conservative range → Nearby/notification pipeline is retained.
Experimental activity is a separate opt-in path and never establishes physical
proximity. Connections notes, own profiles, MingleBar and MSP behavior remain intact.
The existing Settings MingleBar dropdown spacing of 8 is preserved.

New functionality:

- Privacy panel: separate Public/Approval Required/Connections Only disclosure,
  pending owner decisions and explicit saved-Connection grants. Remember/Favorite
  is not authorization. Grants and disclosure persist per character; existing
  users default to Public. Existing visibility still controls discovery and access.
- Optional activity network and zone-organized panel; location hidden by default,
  optional zone-only/precise sharing. Settings are account-wide. All layer states
  remain Unknown; no reliable layer evidence is available in the inspected APIs.
- Neutral noninteractive minimap markers, only recent valid precise data in the
  local zone/coordinate space and view radius. Frames are pooled; no profile clicks,
  tooltips, auto-requests, permanent location storage or layer inference.
- Bing Bong/legacy Drumroll/None, Master/SFX and preview. New installs default to
  Bing Bong; upgrades retain Drumroll and channel/enable preferences. Exact selected
  channel is passed to the API; nil/error/false is not reported as confirmed success.
  Playback spacing is two seconds with handle-based overlap suppression when available.
  No global audio settings are written. A client failure is explicit on preview;
  actual Master audibility remains unverified, not claimed fixed by offline mocks.
- Developer commands restored: debug, diag, sim, hello, presence; new privacy,
  activity and network commands. Simulation still requires debug. Network counters
  contain no coordinates, profiles or notes; diagnostic identity output is intentional.

## Protocol and compatibility

Existing `FOREVERRP` HELLO/ACK/PROFILE_REQUEST/PROFILE_DATA payloads and protocol
version 1 are unchanged. The optional WHISPER extension is
`PROFILE_STATUS|1|version|requestID|pending/denied/revoked`. A revoked notice uses
`REVOKE` as ID, includes no profile contents and is restricted to previously served
recipients. Legacy clients ignore the unknown extension, may time out during owner
approval and may retain previously disclosed profiles; ordinary Public exchange
remains compatible. No new profile fields are placed in presence messages.

The experimental prefix `FOREVERRPX1` carries:
`A1|version|privacyRevision|disclosure|zone|coordinateSpace-or--|x-or--|y-or--`, or
`OFF`. Payloads are bounded to 200 bytes. `UnitPosition`'s mapID is only a coordinate
space, never a layer ID. Raw client transport recipients remain separate from lookup
keys. Metadata uses the transport sender identity; it is self-reported information,
not authenticated geography or physical layer evidence.

Eligible existing group/guild routes are reused. Visible opt-in users additionally
join `ForeverRPActivity` and attempt addon CHANNEL delivery. This transport and its
zone/realm/backend/layer scope require live verification. Friends/Guild Only does
not join the shared channel; friends without shared routes may require existing
directed observed discovery. There is no relay, roster polling, visible chat spam,
automatic profile request or guarantee of server-wide/random-player coverage.

## Privacy and cache limits

Authorization is checked before serialization and every chunk. Approval covers one
request ID for 30 seconds; pending owner requests expire after 25 seconds. Requester
pending status gets one bounded timeout extension, not an unlimited keepalive.
Owner requests: at most 8 pending, 20 processed/minute, 10-second per-peer suppression,
100 peer suppression entries retained for up to five minutes. Saved grants cap at
100 per character. Forget revokes a grant, without touching private notes.

Visibility/disclosure changes cancel disallowed chunks and queue content-free
revocations for up to 100 previously served peers, one attempt/second, three attempts
maximum each. Entering Hidden may send those withdrawal notices, never a location or
profile advertisement. Receiver clears cached profiles and in-flight chunks on revoke.
Updated ForeverRP remote caches have a five-minute runtime lease as a fallback for lost
notices. Client-side settings also prevent disallowed cache display. Legacy, modified
clients, screenshots and copied data cannot be retracted; there is no guarantee of
immediate cache removal after a lost notice. MSP runtime profiles are separate and
these ForeverRP disclosure settings do not control another addon's publication.

Location changes rebuild queued payloads at send time, withdraw old metadata and
reset the experimental cache. Hidden disables advertising; Friends/Guild Only applies
existing verified relationship checks. Lost withdrawal packets can leave a marker
until its 45-second expiry or metadata until its 150-second expiry. Channel membership
and the act of communication are not anonymous, even with location hidden.

## Performance and bandwidth

No new per-frame loops. One-second tickers service authorization and activity;
UI activity refreshes are batched and skipped while hidden. Markers reuse at most
64 frames and avoid repositioning unchanged points. Activity metadata caps at 250
peers; excess new peers are rejected until predictable expiry frees capacity.

Activity sends useful changes at most every 30–40 seconds (10-unit world-coordinate
movement threshold), otherwise heartbeats every 90–110 seconds. Queue cap 3 routes,
one attempted route per second, maximum two attempts with a ten-second retry pause.
Shared token budget: one/second, burst 3, including withdrawal messages. Receiver
acceptance processing caps at 100 attempts/second; equal payloads deduplicate for
30 seconds and peer changes have a five-second minimum interval. No relay loops.

The offline moving-client run produced **18 attempts in 10 minutes on one route**,
despite 10 repeated update events per simulated second. Linear projection for 100
such clients is 1,800 sends/10 minutes (3 sends/second aggregate). A stationary client
generally sends around 6–7 times/10 minutes/route. At 200 bytes maximum this moving
projection is at most 360 KB payload/10 minutes before transport overhead. Up to three
overlapping routes can triple sends and duplicate receive work. Channel fan-out can
produce roughly quadratic aggregate deliveries as population grows; local rate limits
do not remove that server cost. Receive caps deliberately sacrifice freshness under
overload. This is a projection, not a 100-client live benchmark or bandwidth guarantee.

Existing profile queue limits remain 8 transfers, one per peer, 10-second peer
cooldown, 0.1-second chunk spacing and at most two retries per failed chunk. Large
profiles still cost substantially more than metadata. They are explicitly requested,
not refreshed automatically when activity arrives.

## Automated validation

All ten Lua regression suites pass: **943 checks**, including **121 enhanced-discovery
checks across 21 cases**. All **45 runtime Lua files** pass `luac -p`; TOC-loaded
modules also compile in the communication suite. `git diff --check` passes.

Suites: communication (329), Connections (82), restricted values (21), audit fixes
(19), MSP compatibility (15), diagnostics (123), observed discovery (161), notifications
(44), public commands (28), enhanced discovery (121). These use mocked client APIs;
they cannot prove same-layer/cross-layer transport, client sound decoding, actual
Master volume, visual layout, projection orientation or the secret/taint engine.

Owner-provided `nyc-bing-bong.mp3` is bundled byte-for-byte as `Media/Sounds/BingBong.mp3`
(15,690 bytes). SHA256:
`6FA6698B8B224CC6C72D74A1A0A57E812BED7075D4C429CB1DB793FF17A7BA86`.
Owner explicitly confirmed redistribution rights. The recording was not downloaded
from YouTube, independently listened to, decoded, normalized or independently
verified against the reference. Separate rights notice accompanies the file.

## Remaining client work / deferred functionality

Follow [the two-client/guild checklist](ENHANCED_DISCOVERY_TESTING.md). Cross-layer
integration remains experimental and OFF by default; green/blue layer classification
is deferred until reliable client-supported evidence exists. Full server coverage,
automatic invisible-player proximity alerts and live Master playback are not verified.
Minimap replacements, rotating projection, combat/phasing and MP3 decoding need tests.
MSP feature expansion remains paused; no publishing ForeverRP profiles over MSP.

## Exact source files changed or created

Modified:

- `ForeverRP/Core.lua`
- `ForeverRP/Core/Commands.lua`
- `ForeverRP/Core/Constants.lua`
- `ForeverRP/Core/Database.lua`
- `ForeverRP/Core/DiscoveryDiagnostics.lua`
- `ForeverRP/Core/Events.lua`
- `ForeverRP/Discovery/Communication.lua`
- `ForeverRP/Discovery/Presence.lua`
- `ForeverRP/Discovery/ProfileTransfer.lua`
- `ForeverRP/ForeverRP.toc`
- `ForeverRP/Localization/enUS.lua`
- `ForeverRP/Modules/Connections.lua`
- `ForeverRP/Profile/RemoteProfiles.lua`
- `ForeverRP/README.md`
- `ForeverRP/UI/MainWindow.lua`
- `ForeverRP/UI/Notifications.lua`
- `ForeverRP/UI/Settings.lua`
- `README.md`
- `CHANGELOG.md`
- `tests/README.md`
- `tests/discovery_diagnostics.lua`
- `tests/notifications.lua`
- `tests/public_commands.lua`

Created:

- `ForeverRP/Discovery/ProfileAuthorization.lua`
- `ForeverRP/Discovery/Activity.lua`
- `ForeverRP/UI/PlayerMarkers.lua`
- `ForeverRP/UI/DiscoveryOptions.lua`
- `ForeverRP/UI/Activity.lua`
- `ForeverRP/Media/Sounds/BingBong.mp3`
- `ForeverRP/Media/Sounds/NOTICE.md`
- `tests/enhanced_discovery.lua`
- `docs/ENHANCED_DISCOVERY_PLAN.md`
- `docs/ENHANCED_DISCOVERY_TESTING.md`
- `docs/ENHANCED_DISCOVERY_REPORT.md`

Generated testing artifact (ignored by Git): `dist/ForeverRP-v0.1.1-beta.7.zip`.
All 58 archive files were verified against development source by SHA256 (root
README/LICENSE are the packaging script's intentional replacements). Archive size:
137,551 bytes. ZIP SHA256:
`ED37A26C33BC2EA2C89A6EF662495471F55E083E20DC0F951FBB875B886DE6F2`.
