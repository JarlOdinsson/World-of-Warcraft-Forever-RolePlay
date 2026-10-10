# Forever split-name identity repair

Historical test instructions: public build `0.1.1-beta.6` retires the debug,
diagnostic, simulation, manual HELLO and presence commands used below.

Retest version: `0.1.1-beta.4`.
Build: `discovery-identity-20261009-4`.
Package: `dist/ForeverRP-v0.1.1-beta.4.zip`.

## Confirmed live defect

Accepted presence was stored as `Linea Aspera-ClassicBetaPvE`, while target and
party2 returned `UnitFullName = Linea, Aspera`, `UnitName = Linea, Aspera`, and
`GetUnitName(unit, true) = Linea Aspera`. The old resolver treated `Aspera` as a
realm and cached `Linea-Aspera`. The same defect affected `Ravisholan, Ruefield`.
Presence and UI refresh succeeded, but lookup failed with `no-unit-association`.

## Resolution and address handling

Detection, tooltip lookup, local self identity and diagnostics share
`Presence:ResolveUnitIdentity`. It guards unit/API outputs for accessibility
before comparing, concatenating or indexing anything.

- An explicitly qualified GetUnitName result keeps its full character name and
  explicit realm. It does not inherit the local realm or drop a cross-realm suffix.
- For an unqualified GetUnitName result exactly equal to the first return, one
  space, and the second return, that complete result is the character name.
  This is evidence of the observed Forever split-name behavior, not a rule to
  replace hyphens with spaces. The lookup realm comes from accessible local
  client realm APIs; the original unqualified complete name is the probe address.
- If GetUnitName equals the entire first return instead, an accessible nonempty
  second return remains a realm. Standard one-word and multiword cross-realm
  identities keep working.
- Conflicting, inaccessible or unavailable GetUnitName results fail closed.
  Clients without that API retain the existing UnitFullName/UnitName fallback.
- The existing character-key realm normalization and SavedVariables keys are
  unchanged. No migration, hardcoded aliases, bare-name matching across presence
  records, or arbitrary separator substitution is introduced.

| Evidence | Internal lookup key | Initial probe recipient |
| --- | --- | --- |
| UFN `Linea`, `Aspera`; GUN `Linea Aspera`; local realm `ClassicBetaPvE` | `Linea Aspera-ClassicBetaPvE` | `Linea Aspera` |
| UFN `Ravisholan`, `Ruefield`; GUN `Ravisholan Ruefield`; local realm `ClassicBetaPvE` | `Ravisholan Ruefield-ClassicBetaPvE` | `Ravisholan Ruefield` |
| GUN `Linea Aspera-Other-Realm` | `Linea Aspera-OtherRealm` under existing realm normalization | `Linea Aspera-Other-Realm` |

Received packets store their exact sender separately as `transportRecipient`.
ACK replies and profile requests/responses use the original transport address,
with privacy checked against the internal identity key. A successful send still
only means enqueue acceptance. Discovery bounds and consent checks are retained.

## Verification

The existing seven suites cover communication, Connections, restricted values,
prior audit fixes, MSP compatibility, discovery diagnostics and observed discovery.
The observed-discovery suite now includes the exact Linea and Ravisholan API
returns, target/party2 lookup, receive-before-observe, genuine cross-realm suffixes,
`ClassicBetaPvE` versus `ClassicBetaPvE2`, raw recipient preservation for HELLO,
ACK and profile exchange, tooltip/self lookup, and restricted/conflicting outputs.
These are offline API mocks, not live delivery or visual UI validation.

Results: all seven suites passed, 732 checks total. Observed discovery has 27
cases/143 checks, including nine new repair cases/52 checks. All 40 runtime Lua
files passed `luac -p`; `git diff --check` and untracked-file whitespace checks
passed. The existing Settings layout was verified intact.

