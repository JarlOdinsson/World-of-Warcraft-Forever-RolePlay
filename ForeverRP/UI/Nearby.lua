local Addon = ForeverRP

Addon.NearbyUI = {
    rows = {},
}

local function GetProfileSummary(characterKey, includeSimulated)
    local entry = Addon.RemoteProfiles:GetProfile(characterKey, includeSimulated)
    if not entry then
        return nil, nil
    end
    local rpName = entry.profile.rpName ~= "" and entry.profile.rpName or nil
    return rpName, entry.profile.status
end

function Addon.NearbyUI:Create(parent)
    if self.panel then
        return self.panel
    end

    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText(Addon:GetText("NEARBY_PANEL_TITLE"))

    local empty = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    empty:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -24)
    empty:SetText(Addon:GetText("NEARBY_PANEL_EMPTY"))
    self.empty = empty

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -52)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(480, 380)
    scrollFrame:SetScrollChild(content)

    self.panel = panel
    self.content = content
    self:Refresh()
    return panel
end

function Addon.NearbyUI:CreateRow(index)
    local row = CreateFrame("Button", nil, self.content)
    row:SetHeight(38)
    row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -((index - 1) * 40))
    row:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -((index - 1) * 40))
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local identity = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    identity:SetPoint("TOPLEFT", 8, -5)
    identity:SetJustifyH("LEFT")
    local detail = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    detail:SetPoint("TOPLEFT", identity, "BOTTOMLEFT", 0, -3)
    detail:SetJustifyH("LEFT")
    local availability = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    availability:SetPoint("RIGHT", -8, 0)
    availability:SetJustifyH("RIGHT")

    row:SetScript("OnClick", function(button)
        self:SelectPlayer(button.characterKey, button.simulated)
    end)
    row.identity = identity
    row.detail = detail
    row.availability = availability
    self.rows[index] = row
    return row
end

function Addon.NearbyUI:SelectPlayer(characterKey, simulated)
    if Addon.RemoteProfiles:HasProfile(characterKey, simulated == true) then
        Addon.ProfileViewer:ShowRemote(characterKey, simulated == true)
        return
    end
    if Addon.ProfileTransfer:IsRequestPending(characterKey, simulated == true) then
        return
    end
    if simulated then
        Addon.ProfileTransfer:SimulateProfile("valid")
        return
    end
    local requested = Addon.ProfileTransfer:Request(characterKey)
    if requested then
        Addon:Print(string.format(Addon:GetText("PROFILE_REQUEST_SENT"), characterKey))
        self:Refresh()
    else
        Addon:Print(Addon:GetText("PROFILE_REQUEST_UNKNOWN"))
    end
end

function Addon.NearbyUI:Refresh()
    if not self.panel then
        return
    end
    local includeSimulated = Addon.Database:IsDebugEnabled()
    local players = Addon.NearbyPlayers:GetAll(includeSimulated)
    self.empty:SetShown(#players == 0)
    while #self.rows < #players do
        self:CreateRow(#self.rows + 1)
    end
    self.content:SetHeight(math.max(380, #players * 40))

    for index, row in ipairs(self.rows) do
        local player = players[index]
        row:SetShown(player ~= nil)
        if player then
            local rpName, status = GetProfileSummary(player.characterKey, includeSimulated)
            local identity = player.characterKey
            if player.simulated then
                identity = identity .. " " .. Addon:GetText("NEARBY_SIMULATED_MARKER")
            end
            row.identity:SetText(identity)
            row.detail:SetText(rpName and string.format(Addon:GetText("NEARBY_PROFILE_SUMMARY"), rpName, status)
                or Addon:GetText("NEARBY_PROFILE_UNKNOWN"))
            local available = Addon.RemoteProfiles:HasProfile(player.characterKey, includeSimulated)
            local pending = Addon.ProfileTransfer:IsRequestPending(player.characterKey, player.simulated)
            local key = available and "NEARBY_PROFILE_AVAILABLE"
                or (pending and "NEARBY_PROFILE_REQUESTING" or "NEARBY_PROFILE_REQUEST")
            row.availability:SetText(Addon:GetText(key))
            row.characterKey = player.characterKey
            row.simulated = player.simulated == true
        end
    end
end
