local Addon = ForeverRP

Addon.PlayerDetection = {
    units = {},
    characters = {},
    initialized = false,
}

local function ResolveCharacterKey(unit)
    if not UnitExists or not UnitExists(unit) or not UnitIsPlayer or not UnitIsPlayer(unit) then
        return nil
    end
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName(unit)
    end
    name = name or (UnitName and UnitName(unit))
    if not name then
        return nil
    end
    if realm and realm ~= "" then
        return Addon.Presence:NormalizeCharacterKey(name .. "-" .. realm)
    end
    return Addon.Presence:NormalizeCharacterKey(name)
end

local function AddAssociation(characterKey, unit, source, simulated)
    Addon.PlayerDetection.units[unit] = {
        characterKey = characterKey,
        unit = unit,
        source = source,
        simulated = simulated == true,
    }
    Addon.PlayerDetection.characters[characterKey] = Addon.PlayerDetection.characters[characterKey] or {}
    Addon.PlayerDetection.characters[characterKey][unit] = true
end

function Addon.PlayerDetection:RemoveUnit(unit)
    local detection = self.units[unit]
    if not detection then
        return
    end
    self.units[unit] = nil
    local characterUnits = self.characters[detection.characterKey]
    if characterUnits then
        characterUnits[unit] = nil
        if not next(characterUnits) then
            self.characters[detection.characterKey] = nil
        end
    end
    Addon:Debug("Player unit removed:", unit, detection.characterKey)
    Addon.NearbyPlayers:Reevaluate(detection.characterKey)
end

function Addon.PlayerDetection:DetectUnit(unit, source)
    local characterKey = ResolveCharacterKey(unit)
    if not characterKey or Addon.Presence:IsSelf(characterKey) then
        self:RemoveUnit(unit)
        return
    end

    local existing = self.units[unit]
    if existing and existing.characterKey ~= characterKey then
        self:RemoveUnit(unit)
    end
    AddAssociation(characterKey, unit, source, false)
    if not existing or existing.characterKey ~= characterKey then
        Addon:Debug("Player unit detected:", unit, characterKey)
    end
    Addon.NearbyPlayers:Reevaluate(characterKey)
end

function Addon.PlayerDetection:RefreshUnit(unit, source)
    if UnitExists and UnitExists(unit) and UnitIsPlayer and UnitIsPlayer(unit) then
        self:DetectUnit(unit, source)
    else
        self:RemoveUnit(unit)
    end
end

function Addon.PlayerDetection:IsValid(detection)
    if not detection then
        return false
    end
    if detection.simulated then
        return Addon.Database:IsDebugEnabled()
            and Addon.Range:GetSimulatedState(detection.characterKey) ~= nil
    end
    return ResolveCharacterKey(detection.unit) == detection.characterKey
end

function Addon.PlayerDetection:GetUnits(characterKey, includeSimulated)
    local results = {}
    local characterUnits = self.characters[characterKey]
    if not characterUnits then
        return results
    end
    for unit in pairs(characterUnits) do
        local detection = self.units[unit]
        if detection and (includeSimulated or not detection.simulated) then
            results[#results + 1] = detection
        end
    end
    return results
end

function Addon.PlayerDetection:GetCharacterKeys(includeSimulated)
    local results = {}
    for characterKey in pairs(self.characters) do
        if #self:GetUnits(characterKey, includeSimulated) > 0 then
            results[#results + 1] = characterKey
        end
    end
    return results
end

function Addon.PlayerDetection:ScanGroup()
    local staleUnits = {}
    for unit, detection in pairs(self.units) do
        if detection.source == "group" then
            staleUnits[#staleUnits + 1] = unit
        end
    end
    for _, unit in ipairs(staleUnits) do
        self:RemoveUnit(unit)
    end
    local prefix = IsInRaid and IsInRaid() and "raid" or "party"
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    for index = 1, count do
        self:RefreshUnit(prefix .. index, "group")
    end
end

function Addon.PlayerDetection:SetSimulatedCharacter(characterKey)
    local unit = "simulated:" .. characterKey
    AddAssociation(characterKey, unit, "simulation", true)
    Addon.NearbyPlayers:Reevaluate(characterKey)
end

function Addon.PlayerDetection:ClearSimulated()
    local units = {}
    for unit, detection in pairs(self.units) do
        if detection.simulated then
            units[#units + 1] = unit
        end
    end
    for _, unit in ipairs(units) do
        self:RemoveUnit(unit)
    end
end

function Addon.PlayerDetection:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    self:RefreshUnit("target", "target")
    self:RefreshUnit("mouseover", "mouseover")
    self:RefreshUnit("focus", "focus")
    self:ScanGroup()
end
