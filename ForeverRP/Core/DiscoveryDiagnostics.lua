local Addon = ForeverRP
local Access = Addon.ValueAccess

-- Runtime-only metadata. Never retain packet payloads, profiles or notes.
local Diagnostics = { peers = {}, sends = {}, pipeline = {}, sequence = 0 }
Addon.DiscoveryDiagnostics = Diagnostics

local function Now()
    return GetTime and GetTime() or 0
end

local function Text(value)
    if not Access:CanAccess(value) then return "<inaccessible>" end
    if value == nil then return "-" end
    if type(value) ~= "string" and type(value) ~= "number" and type(value) ~= "boolean" then
        return "<invalid>"
    end
    return (tostring(value):sub(1, 120):gsub("%c", "?"):gsub("|", "||"))
end

local function Identity(value)
    return Access:IsString(value) and value:sub(1, 100) or Text(value)
end

local function Age(record)
    return record and string.format("%.1fs", math.max(0, Now() - record.at)) or "-"
end

local function Event(record)
    if not record then return "none" end
    return string.format("%s raw=%s key=%s via=%s decision=%s age=%s",
        Text(record.kind), Text(record.sender), Text(record.characterKey),
        Text(record.channel), Text(record.reason), Age(record))
end

function Diagnostics:RecordSend(kind, channel, accepted, reason, result)
    if kind ~= "HELLO" then return end
    self.lastSend = {at = Now(), channel = Identity(channel), accepted = accepted == true,
        reason = reason, result = Text(result)}
    if channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT" or channel == "GUILD" then
        self.sends[channel] = self.lastSend
    end
end

function Diagnostics:RecordIncoming(kind, sender, characterKey, channel, reason, simulated)
    if simulated or (kind ~= "HELLO" and kind ~= "ACK" and kind ~= "INVALID") then return end
    self.sequence = self.sequence + 1
    local record = {at = Now(), sequence = self.sequence, kind = kind,
        sender = Identity(sender), characterKey = Identity(characterKey),
        channel = Identity(channel), reason = reason}
    self.lastIncoming = record
    if kind == "HELLO" then self.lastHello = record end
    if kind == "ACK" then self.lastAck = record end
    -- Self echoes remain visible globally without evicting a remote peer.
    if reason == "self" then return end
    self.lastPeer = record
    local key = string.lower(record.characterKey ~= "-" and record.characterKey or record.sender)
    if not self.peers[key] then
        local count, oldestKey, oldestSequence = 0
        for peerKey, peer in pairs(self.peers) do
            count = count + 1
            if not oldestSequence or peer.sequence < oldestSequence then
                oldestKey, oldestSequence = peerKey, peer.sequence
            end
        end
        if count >= 20 then self.peers[oldestKey] = nil end
    end
    self.peers[key] = record
end

function Diagnostics:RecordEvaluation(characterKey, reason, unit, range, origin, unitCount)
    if not Access:IsString(characterKey) then return end
    local presence = Addon.Presence and Addon.Presence.players[characterKey]
    if presence and presence.simulated then return end
    local detection = Addon.PlayerDetection
    for token in pairs(detection and detection.characters[characterKey] or {}) do
        if detection.units[token] and detection.units[token].simulated then return end
    end
    local key = string.lower(characterKey)
    local old = self.pipeline[key]
    if not old then
        local count, oldestKey, oldestSequence = 0
        for peerKey, peer in pairs(self.pipeline) do
            count = count + 1
            if not oldestSequence or peer.sequence < oldestSequence then
                oldestKey, oldestSequence = peerKey, peer.sequence
            end
        end
        if count >= 20 then self.pipeline[oldestKey] = nil end
    end
    self.sequence = self.sequence + 1
    local record = {at = Now(), sequence = self.sequence, reason = reason, unit = unit,
        range = range, origin = origin or "reevaluate", unitCount = unitCount,
        count = old and old.count + 1 or 1, lastPresence = old and old.lastPresence}
    if origin == "presence-update" then
        record.lastPresence = {at = record.at, reason = reason, unit = unit, range = range}
    end
    self.pipeline[key] = record
