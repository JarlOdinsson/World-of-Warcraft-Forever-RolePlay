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

-- UnitFullName/UnitName on Forever can split "First Last" into two returns.
-- Only GetUnitName evidence distinguishes that case from a real realm return.
function Addon.Presence:ResolveUnitIdentity(unit)
    if not ValueAccess:IsString(unit) then return nil end
    if unit ~= "player" or UnitExists then
        if not UnitExists or not UnitIsPlayer then return nil end
        local exists, player = UnitExists(unit), UnitIsPlayer(unit)
        if not ValueAccess:CanAccess(exists, player)
            or (exists ~= true and exists ~= 1) or (player ~= true and player ~= 1) then return nil end
    end
    local name, second
    if UnitFullName then name, second = UnitFullName(unit) end
    if not ValueAccess:CanAccess(name, second) then return nil end
    if not name and UnitName then name, second = UnitName(unit) end
    if not ValueAccess:IsString(name) or not ValueAccess:CanAccess(second)
        or (second ~= nil and not ValueAccess:IsString(second)) then return nil end

    local combined
    if GetUnitName then
        combined = GetUnitName(unit, true)
        if not ValueAccess:IsString(combined) or combined == "" then return nil end
    end
    local characterName, realm, recipient, evidence = name, second, nil, "unit-name-pair"
    if combined then
        local fullName, fullRealm = combined:match("^([^%-]+)%-(.+)$")
        if fullName then
            -- Preserve an explicitly supplied cross-realm suffix and raw address.
            characterName, realm, recipient, evidence = fullName, fullRealm, combined, "qualified-GetUnitName"
        elseif second and second ~= "" and combined == name .. " " .. second then
            characterName, realm, recipient, evidence = combined, nil, combined, "split-name-GetUnitName"
        elseif combined == name then
            recipient, evidence = combined, "GetUnitName-with-unit-realm"
            -- A genuine realm return is retained when it is not part of GUN's name.
            if realm and realm ~= "" then recipient = name .. "-" .. realm end
        else
            return nil -- conflicting evidence; do not invent separators or aliases
        end
    end
    if not realm or realm == "" then
        realm = GetNormalizedRealmName and GetNormalizedRealmName()
        if not ValueAccess:CanAccess(realm) then return nil end
        if not ValueAccess:IsString(realm) or realm == "" then
            realm = GetRealmName and GetRealmName()
        end
    end
    if not ValueAccess:IsString(realm) or realm == "" then return nil end
    local key = self:NormalizeCharacterKey(characterName .. "-" .. realm)
    if not key then return nil end
    return key, recipient or (characterName .. "-" .. realm), evidence, characterName
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

    local key, _, _, name = self:ResolveUnitIdentity("player")
    if key then
        keys[#keys + 1] = key
        known[string.lower(key)] = true
    end
    if ValueAccess:IsString(name) then
        local unitName, unitRealm
        if UnitFullName then unitName, unitRealm = UnitFullName("player") end
        if ValueAccess:IsString(unitName) and unitName == name then Add(name, unitRealm) end
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
        if player.activity and (now - player.activity.at > 150
            or not Addon.Privacy:CanInteract(characterKey, "WHISPER", false)) then
            self:ClearActivity(characterKey)
        end
        if type(player.lastSeen) ~= "number" or player.lastSeen < cutoff then
            self.players[characterKey] = nil
            if Addon.DiscoveryDiagnostics then
                local counters = Addon.DiscoveryDiagnostics.counters
                counters.expired = counters.expired + 1
            end
        end
    end
    return true
end

function Addon.Presence:EvictOldest()
    local oldestKey, oldestSeen, oldestPriority
    for characterKey, player in pairs(self.players) do
        local seen = type(player.lastSeen) == "number" and player.lastSeen or -math.huge
        local priority = player.metadataOnly and 0 or 1
        if not oldestKey or priority < oldestPriority or priority == oldestPriority
            and (seen < oldestSeen or seen == oldestSeen and characterKey < oldestKey) then
            oldestKey, oldestSeen, oldestPriority = characterKey, seen, priority
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
    local activity = self.players[characterKey] and self.players[characterKey].activity
    self.players[characterKey] = {
        characterKey = characterKey,
        addonVersion = metadata.addonVersion,
        protocolVersion = metadata.protocolVersion,
        lastSeen = Now(),
        confirmed = true,
        simulated = metadata.simulated == true,
        activity = activity,
        transportRecipient = metadata.simulated ~= true and ValueAccess:IsString(metadata.transportRecipient)
            and metadata.transportRecipient or nil,
        transportRecipientSource = ValueAccess:IsString(metadata.transportRecipientSource) and metadata.transportRecipientSource or nil,
    }
    Addon:Debug("Presence updated:", characterKey)
    if Addon.NearbyPlayers then
        Addon.NearbyPlayers:Reevaluate(characterKey, "presence-update")
    end
    return true
end

-- Optional metadata lives on the existing presence record, never a second peer cache.
-- Broad metadata may occupy free slots but cannot evict legacy discovery records.
function Addon.Presence:UpdateActivity(characterKey, activity, version, recipient)
    if Addon.Activity and Addon.Activity.unavailable then return false end
    local existing = self:ResolveKnownKey(characterKey, false)
    characterKey = existing or characterKey
    local record = self.players[characterKey]
    if not record then
        local count = 0; for _ in pairs(self.players) do count = count + 1 end
        if count >= (Addon.Constants.PRESENCE_CACHE_MAX or 250) then return false end
        record = {characterKey = characterKey, addonVersion = version,
            protocolVersion = Addon.Constants.PROTOCOL_VERSION, confirmed = true,
            simulated = false, metadataOnly = true}
        self.players[characterKey] = record
    end
    record.activity, record.lastSeen, record.transportRecipient = activity, Now(), recipient
    record.transportRecipientSource = "CHAT_MSG_ADDON.sender:activity"
    activity.characterKey = characterKey
    if Addon.NearbyPlayers then Addon.NearbyPlayers:Reevaluate(characterKey, "presence-update") end
    return true
end

function Addon.Presence:ClearActivity(characterKey)
    local record = self.players[characterKey]
    if not record or not record.activity then return false end
    record.activity = nil
    if record.metadataOnly and not (Addon.NearbyPlayers and Addon.NearbyPlayers:IsNearby(characterKey, false)) then
        self.players[characterKey] = nil
        if Addon.NearbyPlayers then Addon.NearbyPlayers:Remove(characterKey, "activity withdrawn") end
    end
    if Addon.Activity then
        Addon.Activity.counters.expired = Addon.Activity.counters.expired + 1
        Addon.Activity.uiDirty = true
    end
    return true
end

function Addon.Presence:GetActivityRecords()
    self:Expire()
    local results = {}
    for _, record in pairs(self.players) do
        if record.activity and not record.simulated then results[#results + 1] = record.activity end
    end
    return results
end

function Addon.Presence:GetTransportRecipient(characterKey)
    local player = self:Get(characterKey, false)
    return player and player.transportRecipient or characterKey
end

function Addon.Presence:GetTransportRecipientSource(characterKey)
    local player = self:Get(characterKey, false)
    return player and player.transportRecipient
        and ("presence:" .. (player.transportRecipientSource or "stored-recipient")) or "canonical-key-fallback"
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
