# Beta 17: channel validation and ordered Directory snapshots

Version `0.1.1-beta.17`, build `ordered-directory-20261011-17`.
Paired Forever transport/layer validation: **NOT RUN**. These fixes establish
local acceptance/order behavior; they do not establish cross-layer delivery.

## Fixes

1. CHANNEL ingress is checked against receiver-local evidence for ForeverRPActivity.
   An accessible positive incoming localID conflicting with this client's current
   GetChannelName result, or an accessible nonempty channel name conflicting with
   ForeverRPActivity, is excluded. Matching accessible local ID or exact
   case-insensitive channel name is sufficient if no supplied evidence conflicts.
   Isolation also excludes missing/restricted/unverifiable evidence. Normal mode
   retains compatibility with missing metadata but labels it channel-unverifiable;
   known mismatches are excluded in either mode. Never compare numbers across clients.
2. Layer proof generations now have a per-peer high-water mark independent of the
   listing object. Older and duplicate generations cannot replace or renew evidence.
   L1|OFF and Directory OFF retain the guard even when evidence/listing is removed.
3. New peers exchange atomic A3 Directory snapshots and ordered withdrawals.
   Lower/equal sequence numbers cannot replace newer state. Once ordered traffic
   is accepted, unsequenced A1/A2/L1/OFF copies cannot mutate that peer's state.
   Existing diagnostic isolation, probes and native FRP/MSP behavior remain intact.

No SavedVariables keys/defaults were changed. No profile or note data is added to
Directory packets or diagnostic logs. No new transport route, relay or ordinary
chat automation was added. Older unrelated working-tree edits are preserved.

## Protocol and compatibility contract

Prefix remains FOREVERRPX1. New wire formats:

```
A3|opaque-session|positive-sequence|<complete A2 payload>~<L1 payload or L1|OFF>
A3|opaque-session|positive-sequence|OFF
```

The tilde separator is reserved; outbound subzones already percent-escape it.
The same 200-byte bound applies. Optional subzone is omitted if the snapshot is
too long; if necessary, layer proof is replaced by L1|OFF (unknown) to keep the
snapshot bounded. The Directory fields still fit. Native profile protocol 1 is
unchanged. L1 carries its existing opaque numeric session and observation generation.

One sequence identifies an immutable serialized snapshot. Changed body or a new
heartbeat creates a higher sequence; the sender session/sequence survive settings
resets and mode toggles, but a reload creates a new opaque random session token.
No session comparison relies on numeric or lexicographic order. A3 parsing must
validate the inner advertisement before consuming its sequence. Invalid layer
proofs leave the accepted listing's layer unknown. Repeated valid layer proofs
keep their original observation time, including across newer A3 heartbeats.

New send cycles use A3, then legacy A2, then optional legacy L1 on each route.
Old clients ignore A3 and can still list the A2 advertisement; new clients ignore
the legacy copies after accepting A3. These are direct copies of the sender's own
metadata, not relayed records. Withdrawal cancels pending compatibility jobs,
attempts ordered OFF on eligible routes first, then legacy OFF with remaining
budget. Both are best effort; successful enqueue still does not prove receipt.

There remain at most three route jobs, two attempts per stage, one-second accepted
send spacing, ten-second failure spacing, the existing token bucket (capacity 3,
refill 1/sec), 30-40 second minimum announcement interval and 90-110 second heartbeat.
Each route cycle now has up to three stages rather than two. Legacy withdrawal
may be throttled after ordered withdrawals consume the budget; old records then
rely on their existing expiry. A failure does not authorize unbounded retries.

## Sessions, retention and limits

Directory and layer streams each retain at most 250 peer guards, with at most
eight retired sessions per peer. Active guards are not evicted to admit new peers;
capacity exhaustion rejects the new state with an explicit diagnostic reason.
An established session accepts only increasing sequences/generations. Duplicate
and rejected packets never extend guard lifetime or evidence freshness.

An unfamiliar session is rejected until 150 seconds have passed since the current
stream's last accepted advancement (or layer withdrawal). After that quiet window,
the new session may be adopted and the previous token is retired. A retired token
cannot return while its guard survives. Session-history saturation rejects further
session changes rather than discarding retirement protection. A peer who reloads
may take roughly 150 seconds plus the next 90-110 second heartbeat to reappear.
Do not repeatedly reload while waiting for adoption.

Guards expire after 1,800 seconds without advancement; cleanup runs at most once
per second and also while networking is disabled. OFF, privacy resets and isolation
toggles do not erase guards. A receiver reload does erase runtime guards.

These are bounded replay guarantees, not authentication or unlimited history:

- After guard expiry or receiver reload, older packets cannot reliably be recognized.
- An unknown session cannot be chronologically identified from its token. After
  the quiet window, first unseen-session adoption is a conservative policy, not
  proof that its sender started more recently.
- Before the first accepted A3, legacy traffic remains best effort. A legacy A2
  has no sequence and a legacy OFF has no session/generation. Delayed legacy
  advertisements can still resurrect legacy-only listings/coordinates. Legacy
  layer OFF can block already-seen proofs, but cannot identify an unseen delayed
  generation as older than the withdrawal.
- After accepted A3, legacy copies cannot bypass the retained ordered fence,
  including through another social route or after clearing the Directory view.
