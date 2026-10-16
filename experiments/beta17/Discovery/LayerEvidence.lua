local Addon = ForeverRP
local Access = Addon.ValueAccess
-- Independent implementation. GUID components are candidates, not a documented layer API.
-- Comparisons remain experimental until controlled Forever-client validation is recorded.
local Evidence = {samples = {}, ttl = 120, maxSamples = 8, minimum = 3,
    session = math.random(1, 999999999), generation = 0}
Addon.LayerEvidence = Evidence
local function Now() return GetTime and GetTime() or 0 end
local function Integer(text, positive)
    if not Access:IsString(text) or #text > 9 or not text:match("^%d+$") then return nil end
    local n = tonumber(text)
    if positive and n == 0 then return nil end
    return n
end
function Evidence:Reset()
    self.samples, self.zone, self.suspended = {}, nil, false
end
function Evidence:Suspend()
    self:Reset()
    self.suspended = true
end
function Evidence:Zone()
    if not Addon.Activity:Enabled() or not GetBuildInfo or not IsInInstance then return nil end
    local _, _, _, interface = GetBuildInfo()
    local instanced = IsInInstance()
    if not Access:CanAccess(interface, instanced) or interface ~= 16001 or instanced ~= false then return nil end
    local zone = Addon.Activity:CurrentZone()
    return zone > 0 and zone == math.floor(zone) and zone or nil
end
function Evidence:Prune()
    if self.suspended then return nil end
    local zone = self:Zone()
    if zone ~= self.zone then self:Reset(); self.zone = zone end
    local now = Now()
    for i = #self.samples, 1, -1 do
        if now - self.samples[i].at >= self.ttl or now < self.samples[i].at then table.remove(self.samples, i) end
    end
    return zone
end
function Evidence:Observe(unit)
    if not Access:IsString(unit) or not (unit == "target" or unit == "mouseover" or unit:match("^nameplate%d+$")) then return false end
    if not self:Prune() or not UnitGUID then return false end
    local guid = UnitGUID(unit)
    if not Access:IsString(guid) or #guid > 100 then return false end
    -- Exclude pets/vehicles: their origin may differ from the observer's world.
    local server, map, scope, npc, spawn = guid:match("^Creature%-0%-(%d+)%-(%d+)%-(%d+)%-(%d+)%-([%x]+)$")
    server, map, scope, npc = Integer(server, true), Integer(map), Integer(scope, true), Integer(npc, true)
    if not server or not map or not scope or not npc or not spawn or #spawn > 16 then return false end
    for _, sample in ipairs(self.samples) do if sample.guid == guid then return false end end
    self.generation = self.generation + 1
    self.samples[#self.samples + 1] = {guid = guid, id = server .. ":" .. map .. ":" .. scope, at = Now()}
    if #self.samples > self.maxSamples then table.remove(self.samples, 1) end
    return true
end
function Evidence:GetLocal()
    local zone = self:Prune()
    if not zone or #self.samples < self.minimum then return nil end
    local first = self.samples[1]
    for _, sample in ipairs(self.samples) do if sample.id ~= first.id then return nil end end
    return {zone = zone, id = first.id, count = #self.samples, at = first.at}
end
function Evidence:Payload()
    local settings = Addon.Database:GetActivitySettings()
    if not Addon.Activity:Enabled() or not settings.directory or settings.location == "hidden" or Addon.Activity:Availability() == "DND" then return nil end
    local value = self:GetLocal()
    if not value then return "L1|OFF" end
    return table.concat({"L1", value.zone, value.id, value.count, math.ceil(Now() - value.at),
        self.session .. ":" .. self.generation}, "|")
end
function Evidence:WithdrawPeer(key)
    local state = key and Addon.Activity:OrderState("layer", key)
    if state and not state.withdrawn then state.withdrawn, state.at = true, Now() end
end
function Evidence:Receive(payload, entry, key)
    key = key or entry and entry.characterKey
    if payload == "L1|OFF" then
        self:WithdrawPeer(key)
        if entry then entry.layerEvidence = nil; return true, "layer-withdrawal" end
        return false, "layer-base-unavailable"
    end
    -- Optional companion metadata cannot create presence or renew coordinates.
    if not entry or not entry.directory or entry.zone <= 0 or entry.availability == "DND" then return false, "layer-base-unavailable" end
    local zone, server, map, scope, count, age, session, generation = payload:match("^L1|(%d+)|(%d+):(%d+):(%d+)|(%d+)|(%d+)|(%d+):(%d+)$")
    zone, server, map, scope, count, age = Integer(zone, true), Integer(server, true), Integer(map), Integer(scope, true), Integer(count), Integer(age)
    if not zone or not server or not map or not scope or not count or not age
        or not Integer(session, true) or not Integer(generation, true)
        or zone ~= entry.zone or count < self.minimum or count > self.maxSamples or age >= self.ttl then return false, "invalid-or-stale-layer-evidence" end
    if not key then return false, "layer-peer-unavailable" end
    local allowed, reason, outcome = Addon.Activity:CheckOrder("layer", key, session, tonumber(generation))
    if not allowed then return false, reason, outcome end
    local value = {zone = zone, id = server .. ":" .. map .. ":" .. scope, count = count, at = Now() - age,
        proof = session .. ":" .. generation}
    -- Identical retransmissions must not extend the evidence's lifetime.
    Addon.Activity:CommitOrder("layer", key, session, tonumber(generation))
    entry.layerEvidence = value
    return true, "layer-evidence-stored"
end
function Evidence:GetRemote(entry)
    local value = entry and entry.layerEvidence
    if not value or value.zone ~= entry.zone or not entry.directory or entry.zone <= 0
        or Now() < value.at or Now() - value.at >= self.ttl or Now() - entry.at > 150 then return nil end
    return value
end
function Evidence:Compare(entry)
    local own, remote = self:GetLocal(), self:GetRemote(entry)
    if not own or not remote or own.zone ~= remote.zone then return "UNKNOWN", "insufficient-or-different-zone" end
    if own.id:match("^%d+:(%d+):") ~= remote.id:match("^%d+:(%d+):") then return "UNKNOWN", "different-guid-map" end
    return own.id == remote.id and "SAME" or "DIFFERENT", "inferred-unvalidated"
end
function Evidence:Report()
    local own = self:GetLocal()
    Addon:Print("Layer inference EXPERIMENTAL; live accuracy unverified. zone=" .. (self.zone or "unknown")
        .. " id=" .. (own and own.id or "unknown") .. " observations=" .. #self.samples
        .. " age=" .. (own and math.floor(Now() - own.at) or "unknown"))
    local count = 0
    for _, entry in ipairs(Addon.Activity:GetAll()) do
        if count >= 8 then break end
        local remote = self:GetRemote(entry)
        Addon:Print("Layer evidence peer=[" .. Addon:EscapePlainText(entry.characterKey) .. "] zone=" .. entry.zone
            .. " id=" .. (remote and remote.id or "unknown") .. " observations=" .. (remote and remote.count or 0)
            .. " age=" .. (remote and math.floor(Now() - remote.at) or "unknown"))
        count = count + 1
    end
end
