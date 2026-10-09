local Addon = ForeverRP

Addon.RemoteProfiles = {
    profiles = {},
}

local function CopyProfile(profile)
    local copy = {}
    for _, field in ipairs(Addon.Constants.PROFILE_FIELD_ORDER) do
        copy[field] = profile[field]
    end
    return copy
end

function Addon.RemoteProfiles:EvictOldest()
    local oldestKey, oldestAt
    for characterKey, entry in pairs(self.profiles) do
        local receivedAt = type(entry.receivedAt) == "number" and entry.receivedAt or -math.huge
        if not oldestKey or receivedAt < oldestAt or (receivedAt == oldestAt and characterKey < oldestKey) then
            oldestKey, oldestAt = characterKey, receivedAt
        end
    end
    if oldestKey then
        self.profiles[oldestKey] = nil
        if Addon.ProfileViewer then
            Addon.ProfileViewer:RefreshIfViewing(oldestKey)
        end
    end
end

function Addon.RemoteProfiles:StoreProfile(characterKey, profile, metadata)
    if type(characterKey) ~= "string" or Addon.Presence:IsSelf(characterKey) then
        return false, "invalid remote identity"
    end
    local sanitized, reason = Addon.Profile:SanitizeRemoteProfile(profile)
    if not sanitized then
        return false, reason
    end
    metadata = type(metadata) == "table" and metadata or {}
    if not self.profiles[characterKey] then
        local count = 0
        for _ in pairs(self.profiles) do count = count + 1 end
        if count >= (Addon.Constants.REMOTE_PROFILE_CACHE_MAX or math.huge) then
            self:EvictOldest()
        end
    end
    self.profiles[characterKey] = {
        characterKey = characterKey,
        profile = sanitized,
        receivedAt = GetTime and GetTime() or 0,
        addonVersion = type(metadata.addonVersion) == "string" and metadata.addonVersion or "unknown",
        protocolVersion = metadata.protocolVersion,
        simulated = metadata.simulated == true,
    }
    if Addon.Connections then
        Addon.Connections:CacheRPName(characterKey, sanitized.rpName, metadata.simulated == true)
    end
    if Addon.NearbyUI then
        Addon.NearbyUI:Refresh()
    end
    return true
end

function Addon.RemoteProfiles:HasProfile(characterKey, includeSimulated)
    return self:GetProfile(characterKey, includeSimulated) ~= nil
end

function Addon.RemoteProfiles:GetProfile(characterKey, includeSimulated)
    local entry = self.profiles[characterKey]
    if not entry or (entry.simulated and not includeSimulated) then
        return nil
    end
    return {
        characterKey = entry.characterKey,
        profile = CopyProfile(entry.profile),
        receivedAt = entry.receivedAt,
        addonVersion = entry.addonVersion,
        protocolVersion = entry.protocolVersion,
        simulated = entry.simulated,
    }
end

function Addon.RemoteProfiles:ClearProfile(characterKey)
    self.profiles[characterKey] = nil
    if Addon.NearbyUI then
        Addon.NearbyUI:Refresh()
    end
end

function Addon.RemoteProfiles:ClearSimulated()
    for characterKey, entry in pairs(self.profiles) do
        if entry.simulated then
            self.profiles[characterKey] = nil
        end
    end
    if Addon.NearbyUI then
        Addon.NearbyUI:Refresh()
    end
end
