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

local function Fixture()
    local f = {now = 0, requested = {}, privacy = true, localKey = "Local-Realm"}
    GetTime = function() return f.now end
    ForeverRP = {}
    dofile("ForeverRP/Core/Constants.lua")
    ForeverRP.ValueAccess = {IsString = function(_, value) return type(value) == "string" end}
    ForeverRP.Presence = {
        NormalizeCharacterKey = function(_, value) return value end,
        IsSelf = function(_, value) return value == f.localKey end,
    }
    ForeverRP.Privacy = {CanInteract = function() return f.privacy end}
    ForeverRP.PlayerDetection = {GetCharacterKeys = function() return {"Alice-Realm"} end}
    ForeverRP.Profile = {
        SanitizeRemoteProfile = function(_, profile)
            for _, field in ipairs(ForeverRP.Constants.PROFILE_FIELD_ORDER) do
                if type(profile[field]) ~= "string" then return nil end
            end
            return profile
        end,
    }
    ForeverRP.ProfileViewer = {ShowMSP = function(_, key) f.opened = key; return true end}
    ForeverRP.RemoteProfiles = {StoreProfile = function() error("MSP must not write ForeverRP remote profiles") end}
    msp = {
        char = {},
        callback = {received = {}},
        Request = function(_, name)
            f.requested[#f.requested + 1] = name
            return 1
        end,
    }
    dofile("ForeverRP/Discovery/MSPCompatibility.lua")
    f.msp = ForeverRP.MSPCompatibility
    f.msp:Initialize()
    return f
end

Test("target and mouseover request MSP without ForeverRP presence", function()
    local f = Fixture()
    Check(f.msp:ObserveUnit("target", "Alice-Realm", "target"), true)
    Check(#f.requested, 1)
    Check(f.msp:ObserveUnit("mouseover", "Alice-Realm", "mouseover"), false)
    Check(f.msp:ObserveUnit("party1", "Alice-Realm", "group"), false)
end)

Test("privacy and local identity prevent MSP requests", function()
    local f = Fixture()
    f.privacy = false
    Check(f.msp:ObserveUnit("target", "Alice-Realm", "target"), false)
    f.privacy = true
    Check(f.msp:ObserveUnit("target", "Local-Realm", "target"), false)
    Check(#f.requested, 0)
end)

Test("received MSP data is validated, isolated, and opened in the existing viewer", function()
    local f = Fixture()
    msp.char["Alice-Realm"] = {field = {
        NA = "Alice", NT = "the Ranger", RA = "Human", FC = "Rogue", CU = "Watching the road",
    }}
    Check(f.msp:OnReceived("Alice-Realm"), true)
    local entry = f.msp:GetProfile("Alice-Realm")
    Check(entry.source, "MSP")
    Check(entry.profile.rpName, "Alice")
    Check(entry.profile.status, "OOC")
    Check(f.opened, "Alice-Realm")
end)

Test("malformed MSP fields are rejected and never replace local identity", function()
    local f = Fixture()
    msp.char["Alice-Realm"] = {field = {NA = "Alice\1"}}
    Check(f.msp:OnReceived("Alice-Realm"), false)
    Check(f.msp:HasProfile("Alice-Realm"), false)
    msp.char["Local-Realm"] = {field = {NA = "Local"}}
    Check(f.msp:OnReceived("Local-Realm"), false)
end)

print(string.format("PASS: %d MSP compatibility cases; %d checks", cases, checks))
