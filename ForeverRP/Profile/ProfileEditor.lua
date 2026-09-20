local Addon = ForeverRP

local Editor = {
    fields = {},
    initialized = false,
    refreshing = false,
}
Addon.ProfileEditor = Editor

local SINGLE_FIELDS = {
    { key = "rpName", label = "PROFILE_RP_NAME" },
    { key = "title", label = "PROFILE_CHARACTER_TITLE" },
    { key = "race", label = "PROFILE_RACE" },
    { key = "class", label = "PROFILE_CLASS" },
    { key = "age", label = "PROFILE_AGE" },
    { key = "pronouns", label = "PROFILE_PRONOUNS" },
    { key = "currently", label = "PROFILE_CURRENTLY" },
}

local MULTILINE_FIELDS = {
    { key = "atAGlance", label = "PROFILE_AT_A_GLANCE", height = 100 },
    { key = "description", label = "PROFILE_DESCRIPTION", height = 130 },
    { key = "history", label = "PROFILE_HISTORY", height = 130 },
    { key = "oocNotes", label = "PROFILE_OOC_NOTES", height = 100 },
}

local function Trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

local function UpdateMultilineHeight(editBox, viewportHeight)
    local text = editBox:GetText() or ""
    local visualLines = 0
    for line in (text .. "\n"):gmatch("(.-)\n") do
        visualLines = visualLines + math.max(1, math.ceil(#line / 62))
    end
    editBox:SetHeight(math.max(viewportHeight, (visualLines * 14) + 12))
end

function Editor:CommitField(field)
    local editBox = self.fields[field]
    if not editBox or self.refreshing then
        return
    end

    local value = editBox:GetText() or ""
    if not editBox.isMultiline then
        value = Trim(value)
    end
    Addon.Profile:SetField(field, value)
    editBox:SetText(Addon.Profile:GetField(field) or "")
    self:UpdateCompletion()
end

local function CreateSingleField(parent, definition, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(Addon:GetText(definition.label))

    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(214, 24)
    editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 4, -4)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(Addon.Constants.PROFILE_LIMITS[definition.key])
    editBox:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(box)
        box:SetText(Addon.Profile:GetField(definition.key) or "")
        box:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusLost", function()
        Editor:CommitField(definition.key)
    end)

    Editor.fields[definition.key] = editBox
end

local function CreateMultilineField(parent, definition, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 4, y)
    label:SetText(Addon:GetText(definition.label))

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(460, definition.height)
    scrollFrame:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)

    local background = scrollFrame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.03, 0.03, 0.03, 0.65)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetWidth(432)
    editBox:SetHeight(definition.height)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextInsets(6, 6, 6, 6)
    editBox:SetMaxLetters(Addon.Constants.PROFILE_LIMITS[definition.key])
    editBox:SetScript("OnEscapePressed", function(box)
        box:SetText(Addon.Profile:GetField(definition.key) or "")
        box:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusLost", function()
        Editor:CommitField(definition.key)
    end)
    editBox:SetScript("OnTextChanged", function(box)
        UpdateMultilineHeight(box, definition.height)
        scrollFrame:UpdateScrollChildRect()
    end)
    editBox:SetScript("OnCursorChanged", function(_, _, cursorY, _, cursorHeight)
        local offset = scrollFrame:GetVerticalScroll()
        local cursorTop = -cursorY
        local cursorBottom = cursorTop + cursorHeight
        if cursorTop < offset then
            scrollFrame:SetVerticalScroll(cursorTop)
        elseif cursorBottom > offset + scrollFrame:GetHeight() then
            scrollFrame:SetVerticalScroll(cursorBottom - scrollFrame:GetHeight())
        end
    end)
    editBox.isMultiline = true
    scrollFrame:SetScrollChild(editBox)

    Editor.fields[definition.key] = editBox
    return y - definition.height - 42
end

function Editor:Create(parent)
    if self.panel then
        return self.panel
    end

    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(480, 1020)
    scrollFrame:SetScrollChild(content)

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 4, -4)
    title:SetText(Addon:GetText("PROFILE_TITLE"))

    self.completion = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.completion:SetPoint("TOPRIGHT", -8, -8)

    for index, definition in ipairs(SINGLE_FIELDS) do
        local zeroIndex = index - 1
        local column = zeroIndex % 2
        local row = math.floor(zeroIndex / 2)
        CreateSingleField(content, definition, 4 + (column * 238), -42 - (row * 58))
    end

    local statusLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusLabel:SetPoint("TOPLEFT", 242, -216)
    statusLabel:SetText(Addon:GetText("PROFILE_STATUS"))

    local statusDropdown = CreateFrame("Frame", "ForeverRPProfileStatusDropdown", content, "UIDropDownMenuTemplate")
    statusDropdown:SetPoint("TOPLEFT", statusLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(statusDropdown, 180)
    UIDropDownMenu_Initialize(statusDropdown, function(_, level)
        for _, status in ipairs(Addon.Constants.PROFILE_STATUSES) do
            local statusValue = status
            local info = UIDropDownMenu_CreateInfo()
            info.text = Addon:GetText("PROFILE_STATUS_" .. statusValue)
            info.value = statusValue
            info.checked = Addon.Profile:GetField("status") == statusValue
            info.func = function()
                Addon.Profile:SetField("status", statusValue)
                UIDropDownMenu_SetSelectedValue(statusDropdown, statusValue)
                UIDropDownMenu_SetText(statusDropdown, Addon:GetText("PROFILE_STATUS_" .. statusValue))
                self:UpdateCompletion()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self.statusDropdown = statusDropdown

    local y = -286
    for _, definition in ipairs(MULTILINE_FIELDS) do
        y = CreateMultilineField(content, definition, y)
    end

    local resetButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetButton:SetSize(130, 24)
    resetButton:SetPoint("TOPLEFT", 4, y - 4)
    resetButton:SetText(Addon:GetText("PROFILE_RESET"))
    resetButton:SetScript("OnClick", function()
        StaticPopup_Show("FOREVERRP_RESET_PROFILE")
    end)

    self.panel = panel
    self.initialized = true
    self:Refresh()
    return panel
end

function Editor:Commit()
    if not self.initialized then
        return
    end
    for field in pairs(self.fields) do
        self:CommitField(field)
    end
end

function Editor:Refresh()
    if not self.initialized then
        return
    end

    self.refreshing = true
    for field, editBox in pairs(self.fields) do
        editBox:SetText(Addon.Profile:GetField(field) or "")
    end
    local status = Addon.Profile:GetField("status") or "OOC"
    UIDropDownMenu_SetSelectedValue(self.statusDropdown, status)
    UIDropDownMenu_SetText(self.statusDropdown, Addon:GetText("PROFILE_STATUS_" .. status))
    self.refreshing = false
    self:UpdateCompletion()
end

function Editor:UpdateCompletion()
    if not self.completion then
        return
    end
    local completed, total = Addon.Profile:GetCompletion()
    self.completion:SetText(string.format(Addon:GetText("PROFILE_COMPLETION"), completed, total))
end

StaticPopupDialogs.FOREVERRP_RESET_PROFILE = {
    text = Addon:GetText("PROFILE_RESET_CONFIRM"),
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        Addon.Profile:Reset()
        Editor:Refresh()
        Addon:Print(Addon:GetText("PROFILE_SAVED"))
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
