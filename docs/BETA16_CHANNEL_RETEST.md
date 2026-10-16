# Beta 16: isolated Directory transport investigation

Version `0.1.1-beta.16`; build `channel-diagnostics-20261011-16`.
Paired live transport tests: **NOT RUN**. Cross-layer and internal-realm delivery
remain unverified. Backend-realm isolation is a hypothesis, not an established
explanation of the testers' incident. No production transport defect is claimed fixed.

## Commands and isolation

```
/frp version
/frp network channel on
/frp network
/frp network probe TesterA-Control
/frp network trace
/frp directory
/frp network channel off
```

`network channel on` isolates only ForeverRP Directory advertisements/receives.
Social Directory arrivals remain diagnosed with `outcome=ignored
reason=excluded-by-isolation`, but cannot populate the test view, modify its
coordinates/layer evidence or withdraw its CHANNEL records. Outbound social
Directory advertisements/withdrawals are excluded even at the send entry point.
Normal native HELLO/ACK, Nearby, profile transfer and MSP remain operational.
Neither group membership nor guild membership needs to change.

Changing mode clears runtime Directory records (including their coordinates and
remote layer evidence), local inferred-layer samples, pending Directory sends,
and legacy last-send/receipt summaries; pooled markers refresh immediately.
Native presence records are retained. Directory-only records may be removed by
existing cleanup. Existing profile caches, Connections and private notes remain.
Trace history stays available with the mode recorded on each entry.

The mode is NOT saved. `/reload` always restores normal routing; `network channel
off` restores it immediately, with a fresh Directory cache. Saved preferences and
consent defaults are unchanged. No opt-in is enabled automatically. Networking
still requires discovery enabled, non-Hidden visibility and Experimental Network
ON; CHANNEL additionally requires Visible. Directory Participation controls
listing; location sharing is a separate permission and can remain withheld.

## Diagnostic contract

`/frp network` shows active isolation, routes and existing transport summaries.
`/frp network trace` shows per-route ingress/outbound counts and the latest 12
records, at most once every five seconds. Debug logging need not be enabled.
Each receive record is created before application gates and then assigned a
terminal accepted, duplicate, rejected or ignored outcome. An unexpected runtime
error can leave `outcome=ingress reason=pending`; report that and the Lua error.
A1/A2 advertisements, L1 companions, OFF withdrawals and T1 probes are covered.

Records include local GetTime timestamp, mode, prefix, route, exact accessible
valid raw sender, normalized/resolved key when available, local channel ID,
channel name, target, zoneChannelID and opaque instanceID metadata. Do not treat
instanceID as a layer identifier. Invalid long strings are capped at 120 characters;
inaccessible values are labeled without inspecting or unwrapping them.

Fingerprint is bounded packet length plus a rolling checksum over at most 200
bytes. It is a correlation aid, not authentication, and collisions are possible.
No full payload, profile contents, notes, coordinates or layer identifier are
retained by this trace. Probe IDs are public test labels, not secret content.
TX reports actual API selection and result, or not-called for preflight rejection.
TX rawSender is the local lookup identity, not proof of the server's sender format.
RX rawSender is the event-provided value; keys and raw transport addresses remain
separate. No aliases are inferred.

History is limited to 64 records and 100 retained observations per second shared
between RX/TX. `total`, `suppressed` and `evicted` expose lost detail. Per-route
counts continue even when records are suppressed. `receiveAccepted` and
`enqueueAccepted` are separate; rejected/ignored/duplicate totals are historical.
Reports show only the latest 12 retained records. Capture promptly; silence in
that excerpt does not mean zero ingress. There are at most six route summaries,
12 detail lines and one header per trace report. No automatic trace chat spam.

Probe command sends one T1 packet through the existing prefix/channel, with a
tag/time/sequence correlation ID. Tags: 1-24 ASCII letters/digits/underscore/hyphen;
use a different tag per tester and case. At most one invocation per ten seconds,
subject to normal token budget and privacy. No automatic reply or retry. Accepted
probes never create presence, listings, profile requests, coordinates or alerts.
Older clients ignore T1; use this ZIP on both clients.

