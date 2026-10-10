local Fixture = dofile("tests/helpers/client_fixture.lua")
local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function Test(name, run)
    local f = Fixture()
    f.calls, f.blocked, f.combat = 0, 0, false
    InCombatLockdown = function() return f.combat end
    CheckInteractDistance = function(_, index)
        f.calls = f.calls + 1
        if f.combat == true or f.combat == 1 then
            f.blocked = f.blocked + 1 -- models an event independent of Lua error handling
            error("simulated ADDON_ACTION_BLOCKED: CheckInteractDistance")
        end
        return index == 3
    end
    dofile("ForeverRP/Discovery/Range.lua")
    run(f); cases = cases + 1; print("PASS " .. name)
end
Test("combat lockdown prevents every interaction API invocation", function(f)
    f.combat = true
    for _, unit in ipairs({"mouseover", "target", "focus", "nameplate1", "party1"}) do
        Check(ForeverRP.Range:GetRangeState(unit), "UNKNOWN")
        for _, radius in ipairs({10, 15, 20, 25, 30}) do
            local within, state = ForeverRP.Range:IsWithin(unit, radius)
            Check(within, false); Check(state, "UNKNOWN")
        end
    end
    Check(f.calls, 0); Check(f.blocked, 0)
end)
Test("missing and inaccessible lockdown evidence fail closed", function(f)
    for _, value in ipairs({f.secret, true, 1, 0, "false", {}, 99}) do
        InCombatLockdown = function() return value end
        Check(ForeverRP.Range:GetRangeState("target"), "UNKNOWN")
    end
    InCombatLockdown = function() return nil end
    Check(ForeverRP.Range:GetRangeState("target"), "UNKNOWN")
    InCombatLockdown = nil
    Check(ForeverRP.Range:GetRangeState("target"), "UNKNOWN")
    Check(f.calls, 0); Check(f.blocked, 0)
end)
Test("documented out-of-combat state retains bool and numeric interaction evidence", function(f)
    Check(ForeverRP.Range:GetRangeState("target"), "WITHIN_10")
    Check(f.calls, 1)
    CheckInteractDistance = function(_, index) f.calls = f.calls + 1; return index == 2 and 1 or 0 end
    Check(ForeverRP.Range:GetRangeState("target"), "WITHIN_15")
    CheckInteractDistance = function(_, index) return index == 1 end
    Check(ForeverRP.Range:GetRangeState("target"), "WITHIN_30")
    Check(f.blocked, 0)
end)
Test("lockdown is rechecked before later bracket calls", function(f)
    CheckInteractDistance = function()
        f.calls = f.calls + 1
        if f.combat then f.blocked = f.blocked + 1; error("forbidden call") end
        f.combat = true
        return false
    end
    Check(ForeverRP.Range:GetRangeState("target"), "UNKNOWN")
    Check(f.calls, 1); Check(f.blocked, 0)
end)
Test("missing inaccessible and unrecognized range returns remain unknown", function(f)
    CheckInteractDistance = nil
    Check(ForeverRP.Range:GetRangeState("target"), "UNKNOWN")
    for _, value in ipairs({f.secret, "yes", {}, 7}) do
        CheckInteractDistance = function() return value end
        Check(ForeverRP.Range:GetRangeState("target"), "UNKNOWN")
        Check(ForeverRP.Range:IsWithin("target", 30), false)
    end
    CheckInteractDistance = function() return nil end
    Check(ForeverRP.Range:GetRangeState("target"), "UNKNOWN")
    Check(f.blocked, 0)
end)
Test("a coarse group range or coordinates never substitute for blocked proximity", function(f)
    f.combat = true
    UnitInRange = function() error("40-yard group evidence cannot establish <=30") end
    UnitDistanceSquared = function() error("unverified restricted distance fallback") end
    UnitPosition = function() error("do not reconstruct protected distance") end
    Check(ForeverRP.Range:GetRangeState("party1"), "UNKNOWN")
    Check(f.calls, 0); Check(f.blocked, 0)
end)
Test("inaccessible units disappearing units and NPCs never reach interaction API", function(f)
    Check(ForeverRP.Range:GetRangeState(f.secret), "UNKNOWN")
    UnitExists = function() return false end
    Check(ForeverRP.Range:GetRangeState("target"), "UNKNOWN")
    UnitExists = function() return true end
    UnitIsPlayer = function() return false end
    Check(ForeverRP.Range:GetRangeState("mouseover"), "UNKNOWN")
    Check(f.calls, 0)
end)
Test("simulation remains isolated and does not call restricted real APIs", function(f)
    f.combat = true
    local a = ForeverRP
    Check(a.Range:SetSimulatedState("Sim-Realm", "30"), true)
    Check(a.Range:GetRangeState("simulated", "Sim-Realm"), "WITHIN_30")
    Check(a.Range:IsWithin("simulated", 30, "Sim-Realm"), true)
    Check(a.Range:GetRangeState("target", "Real-Realm"), "UNKNOWN")
    Check(f.calls, 0); Check(f.blocked, 0)
end)
Test("reported real mouseover path is safe; Nearby recovers after combat via existing ticker", function(f)
    local a = ForeverRP
    f.combat = true
    UnitExists = function(unit) return unit == "player" or unit == "mouseover" end
    UnitIsPlayer = UnitExists
    UnitFullName = function(unit)
        if unit == "player" then return "Local", "Realm" end
        return "Linea", "Aspera"
    end
    GetUnitName = function(unit) return unit == "player" and "Local-Realm" or "Linea Aspera" end
    dofile("ForeverRP/Discovery/PlayerDetection.lua")
    dofile("ForeverRP/Discovery/ObservedDiscovery.lua")
    dofile("ForeverRP/Discovery/NearbyPlayers.lua")
    local entries = 0
    a.Notifications = {OnNearbyEntered = function() entries = entries + 1 end, OnNearbyLeft = function() end}
    C_Timer.NewTicker = function(_, run) f.tick = run; return {} end
    CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
    dofile("ForeverRP/Core/Events.lua")
    a.NearbyPlayers:Initialize()
    a.Events.handlers.UPDATE_MOUSEOVER_UNIT()
    Check(f.calls, 0); Check(f.blocked, 0)
    Check(f.sent[1].payload:match("^HELLO|"), "HELLO|") -- UNKNOWN doesn't disable directed discovery
    local peer = "Linea Aspera-Realm"
    a.Communication:HandleIncoming("FOREVERRP", "ACK|1|v", "WHISPER", peer, false)
    Check(a.Presence:IsConfirmed(peer, false), true)
    Check(a.NearbyPlayers:IsNearby(peer, false), false); Check(entries, 0)
    f.now = 101; f.tick(); Check(a.NearbyPlayers:IsNearby(peer, false), false)
    Check(f.blocked, 0)
    f.combat = false; f.now = 102; f.tick()
    Check(a.NearbyPlayers:IsNearby(peer, false), true); Check(entries, 1)
    f.combat = true; f.now = 103; f.tick()
    Check(a.NearbyPlayers:IsNearby(peer, false), false); Check(f.blocked, 0)
    -- Directory is independent of combat range; privacy/location opt-ins unchanged.
    a.Database:SetActivitySetting("enabled", true)
    Check(a.Activity:Receive("A2|v|0|public|0|-|-|-|1|IC|NORMAL|0|", "CHANNEL", "Remote-Realm"), true)
    Check(#a.Activity:QueryDirectory(), 1)
    Check(a.Activity:GetPeer("Remote-Realm").layer, "UNKNOWN")
    Check(a.NearbyPlayers:IsNearby("Remote-Realm", false), false)
    Check(a.Database:GetActivitySettings().location, "hidden")
    Check(a.Database:GetActivitySettings().directory, false)
    Check(f.blocked, 0)
end)
print(string.format("PASS: %d restricted range cases; %d checks (no client taint engine)", cases, checks))
