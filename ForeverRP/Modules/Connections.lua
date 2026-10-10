local Addon = ForeverRP

Addon.Connections = {
    simulated = {},
}

local function Now()
    return time and time() or 0
end

local function CleanText(value, limit)
    value = type(value) == "string" and value or ""
    value = value:gsub("[%z\1-\8\11\12\14-\31\127]", "")
    return value:sub(1, limit)
end

function Addon.Connections:GetStore()
    return Addon.Database:GetConnections()
end

function Addon.Connections:Get(characterKey, includeSimulated)
    if includeSimulated and self.simulated[characterKey] then
        return self.simulated[characterKey]
    end
    return self:GetStore()[characterKey]
end

function Addon.Connections:GetAll(includeSimulated)
    if Addon.Database:GetPrivacyMode() == "hidden" then
        return {}
    end
    local results = {}
    for _, connection in pairs(self:GetStore()) do
        results[#results + 1] = connection
    end
    if includeSimulated then
        for _, connection in pairs(self.simulated) do
            results[#results + 1] = connection
        end
    end
    table.sort(results, function(left, right)
        if left.favorite ~= right.favorite then
            return left.favorite == true
        end
        return left.characterKey < right.characterKey
    end)
    return results
end

function Addon.Connections:Remember(characterKey, simulated)
    if type(characterKey) ~= "string" or Addon.Presence:IsSelf(characterKey) then
        return false
    end
    local store = simulated and self.simulated or self:GetStore()
    local connection = store[characterKey]
    if not connection then
        connection = {
            characterKey = characterKey,
            rpName = "",
            remembered = true,
            favorite = false,
            privateNote = "",
            addedAt = simulated and 0 or Now(),
            lastEncountered = nil,
            simulated = simulated == true,
        }
        store[characterKey] = connection
    else
        connection.remembered = true
    end
    if Addon.Presence:IsConfirmed(characterKey, simulated == true)
        and Addon.NearbyPlayers:IsNearby(characterKey, simulated == true) then
        connection.lastEncountered = Now()
    end
    if not simulated and Addon.RemoteProfiles then
        local entry = Addon.RemoteProfiles:GetProfile(characterKey, false)
        if entry then
            connection.rpName = CleanText(entry.profile.rpName, Addon.Constants.PROFILE_LIMITS.rpName)
        end
    end
    self:RefreshUI()
    return true
end

function Addon.Connections:Forget(characterKey, simulated)
    if not simulated and Addon.ProfileAuthorization then
        Addon.ProfileAuthorization:SetConnectionApproval(characterKey, false)
    end
    local store = simulated and self.simulated or self:GetStore()
    store[characterKey] = nil
    self:RefreshUI()
end

function Addon.Connections:SetFavorite(characterKey, favorite, simulated)
    if not self:Remember(characterKey, simulated) then
        return false
    end
    local connection = self:Get(characterKey, simulated)
    connection.favorite = favorite == true
    self:RefreshUI()
    return true
end

function Addon.Connections:SetNote(characterKey, note, simulated)
    local connection = self:Get(characterKey, simulated == true)
    if not connection then
        return false
    end
    connection.privateNote = CleanText(note, Addon.Constants.CONNECTION_NOTE_LIMIT)
    self:RefreshUI()
    return true
end

function Addon.Connections:CacheRPName(characterKey, rpName, simulated)
    local connection = self:Get(characterKey, simulated == true)
    if connection then
        connection.rpName = CleanText(rpName, Addon.Constants.PROFILE_LIMITS.rpName)
        self:RefreshUI()
    end
end

function Addon.Connections:RecordEncounter(characterKey, simulated)
    local connection = self:Get(characterKey, simulated)
    if connection then
        connection.lastEncountered = Now()
        self:RefreshUI()
    end
end

function Addon.Connections:GetLevel(characterKey, simulated)
    local connection = self:Get(characterKey, simulated)
    if connection and connection.favorite then
        return "favorite"
    end
    if connection and connection.remembered then
        return "remembered"
    end
    return "normal"
end

function Addon.Connections:ClearSimulated()
    self.simulated = {}
    self:RefreshUI()
end

function Addon.Connections:RefreshUI()
    if Addon.NearbyUI then
        Addon.NearbyUI:Refresh()
    end
    if Addon.ConnectionsUI then
        Addon.ConnectionsUI:Refresh()
    end
    if Addon.ProfileViewer then
        Addon.ProfileViewer:RefreshConnectionActions()
    end
end
