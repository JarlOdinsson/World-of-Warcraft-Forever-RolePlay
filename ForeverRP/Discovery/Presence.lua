local Addon = ForeverRP
local ValueAccess = Addon.ValueAccess

Addon.Presence = {
    players = {},
}

local function Now()
    return GetTime and GetTime() or 0
end

local function NormalizeRealm(realm)
    if not ValueAccess:IsString(realm) then
        return ""
    end
    return realm:gsub("[%s%-]", "")
end

function Addon.Presence:NormalizeCharacterKey(sender)
    if not ValueAccess:IsString(sender) or #sender == 0 or #sender > 100 then
        return nil
    end
    if sender:find("[%c|]") then
        return nil
    end

    local name, realm = sender:match("^([^%-]+)%-(.+)$")
    if not name then
        name = sender
        realm = GetNormalizedRealmName and GetNormalizedRealmName()
            or (GetRealmName and GetRealmName())
    end

    realm = NormalizeRealm(realm)
    if not ValueAccess:IsString(name) or not ValueAccess:IsString(realm)
        or name == "" or realm == "" then
        return nil
    end
    return name .. "-" .. realm
end

function Addon.Presence:GetLocalCharacterKey()
    local keys = self:GetLocalCharacterKeys()
    return keys[1]
end

function Addon.Presence:GetLocalCharacterKeys()
    local keys, known = {}, {}
    local function Add(name, realm)
        if not ValueAccess:CanAccess(name, realm)
            or not ValueAccess:IsString(name) or not ValueAccess:IsString(realm) then
            return
        end
        local key = self:NormalizeCharacterKey(name .. "-" .. NormalizeRealm(realm))
        if key and not known[string.lower(key)] then
            known[string.lower(key)] = true
            keys[#keys + 1] = key
        end
    end

    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("player")
    end
    Add(name, realm)
    if (not ValueAccess:IsString(name) or not ValueAccess:IsString(realm)) and UnitName then
        name, realm = UnitName("player")
        Add(name, realm)
    end

    if GetUnitName then
        local combined = GetUnitName("player", true)
        if ValueAccess:IsString(combined) then
            local key = self:NormalizeCharacterKey(combined)
            if key and not known[string.lower(key)] then
                known[string.lower(key)] = true
                keys[#keys + 1] = key
            end
        end
    end

    if ValueAccess:IsString(name) then
        local normalizedRealm = GetNormalizedRealmName and GetNormalizedRealmName()
        Add(name, normalizedRealm)
        local realmName = GetRealmName and GetRealmName()
        Add(name, realmName)
    end
    return keys
end

function Addon.Presence:IsSelf(characterKey)
    if not ValueAccess:IsString(characterKey) then
        return false
    end
    local target = string.lower(characterKey)
    for _, localKey in ipairs(self:GetLocalCharacterKeys()) do
        if target == string.lower(localKey) then
            return true
        end
    end
    return false
end

function Addon.Presence:Expire(force)
    local now = Now()
    if not force and self.lastExpirySweepAt and now - self.lastExpirySweepAt < 1 then
        return false
    end
    self.lastExpirySweepAt = now
    local cutoff = now - Addon.Constants.PRESENCE_EXPIRY_SECONDS
    for characterKey, player in pairs(self.players) do
        if type(player.lastSeen) ~= "number" or player.lastSeen < cutoff then
            self.players[characterKey] = nil
        end
    end
    return true
end

function Addon.Presence:EvictOldest()
    local oldestKey, oldestSeen
    for characterKey, player in pairs(self.players) do
        local seen = type(player.lastSeen) == "number" and player.lastSeen or -math.huge
        if not oldestKey or seen < oldestSeen or (seen == oldestSeen and characterKey < oldestKey) then
            oldestKey, oldestSeen = characterKey, seen
        end
    end
    if oldestKey then
        self.players[oldestKey] = nil
        if Addon.NearbyPlayers then
            Addon.NearbyPlayers:Remove(oldestKey, "presence cache limit")
        end
    end
end

function Addon.Presence:Update(characterKey, metadata)
    self:Expire()
    if type(characterKey) ~= "string" or type(metadata) ~= "table" or self:IsSelf(characterKey) then
        return false
    end
    if type(metadata.addonVersion) ~= "string"
        or type(metadata.protocolVersion) ~= "number"
        or metadata.protocolVersion ~= Addon.Constants.PROTOCOL_VERSION then
        return false
    end

    if not self.players[characterKey] then
        local count = 0
        for _ in pairs(self.players) do count = count + 1 end
        if count >= (Addon.Constants.PRESENCE_CACHE_MAX or math.huge) then
            self:EvictOldest()
        end
    end
    self.players[characterKey] = {
        characterKey = characterKey,
        addonVersion = metadata.addonVersion,
        protocolVersion = metadata.protocolVersion,
        lastSeen = Now(),
        confirmed = true,
        simulated = metadata.simulated == true,
    }
    Addon:Debug("Presence updated:", characterKey)
    if Addon.NearbyPlayers then
        Addon.NearbyPlayers:Reevaluate(characterKey)
    end
    return true
end

function Addon.Presence:IsConfirmed(characterKey, includeSimulated)
    local player = self:Get(characterKey, includeSimulated)
    return player and player.confirmed == true or false
end

function Addon.Presence:Get(characterKey, includeSimulated)
    self:Expire()
    local player = self.players[characterKey]
    if player and player.simulated and not includeSimulated then
        return nil
    end
    return player
end

function Addon.Presence:RevalidatePrivacy()
    local removed = {}
    for characterKey, player in pairs(self.players) do
        if not Addon.Privacy:CanInteract(characterKey, "WHISPER", player.simulated == true) then
            removed[#removed + 1] = characterKey
        end
    end
    for _, characterKey in ipairs(removed) do
        self.players[characterKey] = nil
        if Addon.NearbyPlayers then
            Addon.NearbyPlayers:Remove(characterKey, "privacy relationship changed")
        end
    end
    return #removed
end

function Addon.Presence:ResolveKnownKey(value, includeSimulated)
    local normalized = self:NormalizeCharacterKey(value)
    if not normalized then
        return nil
    end

    local target = string.lower(normalized)
    for characterKey, player in pairs(self.players) do
        if string.lower(characterKey) == target
            and (includeSimulated or not player.simulated)
            and player.confirmed == true then
            return characterKey
        end
    end
    return nil
end

function Addon.Presence:GetAll(includeSimulated)
    self:Expire()
    local results = {}
    for _, player in pairs(self.players) do
        if includeSimulated or not player.simulated then
            results[#results + 1] = {
                characterKey = player.characterKey,
                addonVersion = player.addonVersion,
                protocolVersion = player.protocolVersion,
                lastSeen = player.lastSeen,
                confirmed = player.confirmed,
                simulated = player.simulated,
            }
        end
    end
    table.sort(results, function(left, right)
        return left.characterKey < right.characterKey
    end)
    return results
end

function Addon.Presence:ClearSimulated()
    local removed = 0
    for characterKey, player in pairs(self.players) do
        if player.simulated then
            self.players[characterKey] = nil
            removed = removed + 1
        end
    end
    return removed
end

function Addon.Presence:ClearAll()
    for characterKey in pairs(self.players) do
        self.players[characterKey] = nil
    end
end
