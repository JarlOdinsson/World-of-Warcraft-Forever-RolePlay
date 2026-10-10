# Unrelated-player discovery: requirement and transport investigation

Current retest: `0.1.1-beta.4`, build `discovery-identity-20261009-4`.
The live `no-unit-association` defect is now explained by Forever's split-name
returns. See [IDENTITY_RESOLUTION_RETEST.md](IDENTITY_RESOLUTION_RETEST.md) for
the repair, current package and exact paired validation steps. The bounded
observed-player transport below remains unverified for unrelated live clients.

Status: bounded observed-player prototype implemented in
`discovery-observed-20261009-3`; not live validated. MSP feature work remains
paused. The post-presence Nearby bug remains a separate release blocker; collect
paired captures using the current build in
[DISCOVERY_DIAGNOSTICS.md](DISCOVERY_DIAGNOSTICS.md).

## Required behavior

Two consenting ForeverRP users passing near one another in a city must be able
to discover each other and trigger the configured proximity notification without
sharing a party or guild, and without targeting or mousing over each other.
Party/guild HELLO delivery, simulator success, or offline tests do not meet that
acceptance criterion. A target/mouseover test is only a transport/identity probe.
If supported APIs do not expose the passing player or a usable range check,
report that coverage limit rather than claiming automatic detection is complete.

## Evidence and client scope

Current tester screenshots establish PARTY/GUILD HELLO receipt, WHISPER ACK
receipt and accepted presence in those contexts. They do not establish WHISPER
delivery between unrelated clients, passive nameplate discovery, or notification.
Group/guild broadcasts are preserved. ObservedDiscovery now initiates directed
HELLO over WHISPER for independently observed target/mouseover/nameplate players.
Directed HELLO responses share the new traffic budget. This is a candidate
transport, not proven unrelated delivery. Notifications run only when a
peer actually enters Nearby; they also respect configured notification settings
and the existing per-peer cooldown (default 600 seconds).

The following are Blizzard-generated sources extracted in the **forever** branch
of wow-ui-source, consulted 2026-10-09. This is stronger evidence than a retail
analogy, but the moving branch is not the testers' exact installed client build.
Record GetBuildInfo from both clients before relying on these signatures.

- [Forever ChatInfo documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua):
  addon sending returns an enum, rejects secret arguments, and distinguishes
  ordinary and logged addon receive events. Its chatType is a string, not a
  documented list of supported server routes. It does not establish CHANNEL
  delivery, channel target representation, faction reach, or automatic-send
  permission in every context.
- [Forever Unit documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua):
  UnitFullName can return restricted identity values. Type checking alone is
  insufficient; validate accessibility before normalization, lookup or sending.
- [Forever NamePlate documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/NamePlateDocumentation.lua):
  nameplate lookup/enumeration APIs exist. This does not establish friendly-player
  token availability or passive coverage under every setting or client context.

No secret unwrapping, identity reconstruction, synthetic names, hardcoded realm
aliases, /who polling, player-list scraping, or visible chat fallback is proposed.
Logged messages are not a bypass for a rejected route. Any alternate transport
would require its own documented contract and explicit receiver implementation.

## Candidate transport comparison

| Candidate | Use | Gaps and validation required |
| --- | --- | --- |
| Target/mouseover-directed WHISPER HELLO/ACK | First controlled unrelated-client transport test; accessible client identity only. | Requires user interaction, so cannot alone meet passive pass-by requirement. Test unrelated delivery, exact realm/name addressing, both directions and client restrictions. |
| Nameplate-observed directed HELLO/ACK | Preferred first candidate for passive discovery, contingent on live support. | Friendly/nameplate settings, token creation/removal, visibility, combat, crowded cities and phases can limit observation. Token availability is not distance or consent. No token/accessible identity means no probe. |
| Dedicated opt-in shared addon channel | Potential presence rendezvous independent of group/guild. | Unverified on Forever. Joining a chat channel does not prove addon payload support. Channel membership, limits, routing, zone/realm/faction boundaries, moderation and reconnect behavior require tests. Broad membership still supplies no physical proximity or unit token. |
| Group/guild broadcasts | Existing route, useful for regression testing. | Cannot satisfy unrelated-player discovery. |

A shared channel must not result in a HELLO response to every member. That would
amplify traffic with population size. If validated, use sparse jittered presence
announcements, no broadcast ACK fanout, and bounded directed verification only
for an independently observed candidate. A city/zone channel is not proof of
being in range or in the same phase. Use no public General/Trade payload spam.

