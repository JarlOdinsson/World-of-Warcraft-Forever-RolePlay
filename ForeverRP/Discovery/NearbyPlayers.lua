local Addon = ForeverRP
local ValueAccess = Addon.ValueAccess

Addon.NearbyPlayers = {
    players = {},
    initialized = false,
}

local function Now()
    return GetTime and GetTime() or 0
end

local function Trace(characterKey, reason, unit, range, origin, unitCount)
    if Addon.DiscoveryDiagnostics then
        Addon.DiscoveryDiagnostics:RecordEvaluation(characterKey, reason, unit, range, origin, unitCount)
    end
end

function Addon.NearbyPlayers:Remove(characterKey, reason)
    if not ValueAccess:IsString(characterKey) then
        return
    end
    local player = self.players[characterKey]
    if player then
        self.players[characterKey] = nil
        Addon:Debug("Player left discovery range:", characterKey, reason or "")
        if Addon.Notifications then
            Addon.Notifications:OnNearbyLeft(player)
        end
        if Addon.NearbyUI then
            Addon.NearbyUI:Refresh()
        end
    end
end

function Addon.NearbyPlayers:Reevaluate(characterKey, origin)
    if not ValueAccess:IsString(characterKey) then
        return
    end
    if not Addon.Database or not Addon.Database:GetAccount() then
        Trace(characterKey, "database-unavailable", nil, "UNKNOWN", origin, 0)
        return
    end
    if not Addon.Database:IsDiscoveryEnabled() then
        Trace(characterKey, "discovery-disabled", nil, "UNKNOWN", origin, 0)
        self:Remove(characterKey, "discovery disabled")
        return
    end

    local includeSimulated = Addon.Database:IsDebugEnabled()
    local presence = Addon.Presence:Get(characterKey, includeSimulated)
    if not presence or not presence.confirmed or Addon.Presence:IsSelf(characterKey) then
        Trace(characterKey, "presence-unavailable-or-self", nil, "UNKNOWN", origin, 0)
        self:Remove(characterKey, "presence unavailable")
        return
    end

    local detections = Addon.PlayerDetection:GetUnits(characterKey, includeSimulated)
    local selectedUnit
    local selectedState = "UNKNOWN"
    local validUnits, lastUnit = 0, nil
    local radius = Addon.Database:GetDiscoveryRadius()
    for _, detection in ipairs(detections) do
        if detection and ValueAccess:IsString(detection.unit)
            and ValueAccess:IsString(detection.characterKey)
            and Addon.PlayerDetection:IsValid(detection) then
            validUnits = validUnits + 1
            lastUnit = detection.unit
            local inRange, rangeState = Addon.Range:IsWithin(detection.unit, radius, characterKey)
            if inRange then
                selectedUnit = detection.unit
                selectedState = rangeState
                break
            elseif selectedState == "UNKNOWN" then
                selectedState = rangeState
            end
        end
    end

    if not selectedUnit then
        local reason = #detections == 0 and "no-unit-association"
            or (validUnits == 0 and "unit-disappeared-or-identity-changed"
            or (selectedState == "UNKNOWN" and "range-unknown"
            or (selectedState == "OVER_30" and "range-outside-configured-radius" or "range-bracket-insufficient-for-radius")))
        Trace(characterKey, reason, lastUnit, selectedState, origin, #detections)
        self:Remove(characterKey, selectedState)
        return
    end

    local previous = self.players[characterKey]
    Trace(characterKey, "eligible", selectedUnit, selectedState, origin, #detections)
    self.players[characterKey] = {
        characterKey = characterKey,
        unit = selectedUnit,
        confirmed = true,
        inRange = true,
        lastSeen = Now(),
        rangeState = selectedState,
        simulated = presence.simulated == true,
    }
    if not previous then
        Addon:Debug("Player entered discovery range:", characterKey, selectedState)
    elseif previous.rangeState ~= selectedState or previous.unit ~= selectedUnit then
        Addon:Debug("Player discovery range updated:", characterKey, selectedState)
    end
    if not previous and Addon.Connections then
        Addon.Connections:RecordEncounter(characterKey, presence.simulated == true)
    end
    if not previous and Addon.Notifications then
        Addon.Notifications:OnNearbyEntered(self.players[characterKey])
    end
    if not previous and Addon.NearbyUI then
        Addon.NearbyUI:Refresh()
    end
end

function Addon.NearbyPlayers:ReevaluateAll()
    if not Addon.Database or not Addon.Database:GetAccount() then
        return
    end
    if not Addon.Database:IsDiscoveryEnabled() then
        for characterKey in pairs(self.players) do
            self:Remove(characterKey, "discovery disabled")
        end
        return
    end

    local keys = {}
    local includeSimulated = Addon.Database:IsDebugEnabled()
    for _, presence in ipairs(Addon.Presence:GetAll(includeSimulated)) do
        keys[presence.characterKey] = true
    end
    for characterKey in pairs(self.players) do
        keys[characterKey] = true
    end
    for characterKey in pairs(keys) do
        self:Reevaluate(characterKey)
    end
end

function Addon.NearbyPlayers:IsNearby(characterKey, includeSimulated)
    local player = self:Get(characterKey, includeSimulated)
    return player and player.inRange == true or false
end

function Addon.NearbyPlayers:Get(characterKey, includeSimulated)
    if not ValueAccess:IsString(characterKey) then
        return nil
    end
    local player = self.players[characterKey]
    if player and player.simulated and not includeSimulated then
        return nil
    end
    return player
end

function Addon.NearbyPlayers:GetAll(includeSimulated)
    local results = {}
    for _, player in pairs(self.players) do
        if includeSimulated or not player.simulated then
            results[#results + 1] = player
        end
    end
    table.sort(results, function(left, right)
        return left.characterKey < right.characterKey
    end)
    return results
end

function Addon.NearbyPlayers:GetCount(includeSimulated)
    return #self:GetAll(includeSimulated)
end

function Addon.NearbyPlayers:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    if C_Timer and C_Timer.NewTicker then
        self.ticker = C_Timer.NewTicker(1, function()
            if Addon.ObservedDiscovery then Addon.ObservedDiscovery:Tick() end
            self:ReevaluateAll()
        end)
    end
end
