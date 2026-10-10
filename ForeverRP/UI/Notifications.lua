local Addon = ForeverRP

Addon.Notifications = {
    initialized = false,
    notifiedAt = {},
    simulationEnabled = false,
}

local function Now()
    return GetTime and GetTime() or 0
end

function Addon.Notifications:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    self:RefreshCount()
end

function Addon.Notifications:IsSimulationEnabled()
    return self.simulationEnabled == true and Addon.Database:IsDebugEnabled()
end

function Addon.Notifications:SetSimulationEnabled(enabled)
    self.simulationEnabled = enabled == true
    self:RefreshCount()
end

function Addon.Notifications:RefreshCount()
    if not Addon.MinimapButton or not Addon.NearbyPlayers then
        return
    end
    local count = Addon.NearbyPlayers:GetCount(self:IsSimulationEnabled())
    Addon.MinimapButton:UpdateNearbyCount(count)
end

function Addon.Notifications:CanNotify(characterKey)
    local lastNotification = self.notifiedAt[characterKey]
    if not lastNotification then
        return true
    end
    local cooldown = Addon.Database:GetNotificationSettings().cooldown
    return Now() - lastNotification >= cooldown
end

function Addon.Notifications:PlayDiscoverySound(level)
    -- Use an audible alert for every connection level, including new players.
    local soundKit = SOUNDKIT and (SOUNDKIT.READY_CHECK or SOUNDKIT.IG_QUEST_LOG_OPEN)
    local channel = Addon.Database:GetNotificationSettings().soundChannel
    if channel ~= "SFX" then channel = "Master" end
    if PlaySound and soundKit then
        local ok, played = pcall(PlaySound, soundKit, channel)
        return ok and played ~= false
    end
    return false
end

function Addon.Notifications:TestSound()
    local now = Now()
    if self.lastSoundTest and now - self.lastSoundTest < 2 then
        return false
    end
    self.lastSoundTest = now
    -- Preview even when automatic sounds are disabled; never consume peer cooldowns.
    if not self:PlayDiscoverySound() then
        Addon:Print(Addon:GetText("NOTIFICATION_SOUND_UNAVAILABLE"))
        return false
    end
    return true
end

function Addon.Notifications:OnNearbyEntered(player)
    self:RefreshCount()
    if not player or (player.simulated and not self:IsSimulationEnabled()) then
        return
    end
    local settings = Addon.Database:GetNotificationSettings()
    if not settings.minimapPulse and not settings.sound and not settings.chat then
        return
    end
    if not self:CanNotify(player.characterKey) then
        Addon:Debug("Discovery notification suppressed by cooldown:", player.characterKey)
        return
    end

    self.notifiedAt[player.characterKey] = Now()
    local level = Addon.Connections and Addon.Connections:GetLevel(player.characterKey, player.simulated) or "normal"
    if settings.minimapPulse then
        Addon.MinimapButton:Pulse()
    end
    if settings.sound then
        self:PlayDiscoverySound(level)
    end
    if settings.chat then
        local key = level == "favorite" and "FAVORITE_NEARBY"
            or (level == "remembered" and "FAMILIAR_NEARBY" or "KINDRED_NEARBY")
        Addon:Print(string.format(Addon:GetText(key), player.characterKey))
    end
    Addon:Debug("Discovery notification fired:", player.characterKey)
end

function Addon.Notifications:OnNearbyLeft()
    self:RefreshCount()
end

function Addon.Notifications:ResetCooldown(characterKey)
    self.notifiedAt[characterKey] = nil
end

function Addon.Notifications:ClearSimulatedState(characterKey)
    self.notifiedAt[characterKey] = nil
    self:RefreshCount()
end
