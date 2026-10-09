-- Run from the repository root with Lua 5.1 or LuaJIT.
local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end

local function Test(name, callback)
    callback()
    cases = cases + 1
    print("PASS " .. name)
end

local function Profile()
    local profile = {}
    for _, field in ipairs(ForeverRP.Constants.PROFILE_FIELD_ORDER) do
        profile[field] = ""
    end
    profile.rpName, profile.status = "Alice", "IC"
    profile.history = string.rep("x", 300)
    return profile
end

local function TransferFixture()
    local f = {now = 0, sent = {}, timers = {}, allowed = true}
    GetTime = function() return f.now end
    C_Timer = {After = function(_, callback) f.timers[#f.timers + 1] = callback end}
    ForeverRP = {}
    dofile("ForeverRP/Core/Constants.lua")
    ForeverRP.Debug = function() end
    ForeverRP.Database = {GetPrivacyMode = function() return "visible" end}
    ForeverRP.Privacy = {CanInteract = function() return f.allowed end}
    ForeverRP.Presence = {
        ResolveKnownKey = function(_, value) return value end,
        IsSelf = function() return false end,
    }
    ForeverRP.Communication = {
        Serialize = function(_, kind, messageId, index, total, chunk)
            return table.concat({kind, messageId, index, total, chunk}, "|")
        end,
        SendPayload = function(_, payload, channel, target)
            f.sent[#f.sent + 1] = {payload = payload, channel = channel, target = target}
            return table.remove(f.results or {}, 1) ~= false
        end,
    }
    ForeverRP.Profile = {
        Get = Profile,
        SanitizeRemoteProfile = function(_, profile)
            local copy = {}
            for _, field in ipairs(ForeverRP.Constants.PROFILE_FIELD_ORDER) do
                if type(profile[field]) ~= "string" then return nil end
                copy[field] = profile[field]
            end
            return copy
        end,
    }
    dofile("ForeverRP/Discovery/ProfileTransfer.lua")
    f.transfer = ForeverRP.ProfileTransfer
    function f:RunTimers()
        while #self.timers > 0 do
            local callback = table.remove(self.timers, 1)
            callback()
        end
    end
    return f
end

Test("local identity accepts every client-reported local realm form without aliases", function()
    GetTime = function() return 0 end
    UnitFullName = function() return "Pokerus", "Foreverrp" end
    UnitName = function() return "Pokerus", nil end
    GetUnitName = function() return "Pokerus" end
    GetNormalizedRealmName = function() return "ForeverRP-ClassicBetaPvE" end
    GetRealmName = function() return "ForeverRP-ClassicBetaPvE" end
    ForeverRP = {Constants = {PRESENCE_EXPIRY_SECONDS = 900, PRESENCE_CACHE_MAX = 10}, ValueAccess = {}}
    dofile("ForeverRP/Core/ValueAccess.lua")
    ForeverRP.NearbyPlayers = {Reevaluate = function() end, Remove = function() end}
    dofile("ForeverRP/Discovery/Presence.lua")
    Check(ForeverRP.Presence:IsSelf("Pokerus-ForeverRPClassicBetaPvE"), true)
    Check(ForeverRP.Presence:Update("Pokerus-ForeverRPClassicBetaPvE", {addonVersion = "x", protocolVersion = 1}), false)
end)

Test("profile response queues chunks, suppresses duplicates, and applies cooldown", function()
    local f = TransferFixture()
    local encoded = f.transfer:SerializeProfile(Profile())
    local chunks = f.transfer:BuildChunks(encoded)
    Check(#chunks > 1, true)
    Check(f.transfer:SendProfile("Alice-Realm", "one"), true)
    Check(f.transfer:SendProfile("Alice-Realm", "two"), false)
    f:RunTimers()
    Check(#f.sent, #chunks)
    Check(f.transfer:SendProfile("Alice-Realm", "three"), false)
    f.now = ForeverRP.Constants.PROFILE_RESPONSE_PEER_COOLDOWN_SECONDS
    Check(f.transfer:SendProfile("Alice-Realm", "three"), true)
end)

Test("failed profile chunks retry a bounded number of times and clear the response", function()
    local f = TransferFixture()
    f.results = {false, false, false}
    Check(f.transfer:SendProfile("Alice-Realm", "one"), true)
    f:RunTimers()
    Check(#f.sent, 3)
    Check(next(f.transfer.outgoingResponses), nil)
end)

Test("privacy changes cancel queued responses and duplicate requests are rejected", function()
    local f = TransferFixture()
    Check(f.transfer:SendProfile("Alice-Realm", "one"), true)
    f.allowed = false
    Check(f.transfer:CancelDisallowedResponses(), 1)
    f:RunTimers()
    Check(#f.sent, 0)
    f.allowed = true
    Check(f.transfer:Request("Alice-Realm"), true)
    Check(f.transfer:Request("Alice-Realm"), false)
end)

Test("remote profile and presence caches evict the oldest entry predictably", function()
    GetTime = function() return 0 end
    ForeverRP = {}
    dofile("ForeverRP/Core/Constants.lua")
    ForeverRP.Constants.REMOTE_PROFILE_CACHE_MAX = 2
    ForeverRP.Profile = {SanitizeRemoteProfile = function(_, profile) return profile end}
    ForeverRP.Presence = {IsSelf = function() return false end}
    ForeverRP.Connections = {CacheRPName = function() end}
    ForeverRP.NearbyUI = {Refresh = function() end}
    dofile("ForeverRP/Profile/RemoteProfiles.lua")
    ForeverRP.RemoteProfiles:StoreProfile("A-Realm", Profile(), {})
    GetTime = function() return 1 end
    ForeverRP.RemoteProfiles:StoreProfile("B-Realm", Profile(), {})
    GetTime = function() return 2 end
    ForeverRP.RemoteProfiles:StoreProfile("C-Realm", Profile(), {})
    Check(ForeverRP.RemoteProfiles:GetProfile("A-Realm"), nil)
    Check(ForeverRP.RemoteProfiles:HasProfile("C-Realm"), true)
end)

print(string.format("PASS: %d audit-fix cases; %d checks", cases, checks))