The current SendPayload treats a target as a character identity and checks it
through Privacy. It cannot simply be given a numeric channel identifier: shared
channels would require a separate channel-aware transport/privacy adapter after
the actual Forever contract is established. No such runtime change is included
in this investigation.

## Implemented bounded directed handshake

1. A target/mouseover/nameplate event supplies a genuine player unit. Guard the
   token, existence/player outputs, and identity. Keep full accessible names,
   including spaces and client realm identifiers. Revalidate the association
   immediately before sending because nameplate tokens are reused.
2. Require enabled discovery and local privacy permission. Prefer candidates
   with passing range evidence; unknown range never counts as nearby. Queue at
   most one handshake per identity, regardless of how many units observe it.
3. Send the existing HELLO as a directed addon WHISPER. The other consenting
   client applies its own policy before an ACK. Keep prefix/protocol/self checks;
   enqueue success is not delivery, and timeout is not proof of rejection.
4. Associate the received sender only using independently supported identity
   evidence. A mismatched realm/name remains unmatched until diagnosed; never
   broadly collapse realms. An inbound HELLO can establish presence, but does not
   manufacture a unit or prove physical proximity.
5. Confirmed presence plus a currently valid unit plus passing range enters
   Nearby and calls the existing notification path. Require both clients to
   observe the other independently for symmetric alerts. If one has no usable
   unit, one-sided delivery cannot promise two-sided proximity detection.

Implemented application budgets, **not claimed Blizzard limits**:

- Directed HELLO and directed-HELLO ACK responses share a 2 packets/second
  token bucket, burst 4. HELLO attempts also have a rolling 20/minute ceiling.
  Existing group/guild broadcasts and their ACK responses remain unchanged.
- At most 32 pending probes and 128 probe-history records. Reject new candidates
  when full; do not evict cooldown records to permit extra sends.
- Two attempts maximum, separated by deterministic 10-15 second staggering.
  Unsent queued candidates expire after 30 seconds. No recursive timers.
- History expires after five minutes, except exhausted, still-observed,
  unconfirmed peers retain suppression while eligible. Non-addon users do not
  cause indefinite retries while continuously observed. A later encounter may
  probe again after suppression expires without an eligible observation.
- Confirmed, observed peers can renew after 600 seconds using the same budgets.
  Received presence refreshes suppress further probing until renewal is due.
- Directed HELLO ACK responses have a 10-second per-peer cooldown and 128 history
  slots with five-minute expiry. ACKs dropped by limits are not queued.
- A throttled HELLO or directed ACK pauses the shared budget for ten seconds.
  Failed sends consume attempts and budgets. Two failures end that probe cycle.
- Every attempt rechecks discovery/privacy, current unit identity and range.
  UNKNOWN may be probed but never counts as nearby. OVER_30 is not probed.
  Nearby retains the configured-radius check and existing notification settings.
- The one-second Nearby ticker processes probes and observes retained tokens.
  No target/mouseover/nameplate token means no candidate. Existing nameplates at
  login are not enumerated; an event or target/mouseover observation must first
  associate the player. Without the ticker API, only immediate event probes run.

These conservative starting limits deliberately create gaps in a dense city:
a fast-moving player may leave before their queued probe runs. Do not remove the
bounds to hide that limitation. Measure actual populations, notification latency
and client delivery before tuning them.

## Consent and privacy enforcement

Discovery-enabled plus Visible permits stranger discovery; observing a nameplate
does not prove the remote player participates. The remote addon must independently
allow the handshake. Hidden means no initiation, announcement, ACK or notification.
Friends/Guild Only permits directed contact only with currently verified allowed
peers, never unknown strangers, and no identity announcement on an unrelated
shared channel. Shared-channel membership exposes participation to its members,
so restricted/hidden clients must not autojoin for discovery. Relationship changes
invalidate trust and must cancel queued handshakes as well as profile responses.
Do not transfer profiles or Connections notes as part of discovery.

Directed HELLO/ACK receive handling now checks discovery-enabled before storing
presence or responding. Hidden/restricted privacy checks remain in the existing
receiver. Existing group/guild lifecycle behavior is preserved. Runtime probes
are canceled on reevaluation when identity, privacy or discovery becomes
ineligible; no canceled probe is transmitted. Simulation never queues probes.

## Solo-client checks (evidence, not delivery validation)

1. Reload the test build. Verify `/frp version` includes
   `discovery-observed-20261009-3`.
2. With Visible privacy and discovery enabled, mouse over a real player, then
   target them. Run `/frp diag` and capture all output. `observed-probe` shows
   result, attempts, unit and range. A non-addon player's accepted send should
   leave presence unconfirmed and Nearby empty.
