# Beta 14: native profile pipeline and MSP A/B isolation

Version `0.1.1-beta.14`, build `profile-ab-20261010-14`.
Requester-only diagnostic build. Keep the responder on Beta 12 initially.
Beta 13's empty-MSP/source-priority/privacy fixes are retained.

## What is established

Confirmed presence, WITHIN_10 and a Nearby row prove discovery, not a completed
profile request. The live report has no correlated request ID or response chunks;
the first live failing stage remains unknown. No native behavior repair is made
on the assumption that realms or MSP caused the failure.

The actual archived Beta 12 Communication, Presence, ProfileTransfer and
ProfileAuthorization modules were replayed against a Beta 13 requester wire
version, with actual Nearby row callback, privacy/disclosure, queued responses,
packet parsing, assembly, cache and viewer code. Full profiles succeed when
HELLO and profile senders are bare on clients using different local realms.
Protocol version stays 1, packet layouts/request IDs are unchanged, and Beta 12
does not reject a request solely because the requester version is 13/14.

Two reproduced failure boundaries are diagnostic hypotheses, not live findings:

- Bare HELLO becomes a key using the receiver's local realm. A later qualified
  profile sender with a different realm is rejected at confirmed-peer admission.
  This can happen on the requester or responder. No realm aliases are invented.
- Approval disclosure sends `pending` rather than profile chunks until the owner
  approves. Discovery visibility/confirmed presence does not override disclosure.

Actual Beta 12 archive used: `dist/ForeverRP-v0.1.1-beta.12.zip`, SHA256
`EDBF9EF199ED50B1DB12A0DC5908DE569036AF6CC8F2B4BE0F4B168DAB4889ED`.
The test loads code from a workspace extraction, not the tester's installation.

## Temporary reversible toggle

- `/frp msp on`: enable ForeverRP's integration (normal default).
- `/frp msp off`: disable only ForeverRP's integration.
- `/frp msp status`: read current preference.
- **Run `/reload` after changing it for each A/B pass.** This empties native and
  imported runtime caches and resets pending requests, yielding a fresh test.

The optional account flag `ForeverRPDB.diagnosticMSPDisabled=true` persists across
reload. `/frp msp on` removes it. Existing privacy/disclosure/opt-ins are unchanged.
Toggle changes clear ForeverRP's MSP cache/request history immediately; reload
is still required for a clean comparison. OFF blocks automatic requests, guarded
queued sends, imported cache selection/storage and callbacks opening/updating the
ForeverRP viewer. Shared `msp`, Chomp, their callbacks and other addons' MSP work
remain available. Shared API diagnostics may therefore still show MSP traffic
from another addon even while ForeverRP integration is OFF.

## Exact A/B procedure (requester)

The installed client must `/reload` to load Beta 14. Use the same responder,
party and privacy/disclosure preferences in both passes. Do not alter addresses
or try guessed variants. Have the Beta 12 responder enable `/frp debug on` first.

Pass A:

```text
/frp msp on
/reload
/frp version
/frp debug on
```

Wait for the responder's Nearby row. Click that row **once** to request a profile;
the Remember/Favorite button is a different control. After 35 seconds:

```text
/frp diag profile
```

Capture the PROFILE lines from the click onward (chat history includes up to 60
metadata records/minute; the report repeats the last 12). Keep the request ID,
raw recipient, normalized key, rejection/status reason and first/last chunk.

Pass B:

```text
/frp msp off
/reload
/frp msp status
/frp debug on
```

Wait for the same Nearby row, click once, wait 35 seconds, and capture
`/frp diag profile` again. Request IDs differ between passes; correlate each
response to its own request. Finish with `/frp debug off`. Restore the normal
integration with `/frp msp on` then `/reload` after recording the result.

Live A/B is **not executed by Codex**: the Windows computer-use connection failed
(`native pipe unavailable`). Offline replay is not a substitute for live sends.
The user's two captures are needed to establish the first failing live stage.

## Responder Beta 12 evidence without reinstall

Capture `/frp version`, `/frp debug on`, and the following policy-only diagnostic:

```text
/run print("FRP POLICY",ForeverRP.Database:GetPrivacyMode(),ForeverRP.Database:GetDisclosureMode())
```

During each single requester click, capture `PROFILE_REQUEST received from`,
`ignored from unconfirmed sender`, any approval notice, and PROFILE_DATA whisper
send results. Beta 12 already has these debug paths, although it lacks Beta 14's
correlated pipeline diagnostics.

