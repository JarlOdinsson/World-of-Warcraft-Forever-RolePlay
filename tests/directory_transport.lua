local Fixture = dofile("tests/helpers/client_fixture.lua")
local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function Test(name, run)
    run(Fixture()); cases = cases + 1; print("PASS " .. name)
end
local function Enable()
    ForeverRP.Database:SetActivitySetting("enabled", true)
    ForeverRP.Activity:Initialize()
end
local function Packet() return "A2|v|0|public|0|-|-|-|1|IC|NORMAL|0|" end
Test("no route does not consume advertisement; late membership sends immediately", function(f)
    local id, joins = 0, 0
    GetChannelName = function() return id end
    JoinChannelByName = function() joins = joins + 1 end
    Enable(); local a = ForeverRP.Activity
    a:Tick(); Check(joins, 1); Check(a.joined, false)
    Check(a.lastAnnouncement, nil); Check(a.lastLocation, nil); Check(#f.sent, 0)
    f.now = 105; a:Tick(); Check(joins, 1)
    id = 9; f.now = 106; a:Tick()
    Check(a.joined, true); Check(#f.sent, 1)
    Check(f.sent[1].channel, "CHANNEL"); Check(f.sent[1].target, "9")
    Check(a.lastSends.CHANNEL.accepted, true); Check(a.lastSends.CHANNEL.result, 0)
end)
Test("failed joins stop after three and world rearming is rate limited", function(f)
    local joins = 0
    GetChannelName = function() return 0 end
    JoinChannelByName = function() joins = joins + 1 end
    Enable(); local a = ForeverRP.Activity
    for second = 100, 1000 do f.now = second; a:Tick() end
    Check(joins, 3); Check(#f.sent, 0); Check(a.lastAnnouncement, nil)
    a:OnWorldChanged(); a:Tick(); Check(joins, 4)
    for _ = 1, 100 do a:OnWorldChanged(); a:Tick() end
    Check(joins, 4)
    f.now = 1010; a:Tick(); f.now = 1020; a:Tick(); Check(joins, 6)
    f.now = 1029; a:OnWorldChanged(); a:Tick(); Check(joins, 6)
    f.now = 1030; a:OnWorldChanged(); a:Tick(); Check(joins, 7)
end)
Test("confirmed membership loss recovers and drops obsolete numeric destinations", function(f)
    local id = 7
    GetChannelName = function() return id end
    JoinChannelByName = function() end
    Enable(); local a = ForeverRP.Activity
    f.result = 3; a:Tick(); Check(f.sent[1].target, "7"); Check(#a.queue, 1)
    id = 0; f.now = 101; a:Tick()
    Check(a.joined, false); Check(a.joinAttempts, 1); Check(#a.queue, 0)
    id = 12; f.result = 0; f.now = 110; a:Tick(); Check(#f.sent, 1)
    f.now = 130; a:Tick(); Check(#f.sent, 2)
    Check(f.sent[2].target, "12"); Check(a.joinAttempts, 0)
end)
Test("route changes retain thirty-second floor and never starve shared channel", function(f)
    Enable(); local a = ForeverRP.Activity
    IsInGroup, IsInGuild = function() return true end, function() return true end
    a:Tick(); Check(#a.queue, 3)
    for second = 101, 105 do f.now = second; a:Tick() end
    Check(#f.sent, 6)
    Check(f.sent[1].channel, "PARTY"); Check(f.sent[3].channel, "GUILD"); Check(f.sent[5].channel, "CHANNEL")
    IsInGroup = function() return false end
    f.now = 106; a:Tick(); Check(#f.sent, 6)
    for second = 130, 133 do f.now = second; a:Tick() end
    Check(#f.sent, 10)
    Check(f.sent[7].channel, "GUILD"); Check(f.sent[9].channel, "CHANNEL")
end)
Test("API rejection and throttling stay bounded and never assert delivery", function(f)
    Enable(); local a = ForeverRP.Activity
    f.result = 8
    for second = 100, 129 do f.now = second; a:Tick() end
    Check(#f.sent, 2); Check(#a.queue, 0)
    Check(a.lastSends.CHANNEL.accepted, false); Check(a.lastSends.CHANNEL.reason, "throttled")
    a:ReportTransport()
    Check(table.concat(f.lines, "\n"):find("Enqueue is not delivery", 1, true) ~= nil, true)
    f.now = 250; f.result = 5; a:Tick()
    Check(a.lastSends.CHANNEL.result, 5); Check(a.lastSends.CHANNEL.reason, "failed")
end)
Test("privacy cannot join or publish globally without consent", function(f)
    local calls = 0
    GetChannelName = function() return 0 end
    JoinChannelByName = function() calls = calls + 1 end
    local a, db = ForeverRP.Activity, ForeverRP.Database
    a:Tick(); Check(calls, 0)
    db:SetPrivacyMode("hidden", true); Enable(); a:Tick(); Check(calls, 0)
    db:SetPrivacyMode("restricted", true); a:Tick(); Check(calls, 0); Check(#f.sent, 0)
    db:SetPrivacyMode("visible", true); a:Tick(); Check(calls, 1)
    local left = 0; LeaveChannelByName = function() left = left + 1 end
    db:SetActivitySetting("enabled", false); Check(left, 1)
    Check(db:GetPrivacyMode(), "visible"); Check(db:GetActivitySettings().location, "hidden")
    Check(db:GetActivitySettings().directory, false)
end)
Test("missing or inaccessible channel APIs fail cleanly", function(f)
    Enable(); local a = ForeverRP.Activity
    GetChannelName, JoinChannelByName = nil, nil
    a:Tick(); Check(#f.sent, 0); Check(#a:Routes(), 0)
    for _, value in ipairs({f.secret, -1, 0, 1.5, 1001}) do
        GetChannelName = function() return value end
        Check(a:SharedChannelID(), nil)
    end
end)
Test("prefix failure stops and a world transition permits bounded recovery", function(f)
    Enable(); local a = ForeverRP.Activity
    local attempts = 0
    ForeverRP.Communication.RegisterCompatibilityPrefix = function() attempts = attempts + 1; return false end
    for second = 100, 200 do f.now = second; a:Tick() end
    Check(attempts, 3); Check(#f.sent, 0)
    ForeverRP.Communication.RegisterCompatibilityPrefix = function() attempts = attempts + 1; return true end
    a:OnWorldChanged(); a:Tick()
    Check(attempts, 4); Check(a.registered, true); Check(#f.sent, 1)
end)
Test("real event dispatch records shared receipt without unit, range, or simulated presence", function(f)
    Enable(); local a = ForeverRP
    UnitExists = function(unit) return unit == "player" end
    dofile("ForeverRP/Discovery/Range.lua")
    dofile("ForeverRP/Discovery/PlayerDetection.lua")
    dofile("ForeverRP/Discovery/NearbyPlayers.lua")
    local refreshes = 0; a.ActivityUI = {Refresh = function() refreshes = refreshes + 1 end}
    local handlers = {}
    CreateFrame = function() return {RegisterEvent = function() end, SetScript = function(_, _, run) handlers.dispatch = run end} end
    dofile("ForeverRP/Core/Events.lua")
    handlers.dispatch(nil, "CHAT_MSG_ADDON", a.Activity.prefix, Packet(), "CHANNEL", "Linea Aspera-ClassicBetaPvE2", "", 0, 7, "ForeverRPActivity", 0)
    local key = "Linea Aspera-ClassicBetaPvE2"
    Check(a.Presence:IsConfirmed(key, false), true)
    Check(#a.Activity:QueryDirectory(), 1)
    Check(a.Activity:GetPeer(key).layer, "UNKNOWN")
    Check(a.Activity:GetPeer(key).receivedVia, "CHANNEL")
    Check(a.Activity.lastReceives.CHANNEL.localID, 7)
    Check(a.Activity.lastReceives.CHANNEL.name, "ForeverRPActivity")
    Check(a.NearbyPlayers:IsNearby(key, false), false)
    Check(a.Presence:Get(key, false).simulated, false)
    a.Activity:Tick(); Check(refreshes > 0, true)
    local found = false
    for _, sent in ipairs(f.sent) do
        if sent.prefix == "FOREVERRP" then found = true end
    end
    Check(found, false) -- metadata doesn't send HELLO, ACK or profiles
    handlers.dispatch(nil, "CHAT_MSG_ADDON", a.Activity.prefix, Packet(), "CHANNEL", "Local-Realm", "", 0, 7, "ForeverRPActivity", 0)
    Check(a.Activity.lastReceives.CHANNEL.sender, key) -- self echo isn't remote evidence
    f.now = 251; a.Presence:Expire(true); Check(#a.Activity:QueryDirectory(), 0)
end)
Test("network command evidence is rate limited and contains no profile or private notes", function(f)
    Enable(); local a = ForeverRP
    a.Communication:OnAddonMessage(a.Activity.prefix, Packet(), "CHANNEL", "Cheese Spy-Realm", "", 0, 7, "ForeverRPActivity")
    a.Profile:Get().description = "PRIVATE_PROFILE_SENTINEL"
    a.Connections:Remember("Cheese Spy-Realm", false)
    ForeverRPDB.connections["Cheese Spy-Realm"].privateNote = "PRIVATE_NOTE_SENTINEL"
    a.DiscoveryDiagnostics = {counters = {sent = 0, received = 0, throttled = 0, expired = 0}}
    dofile("ForeverRP/Core/Commands.lua")
    a.Activity:Tick(); a.Commands:Handle("network")
    local count = #f.lines; a.Commands:Handle("network"); Check(#f.lines, count)
    local text = table.concat(f.lines, "\n")
    Check(text:find("Directory remote receipt CHANNEL sender=[Cheese Spy-Realm]", 1, true) ~= nil, true)
    Check(text:find("enqueue=accepted", 1, true) ~= nil, true)
    Check(text:find("PRIVATE_PROFILE_SENTINEL", 1, true), nil)
    Check(text:find("PRIVATE_NOTE_SENTINEL", 1, true), nil)
    f.now = 105; a.Commands:Handle("network"); Check(#f.lines > count, true)
end)
Test("same multiword name on distinct realm suffixes stays distinct", function(f)
    Enable(); local a = ForeverRP.Activity
    Check(a:Receive(Packet(), "CHANNEL", "Spencer Raven-ClassicBetaPvE"), true)
    Check(a:Receive(Packet(), "CHANNEL", "Spencer Raven-ClassicBetaPvE2"), true)
    Check(#a:QueryDirectory(), 2)
    Check(a:GetPeer("Spencer Raven-ClassicBetaPvE").characterKey, "Spencer Raven-ClassicBetaPvE")
    Check(a:GetPeer("Spencer Raven-ClassicBetaPvE2").characterKey, "Spencer Raven-ClassicBetaPvE2")
end)
Test("two isolated mocked clients exchange real metadata without shared social or visible units", function(first)
    local function Client(f, name)
        f.name, f.realm = name, "ClassicBetaPvE2"
        local a = ForeverRP
        a.Database:SetActivitySetting("enabled", true)
        a.Database:SetActivitySetting("directory", true)
        a.Profile:Get().status = "IC"
        UnitExists = function(unit) return unit == "player" end
        dofile("ForeverRP/Discovery/Range.lua")
        dofile("ForeverRP/Discovery/PlayerDetection.lua")
        dofile("ForeverRP/Discovery/NearbyPlayers.lua")
        local env = {ForeverRP = a}
        for _, key in ipairs({"GetTime", "time", "GetNormalizedRealmName", "GetRealmName", "UnitName",
            "UnitFullName", "GetUnitName", "UnitExists", "UnitIsPlayer", "UnitIsAFK", "UnitIsDND",
            "UnitPosition", "GetSubZoneText", "C_Map", "C_ChatInfo", "canaccessallvalues",
            "JoinChannelByName", "LeaveChannelByName", "GetChannelName", "IsInGroup", "IsInRaid", "IsInGuild"}) do env[key] = _G[key] end
        return {a = a, f = f, env = env, consumed = 0, sender = name .. "-ClassicBetaPvE2"}
    end
    local one = Client(first, "Spencer Raven")
    local two = Client(Fixture(), "Cheese Spy")
    local function Activate(client) for key, value in pairs(client.env) do _G[key] = value end end
    local function Exchange(from, to)
        Activate(from); from.a.Activity:Tick()
        while from.consumed < #from.f.sent do
            from.consumed = from.consumed + 1
            local packet = from.f.sent[from.consumed]
            Check(packet.channel, "CHANNEL"); Check(packet.prefix, "FOREVERRPX1")
            Activate(to)
            to.a.Communication:OnAddonMessage(packet.prefix, packet.payload, packet.channel,
                from.sender, "", 0, 7, "ForeverRPActivity")
        end
    end
    -- This bridge intentionally delivers messages: it tests pipeline behavior,
    -- not whether Forever's backend actually carries CHANNEL between layers.
    for second = 100, 400 do
        one.f.now, two.f.now = second, second
        Exchange(one, two); Exchange(two, one)
    end
    for _, pair in ipairs({{one, two}, {two, one}}) do
        local localClient, remoteClient = pair[1], pair[2]
        Activate(localClient)
        local a = localClient.a
        Check(#a.Activity:QueryDirectory(), 1)
        Check(a.Activity:QueryDirectory()[1].characterKey, remoteClient.sender)
        Check(a.Activity:GetPeer(remoteClient.sender).layer, "UNKNOWN")
        Check(a.Activity:GetPeer(remoteClient.sender).zone, 0)
        Check(a.NearbyPlayers:GetCount(false), 0)
        Check(#localClient.f.sent <= 10, true) -- ordered snapshots plus legacy copies
    end
    Activate(one); one.a.Database:SetActivitySetting("directory", false)
    one.f.now, two.f.now = 401, 401; Exchange(one, two)
    Activate(two); Check(#two.a.Activity:QueryDirectory(), 0)
    Check(two.a.NearbyPlayers:GetCount(false), 0)
    -- Existing independent metadata sharing can resume with listing disabled.
    local remaining = two.a.Activity:GetPeer(one.sender)
    Check(remaining and remaining.directory or false, false)
end)
print(string.format("PASS: %d directory transport cases; %d checks (mock delivery only; no layer server)", cases, checks))
