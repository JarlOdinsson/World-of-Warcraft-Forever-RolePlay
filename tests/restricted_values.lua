-- Run from the repository root with Lua 5.1 or LuaJIT.
local checks, cases = 0, 0

local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end

local function Fixture()
    local f = {
        inaccessible = {},
        units = {
            player = {exists = true, player = true, name = "Self", realm = "Realm"},
            target = {exists = true, player = true, name = "Alice", realm = "Realm"},
            mouseover = {exists = true, player = false, name = "Guard", realm = "Realm"},
            focus = {exists = true, player = true, name = "Focus", realm = "Realm"},
            nameplate1 = {exists = true, player = true, name = "Nameplate", realm = "Realm"},
            party1 = {exists = true, player = true, name = "Party", realm = "Realm"},
        },
        range = {},
        calls = {exists = 0, player = 0, fullName = 0, range = 0},
    }

    ForeverRP = {}
    CreateFrame = function()
        local frame = {registered = {}, scripts = {}}
        function frame:RegisterEvent(event) self.registered[event] = true end
        function frame:UnregisterEvent(event) self.registered[event] = nil end
        function frame:SetScript(event, handler) self.scripts[event] = handler end
        return frame
    end
    InCombatLockdown = function() return false end
    GetTime = function() return 100 end
    GetNormalizedRealmName = function() return "Realm" end
    IsInRaid = function() return false end
    GetNumGroupMembers = function() return 1 end
    canaccessallvalues = function(...)
        for index = 1, select("#", ...) do
            local value = select(index, ...)
            if value ~= nil and f.inaccessible[value] then
                return false
            end
        end
        return true
    end
    UnitExists = function(unit)
        f.calls.exists = f.calls.exists + 1
        assert(not f.inaccessible[unit], "UnitExists received inaccessible value")
        return f.units[unit] and f.units[unit].exists or false
    end
    UnitIsPlayer = function(unit)
        f.calls.player = f.calls.player + 1
        assert(not f.inaccessible[unit], "UnitIsPlayer received inaccessible value")
        return f.units[unit] and f.units[unit].player or false
    end
    UnitFullName = function(unit)
        f.calls.fullName = f.calls.fullName + 1
        assert(not f.inaccessible[unit], "UnitFullName received inaccessible value")
        local data = f.units[unit]
        if not data then
            return nil, nil
        end
        return data.name, data.realm
    end
    UnitName = function(unit)
        assert(not f.inaccessible[unit], "UnitName received inaccessible value")
        local data = f.units[unit]
        return data and data.name, data and data.realm
    end
    CheckInteractDistance = function(unit, index)
        f.calls.range = f.calls.range + 1
        assert(not f.inaccessible[unit], "CheckInteractDistance received inaccessible value")
        return f.range[unit] and f.range[unit][index] or false
    end

    dofile("ForeverRP/Core/Constants.lua")
    ForeverRP.GetText = function(_, key) return key end
    ForeverRP.Debug = function() end
    ForeverRP.Database = {
        GetAccount = function() return {} end,
        IsDiscoveryEnabled = function() return true end,
        IsDebugEnabled = function() return true end,
        GetDiscoveryRadius = function() return 30 end,
    }
    ForeverRP.Privacy = {CanDisplay = function() return true end}
    ForeverRP.RemoteProfiles = {GetProfile = function() return nil end}
    ForeverRP.Notifications = nil
    ForeverRP.Connections = nil
    ForeverRP.NearbyUI = nil
    dofile("ForeverRP/Core/ValueAccess.lua")
    dofile("ForeverRP/Discovery/Presence.lua")
    dofile("ForeverRP/Discovery/Range.lua")
    dofile("ForeverRP/Discovery/NearbyPlayers.lua")
    dofile("ForeverRP/Discovery/PlayerDetection.lua")
    dofile("ForeverRP/UI/PlayerTooltip.lua")
    dofile("ForeverRP/Core/Events.lua")
    return f
end

local function Confirm(f, key, simulated)
    return ForeverRP.Presence:Update(key, {
        addonVersion = "0.1.1-beta",
        protocolVersion = 1,
        simulated = simulated == true,
    })
end

