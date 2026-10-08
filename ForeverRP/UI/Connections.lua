local Addon = ForeverRP

Addon.ConnectionsUI = {
    rows = {},
}

local function RelativeTime(timestamp)
    if type(timestamp) ~= "number" then
        return Addon:GetText("CONNECTION_NEVER")
    end
    local elapsed = math.max(0, (time and time() or timestamp) - timestamp)
    if elapsed < 60 then
        return Addon:GetText("CONNECTION_JUST_NOW")
    elseif elapsed < 3600 then
        return string.format(Addon:GetText("CONNECTION_MINUTES_AGO"), math.floor(elapsed / 60))
    elseif elapsed < 86400 then
        return string.format(Addon:GetText("CONNECTION_HOURS_AGO"), math.floor(elapsed / 3600))
    end
    return string.format(Addon:GetText("CONNECTION_DAYS_AGO"), math.floor(elapsed / 86400))
end

function Addon.ConnectionsUI:Create(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -18)
    title:SetText(Addon:GetText("CONNECTIONS_TITLE"))

    local empty = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    empty:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    self.empty = empty

    local listScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 8, -52)
    listScroll:SetPoint("BOTTOMLEFT", 8, 12)
    listScroll:SetWidth(245)
    local list = CreateFrame("Frame", nil, listScroll)
    list:SetSize(215, 380)
    listScroll:SetScrollChild(list)
    self.list = list

    local detail = CreateFrame("Frame", nil, panel)
    detail:SetPoint("TOPLEFT", 270, -52)
    detail:SetPoint("BOTTOMRIGHT", -12, 12)
    self.detail = detail

    local identity = detail:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    identity:SetPoint("TOPLEFT", 4, -4)
    identity:SetWidth(245)
    identity:SetJustifyH("LEFT")
    self.identity = identity

    local encountered = detail:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    encountered:SetPoint("TOPLEFT", identity, "BOTTOMLEFT", 0, -8)
    self.encountered = encountered

    local favorite = CreateFrame("CheckButton", nil, detail, "UICheckButtonTemplate")
    favorite:SetPoint("TOPLEFT", encountered, "BOTTOMLEFT", -4, -10)
    local favoriteText = favorite.Text or favorite.text
    if favoriteText then
        favoriteText:SetText(Addon:GetText("CONNECTION_FAVORITE"))
    end
    favorite:SetScript("OnClick", function(button)
        if self.selectedKey then
            Addon.Connections:SetFavorite(self.selectedKey, button:GetChecked(), false)
        end
    end)
    self.favorite = favorite

    local noteLabel = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    noteLabel:SetPoint("TOPLEFT", favorite, "BOTTOMLEFT", 4, -12)
    noteLabel:SetText(Addon:GetText("CONNECTION_PRIVATE_NOTE"))

    local note = CreateFrame("EditBox", nil, detail, "InputBoxTemplate")
    note:SetPoint("TOPLEFT", noteLabel, "BOTTOMLEFT", 4, -6)
    note:SetSize(235, 24)
    note:SetAutoFocus(false)
    note:SetMaxLetters(Addon.Constants.CONNECTION_NOTE_LIMIT)
    note:SetScript("OnEnterPressed", function(box)
        if self.selectedKey then
            Addon.Connections:SetNote(self.selectedKey, box:GetText())
        end
        box:ClearFocus()
    end)
    self.note = note

    local save = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    save:SetSize(72, 24)
    save:SetPoint("TOPLEFT", note, "BOTTOMLEFT", -4, -10)
    save:SetText(Addon:GetText("SAVE"))
    save:SetScript("OnClick", function()
        if self.selectedKey then
            Addon.Connections:SetNote(self.selectedKey, note:GetText())
        end
    end)

    local view = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    view:SetSize(92, 24)
    view:SetPoint("LEFT", save, "RIGHT", 6, 0)
    view:SetText(Addon:GetText("CONNECTION_VIEW_PROFILE"))
    view:SetScript("OnClick", function()
        if self.selectedKey then
            Addon.ProfileViewer:ShowRemote(self.selectedKey, false)
        end
    end)
    self.view = view

    local forget = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    forget:SetSize(72, 24)
    forget:SetPoint("TOPLEFT", save, "BOTTOMLEFT", 0, -8)
    forget:SetText(Addon:GetText("CONNECTION_FORGET"))
    forget:SetScript("OnClick", function()
        if self.selectedKey then
            Addon.Connections:Forget(self.selectedKey, false)
            self.selectedKey = nil
            self:Refresh()
        end
    end)

    self.panel = panel
    self:Refresh()
    return panel
end

function Addon.ConnectionsUI:CreateRow(index)
    local row = CreateFrame("Button", nil, self.list)
    row:SetSize(210, 34)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * 36))
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", 6, 0)
    text:SetWidth(195)
    text:SetJustifyH("LEFT")
    row.text = text
    row:SetScript("OnClick", function(button)
        self.selectedKey = button.characterKey
        self:Refresh()
    end)
    self.rows[index] = row
    return row
end

function Addon.ConnectionsUI:Refresh()
    if not self.panel then
        return
    end
    local hidden = Addon.Database:GetPrivacyMode() == "hidden"
    local connections = Addon.Connections:GetAll()
    self.empty:SetText(hidden and Addon:GetText("CONNECTIONS_HIDDEN") or Addon:GetText("CONNECTIONS_EMPTY"))
    self.empty:SetShown(#connections == 0)

    while #self.rows < #connections do
        self:CreateRow(#self.rows + 1)
    end
    self.list:SetHeight(math.max(380, #connections * 36))
    for index, row in ipairs(self.rows) do
        local connection = connections[index]
        row:SetShown(connection ~= nil)
        if connection then
            local marker = connection.favorite and Addon:GetText("CONNECTION_MARKER_FAVORITE")
                or Addon:GetText("CONNECTION_MARKER_REMEMBERED")
            local name = connection.rpName ~= "" and connection.rpName or connection.characterKey
            row.text:SetText(marker .. " " .. name)
            row.characterKey = connection.characterKey
        end
    end

    local selected = self.selectedKey and Addon.Connections:Get(self.selectedKey, false)
    self.detail:SetShown(selected ~= nil and not hidden)
    if selected then
        local name = selected.rpName ~= "" and selected.rpName or selected.characterKey
        self.identity:SetText(name .. "\n" .. selected.characterKey)
        self.encountered:SetText(string.format(Addon:GetText("CONNECTION_LAST_SEEN"),
            RelativeTime(selected.lastEncountered)))
        self.favorite:SetChecked(selected.favorite == true)
        self.note:SetText(selected.privateNote or "")
        self.view:SetEnabled(Addon.RemoteProfiles:HasProfile(selected.characterKey, false))
    end
end

function Addon.ConnectionsUI:Select(characterKey)
    self.selectedKey = characterKey
    Addon.UI:Show("connections")
    self:Refresh()
end
