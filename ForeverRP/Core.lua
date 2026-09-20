local Addon = ForeverRP

Addon.State = Addon.State or {
    initialized = false,
    ready = false,
}

Addon.L = Addon.Localization and Addon.Localization.enUS or {}

function Addon:GetText(key)
    return self.L[key] or key
end

local function JoinMessage(...)
    local values = {}
    for index = 1, select("#", ...) do
        values[index] = tostring(select(index, ...))
    end
    return table.concat(values, " ")
end

function Addon:Print(...)
    print(self.Constants.ADDON_DISPLAY_NAME .. ": " .. JoinMessage(...))
end

function Addon:Debug(...)
    if not self.Database or not self.Database:IsDebugEnabled() then
        return
    end

    print(self.Constants.ADDON_DISPLAY_NAME .. " DEBUG: " .. JoinMessage(...))
end

function Addon:OnAddonLoaded(addonName)
    if addonName ~= self.Constants.ADDON_NAME or self.State.initialized then
        return
    end

    self.Database:Initialize()
    self.Communication:Initialize()
    self.Commands:Register()
    self.State.initialized = true
    self.State.loadedAt = GetTime and GetTime() or 0
end

function Addon:OnPlayerLogin()
    if not self.State.initialized or self.State.ready then
        return
    end

    self.Profile:Initialize()
    self.ProfileTransfer:Initialize()
    self.PlayerTooltip:Initialize()
    self.UI:Initialize()
    self.Notifications:Initialize()
    self.NearbyPlayers:Initialize()
    self.PlayerDetection:Initialize()
    self.State.ready = true
    self.Communication:SendInitialHello()
    self:Print(self:GetText("ADDON_LOADED"))
end
