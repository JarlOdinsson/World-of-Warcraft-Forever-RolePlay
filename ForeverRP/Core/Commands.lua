local Addon = ForeverRP

Addon.Commands = {
    registered = false,
}

local function Trim(message)
    return (message or ""):match("^%s*(.-)%s*$")
end

function Addon.Commands:Register()
    if self.registered then
        return
    end

    SLASH_FOREVERRP1 = "/frp"
    SLASH_FOREVERRP2 = "/foreverrp"
    SlashCmdList.FOREVERRP = function(message)
        self:Handle(message)
    end
    self.registered = true
end

function Addon.Commands:Handle(message)
    local rawCommand = Trim(message)
    local command = string.lower(rawCommand)
    if command == "diag" or command:match("^diag%s+") then
        Addon.DiscoveryDiagnostics:Report(rawCommand:match("^%S+%s+(.+)$"))
        return
    end
    if command == "" then
        Addon.UI:Show("home")
        return
    end

    if command == "help" then
        Addon:Print(Addon:GetText("HELP"))
        return
    end

    if command == "settings" then
        Addon.UI:Show("settings")
        return
    end
    if command == "privacy" or command == "activity" or command == "directory" then
        Addon.UI:Show(command == "directory" and "activity" or command)
        return
    end
    if command == "network" then
        local activity = Addon.Activity and Addon.Activity.counters or {}
        local legacy = Addon.DiscoveryDiagnostics.counters
        local active, markers = 0, 0
        if Addon.Presence and Addon.Presence.players then for _ in pairs(Addon.Presence.players) do active = active + 1 end end
        if Addon.PlayerMarkers then for _, marker in ipairs(Addon.PlayerMarkers.pool) do if marker:IsShown() then markers = markers + 1 end end end
        Addon:Print(string.format("Network: sent=%d received=%d throttled=%d expired=%d; activity sent=%d received=%d throttled=%d duplicates=%d expired=%d; requestsRejected=%d active=%d markers=%d",
            legacy.sent, legacy.received, legacy.throttled, legacy.expired,
            activity.sent or 0, activity.received or 0, activity.throttled or 0, activity.duplicates or 0,
            activity.expired or 0, Addon.ProfileAuthorization and Addon.ProfileAuthorization.denied or 0, active, markers))
        return
    end

    if command == "profile" then
        Addon.UI:Show("profile")
        return
    end

    if command == "view" then
        Addon.ProfileViewer:ShowLocal()
        Addon.UI:Show("viewer")
        return
    end

    if command:match("^request%s+") then
        local target = rawCommand:match("^%S+%s+(.+)$")
        local requested, result = Addon.ProfileTransfer:Request(target)
        if requested then
            Addon:Print(string.format(Addon:GetText("PROFILE_REQUEST_SENT"), result))
        elseif result == "send" then
            Addon:Print(Addon:GetText("PROFILE_REQUEST_SEND_FAILED"))
        else
            Addon:Print(Addon:GetText("PROFILE_REQUEST_UNKNOWN"))
        end
        return
    end

    if command == "hello" then
        local sent, channel = Addon.Communication:SendHello()
        if sent then
            Addon:Print(string.format(Addon:GetText("HELLO_SENT"), channel))
        else
            Addon:Print(Addon:GetText("HELLO_NO_CHANNEL"))
        end
        return
    end

    if command == "presence" then
        local includeSimulated = Addon.Database:IsDebugEnabled()
        local players = Addon.Presence:GetAll(includeSimulated)
        if #players == 0 then
            Addon:Print(Addon:GetText("PRESENCE_NONE"))
            return
        end

        Addon:Print(Addon:GetText("PRESENCE_HEADER"))
        local now = GetTime and GetTime() or 0
        for _, player in ipairs(players) do
            local key = player.simulated and "PRESENCE_ENTRY_SIMULATED" or "PRESENCE_ENTRY"
            Addon:Print(string.format(Addon:GetText(key), player.characterKey, player.addonVersion,
                math.max(0, math.floor(now - player.lastSeen))))
        end
        return
    end

    if command == "nearby" then
        local includeSimulated = Addon.Database:IsDebugEnabled()
        local players = Addon.NearbyPlayers:GetAll(includeSimulated)
        if #players == 0 then
            Addon:Print(Addon:GetText("NEARBY_NONE"))
            return
        end
        Addon:Print(Addon:GetText("NEARBY_HEADER"))
        for _, player in ipairs(players) do
            local key = player.simulated and "NEARBY_ENTRY_SIMULATED" or "NEARBY_ENTRY"
            Addon:Print(string.format(Addon:GetText(key), player.characterKey))
        end
        return
    end

    local simulationAction
    if command == "sim" then
        simulationAction = ""
    else
        simulationAction = command:match("^sim%s+(.+)$")
    end
    if simulationAction ~= nil then
        if not Addon.Database:IsDebugEnabled() then
            Addon:Print(Addon:GetText("SIM_REQUIRES_DEBUG"))
            return
        end
        Addon.Communication:Simulate(simulationAction)
        return
    end

    if command == "version" then
        Addon:Print(string.format(Addon:GetText("VERSION_ADDON"), Addon.Constants.ADDON_VERSION))
        Addon:Print("Build: " .. Addon.Constants.DIAGNOSTIC_BUILD)
        Addon:Print(string.format(Addon:GetText("VERSION_PROTOCOL"), Addon.Constants.PROTOCOL_VERSION))
        Addon:Print(string.format(Addon:GetText("VERSION_DATABASE"), Addon.Constants.DATABASE_VERSION))
        return
    end

    if command == "debug" then
        local key = Addon.Database:IsDebugEnabled() and "DEBUG_STATUS_ENABLED" or "DEBUG_STATUS_DISABLED"
        Addon:Print(Addon:GetText(key))
        return
    end

    if command == "debug on" then
        Addon.Database:SetDebugEnabled(true)
        Addon.UI:RefreshSettings()
        Addon:Print(Addon:GetText("DEBUG_ENABLED"))
        return
    end

    if command == "debug off" then
        Addon.Database:SetDebugEnabled(false)
        Addon.UI:RefreshSettings()
        Addon:Print(Addon:GetText("DEBUG_DISABLED"))
        return
    end

    Addon:Print(Addon:GetText("UNKNOWN_COMMAND"))
end