end

function Diagnostics:RecordUIRefresh(created)
    self.uiRefresh = {at = Now(), created = created == true,
        count = self.uiRefresh and self.uiRefresh.count + 1 or 1, completed = false}
end

function Diagnostics:CompleteUIRefresh(rowCount)
    if self.uiRefresh then
        self.uiRefresh.completed = true
        self.uiRefresh.rowCount = rowCount
    end
end

-- Read the raw client values even when the association was never created.
-- A failed/restricted identity is evidence, never a reason to invent an alias.
local function UnitEvidence(unit)
    local exists = UnitExists and UnitExists(unit)
    if not Access:CanAccess(exists) or (exists ~= true and exists ~= 1) then
        return "unit=" .. unit .. " exists=" .. Text(exists)
    end
    local player = UnitIsPlayer and UnitIsPlayer(unit)
    if not Access:CanAccess(player) or (player ~= true and player ~= 1) then
        return "unit=" .. unit .. " exists=" .. Text(exists) .. " player=" .. Text(player)
    end
    local fullName, fullRealm, name, realm
    if UnitFullName then fullName, fullRealm = UnitFullName(unit) end
    if UnitName then name, realm = UnitName(unit) end
    local combined = GetUnitName and GetUnitName(unit, true)
    local normalized, recipient, evidence = Addon.Presence:ResolveUnitIdentity(unit)
    local cached = Addon.PlayerDetection.units[unit]
    local within, range = Addon.Range:IsWithin(unit, Addon.Database:GetDiscoveryRadius())
    return "unit=" .. unit .. " exists=" .. Text(exists) .. " player=" .. Text(player)
        .. " UFN=[" .. Text(fullName) .. "]/[" .. Text(fullRealm) .. "]"
        .. " UN=[" .. Text(name) .. "]/[" .. Text(realm) .. "]"
        .. " GUN=[" .. Text(combined) .. "] normalized=[" .. Text(normalized)
        .. "] cached=[" .. Text(cached and cached.characterKey) .. "] recipient=[" .. Text(recipient)
        .. "] identityEvidence=" .. Text(evidence) .. " range=" .. Text(range) .. " within=" .. Text(within)
end

