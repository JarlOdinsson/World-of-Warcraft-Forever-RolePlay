local Addon = ForeverRP

Addon.Privacy = {
    simulatedRelationship = "unknown",
    trustedPeers = {},
}

local function SameCharacter(left, right)
    local leftKey = Addon.Presence:NormalizeCharacterKey(left)
    local rightKey = Addon.Presence:NormalizeCharacterKey(right)
    return leftKey and rightKey and string.lower(leftKey) == string.lower(rightKey)
end

function Addon.Privacy:IsFriend(characterKey)
    if C_FriendList and C_FriendList.GetFriendInfo then
        local succeeded, info = pcall(C_FriendList.GetFriendInfo, characterKey)
        if succeeded and info then
            return true
        end
        local name = characterKey:match("^([^%-]+)")
        succeeded, info = pcall(C_FriendList.GetFriendInfo, name)
        if succeeded and info then
            return true
        end
    end
    local count = C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends()
        or (GetNumFriends and GetNumFriends()) or 0
    local getInfo = C_FriendList and C_FriendList.GetFriendInfo or GetFriendInfo
    if getInfo then
        for index = 1, count do
            local succeeded, info = pcall(getInfo, index)
            local name = type(info) == "table" and info.name or info
            if succeeded and type(name) == "string" and SameCharacter(name, characterKey) then
                return true
            end
        end
    end
    return false
end

function Addon.Privacy:IsGuildMember(characterKey, channel)
    if channel == "GUILD" then
        return true
    end
    if not IsInGuild or not IsInGuild() or not GetNumGuildMembers or not GetGuildRosterInfo then
        return false
    end
    for index = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(index)
        if name and SameCharacter(name, characterKey) then
            return true
        end
    end
    return false
end

function Addon.Privacy:IsRestrictedPeer(characterKey, channel, simulated)
    if simulated then
        return self.simulatedRelationship == "friend" or self.simulatedRelationship == "guild"
    end
    if self.trustedPeers[string.lower(characterKey)] then
        return true
    end
    local allowed = self:IsFriend(characterKey) or self:IsGuildMember(characterKey, channel)
    if allowed then
        self.trustedPeers[string.lower(characterKey)] = true
    end
    return allowed
end

function Addon.Privacy:ResetRuntimeTrust()
    self.trustedPeers = {}
end

function Addon.Privacy:CanInteract(characterKey, channel, simulated)
    local mode = Addon.Database:GetPrivacyMode()
    if mode == "hidden" then
        return false
    end
    if mode == "restricted" then
        return type(characterKey) == "string"
            and self:IsRestrictedPeer(characterKey, channel, simulated == true)
    end
    return true
end

function Addon.Privacy:CanBroadcast(channel)
    local mode = Addon.Database:GetPrivacyMode()
    if mode == "hidden" then
        return false
    end
    if mode == "restricted" then
        return channel == "GUILD"
    end
    return true
end

function Addon.Privacy:CanDisplay(characterKey)
    if Addon.Database:GetPrivacyMode() == "hidden" then
        return false
    end
    return Addon.Presence:IsConfirmed(characterKey, false)
end

function Addon.Privacy:SetSimulatedRelationship(relationship)
    if relationship ~= "friend" and relationship ~= "guild" and relationship ~= "unknown" then
        return false
    end
    self.simulatedRelationship = relationship
    return true
end