local function Test(name, run)
    run(Fixture())
    cases = cases + 1
    print("PASS " .. name)
end

Test("inaccessible tooltip unit is skipped before UnitExists", function(f)
    local unit = {}
    f.inaccessible[unit] = true
    local tooltip = {
        GetUnit = function() return "Hidden", unit end,
        AddLine = function() error("tooltip should not be changed") end,
    }
    ForeverRP.PlayerTooltip:Process(tooltip)
    Check(f.calls.exists, 0)
    Check(f.calls.player, 0)
end)

Test("restricted identity output is skipped before string handling", function(f)
    local secretName = {}
    f.inaccessible[secretName] = true
    f.units.target.name = secretName
    ForeverRP.PlayerDetection:DetectUnit("target", "target")
    Check(#ForeverRP.PlayerDetection:GetUnits("Alice-Realm", true), 0)
end)

Test("normal player tooltip and detection still work", function(f)
    local lines = 0
    local tooltip = {
        GetUnit = function() return "Alice", "target" end,
        AddLine = function() lines = lines + 1 end,
        Show = function() end,
    }
    ForeverRP.PlayerTooltip:Process(tooltip)
    Check(lines, 1)
    ForeverRP.PlayerDetection:DetectUnit("target", "target")
    Check(#ForeverRP.PlayerDetection:GetUnits("Alice-Realm", true), 1)
end)

Test("NPC and disappearing units are not retained", function(f)
    ForeverRP.PlayerDetection:DetectUnit("mouseover", "mouseover")
    Check(#ForeverRP.PlayerDetection:GetUnits("Guard-Realm", true), 0)
    ForeverRP.PlayerDetection:DetectUnit("target", "target")
    f.units.target.exists = false
    ForeverRP.PlayerDetection:RefreshUnit("target", "target")
    Check(#ForeverRP.PlayerDetection:GetUnits("Alice-Realm", true), 0)
end)

Test("nameplate removal ignores inaccessible input and removes normal tokens", function(f)
    ForeverRP.PlayerDetection:DetectUnit("nameplate1", "nameplate")
    Check(#ForeverRP.PlayerDetection:GetUnits("Nameplate-Realm", true), 1)
    local unit = {}
    f.inaccessible[unit] = true
    ForeverRP.Events.handlers.NAME_PLATE_UNIT_REMOVED(unit)
    Check(#ForeverRP.PlayerDetection:GetUnits("Nameplate-Realm", true), 1)
    ForeverRP.Events.handlers.NAME_PLATE_UNIT_REMOVED("nameplate1")
    Check(#ForeverRP.PlayerDetection:GetUnits("Nameplate-Realm", true), 0)
end)

Test("group units and simulated discovery remain available", function(f)
    ForeverRP.PlayerDetection:ScanGroup()
    Check(#ForeverRP.PlayerDetection:GetUnits("Party-Realm", true), 1)
    Check(Confirm(f, "Tester-Realm", true), true)
    Check(ForeverRP.Range:SetSimulatedState("Tester-Realm", "10"), true)
    Check(ForeverRP.PlayerDetection:SetSimulatedCharacter("Tester-Realm"), true)
    Check(ForeverRP.NearbyPlayers:IsNearby("Tester-Realm", true), true)
end)

Test("range stays unknown when input is inaccessible and normal checks still work", function(f)
    local unit = {}
    f.inaccessible[unit] = true
    Check(ForeverRP.Range:GetRangeState(unit, nil), "UNKNOWN")
    Check(f.calls.range, 0)
    local key = {}
    f.inaccessible[key] = true
    Check(ForeverRP.Range:GetRangeState("target", key), "UNKNOWN")
    Check(f.calls.range, 0)
    f.range.target = {[3] = true}
    Check(ForeverRP.Range:GetRangeState("target", "Alice-Realm"), "WITHIN_10")
end)

Test("legacy clients without the secret API retain normal unit behavior", function(f)
    canaccessallvalues = nil
    ForeverRP.PlayerDetection:DetectUnit("focus", "focus")
    Check(#ForeverRP.PlayerDetection:GetUnits("Focus-Realm", true), 1)
end)

print(string.format("PASS: %d restricted-value cases; %d checks", cases, checks))
