# Discovery release blocker: two-player evidence

Update: live evidence confirmed the split-name identity defect. Retest build
`discovery-identity-20261009-4` (`0.1.1-beta.4`) repairs the resolver and preserves
transport addresses separately. Use [IDENTITY_RESOLUTION_RETEST.md](IDENTITY_RESOLUTION_RETEST.md)
for current instructions. The earlier evidence and prototype notes below describe
the preceding build and are retained as investigation history.

Discord reports that last night's ZIP still fails discovery. That report remains
unresolved. Offline mocks and simulation do not establish live delivery or live
proximity detection. MSP feature development is paused for this investigation.

## Post-presence evidence (build discovery-observed-20261009-3)

Testers now report GUILD/PARTY HELLO receipt, WHISPER ACK receipt, and Presence
updated logs, with Nearby still empty. For those captured exchanges, transport
and acceptance succeeded. The remaining failure is not yet identified: the raw
party/target/mouseover identities and range/evaluation output are still needed.

Both `Linea Aspera-ClassicBetaPvE2` and
`Ravisholan Ruefield-ClassicBetaPvE2` are accepted unchanged by the current
character-key parser. It preserves the spaces in these character names and
the entire `ClassicBetaPvE2` realm identifier. The existing realm normalization
removes spaces/hyphens within a realm; it does not remove words or the trailing
`2`. Character-to-unit lookup currently requires exact normalized keys, including
case, so a genuinely different unit-reported realm/name cannot match. The code
has not been given a realm alias, name truncation or display-name reconstruction.
Sender screenshots alone do not establish what the unit APIs return.

This build adds raw identity evidence for target, mouseover and party1-party4
even when no detection was cached. `UFN` is UnitFullName's two return values,
`UN` is UnitName's two return values, `GUN` is GetUnitName(unit,true), `normalized`
is the current resolver's interpretation, and `cached` is the stored association.
Missing/disappeared units and NPCs are reported without querying their identity.
Secret outputs are marked inaccessible before string operations.

The recorded `last-evaluation` is the actual last Nearby reevaluation, not just
the diagnostic snapshot. `presence-triggered-evaluation` retains the last result
caused by Presence:Update; `UI-refresh` reports actual refresh attempts, completion
and row count. An excluded player that was never nearby is now visible in these
records (the old Remove debug line only ran when an existing entry was removed).
These evaluation records are runtime-only and capped separately at twenty peers.

A confirmed static defect was also repaired: nil, inaccessible or unexpected
interaction-check results were previously treated as failed checks and could
fall through to OVER_30. They now produce UNKNOWN unless an accessible positive
check establishes a usable bracket. Fully accessible negative checks still
produce OVER_30. A WITHIN_30 bracket at radius 20 is reported as
`range-bracket-insufficient-for-radius`, not proof that the player is outside
20 yards. The live incident's cause remains unproven until these results arrive.

For the next standing-together capture, both testers use the identical build,
target one another, open Nearby and wait two seconds. Verify `/frp version`
shows `discovery-observed-20261009-3`. Send `/frp hello` once from each client.
On Ravisholan's client run:

```text
/frp diag Linea Aspera-ClassicBetaPvE2
```

On Linea's client run:

```text
/frp diag Ravisholan Ruefield-ClassicBetaPvE2
```

Capture every line on both clients, particularly raw unit identities,
presence-triggered-evaluation, last-evaluation, range, exclusion, and UI refresh
completion. The argument includes the full name with spaces; do not quote it or
replace its realm. Wait five seconds between reports. Keep the screenshots
labeled by receiver and preserve Lua errors if a refresh never completes.

## Current source pipeline

1. `Communication:Initialize` registers FOREVERRP. `SendHello` calls `Send` and
   `SendPayload` for each eligible broadcast channel; send success means only
   accepted for enqueueing by the client.
2. `Core/Events.lua` routes CHAT_MSG_ADDON to `Communication:OnAddonMessage`, then
   `HandleIncoming`. It checks the prefix, normalizes the event sender, parses
   the packet/protocol, rejects self echoes, and applies `Privacy:CanInteract`.
3. An accepted HELLO or ACK calls `Presence:Update`. HELLO also attempts a
   WHISPER ACK to the original event sender. Profile packets need already
   confirmed presence and are outside this diagnostic's retained metadata.