## LayerSwap reference inspection

Inspected the supplied `LayerSwap.zip`, `LayerSwap/LayerSwap.lua`; no code copied
or bundled. `LAYER_CHANNEL="layer"` at line 26, addon `NOTE_PREFIX="LayerSwap"`
at line 42. Joining occurs at lines 704, 1058 and 1614; prefix registration at 2084.
These are different concepts: the name selects a chat route; the prefix identifies
addon traffic carried through a route.

- `sendNote` (879-883) uses `C_ChatInfo.SendAddonMessage`, CHANNEL/local handle
  or GUILD; `sendZone` (887-889) adds a zone note. `sendClaim` (393-399) and
  `replyHeard` (447-459) also use addon CHANNEL/GUILD; line 603 sends a WHISPER reply.
- `sendAsk` (895-909) uses namespaced `SendChatMessage` or the global fallback.
  `requestSwap` (1031-1087) joins if needed and asks the user to click again;
  it sends addon notes and an ordinary chat request, then an addon ping.
  `requestGuild` (1184-1218) similarly sends notes plus ordinary GUILD chat.
  Buttons call these functions at 1494/1512; the guild path exposes `/ls guild`.
  Its ordinary request is driven by user interaction, unlike ForeverRP's timer.
- `CHAT_MSG_CHANNEL` (2093-2101) recognizes channel base name `layer` or General
  zoneChannelID 1. WHISPER/GUILD ordinary chat also feed `onChat` (2102-2105).
  `CHAT_MSG_ADDON` (2106-2108) checks the prefix and calls `onNote(text,sender)`;
  that dispatch does not preserve the event's route/channel metadata.
- Its self-ping timing comments and ordinary chat success are not proof of remote
  addon CHANNEL delivery. Its pcall calls do not establish permission or delivery.
  No restriction from another WoW branch establishes this installed client's behavior.

ForeverRP has no ordinary-chat fallback, layer-hop behavior or player-record relay.
No concrete reason was found to create another diagnostic channel.

## Paired live matrix

Both use this same ZIP and capture:

```
/reload
/frp version
/run print(GetBuildInfo())
/run print(GetNormalizedRealmName(), GetRealmName())
/frp network channel on
/frp network
```

Opt in manually as above; set Directory Participation ON and IC/LF RP on both.
Directory filters should include that status and All zones. Location may stay
hidden throughout this route test. Native social discovery can continue but
cannot populate the isolated Directory. Inspect the mode/CHANNEL route on both.

For each row test BOTH directions, one tester at a time:

| Case | Independent evidence to record |
| --- | --- |
| Control: same zone, visible together | Both client builds/realm outputs; mutual physical visibility |
| Different zones | Both zone names and current locations recorded manually |
| Same zone, different layers | Independent confirmation of separation and any transition; inference alone is insufficient |

1. Read each client's own `Shared channel: ForeverRPActivity localID=N` output.
   Manually type `/N FRP16-TesterA-Control-001` using YOUR number. Other tester
   captures the ordinary chat line with sender and exact unique text. Repeat
   with TesterB and distinct labels. Different numbers are normal. No addon code
   sends ordinary chat; no automatic ordinary-chat fallback is being tested.
2. A types `/frp network probe TesterA-Control`, immediately captures
   `/frp network trace`; B captures trace after receipt/wait. Record exact generated
   ID and fingerprint. B repeats with `TesterB-Control`. Change tags per case.
3. Sender proof is `Directory TX ... route=CHANNEL ... type=T1 ...
   outcome=enqueue-accepted ... result=0 ... id=<generated ID> target=[N]`.
   Receiver proof is `Directory RX ... route=CHANNEL ... type=T1 ...
   rawSender=[other tester] ... outcome=accepted reason=probe-only-no-presence`
   with matching ID/fingerprint. A self-echo with `reason=self-echo` does NOT count.
