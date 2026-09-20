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
    if Addon.ProfileEditor then
        Addon.ProfileEditor:Commit()
    end
end)

Addon.Events:Register("CHAT_MSG_ADDON", function(prefix, payload, channel, sender)
    Addon.Communication:OnAddonMessage(prefix, payload, channel, sender)
end)

Addon.Events:RegisterOptional("NAME_PLATE_UNIT_ADDED", function(unit)
    Addon.PlayerDetection:DetectUnit(unit, "nameplate")
end)

Addon.Events:RegisterOptional("NAME_PLATE_UNIT_REMOVED", function(unit)
    Addon.PlayerDetection:RemoveUnit(unit)
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
end)
