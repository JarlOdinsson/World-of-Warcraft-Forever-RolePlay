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
