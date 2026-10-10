# Beta 11 CheckInteractDistance blocked-action repair

The repair is installed locally; all 59 installed addon files were verified against
the source at deployment. The user subsequently reported it working with no Lua
error. Specific combat conditions and the full retest matrix were not recorded.
The original generated Beta 11 ZIP predates this repair; the user packages the
installed addon folder manually. Source, tests and documentation accompany this fix.

## Confirmed defect and scope

The supplied live stack follows Events UPDATE_MOUSEOVER_UNIT -> PlayerDetection
RefreshUnit/DetectUnit -> ObservedDiscovery Observe/Candidate -> Range GetRangeState
-> InteractionCheck -> CheckInteractDistance. Range was checking token accessibility
and output accessibility, but had no pre-call combat-lockdown guard. The same range
helper is used by Nearby reevaluation and existing diagnostic commands, so guarding
only mouseover would leave the other callers vulnerable.

The error confirms that this API call was blocked in the reported context. The
stack does not record combat state, friendliness, instance or client build, so
combat as the exact trigger for that occurrence is a supported explanation rather
than a confirmed observation from this report alone.

## Restriction evidence

- [Blizzard hotfix notes](https://worldofwarcraft.blizzard.com/en-us/news/24030413/hotfixes-january-8-2024)
  document restrictions on addon player-distance checks in combat. Those historical
  retail notes do not independently establish every Forever-client condition.
- [LibRangeCheck's own implementation](https://raw.githubusercontent.com/WeakAuras/LibRangeCheck-3.0/master/LibRangeCheck-3.0/LibRangeCheck-3.0.lua)
  recognizes Forever and guards interaction checks with its combat restriction,
  allowing a hostile-unit exception. This repair does not assume that exception is
  reliable on the current Forever client: all real interaction checks pause in
  combat lockdown, including hostile players.
- [Forever generated restricted-action API definitions](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua)
  expose InCombatLockdown as a boolean and define ADDON_ACTION_BLOCKED. A function
  call that emits a blocked event must be prevented, not merely caught with pcall.
- [Forever generated unit API definitions](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
  mark UnitInRange results secret and return separate checkedRange evidence. The
  coarse group range is not proof of the configured 10–30-yard proximity bracket.
  UnitDistanceSquared's signature alone does not establish permission to obtain
  precise distances in restricted contexts. No coordinate, spell or item workaround
  is added to reconstruct unavailable evidence.

## Implementation

InteractionCheck now requires an accessible InCombatLockdown() result exactly
false before each CheckInteractDistance call. Missing API, nil, inaccessible or
unrecognized combat evidence returns unavailable without calling the protected
function. The guard is repeated for subsequent interaction brackets; it does not
rely on a combat flag cached earlier in the event or ticker.

Allowed out-of-combat interaction checks and their existing boolean/numeric output
handling remain intact. Unavailable evidence remains UNKNOWN; IsWithin returns
false. Existing negative/positive bracket mapping is unchanged by this repair.
Simulation stays runtime-only and uses its explicit simulated state without invoking
real interaction APIs. Existing input/output accessibility guards are retained.
No pcall, secure execution, event suppression or error filtering is introduced.

No Nearby rules or communication/privacy/UI logic change. Unknown range still
allows the existing bounded observed-player handshake, but cannot admit Nearby.
An existing Nearby player can leave the eligible list during lockdown and return
once the existing one-second ticker finds accessible allowed range evidence again.
The current notification cooldown continues to apply. Directory metadata discovery
continues without visible units or a range result; layer stays Unknown.

## Exact changed files

- ForeverRP/Discovery/Range.lua: pre-call lockdown/accessibility guard.
- tests/range_restrictions.lua: nine focused cases, 119 assertions.
- tests/helpers/client_fixture.lua: explicitly mock documented out-of-combat state.
- tests/restricted_values.lua: explicitly mock documented out-of-combat state.
- tests/observed_discovery.lua: explicitly mock documented out-of-combat state.
- tests/discovery_diagnostics.lua: explicitly mock documented out-of-combat state.
- tests/forever_transport.lua: explicitly mock documented out-of-combat state.
- tests/README.md: add suite invocation and limits.
- docs/RANGE_BLOCKED_RETEST.md: this report and live procedure.
- README.md and ForeverRP/README.md: current range behavior, live retest limits,
  current testing links and network diagnostic description.
- CHANGELOG.md: post-Beta-11 range repair note.

The checkout was clean at task start. Existing UI layout, Settings spacing,
SavedVariables, opt-ins, Directory, identity handling and privacy are preserved.

## Offline results and limits

All 15 suites pass under Lua 5.1.5: 1,827 checks. All 45 runtime Lua files and all
17 test/helper Lua files pass luac -p. git diff --check and new-file trailing-
whitespace checks pass.

The focused suite covers combat lockdown on mouseover/target/focus/nameplate/group
unit tokens and all five configured radii, absent/inaccessible combat evidence,
absent/inaccessible/invalid range evidence, NPCs and disappearing units, allowed
out-of-combat checks, a state change between bracket calls, and simulation isolation.
Its restricted API mock increments a blocked-event counter and throws if invoked
in combat; zero invocations/events are required. This catches calling the API even
if someone later tries to wrap it in pcall.

The actual reported event/detection/observation path is exercised with combat
active. HELLO remains bounded and permitted by existing rules, ACK confirms
presence but does not admit Nearby, and the actual ticker restores Nearby when
allowed out-of-combat evidence returns. Metadata received during combat can still
create a Directory entry without Nearby or location/listing auto-opt-in.

Mocks do not emulate Blizzard's taint engine, verify all Forever protection flags,
prove that the original report occurred in combat, or establish live transport
or cross-layer delivery. The source guard fixes the missing combat precondition;
any continued out-of-combat blocked report needs additional client evidence.

## Required live retest after installing the repaired source

1. Reload with the repaired source installed, not the unchanged Beta 11 ZIP.
   Keep existing opt-ins and privacy settings. Test a real consenting player;
   simulation cannot validate protected APIs.
2. Out of combat: target/mouseover a player, then test focus, a player nameplate
   and a party unit. Confirm normal permitted range brackets, HELLO/ACK, Nearby
   and proximity notifications. NPCs must not become player detections.
3. Enter combat (including a duel if practical) and repeatedly mouseover/target
   friendly players. Exercise focus/nameplates and party changes plus the normal
   ticker and /frp diag. Expect no CheckInteractDistance blocked event. Real range
   should be UNKNOWN while lockdown is active; no new Nearby admission based on
   that unknown result. Existing Nearby eligibility can pause during lockdown.
4. Leave combat, remain near the confirmed player and wait for the next ticker.
   Range and Nearby should recover from fresh allowed evidence. Movement should
   still change brackets; existing notification cooldown must prevent repeat spam.
5. With existing consent, check Directory during combat: listings may update over
   transport independently, without a visible unit or a Nearby row. Hidden and
   disabled-network behavior must remain unchanged. Do not infer a layer from
   receipt; live cross-layer verification remains a separate test.
6. If a block persists, capture the full new stack and /frp version. At the time
   of reproduction capture this safe context command (it makes no range call):

   `/run print("FRP lockdown:", InCombatLockdown()); print("Client:", GetBuildInfo())`

   Include whether combat/duel was active, target type/friendliness, instance type,
   and which event triggered it. In particular, an explicit false lockdown result
   with continued blocking would indicate another Forever restriction requiring
   investigation; this report does not claim all such contexts are already known.
