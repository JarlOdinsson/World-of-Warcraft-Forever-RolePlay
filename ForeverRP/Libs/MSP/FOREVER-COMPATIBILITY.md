# ForeverRP local compatibility patch

Bundled Chomp remains derived from upstream v24 under its original ISC notices.
LibMSP retains its CC0 notice. No license text or copyright header was removed.

On client Interface 16001 only, this copy advertises **local compatibility
revision 26** through normal `LibStub:NewLibrary("Chomp", version)` negotiation.
This is a ForeverRP maintenance revision, not a claim to be upstream Chomp v26.
Non-Forever clients retain v24 and upstream formatting/filter behavior. A selected
newer shared library is left alone. An equal/newer external revision may lack this
patch; check `/frp diag`'s version and ForeverNameCompatibility flag and retest.
Do not force-downgrade/replace another addon's shared library to work around it.

The local identity format on Forever is `%s-%s`, independent of the client display
global `FULL_PLAYER_NAME`. Spaces in character names remain untouched. Matching
explicit/qualified realms are idempotent; contradictory realms still error.
Unit-name call sites use `GetUnitName` evidence for split surnames. The Battle.net
cache keeps full character names and realm suffixes. Its existing normalized
realm convention remains, including distinct ClassicBetaPvE and ClassicBetaPvE2.

The Forever version does not register Chomp's player-not-found system-message
filter or collect filter keys. It leaves these errors visible. It still meters
outgoing traffic and retains the library's protocol, queues and callbacks.

LibMSP advertises local maintenance revision 33 on Forever (upstream 32 elsewhere).
Its additive `RequestObserved` adapter keeps the canonical MSP cache key separate
from the observed client recipient. Only ForeverRP's automatic target/mouseover
requests opt into this adapter. Their short binary MSP request uses Chomp framing
and its LOW-priority bandwidth queue, with a 32-message cap and five-second expiry.
The final send revalidates the observation, privacy and exact raw recipient. It
does not pass that recipient through `NameMergedRealm`, `Ambiguate`, Battle.net
selection or an external CTL queue that cannot cancel it. External CTL still sees
the actual API send through its normal bandwidth hook. Ordinary shared-library
requests, replies and other addons keep their existing transport behavior.

Equal/newer shared libraries without this adapter remain untouched. ForeverRP
skips automatic MSP requests in that case; ForeverRP HELLO discovery continues.
The library notices remain intact. This does not prove that a client-reported
recipient is deliverable after the player leaves, phases or disconnects. Live
retesting is required; no system-message filter is added.

Another addon's older LibMSP may have initialized/cached local identity before
ForeverRP loads; this update cannot undo an earlier Lua error or rewrite those
private cached locals. Test ForeverRP alone and then with each other RP addon.