4. `PlayerDetection:DetectUnit` resolves UnitFullName/UnitName for real player
   tokens and stores character-to-unit associations. Target, mouseover, focus,
   nameplate and group handlers supply tokens. Presence receipt itself does not
   create a unit association; both normalized identities must match.
5. `NearbyPlayers:Reevaluate` requires enabled discovery, confirmed presence,
   a valid associated unit, and `Range:IsWithin` for the configured radius.
   `Range:GetRangeState` uses CheckInteractDistance brackets. `ReevaluateAll`
   runs on the one-second discovery ticker as well as event-driven updates.
6. A passing peer enters `NearbyPlayers.players`. Changes call
   `NearbyUI:Refresh`, which obtains `NearbyPlayers:GetAll` and displays rows.
   The diagnostic reports both current eligibility and actual cached Nearby/UI
   state so delayed evaluation or UI refresh problems can be distinguished.

## Current transport coverage

ForeverRP broadcasts HELLO through eligible INSTANCE_CHAT, RAID or PARTY, plus
GUILD. Privacy filters those channels; Friends/Guild Only currently permits
GUILD broadcasts only. ACK replies are targeted WHISPER messages to the sender
of an accepted HELLO. Renewal repeats eligible HELLO broadcasts periodically.

There is no automatic SAY/YELL, zone channel, or vicinity broadcast. Two unrelated
nearby players without a shared party/raid/instance group or guild cannot
automatically discover each other just by standing together or targeting each
other. Friendship alone supplies no broadcast channel. Neither unit observation
nor MSP data creates ForeverRP presence. A previously received presence can
remain visible until expiry, so test absence of shared channels with a fresh
reload rather than assuming a cached presence proves transport coverage.

## What the command does

`/frp diag` reports the detected target, otherwise the latest remote packet peer.
`/frp diag Name-Realm` selects a specific normalized peer identity. It reports
version, diagnostic build, protocol, cached/client prefix registration, available
send API, eligible channels, selected first channel, local identity evidence,
last HELLO enqueue result (including raw boolean/enum/nil), per-channel results,
received HELLO/ACK and rejection reasons, real presence count, unit identity
matches, current range and raw interaction checks, Nearby membership and UI row.

It is a snapshot, not a probe: it sends nothing, does not inject presence,
refresh unit associations, change privacy, or repair discovery. Allow at least
one ticker second after changing targets or moving. Diagnostic output is limited
to once per five seconds. Repeated commands during that interval are silent.
Metadata is held only for the current session: latest HELLO/ACK/input, four
channel send results, and at most twenty remote peer records. It never retains
or prints packet payloads, profile contents, private notes, or simulation events.
Identity text is bounded and escapes WoW markup. Peer records are evicted in
oldest-observation order. The last packet may be a self echo; its decision is
explicitly `self`, and it does not replace the latest remote peer record.

`range=UNKNOWN` remains excluded. Fully accessible false interaction checks
produce `OVER_30`; inaccessible checks are shown as `<inaccessible>` in the raw
check line and must not be interpreted as proof of distance.
Range brackets are conservative client interaction checks, not exact yards.

## Exact two-player procedure

