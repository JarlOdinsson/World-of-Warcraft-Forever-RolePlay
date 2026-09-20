local Addon = ForeverRP

local Viewer = {
    rows = {},
}
Addon.ProfileViewer = Viewer

local VIEW_FIELDS = {
    { key = "rpName", label = "PROFILE_RP_NAME" },
    { key = "title", label = "PROFILE_CHARACTER_TITLE" },
    { key = "race", label = "PROFILE_RACE" },
    { key = "class", label = "PROFILE_CLASS" },
    { key = "age", label = "PROFILE_AGE" },
    { key = "pronouns", label = "PROFILE_PRONOUNS" },
    { key = "status", label = "PROFILE_STATUS" },
    { key = "currently", label = "PROFILE_CURRENTLY" },
    { key = "atAGlance", label = "PROFILE_AT_A_GLANCE" },
    { key = "description", label = "PROFILE_DESCRIPTION" },
    { key = "history", label = "PROFILE_HISTORY" },
    { key = "oocNotes", label = "PROFILE_OOC_NOTES" },
}

local function PlainText(value)
    value = type(value) == "string" and value or ""
    if value == "" then
        return Addon:GetText("PROFILE_VIEWER_EMPTY")
    end
    local escaped = value:gsub("|", "||")
    return escaped
end

function Viewer:Create(parent)
    if self.panel then
        return self.panel
    end

    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(480, 600)
    scrollFrame:SetScrollChild(content)

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 4, -4)
    title:SetText(Addon:GetText("PROFILE_VIEWER_TITLE"))

    local contextLabel = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    contextLabel:SetPoint("LEFT", title, "RIGHT", 10, 0)
    contextLabel:SetText(Addon:GetText("PROFILE_VIEWER_LOCAL"))

    for _, definition in ipairs(VIEW_FIELDS) do
        local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetText(Addon:GetText(definition.label))

        local value = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        value:SetWidth(450)
        value:SetJustifyH("LEFT")
        value:SetJustifyV("TOP")
        value:SetWordWrap(true)

        self.rows[#self.rows + 1] = {
            key = definition.key,
            label = label,
            value = value,
        }
    end

    self.panel = panel
    self.content = content
    self.title = title
    self.contextLabel = contextLabel
    self:Refresh()
    return panel
end

function Viewer:Refresh()
    if not self.panel then
        return
    end

    local profile = Addon.Profile:Get()
    if self.remoteCharacterKey then
        local entry = Addon.RemoteProfiles:GetProfile(self.remoteCharacterKey, self.includeSimulated == true)
        if entry then
            profile = entry.profile
            self.title:SetText(profile.rpName ~= "" and profile.rpName or Addon:GetText("PROFILE_VIEWER_TITLE"))
            self.contextLabel:SetText(string.format(Addon:GetText("PROFILE_VIEWER_REMOTE"), entry.characterKey))
        else
            self.remoteCharacterKey = nil
            self.includeSimulated = false
        end
    end
    if not self.remoteCharacterKey then
        self.title:SetText(Addon:GetText("PROFILE_VIEWER_TITLE"))
        self.contextLabel:SetText(Addon:GetText("PROFILE_VIEWER_LOCAL"))
    end

    local y = -48
    for _, row in ipairs(self.rows) do
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, y)
        y = y - 18

        row.value:ClearAllPoints()
        row.value:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, y)
        row.value:SetText(PlainText(profile[row.key]))
        y = y - math.max(18, row.value:GetStringHeight()) - 18
    end

    self.content:SetHeight(math.max(600, -y + 20))
end

function Viewer:ShowLocal()
    self.remoteCharacterKey = nil
    self.includeSimulated = false
    self:Refresh()
end

function Viewer:ShowRemote(characterKey, includeSimulated)
    if not Addon.RemoteProfiles:HasProfile(characterKey, includeSimulated) then
        return false
    end
    self.remoteCharacterKey = characterKey
    self.includeSimulated = includeSimulated == true
    Addon.UI:Show("viewer")
    self:Refresh()
    return true
end

function Viewer:RefreshIfViewing(characterKey)
    if self.remoteCharacterKey and string.lower(self.remoteCharacterKey) == string.lower(characterKey) then
        self:Refresh()
    end
end