4. Test real advertisements separately. Allow normal scheduled A2 sends and
   capture TX fingerprint and remote RX with that fingerprint:
   `type=A2 outcome=accepted reason=advertisement-stored`. Then capture the remote
   Directory listing. A duplicate RX proves delivery, but is not fresh storage;
   examine the earlier accepted CHANNEL record. Rejected/ignored RX proves
   arrival only; the reason identifies an application/isolation/privacy decision.
   L1 acceptance is not required for listing and cannot create one alone.

Observe for three minutes per case, capturing trace promptly after each probe and
every 15-30 seconds while waiting for advertisements (reports limited to 5 seconds).
Accepted sends have no automatic delivery confirmation. Label any later arrivals
with elapsed real time; a three-minute timeout is failure within that window, not
proof of permanent impossibility. If a probe was locally throttled, wait ten
seconds and manually send one new uniquely tagged probe; never infer loss from
a rejected enqueue. Normal Directory heartbeat is 90-110 seconds; changed routes
retain a 30-second announcement floor. Existing retry limits remain unchanged.

Capture manual-chat receipt, probe RX outcome, A2 RX outcome and listing separately.
Manual chat success with no addon ingress suggests a route/prefix/API difference,
not a proven layer error. Addon ingress with rejected A2 identifies application
handling. Both forms failing only across a particular realm/layer boundary is
evidence for that tested boundary, not proof of its cause. Matching local handles,
zones, cumulative counters or enqueue results cannot substitute for remote RX.

Restoration: `/frp network channel off`, or `/reload`; `/frp network` must say normal.
No guild leave, group change, SavedVariables edit, external service, relay or hop.

## Offline validation and deployment

The new suite is `lua tests/directory_diagnostics.lua`. It covers actual receive
and send paths, social-first duplicates, malformed/restricted metadata, isolation
in both directions, cache clearing, native HELLO/ACK/profile continuity, reload
initialization, probe correlation/no presence/no replies, L1/OFF and trace bounds.
Mocks cannot establish client security, visual layout, server delivery or layer accuracy.

Validation: all 20 suites passed under Lua 5.1, totaling 2,723 checks. All 68
runtime/test/helper Lua files passed `luac -p`; `git diff --check` passed.
The diagnostic suite accounts for 9 cases / 108 checks. Existing profile, privacy,
markers, status, layer, native transport, MSP and restricted-value suites pass.

Package: `dist/ForeverRP-v0.1.1-beta.16.zip`.
Installed: `D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverRP`.
All 60 files hash-match source/ZIP/install, accounting for root README/LICENSE
packaging overrides. The previous 60 files were backed up and verified at
`D:\my build wow addons\ForeverRP\Backups\ForeverRP-before-beta16-20261011-034047`.
WTF/SavedVariables were not touched. No commit, push or publication.

Files changed in this task (earlier unrelated edits preserved):

- `ForeverRP/Discovery/Activity.lua`
- `ForeverRP/Discovery/Communication.lua`
- `ForeverRP/Discovery/LayerEvidence.lua` (diagnostic return reasons only)
- `ForeverRP/Core/Commands.lua`
- `ForeverRP/Core/Constants.lua`
- `ForeverRP/ForeverRP.toc`
- `ForeverRP/README.md`
- `README.md`
- `tests/directory_diagnostics.lua` (new)
- `tests/discovery_diagnostics.lua` (build expectation)
- `tests/public_commands.lua` (build expectation)
- `tests/README.md`
- `docs/BETA16_CHANNEL_RETEST.md` (new)

The diagnostic defect corrected is invisible duplicate/rejected/L1/OFF traffic in
per-route receive reporting. No underlying delivery defect has been identified
or claimed repaired. No channel/realm alias, ordinary-chat automation or relay
was added. Actual paired transport and visual/taint behavior still require the
matrix above on the installed Forever client.
