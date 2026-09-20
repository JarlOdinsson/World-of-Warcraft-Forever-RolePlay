local Addon = ForeverRP

Addon.PlayerTooltip = {
    initialized = false,
}

local function GetCharacterKey(unit)
    if type(unit) ~= "string" or not UnitExists or not UnitExists(unit)
        or not UnitIsPlayer or not UnitIsPlayer(unit) then
        return nil
    end
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName(unit)
    end
    name = name or (UnitName and UnitName(unit))
    if not name then
        return nil
    end
    if realm and realm ~= "" then
        return Addon.Presence:NormalizeCharacterKey(name .. "-" .. realm)
    end
    return Addon.Presence:NormalizeCharacterKey(name)
end

local function AddProfileLines(tooltip, characterKey)
    local entry = Addon.RemoteProfiles:GetProfile(characterKey, false)
    tooltip:AddLine(Addon:GetText("TOOLTIP_FOREVERRP_USER"), 1, 0.82, 0)
    if not entry then
        return
    end

    local profile = entry.profile
    local rpName = profile.rpName:gsub("|", "||")
    local title = profile.title:gsub("|", "||")
    local displayName = rpName
    if title ~= "" then
        displayName = displayName ~= "" and (displayName .. ", " .. title) or title
    end
    if displayName ~= "" then
        tooltip:AddLine(displayName, 1, 1, 1)
    end
    if profile.status ~= "" then
        tooltip:AddLine(string.format(Addon:GetText("TOOLTIP_RP_STATUS"), profile.status), 0.75, 0.75, 0.75)
    end
    tooltip:AddLine(Addon:GetText("TOOLTIP_PROFILE_AVAILABLE"), 0.45, 0.85, 0.45)
end

function Addon.PlayerTooltip:Process(tooltip)
    if not tooltip or not tooltip.GetUnit then
        return
    end
    local _, unit = tooltip:GetUnit()
    local characterKey = GetCharacterKey(unit)
    if not characterKey or not Addon.Privacy:CanDisplay(characterKey) then
        tooltip.__foreverRPCharacterKey = nil
        return
    end
    if tooltip.__foreverRPCharacterKey == characterKey then
        return
    end

    tooltip.__foreverRPCharacterKey = characterKey
    if not tooltip.__foreverRPClearHooked and tooltip.HookScript then
        tooltip.__foreverRPClearHooked = true
        tooltip:HookScript("OnTooltipCleared", function(owner)
            owner.__foreverRPCharacterKey = nil
        end)
    end
    AddProfileLines(tooltip, characterKey)
    tooltip:Show()
end

function Addon.PlayerTooltip:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            self:Process(tooltip)
        end)
        return
    end

    if GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
            self:Process(tooltip)
        end)
    end
end