3. Repeat over an NPC: no NPC peer probe should be created. Repeatedly hover
   one player: no more than two HELLO attempts. Allow 15 seconds for the retry;
   budget pressure can delay/suppress it. Confirmed peers need no new probe.
   Hidden/discovery-disabled modes must not initiate probes.
4. Enable friendly player nameplates and inspect unit evidence. No generated
   nameplate unit means passive coverage is unavailable in that context.
   UNKNOWN range must not become Nearby.

## Files changed for this implementation

These are changes from the pre-task working tree; earlier uncommitted diagnostics
and Settings edits are preserved.

| File | Change |
| --- | --- |
| `ForeverRP/Discovery/ObservedDiscovery.lua` | New bounded observation/probe/ACK scheduler and suppression records. |
| `ForeverRP/Discovery/PlayerDetection.lua` | Submit independently observed identities. |
| `ForeverRP/Discovery/NearbyPlayers.lua` | Process probes through the existing ticker. |
| `ForeverRP/Discovery/Communication.lua` | Consent gate and bounded responses for directed HELLO. |
| `ForeverRP/Core/DiscoveryDiagnostics.lua` | Report actual per-peer probe state. |
| `ForeverRP/Core/Constants.lua` | Unique build identifier. |
| `ForeverRP/ForeverRP.toc` | Load module and identify build. |
| `tests/observed_discovery.lua` | New real-module regression suite. |
| `tests/discovery_diagnostics.lua` | Expect the new build identifier. |
| `tests/README.md` | Suite instructions and mock limitations. |
| `docs/UNRELATED_PLAYER_DISCOVERY.md` | Implemented limits, coverage and validation report. |
| `docs/DISCOVERY_DIAGNOSTICS.md` | Current build and probe diagnostics. |

Validation: all seven suites passed (`communication`, `connections`,
`restricted_values`, `audit_fixes`, `msp_compatibility`, `discovery_diagnostics`,
`observed_discovery`): 680 checks, including 18 new cases/91 checks. `luac -p`
passed for all 40 runtime Lua files. `git diff --check` and untracked-file
whitespace checks passed. The existing Settings layout was verified intact.
No source changes to profiles, Connections, MingleBar or MSP. No deployment,
commit, push, packaging or publishing performed for this implementation.

## Live validation gates

Keep the existing party test separate: collect the post-presence diagnostic on
both clients, including raw names, unit matching, range and UI refresh completion.
That can locate the current bug without adding a new transport variable.

For unrelated transport, use two consenting testers with the same diagnostic
build. Record `/run print(GetBuildInfo())`, `/frp version`, local identity evidence
and settings. Use characters without a shared guild, leave groups, and reload
both clients to clear runtime presence. Stand together in the same phase, Visible
privacy and discovery enabled. Mouse over or target each other, wait two seconds,
and capture the automatic probe. Do not manually send HELLO during this capture.

Capture every `/frp diag OtherFullName-Realm` line from both ends after at least
five seconds since the previous report. Require B's received HELLO, A's received
ACK, matching identities, unit/range evidence, actual Nearby entry and enabled
notification. Reverse direction in a fresh run. If addressing fails, preserve
raw values and results; do not guess a name spelling. Target/mouseover success does not establish passive nameplate coverage.

Then test this same build with nameplate-event sends. With no target/mouseover/group/guild, walk past each
other in both directions. Verify accessible token creation, directed packets,
range-confirmed Nearby entry and notification. Repeat with friendly nameplates
on/off, crowded areas, combat/out of combat, disappearing/reused tokens and
different phases. A third non-addon client must not generate probes/responses
forever or visible chat spam. Repeat Hidden, restricted permitted/unpermitted
peers, discovery disabled, and switching policy while a probe is queued.

Shared-channel validation is a distinct experiment using a manually joined,
dedicated test channel and an isolated one-shot addon canary. First verify the
actual channel API argument contract and capture local channel identifiers on
both clients (they need not be numerically equal). Use addon events, not visible
SendChatMessage. Prove receipt in both directions, capture raw send results and
channel event metadata, then test after zone/relog/phase changes and with three
clients to measure fanout. Do not enable announcements globally merely because
joining succeeded. If the server rejects this route, record it as unsupported
for that client build; do not tunnel around the rejection.

Unknowns to resolve include server delivery rules for unrelated whispers,
automatic sends, opposite faction/connected realm/shard reach, restrictions in
combat or identity lockdown, custom-channel delivery, and friendly nameplate/range
coverage. Any of these can limit the product requirement. A release can claim
passive unrelated-player discovery only for the scenarios demonstrated by paired
live event, range, Nearby and notification evidence.
