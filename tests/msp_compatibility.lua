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
    f.account = {}
    ForeverRP.Database = {IsDiscoveryEnabled = function() return true end, GetAccount = function() return f.account end}
    ForeverRP.PlayerDetection = {units = {
        target = {characterKey = "Alice-Realm", transportRecipient = "Alice-Realm"},
        mouseover = {characterKey = "Alice-Realm", transportRecipient = "Alice-Realm"},
    }, IsValid = function() return true end,
        GetCharacterKeys = function() return {"Alice-Realm"} end}
    ForeverRP.Profile = {
        SanitizeRemoteProfile = function(_, profile)
            for _, field in ipairs(ForeverRP.Constants.PROFILE_FIELD_ORDER) do
                if type(profile[field]) ~= "string" then return nil end
            end
            return profile
        end,
    }
    ForeverRP.ProfileViewer = {ShowMSP = function(_, key) f.opened = key; return true end,
        Refresh = function() end}
    ForeverRP.RemoteProfiles = {HasProfile = function() return false end,
        StoreProfile = function() error("MSP must not write ForeverRP remote profiles") end}
    msp = {
        char = {},
        callback = {received = {}},
        Request = function(_, name)
            f.requested[#f.requested + 1] = name
            return 1
        end,
        RequestObserved = function(self, name, recipient, validate)
            f.validate = validate
            if not validate() then return false end
            Check(recipient, "Alice-Realm")
            return self:Request(name)
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

Test("shared MSP without cancellable transport never falls back to an unsafe probe", function()
    local f = Fixture()
    msp.RequestObserved = nil
    local accepted, reason = f.msp:ObserveUnit("target", "Alice-Realm", "target")
    Check(accepted, false); Check(reason, "safe-transport-unavailable"); Check(#f.requested, 0)
end)

Test("diagnostic toggle isolates integration, cancels queued validation and survives reload", function()
    local f = Fixture()
    local shared = msp
    Check(f.msp:ObserveUnit("target", "Alice-Realm", "target"), true)
    f.msp:SetEnabled(false)
    Check(f.validate(), false)
    Check(f.account.diagnosticMSPDisabled, true)
    Check(f.msp:IsEnabled(), false)
    Check(f.msp:ObserveUnit("target", "Alice-Realm", "target"), false)
    msp.char["Alice-Realm"] = {field = {NA = "External Alice"}}
    Check(f.msp:OnReceived("Alice-Realm"), false)
    Check(f.msp:GetProfile("Alice-Realm"), nil)
    Check(f.opened, nil); Check(msp, shared)
    dofile("ForeverRP/Discovery/MSPCompatibility.lua")
    Check(ForeverRP.MSPCompatibility:IsEnabled(), false)
    ForeverRP.MSPCompatibility:SetEnabled(true)
    Check(f.account.diagnosticMSPDisabled, nil)
    Check(ForeverRP.MSPCompatibility:IsEnabled(), true)
    Check(ForeverRP.MSPCompatibility:OnReceived("Alice-Realm"), true)
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
