local Fixture = dofile("tests/helpers/client_fixture.lua")
local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function Test(name, callback)
    callback(Fixture()); cases = cases + 1; print("PASS " .. name)
end
local function Count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local function Packet(directory, status, availability, zone, subzone)
    return table.concat({"A2", "v", "0", "public", zone or 10, "-", "-", "-",
        directory == false and "0" or "1", status or "IC", availability or "NORMAL", "0", subzone or ""}, "|")
end
local function Enable() ForeverRP.Database:SetActivitySetting("enabled", true) end

Test("shared cache cannot evict a confirmed legacy peer; legacy ingress preserves metadata", function(f)
    local a, p = ForeverRP.Activity, ForeverRP.Presence
    Enable(); f:Peer("Nearby-Realm")
    for i = 1, 260 do
        f.now = 101 + math.floor(i / 50)
        a:Receive(Packet(), "GUILD", "Directory" .. i .. "-Realm")
    end
    Check(p:IsConfirmed("Nearby-Realm", false), true)
    Check(Count(p.players), 250)
    Check(#a:GetAll(), 249)
    Check(a.peers, nil)
    f:Peer("NewLegacy-Realm")
    Check(p:IsConfirmed("NewLegacy-Realm", false), true)
    Check(p:IsConfirmed("Nearby-Realm", false), true)
    local entry = a:GetAll()[1]
    p:Update(entry.characterKey, {addonVersion = "v", protocolVersion = 1})
    Check(p.players[entry.characterKey].activity, entry)
end)

Test("historical GUILD metadata cannot restore revoked relationship trust", function(f)
    local db, a, privacy = ForeverRP.Database, ForeverRP.Activity, ForeverRP.Privacy
    IsInGuild = function() return true end
    GetNumGuildMembers = function() return 1 end
    GetGuildRosterInfo = function() return "Peer-Realm" end
    db:SetPrivacyMode("restricted"); Enable()
    Check(a:Receive(Packet(), "GUILD", "Peer-Realm"), true)
    IsInGuild = function() return false end
    GetNumGuildMembers = function() return 0 end
    privacy:OnRelationshipsChanged()
    f.now = f.now + 1; a:Tick()
    Check(privacy:CanInteract("Peer-Realm", "WHISPER", false), false)
    Check(a:GetPeer("Peer-Realm"), nil)
    f:Request(); f:Drain()
    local chunks = 0; for _, sent in ipairs(f.sent) do if sent.payload:match("^PROFILE_DATA|") then chunks = chunks + 1 end end
    Check(chunks, 0)
end)

Test("revocation retains raw realm address and never queues unserved contacts", function(f)
    local a, comm = ForeverRP.ProfileAuthorization, ForeverRP.Communication
    local raw = "Peer-ForeverRP-ClassicBetaPvE"
    comm:HandleIncoming("FOREVERRP", "HELLO|1|v", "GUILD", raw, false)
    local key = ForeverRP.Presence:NormalizeCharacterKey(raw)
    Check(ForeverRP.ProfileTransfer:SendProfile(key, "P1", raw), true); f:Drain()
    f.sent = {}; ForeverRP.Database:SetPrivacyMode("hidden")
    f.now = f.now + 1; a:Tick()
    Check(f.sent[1].target, raw)
    ForeverRP.Database:SetPrivacyMode("visible", true)
    local before = Count(a.revocations)
    for i = 1, 260 do
        local peer = "Contact" .. i .. "-Realm"
        ForeverRP.Connections:Remember(peer, false)
        a:SetConnectionApproval(peer, true); a:SetConnectionApproval(peer, false)
    end
    Check(Count(a.revocations), before)
    for i = 1, 200 do a:MarkServed("Served" .. i .. "-Realm", "Raw" .. i .. "-Realm") end
    a:Reset(); Check(Count(a.served), 100); Check(Count(a.revocations), 100)
end)

Test("new authorized data cancels a stale revocation", function(f)
    local auth = ForeverRP.ProfileAuthorization
    f:Request("A-Realm"); f:Drain(); f:Request("B-Realm"); f:Drain()
    ForeverRP.Database:SetDisclosureMode("approval"); ForeverRP.Database:SetDisclosureMode("public")
    f.now = 111; auth:Tick()
    local key, notice = next(auth.revocations)
    Check(notice ~= nil, true)
    f:Request(notice.peer, "P2"); f:Drain()
    Check(auth.revocations[key], nil)
    local before = #f.sent; f.now = 112; auth:Tick(); Check(#f.sent, before)
end)

Test("real timer delays complete admitted large profiles and explicitly reject excess work", function(f)
    local a = ForeverRP
    local profile = a.Profile:Get()
    for _, field in ipairs({"description", "history", "oocNotes", "atAGlance"}) do
        profile[field] = string.rep("%", a.Constants.PROFILE_LIMITS[field])
    end
    local chunks = #a.ProfileTransfer:BuildChunks(a.ProfileTransfer:SerializeProfile(profile))
    Check(chunks > 200, true)
    f.timers = {}
    C_Timer.After = function(delay, run) f.timers[#f.timers + 1] = {at = f.now + delay, run = run} end
    a.Database:SetDisclosureMode("approval")
    for i = 1, 3 do
        f:Request("Peer" .. i .. "-Realm")
        Check(a.ProfileAuthorization:Decide("Peer" .. i .. "-Realm", true), i == 1)
    end
    for _ = 1, 1000 do
        table.sort(f.timers, function(x, y) return x.at < y.at end)
        local event = table.remove(f.timers, 1); if not event then break end
        f.now = event.at; a.ProfileAuthorization:Tick(); event.run()
    end
    local delivered, busy = 0, 0
    for _, packet in ipairs(f.sent) do
        if packet.payload:match("^PROFILE_DATA|") then
            Check(packet.target, "Peer1-Realm"); delivered = delivered + 1
        elseif packet.payload:match("|busy$") then busy = busy + 1 end
    end
    Check(delivered, chunks); Check(busy, 2)
    Check(#a.ProfileTransfer.outgoingResponseOrder, 0)
    Check(f.now < 130, true)
end)

Test("bounded prefix retries recover without enabling the feature by default", function(f)
    local a = ForeverRP.Activity; local attempts = 0
    ForeverRP.Communication.RegisterCompatibilityPrefix = function() attempts = attempts + 1; return attempts == 3 end
    a:Tick(); Check(attempts, 0); Enable()
    for i = 1, 35 do f.now = 100 + i; a:Tick() end
    Check(attempts, 3); Check(a.registered, true)
    ForeverRP.Database:SetActivitySetting("enabled", false)
    ForeverRP.Communication.RegisterCompatibilityPrefix = function() attempts = attempts + 1; return false end
    Enable(); attempts = 0
    for i = 1, 200 do f.now = 200 + i; a:Tick() end
    Check(attempts, 3)
end)

Test("directory defaults, location preference and reload retain independent opt-ins", function(f)
    local db, a = ForeverRP.Database, ForeverRP.Activity
    Check(db:GetActivitySettings().directory, false); Check(db:GetActivitySettings().subzone, false)
    db:SetActivitySetting("directory", true)
    Check(a:Enabled(), false); Check(db:GetActivitySettings().location, "hidden")
    Enable(); db:SetActivitySetting("subzone", true)
    local payload = a:Payload()
    Check(payload:find("|0|-|-|-|1|OOC|NORMAL|0|", 1, true) ~= nil, true)
    Check(payload:find("Brill", 1, true), nil)
    db:Initialize(); Check(db:GetActivitySettings().directory, true); Check(db:GetActivitySettings().subzone, true)
    db:SetPrivacyMode("hidden"); Check(a:Enabled(), false)
end)

Test("directory opt-in, status, AFK, DND, zone and literal name filtering are local", function(f)
    local a = ForeverRP.Activity; Enable()
    local records = {{"IC", "NORMAL", 10}, {"LFRP", "NORMAL", 20}, {"OOC", "NORMAL", 10}, {"IC", "AFK", 10}, {"IC", "DND", 10}}
    for i, record in ipairs(records) do a:Receive(Packet(true, record[1], record[2], record[3]), "GUILD", "Name " .. i .. "-Realm") end
    a:Receive(Packet(false), "GUILD", "OptedOut-Realm")
    a:Receive("A1|v|0|public|10|-|-|-", "GUILD", "Legacy-Realm")
    Check(#a:QueryDirectory(), 2)
    Check(#a:QueryDirectory({status = "ALL"}), 4)
    Check(#a:QueryDirectory({status = "IC"}), 1)
    Check(#a:QueryDirectory({zone = 20}), 1)
    Check(#a:QueryDirectory({search = "name 2"}), 1)
    Check(#a:QueryDirectory({search = ".*"}), 0)
    Check(#f.sent, 0)
end)

Test("metadata rejects malformed text/coordinates and opt-out removes listings promptly", function(f)
    local a = ForeverRP.Activity; Enable()
    Check(a:Receive(Packet(true, "BOGUS"), "GUILD", "Peer-Realm"), false)
    Check(a:Receive(Packet(true, "IC", "NORMAL", 10, "%7Cevil"), "GUILD", "Peer-Realm"), false)
    Check(a:Receive(Packet(true, "IC", "NORMAL", 10, "Brill"), "GUILD", "Peer-Realm"), true)
    Check(#a:QueryDirectory(), 1)
    Check(a:Receive(Packet(false), "GUILD", "Peer-Realm"), true)
    Check(#a:QueryDirectory(), 0)
    f.now = f.now + 6
    Check(a:Receive(Packet(), "GUILD", "Peer-Realm"), true)
    Check(a:Receive(Packet(true, "IC", "DND"), "GUILD", "Peer-Realm"), true)
    Check(#a:QueryDirectory({status = "ALL"}), 0)
end)

Test("continent metadata and subzones follow explicit sharing with guarded API values", function(f)
    local a, db = ForeverRP.Activity, ForeverRP.Database
    Enum = {UIMapType = {Continent = 2}}
    C_Map.GetMapInfo = function(id)
        if id == 10 then return {mapType = 3, parentMapID = 1000} end
        return {mapType = 2, parentMapID = 0}
    end
    db:SetActivitySetting("location", "zone"); db:SetActivitySetting("subzone", true)
    Check(a:Region(10), 1000)
    Check(a:Payload():match("|1000|Brill$") ~= nil, true)
    C_Map.GetMapInfo = function() return f.secret end; Check(a:Region(10), 0)
    f.subzone = f.secret; Check(a:Payload():match("|0|$") ~= nil, true)
    Enum = nil
end)

Test("temporary AFK/DND preserve selected LF RP and legacy profile compatibility", function(f)
    local a, profile = ForeverRP.Activity, ForeverRP.Profile
    Check(profile:SetField("status", "LFRP"), true)
    f.afk = true; Check(a:Availability(), "AFK"); Check(profile:GetField("status"), "LFRP")
    f.dnd = true; Check(a:Availability(), "DND")
    f.afk, f.dnd = false, false; Check(a:Availability(), "NORMAL")
    local encoded = ForeverRP.ProfileTransfer:SerializeProfile(profile:Get())
    Check(ForeverRP.ProfileTransfer:DeserializeProfile(encoded).status, "IC")
    Check(profile:GetField("status"), "LFRP")
    f.dnd = f.secret; Check(a:Availability(), "DND")
end)

Test("stationary markers survive a heartbeat, expire after loss, and project rotation/zoom", function(f)
    local a, markers = ForeverRP.Activity, ForeverRP.PlayerMarkers; Enable()
    a:Receive("A1|v|0|public|10|1|110|200", "GUILD", "Peer-Realm")
    local entry, here = a:GetPeer("Peer-Realm"), {zone = 10, space = 1, x = 100, y = 200}
    f.now = 210
    local x, y = markers:Project(entry, here, 100, 200, 200)
    Check(x, 0); Check(y, 10)
    local rx, ry = markers:Project(entry, here, 100, 200, 200, math.pi / 2)
    Check(math.abs(rx - 10) < 0.001, true); Check(math.abs(ry) < 0.001, true)
    local _, zoomed = markers:Project(entry, here, 50, 200, 200); Check(zoomed, 20)
    f.now = 226; Check(markers:Project(entry, here, 100, 200, 200), nil)
end)

Test("directory UI search is local and its explicit action uses the existing transfer", function(f)
    local Widget = {}; Widget.__index = Widget
    for _, method in ipairs({"SetPoint", "SetWidth", "SetJustifyH", "SetSize", "SetAllPoints", "SetScrollChild", "SetHeight", "SetAutoFocus", "SetMaxLetters", "ClearFocus", "RegisterEvent"}) do Widget[method] = function() end end
    function Widget:CreateFontString() return setmetatable({}, Widget) end
    function Widget:SetText(text) self.text = text end
    function Widget:GetText() return self.text or "" end
    function Widget:SetScript(event, run) self[event] = run end
    function Widget:Show() self.shown = true end
    function Widget:Hide() self.shown = false end
    function Widget:IsShown() return self.shown ~= false end
    function Widget:SetEnabled(value) self.enabled = value end
    CreateFrame = function() return setmetatable({}, Widget) end
    UIDropDownMenu_SetWidth = function() end
    UIDropDownMenu_Initialize = function(widget, callback) widget.initialize = callback end
    UIDropDownMenu_CreateInfo = function() return {} end
    UIDropDownMenu_SetText = function(widget, value) widget.text = value end
    local options = {}; UIDropDownMenu_AddButton = function(info) options[#options + 1] = info end
    dofile("ForeverRP/UI/Nearby.lua"); dofile("ForeverRP/UI/Activity.lua")
    Enable(); ForeverRP.Activity:Receive(Packet(), "GUILD", "Peer-Realm")
    local ui = ForeverRP.ActivityUI; ui:Create({})
    Check(#f.sent, 0); Check(ui.rows[1].request.text, "Request Profile")
    ui.search:SetText("peer"); ui.search.OnTextChanged(ui.search)
    ui.statusDropdown.initialize(nil, 1); options[3].func(); Check(#f.sent, 0)
    options[1].func(); ui.rows[1].request.OnClick()
    Check(f.sent[1].payload:match("^PROFILE_REQUEST|") ~= nil, true)
    Check(ui.rows[1].request.text, "Request pending")
    Check(ui.rows[1].request.enabled, false)
end)

Test("aggregate request rejection counters include cooldown and duplicate admission", function(f)
    local auth = ForeverRP.ProfileAuthorization
    f:Request(); Check(auth.denied, 0)
    f:Request(); Check(auth.denied, 1)
    f.now = f.now + 11
    f:Request(); Check(auth.denied, 2)
    Check(Count(ForeverRP.ProfileTransfer.outgoingResponses), 1)
end)

Test("expired response cleanup terminates and never sends overdue chunks", function(f)
    local transfer = ForeverRP.ProfileTransfer
    f:Peer(); Check(transfer:SendProfile("Peer-Realm", "Late1", "Peer-Realm"), true)
    f.now = 130
    Check(transfer:ProcessResponseQueue(), false)
    Check(Count(transfer.outgoingResponses), 0)
    Check(#transfer.outgoingResponseOrder, 0)
    Check(Count(transfer.outgoingResponsePeers), 0)
    Check(f.sent[#f.sent].payload:match("|busy$") ~= nil, true)
    f:Peer(); Check(transfer:SendProfile("Peer-Realm", "Late2", "Peer-Realm"), true)
    local key = transfer.outgoingResponseOrder[1]
    f.now = 160
    Check(transfer:RemoveResponse(key), true)
    Check(Count(transfer.outgoingResponses), 0)
    f:Drain(); Check(Count(transfer.outgoingResponses), 0)
end)

Test("combined lifecycle preserves Forever names, range entry, and directory isolation", function(f)
    local units = {player = {"Local", "Realm", "Local-Realm"},
        target = {"Linea", "Aspera", "Linea Aspera"},
        party2 = {"Ravisholan", "Ruefield", "Ravisholan Ruefield"}}
    f.realm = "ClassicBetaPvE"
    UnitExists = function(unit) return units[unit] ~= nil end
    UnitIsPlayer = UnitExists
    UnitFullName = function(unit) local u = units[unit]; if u then return u[1], u[2] end end
    UnitName = UnitFullName
    GetUnitName = function(unit) return units[unit] and units[unit][3] end
    local bracket = "WITHIN_30"
    CheckInteractDistance = function(_, index)
        if bracket == "UNKNOWN" then return nil end
        return bracket == "WITHIN_10" or bracket == "WITHIN_30" and index == 1
    end
    local ticks, pulse, refreshed = {}, 0, 0
    C_Timer.NewTicker = function(_, run) ticks[#ticks + 1] = run; return {} end
    ForeverRP.MinimapButton = {UpdateNearbyCount = function() end, Pulse = function() pulse = pulse + 1 end}
    ForeverRP.NearbyUI = {Refresh = function() refreshed = refreshed + 1 end}
    dofile("ForeverRP/Discovery/Range.lua")
    dofile("ForeverRP/Discovery/PlayerDetection.lua")
    dofile("ForeverRP/Discovery/ObservedDiscovery.lua")
    dofile("ForeverRP/Discovery/NearbyPlayers.lua")
    dofile("ForeverRP/UI/Notifications.lua")
    local db, p, nearby = ForeverRP.Database, ForeverRP.Presence, ForeverRP.NearbyPlayers
    db:SetDiscoveryRadius(30); db:SetNotificationSetting("sound", false)
    ForeverRP.ProfileAuthorization:Initialize(); ForeverRP.Activity:Initialize()
    nearby:Initialize(); nearby:Initialize(); Check(#ticks, 1)
    Check(ForeverRP.PlayerDetection:DetectUnit("target", "target"), true)
    Check(nearby:GetCount(false), 0)
    ForeverRP.Communication:HandleIncoming("FOREVERRP", "HELLO|1|0.1.1-beta.6", "PARTY", "Linea Aspera-ClassicBetaPvE", false)
    local key = "Linea Aspera-ClassicBetaPvE"
    Check(nearby:Get(key, false).unit, "target")
    Check(nearby:Get(key, false).rangeState, "WITHIN_30"); Check(pulse, 1)
    bracket = "WITHIN_10"; f.now = f.now + 1; ticks[1]()
    Check(nearby:Get(key, false).rangeState, "WITHIN_10"); Check(pulse, 1)
    Check(ForeverRP.PlayerDetection:DetectUnit("party2", "group"), true)
    ForeverRP.Communication:HandleIncoming("FOREVERRP", "ACK|1|0.1.1-beta.6", "WHISPER", "Ravisholan Ruefield-ClassicBetaPvE", false)
    Check(nearby:Get("Ravisholan Ruefield-ClassicBetaPvE", false).unit, "party2")
    Check(refreshed, 2)
    Enable(); db:SetActivitySetting("directory", true)
    Check(ForeverRP.Activity:Receive(Packet(), "GUILD", "Remote-ClassicBetaPvE"), true)
    Check(nearby:IsNearby("Remote-ClassicBetaPvE", false), false)
    Check(#ForeverRP.Activity:QueryDirectory(), 1)
    Check(ForeverRP.Activity:Receive(Packet(), "PARTY", key), true)
    Check(ForeverRP.Activity:Receive("OFF", "PARTY", key), true)
    Check(nearby:IsNearby(key, false), true); Check(pulse, 2)
    bracket = "UNKNOWN"; f.now = f.now + 1; ticks[1]()
    Check(nearby:IsNearby(key, false), false)
    Check(ForeverRP.Range:GetRangeState("target", key), "UNKNOWN")
    bracket = "WITHIN_10"; f.now = f.now + 1; ticks[1]()
    Check(nearby:IsNearby(key, false), true); Check(pulse, 2)
    local sent = #f.sent
    f.dnd = true; f.now = f.now + 1; ticks[1]()
    Check(f.sent[#f.sent].payload, "OFF")
    f.now = f.now + 1; ticks[1](); Check(#f.sent, sent + 2) -- ordered and legacy withdrawals
end)

print(string.format("PASS: %d directory/audit regression cases; %d checks (mocks only)", cases, checks))
