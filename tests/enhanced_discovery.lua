-- Real privacy, protocol, transfer, location and marker modules; mocked client.
local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local Fixture = dofile('tests/helpers/client_fixture.lua')
local function Test(name, callback)
    callback(Fixture()); cases = cases + 1; print("PASS " .. name)
end
local function Count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

Test("defaults preserve profiles and grants remain per character", function(f)
    local db = ForeverRP.Database
    Check(db:GetDisclosureMode(), "public")
    Check(db:GetActivitySettings().enabled, false)
    Check(db:GetActivitySettings().location, "hidden")
    Check(db:GetNotificationSettings().soundChoice, "bingbong")
    db:GetNotificationSettings().soundChoice = nil
    db:Initialize()
    Check(db:GetNotificationSettings().soundChoice, "drumroll")
    db:SetDisclosureMode("connections")
    db:SetActivitySetting("location", "zone")
    db:Initialize()
    Check(db:GetDisclosureMode(), "connections")
    Check(db:GetActivitySettings().location, "zone")
    Check(db:SetDisclosureMode("bad"), false)
    Check(db:SetActivitySetting("location", "bad"), false)
end)

Test("public requests preserve existing chunk protocol", function(f)
    f:Request(); f:Drain()
    Check(#f.sent > 0, true)
    Check(f.sent[1].payload:match("^PROFILE_DATA|1|"), "PROFILE_DATA|1|")
    Check(ForeverRP.ProfileAuthorization.served["peer-realm"] ~= nil, true)
end)

Test("approval cannot send before explicit owner action; duplicates are bounded", function(f)
    ForeverRP.Database:SetDisclosureMode("approval")
    for _ = 1, 50 do f:Request() end
    Check(Count(ForeverRP.ProfileAuthorization.pending), 1)
    Check(#f.sent, 1)
    Check(f.sent[1].payload:match("|pending$"), "|pending")
    Check(ForeverRP.ProfileTransfer:SendProfile("Peer-Realm", "P2"), false)
    Check(ForeverRP.ProfileAuthorization:Decide("Peer-Realm", true), true)
    f:Drain()
    Check(f.sent[2].payload:match("^PROFILE_DATA|"), "PROFILE_DATA|")
    Check(ForeverRP.ProfileAuthorization:CanSend("Peer-Realm", "Other"), false)
    f.now = f.now + 31
    Check(ForeverRP.ProfileAuthorization:CanSend("Peer-Realm", "P1"), false)
end)

Test("denial and expiry never serialize a biography", function(f)
    ForeverRP.Database:SetDisclosureMode("approval")
    f:Request()
    Check(ForeverRP.ProfileAuthorization:Decide("Peer-Realm", false), false)
    f:Drain()
    Check(#f.sent, 2)
    Check(f.sent[2].payload:match("|denied$"), "|denied")
    f.now = f.now + 11; f:Request(nil, "P2")
    f.now = f.now + 26
    ForeverRP.ProfileAuthorization:Tick()
    Check(ForeverRP.ProfileAuthorization:Decide("Peer-Realm", true), false)
    Check(Count(ForeverRP.ProfileAuthorization.pending), 0)
end)

Test("Connections Only requires owner grant, not Remember or Favorite", function(f)
    f:Peer()
    ForeverRP.Connections:Remember("Peer-Realm", false)
    ForeverRP.Database:SetDisclosureMode("connections")
    Check(ForeverRP.ProfileAuthorization:CanSend("Peer-Realm", "P1"), false)
    Check(ForeverRP.ProfileAuthorization:SetConnectionApproval("peer-realm", true), true)
    Check(ForeverRP.ProfileAuthorization:CanSend("Peer-Realm", "P1"), true)
    ForeverRP.Connections:Forget("Peer-Realm", false)
    ForeverRP.Connections:Remember("Peer-Realm", false)
    Check(ForeverRP.ProfileAuthorization:CanSend("Peer-Realm", "P1"), false)
    Check(ForeverRP.ProfileAuthorization:SetConnectionApproval("Stranger-Realm", true), false)
end)

Test("privacy changes stop queued chunks and send content-free revocations", function(f)
    f:Request(); f:Drain()
    Check(ForeverRP.ProfileAuthorization.served["peer-realm"] ~= nil, true)
    f.now = f.now + 11; f:Request(nil, "P2")
    local before = #f.sent
    ForeverRP.Database:SetPrivacyMode("hidden")
    f:Drain()
    ForeverRP.ProfileAuthorization:Tick()
    Check(#f.sent, before + 1)
    Check(f.sent[#f.sent].payload:match("PROFILE_STATUS|1|[^|]+|REVOKE|revoked" ) ~= nil, true)
    Check(#ForeverRP.ProfileTransfer.outgoingResponseOrder, 0)
end)

Test("cached profiles clear on revocation/denial and expire without a live notice", function(f)
    f:Peer()
    local profiles = ForeverRP.RemoteProfiles
    profiles:StoreProfile("Peer-Realm", ForeverRP.Profile:Get(), {})
    Check(profiles:HasProfile("Peer-Realm", false), true)
    ForeverRP.ProfileTransfer:HandleStatus({messageId = "REVOKE", status = "revoked"}, "Peer-Realm")
    Check(profiles:HasProfile("Peer-Realm", false), false)
    profiles:StoreProfile("Peer-Realm", ForeverRP.Profile:Get(), {})
    f.now = f.now + 301
    profiles:Expire()
    Check(profiles:HasProfile("Peer-Realm", false), false)
    profiles:StoreProfile("Peer-Realm", ForeverRP.Profile:Get(), {})
    ForeverRP.Database:SetPrivacyMode("hidden")
    Check(profiles:HasProfile("Peer-Realm", false), false)
end)

Test("approval request crowds cap prompts, pending rows and metadata", function(f)
    ForeverRP.Database:SetDisclosureMode("approval")
    for i = 1, 300 do f:Request("Peer" .. i .. "-Realm", "P" .. i) end
    Check(Count(ForeverRP.ProfileAuthorization.pending), 8)
    Check(#f.lines <= 1, true)
    Check(#f.sent <= 20, true)
    Check(Count(ForeverRP.ProfileAuthorization.seen) <= 100, true)
end)

Test("experimental discovery stays off until opt-in and never guesses a layer", function(f)
    local activity, db = ForeverRP.Activity, ForeverRP.Database
    activity:Initialize(); activity:Tick()
    Check(#f.sent, 0); Check(f.joined, 0)
    Check(activity:Receive("A1|0.1.1-beta.7|0|public|10|-|-|-", "GUILD", "Peer-Realm"), false)
    db:SetActivitySetting("enabled", true)
    activity:Tick()
    Check(#f.sent, 1); Check(f.joined, 1)
    Check(f.sent[1].prefix, "FOREVERRPX1")
    Check(f.sent[1].channel, "CHANNEL")
    Check(f.sent[1].payload:match("^A2|") ~= nil, true)
    Check(activity:Receive("A1|0.1.1-beta.7|0|public|10|-|-|-", "GUILD", "Peer-Realm"), true)
    Check(activity:GetPeer("Peer-Realm").layer, "UNKNOWN")
    Check(ForeverRP.Presence:IsConfirmed("Peer-Realm", false), true)
    Check(activity:Receive("A1|0.1.1-beta.7|0|public|10|-|-|-", "GUILD", "Peer-Realm"), false)
    Check(activity.counters.duplicates, 1)
end)

Test("zone/coordinate validation and movement keep remote data bounded", function(f)
    local activity, db = ForeverRP.Activity, ForeverRP.Database
    db:SetActivitySetting("enabled", true); db:SetActivitySetting("location", "precise")
    activity:Initialize(); activity:Tick()
    Check(activity:Location().x, 100)
    f.x = f.secret
    Check(activity:Location().x, nil)
    f.x = 100
    Check(activity:Receive("A1|v|0|public|10|1|nan|200", "GUILD", "Peer-Realm"), false)
    Check(activity:Receive("A1|v|0|public|10|1|100|200", "GUILD", "Peer-Realm"), true)
    f.now = f.now + 6
    Check(activity:Receive("A1|v|1|public|20|-|-|-", "GUILD", "Peer-Realm"), true)
    Check(activity:GetPeer("Peer-Realm").zone, 20)
    Check(activity:GetPeer("Peer-Realm").x, nil)
    f.now = f.now + 151; activity:Tick()
    Check(#activity:GetAll(), 0)
end)

Test("Hidden withdraws and stops the channel; restricted mode excludes strangers", function(f)
    local activity, db = ForeverRP.Activity, ForeverRP.Database
    db:SetActivitySetting("enabled", true); activity:Initialize(); activity:Tick()
    db:SetPrivacyMode("hidden"); activity:Tick()
    Check(f.joined, 0)
    local count = #f.sent
    f.now = f.now + 200; activity:Tick()
    Check(#f.sent, count)
    db:SetPrivacyMode("restricted")
    Check(activity:Receive("A1|v|0|public|10|-|-|-", "CHANNEL", "Peer-Realm"), false)
end)

Test("markers reject stale/cross-zone/cross-space data and never invent green/blue", function(f)
    local markers = ForeverRP.PlayerMarkers
    local entry = {zone = 10, space = 1, x = 110, y = 200, at = f.now, layer = "UNKNOWN"}
    local location = {zone = 10, space = 1, x = 100, y = 200}
    local x, y = markers:Project(entry, location, 100, 200, 200)
    Check(x, 0); Check(y, 10)
    entry.zone = 20; Check(markers:Project(entry, location, 100, 200, 200), nil)
    entry.zone = 10; entry.space = 2; Check(markers:Project(entry, location, 100, 200, 200), nil)
    entry.space = 1; entry.x = 1000; Check(markers:Project(entry, location, 100, 200, 200), nil)
    entry.x = 110; f.now = f.now + 126; Check(markers:Project(entry, location, 100, 200, 200), nil)
end)

Test("bounded channel load and repeated events cannot create announcement storms", function(f)
    local activity, db = ForeverRP.Activity, ForeverRP.Database
    db:SetActivitySetting("enabled", true); db:SetActivitySetting("location", "precise")
    activity:Initialize()
    for second = 1, 600 do
        f.now = 100 + second
        f.x = 100 + second
        for _ = 1, 10 do activity:Changed(); activity:Tick() end
    end
    Check(#f.sent <= 21, true)
    local sent = #f.sent
    f.result = 3
    for second = 1, 100 do f.now = f.now + 1; activity:Tick() end
    Check(#f.sent - sent <= 8, true)
    Check(activity.counters.throttled > 0, true)
    print("Measured moving-client 10-minute attempts: " .. sent .. "; projected 100-client attempts <= " .. sent * 100)
end)

Test("marker frames are pooled, neutral, noninteractive and removed when stale", function(f)
    local markers, activity, db = ForeverRP.PlayerMarkers, ForeverRP.Activity, ForeverRP.Database
    local created, positioned = 0, 0
    local Widget = {}
    Widget.__index = Widget
    function Widget:Hide() self.shown = false end
    function Widget:Show() self.shown = true end
    function Widget:SetSize() end
    function Widget:EnableMouse(value) self.interactive = value end
    function Widget:CreateTexture() return setmetatable({}, Widget) end
    function Widget:SetAllPoints() end
    function Widget:SetTexture() end
    function Widget:SetVertexColor(r, g, b) self.color = {r, g, b} end
    function Widget:ClearAllPoints() end
    function Widget:SetPoint() positioned = positioned + 1 end
    CreateFrame = function() created = created + 1; return setmetatable({}, Widget) end
    Minimap = {GetWidth = function() return 200 end, GetHeight = function() return 200 end}
    C_Minimap = {GetViewRadius = function() return 100 end}
    GetCVar = function() return "0" end
    db:SetActivitySetting("enabled", true)
    db:SetActivitySetting("markers", true)
    Check(activity:Receive("A1|v|0|public|10|1|110|200", "GUILD", "Peer-Realm"), true)
    markers:Refresh()
    Check(created, 1)
    Check(markers.pool[1].shown, true)
    Check(markers.pool[1].interactive, false)
    Check(markers.pool[1].texture.color[1], markers.pool[1].texture.color[2])
    local before = positioned
    markers:Refresh()
    Check(positioned, before)
    f.y = 205; markers:Refresh(); Check(positioned > before, true)
    f.now = f.now + 126; markers:Refresh(); Check(markers.pool[1].shown, false)
    f.now = f.now + 5
    activity:Receive("A1|v|0|public|10|1|110|200", "GUILD", "Peer-Realm")
    markers:Refresh(); Check(created, 1)
    db:SetActivitySetting("markers", false)
    Check(markers.pool[1].shown, false)
    Minimap, C_Minimap = nil, nil
end)

Test("approval status extends once; denied/revoked in-flight data cannot complete", function(f)
    local transfer = ForeverRP.ProfileTransfer
    f:Peer()
    Check(transfer:Request("Peer-Realm"), true)
    local requestKey, request = next(transfer.pendingRequests)
    local id = requestKey:match("\031(.+)$")
    transfer:HandleStatus({messageId = id, status = "pending"}, "Peer-Realm")
    Check(request.createdAt, 130)
    f.now = 110
    ForeverRP.Communication:HandleIncoming("FOREVERRP", "PROFILE_STATUS|1|v|" .. id .. "|pending",
        "WHISPER", "Peer-Realm", false)
    Check(ForeverRP.Presence.players["Peer-Realm"].lastSeen, 100)
    transfer:HandleStatus({messageId = id, status = "pending"}, "Peer-Realm")
    Check(request.createdAt, 130)
    transfer:HandleStatus({messageId = id, status = "denied"}, "Peer-Realm")
    Check(next(transfer.pendingRequests), nil)
    Check(transfer:HandleChunk({messageId = id, totalChunks = 1, chunkIndex = 1, chunk = "x"}, "Peer-Realm", false), false)
    local packet = ForeverRP.Communication:Parse("PROFILE_STATUS|1|v|P1|denied")
    Check(packet.status, "denied")
    Check(ForeverRP.Communication:Parse("PROFILE_STATUS|1|v|P1|allow"), nil)
end)

Test("zone list prioritizes local zone even when our own location is hidden", function(f)
    local activity = ForeverRP.Activity
    ForeverRP.Database:SetActivitySetting("enabled", true)
    activity:Receive("A1|v|0|public|20|-|-|-", "GUILD", "Other-Realm")
    activity:Receive("A1|v|0|public|10|-|-|-", "GUILD", "LocalZone-Realm")
    Check(activity:GetAll()[1].characterKey, "LocalZone-Realm")
    f.zone = 20
    Check(activity:GetAll()[1].characterKey, "Other-Realm")
    Check(activity:Receive("OFF", "GUILD", "Other-Realm"), true)
    Check(activity:GetPeer("Other-Realm"), nil)
end)

Test("visibility changes leave the shared channel; marker toggles retain peers", function(f)
    local db, activity = ForeverRP.Database, ForeverRP.Activity
    db:SetActivitySetting("enabled", true); activity:Tick()
    activity:Receive("A1|v|0|public|10|-|-|-", "GUILD", "Peer-Realm")
    local before = #f.sent
    db:SetActivitySetting("markers", true)
    Check(activity:GetPeer("Peer-Realm") ~= nil, true)
    Check(#f.sent, before)
    db:SetPrivacyMode("restricted")
    Check(f.joined, 0)
    activity:Tick(); Check(f.joined, 0)
end)

Test("failed revocations retry at most three times", function(f)
    local auth = ForeverRP.ProfileAuthorization
    f:Request(); f:Drain()
    ForeverRP.Database:SetDisclosureMode("approval")
    f.result = 3
    local before = #f.sent
    for _ = 1, 10 do f.now = f.now + 1; auth:Tick() end
    Check(#f.sent - before, 3)
    Check(next(auth.revocations), nil)
end)

Test("activity cache caps peers predictably and rejects receive floods", function(f)
    local activity = ForeverRP.Activity
    ForeverRP.Database:SetActivitySetting("enabled", true)
    for index = 1, 260 do
        f.now = 100 + math.floor(index / 50)
        activity:Receive("A1|v|0|public|10|-|-|-", "GUILD", "Peer" .. index .. "-Realm")
    end
    Check(#activity:GetAll(), 250)
    Check(activity:GetPeer("Peer1-Realm") ~= nil, true)
    Check(activity:GetPeer("Peer260-Realm"), nil)
    f.now = f.now + 200; activity:Tick()
    Check(#activity:GetAll(), 0)
    local before = activity.counters.received
    for _ = 1, 150 do activity:Receive("invalid", "GUILD", "Peer-Realm") end
    Check(activity.counters.received - before <= 100, true)
end)

Test("privacy UI routes disclosure, approvals and markers to real modules", function(f)
    local Widget = {}; Widget.__index = Widget
    for _, method in ipairs({"SetPoint", "SetWidth", "SetJustifyH", "SetSize", "SetAllPoints", "SetScrollChild", "SetHeight", "ClearAllPoints"}) do
        Widget[method] = function() end
    end
    function Widget:CreateFontString() return setmetatable({}, Widget) end
    function Widget:SetText(value) self.text = value end
    function Widget:SetScript(event, callback) self[event] = callback end
    function Widget:Show() self.shown = true end
    function Widget:Hide() self.shown = false end
    function Widget:SetShown(value) self.shown = value end
    CreateFrame = function() return setmetatable({}, Widget) end
    local choices = {}
    UIDropDownMenu_SetWidth = function() end
    UIDropDownMenu_Initialize = function(_, callback) callback(nil, 1) end
    UIDropDownMenu_CreateInfo = function() return {} end
    UIDropDownMenu_AddButton = function(info) choices[info.value] = info.func end
    UIDropDownMenu_SetSelectedValue, UIDropDownMenu_SetText = function() end, function() end
    dofile("ForeverRP/UI/DiscoveryOptions.lua")
    local options = ForeverRP.DiscoveryOptions
    options:Create({})
    choices.approval()
    Check(ForeverRP.Database:GetDisclosureMode(), "approval")
    choices.zone(); Check(ForeverRP.Database:GetActivitySettings().location, "zone")
    options.experimental.OnClick(); Check(ForeverRP.Database:GetActivitySettings().enabled, true)
    options.markers.OnClick(); Check(ForeverRP.Database:GetActivitySettings().markers, true)
    f:Request()
    Check(options.rows[1].primary.text, "Approve")
    options.rows[1].primary.OnClick(); f:Drain()
    Check(next(ForeverRP.ProfileAuthorization.pending), nil)
    Check(f.sent[#f.sent].payload:match("^PROFILE_DATA|") ~= nil, true)
    f.now = f.now + 11; f:Request("Other-Realm")
    options.rows[1].deny.OnClick()
    Check(f.sent[#f.sent].payload:match("|denied$") ~= nil, true)
    f:Peer(); ForeverRP.Connections:Remember("Peer-Realm", false); options:Refresh()
    options.rows[1].primary.OnClick()
    Check(ForeverRP.Database.character.profileApprovals["peer-realm"], true)
    options.rows[1].primary.OnClick()
    Check(ForeverRP.Database.character.profileApprovals["peer-realm"], nil)
end)

Test("lazy cache expiry clears an open viewer and Hidden Forget removes grants", function(f)
    local refreshed
    ForeverRP.ProfileViewer = {RefreshIfViewing = function(_, peer) refreshed = peer end,
        RefreshConnectionActions = function() end, Refresh = function() end}
    f:Peer()
    ForeverRP.RemoteProfiles:StoreProfile("Peer-Realm", ForeverRP.ProfileTransfer:GetSimulatedProfile(), {})
    f.now = f.now + 301
    Check(ForeverRP.RemoteProfiles:GetProfile("Peer-Realm", false), nil)
    Check(refreshed, "Peer-Realm")
    ForeverRP.Connections:Remember("Peer-Realm", false)
    ForeverRP.ProfileAuthorization:SetConnectionApproval("Peer-Realm", true)
    ForeverRP.Database:SetPrivacyMode("hidden")
    ForeverRP.Connections:Forget("Peer-Realm", false)
    Check(ForeverRP.Database.character.profileApprovals["peer-realm"], nil)
end)

print(string.format("PASS: %d enhanced discovery cases; %d checks (mocks only)", cases, checks))