Package verification passed: all 51 ZIP files match their intended source by
SHA256, including all 40 Lua files and the TOC. The standard package script
supplies README/LICENSE from the repository root. Archive size: 108041 bytes.
ZIP SHA256: `08918F51AEE0D5731540988EAF83B05AA389E35C61F4AF7E933AAD3E0489D41E`.

## Paired retest

1. Both testers install this same ZIP and reload. Run `/frp version`; capture
   version `0.1.1-beta.4` and build `discovery-identity-20261009-4` on both clients.
2. Initially stay in the same party and phase, standing together. Keep the
   existing privacy/radius settings; enable discovery and open Nearby. Target
   each other, wait two seconds, then run `/frp hello` once on each client.
3. On Ravisholan's client run `/frp diag Linea Aspera-ClassicBetaPvE`.
   On Linea's client run `/frp diag Ravisholan Ruefield-ClassicBetaPvE`.
   If the actual packet realm differs, use its exact captured sender identity.
4. Capture all lines and a Nearby screenshot. Expected: the complete character
   name in `normalized` and `cached`, a matched target/party token, eligible
   range, `Nearby=true`, `exclusion=eligible`, and a visible UI row. Split-name
   evidence should read `identityEvidence=split-name-GetUnitName`. A notification
   depends on the existing settings/cooldown. UNKNOWN or a bracket insufficient
   for the configured radius must still be excluded.
5. Move apart and back, mouse over each other, swap targets, and repeat with
   friendly nameplates. NPCs must not become candidates. Confirm names/realms
   remain distinct and there are no Lua errors.
6. Separately test unrelated discovery: no shared party or guild, reload both
   clients to clear runtime presence, Visible privacy, discovery enabled, same
   phase. First mouse over/target each other and capture automatic HELLO/ACK;
   do not manually broadcast during this capture. Then repeat a pass-by with
   friendly nameplates and no targeting/mouseover. Capture `/frp diag` on each
   client, including probe address, received sender, matched unit and range.
7. Repeat Hidden and Friends/Guild Only with permitted and unpermitted peers;
   verify no forbidden probes or notifications. Repeated observation of a
   non-addon player must remain bounded and never manufacture presence.

Unqualified names supply no independent remote-realm identity. This repair only
qualifies those with local realm evidence; it never attaches them to an arbitrary
same-name remote peer. If a peer remains unmatched, capture `GetRealmName`,
`GetNormalizedRealmName`, player/target/party UFN/UN/GUN fields, incoming sender,
version/build and `/run print(GetBuildInfo())`. A mismatch between local realm
evidence and sender realm still requires investigation, not an invented alias.
Unrelated-player whisper delivery, friendly nameplate coverage, combat/phase
restrictions and visual notifications remain client-only validation gates.

The Forever-generated [Unit API export](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
documents restricted unit/name APIs. The split-name behavior above is established
by the tester's actual client output, not inferred from standard retail semantics.

## Files changed for this repair

- `ForeverRP/Discovery/Presence.lua`
- `ForeverRP/Discovery/PlayerDetection.lua`
- `ForeverRP/Discovery/ObservedDiscovery.lua`
- `ForeverRP/Discovery/Communication.lua`
- `ForeverRP/Discovery/ProfileTransfer.lua`
- `ForeverRP/UI/PlayerTooltip.lua`
- `ForeverRP/Core/DiscoveryDiagnostics.lua`
- `ForeverRP/Core/Constants.lua`
- `ForeverRP/ForeverRP.toc`
- `tests/observed_discovery.lua`
- `tests/discovery_diagnostics.lua`
- `tests/README.md`
- `docs/DISCOVERY_DIAGNOSTICS.md`
- `docs/UNRELATED_PLAYER_DISCOVERY.md`
- `docs/IDENTITY_RESOLUTION_RETEST.md`

Existing uncommitted Settings layout and other prior work are preserved.
Packaging is local only; no deployment, commit, push or release publication.