If request admission/queue correlation is still missing, these optional, bounded
secure post-hooks inspect existing methods without modifying files or libraries.
Run each once; each hook prints at most four records. `/reload` removes them.
They observe arguments/queue state, not return values or delivery.

```text
/run local n=0;hooksecurefunc(ForeverRP.ProfileTransfer,"HandleRequest",function(_,p,s,k) if n<4 then n=n+1;print("FRP REQUEST ADMITTED",p.messageId,s,k) end end)
/run local n=0;hooksecurefunc(ForeverRP.ProfileTransfer,"SendProfile",function(t,k,id) if n<4 then n=n+1;local q=t.outgoingResponses[k:lower().."\031"..id];print("FRP RESPONSE QUEUED",id,q and #q.chunks or 0) end end)
```

An admitted request with no queued response requires disclosure/approval or
queue-admission evidence. A request rejected as unconfirmed before HandleRequest
will not trigger these hooks. Reinstalling the responder is only justified if
captured evidence locates a responder-side defect requiring a fix.

## Reading the first failing stage

| Trace | Meaning / next evidence |
| --- | --- |
| No `nearby-click` | Wrong control, row callback not reached, or debug not enabled |
| `nearby-action cached-FRP` / `already-pending` | Existing UI admission explains no new packet; start fresh with reload |
| `request-reject` | Unknown peer, pending request or capacity rejection |
| `request-send` | Exact raw target, full key, request ID and enqueue result; success is not delivery |
| No responder receipt | Delivery not established; capture Beta 12 debug before changing an address |
| `packet-reject unconfirmed-sender` | Incoming identity lacks an exact/full case-equivalent confirmed match; compare bare/qualified sender evidence |
| `authorization` / `status` | Public/connection/approval decision, pending/denied/busy status |
| `response-queued` | Response admitted with chunk count and raw target |
| `chunk-send` / `chunk-send-failed` | First/last accepted enqueue or failed chunk/retry; not confirmed delivery |
| Requester `receive`, `chunk-reject`, `chunk-accepted` | Actual packet admission and request-ID/transfer matching |
| `assembly-reject` | Schema/encoding/bounds validation failure |
| `cache FRP-stored`, `viewer ForeverRP` | Completed native storage and selected source |
| `request-expired` | No successful completion before timeout; preceding boundaries locate the loss |

## Bounds and validation

PROFILE tracing requires debug ON. It stores at most 64 metadata lines, emits at
most 60/minute, deduplicates within five seconds, and prints only first/last
successful chunks plus failures. Reports are limited to once per five seconds,
12 history lines plus a status header. No profile contents or private notes are
accepted into these trace calls. Existing WHISPER limits remain separate.

Run all suites with Lua 5.1. Additional actual Beta 12 replay:

```text
lua tests/profile_pipeline.lua build/beta12-profile-audit/ForeverRP
lua tests/profile_pipeline.lua build/beta12-profile-audit/ForeverRP 0.1.1-beta.14
```

The extraction is generated from the existing archive and is not packaged.
All 17 Lua 5.1 suites pass (2,367 checks), with two additional 205-check actual
Beta 12 replays using Beta 13 and Beta 14 requester version strings. All 45
runtime and 19 test/helper Lua files compile; `git diff --check` passes.
Regression coverage includes real row callback -> request -> response queue ->
chunks -> assembly -> cache -> viewer; both realm mismatch boundaries; approval;
metadata limits; MSP absent/enabled/disabled; empty/populated data before/after
FRP; reload persistence; queued cancellation; shared-library isolation. No live
transport delivery or visual layout is established by these mocks.

Incremental runtime files: `Core/Commands.lua`, `Core/DiscoveryDiagnostics.lua`,
`Discovery/MSPCompatibility.lua`, `Discovery/Communication.lua`,
`Discovery/ProfileTransfer.lua`, `Discovery/ProfileAuthorization.lua`,
`UI/Nearby.lua`, `Profile/ProfileViewer.lua`. Build metadata and READMEs identify
Beta 14. Tests: `profile_pipeline.lua` (new), `profile_sources.lua`,
`msp_compatibility.lua`, expected build strings and `tests/README.md`.
All prior uncommitted Beta 12/13 repairs are preserved. No GitHub push/publication.
