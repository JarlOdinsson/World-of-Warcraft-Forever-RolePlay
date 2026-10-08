local Addon = ForeverRP

Addon.EmoteConfigUI = {
    selectedSlot = 1,
    selectedType = "emote",
}

function Addon.EmoteConfigUI:Create(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText(Addon:GetText("EMOTE_CONFIG_TITLE"))

    local slotLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    slotLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -22)
    slotLabel:SetText(Addon:GetText("EMOTE_CONFIG_SLOT"))

    local slotDropdown = CreateFrame("Frame", "ForeverRPEmoteSlotDropdown", panel, "UIDropDownMenuTemplate")
    slotDropdown:SetPoint("TOPLEFT", slotLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(slotDropdown, 100)
    UIDropDownMenu_Initialize(slotDropdown, function(_, level)
        for index = 1, Addon.Constants.EMOTE_BAR_MAX_SLOTS do
            local slot = index
            local info = UIDropDownMenu_CreateInfo()
            info.text = string.format(Addon:GetText("EMOTE_SLOT_NUMBER"), slot)
            info.value = slot
            info.checked = self.selectedSlot == slot
            info.func = function()
                self.selectedSlot = slot
                self:Refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self.slotDropdown = slotDropdown

    local presetLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    presetLabel:SetPoint("TOPLEFT", slotDropdown, "BOTTOMLEFT", 20, -12)
    presetLabel:SetText(Addon:GetText("EMOTE_CONFIG_PRESET"))

    local presetDropdown = CreateFrame("Frame", "ForeverRPEmotePresetDropdown", panel, "UIDropDownMenuTemplate")
    presetDropdown:SetPoint("TOPLEFT", presetLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(presetDropdown, 180)
    UIDropDownMenu_Initialize(presetDropdown, function(_, level)
        for _, preset in ipairs(Addon.EmoteBar.presets) do
            local selected = preset
            local info = UIDropDownMenu_CreateInfo()
            info.text = selected[1]
            info.func = function()
                self.titleBox:SetText(selected[1])
                self.commandBox:SetText(selected[3])
                self.selectedType = selected[2]
                UIDropDownMenu_SetSelectedValue(self.typeDropdown, selected[2])
                UIDropDownMenu_SetText(self.typeDropdown,
                    Addon:GetText(selected[2] == "emote" and "EMOTE_TYPE_BLIZZARD" or "EMOTE_TYPE_CUSTOM"))
                UIDropDownMenu_SetText(presetDropdown, selected[1])
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local titleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    titleLabel:SetPoint("TOPLEFT", presetDropdown, "BOTTOMLEFT", 20, -12)
    titleLabel:SetText(Addon:GetText("EMOTE_CONFIG_BUTTON_TITLE"))
    local titleBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    titleBox:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 4, -6)
    titleBox:SetSize(220, 24)
    titleBox:SetAutoFocus(false)
    titleBox:SetMaxLetters(32)
    self.titleBox = titleBox

    local typeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    typeLabel:SetPoint("TOPLEFT", titleBox, "BOTTOMLEFT", -4, -14)
    typeLabel:SetText(Addon:GetText("EMOTE_CONFIG_TYPE"))
    local typeDropdown = CreateFrame("Frame", "ForeverRPEmoteTypeDropdown", panel, "UIDropDownMenuTemplate")
    typeDropdown:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(typeDropdown, 180)
    UIDropDownMenu_Initialize(typeDropdown, function(_, level)
        for _, actionType in ipairs({ "emote", "custom" }) do
            local selected = actionType
            local info = UIDropDownMenu_CreateInfo()
            info.text = Addon:GetText(selected == "emote" and "EMOTE_TYPE_BLIZZARD" or "EMOTE_TYPE_CUSTOM")
            info.value = selected
            info.checked = self.selectedType == selected
            info.func = function()
                self.selectedType = selected
                UIDropDownMenu_SetSelectedValue(typeDropdown, selected)
                UIDropDownMenu_SetText(typeDropdown, info.text)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self.typeDropdown = typeDropdown

    local commandLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    commandLabel:SetPoint("TOPLEFT", typeDropdown, "BOTTOMLEFT", 20, -12)
    commandLabel:SetText(Addon:GetText("EMOTE_CONFIG_ACTION"))
    local commandBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    commandBox:SetPoint("TOPLEFT", commandLabel, "BOTTOMLEFT", 4, -6)
    commandBox:SetSize(430, 24)
    commandBox:SetAutoFocus(false)
    commandBox:SetMaxLetters(255)
    self.commandBox = commandBox

    local save = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    save:SetSize(100, 26)
    save:SetPoint("TOPLEFT", commandBox, "BOTTOMLEFT", -4, -16)
    save:SetText(Addon:GetText("SAVE"))
    save:SetScript("OnClick", function()
        Addon.EmoteBar:SetAction(self.selectedSlot, titleBox:GetText(), self.selectedType, commandBox:GetText())
        Addon:Print(Addon:GetText("EMOTE_SLOT_SAVED"))
    end)

    self.panel = panel
    self:Refresh()
    return panel
end

function Addon.EmoteConfigUI:Refresh()
    if not self.panel then
        return
    end
    local action = Addon.EmoteBar:GetSettings().actions[self.selectedSlot]
    self.selectedType = action.type
    UIDropDownMenu_SetSelectedValue(self.slotDropdown, self.selectedSlot)
    UIDropDownMenu_SetText(self.slotDropdown, string.format(Addon:GetText("EMOTE_SLOT_NUMBER"), self.selectedSlot))
    UIDropDownMenu_SetSelectedValue(self.typeDropdown, action.type)
    UIDropDownMenu_SetText(self.typeDropdown,
        Addon:GetText(action.type == "emote" and "EMOTE_TYPE_BLIZZARD" or "EMOTE_TYPE_CUSTOM"))
    self.titleBox:SetText(action.title)
    self.commandBox:SetText(action.command)
end
