# Beta 9: login names and whisper transport retest

Version **0.1.1-beta.9**, build **forever-names-transport-20261010-9**.
Baseline: Beta 8, commit `48f232c`; initial working tree was clean. Existing UI,
privacy/disclosure controls, SavedVariables schema, multiword identity resolution,
directory consent, range checks, notifications and traffic limits are retained.
No CurseForge release is authorized or created. This is a controlled test build.

## Finding 1: confirmed login-time Chomp defect

Chomp v24 derives both its split/find patterns and merged output from the client
display global `FULL_PLAYER_NAME`. With `%s %s`, the patterns become
`^(.-) (.+)$` and `^.- .+$`. Therefore `Spencer Raven` and `Cheese Spy` appear
already realm-qualified. `UpdateBattleNetAccountData` receives character and realm
as separate API fields and calls `NameMergedRealm(characterName, realmName)`, which
throws the exact reported error. No observation or Nearby evaluation is involved:
the real Chomp PLAYER_LOGIN and Battle.net update callbacks invoke this path.

The fix uses a library-local `%s-%s` identity format on supported Forever Interface
16001. The global display format is untouched. Full multiword names survive
separate realm merging and cache indexing. ClassicBetaPvE and ClassicBetaPvE2
remain separate keys. Matching already-qualified and explicit realm inputs are
idempotent on Forever; contradictory explicit realms still raise an error.
Other clients retain upstream formatting and duplicate-realm behavior.

Related callers were audited: in-game receive parsing, logged receive parsing,
Battle.net receive identity, broadcast targeting, SmartAddonMessage targets,
report-by-GUID merging, LibMSP's own name, coalesced-group names, cache metatables,
QueueRequest/Request/Send. They all use the corrected merge/split implementation.
The unit-derived own/group/broadcast identity calls additionally use complete
`GetUnitName(unit, true)` evidence, preserving a genuine explicit realm and resolving
Forever's first-name/surname UnitFullName split without guessing an alias.
Inaccessible/conflicting complete unit evidence is skipped.

Battle.net cache generation and reverse/case-insensitive lookup retain complete
character identities. Existing realm normalization remains; no realm aliases or
ClassicBetaPvE/ClassicBetaPvE2 collapsing were introduced. No profile/note contents
are involved in the cache or diagnostics.

## Shared-library behavior

Chomp is shared through LibStub. The bundled maintenance version is **25 on
Forever**, explicitly a local compatibility revision of upstream v24, and **24
elsewhere**. Normal NewLibrary negotiation upgrades a shared v24 in place and
prevents a later v24 from replacing it. A selected equal/newer shared implementation
is not forcibly overwritten. License headers and ISC/CC0 notices remain intact;
the installed [compatibility notice](../ForeverRP/Libs/MSP/FOREVER-COMPATIBILITY.md)
records the changes.

`/frp diag` reports client version/build/interface, FULL_PLAYER_NAME, Chomp's
selected VERSION and ForeverNameCompatibility. Expected with ForeverRP alone:
Interface 16001, Chomp 25, ForeverNameCompatibility true. This revision is not
advertised as an upstream Chomp release. A different external v25/v26+ may not
contain the patch; capture its flags/version rather than downgrading it.

Another RP addon's LibMSP may initialize before ForeverRP and retain older private
unit-name locals. This patch cannot undo an already-raised earlier error or alter
private cached locals. Standalone and coexistence tests are both required; no
blanket guarantee for arbitrary third-party versions/load orders is made.

## Finding 2: confirmed MSP corruption path; live yellow-error attribution pending

The unpatched parser also corrupts qualified MSP recipients:

| MSP request input | Old space-format output | Fixed Forever output |
| --- | --- | --- |
| Cletus Jenkins-ClassicBetaPvE | Cletus JenkinsClassicBetaPvE | Cletus Jenkins-ClassicBetaPvE |
| Ellina Stillwind-ClassicBetaPvE | Ellina StillwindClassicBetaPvE | Ellina Stillwind-ClassicBetaPvE |
| Gladiator Trapgodx-ClassicBetaPvE | Gladiator TrapgodxClassicBetaPvE | Gladiator Trapgodx-ClassicBetaPvE |

The old parser splits the character at the first space, treats surname plus realm
as a realm, removes that realm's hyphen, then uses the space display formatter.
The actual bundled LibMSP → Chomp → mocked API path reproduces these strings.
This provides a concrete explanation matching the tester's yellow message.
It does **not** prove which live send produced that particular system message,
that the error displays the API argument verbatim, or that a corrected recipient
will be delivered by the server. The reported Beta 5 ZIP was not available here;
its contents were not independently verified against the installed Beta 8 source.

