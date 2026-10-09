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
            Addon.Connections:SetFavorite(self.selectedKey, button:GetChecked(), self.selectedSimulated == true)
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
    note:SetScript("OnTextChanged", function(_, userInput)
        if userInput then
            self.noteDirty = true
        end
    end)
    note:SetScript("OnEditFocusLost", function()
        self:CommitNote()
    end)
    note:SetScript("OnEnterPressed", function(box)
        self:CommitNote()
        box:ClearFocus()
    end)
    self.note = note

    local save = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    save:SetSize(72, 24)
    save:SetPoint("TOPLEFT", note, "BOTTOMLEFT", -4, -10)
    save:SetText(Addon:GetText("SAVE"))
    save:SetScript("OnClick", function()
        self:CommitNote()
    end)

    local view = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    view:SetSize(110, 24)
    view:SetPoint("LEFT", save, "RIGHT", 6, 0)
    view:SetText(Addon:GetText("CONNECTION_VIEW_PROFILE"))
    view:SetScript("OnClick", function()
        self:OpenProfile()
    end)
    self.view = view

    local forget = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    forget:SetSize(72, 24)
    forget:SetPoint("TOPLEFT", save, "BOTTOMLEFT", 0, -8)
    forget:SetText(Addon:GetText("CONNECTION_FORGET"))
    forget:SetScript("OnClick", function()
        if self.selectedKey then
            Addon.Connections:Forget(self.selectedKey, self.selectedSimulated == true)
            self.selectedKey = nil
            self.selectedSimulated = false
            self:Refresh()
        end
    end)

    panel:SetScript("OnHide", function()
        self:CommitNote()
    end)
    local elapsedSinceRefresh = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        elapsedSinceRefresh = elapsedSinceRefresh + elapsed
        if elapsedSinceRefresh >= 1 then
            elapsedSinceRefresh = 0
            self:RefreshProfileAction()
            self:RefreshEncounterLabel()
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
        self:Select(button.characterKey, button.simulated)
    end)
    self.rows[index] = row
    return row
end

function Addon.ConnectionsUI:Refresh()
    if not self.panel then
        return
    end
    local hidden = Addon.Database:GetPrivacyMode() == "hidden"
    local includeSimulated = Addon.Database:IsDebugEnabled()
    local connections = Addon.Connections:GetAll(includeSimulated)
    if self.selectedSimulated and not includeSimulated then
        self:CommitNote()
        self.selectedKey = nil
        self.selectedSimulated = false
    end
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
            if connection.simulated then
                name = name .. " " .. Addon:GetText("CONNECTION_SIMULATED_MARKER")
            end
            row.text:SetText(marker .. " " .. name)
            row.characterKey = connection.characterKey
            row.simulated = connection.simulated == true
        end
    end

    local selected = self.selectedKey and Addon.Connections:Get(self.selectedKey, self.selectedSimulated == true)
    self.detail:SetShown(selected ~= nil and not hidden)
    if selected then
        local name = selected.rpName ~= "" and selected.rpName or selected.characterKey
        self.identity:SetText(name .. "\n" .. selected.characterKey)
        self:RefreshEncounterLabel()
        self.favorite:SetChecked(selected.favorite == true)
        if self.noteKey ~= self.selectedKey or self.noteSimulated ~= self.selectedSimulated then
            self:CommitNote()
            self.noteKey = self.selectedKey
            self.noteSimulated = self.selectedSimulated == true
        end
        if not self.noteDirty and self.note:GetText() ~= (selected.privateNote or "") then
            self.note:SetText(selected.privateNote or "")
        end
    end
    self:RefreshProfileAction()
end

function Addon.ConnectionsUI:RefreshEncounterLabel()
    if not self.encountered or not self.selectedKey then
        return
    end
    local connection = Addon.Connections:Get(self.selectedKey, self.selectedSimulated == true)
    if connection then
        self.encountered:SetText(string.format(Addon:GetText("CONNECTION_LAST_SEEN"),
            RelativeTime(connection.lastEncountered)))
    end
end

function Addon.ConnectionsUI:CommitNote()
    if not self.note or not self.noteKey or not self.noteDirty then
        return
    end
    -- Clear before SetNote: saving refreshes this panel synchronously.
    self.noteDirty = false
    Addon.Connections:SetNote(self.noteKey, self.note:GetText(), self.noteSimulated == true)
end

function Addon.ConnectionsUI:GetProfileAction()
    local characterKey = self.selectedKey
    local simulated = self.selectedSimulated == true
    if not characterKey or not Addon.Connections:Get(characterKey, simulated)
        or Addon.Database:GetPrivacyMode() == "hidden" then
        return "unavailable"
    end
    if simulated and not Addon.Database:IsDebugEnabled() then
        return "unavailable"
    end
    if Addon.RemoteProfiles:HasProfile(characterKey, simulated) then
        return "view", characterKey, simulated
    end
    if simulated then
        if Addon.Database:IsDebugEnabled() and Addon.Presence:IsConfirmed(characterKey, true) then
            return "request", characterKey, true
        end
        return "unavailable"
    end
    -- ResolveKnownKey alone does not expire stale presence entries.
    Addon.Presence:Expire()
    local target = Addon.Presence:ResolveKnownKey(characterKey, false)
    if not target or not Addon.Presence:IsConfirmed(target, false)
        or not Addon.Communication:CanBroadcast()
        or not Addon.Privacy:CanInteract(target, "WHISPER", false) then
        return "unavailable"
    end
    if Addon.ProfileTransfer:IsRequestPending(target, false) then
        return "pending", target
    end
    return "request", target, false
end

function Addon.ConnectionsUI:RefreshProfileAction()
    if not self.view then
        return
    end
    local action = self:GetProfileAction()
    local textKey = action == "view" and "CONNECTION_VIEW_PROFILE"
        or (action == "request" and "NEARBY_PROFILE_REQUEST"
        or (action == "pending" and "NEARBY_PROFILE_REQUESTING" or "CONNECTION_PROFILE_UNAVAILABLE"))
    self.view:SetText(Addon:GetText(textKey))
    self.view:SetEnabled(action == "view" or action == "request")
end

function Addon.ConnectionsUI:OpenProfile()
    local action, characterKey, simulated = self:GetProfileAction()
    if action == "view" then
        Addon.ProfileViewer:ShowRemote(characterKey, simulated)
    elseif action == "request" then
        if simulated then
            Addon.ProfileTransfer:SimulateProfile("valid")
        else
            local requested = Addon.ProfileTransfer:Request(characterKey)
            Addon:Print(requested and string.format(Addon:GetText("PROFILE_REQUEST_SENT"), characterKey)
                or Addon:GetText("PROFILE_REQUEST_SEND_FAILED"))
        end
    end
    self:RefreshProfileAction()
end

function Addon.ConnectionsUI:Select(characterKey, simulated)
    self:CommitNote()
    self.selectedKey = characterKey
    self.selectedSimulated = simulated == true
    Addon.UI:Show("connections")
    self:Refresh()
end
