local Fixture = dofile("tests/helpers/phase1_fixture.lua")
local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function Test(name, run)
    run(Fixture()); cases = cases + 1; print("PASS " .. name)
end
local function NoExperimentalTraffic(f)
    Check(f.registrations.FOREVERRPX1, nil)
    for _, packet in ipairs(f.sent) do
        Check(packet.prefix, "FOREVERRP")
        Check(packet.channel ~= "CHANNEL", true)
    end
end
local function Dots(f)
    local n = 0
    for _, pin in ipairs(f.a.PlayerMarkers.pool) do if pin:IsShown() then n = n + 1 end end
    return n
end

Test("Phase 1 manifest excludes layer code; saved Beta 17 opt-ins cannot start networking", function(f)
    local file = assert(io.open("ForeverRP/ForeverRP.toc")); local toc = file:read("*a"); file:close()
    Check(toc:find("LayerEvidence", 1, true), nil)
    Check(toc:find("experiments", 1, true), nil)
    Check(toc:find("Discovery\\Activity.lua", 1, true) ~= nil, true)
    Check(toc:find("UI\\PlayerMarkers.lua", 1, true) ~= nil, true)
    local a, db = f.a, f.a.Database
    for _, key in ipairs({"enabled", "directory", "subzone", "markers"}) do db:SetActivitySetting(key, true) end
    db:SetActivitySetting("location", "precise")
    f.joined = 7; f:Login(); a.Activity:Initialize()
    Check(f.leaves, 1); Check(f.joined, 0)
    Check(a.Activity:Enabled(), false); Check(a.LayerEvidence, nil)
    for _, event in ipairs({"SHARD_TRANSFER", "SHARD_TRANSFER_IMMINENT", "GROUP_JOINED", "GROUP_LEFT", "ZONE_CHANGED_NEW_AREA"}) do
        Check(a.Events.handlers[event], nil)
    end
    for _ = 1, 600 do f:Tick() end
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "GUILD_ROSTER_UPDATE"}) do a.Events.handlers[event]() end
    for _, command in ipairs({"network channel on", "network channel off", "network trace", "network probe Test", "network"}) do
        a.Commands:Handle(command)
    end
    Check(a.Communication:SendActivity("A2|bad", "GUILD"), false)
    Check(a.Communication:SendActivityPacket("A2|bad", "CHANNEL", "7"), false)
    for _, route in ipairs({"CHANNEL", "GUILD", "PARTY", "WHISPER"}) do
        for _, payload in ipairs({"A2|v|0|public|10|1|110|200|1|IC|NORMAL|0|", "A3|opaque|1|OFF", "L1|OFF", "T1|Test", "OFF"}) do
            f:Receive(payload, "Peer Person-Realm", route, "FOREVERRPX1")
        end
    end
    Check(a.Presence:UpdateActivity("Peer Person-Realm", {}, "v", "Peer Person"), false)
    Check(#a.Presence:GetAll(false), 0); Check(#a.Activity:GetAll(), 0)
    Check(#a.Activity:QueryDirectory({}), 0); Check(Dots(f), 0)
    Check(#f.sent, 0); NoExperimentalTraffic(f)
    Check(db:GetActivitySettings().enabled, true); Check(db:GetActivitySettings().location, "precise")
end)

Test("native Beta 5 handshake, identity and notification path work with network paused", function(f)
    f:Login(); local a = f.a
    a.Database:SetActivitySetting("markers", true)
    f:Unit("mouseover"); a.Events.handlers.UPDATE_MOUSEOVER_UNIT()
    Check(#f.sent, 1); Check(f.sent[1].payload:match("^HELLO|1|"), "HELLO|1|")
    Check(f.sent[1].target, "Peer Person"); Check(f.sent[1].channel, "WHISPER")
    Check(a.NearbyPlayers:GetCount(false), 0); Check(Dots(f), 0)
    f:Receive(nil, "Peer Person-OtherRealm"); Check(a.NearbyPlayers:GetCount(false), 0)
    f:Receive(); f:Tick()
    Check(a.NearbyPlayers:IsNearby("Peer Person-Realm", false), true)
    Check(f.alerts, 1); Check(Dots(f), 1)
    for _ = 1, 10 do a.Events.handlers.UPDATE_MOUSEOVER_UNIT(); f:Receive(); f:Tick() end
    Check(f.alerts, 1); Check(#f.sent, 1)
    f.units.mouseover.range = false; f:Tick()
    Check(a.NearbyPlayers:GetCount(false), 0); Check(Dots(f), 0)
    f.units.mouseover.range = true; f:Tick()
    Check(a.NearbyPlayers:GetCount(false), 1); Check(Dots(f), 1); Check(f.alerts, 1)
    f.units.mouseover = nil; a.Events.handlers.UPDATE_MOUSEOVER_UNIT(); f:Tick()
    Check(a.NearbyPlayers:GetCount(false), 0); Check(Dots(f), 0)
    NoExperimentalTraffic(f)
end)

Test("guild, party, channel, coordinates and message receipt cannot create proximity", function(f)
    f:Login(); local a = f.a; a.Database:SetActivitySetting("markers", true)
    for _, route in ipairs({"GUILD", "PARTY", "WHISPER"}) do
        f:Receive(nil, nil, route); f:Tick()
        Check(a.NearbyPlayers:GetCount(false), 0); Check(Dots(f), 0)
    end
    local u = f:Unit("party1"); u.range = nil
    f.group = true; a.Events.handlers.GROUP_ROSTER_UPDATE(); f:Tick()
    Check(a.NearbyPlayers:GetCount(false), 0); Check(Dots(f), 0)
    Check(a.Range:GetRangeState("party1"), "UNKNOWN")
    u.range = true; u.visible = false; f:Tick(); Check(Dots(f), 0)
    NoExperimentalTraffic(f)
end)

Test("local dots retain pooling, movement, zoom and rotation without coordinate packets", function(f)
    f:Login(); local a = f.a; a.Database:SetActivitySetting("markers", true); f:Discover()
    local pin = a.PlayerMarkers.pool[1]; Check(pin.y, 10)
    local anchors, sent = pin.anchors, #f.sent
    a.PlayerMarkers:Refresh(); Check(pin.anchors, anchors)
    f.units.target.x = 120; f:Tick(); Check(pin.y, 20)
    f.x = 110; f:Tick(); Check(pin.y, 10)
    f.radius = 50; a.Events.handlers.MINIMAP_UPDATE_ZOOM(); Check(pin.y, 20)
    f.rotate, f.facing = true, math.pi / 2; f:Tick()
    Check(math.abs(pin.x - 20) < 0.001, true); Check(math.abs(pin.y) < 0.001, true)
    a.Database:SetActivitySetting("markers", false); Check(Dots(f), 0)
    a.Database:SetActivitySetting("markers", true); Check(Dots(f), 1)
    Check(a.PlayerMarkers.pool[1], pin); Check(#a.PlayerMarkers.pool, 1)
    Check(#f.sent, sent); Check(a.Database:GetActivitySettings().enabled, false)
    Check(a.Database:GetActivitySettings().location, "hidden")
    NoExperimentalTraffic(f)
end)

Test("dots fail closed for invalid positions, invisible/reused units, range and combat", function(f)
    f:Login(); local a = f.a; a.Database:SetActivitySetting("markers", true); f:Discover()
    for _, value in ipairs({f.secret, 0/0, math.huge, -math.huge, "110"}) do
        f.units.target.x = value; a.PlayerMarkers:Refresh(); Check(Dots(f), 0)
    end
    f.units.target.x = nil; a.PlayerMarkers:Refresh(); Check(Dots(f), 0)
    f.units.target.x, f.units.target.space = 110, 2; a.PlayerMarkers:Refresh(); Check(Dots(f), 0)
    f.units.target.space = 1; a.PlayerMarkers:Refresh(); Check(Dots(f), 1)
    f.units.target.visible = f.secret; a.PlayerMarkers:Refresh(); Check(Dots(f), 0)
    f.units.target.visible = true; f.units.target.full = "Someone Else"
    a.PlayerMarkers:Refresh(); Check(Dots(f), 0)
    f.units.target.full = "Peer Person"; f:Tick(); Check(Dots(f), 1)
    for _, combat in ipairs({true, f.secret, 1}) do
        f.combat = combat; local calls, positions = f.rangeCalls, f.positionCalls
        f:Tick(); a.Events.handlers.MINIMAP_UPDATE_ZOOM()
        Check(f.rangeCalls, calls); Check(f.positionCalls, positions)
        Check(a.NearbyPlayers:GetCount(false), 0); Check(Dots(f), 0)
    end
    f.combat = false; f:Tick(); Check(Dots(f), 1); Check(f.alerts, 1)
    f.radius = f.secret; a.PlayerMarkers:Refresh(); Check(Dots(f), 0)
end)

Test("native presence expires and removes dots despite stale units and old advertisements", function(f)
    f:Login(); local a = f.a; a.Database:SetActivitySetting("markers", true); f:Discover()
    Check(Dots(f), 1)
    f:Tick(901)
    Check(a.Presence:IsConfirmed("Peer Person-Realm", false), false)
    Check(a.NearbyPlayers:GetCount(false), 0); Check(Dots(f), 0)
    f:Receive("A2|v|0|public|10|1|110|200|1|IC|NORMAL|0|", nil, "GUILD", "FOREVERRPX1")
    f:Tick(); Check(Dots(f), 0); Check(a.Presence:IsConfirmed("Peer Person-Realm", false), false)
end)

Test("dots use another validated unit when the selected token has no position", function(f)
    f:Login(); local a = f.a; a.Database:SetActivitySetting("markers", true); f:Discover()
    f.units.target.x = nil; f:Tick(); Check(Dots(f), 0)
    f:Unit("party1"); f.group = true; a.Events.handlers.GROUP_ROSTER_UPDATE(); f:Tick()
    Check(Dots(f), 1)
    f.units.party1.full = "Other Person"; a.PlayerMarkers:Refresh(); Check(Dots(f), 0)
    f.units.party1.full = "Peer Person"; a.PlayerMarkers:Refresh(); Check(Dots(f), 1)
    f.units.party1.range = nil; a.PlayerMarkers:Refresh(); Check(Dots(f), 0)
    f.units.party1.range = true
    local positions = f.positionCalls
    CheckInteractDistance = function() f.combat = true; return true end
    a.PlayerMarkers:Refresh()
    Check(f.positionCalls, positions + 1) -- only local position read before combat changed
    Check(Dots(f), 0)
end)

Test("profile requests complete without Directory; tooltips never initiate requests", function(f)
    f:Login(); local a = f.a; f:Discover()
    Check(a.ProfileTransfer:Request("Peer Person-Realm"), true)
    local request = assert(a.Communication:Parse(f.sent[#f.sent].payload))
    Check(request.messageType, "PROFILE_REQUEST"); Check(f.sent[#f.sent].target, "Peer Person-Realm")
    local profile = a.Profile:Get(); local remote = {}
    for k, v in pairs(profile) do remote[k] = v end
    remote.rpName, remote.title = "Test Peer", "Phase 1"
    local encoded = assert(a.ProfileTransfer:SerializeProfile(remote))
    local chunks = assert(a.ProfileTransfer:BuildChunks(encoded))
    for i, chunk in ipairs(chunks) do
        f:Receive(a.Communication:Serialize("PROFILE_DATA", request.messageId, i, #chunks, chunk))
    end
    Check(a.RemoteProfiles:GetProfile("Peer Person-Realm", false).profile.rpName, "Test Peer")
    Check(a.Profile:GetField("rpName") ~= "Test Peer", true)
    local tooltip = {GetUnit = function() return "Peer Person", "target" end,
        AddLine = function() f.tooltipLines = (f.tooltipLines or 0) + 1 end, Show = function() end}
    local sent = #f.sent; a.PlayerTooltip:Process(tooltip)
    Check(f.tooltipLines > 0, true); Check(#f.sent, sent)
    Check(a.ProfileTransfer:IsRequestPending("Peer Person-Realm", false), false)
    NoExperimentalTraffic(f)
end)

Test("approval and Connections grants still gate transfers; privacy cancels queued data", function(f)
    f:Login(); local a = f.a; f:Discover()
    a.Database:SetDisclosureMode("approval")
    f:Receive("PROFILE_REQUEST|1|0.1.1-beta.18|P1")
    Check(a.ProfileAuthorization.pending["peer person-realm"] ~= nil, true)
    local function DataCount()
        local n = 0; for _, p in ipairs(f.sent) do if p.payload:match("^PROFILE_DATA|") then n = n + 1 end end; return n
    end
    Check(DataCount(), 0); Check(a.ProfileAuthorization:Decide("Peer Person-Realm", true), true)
    a.Database:SetPrivacyMode("hidden", true); f:Drain(); Check(DataCount(), 0)
    Check(a.NearbyPlayers:GetCount(false), 0); Check(Dots(f), 0)
    a.Database:SetPrivacyMode("visible", true); f:Receive(); f.now = f.now + 11
    a.Database:SetDisclosureMode("connections")
    a.Connections:Remember("Peer Person-Realm", false)
    Check(a.ProfileAuthorization:CanSend("Peer Person-Realm", "P2"), false)
    Check(a.ProfileAuthorization:SetConnectionApproval("Peer Person-Realm", true), true)
    Check(a.ProfileAuthorization:CanSend("Peer Person-Realm", "P2"), true)
    f:Receive("PROFILE_REQUEST|1|0.1.1-beta.18|P2"); f:Drain(); Check(DataCount() > 0, true)
    Check(a.ProfileAuthorization:SetConnectionApproval("Peer Person-Realm", false), true)
    Check(a.ProfileAuthorization:CanSend("Peer Person-Realm", "P3"), false)
    f:Tick(); NoExperimentalTraffic(f)
end)

Test("restricted and disabled discovery preserve privacy with no experimental dependency", function(f)
    f:Login(); local a = f.a; a.Database:SetActivitySetting("markers", true)
    a.Database:SetPrivacyMode("restricted", true); f:Discover()
    Check(a.NearbyPlayers:GetCount(false), 0); Check(Dots(f), 0); Check(#f.sent, 0)
    f.guild, f.friend = true, true; a.Events.handlers.GUILD_ROSTER_UPDATE(); f:Receive(); f:Tick()
    Check(a.NearbyPlayers:GetCount(false), 1); Check(Dots(f), 1)
    f.friend = false; a.Events.handlers.GUILD_ROSTER_UPDATE(); f:Tick()
    Check(a.NearbyPlayers:GetCount(false), 0); Check(Dots(f), 0)
    a.Database:SetPrivacyMode("visible", true); f:Receive(); f:Tick(); Check(Dots(f), 1)
    a.Database:SetDiscoveryEnabled(false); Check(a.NearbyPlayers:GetCount(false), 0); Check(Dots(f), 0)
    local sent = #f.sent; f:Tick(20); Check(#f.sent, sent)
    a.Database:SetPrivacyMode("hidden", true); f:Receive("PROFILE_REQUEST|1|v|P9"); f:Drain()
    Check(#f.sent, sent); NoExperimentalTraffic(f)
end)

Test("existing Privacy and Directory layouts explain paused controls and retain saved data", function(f)
    f:Login(); local a, db = f.a, f.a.Database
    db:SetActivitySetting("enabled", true); db:SetActivitySetting("directory", true)
    db:SetActivitySetting("subzone", true); db:SetActivitySetting("location", "precise")
    a.Profile:SetField("rpName", "Preserved Local")
    a.Connections:Remember("Peer Person-Realm", false)
    a.DiscoveryOptions:Create({}); a.ActivityUI:Create({})
    local ui = a.DiscoveryOptions
    for _, control in ipairs({ui.experimental, ui.directory, ui.subzone}) do
        Check(control.enabled, false); Check(control.text:find("Paused for Phase 1", 1, true) ~= nil, true)
        control.OnClick()
    end
    Check(ui.dropdowns[2].widget.enabled, false)
    Check(a.ActivityUI.search.enabled, false); Check(a.ActivityUI.statusDropdown.enabled, false)
    Check(#a.ActivityUI.rows, 0)
    Check(a.ActivityUI.status.text:find("Temporarily unavailable", 1, true) ~= nil, true)
    Check(db:GetActivitySettings().enabled, true); Check(db:GetActivitySettings().directory, true)
    ui.markers.OnClick(); Check(db:GetActivitySettings().markers, true)
    local reload = Fixture(ForeverRPDB, ForeverRPCharacterDB); reload:Login()
    Check(reload.a.Profile:GetField("rpName"), "Preserved Local")
    Check(reload.a.Database:GetActivitySettings().enabled, true)
    Check(reload.a.Database:GetActivitySettings().location, "precise")
    Check(reload.a.Database:GetActivitySettings().markers, true)
    Check(#reload.a.Connections:GetAll(false), 1)
    Check(reload.a.Activity:Enabled(), false); Check(reload.a.LayerEvidence, nil)
    Check(#reload.a.Presence:GetAll(false), 0); NoExperimentalTraffic(reload)
end)

print("PASS: " .. cases .. " Phase 1 cases; " .. checks .. " checks (mock APIs/transport/widgets; no live multiplayer claim)")