function Diagnostics:Report(value)
    local now = Now()
    if self.lastReportAt and now - self.lastReportAt < 5 then return false, "rate-limited" end
    self.lastReportAt = now
    local comm, presence, detection = Addon.Communication, Addon.Presence, Addon.PlayerDetection
    local function Print(message) Addon:Print("DIAG " .. message) end
    local query = C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered or IsAddonMessagePrefixRegistered
    local queried = query and Text(query(Addon.Constants.COMMUNICATION_PREFIX)) or "unavailable"
    local transport = C_ChatInfo and C_ChatInfo.SendAddonMessage and "C_ChatInfo.SendAddonMessage"
        or (SendAddonMessage and "SendAddonMessage" or "unavailable")
    local channels = comm:GetBroadcastChannels()
    Print("version=" .. Text(Addon.Constants.ADDON_VERSION) .. " build=" .. Text(Addon.Constants.DIAGNOSTIC_BUILD)
        .. " protocol=" .. Text(Addon.Constants.PROTOCOL_VERSION))
    Print("prefix=" .. Text(comm.prefixRegistered) .. " clientQuery=" .. queried
        .. " registrationAPI=" .. Text(comm.registrationAPI) .. " transport=" .. transport)
    Print("channels=" .. (#channels > 0 and table.concat(channels, ",") or "none")
        .. " selected=" .. Text(comm:SelectBroadcastChannel()) .. " (HELLO uses all eligible channels)"
        .. " group=" .. Text(IsInGroup and IsInGroup()) .. " raid=" .. Text(IsInRaid and IsInRaid())
        .. " guild=" .. Text(IsInGuild and IsInGuild()))
    local localKeys = presence:GetLocalCharacterKeys()
    Print("local=" .. Text(table.concat(localKeys, ",")) .. " privacy=" .. Text(Addon.Database:GetPrivacyMode())
        .. " discovery=" .. Text(Addon.Database:IsDiscoveryEnabled()) .. " radius=" .. Text(Addon.Database:GetDiscoveryRadius()))
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    Print("identityEvidence UnitFullName=" .. Text(name) .. "/" .. Text(realm)
        .. " GetUnitName=" .. Text(GetUnitName and GetUnitName("player", true))
        .. " realm=" .. Text(GetRealmName and GetRealmName())
        .. " normalizedRealm=" .. Text(GetNormalizedRealmName and GetNormalizedRealmName()))
    local send = self.lastSend
    Print("HELLO-send=" .. (send and (Text(send.reason) .. " accepted=" .. Text(send.accepted)
        .. " rawResult=" .. send.result .. " via=" .. Text(send.channel) .. " age=" .. Age(send)) or "none")
        .. " (accepted means enqueue only)")
    local sentChannels = {}
    for _, channel in ipairs({"PARTY", "RAID", "INSTANCE_CHAT", "GUILD"}) do
        local attempt = self.sends[channel]
        if attempt then sentChannels[#sentChannels + 1] = channel .. ":" .. Text(attempt.reason)
            .. ":raw=" .. attempt.result .. ":age=" .. Age(attempt) end
    end
    Print("HELLO-by-channel=" .. (#sentChannels > 0 and table.concat(sentChannels, ",") or "none"))
    Print("last-HELLO " .. Event(self.lastHello))
    Print("last-ACK " .. Event(self.lastAck))
    Print("last-input " .. Event(self.lastIncoming))

    local peer = value and presence:NormalizeCharacterKey(value)
    if not peer then
        local target = detection.units.target
        peer = target and not target.simulated and target.characterKey or nil
        peer = peer or (self.lastPeer and self.lastPeer.characterKey ~= "-" and self.lastPeer.characterKey)
    end
    local record = peer and self.peers[string.lower(peer)]
    if record then peer = record.characterKey end
    local observed = Addon.ObservedDiscovery
    local probe = observed and peer and observed.peers[string.lower(peer)]
    Print("observed-probe=" .. Text(probe and probe.reason) .. " attempts=" .. Text(probe and probe.attempts)
        .. " pending=" .. Text(probe and probe.pending) .. " unit=" .. Text(probe and probe.unit)
        .. " range=" .. Text(probe and probe.range)
        .. " recipient=" .. Text(probe and probe.transportRecipient)
        .. " (enqueue acceptance is not delivery; no record can mean ineligible or queue full)")
    Print("peer-input=" .. Text(value) .. " peer=" .. Text(peer) .. " evidence=" .. Event(record))
    local count = 0
    for _, player in pairs(presence.players) do
        if not player.simulated and player.confirmed and type(player.lastSeen) == "number"
            and now - player.lastSeen <= Addon.Constants.PRESENCE_EXPIRY_SECONDS then count = count + 1 end
    end
    local player = peer and presence.players[peer]
    local confirmed = player and not player.simulated and player.confirmed
        and type(player.lastSeen) == "number" and now - player.lastSeen <= Addon.Constants.PRESENCE_EXPIRY_SECONDS or false
    local matched, valid, inRange, range = "none", false, false, "UNKNOWN"
    local units = peer and detection:GetUnits(peer, false) or {}
    local summaries, interactions = {}, {}
    table.sort(units, function(a, b) return a.unit < b.unit end)
    for _, unit in ipairs(units) do
        local unitValid = detection:IsValid(unit)
        local within, state = false, "UNKNOWN"
        if unitValid then within, state = Addon.Range:IsWithin(unit.unit, Addon.Database:GetDiscoveryRadius(), peer) end
        if #summaries < 8 then summaries[#summaries + 1] = Text(unit.unit) .. ":" .. Text(unitValid) .. ":" .. Text(state) end
        if unitValid and #interactions < 4 then
            local checks = {}
            for _, index in ipairs({3, 2, 1, 4}) do
                checks[#checks + 1] = index .. "=" .. (CheckInteractDistance
                    and Text(CheckInteractDistance(unit.unit, index)) or "unavailable")
            end
            interactions[#interactions + 1] = Text(unit.unit) .. "[" .. table.concat(checks, ",") .. "]"
        end
        if matched == "none" or (unitValid and not valid) or (within and not inRange) then
            matched, valid, inRange, range = unit.unit, unitValid, within, state
        end
    end
    local reason = "eligible"
    if not peer then reason = "no-peer-identity (target the other player or supply Name-Realm)"
    elseif not Addon.Database:IsDiscoveryEnabled() then reason = "discovery-disabled"
    elseif presence:IsSelf(peer) then reason = "self-identity"
    elseif not confirmed then reason = player and "presence-expired-or-simulated" or "no-confirmed-presence"
    elseif #units == 0 then reason = "no-unit-association (compare incoming and detected identities)"
    elseif not valid then reason = "unit-disappeared-or-identity-changed"
    elseif not inRange then reason = range == "UNKNOWN" and "range-unknown"
        or (range == "OVER_30" and "range-outside-configured-radius" or "range-bracket-insufficient-for-radius") end
    local nearby = peer and Addon.NearbyPlayers:Get(peer, false)
    local uiRow = false
    for _, row in ipairs(Addon.NearbyUI and Addon.NearbyUI.rows or {}) do
        if row.characterKey == peer and row.IsShown and row:IsShown() then uiRow = true; break end
    end
    Print("presenceCount=" .. count .. " peerConfirmed=" .. Text(confirmed)
        .. " matched=" .. Text(matched) .. " valid=" .. Text(valid) .. " range=" .. Text(range) .. " within=" .. Text(inRange))
    Print("units=" .. (#summaries > 0 and table.concat(summaries, ",") or "none")
        .. " targetKey=" .. Text(detection.units.target and detection.units.target.characterKey)
        .. " mouseoverKey=" .. Text(detection.units.mouseover and detection.units.mouseover.characterKey))
    Print("interactionChecks=" .. (#interactions > 0 and table.concat(interactions, ";") or "none")
        .. " (client results; range brackets are not exact yards)")
    Print("Nearby=" .. Text(nearby ~= nil) .. " exclusion=" .. reason .. " UI-created="
        .. Text(Addon.NearbyUI and Addon.NearbyUI.panel ~= nil) .. " UI-row=" .. Text(uiRow)
        .. " (current snapshot; allow one ticker second)")
    local evaluated = peer and self.pipeline[string.lower(peer)]
    local fromPresence = evaluated and evaluated.lastPresence
    Print("last-evaluation=" .. (evaluated and (Text(evaluated.reason) .. " origin=" .. Text(evaluated.origin)
        .. " unit=" .. Text(evaluated.unit) .. " range=" .. Text(evaluated.range)
        .. " unitCount=" .. Text(evaluated.unitCount) .. " age=" .. Age(evaluated) .. " count=" .. evaluated.count) or "none"))
    Print("presence-triggered-evaluation=" .. (fromPresence and (Text(fromPresence.reason)
        .. " unit=" .. Text(fromPresence.unit) .. " range=" .. Text(fromPresence.range) .. " age=" .. Age(fromPresence)) or "none")
        .. " UI-refresh=" .. Age(self.uiRefresh) .. " calls=" .. Text(self.uiRefresh and self.uiRefresh.count)
        .. " panelCreated=" .. Text(self.uiRefresh and self.uiRefresh.created)
        .. " completed=" .. Text(self.uiRefresh and self.uiRefresh.completed)
        .. " rows=" .. Text(self.uiRefresh and self.uiRefresh.rowCount))
    for _, token in ipairs({"target", "mouseover", "party1", "party2", "party3", "party4"}) do
        Print(UnitEvidence(token))
    end
    if matched ~= "none" and matched ~= "target" and matched ~= "mouseover" and not matched:match("^party[1-4]$") then
        Print(UnitEvidence(matched))
    end
    return true
end
