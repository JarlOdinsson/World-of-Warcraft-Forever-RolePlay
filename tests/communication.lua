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

local function LifecycleFixture()
    local f = {now = 0, mode = "visible", sent = {}, sendResult = 0}
    C_ChatInfo, Enum = nil, nil
    RegisterAddonMessagePrefix, SendAddonMessage, IsAddonMessagePrefixRegistered = nil, nil, nil
    LE_PARTY_CATEGORY_INSTANCE = 1
    IsInGroup = function(category)
        if category == LE_PARTY_CATEGORY_INSTANCE then
            return f.instance == true
        end
        return f.party == true or f.raid == true or f.instance == true
    end
    IsInRaid = function() return f.raid == true end
    IsInGuild = function() return f.guild == true end
    GetTime = function() return f.now end
    C_Timer = nil
    ForeverRP = {
        Constants = {
            COMMUNICATION_PREFIX = "FOREVERRP",
            PROTOCOL_VERSION = 1,
            ADDON_VERSION = "0.1.1-beta",
            MAX_MESSAGE_BYTES = 240,
            PRESENCE_RENEWAL_SECONDS = 600,
            PRESENCE_RETRY_SECONDS = 60,
            PRESENCE_MAX_RETRIES = 3,
        },
        Database = {GetPrivacyMode = function() return f.mode end},
        Privacy = {
            CanBroadcast = function(_, channel)
                if f.mode == "hidden" then return false end
                return f.mode ~= "restricted" or channel == "GUILD"
            end,
            CanInteract = function() return true end,
        },
        Presence = {NormalizeCharacterKey = function(_, value) return value end},
        Debug = function() end,
    }
    C_ChatInfo = {
        RegisterAddonMessagePrefix = function() return 0 end,
        SendAddonMessage = function(_, payload, channel)
            f.sent[#f.sent + 1] = {payload = payload, channel = channel}
            return f.sendResult
        end,
    }
    dofile("ForeverRP/Discovery/Communication.lua")
    f.comm = ForeverRP.Communication
    Check(f.comm:Initialize(), true)
    return f
end

Test = function(name, run)
    run()
    print("PASS " .. name)
end

Test("startup solo retries on a later group context", function()
    local f = LifecycleFixture()
    Check(f.comm:SendInitialHello(), false)
    Check(f.comm.initialHelloSent, false)
    Check(#f.sent, 0)
    f.party = true
    Check(f.comm:OnBroadcastContextChanged(), true)
    Check(f.comm.initialHelloSent, true)
    Check(#f.sent, 1)
    Check(f.sent[1].channel, "PARTY")
    Check(f.comm:OnBroadcastContextChanged(), false)
    Check(#f.sent, 1)
end)

Test("group and guild changes announce only newly available channels", function()
    local f = LifecycleFixture()
    f.guild = true
    Check(f.comm:SendInitialHello(), true)
    Check(f.sent[1].channel, "GUILD")
    f.party = true
    Check(f.comm:OnBroadcastContextChanged(), true)
    Check(#f.sent, 2)
    Check(f.sent[2].channel, "PARTY")
    f.party = false
    Check(f.comm:OnBroadcastContextChanged(), false)
    Check(#f.sent, 2)
    f.instance = true
    Check(f.comm:OnBroadcastContextChanged(), true)
    Check(#f.sent, 3)
    Check(f.sent[3].channel, "INSTANCE_CHAT")
end)

Test("renewal occurs before expiry and retries are bounded after throttling", function()
    local f = LifecycleFixture()
    f.party = true
    Check(f.comm:SendInitialHello(), true)
    f.now = 599
    Check(f.comm:TickPresenceLifecycle(), false)
    Check(#f.sent, 1)
    f.now = 600
    Check(f.comm:TickPresenceLifecycle(), true)
    Check(#f.sent, 2)
    f.sendResult = 3
    f.now = 1200
    Check(f.comm:TickPresenceLifecycle(), false)
    Check(#f.sent, 3)
    f.now = 1210
    Check(f.comm:TickPresenceLifecycle(), false)
    Check(#f.sent, 3)
    f.now = 1260
    Check(f.comm:TickPresenceLifecycle(), false)
    f.now = 1320
    Check(f.comm:TickPresenceLifecycle(), false)
    Check(#f.sent, 5)
    f.now = 1380
    Check(f.comm:TickPresenceLifecycle(), false)
    Check(#f.sent, 5)
end)

Test("privacy filters lifecycle broadcasts and restores eligible coverage", function()
    local f = LifecycleFixture()
    f.party, f.guild = true, true
    f.mode = "hidden"
    Check(f.comm:SendInitialHello(), false)
    Check(#f.sent, 0)
    f.mode = "restricted"
    Check(f.comm:OnBroadcastContextChanged(), true)
    Check(#f.sent, 1)
    Check(f.sent[1].channel, "GUILD")
    f.mode = "visible"
    local sent = f.comm:SendHello()
    Check(sent, true)
    Check(#f.sent, 3)
    Check(f.sent[2].channel, "PARTY")
    Check(f.sent[3].channel, "GUILD")
end)

Test("initial throttling retries at most three times", function()
    local f = LifecycleFixture()
    f.party, f.sendResult = true, 3
    Check(f.comm:SendInitialHello(), false)
    Check(#f.sent, 1)
    f.now = 60
    Check(f.comm:TickPresenceLifecycle(), false)
    f.now = 120
    Check(f.comm:TickPresenceLifecycle(), false)
    f.now = 180
    Check(f.comm:TickPresenceLifecycle(), false)
    Check(#f.sent, 3)
end)

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
