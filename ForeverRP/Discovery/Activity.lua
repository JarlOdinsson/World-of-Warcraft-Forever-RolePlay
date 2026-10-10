local Addon = ForeverRP
local Access = Addon.ValueAccess
-- Experimental metadata only; no profile contents and no relaying.
local Activity = {prefix = "FOREVERRPX1", channelName = "ForeverRPActivity",
    counters = {sent = 0, received = 0, throttled = 0, duplicates = 0, expired = 0}, revision = 0}
Addon.Activity = Activity
local function Now() return GetTime and GetTime() or 0 end
local function Number(value, limit)
    return Access:CanAccess(value) and type(value) == "number" and value == value
        and math.abs(value) <= (limit or 100000) and value or nil
end
local function Encode(value)
    return (value:gsub("([^%w%s%-%_%.])", function(c) return string.format("%%%02X", c:byte()) end))
end
local function Decode(value)
    if value:gsub("%%[%x][%x]", ""):find("%%", 1, true) then return nil end
    value = value:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    if #value > 64 or value:find("[%c|]") then return nil end
    return value
end

function Activity:GetPeer(key)
    key = Addon.Presence:ResolveKnownKey(key, false) or key
    local player = Addon.Presence.players[key]
    return player and player.activity
end

function Activity:Availability()
    local status = Addon.Profile:GetField("status")
    local afk = UnitIsAFK and UnitIsAFK("player")
    local dnd = UnitIsDND and UnitIsDND("player")
    if not Access:CanAccess(afk, dnd) then return "DND" end
    if dnd == true or dnd == 1 or status == "DND" then return "DND" end
    if afk == true or afk == 1 or status == "AFK" then return "AFK" end
    return "NORMAL"
end

-- Region means the continent in the supported map hierarchy, never a server region.
function Activity:Region(zone)
    local seen = {}
    for _ = 1, 8 do
        if not Number(zone) or zone <= 0 or seen[zone] or not C_Map or not C_Map.GetMapInfo then return 0 end
        seen[zone] = true
        local info = C_Map.GetMapInfo(zone)
        if not Access:CanAccess(info) or type(info) ~= "table" or not Access:CanAccess(info.mapType, info.parentMapID) then return 0 end
        if Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Continent then return zone end
        zone = info.parentMapID
    end
    return 0
end

function Activity:Enabled()
    return Addon.Database:GetActivitySettings().enabled and Addon.Database:IsDiscoveryEnabled()
        and Addon.Database:GetPrivacyMode() ~= "hidden"
end

