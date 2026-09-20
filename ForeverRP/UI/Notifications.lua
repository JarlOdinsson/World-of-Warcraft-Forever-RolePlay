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

function Addon.Notifications:PlayDiscoverySound()
    local soundKit = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
    if PlaySound and soundKit then
        pcall(PlaySound, soundKit, "SFX")
    end
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
    if settings.minimapPulse then
        Addon.MinimapButton:Pulse()
    end
    if settings.sound then
        self:PlayDiscoverySound()
    end
    if settings.chat then
        Addon:Print(string.format(Addon:GetText("KINDRED_NEARBY"), player.characterKey))
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