Use players A and B on two real clients. Both must install the **same diagnostic
ZIP** and reload. Last night's ZIP does not gain `/frp diag` from this source edit;
an unknown command means that client does not have this instrumentation. This
change does not itself build, distribute or deploy a ZIP. Record the supplied
ZIP's filename and SHA256 once it is provided; on Windows:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath 'C:\path\to\the-shared-diagnostic.zip'
```

1. Both use that identical ZIP in the active client's AddOns folder. Remove an
   older duplicate installation if present, then `/reload`. Verify the enabled
   addon belongs to this client installation. Capture any startup Lua error.
2. Join the same ordinary two-player party (not separate parties or raids),
   enter the same phase, and stand directly beside each other. Visually verify
   both characters are present. On **both** clients open `/frp settings`, enable
   discovery, and choose Visible privacy for the initial transport test. Record
   the configured radius. Do not use simulation or profile requests.
3. On **both** run `/frp debug off`. Target the other player. Open `/frp`, click
   Nearby, wait two seconds, and run `/frp diag`. Capture **every DIAG line**,
   labeled `A baseline` / `B baseline`. Both must report
   `build=discovery-observed-20261009-3` and the same version/protocol. Capture a
   screenshot of Nearby alongside the report, even if it is empty.
4. **A only:** run `/frp hello`. Capture its message, even if it says no channel.
   Wait two seconds. Both run `/frp diag` once five seconds have passed since
   their last diagnostic command. Capture all lines labeled `A after A HELLO`
   and `B after A HELLO`. Also capture `/frp presence` and `/frp nearby` on both.
5. **B only:** run `/frp hello`. Repeat the waits and capture on both clients,
   labeled `A after B HELLO` / `B after B HELLO`, again including `/frp presence`
   and `/frp nearby`. Keep each other targeted throughout.
6. If the incoming packet identity and target identity differ, copy the exact
   incoming `key=` from the report. On the affected receiver run
   `/frp diag ExactIncomingName-Realm` after five seconds. Capture all lines.
   Do not shorten the realm name. The `identityEvidence` line on the sender is
   needed to investigate supported aliases without hardcoding a realm mapping.
7. Only after the standing-together captures, move apart until range stops
   passing, then return together. Keep targets selected; wait two seconds per
   position. Capture `/frp diag` on both at each position, at least five seconds
   apart, with screenshots of Nearby. Record combat/instance/phasing changes.

Do not change privacy/radius or resend HELLO repeatedly during a failing capture.
First preserve evidence from both ends. Later restricted-privacy and group/guild
change tests should be separate runs with the relationship and channel recorded.

## Locate the first failing stage

| Evidence | Stage / next investigation |
| --- | --- |
| Missing command or different build/version | Installation/ZIP mismatch; first obtain matching builds. |
| Prefix cache false or client query false | Registration; compare query and registration API fields. |
| No send API or no eligible PARTY channel in the initial test | Transport/client API or group/privacy context. |
| HELLO failed/throttled/unavailable, or raw result nil | Client enqueue rejected; inspect exact return contract. |
| A accepted PARTY HELLO, B never records that HELLO | Transport/receiver event path; enqueue is not delivery. Preserve both outputs. |
| B input shows invalid sender, unsupported protocol or privacy | Identity/parser/privacy acceptance; inspect exact reason and sender. |
| A's identity marked self only on A | Expected self-echo filtering. If B marks A self, investigate identity evidence. |
| B accepted A HELLO but A has no ACK | Reverse ACK transport/acceptance; compare B receipt and A last-input. |
| Accepted peer but no confirmed presence | Presence rejection/expiry; compare decision and age. |
| Confirmed presence but no unit association | Compare incoming key with targetKey/mouseoverKey; inspect unit lifecycle. |
| Invalid unit or UNKNOWN range | Unit disappeared, restricted/unavailable values, phase or API availability. |
| Range outside radius despite standing together | Client interaction checks/brackets; preserve raw results and radius. |
| Eligible snapshot but Nearby false after ticker delay | Nearby evaluation/update path. |
| Nearby true but visible Nearby panel has no row | UI creation/refresh/render path; include screenshot and UI-row output. |

No discovery algorithm change should be selected from an offline success or an
enqueue result alone. Use the earliest mismatched stage in the paired live
captures to choose the next fix. Real-client behavior, delivery, restricted-value
semantics, phasing, and visual UI state remain unverified by the mocked suite.

## Observed-player prototype

This build initiates bounded directed HELLO for target/mouseover/nameplate
observations, including unrelated players. `/frp diag` now includes
`observed-probe`, attempts, pending state, unit and range. Metadata contains no
profiles or private notes. The existing five-second report limit applies.
An accepted probe only means client enqueue acceptance. A missing probe record
can mean a confirmed peer, privacy/discovery suppression, out-of-range or absent
unit, or queue/history capacity. Queue backpressure is intentionally lossy.

See [UNRELATED_PLAYER_DISCOVERY.md](UNRELATED_PLAYER_DISCOVERY.md) for limits,
solo checks, paired-client gates and passive-coverage restrictions. The original
screenshot incident still needs paired post-presence identity/range evidence;
this prototype does not claim to repair an unverified realm mismatch.
