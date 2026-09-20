local Addon = ForeverRP

Addon.UI = Addon.UI or {}

local function SetCheckButtonText(button, text)
    local label = button.Text or button.text
    if not label then
        label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", button, "RIGHT", 2, 0)
    end
    label:SetText(text)
end

function Addon.UI:CreateSettingsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -24)
    title:SetText(Addon:GetText("SETTINGS_TITLE"))

    local debugCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -4, -20)
    SetCheckButtonText(debugCheck, Addon:GetText("SETTINGS_DEBUG"))
    debugCheck:SetScript("OnClick", function(button)
        Addon.Database:SetDebugEnabled(button:GetChecked())
    end)

    local minimapCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", debugCheck, "BOTTOMLEFT", 0, -10)
    SetCheckButtonText(minimapCheck, Addon:GetText("SETTINGS_MINIMAP"))
    minimapCheck:SetScript("OnClick", function(button)
        local visible = button:GetChecked() == true
        Addon.Database:SetMinimapVisible(visible)
        Addon.MinimapButton:SetVisible(visible)
    end)

    local discoveryTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    discoveryTitle:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 4, -24)
    discoveryTitle:SetText(Addon:GetText("SETTINGS_DISCOVERY"))

    local discoveryCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    discoveryCheck:SetPoint("TOPLEFT", discoveryTitle, "BOTTOMLEFT", -4, -8)
    SetCheckButtonText(discoveryCheck, Addon:GetText("SETTINGS_DISCOVERY_ENABLED"))
    discoveryCheck:SetScript("OnClick", function(button)
        Addon.Database:SetDiscoveryEnabled(button:GetChecked())
    end)

    local privacyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    privacyLabel:SetPoint("TOPLEFT", discoveryCheck, "BOTTOMLEFT", 4, -10)
    privacyLabel:SetText(Addon:GetText("SETTINGS_PRIVACY_MODE"))

    local privacyDropdown = CreateFrame("Frame", "ForeverRPPrivacyDropdown", panel, "UIDropDownMenuTemplate")
    privacyDropdown:SetPoint("TOPLEFT", privacyLabel, "BOTTOMLEFT", -16, -3)
    UIDropDownMenu_SetWidth(privacyDropdown, 170)
    UIDropDownMenu_Initialize(privacyDropdown, function(_, level)
        for _, mode in ipairs(Addon.Constants.PRIVACY_MODES) do
            local privacyMode = mode
            local info = UIDropDownMenu_CreateInfo()
            info.text = Addon:GetText("PRIVACY_" .. string.upper(privacyMode))
            info.value = privacyMode
            info.checked = Addon.Database:GetPrivacyMode() == privacyMode
            info.func = function()
                Addon.Database:SetPrivacyMode(privacyMode)
                UIDropDownMenu_SetSelectedValue(privacyDropdown, privacyMode)
                UIDropDownMenu_SetText(privacyDropdown, info.text)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local radiusLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    radiusLabel:SetPoint("TOPLEFT", privacyDropdown, "BOTTOMLEFT", 20, -8)
    radiusLabel:SetText(Addon:GetText("SETTINGS_DISCOVERY_RADIUS"))

    local radiusDropdown = CreateFrame("Frame", "ForeverRPDiscoveryRadiusDropdown", panel, "UIDropDownMenuTemplate")
    radiusDropdown:SetPoint("TOPLEFT", radiusLabel, "BOTTOMLEFT", -16, -3)
    UIDropDownMenu_SetWidth(radiusDropdown, 150)
    UIDropDownMenu_Initialize(radiusDropdown, function(_, level)
        for _, radius in ipairs(Addon.Constants.DISCOVERY_RADII) do
            local radiusValue = radius
            local info = UIDropDownMenu_CreateInfo()
            info.text = Addon:GetText("DISCOVERY_RADIUS_" .. radiusValue)
            info.value = radiusValue
            info.checked = Addon.Database:GetDiscoveryRadius() == radiusValue
            info.func = function()
                Addon.Database:SetDiscoveryRadius(radiusValue)
                UIDropDownMenu_SetSelectedValue(radiusDropdown, radiusValue)
                UIDropDownMenu_SetText(radiusDropdown, Addon:GetText("DISCOVERY_RADIUS_" .. radiusValue))
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local notificationsTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    notificationsTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 310, -158)
    notificationsTitle:SetText(Addon:GetText("SETTINGS_NOTIFICATIONS"))

    local pulseCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    pulseCheck:SetPoint("TOPLEFT", notificationsTitle, "BOTTOMLEFT", -4, -8)
    SetCheckButtonText(pulseCheck, Addon:GetText("SETTINGS_NOTIFICATION_PULSE"))
    pulseCheck:SetScript("OnClick", function(button)
        Addon.Database:SetNotificationSetting("minimapPulse", button:GetChecked())
    end)

    local soundCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    soundCheck:SetPoint("TOPLEFT", pulseCheck, "BOTTOMLEFT", 0, -4)
    SetCheckButtonText(soundCheck, Addon:GetText("SETTINGS_NOTIFICATION_SOUND"))
    soundCheck:SetScript("OnClick", function(button)
        Addon.Database:SetNotificationSetting("sound", button:GetChecked())
    end)

    local chatCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    chatCheck:SetPoint("TOPLEFT", soundCheck, "BOTTOMLEFT", 0, -4)
    SetCheckButtonText(chatCheck, Addon:GetText("SETTINGS_NOTIFICATION_CHAT"))
    chatCheck:SetScript("OnClick", function(button)
        Addon.Database:SetNotificationSetting("chat", button:GetChecked())
    end)

    panel.debugCheck = debugCheck
    panel.minimapCheck = minimapCheck
    panel.discoveryCheck = discoveryCheck
    panel.privacyDropdown = privacyDropdown
    panel.radiusDropdown = radiusDropdown
    panel.pulseCheck = pulseCheck
    panel.soundCheck = soundCheck
    panel.chatCheck = chatCheck
    self.settingsPanel = panel
    return panel
end

function Addon.UI:RefreshSettings()
    if not self.settingsPanel then
        return
    end

    self.settingsPanel.debugCheck:SetChecked(Addon.Database:IsDebugEnabled())
    self.settingsPanel.minimapCheck:SetChecked(Addon.Database:IsMinimapVisible())
    self.settingsPanel.discoveryCheck:SetChecked(Addon.Database:IsDiscoveryEnabled())
    local privacy = Addon.Database:GetPrivacyMode()
    UIDropDownMenu_SetSelectedValue(self.settingsPanel.privacyDropdown, privacy)
    UIDropDownMenu_SetText(self.settingsPanel.privacyDropdown, Addon:GetText("PRIVACY_" .. string.upper(privacy)))
    local radius = Addon.Database:GetDiscoveryRadius()
    UIDropDownMenu_SetSelectedValue(self.settingsPanel.radiusDropdown, radius)
    UIDropDownMenu_SetText(self.settingsPanel.radiusDropdown, Addon:GetText("DISCOVERY_RADIUS_" .. radius))
    local notifications = Addon.Database:GetNotificationSettings()
    self.settingsPanel.pulseCheck:SetChecked(notifications.minimapPulse)
    self.settingsPanel.soundCheck:SetChecked(notifications.sound)
    self.settingsPanel.chatCheck:SetChecked(notifications.chat)
end
