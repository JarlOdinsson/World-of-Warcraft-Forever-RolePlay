local Fixture = dofile("tests/helpers/client_fixture.lua")
local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function Setup()
    local f = Fixture()
    GetBuildInfo = function() return "1.60.1", "69913", "", 16001 end
    IsInInstance = function() return f.instanced == true end
    UnitGUID = function(unit) f.guidCalls = (f.guidCalls or 0) + 1; return f.guid end
    dofile("experiments/beta17/Discovery/LayerEvidence.lua")
    ForeverRP.Database:SetActivitySetting("enabled", true)
    ForeverRP.Database:SetActivitySetting("directory", true)
    ForeverRP.Database:SetActivitySetting("location", "zone")
    return f, ForeverRP.LayerEvidence, ForeverRP.Activity, ForeverRP.Database
end
local function Test(name, run) run(Setup()); cases = cases + 1; print("PASS " .. name) end
local function Observe(f, e, count, scope)
    for i = 1, count do
        f.guid = "Creature-0-1465-0-" .. (scope or 2105) .. "-448-000043F59" .. i
        Check(e:Observe("target"), true)
    end
end
local base = "A2|v|0|public|10|-|-|-|1|IC|NORMAL|0|"
local layer = "L1|10|1465:0:2105|3|0|123:3"

