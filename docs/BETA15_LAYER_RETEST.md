# Beta 15: inferred Directory layers and cleanup

Version `0.1.1-beta.15`, build `layer-inference-20261011-15`.
Live inference accuracy and cross-layer transport tests: **NOT RUN**.
This controlled test build displays experimental inferences, not official layer numbers.

## Reference investigation

The supplied LayerSwap 1.10 ZIP targets Interface 16001 among other clients.
Its `LayerSwap.lua:711-715,816-834` observes creature/vehicle GUIDs, extracts server
and zoneUID components, requires two agreeing unique GUIDs initially and three
when changing its current candidate, and assigns local A/B/C labels. The author
reports Forever observations in comments; these are reference claims, not our
independently reproduced live results. Local labels are not portable between clients.
Its world/zone/shard handling is at lines 2213-2233. No source was copied, no
LayerSwap dependency was added, and ForeverRP does not invite, join, leave or hop layers.

The [Blizzard-generated UnitGUID documentation mirrored in UI source](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
marks identity outputs potentially restricted. That is retail reference behavior,
not proof of Forever's GUID component semantics. This implementation guards
arguments and returned GUIDs with the existing accessibility adapter before
comparison, parsing or indexing; it never unwraps restricted data.

## Independent implementation

- Interface 16001, accessible outdoor context and numeric current UI-map zone required.
- NPC target, mouseover and nameplate events supply Creature GUIDs independently
  of player detection. Players, pets, vehicles, missing and inaccessible GUIDs do not vote.
- At least three distinct agreeing creature GUIDs; any retained conflicting
  observation makes the result unknown. Eight samples maximum; samples expire at
  120 seconds. Repeated observations of the same GUID do not renew its vote.
- Candidate is `serverID:instance/mapID:zoneUID`, additionally scoped to UI-map
  zone. Distinct server/map/scope values are preserved. No realm aliases or local letters.
- World entry, zone change, group join/leave and supported shard-transfer events
  reset evidence. Imminent transfer suspends collection until transfer/world reset.
  Instances and unsupported/missing APIs produce unknown. Unsigned/unannounced
  phasing remains a risk until observations conflict or age out.
- Directory rows show Same layer — inferred, Different layer — inferred, or
  Layer unknown, plus a fresh peer identifier as secondary text. Different UI-map
  zones or different GUID map components are not comparable. Labels refresh on
  the existing one-second lifecycle.
- Directory membership is unchanged; a different inferred layer does not remove
  a listing. Neither layer evidence nor Directory membership admits a player to Nearby.

## Privacy, transport and compatibility

No settings/defaults/SavedVariables keys changed. Sharing requires enabled
discovery and Experimental Network, non-Hidden visibility, Directory participation,
non-DND availability, and zone/precise location sharing. Withheld location also
withholds layer evidence. Existing Friends/Guild and channel gates still apply.
Collection does not require LayerSwap, a remote player unit or previous Nearby discovery.

The A1/A2 packet stays unchanged. An optional `L1|zone|server:map:scope|count|age|session:generation`
companion (or `L1|OFF` for insufficient evidence) uses the same optional prefix,
routes, 200-byte bound and token budget. It follows a successful A2 enqueue on
each route. There are still at most three queued route jobs, with at most two
attempts per stage, one-second send spacing, ten-second retry spacing, and the
existing 30-40 second minimum announcement interval / 90-110 second heartbeat.
Each route cycle may now send two packets instead of one. No additional channel
or whisper route was introduced. Enqueue success is not confirmed delivery.

Old clients ignore L1 while retaining A2 listings; new clients display unknown for
old clients without L1. L1 cannot create presence, refresh profile data, renew
coordinate age or cause notifications. Evidence has its own observation age;
ordinary HELLO/A2 activity cannot refresh it. Replayed proof tokens cannot extend
freshness. Fresh observations may supply a new proof token. Peer metadata remains
self-reported and unauthenticated, not a security or proximity guarantee.

## Short two-client live retest

Use **this same ZIP** on both clients. Start with `/reload`, then capture
`/frp version` and `/frp network` on both (network report is rate limited).
Opt in manually: discovery enabled, Visible, Experimental Network ON,
Directory Participation ON, Share zone only or precise, IC/LF RP.

1. **Same zone / same layer:** stand together and verify mutual visibility.
   Each observe at least three distinct nearby stationary NPCs via target,
   mouseover or nameplates. Open Directory. Allow up to 40 seconds for the next
   bounded advertisement, plus real transport delay. Capture both rows and
   `/frp network`: zone, raw identifier, sample count and age. Expect matching
   identifiers and Same layer — inferred; do not use A/B letters as evidence.
2. **Same zone / separate layers:** establish separation using the client's
   supported manual flow or the separately installed LayerSwap; ForeverRP does
   not initiate it. Keep both at the same landmark and corroborate the world
   transition and changed visibility independently. Do not form a party that
   puts both back together. Reobserve three NPCs each and capture the same
   outputs. Expect Different layer — inferred only with fresh, differing,
   same-zone evidence. Both remain in Directory; no cross-layer Nearby alert.
3. **Layer switch:** record before/after evidence. Expect unknown during the
   transition, then an updated inference after three new agreeing observations
   and delivery. If no reset event is exposed, report that limitation instead
   of accepting an unchanged cached identifier as proof.
4. **Zone change / expiry:** move one client to another zone. Expect unknown
   while zones differ; three new observations are needed in the new zone.
   For expiry, stop observing new NPCs while remaining online. At 120 seconds
   from the oldest retained agreeing observation, the local comparison must
   become unknown. Continue HELLO/ordinary Directory traffic: it must not renew
   the old evidence. Do not `/reload` to make cleanup pass.

Also verify local Minimap Markers OFF immediately hides all dots; remote Don't
share my location removes that peer's dot when its update arrives; movement,
zoom and profile retrieval still work. Check the status edit shortcut and that
Directory filters do not change your advertised RP status. Capture any Lua or
ADDON BLOCKED errors and both `/frp network` reports on a failure.

## Offline validation scope

`tests/layer_evidence.lua` exercises inaccessible values, unique votes, conflict,
caps, expiry, transitions, privacy, rendering, independent clocks, real Nearby
non-admission and the actual bounded sender. Optional argument points to an
extracted older addon to replay its real parser:

```
lua tests/layer_evidence.lua build/beta12-profile-audit/ForeverRP
```

`tests/player_markers.lua` covers immediate setting/remote-withholding cleanup,
pooled reuse, coordinate expiry with unrelated presence traffic, failed prefix
registration, movement, rotation and zoom. Tests use mocks; they cannot prove
GUID-to-layer accuracy, cross-layer channel delivery, client font layout or
real taint behavior. Do not call live compatibility verified until the above
same/separate-layer matrix passes on both clients.

Validation completed: 19 suites / 2,615 checks, Lua 5.1; all 67 runtime/test/helper
Lua files passed `luac -p`; `git diff --check` passed. Actual Beta 12 parser replay:
153 checks; actual Beta 12 profile responder replay: 205 checks. These are offline
results, not live delivery or layer-accuracy evidence.

Package: `dist/ForeverRP-v0.1.1-beta.15.zip`.
Installed: `D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverRP`.
All 60 installed files hash-matched both the ZIP and source (root README/LICENSE
are packaging overrides). Previous 59-file installation backed up and verified at
`D:\my build wow addons\ForeverRP\Backups\ForeverRP-before-beta15-20261011-010018`.
WTF/SavedVariables were not touched. No commit, push or publication.

Files changed for the layer patch (prior status/marker/profile fixes preserved):

- `ForeverRP/Discovery/LayerEvidence.lua` (new)
- `ForeverRP/Discovery/Activity.lua`
- `ForeverRP/Core/Events.lua`
- `ForeverRP/Core/Commands.lua`
- `ForeverRP/Core/Constants.lua`
- `ForeverRP/ForeverRP.toc`
- `ForeverRP/UI/Activity.lua`
- `ForeverRP/UI/DiscoveryOptions.lua`
- `ForeverRP/README.md`
- `README.md`
- `tests/layer_evidence.lua` (new)
- `tests/discovery_diagnostics.lua`
- `tests/public_commands.lua`
- `tests/README.md`
- `docs/BETA15_LAYER_RETEST.md` (new)
