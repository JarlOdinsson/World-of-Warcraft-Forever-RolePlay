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
```

LuaJIT can replace `lua` in both commands. The Connections suite uses mock
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