Test("distinct agreeing creatures required; duplicates, pets and inaccessible values ignored", function(f, e)
    Observe(f, e, 1); Check(e:GetLocal(), nil)
    Check(e:Observe("target"), false); Check(#e.samples, 1)
    f.guid = "Creature-0-1465-0-2105-449-000043F592"; Check(e:Observe("mouseover"), true)
    Check(e:GetLocal(), nil)
    f.guid = "Creature-0-1465-0-2105-450-000043F593"; Check(e:Observe("nameplate1"), true)
    Check(e:GetLocal().id, "1465:0:2105"); Check(e:GetLocal().zone, 10)
    local calls = f.guidCalls
    Check(e:Observe(f.secret), false); Check(f.guidCalls, calls)
    Check(e:Observe("party1"), false); Check(f.guidCalls, calls)
    for _, guid in ipairs({f.secret, "Player-1465-123", "Pet-0-1465-0-2105-448-123",
        "Vehicle-0-1465-0-2105-448-123", "Creature-0-9999999999-0-2105-448-1", "Creature-0-1465-0-0-448-1"}) do
        f.guid = guid; Check(e:Observe("target"), false)
    end
    f.guid = nil; Check(e:Observe("target"), false)
    Check(#e.samples, 3)
end)
Test("conflicts, zone changes, transfer and stale observations reset confidence with bounded storage", function(f, e)
    Observe(f, e, 3); Check(e:GetLocal() ~= nil, true)
    f.guid = "Creature-0-1465-0-9999-448-123"; Check(e:Observe("target"), true)
    Check(e:GetLocal(), nil)
    for i = 1, 30 do f.guid = "Creature-0-1465-0-2105-448-" .. i; e:Observe("target") end
    Check(#e.samples, 8); Check(e:GetLocal().count, 8)
    f.zone = 11; Check(e:GetLocal(), nil); Check(#e.samples, 0)
    Observe(f, e, 3); e:Suspend(); Check(e:GetLocal(), nil); Check(e:Observe("target"), false)
    e:Reset(); Observe(f, e, 3)
    f.now = 220; Check(e:GetLocal(), nil)
    Observe(f, e, 3); f.instanced = true; Check(e:GetLocal(), nil)
    f.instanced = false; GetBuildInfo = function() return "", "", "", 11509 end
    Check(e:Observe("target"), false)
end)
Test("sharing requires network, location, participation and non-DND; comparable identifiers are inferred", function(f, e, a, db)
    Observe(f, e, 3); Check(e:Payload():match("^L1|10|1465:0:2105|3|0|") ~= nil, true)
    for _, setting in ipairs({{"location", "hidden"}, {"directory", false}, {"enabled", false}}) do
        local old = db:GetActivitySettings()[setting[1]]
        db:SetActivitySetting(setting[1], setting[2]); Check(e:Payload(), nil)
        db:SetActivitySetting(setting[1], old); e:Reset(); Observe(f, e, 3)
    end
    f.dnd = true; Check(e:Payload(), nil); f.dnd = false
    db:SetPrivacyMode("hidden", true); Check(e:Payload(), nil)
    db:SetPrivacyMode("visible", true); Observe(f, e, 3)
    Check(a:Receive(base, "GUILD", "Peer-Realm"), true)
    Check(a:Receive(layer, "GUILD", "Peer-Realm"), true)
    local result, reason = e:Compare(a:GetPeer("Peer-Realm"))
    Check(result, "SAME"); Check(reason, "inferred-unvalidated")
    Check(a:Receive("L1|10|1465:0:2106|3|0|123:4", "GUILD", "Peer-Realm"), true)
    result, reason = e:Compare(a:GetPeer("Peer-Realm"))
    Check(result, "DIFFERENT"); Check(reason, "inferred-unvalidated")
    Check(a:Receive("L1|10|1465:1:2105|3|0|123:5", "GUILD", "Peer-Realm"), true)
    Check(e:Compare(a:GetPeer("Peer-Realm")), "UNKNOWN")
    Check(a:Receive("L1|10|1466:0:2105|3|0|123:6", "GUILD", "Peer-Realm"), true)
    Check(e:Compare(a:GetPeer("Peer-Realm")), "DIFFERENT")
    f.zone = 11; Check(e:Compare(a:GetPeer("Peer-Realm")), "UNKNOWN")
end)
Test("optional layer metadata cannot create presence or renew coordinate/evidence clocks", function(f, e, a)
    Check(a:Receive(layer, "GUILD", "Peer-Realm"), false)
    Check(a:GetPeer("Peer-Realm"), nil)
    Check(a:Receive(base, "GUILD", "Peer-Realm"), true)
    local entry = a:GetPeer("Peer-Realm")
    Check(a:Receive(layer, "GUILD", "Peer-Realm"), true)
    Check(entry.at, 100); Check(entry.layerEvidence.at, 100)
    f.now = 160; Check(a:Receive(layer, "GUILD", "Peer-Realm"), false)
    Check(entry.at, 100); Check(entry.layerEvidence.at, 100)
    f:Peer(); Check(a:GetPeer("Peer-Realm").layerEvidence.at, 100)
    Check(a:Receive(base, "GUILD", "Peer-Realm"), true)
    entry = a:GetPeer("Peer-Realm"); Check(entry.layerEvidence.at, 100)
    f.now = 220; Check(e:GetRemote(entry), nil)
    Check(a:Receive("L1|10|1465:0:2105|3|0|123:4", "GUILD", "Peer-Realm"), true)
    Check(e:GetRemote(entry).at, 220) -- newly observed creatures may renew confidence
    for _, invalid in ipairs({"L1|11|1465:0:2105|3|0|123:4", "L1|10|1465:0:2105|2|0|123:4",
        "L1|10|1465:0:2105|9|0|123:4", "L1|10|1465:0:2105|3|120|123:4", "L1|10|bad|3|0|123:4"}) do
        Check(a:Receive(invalid, "GUILD", "Peer-Realm"), false)
    end
    Check(a:Receive("A2|v|0|public|0|-|-|-|1|IC|NORMAL|0|", "GUILD", "Peer-Realm"), true)
    Check(a:GetPeer("Peer-Realm").layerEvidence, nil)
    Check(a:Receive(layer, "GUILD", "Peer-Realm"), false)
end)
Test("companion uses existing bounded queue, channel, budget and retry policy", function(f, e, a, db)
    Observe(f, e, 3); a:Initialize(); a:Tick()
    Check(#a.queue, 1); Check(a.queue[1].legacyPending, true)
    Check(f.sent[1].payload:sub(1, 3), "A3|"); Check(f.sent[1].prefix, a.prefix)
    f.now = 101; a:Tick()
    Check(f.sent[2].payload:sub(1, 3), "A2|")
    f.now = 102; a:Tick()
    Check(f.sent[3].payload:sub(1, 3), "L1|"); Check(#a.queue, 0)
    Check(f.sent[2].channel, f.sent[1].channel)
    -- Rebuild pending evidence at send time: withholding must cancel it.
    a.queue = {{route = {channel = "CHANNEL", target = 7}, attempts = 0, layerPending = true}}
    db:GetActivitySettings().directory = false
    f.now = 103; a:Tick(); Check(#a.queue, 0); Check(#f.sent, 3)
    db:GetActivitySettings().directory = true
    a.queue = {{route = {channel = "CHANNEL", target = 7}, attempts = 0, layerPending = true}}
    a.retryAt = 103
    f.result, f.now = 3, 103; a:Tick(); Check(#a.queue, 1)
    f.now = 113; a:Tick(); Check(#a.queue, 0); Check(#f.sent, 5)
end)
Test("real observation and optional transfer event handlers reset without touching discovery", function(f, e)
    CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
    dofile("experiments/beta17/Core/Events.lua")
    local detected = 0
    ForeverRP.PlayerDetection = {RefreshUnit = function() detected = detected + 1 end,
        DetectUnit = function() detected = detected + 1 end}
    f.guid = "Creature-0-1465-0-2105-448-1"
    ForeverRP.Events.handlers.PLAYER_TARGET_CHANGED()
    f.guid = "Creature-0-1465-0-2105-448-2"
    ForeverRP.Events.handlers.UPDATE_MOUSEOVER_UNIT()
    f.guid = "Creature-0-1465-0-2105-448-3"
    ForeverRP.Events.handlers.NAME_PLATE_UNIT_ADDED("nameplate1")
    Check(detected, 3); Check(e:GetLocal().count, 3)
    ForeverRP.Events.handlers.SHARD_TRANSFER_IMMINENT(); Check(e:GetLocal(), nil)
    ForeverRP.Events.handlers.SHARD_TRANSFER(); Check(e.suspended, false)
    Observe(f, e, 3)
    ForeverRP.Events.handlers.ZONE_CHANGED_NEW_AREA(); Check(e:GetLocal(), nil)
end)
Test("Directory renders inferred labels, updates on expiry, and never grants Nearby admission", function(f, e, a)
    local Widget = {}; Widget.__index = function(_, key) return Widget[key] or function() end end
    function Widget:CreateFontString() return setmetatable({}, Widget) end
    function Widget:SetText(value) self.text = value end
    function Widget:IsShown() return self.shown ~= false end
    function Widget:Show() self.shown = true end
    function Widget:Hide() self.shown = false end
    function Widget:SetScript(event, run) self[event] = run end
    CreateFrame = function() return setmetatable({}, Widget) end
    UIDropDownMenu_Initialize = function() end
    UIDropDownMenu_SetWidth = function() end
    UIDropDownMenu_SetText = function() end
    dofile("ForeverRP/UI/Activity.lua")
    ForeverRP.PlayerDetection = {GetUnits = function() return {} end}
    dofile("ForeverRP/Discovery/NearbyPlayers.lua")
    local alerts = 0
    ForeverRP.Notifications = {OnNearbyEntered = function() alerts = alerts + 1 end}
    Observe(f, e, 3); Check(a:Receive(base, "GUILD", "Peer-Realm"), true)
    Check(a:Receive(layer, "GUILD", "Peer-Realm"), true)
    local ui = ForeverRP.ActivityUI; ui:Create({})
    Check(ui.rows[1].detail.text, "IC | Same layer — inferred")
    Check(ui.rows[1].layerID.text, "Inferred ID: zone 10 / 1465:0:2105")
    Check(a:Receive("L1|10|1465:0:2106|3|0|123:4", "GUILD", "Peer-Realm"), true)
    ui:RefreshLayers(); Check(ui.rows[1].detail.text, "IC | Different layer — inferred")
    Check(#a:QueryDirectory(), 1); Check(ForeverRP.NearbyPlayers:IsNearby("Peer-Realm"), false)
    Check(alerts, 0)
    Check(#f.sent, 0)
    f.now = 220; ui:RefreshLayers(); Check(ui.rows[1].detail.text, "IC | Layer unknown")
    Check(ui.rows[1].layerID.text, "")
    f.now = 221; Observe(f, e, 3)
    Check(a:Receive("L1|10|1465:0:2105|3|0|123:5", "GUILD", "Peer-Realm"), true)
    ui:RefreshLayers(); Check(ui.rows[1].detail.text, "IC | Same layer — inferred")
    Check(a:Receive("L1|OFF", "GUILD", "Peer-Realm"), true)
    ui:RefreshLayers(); Check(ui.rows[1].detail.text, "IC | Layer unknown")
end)
if arg and arg[1] then
    Test("actual older Directory parser keeps base packet and safely ignores companion", function(f, e, a)
        Observe(f, e, 3)
        local payload, companion = a:Payload(), e:Payload()
        dofile(arg[1] .. "/Discovery/Activity.lua")
        local legacy = ForeverRP.Activity
        Check(legacy:Receive(payload, "GUILD", "Peer-Realm"), true)
        Check(legacy:Receive(companion, "GUILD", "Peer-Realm"), false)
        Check(#legacy:QueryDirectory({status = "ALL"}), 1)
        Check(legacy:GetPeer("Peer-Realm").zone, 10)
    end)
end
print("PASS: " .. cases .. " layer evidence cases; " .. checks .. " checks (no live layer validation)")
