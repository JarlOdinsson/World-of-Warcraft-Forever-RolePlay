-- Run from the repository root with Lua 5.1 or LuaJIT.
local checks = 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end

local function Fixture(result, legacy, query)
    C_ChatInfo, Enum = nil, nil
    RegisterAddonMessagePrefix, SendAddonMessage, IsAddonMessagePrefixRegistered = nil, nil, nil
    local calls = 0
    ForeverRP = {
        Constants = {COMMUNICATION_PREFIX = "FOREVERRP", PROTOCOL_VERSION = 1,
            ADDON_VERSION = "0.1.1-beta", MAX_MESSAGE_BYTES = 240},
        Privacy = {CanBroadcast = function() return true end, CanInteract = function() return true end},
        Presence = {NormalizeCharacterKey = function(_, value) return value end},
        Debug = function() end,
    }
    local api = {
        RegisterAddonMessagePrefix = function(prefix) Check(prefix, "FOREVERRP"); return result end,
        SendAddonMessage = function(prefix, payload, channel)
            Check(prefix, "FOREVERRP")
            Check(payload, "HELLO|1|0.1.1-beta")
            Check(channel, "PARTY")
            calls = calls + 1
            return result
        end,
    }
    if query ~= nil then
        api.IsAddonMessagePrefixRegistered = function() return query end
    end
    if legacy then
        RegisterAddonMessagePrefix = api.RegisterAddonMessagePrefix
        SendAddonMessage = api.SendAddonMessage
        IsAddonMessagePrefixRegistered = api.IsAddonMessagePrefixRegistered
    else
        C_ChatInfo = api
    end
    dofile("ForeverRP/Discovery/Communication.lua")
    return ForeverRP.Communication, function() return calls end
end

for _, legacy in ipairs({false, true}) do
    for _, result in ipairs({true, false, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 99, "0", {}}) do
        local comm = Fixture(result, legacy)
        Check(comm:Initialize(), result == true or result == 0)
        -- Isolate the send contract from registration failures.
        comm.prefixRegistered = true
        local accepted, reason = comm:Send("HELLO", "PARTY")
        Check(accepted, result == true or result == 0)
        Check(reason, accepted and "accepted" or ((result == 3 or result == 8) and "throttled" or "failed"))
    end
    local comm = Fixture(1, legacy, true)
    Check(comm:Initialize(), true) -- Already registered, duplicate result.
    comm = Fixture(0, legacy, false)
    Check(comm:Initialize(), false) -- Query is authoritative.
    comm = Fixture(nil, legacy)
    Check(comm:Initialize(), false)
    comm.prefixRegistered = true
    Check(comm:Send("HELLO", "PARTY"), false)
end

local comm, calls = Fixture(0)
comm:Initialize()
ForeverRP.Privacy.CanBroadcast = function() return false end
ForeverRP.Privacy.CanInteract = function() return false end
Check(comm:Send("HELLO", "PARTY"), false)
Check(comm:Send("ACK", "WHISPER", "Other-Realm"), false)
Check(calls(), 0)

-- Compile every imported runtime module without executing UI or game APIs.
local modules = 0
for line in io.lines("ForeverRP/ForeverRP.toc") do
    line = line:gsub("\r", "")
    if line:match("%.lua$") then
        assert(loadfile("ForeverRP/" .. line:gsub("\\", "/")))
        modules = modules + 1
    end
end
print(string.format("PASS: %d communication checks; %d runtime modules compile", checks, modules))