- Protection is per existing normalized peer identity. No guessed realm aliases,
  identity reconstruction or sender authentication is introduced.
- Ordered withdrawals must actually arrive to protect against preceding snapshots.
  Existing 150-second Directory expiry and 125-second marker freshness remain.

## Exact live retest commands

Install this ZIP on both clients, then run:

```
/reload
/frp version
/run print(GetBuildInfo())
/run print(GetNormalizedRealmName(), GetRealmName())
/frp network channel on
/frp network
```

Confirm Beta 17/build identifier on both. Manually opt in to discovery, Visible,
Experimental Network and Directory Participation; use IC/LF RP and All zones in
Directory filters. Location can stay hidden for transport tests. Social routes
continue for native discovery, but cannot populate the isolated Directory.

1. Each tester manually types `/N FRP17-TesterA-Control-001`, substituting their
   own local ForeverRPActivity channel number and a unique tester/case label.
   Capture ordinary chat receipt separately from addon traffic.
2. A runs `/frp network probe TesterA-Control`. Both run `/frp network trace`.
   B repeats with `/frp network probe TesterB-Control`. Match remote RX T1 ID and
   fingerprint to sender TX; require accepted/probe-only-no-presence and
   channelEvidence=verified-local. An ignored self-echo does not count.
3. Wait for normal advertisements and run `/frp network trace` and `/frp directory`.
   Capture remote `type=A3 outcome=accepted reason=ordered-advertisement-stored`,
   matching ID/session:sequence and fingerprint, then the actual Directory row.
   `legacy-after-ordered`, `ordered-duplicate` or `older-generation` demonstrate
   rejection/duplication, not a fresh listing. Same receiver-local channel numbers
   across clients, enqueue results and aggregate counters are not receipt evidence.
4. Once listed, A turns Directory Participation OFF. B captures ordered-withdrawal
   and the disappearing row. Capture any delayed traffic: older sequences and
   unsequenced copies must not restore that row. Re-enable participation; a newer
   snapshot may list A again. Repeat in the other direction.
5. With precise sharing deliberately enabled, switch to Don't share my location.
   After the ordered update/withdrawal arrives, the remote pin must disappear;
   old snapshots must not restore coordinates. Location sharing is never required
   merely to test transport.
6. To test session adoption, reload only A, re-enable CHANNEL isolation on A and
   capture its new session token. B may report session-change-awaiting-quiet.
   Allow up to five minutes without more reloads for a new advertisement after
   the quiet window. Capture adoption and any retired-session rejections.

Repeat control together, different zones, and independently confirmed separate
layers. Three-minute observation windows apply to ordinary route cases; record
late arrivals. Use five minutes for session-reload tests. If metadata is missing
or inconsistent, preserve both traces; do not disable isolation or guess channels
to turn the test into a pass. Live channel metadata formats remain client-tested
behavior; a known mismatch may identify a format issue needing investigation.

Trace reports remain limited to once per five seconds, 12 recent detail records,
six route summaries and one header. History: 64 records, 100 retained observations
per second; suppression/eviction counts remain visible. Probes: one per ten seconds,
no automatic reply, no listing/presence creation. Layer results still require fresh,
comparable NPC evidence; transport success is not proof of layer accuracy.

Restore normal routing with `/frp network channel off` or `/reload`.
Mode switching clears runtime Directory/layer/marker data, but preserves ordering
guards. Offline tests inject duplicates/replays; testers should not fabricate or
replay other players' advertisements through live commands.

## Validation and changed files

`tests/directory_ordering.lua` exercises all three original failures, cross-route
duplicates, legacy downgrade blocking, invalid envelopes, session changes, retired
session caps, TTL/capacity cleanup, snapshot size and actual sender stages. Optional
argument loads a real older Activity.lua to test A3-ignore/A2-list/OFF behavior:

```
lua tests/directory_ordering.lua <path-to-Beta16-addon>
```

Runtime changes: Discovery/Activity.lua, Discovery/LayerEvidence.lua,
Discovery/Communication.lua (preserve ordered correlation IDs in tracing),
Core/Constants.lua and ForeverRP.toc. Both README files identify Beta 17.
Tests changed: directory_ordering.lua (new), directory_diagnostics.lua,
directory_transport.lua, directory.lua, layer_evidence.lua, enhanced_discovery.lua,
discovery_diagnostics.lua, public_commands.lua and tests/README.md.
This document is new. Existing unrelated edits were preserved.

Validation: all 21 suites passed under Lua 5.1, totaling 2,889 checks; all 69
runtime/test/helper Lua files passed `luac -p`. `git diff --check` passed.
The new ordering suite passes 149 checks, or 154 when exercising the real Beta 16
parser's compatibility path. That replay was run against the installed Beta 16
files before replacing them. Passing mocks does not prove live packet delivery.

Package: `dist/ForeverRP-v0.1.1-beta.17.zip`.
Installed: `D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverRP`.
All 60 files hash-match source/ZIP/install (root README/LICENSE packaging overrides).
The prior 60-file installation was backed up and hash-verified at
`D:\my build wow addons\ForeverRP\Backups\ForeverRP-before-beta17-20261011-044014`.
Installed TOC confirms Beta 17 and ordered-directory-20261011-17.
No WTF/SavedVariables edits, commit, push or publication.
