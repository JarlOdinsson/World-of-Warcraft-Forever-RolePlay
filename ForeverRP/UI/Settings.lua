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

    local minimapCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -4, -20)
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
    notificationsTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 310, -24)
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

    local soundChannelLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    soundChannelLabel:SetPoint("TOPLEFT", chatCheck, "BOTTOMLEFT", 4, -10)
    soundChannelLabel:SetText(Addon:GetText("SETTINGS_NOTIFICATION_CHANNEL"))
    local soundChannelDropdown = CreateFrame("Frame", "ForeverRPNotificationSoundChannelDropdown", panel, "UIDropDownMenuTemplate")
    soundChannelDropdown:SetPoint("TOPLEFT", soundChannelLabel, "BOTTOMLEFT", -16, -3)
    UIDropDownMenu_SetWidth(soundChannelDropdown, 100)
    UIDropDownMenu_Initialize(soundChannelDropdown, function(_, level)
        for _, channel in ipairs({ "Master", "SFX" }) do
            local value = channel
            local info = UIDropDownMenu_CreateInfo()
            info.text = Addon:GetText("SETTINGS_SOUND_" .. string.upper(value))
            info.value = value
            info.checked = Addon.Database:GetNotificationSettings().soundChannel == value
            info.func = function()
                Addon.Database:SetNotificationSoundChannel(value)
                Addon.UI:RefreshSettings()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    local testSound = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testSound:SetSize(90, 24)
    testSound:SetPoint("LEFT", soundChannelDropdown, "RIGHT", 0, 2)
    testSound:SetText(Addon:GetText("SETTINGS_TEST_SOUND"))
    testSound:SetScript("OnClick", function() Addon.Notifications:TestSound() end)
    local soundChoiceLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    soundChoiceLabel:SetPoint("TOPLEFT", soundChannelDropdown, "BOTTOMLEFT", 20, -8)
    soundChoiceLabel:SetText("Notification sound")
    local soundChoiceDropdown = CreateFrame("Frame", "ForeverRPNotificationSoundDropdown", panel, "UIDropDownMenuTemplate")
    soundChoiceDropdown:SetPoint("TOPLEFT", soundChoiceLabel, "BOTTOMLEFT", -16, -3)
    UIDropDownMenu_SetWidth(soundChoiceDropdown, 190)
    local choices = {{"bingbong", "Bing Bong"}, {"drumroll", "Drumroll (legacy)"}, {"none", "None"}}
    UIDropDownMenu_Initialize(soundChoiceDropdown, function(_, level)
        for _, choice in ipairs(choices) do
            local value, label = choice[1], choice[2]
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = label, value
            info.checked = Addon.Database:GetNotificationSettings().soundChoice == value
            info.func = function()
                Addon.Database:SetNotificationSoundChoice(value)
                Addon.UI:RefreshSettings()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    local privacyOptions = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    privacyOptions:SetSize(220, 24)
    privacyOptions:SetPoint("BOTTOMLEFT", 24, 20)
    privacyOptions:SetText("Discovery & Profile Privacy")
    privacyOptions:SetScript("OnClick", function() Addon.UI:ShowPanel("privacy") end)

    local emoteTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    emoteTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 310, -318)
    emoteTitle:SetText(Addon:GetText("SETTINGS_EMOTE_BAR"))

    local emoteEnabled = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    emoteEnabled:SetPoint("TOPLEFT", emoteTitle, "BOTTOMLEFT", -4, -6)
    SetCheckButtonText(emoteEnabled, Addon:GetText("SETTINGS_EMOTE_ENABLED"))
    emoteEnabled:SetScript("OnClick", function(button)
        Addon.EmoteBar:SetEnabled(button:GetChecked())
    end)

    local emoteLocked = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    emoteLocked:SetPoint("LEFT", emoteEnabled, "RIGHT", 98, 0)
    SetCheckButtonText(emoteLocked, Addon:GetText("SETTINGS_EMOTE_LOCKED"))
    emoteLocked:SetScript("OnClick", function(button)
        Addon.EmoteBar:SetLocked(button:GetChecked())
    end)

    local slotDropdown = CreateFrame("Frame", "ForeverRPEmoteCountDropdown", panel, "UIDropDownMenuTemplate")
    slotDropdown:SetPoint("TOPLEFT", emoteEnabled, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(slotDropdown, 70)
    UIDropDownMenu_Initialize(slotDropdown, function(_, level)
        for count = 1, 12 do
            local value = count
            local info = UIDropDownMenu_CreateInfo()
            info.text = string.format(Addon:GetText("EMOTE_SLOT_COUNT"), value)
            info.value = value
            info.checked = Addon.EmoteBar:GetSettings().slots == value
            info.func = function()
                Addon.EmoteBar:SetSlots(value)
                Addon.UI:RefreshSettings()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local scaleDropdown = CreateFrame("Frame", "ForeverRPEmoteScaleDropdown", panel, "UIDropDownMenuTemplate")
    scaleDropdown:SetPoint("LEFT", slotDropdown, "RIGHT", 8, 0)
    UIDropDownMenu_SetWidth(scaleDropdown, 72)
    UIDropDownMenu_Initialize(scaleDropdown, function(_, level)
        for _, scale in ipairs(Addon.Constants.EMOTE_BAR_SCALES) do
            local value = scale
            local info = UIDropDownMenu_CreateInfo()
            info.text = string.format("%d%%", value * 100)
            info.value = value
            info.checked = Addon.EmoteBar:GetSettings().scale == value
            info.func = function()
                Addon.EmoteBar:SetScale(value)
                Addon.UI:RefreshSettings()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local configure = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    configure:SetSize(100, 24)
    configure:SetPoint("TOPLEFT", slotDropdown, "BOTTOMLEFT", 20, -4)
    configure:SetText(Addon:GetText("SETTINGS_EMOTE_CONFIGURE"))
    configure:SetScript("OnClick", function()
        Addon.UI:ShowPanel("emotes")
    end)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(100, 24)
    reset:SetPoint("LEFT", configure, "RIGHT", 8, 0)
    reset:SetText(Addon:GetText("SETTINGS_EMOTE_RESET"))
    reset:SetScript("OnClick", function()
        Addon.EmoteBar:ResetPosition()
    end)

    panel.minimapCheck = minimapCheck
    panel.discoveryCheck = discoveryCheck
    panel.privacyDropdown = privacyDropdown
    panel.radiusDropdown = radiusDropdown
    panel.pulseCheck = pulseCheck
    panel.soundCheck = soundCheck
    panel.chatCheck = chatCheck
    panel.soundChannelDropdown = soundChannelDropdown
    panel.testSound = testSound
    panel.soundChoiceDropdown = soundChoiceDropdown
    panel.emoteEnabled = emoteEnabled
    panel.emoteLocked = emoteLocked
    panel.emoteSlotDropdown = slotDropdown
    panel.emoteScaleDropdown = scaleDropdown
    self.settingsPanel = panel
    return panel
end

function Addon.UI:RefreshSettings()
    if not self.settingsPanel then
        return
    end

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
    UIDropDownMenu_SetSelectedValue(self.settingsPanel.soundChannelDropdown, notifications.soundChannel)
    UIDropDownMenu_SetText(self.settingsPanel.soundChannelDropdown,
        Addon:GetText("SETTINGS_SOUND_" .. string.upper(notifications.soundChannel)))
    local soundLabels = {bingbong = "Bing Bong", drumroll = "Drumroll (legacy)", none = "None"}
    UIDropDownMenu_SetSelectedValue(self.settingsPanel.soundChoiceDropdown, notifications.soundChoice)
    UIDropDownMenu_SetText(self.settingsPanel.soundChoiceDropdown, soundLabels[notifications.soundChoice] or "Drumroll (legacy)")
    local emoteBar = Addon.EmoteBar:GetSettings()
    self.settingsPanel.emoteEnabled:SetChecked(emoteBar.enabled)
    self.settingsPanel.emoteLocked:SetChecked(emoteBar.locked)
    UIDropDownMenu_SetSelectedValue(self.settingsPanel.emoteSlotDropdown, emoteBar.slots)
    UIDropDownMenu_SetText(self.settingsPanel.emoteSlotDropdown,
        string.format(Addon:GetText("EMOTE_SLOT_COUNT"), emoteBar.slots))
    UIDropDownMenu_SetSelectedValue(self.settingsPanel.emoteScaleDropdown, emoteBar.scale)
    UIDropDownMenu_SetText(self.settingsPanel.emoteScaleDropdown, string.format("%d%%", emoteBar.scale * 100))
end
