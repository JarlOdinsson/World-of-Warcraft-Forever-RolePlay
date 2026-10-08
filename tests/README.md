# Offline communication checks

Run `lua tests/communication.lua` or `luajit tests/communication.lua` from the
repository root. Requires Lua 5.1 or LuaJIT; no external Lua libraries.

The tests load the real communication module with boolean and numeric enum
mocks, including already-registered prefixes, failures, throttling, unknown
results, and privacy suppression. They also compile all runtime Lua files
listed in the imported TOC without executing game APIs.

Offline checks cannot confirm live delivery, server throttling, profile
completion, or UI behavior. Send success means accepted for enqueueing.
