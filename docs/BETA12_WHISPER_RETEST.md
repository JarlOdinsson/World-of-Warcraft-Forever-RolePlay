# Beta 12: automatic whisper recipient and stale-probe repair

Version: `0.1.1-beta.12`
Build: `observed-whisper-20261010-12`
Archive: `dist/ForeverRP-v0.1.1-beta.12.zip`

## Confirmed code findings and remaining uncertainty

Debug OFF disables logging, not discovery or MSP traffic. An observation can
send both `FOREVERRP` HELLO and `MSP2` requests. The yellow message provides no
prefix or triggering event; the Asty Pally report alone cannot attribute it to
one of these paths or prove an invalid recipient. No Lua error is necessary for
the server to report an unavailable recipient.

Confirmed defects: automatic MSP requests passed canonical lookup keys into
LibMSP/Chomp, which qualified and ambiguated them again before sending. Its
deferred queues did not revalidate the observed unit. The real-library tests
reproduce that separation failure and stale queued sends. A HELLO retry also
revalidated the lookup key but reused the old transport address when the same
identity acquired a different client-reported transport form. A missing raw
recipient could fall back to a canonical key.

Beta 12 repairs these defects. It does not assert that either caused this exact
live yellow message, or that every still-visible client identity is whisperable.
The server may reject a recipient that leaves, phases, disconnects or otherwise
becomes unavailable after the API call. No alternate addresses are attempted,
and no system messages or Lua errors are filtered.

The [Forever generated ChatInfo API](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua)
declares a string target and a send-result enum; it does not specify a special
multiword-name wire grammar or guarantee delivery. Enqueue success is not proof
of delivery, addon installation, consent, confirmed presence or proximity.

## Audited outbound paths

| Trigger / path | Prefix and recipient at API boundary | Deferred behavior |
| --- | --- | --- |
| `UPDATE_MOUSEOVER_UNIT`, `PLAYER_TARGET_CHANGED`, `NAME_PLATE_UNIT_ADDED` -> PlayerDetection -> ObservedDiscovery | `FOREVERRP`, current `ResolveUnitIdentity` transport evidence; split-surname `GetUnitName` is retained whole | Maximum two HELLO attempts per observation suppression window, existing shared discovery budget; retry revalidates unit, privacy, range eligibility and raw address |
| Target/mouseover -> MSPCompatibility -> LibMSP | `MSP2`, same observed raw client recipient, separate canonical MSP cache key | New opt-in Chomp LOW-priority adapter: 32 pending short requests maximum, five-second expiry, final-send validation; no automatic resend on failure |
| Nameplate observation | `FOREVERRP` only | No automatic MSP request from nameplates |
| Incoming HELLO -> ACK | `FOREVERRP`, exact `CHAT_MSG_ADDON` sender | Immediate; directed ACK shares discovery budget and per-peer reply cooldown; social HELLO reply retains existing handling |
| Presence recipient storage | No send; stores incoming sender separately from normalized lookup key | Later profile actions use stored sender; legacy fallback remains for records without sender evidence |
| User profile request / authorization / response / revocation | `FOREVERRP`, stored incoming sender or request sender; response queue retains its raw recipient | Existing privacy checks, expiry and bounded failed-chunk retries remain; observation alone does not request an FRP profile |
| Incoming MSP request -> LibMSP reply; other addons' MSP calls | `MSP2`, normal shared Chomp name/realm, Ambiguate, CTL or Battle.net route | Existing shared-library behavior; not cancelled merely because no target/mouseover unit exists |
| Focus / group association / simulation | No automatic observed stranger probe from these sources | Simulation remains isolated from real sends |

No RP profile display field is used by the audited automatic send paths. Names
and genuine realm suffixes stay intact. No aliases or speculative variants are
introduced. The Chomp revision is 26 and LibMSP revision 33 only on Interface
16001; ordinary shared calls keep their contract and third-party notices. A
newer/equal external library without the opt-in adapter is left intact; automatic
MSP probing is skipped rather than queued unsafely. FRP discovery still works.

## Diagnostics

