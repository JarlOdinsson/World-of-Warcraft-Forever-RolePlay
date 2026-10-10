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

    if command == "nearby" then
        local players = Addon.NearbyPlayers:GetAll(false)
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

    if command == "version" then
        Addon:Print(string.format(Addon:GetText("VERSION_ADDON"), Addon.Constants.ADDON_VERSION))
        Addon:Print("Build: " .. Addon.Constants.DIAGNOSTIC_BUILD)
        Addon:Print(string.format(Addon:GetText("VERSION_PROTOCOL"), Addon.Constants.PROTOCOL_VERSION))
        Addon:Print(string.format(Addon:GetText("VERSION_DATABASE"), Addon.Constants.DATABASE_VERSION))
        return
    end

    Addon:Print(Addon:GetText("UNKNOWN_COMMAND"))
end
