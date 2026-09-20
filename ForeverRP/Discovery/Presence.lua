local Addon = ForeverRP

Addon.Presence = {
    players = {},
}

local function Now()
    return GetTime and GetTime() or 0
end

local function NormalizeRealm(realm)
    if type(realm) ~= "string" then
        return ""
    end
    return realm:gsub("[%s%-]", "")
end

function Addon.Presence:NormalizeCharacterKey(sender)
    if type(sender) ~= "string" or #sender == 0 or #sender > 100 then
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
    if name == "" or realm == "" then
        return nil
    end
    return name .. "-" .. realm
end

function Addon.Presence:GetLocalCharacterKey()
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("player")
    end
    name = name or (UnitName and UnitName("player"))
    realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName())
        or (GetRealmName and GetRealmName())
    if not name then
        return nil
    end
    return self:NormalizeCharacterKey(name .. "-" .. NormalizeRealm(realm))
end

function Addon.Presence:IsSelf(characterKey)
    local localKey = self:GetLocalCharacterKey()
    return localKey and characterKey and string.lower(localKey) == string.lower(characterKey)
end

function Addon.Presence:Expire()
    local cutoff = Now() - Addon.Constants.PRESENCE_EXPIRY_SECONDS
    for characterKey, player in pairs(self.players) do
        if type(player.lastSeen) ~= "number" or player.lastSeen < cutoff then
            self.players[characterKey] = nil
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
