local Addon = ForeverRP

Addon.Events = {
    handlers = {},
    frame = CreateFrame("Frame"),
}

function Addon.Events:Register(eventName, handler)
    if type(handler) ~= "function" then
        error("ForeverRP event handlers must be functions.")
    end

    self.handlers[eventName] = handler
    self.frame:RegisterEvent(eventName)
end

function Addon.Events:Unregister(eventName)
    self.handlers[eventName] = nil
    self.frame:UnregisterEvent(eventName)
end

function Addon.Events:RegisterOptional(eventName, handler)
    if type(handler) ~= "function" then
        return false
    end
    self.handlers[eventName] = handler
    local registered = pcall(self.frame.RegisterEvent, self.frame, eventName)
    if not registered then
        self.handlers[eventName] = nil
        return false
    end
    return true
end

Addon.Events.frame:SetScript("OnEvent", function(_, eventName, ...)
    local handler = Addon.Events.handlers[eventName]
    if handler then
        handler(...)
    end
end)

Addon.Events:Register("ADDON_LOADED", function(addonName)
    Addon:OnAddonLoaded(addonName)
end)

Addon.Events:Register("PLAYER_LOGIN", function()
    Addon:OnPlayerLogin()
end)

Addon.Events:Register("PLAYER_LOGOUT", function()
    if Addon.ConnectionsUI then
        Addon.ConnectionsUI:CommitNote()
    end
    if Addon.ProfileEditor then
        Addon.ProfileEditor:Commit()
    end
end)

Addon.Events:Register("CHAT_MSG_ADDON", function(...)
    Addon.Communication:OnAddonMessage(...)
end)

Addon.Events:RegisterOptional("NAME_PLATE_UNIT_ADDED", function(unit)
    if Addon.ValueAccess:IsString(unit) then
        Addon.PlayerDetection:DetectUnit(unit, "nameplate")
    end
end)

Addon.Events:RegisterOptional("NAME_PLATE_UNIT_REMOVED", function(unit)
    if Addon.ValueAccess:IsString(unit) then
        Addon.PlayerDetection:RemoveUnit(unit)
    end
end)

Addon.Events:RegisterOptional("PLAYER_TARGET_CHANGED", function()
    Addon.PlayerDetection:RefreshUnit("target", "target")
end)

Addon.Events:RegisterOptional("UPDATE_MOUSEOVER_UNIT", function()
    Addon.PlayerDetection:RefreshUnit("mouseover", "mouseover")
end)

Addon.Events:RegisterOptional("PLAYER_FOCUS_CHANGED", function()
    Addon.PlayerDetection:RefreshUnit("focus", "focus")
end)

Addon.Events:RegisterOptional("GROUP_ROSTER_UPDATE", function()
    Addon.PlayerDetection:ScanGroup()
    Addon.Communication:OnBroadcastContextChanged()
end)

Addon.Events:RegisterOptional("PLAYER_GUILD_UPDATE", function()
    Addon.Privacy:OnRelationshipsChanged()
    Addon.Communication:OnBroadcastContextChanged()
end)

Addon.Events:RegisterOptional("GUILD_ROSTER_UPDATE", function()
    Addon.Privacy:OnRelationshipsChanged()
    Addon.Communication:OnBroadcastContextChanged()
end)

Addon.Events:RegisterOptional("FRIENDLIST_UPDATE", function()
    Addon.Privacy:OnRelationshipsChanged()
end)

Addon.Events:RegisterOptional("PLAYER_ENTERING_WORLD", function()
    Addon.Communication:OnBroadcastContextChanged()
    if Addon.Activity then Addon.Activity:OnWorldChanged() end
end)

Addon.Events:RegisterOptional("ZONE_CHANGED_NEW_AREA", function()
    if Addon.Activity then Addon.Activity:Changed() end
end)

Addon.Events:RegisterOptional("MINIMAP_UPDATE_ZOOM", function()
    if Addon.PlayerMarkers then Addon.PlayerMarkers:Refresh() end
end)