Existing `/frp debug on` tracing remains capped at 30 lines/minute, deduplicated
for ten seconds, with 20 retained metadata records and no profile/note payloads.
Lines now include the actual prefix. Local MSP adapter result lines include
`source=observed-unit:target:...` or `mouseover:...`, the exact raw recipient,
result and enqueue reason. `stale-observation` means no API send occurred.
The generic secure hook uses `source=shared-MSP2:API-bound`; it captures actual
arguments, including other addons' MSP traffic, but cannot observe API results.
It may precede a local adapter's result line for the same send.

Event-driven observations include `trigger=` in the source, distinguishing the
actual handler from `initial-unit-scan`; HELLO traces also identify retry ticks.
For event correlation: `mouseover` originates in `UPDATE_MOUSEOVER_UNIT`,
`target` in `PLAYER_TARGET_CHANGED`, `nameplate` in `NAME_PLATE_UNIT_ADDED`;
subsequent HELLO attempts originate in the existing discovery ticker. Initial
unit scans can also populate target associations. `received-sender:HELLO`
originates in `CHAT_MSG_ADDON`. The trace identifies source evidence, not an
assertion that mouseover caused the reported server error.

## Short live retest

1. Install this ZIP, `/reload`, then `/frp version`. Capture Beta 12 and build
   `observed-whisper-20261010-12`. Start with `/frp debug off`.
2. Mouse over and target a known player without ForeverRP (include a multiword
   name). Clear target/move the mouse away immediately, then wait 35 seconds.
   Repeat while holding target for 35 seconds. Expect no FRP presence, Nearby
   entry or notification and no yellow spam. A missing reply is normal.
3. If yellow text recurs: `/frp debug on`, repeat once after `/reload` (to reset
   probe suppression), capture the preceding `WHISPER` lines and yellow message
   together, including prefix/type, bracketed recipient, source, timestamp and
   enqueue result. Capture `/frp diag` too, then `/frp debug off`. Do not manually
   whisper guessed address variants. State whether other RP addons were loaded.
4. With a consenting ForeverRP tester, stand together without a party/guild,
   observe once and verify HELLO/ACK, one Nearby notification and profile request.
   Repeat Hidden and Friends/Guild Only controls without changing opt-ins.

Also retest login/reload with multiword Battle.net friends and with other RP
addons enabled to check shared-library load order. Network/server yellow errors,
delivery, layer/phasing behavior and live UI cannot be proven offline.

## Offline validation

All 15 Lua 5.1 suites pass: 2,018 checks. All runtime and test/helper Lua files
pass `luac -p`; `git diff --check` passes. Tests use actual LibMSP/Chomp framing,
queue and final send functions with mocked client APIs. They cover raw Asty
Pally/Spencer Raven/Single/Cheese Spy recipients, explicit distinct realms,
nonresponders, vanished/reused units, changed recipient with the same key,
Hidden/discovery-disable changes, queue expiry/cap, external CTL and shared
library coexistence, boolean/enum failures, and preserved profile recipients.
Existing suites cover presence admission, Nearby alerts, privacy and retries.

## Exact changed files

- `ForeverRP/Core/Constants.lua` and `ForeverRP/ForeverRP.toc`: test build identity.
- `ForeverRP/Core/DiscoveryDiagnostics.lua` and `ForeverRP/Discovery/Communication.lua`: actual prefix in bounded debug trace.
- `ForeverRP/Core/Events.lua`: carry the triggering event into observation trace metadata.
- `ForeverRP/Discovery/PlayerDetection.lua` and `ForeverRP/Discovery/ObservedDiscovery.lua`: fresh transport evidence; remove probe lookup-key fallback.
- `ForeverRP/Discovery/MSPCompatibility.lua`: raw observed recipients, final-send validity/privacy predicate and result tracing.
- `ForeverRP/Libs/MSP/Chomp/Internal.lua`, `Chomp/Public.lua`, `LibMSP.lua`, `FOREVER-COMPATIBILITY.md`: scoped adapter, maintenance negotiation and documentation (paths relative to `ForeverRP/Libs/MSP` for the last three).
- `tests/forever_transport.lua`, `tests/msp_compatibility.lua`, `tests/observed_discovery.lua`: regression cases.
- `tests/public_commands.lua`, `tests/discovery_diagnostics.lua`: expected build identifier.
- `README.md`, `ForeverRP/README.md`, this report: current test-build status and retest guidance.

No install, commit, push, release publication or SavedVariables edits performed.