-- Explanations only: keep the existing networking/privacy gates above unchanged.
function Activity:GetNetworkingBlockers()
    local blockers = {}
    if not Addon.Database:IsDiscoveryEnabled() then
        blockers[#blockers + 1] = "Discovery disabled: enable discovery in Settings."
    end
    if Addon.Database:GetPrivacyMode() == "hidden" then
        blockers[#blockers + 1] = "Hidden visibility blocks networking: Settings > Discovery Visibility."
    end
    if not Addon.Database:GetActivitySettings().enabled then
        blockers[#blockers + 1] = "Experimental Network OFF: enable in Privacy > Experimental Network."
    end
    return blockers
end

function Activity:GetNetworkingStatus()
    local settings = Addon.Database:GetActivitySettings()
    local paused = {}
    if not Addon.Database:IsDiscoveryEnabled() then paused[#paused + 1] = "discovery disabled" end
    if Addon.Database:GetPrivacyMode() == "hidden" then paused[#paused + 1] = "Hidden visibility" end
    if not settings.enabled then return "Saved preference: OFF. Networking disabled." end
    if #paused > 0 then return "Saved preference: ON - paused by " .. table.concat(paused, " and ") .. "." end
    return "Settings permit networking; connection and delivery are not confirmed."
end

function Activity:TakeBudget()
    local now = Now()
    self.tokens = math.min(3, (self.tokens or 3) + math.max(0, now - (self.tokenAt or now)))
    self.tokenAt = now
    if self.tokens < 1 then return false end
    self.tokens = self.tokens - 1
    return true
end

function Activity:Location()
    local mode = Addon.Database:GetActivitySettings().location
    if mode == "hidden" then return {zone = 0} end
    local zone = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    zone = Number(zone, 100000)
    if not zone or zone <= 0 then return {zone = 0} end
    local location = {zone = math.floor(zone)}
    if mode == "precise" and UnitPosition then
        local x, y, z, space = UnitPosition("player")
        if Number(x) and Number(y) and Number(z) and Number(space, 100000)
            and space >= 0 and (x ~= 0 or y ~= 0) then
            location.x, location.y, location.space = x, y, math.floor(space)
        end
    end
    return location
end

function Activity:CurrentZone()
    local zone = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    return Number(zone) or 0
end

function Activity:Payload()
    local l = self:Location()
    local settings = Addon.Database:GetActivitySettings()
    local availability = self:Availability()
    local state = Addon.Profile:GetField("status")
    if state ~= "IC" and state ~= "LFRP" then state = "OOC" end
    local subzone = settings.subzone and l.zone > 0 and GetSubZoneText and GetSubZoneText()
    subzone = Access:IsString(subzone) and subzone:sub(1, 64) or ""
    if subzone:find("[%c|]") then subzone = "" end
    local head = table.concat({"A2", Addon.Constants.ADDON_VERSION, self.revision,
        Addon.Database:GetDisclosureMode(), l.zone, l.space or "-",
        l.x and string.format("%.1f", l.x) or "-", l.y and string.format("%.1f", l.y) or "-",
        settings.directory and availability ~= "DND" and "1" or "0", state, availability,
        self:Region(l.zone)}, "|")
    local encoded = Encode(subzone)
    if #head + #encoded + 1 > 200 then encoded = "" end
    return head .. "|" .. encoded
end

function Activity:Routes()
    local routes = {}
    for _, channel in ipairs(Addon.Communication:GetBroadcastChannels()) do
        routes[#routes + 1] = {channel = channel}
    end
    if Addon.Database:GetPrivacyMode() == "visible" then
        local id = self:SharedChannelID()
        if id then routes[#routes + 1] = {channel = "CHANNEL", target = tostring(id)} end
    end
    return routes
end

function Activity:SharedChannelID()
    local id = GetChannelName and GetChannelName(self.channelName)
    return Number(id, 1000) and id > 0 and id == math.floor(id) and id or nil
end

function Activity:MaintainChannel(now)
    if Addon.Database:GetPrivacyMode() ~= "visible" then return end
    local id = self:SharedChannelID()
    if id then
        self.joined, self.joinAttempts, self.joinAt = true, 0, nil
        return
    end
    -- Recover a lost confirmed membership. A join call alone is not evidence.
    if self.joined then self.joinAttempts, self.joinAt = 0, nil end
    self.joined = false
    if not JoinChannelByName or (self.joinAttempts or 0) >= 3 or now < (self.joinAt or 0) then return end
    self.joinAttempts = (self.joinAttempts or 0) + 1
    self.joinAt, self.joinRequested = now + 10, true
    JoinChannelByName(self.channelName)
end

function Activity:OnWorldChanged()
    -- Rearm exhausted joins on a real reconnect/world transition, not chat noise.
    local now = Now()
    if self.worldRetryAt and now < self.worldRetryAt then return end
    self.worldRetryAt = now + 30
    self.joinAttempts, self.joinAt = 0, nil
    if not self.registered then self.registrationAttempts, self.registrationAt = 0, 0 end
end

function Activity:ReportTransport()
    local function Safe(value)
        if not Access:CanAccess(value) then return "unavailable" end
        return Addon:EscapePlainText(tostring(value == nil and "none" or value))
    end
    local id = self:SharedChannelID()
    Addon:Print("Directory transport: build=" .. Addon.Constants.DIAGNOSTIC_BUILD
        .. " eligible=" .. tostring(self:Enabled()) .. " prefix=" .. tostring(self.registered == true)
        .. " sendAPI=" .. ((C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage) and "available" or "unavailable"))
    Addon:Print("Shared channel: " .. self.channelName .. " localID=" .. Safe(id)
        .. " membership=" .. (id and "observed" or "not-observed")
        .. " joinAttempts=" .. (self.joinAttempts or 0) .. "/3"
        .. ((self.joinAttempts or 0) >= 3 and " (stopped; retry on world transition/reload/settings reset)" or ""))
    local routes = {}
    for _, route in ipairs(self:Routes()) do routes[#routes + 1] = route.channel .. ":" .. (route.target or "broadcast") end
    Addon:Print("Directory routes: " .. (#routes > 0 and table.concat(routes, ", ") or "none")
        .. "; queued=" .. #(self.queue or {}))
    for _, blocker in ipairs(self:GetNetworkingBlockers()) do Addon:Print(blocker) end
    for _, channel in ipairs({"CHANNEL", "PARTY", "RAID", "INSTANCE_CHAT", "GUILD"}) do
        local sent, received = (self.lastSends or {})[channel], (self.lastReceives or {})[channel]
        if sent then
            Addon:Print("Directory send " .. channel .. " target=" .. Safe(sent.target)
                .. " age=" .. math.max(0, math.floor(Now() - sent.at)) .. "s enqueue="
                .. (sent.accepted and "accepted" or "rejected") .. " reason=" .. Safe(sent.reason)
                .. " result=" .. Safe(sent.result))
        end
        if received then
            Addon:Print("Directory remote receipt " .. channel .. " sender=[" .. Safe(received.sender)
                .. "] age=" .. math.max(0, math.floor(Now() - received.at)) .. "s localID="
                .. Safe(received.localID) .. " name=[" .. Safe(received.name) .. "]")
        end
    end
    Addon:Print("Enqueue is not delivery. Shared-channel/cross-layer coverage is unverified; layer remains Unknown.")
end

function Activity:Withdraw()
    if self.registered and self.wasEnabled then
        for _, route in ipairs(self:Routes()) do
            Addon.Communication:SendActivity("OFF", route.channel, route.target)
        end
    end
end

function Activity:Reset()
    if (self.joined or self.joinRequested) and LeaveChannelByName then LeaveChannelByName(self.channelName) end
    self.joined = false
    self.joinRequested, self.joinAttempts, self.joinAt = nil, 0, nil
    self.routeSignature, self.retryAt = nil, nil
    for _, entry in ipairs(Addon.Presence:GetActivityRecords()) do Addon.Presence:ClearActivity(entry.characterKey) end
    self.queue, self.lastPayload, self.nextAt = {}, nil, 0
    self.lastLocation, self.heartbeatAt = nil, 0
    self.wasEnabled = false
    self.registrationAttempts, self.registrationAt = 0, 0
    if Addon.ActivityUI then Addon.ActivityUI:Refresh() end
    if Addon.PlayerMarkers then Addon.PlayerMarkers:Refresh() end
end

function Activity:Changed(disclosure)
    if disclosure then self.revision = self.revision + 1 end
    -- UI/zone events cannot bypass the minimum announcement interval.
end

function Activity:Initialize()
    if self.initialized then return end
    self.initialized = true
    self.queue = {}
    -- Serviced by the existing one-second Nearby lifecycle ticker.
end

function Activity:Tick()
    local now = Now()
    Addon.Presence:Expire()
    if not self:Enabled() then
        if self.wasEnabled then self:Reset() end
        return
    end
    if not self.wasEnabled then
        self.wasEnabled = true
        self.registered = false
    end
    -- Explicit opt-in only. Never send visible chat messages or poll rosters.
    self:MaintainChannel(now)
    if not self.registered and (self.registrationAttempts or 0) < 3 and now >= (self.registrationAt or 0) then
        self.registrationAttempts = (self.registrationAttempts or 0) + 1
        self.registrationAt = now + 10
        self.registered = Addon.Communication:RegisterCompatibilityPrefix(self.prefix) == true
    end
    if not self.registered then return end
    self.queue = self.queue or {}
    local routes, signature = self:Routes(), {}
    for _, route in ipairs(routes) do signature[#signature + 1] = route.channel .. ":" .. (route.target or "") end
    signature = table.concat(signature, "|")
    if signature ~= self.routeSignature then
        self.routeSignature = signature
        self.queue = {} -- Drop stale channel numbers and departed social routes.
        self.lastLocation = nil
        self.nextAt = math.max(now, (self.lastAnnouncement or (now - 30)) + 30)
    end
    local payload = self:Payload()
    local current = self:Location()
    local old = self.lastLocation
    local availability = self:Availability()
    -- A transition into DND withdraws an older directory advertisement promptly.
    -- This is a bounded state transition, not a heartbeat or a directory query.
    if old and old.availability ~= "DND" and availability == "DND" then
        self:Withdraw()
        old.availability = "DND"
    end
    local useful = not old or old.zone ~= current.zone or old.space ~= current.space
        or (old.x == nil) ~= (current.x == nil)
        or old.mode ~= Addon.Database:GetDisclosureMode() or old.revision ~= self.revision
        or old.directory ~= Addon.Database:GetActivitySettings().directory
        or old.status ~= Addon.Profile:GetField("status") or old.availability ~= self:Availability()
        or old.subzone ~= Addon.Database:GetActivitySettings().subzone
        or (old.x and current.x and (old.x - current.x)^2 + (old.y - current.y)^2 >= 100)
    if #routes > 0 and #self.queue == 0 and now >= (self.nextAt or 0)
        and (useful or now >= (self.heartbeatAt or 0)) then
        for _, route in ipairs(routes) do
            if #self.queue < 3 then
                self.queue[#self.queue + 1] = {route = route, payload = payload, attempts = 0}
            end
        end
        self.lastPayload, self.lastAnnouncement = payload, now
        current.mode, current.revision = Addon.Database:GetDisclosureMode(), self.revision
        current.directory, current.status, current.availability = Addon.Database:GetActivitySettings().directory,
            Addon.Profile:GetField("status"), self:Availability()
        current.subzone = Addon.Database:GetActivitySettings().subzone
        self.lastLocation = current
        self.nextAt = now + 30 + math.random(0, 10)
        self.heartbeatAt = now + 90 + math.random(0, 20)
    end
    local queued = self.queue[1]
    if queued and now >= (self.retryAt or 0) then
        -- Rebuild at send time so a privacy/location change cannot leak queued coordinates.
        local accepted, reason, result = Addon.Communication:SendActivity(self:Payload(), queued.route.channel, queued.route.target)
        self.lastSends = self.lastSends or {}
        self.lastSends[queued.route.channel] = {at = now, target = queued.route.target,
            accepted = accepted == true, reason = reason, result = result}
        queued.attempts = queued.attempts + 1
        if accepted then self.counters.sent = self.counters.sent + 1; table.remove(self.queue, 1)
        elseif queued.attempts >= 2 then table.remove(self.queue, 1) end
        if reason == "throttled" then self.counters.throttled = self.counters.throttled + 1 end
        self.retryAt = now + (accepted and 1 or 10)
    end
    if Addon.ActivityUI and self.uiDirty then
        self.uiDirty = false
        Addon.ActivityUI:Refresh()
    end
    if Addon.PlayerMarkers then Addon.PlayerMarkers:Refresh() end
end

function Activity:Receive(payload, channel, sender, localID, channelName)
    if not self:Enabled() or not Access:IsString(payload) or #payload > 200
        or not Access:IsString(channel) or not Access:IsString(sender) then return false end
    if channel ~= "CHANNEL" and channel ~= "GUILD" and channel ~= "PARTY"
        and channel ~= "RAID" and channel ~= "INSTANCE_CHAT" then return false end
    if not self.receiveWindow or Now() - self.receiveWindow >= 1 then
        self.receiveWindow, self.receiveCount = Now(), 0
    end
    self.receiveCount = self.receiveCount + 1
    if self.receiveCount > 100 then return false end
    local peer = Addon.Presence:NormalizeCharacterKey(sender)
    if not peer or Addon.Presence:IsSelf(peer) or not Addon.Privacy:CanInteract(peer, channel, false) then return false end
    self.counters.received = self.counters.received + 1
    local key = Addon.Presence:ResolveKnownKey(peer, false) or peer
    local existing = self:GetPeer(key)
    if payload == "OFF" then
        Addon.Presence:ClearActivity(key)
        if Addon.PlayerMarkers then Addon.PlayerMarkers:Refresh() end
        self.uiDirty = true
        return true
    end
    local base, directory, status, availability, region, subzone = payload:match("^(A2|[^|]+|%d+|%a+|%d+|[^|]+|[^|]+|[^|]+)|([01])|(%a+)|(%a+)|(%d+)|(.*)$")
    if base then
        base = "A1" .. base:sub(3)
        subzone, region = Decode(subzone), tonumber(region)
        if not subzone or not Number(region) or (status ~= "IC" and status ~= "OOC" and status ~= "LFRP")
            or (availability ~= "NORMAL" and availability ~= "AFK" and availability ~= "DND") then return false end
        directory = directory == "1" and availability ~= "DND"
    else base, directory, status, availability, region, subzone = payload, false, "OOC", "NORMAL", 0, "" end
    local version, revision, mode, zone, space, x, y = base:match("^A1|([%w%.%-]+)|(%d+)|(%a+)|(%d+)|([%d%-]+)|([%d%.%-]+)|([%d%.%-]+)$")
    if not version or #version > 32 or (mode ~= "public" and mode ~= "approval" and mode ~= "connections") then return false end
    zone, revision = tonumber(zone), tonumber(revision)
    if not Number(zone) or not Number(revision, 1000000000) then return false end
    if space ~= "-" or x ~= "-" or y ~= "-" then
        space, x, y = tonumber(space), tonumber(x), tonumber(y)
        if not Number(space) or space < 0 or not Number(x) or not Number(y) or zone <= 0 then return false end
    else space, x, y = nil, nil, nil end
    if zone == 0 and (region ~= 0 or subzone ~= "") then return false end
    if existing and existing.payload == payload and Now() - existing.at < 30 then
        self.counters.duplicates = self.counters.duplicates + 1
        return false
    end
    local withdrawing = existing and (not directory and existing.directory or availability == "DND"
        or not x and existing.x or zone == 0 and existing.zone > 0)
    if existing and Now() - existing.at < 5 and not withdrawing then return false end
    if existing and (existing.mode ~= mode or existing.revision ~= revision) or not existing and mode ~= "public" then
        Addon.RemoteProfiles:ClearProfile(key)
    end
    local entry = {characterKey = key, at = Now(), zone = zone, space = space, x = x, y = y,
        mode = mode, revision = revision, layer = "UNKNOWN", payload = payload, directory = directory,
        status = status, availability = availability, region = region, subzone = subzone}
    -- A direct valid exchange proves addon participation, never physical proximity.
    if not Addon.Presence:UpdateActivity(key, entry, version, sender) then return false end
    entry.receivedVia = channel
    self.lastReceives = self.lastReceives or {}
    self.lastReceives[channel] = {at = Now(), sender = sender,
        localID = Number(localID, 1000), name = Access:IsString(channelName) and channelName:sub(1, 100) or nil}
    self.uiDirty = true
    return true
end

function Activity:GetAll()
    local result, zone = {}, self:CurrentZone()
    for _, entry in ipairs(Addon.Presence:GetActivityRecords()) do result[#result + 1] = entry end
    table.sort(result, function(a, b)
        if (a.zone == zone) ~= (b.zone == zone) then return a.zone == zone end
        if a.zone ~= b.zone then return a.zone < b.zone end
        return a.characterKey < b.characterKey
    end)
    return result
end

function Activity:QueryDirectory(filters)
    filters = filters or {}
    local result = {}
    local search = type(filters.search) == "string" and string.lower(filters.search:sub(1, 100)) or ""
    for _, entry in ipairs(self:GetAll()) do
        if entry.directory and entry.availability ~= "DND"
            and (filters.status == "ALL" or entry.availability == "NORMAL" and (entry.status == "IC" or entry.status == "LFRP"))
            and (not filters.status or filters.status == "ALL" or filters.status == "DEFAULT" or entry.status == filters.status)
            and (not filters.zone or entry.zone == filters.zone)
            and string.lower(entry.characterKey):find(search, 1, true) then result[#result + 1] = entry end
    end
    return result
end
