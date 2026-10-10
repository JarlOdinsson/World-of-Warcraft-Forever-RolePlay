# Offline communication checks

Run `lua tests/communication.lua` or `luajit tests/communication.lua` from the
repository root. Requires Lua 5.1 or LuaJIT; no external Lua libraries.

The tests load the real communication module with boolean and numeric enum
mocks, including already-registered prefixes, failures, throttling, unknown
results, privacy suppression, presence lifecycle changes, renewal, and bounded
retries. They also compile all runtime Lua files listed in the imported TOC
without executing game APIs.

Offline checks cannot confirm live delivery, server throttling, profile
completion, or UI behavior. Send success means accepted for enqueueing.

Run the full suite from the repository root:

```powershell
lua tests/communication.lua
lua tests/connections.lua
lua tests/restricted_values.lua
lua tests/audit_fixes.lua
lua tests/msp_compatibility.lua
lua tests/discovery_diagnostics.lua
lua tests/observed_discovery.lua
lua tests/notifications.lua
lua tests/public_commands.lua
lua tests/enhanced_discovery.lua
lua tests/directory.lua
lua tests/forever_transport.lua
lua tests/privacy_ux.lua
lua tests/directory_transport.lua
```

LuaJIT can replace `lua` in these commands. The Connections suite uses mock
widgets plus the actual Connections, presence, privacy, transport, transfer,
and remote-cache modules. It covers draft preservation, selection/focus/hide/
logout saving, immediate encounter timestamps, request availability, pending
requests, timeout, throttling, and profile completion. The communication suite
also syntax-checks every runtime module listed in the TOC.

The restricted-values suite uses inaccessible-value sentinels that cause mocked
unit APIs to fail if ForeverRP reaches them. It covers tooltip and identity
guards, NPCs, disappearing units, nameplate removal, group units, range state,
simulated discovery, and the legacy fallback when `canaccessallvalues` is not
available. It cannot reproduce the client secret/taint engine itself.

The observed-discovery suite loads real detection, communication, privacy,
presence, range, Nearby and notification modules against mocked client APIs.
It covers unrelated-player observation, HELLO enqueue vs ACK confirmation,
Nearby/UI-refresh/notification calls, full names with spaces, mismatched realms,
NPCs, inaccessible values, token removal/reuse, unknown and changing range,
simulation/group isolation, privacy revocation, disabled discovery, retries,
crowd budgets, throttling, ACK storms and observed presence renewal.
Mocked notification/UI calls are not visual UI or live delivery validation.

The notification suite covers audible alert selection, Master/SFX routing,
SavedVariables defaults and validation, Test Sound button/dropdown wiring,
preview rate limiting and independence from peer cooldowns. It forbids global
audio-setting writes. Actual loudness, channel behavior and layout need client
validation. The observed-discovery suite also checks eligible bracket/unit
changes and leave/reentry cooldowns against the real notification module.

The same suite includes exact Forever split-name API returns for Linea Aspera
and Ravisholan Ruefield, target/party2 matching against received presence,
receive-before-observe, ClassicBetaPvE versus ClassicBetaPvE2, genuine cross-realm
suffixes, raw transport addresses for discovery and profiles, shared tooltip/self
identity, and conflicting/inaccessible complete-name outputs. Retest instructions:
[IDENTITY_RESOLUTION_RETEST.md](../docs/IDENTITY_RESOLUTION_RETEST.md).

The public-command suite verifies restored debug, diagnostic, manual HELLO and
presence handlers, debug-gated simulation, retained public commands, full names
in requests, and saved debug migration without losing profiles or notes.

The enhanced-discovery suite exercises real database, privacy, protocol,
authorization, transfer, activity, Connections and marker code. It covers
disclosure defaults/persistence, explicit grants, approval/denial/timeout,
chunk cancellation, cache revocation/lease, bounded retries/prompts/queues,
opt-in networking, Unknown layers, zone changes, inaccessible/invalid coordinates,
marker pooling/removal, privacy UI actions, 250-peer caps, receive floods and
ten minutes of mocked movement with repeated events. Audio tests additionally
cover MP3/Master selection, nil/failed playback, silence and preview cooldowns.
Offline mocks do not prove same-layer or cross-layer delivery, audio decoding,
projection orientation, widget layout or client API behavior.

The directory suite covers shared-cache priority under 260 peers, historical
guild-trust revocation, bounded notices with raw transport recipients, stale
revocation cancellation, actual delayed large-profile queues, bounded prefix
registration recovery, independent directory/location consent, local status/
zone/name filters, DND withdrawal, AFK and legacy LF RP handling, guarded map
hierarchies, stationary marker freshness/rotation/zoom, and explicit UI requests.
It also runs the combined real discovery modules against the reported Forever
split-name API returns, checks the single shared lifecycle ticker, and verifies
that bracket changes, metadata opt-out and directory-only peers do not create
duplicate proximity alerts or bypass unit/range requirements.

The Forever transport suite executes the actual bundled Chomp, LibStub,
CallbackHandler and LibMSP initialization, login/Battle.net callbacks, cache
lookups and outbound sends. It covers multiword names, separate/qualified realms,
shared-library negotiation and unchanged behavior on other clients. It also
exercises real ForeverRP detection/HELLO/ACK/profile sends and bounded debug traces.
MSP post-hooks assert actual API arguments, without inferring the API return value.
Test-only client stubs do not establish real login, delivery or recipient syntax.

Beta.9 issue-specific live tests: [BETA9_TRANSPORT_RETEST.md](../docs/BETA9_TRANSPORT_RETEST.md).
Directory live test instructions: [DIRECTORY_GUILD_TESTING.md](../docs/DIRECTORY_GUILD_TESTING.md).
The beta.7 checklist/report are historical and superseded by beta.8.

The privacy UX suite checks all blocker combinations, saved versus effective network
status, independent location/listing consent, real setter refreshes, panel switching
and SavedVariables reinitialization. Widget width/line estimates are mocked; they
do not verify client font rendering, UI scaling or live /reload behavior.

The Directory transport suite exercises delayed/failed joins, membership loss,
bounded recovery, numeric-channel changes, route changes and send failures.
It dispatches the real CHAT_MSG_ADDON event and bridges two independent mocked
clients through the real metadata parser, presence and Directory query, with no
shared party/guild or remote unit. That bridge deliberately delivers packets:
it proves no dependency on mouseover or Nearby, not cross-layer server delivery.
The rate-limited /frp network report distinguishes enqueue from remote receipt.