Mouseover/target invokes the MSP reader as well as ForeverRP's directed discovery,
so white detection text followed by a delayed yellow error does not identify the
responsible protocol by itself. Chomp may use Battle.net for a known cross-realm/
faction friend, and may apply client Ambiguate, CTL queuing or coalesced-group
broadcast routing. Those mechanisms remain; no speculative ForeverRP transport
address rewrite was made.

### Actual outbound recipient trace

| Send | Source / transformation before API |
| --- | --- |
| Observed HELLO | ResolveUnitIdentity's raw recipient from client evidence → PlayerDetection association → ObservedDiscovery → SendPayload → send API, unchanged |
| HELLO reply ACK | Raw CHAT_MSG_ADDON sender → reply budget → send API, unchanged |
| Presence recipient | Raw incoming sender retained separately from canonical key; metadata now records source message kind |
| Profile request | Stored raw presence recipient; canonical-key fallback is explicitly labeled if no raw recipient exists |
| Profile chunks | Raw incoming request sender, or labeled stored recipient fallback; retries reuse the same address |
| Profile status / revocation | Stored presence recipient / previously served raw recipient, respectively |
| MSP | Canonical MSP key → Chomp merge → Battle.net cache ID or existing Ambiguate/CTL/broadcast routing → API |

ForeverRP's normalization validates recipient equivalence and privacy but does
not substitute the normalized key into its API target argument. The previous
realms/spaces fix in Presence is retained. Tests exercise raw client names,
qualified incoming senders and the existing distinct/cross-realm cases.

New debug-only `WHISPER` lines include uptime, API, message type, exact escaped
recipient in brackets, source, enqueue acceptance/rejection and raw result.
No payload, biography or private note is stored/printed. Output is capped at 30
lines per 60 seconds, identical traces suppressed for 10 seconds, history capped
at 20. `/frp diag` includes the last five only while debug is on. Filters and
transport retries are not changed by diagnostics.

For ForeverRP sends, the original API result is decoded with existing bool/enum
rules: success is accepted for enqueueing, never confirmed delivery. Shared MSP2
secure post-hooks capture actual SendAddonMessage/Logged or BNSendGameData targets
but cannot observe original API return values: enqueue is explicitly unobserved.
They may observe another addon's MSP2 traffic; that source is labeled shared.
No global send function is replaced. The Forever Chomp copy no longer registers
its existing player-not-found filter, so yellow errors remain visible. Other
addons' filters/functions are neither disabled nor overwritten.

## Required live reproduction and validation

All real-client results below are **NOT RUN** by the development environment.
Mocks do not prove successful login, secret-value behavior or message delivery.

1. Both testers install the same Beta 9 ZIP and restart the client. Capture
   `/frp version`; both must show the build above. Leave SavedVariables intact.
   Initially test with ForeverRP as the only enabled RP addon; later repeat with
   other MSP addons enabled and record names/versions/load configuration.
2. Login while Battle.net friends include Spencer Raven and/or Cheese Spy on
   ClassicBetaPvE2. No targeting or mouseover is required. Capture any full Lua
   error and its stack. Run `/frp debug on`, then `/reload` with those friends still
   online; repeat logout/login and a friend online/offline transition.
   Expected: no reported Chomp duplicate-realm error and the correct compatibility
   flag/version. Existing visibility/privacy choices must survive reload.
3. On each client, run `/frp diag` and capture its client/display/Chomp metadata.
   The library's Battle.net cache is not dumped, to avoid disclosing other friends.
   If the error persists, include the stack and selected library version/flag,
   especially whether another addon initialized first.
4. For whisper isolation, start Visible, discovery enabled, no simulation,
   experimental directory networking off, and Public disclosure. Stand together
   in the same phase without a shared party/guild. Prefer a tester who is not a
   Battle.net friend for the initial in-game route. Neither client should manually
   send a normal chat whisper during this test.
5. With `/frp debug on`, mouse over or target the other player and hold a usable
   observation for 20 seconds. Capture every `WHISPER` line, the white detection
   line and the full delayed yellow message, including time/order. Repeat on both
   clients. Preserve spaces and realm suffixes exactly in captures. Do not infer
   the API target from the yellow display text; compare the logged API arguments.
6. On both run `/frp presence`, `/frp nearby`, and
   `/frp diag Full Character Name-Realm` with the peer's actual realm. Wait at
   least five seconds between diagnostics. Capture HELLO/ACK receipt, acceptance,
   usable unit, range (including UNKNOWN) and exclusion reason. An accepted send
   without a received peer handshake remains a transport failure/unknown.
7. Establish a party, run `/frp hello` on each, then explicitly Request Profile
   through Nearby. Capture API targets for ACK, PROFILE_REQUEST and PROFILE_DATA
   plus actual completed profiles on both clients. Recheck approvals/restricted/
   Hidden mode and Connections notes. These should retain their Beta 8 behavior.
8. Repeat the target/mouseover test with the reported Cletus Jenkins, Ellina
   Stillwind and Gladiator Trapgodx where available. Repeat genuine cross-realm
   peers separately: ClassicBetaPvE and ClassicBetaPvE2 must never be merged.
   Then repeat with Battle.net friendship/MSP enabled and other RP addons to
   exercise the numeric Battle.net path and shared-library selection.
9. Finish `/frp debug off`. With debug off, no new WHISPER trace lines should appear.
   Send both builds, client/Chomp metadata, minimal timeline/logs and any Lua stack.
   Review identity/account-ID captures before sharing; no profiles/private notes.

Debug limits can omit lines during profile bursts. If the 30-line window is
exhausted, wait 60 seconds and repeat a single scenario. Discovery retry budgets
still apply; missing new probes within the peer's existing cooldown is expected.
Do not use simulation as live-delivery evidence.

## Automated checks and change scope

New `tests/forever_transport.lua` uses actual bundled LibStub, CallbackHandler,
Chomp and LibMSP files and actual library event handlers. Test-only client stubs
reproduce the original login error and MSP corruption with the upstream
space-format branch, then verify the Forever-scoped corrected branch. Coverage:
both reported Battle.net names, single/qualified/separate realms, distinct realms,
fresh-session reload modeling, login/friend/world callbacks, shared version
selection, unchanged non-Forever behavior, real outbound profile/discovery/MSP
arguments and bounded/debug-only diagnostic hooks. No errors are swallowed by
runtime code; pcall is used in tests to assert the original expected exception.

All existing suites, every runtime/test Lua syntax check and whitespace checks
are run before packaging. Final counts/package integrity are recorded below.

Exact changed files relative to the Beta 8 baseline:

- Runtime/version: `ForeverRP/Core/Constants.lua`, `ForeverRP/Core/DiscoveryDiagnostics.lua`,
  `ForeverRP/Discovery/Communication.lua`, `ForeverRP/Discovery/MSPCompatibility.lua`,
  `ForeverRP/Discovery/ObservedDiscovery.lua`, `ForeverRP/Discovery/PlayerDetection.lua`,
  `ForeverRP/Discovery/Presence.lua`, `ForeverRP/Discovery/ProfileAuthorization.lua`,
  `ForeverRP/Discovery/ProfileTransfer.lua`, `ForeverRP/ForeverRP.toc`.
- Bundled library: `ForeverRP/Libs/MSP/Chomp/Internal.lua`,
  `ForeverRP/Libs/MSP/Chomp/StringManip.lua`, `ForeverRP/Libs/MSP/LibMSP.lua`,
  new `ForeverRP/Libs/MSP/FOREVER-COMPATIBILITY.md`.
- Documentation: `README.md`, `ForeverRP/README.md`, `CHANGELOG.md`, `tests/README.md`,
  new `docs/BETA9_TRANSPORT_RETEST.md`.
- Tests: `tests/discovery_diagnostics.lua`, `tests/observed_discovery.lua`,
  `tests/public_commands.lua`, new `tests/forever_transport.lua` and
  `tests/helpers/chomp_fixture.lua`.

Source inspection confirms no UI layout, SavedVariables schema, range algorithm,
discovery budget, profile persistence or sound asset changes. Debug traces alone
are added to existing handlers. Settings' MingleBar spacing remains 8.

## API evidence and remaining uncertainty

The inspected [Forever ChatInfo declarations](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua)
declare a string target and enum send result, but do not specify a multiword
whisper wire grammar. [Battle.net declarations](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/BattleNetDocumentation.lua)
provide separate characterName/realmName fields. These support the parser diagnosis
and logging design; they do not prove an address format works on the tester's
actual client/server. No delimiter stripping, guessed alias or transport fallback
is presented as a delivery fix.

The confirmed Chomp parser defects are repaired and offline-tested. Attribution
of every yellow message and actual live delivery remain open until the controlled
test above. Cross-layer coverage remains experimental as in Beta 8.

## Completed offline validation

2026-10-10: all **12 suites / 1,486 checks passed** under Lua 5.1. The new suite
has 10 cases / 207 checks. All 45 runtime Lua files and 14 test/helper files passed
`luac -p`; `git diff --check` and untracked-source whitespace checks passed.

The existing `tools/package.ps1` produced
`dist/ForeverRP-v0.1.1-beta.9.zip` (145,837 bytes). All 59 packaged files match
development inputs by SHA-256, honoring the packager's existing root README/LICENSE
overrides. Packaged version/build and original sound/third-party license files
were retained. No packaging script change was necessary.

ZIP SHA-256: `AE26A2F8911E9E4058CF7199A2761709CC46A62AFEA5B7A268FCB17AFE3153DA`.
This verifies artifact integrity, not live client behavior.
