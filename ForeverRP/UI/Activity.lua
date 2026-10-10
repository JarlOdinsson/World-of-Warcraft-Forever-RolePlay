local Addon = ForeverRP
-- Reuses the experimental Activity panel; no new window or Nearby replacement.
local UI = {rows = {}, filters = {status = "DEFAULT"}}
Addon.ActivityUI = UI
local function Label(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y); label:SetWidth(width); label:SetJustifyH("LEFT"); label:SetText(text)
    return label
end
local function MapName(id)
    local info = id and id > 0 and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    if Addon.ValueAccess:CanAccess(info) and type(info) == "table" and Addon.ValueAccess:IsString(info.name) then return info.name end
    return id and id > 0 and ("Map " .. id) or "Unknown"
end
function UI:Create(parent)
    self.panel = CreateFrame("Frame", nil, parent)
    self.panel:SetAllPoints()
    local title = self.panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20); title:SetText("RP Directory (Experimental)")
    self.status = Label(self.panel, "", 20, -48, 480)
    self.search = CreateFrame("EditBox", nil, self.panel, "InputBoxTemplate")
    self.search:SetPoint("TOPLEFT", 24, -100); self.search:SetSize(160, 24)
    self.search:SetAutoFocus(false); self.search:SetMaxLetters(100)
    self.search:SetScript("OnTextChanged", function(box) self.filters.search = box:GetText(); self:Refresh() end)
    self.search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    Label(self.panel, "Character search", 24, -84, 160)
    self.statusDropdown = CreateFrame("Frame", "ForeverRPDirectoryStatusDropdown", self.panel, "UIDropDownMenuTemplate")
    self.statusDropdown:SetPoint("TOPLEFT", 188, -98); UIDropDownMenu_SetWidth(self.statusDropdown, 125)
    UIDropDownMenu_Initialize(self.statusDropdown, function(_, level)
        for _, choice in ipairs({{"DEFAULT", "IC / LF RP"}, {"IC", "IC"}, {"LFRP", "LF RP"}, {"ALL", "Include OOC / AFK"}}) do
            local value, text = choice[1], choice[2]
            local info = UIDropDownMenu_CreateInfo(); info.text, info.value = text, value
            info.checked = self.filters.status == value
            info.func = function() self.filters.status = value; UIDropDownMenu_SetText(self.statusDropdown, text); self:Refresh() end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetText(self.statusDropdown, "IC / LF RP")
    self.zoneDropdown = CreateFrame("Frame", "ForeverRPDirectoryZoneDropdown", self.panel, "UIDropDownMenuTemplate")
    self.zoneDropdown:SetPoint("TOPLEFT", 334, -98); UIDropDownMenu_SetWidth(self.zoneDropdown, 120)
    UIDropDownMenu_Initialize(self.zoneDropdown, function(_, level)
        local zones, choices = {}, {{value = 0, text = "All zones"}}
        for _, entry in ipairs(Addon.Activity:GetAll()) do
            if entry.directory and entry.zone > 0 then zones[entry.zone] = true end
        end
        local ids = {}; for id in pairs(zones) do ids[#ids + 1] = id end; table.sort(ids)
        for _, id in ipairs(ids) do choices[#choices + 1] = {value = id, text = MapName(id)} end
        for _, choice in ipairs(choices) do
            local value, text = choice.value, choice.text
            local info = UIDropDownMenu_CreateInfo(); info.text, info.value = Addon:EscapePlainText(text), value
            info.checked = (self.filters.zone or 0) == value
            info.func = function() self.filters.zone = value ~= 0 and value or nil; UIDropDownMenu_SetText(self.zoneDropdown, Addon:EscapePlainText(text)); self:Refresh() end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetText(self.zoneDropdown, "All zones")
    local scroll = CreateFrame("ScrollFrame", nil, self.panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -140); scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    self.content = CreateFrame("Frame", nil, scroll); self.content:SetSize(480, 380); scroll:SetScrollChild(self.content)
    self:Refresh(); return self.panel
end
function UI:CreateRow(index)
    local row = CreateFrame("Frame", nil, self.content)
    row:SetSize(480, 62); row:SetPoint("TOPLEFT", 0, -(index - 1) * 64)
    row.identity = Label(row, "", 8, -4, 340)
    row.location = Label(row, "", 8, -24, 340)
    row.detail = Label(row, "", 8, -43, 340)
    row.request = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.request:SetSize(120, 24); row.request:SetPoint("RIGHT", -8, 0)
    row.request:SetScript("OnClick", function()
        -- Revalidate membership/visibility, then reuse the existing explicit action.
        local entry = Addon.Activity:GetPeer(row.characterKey)
        if not Addon.Activity:Enabled() or not entry or not entry.directory or entry.availability == "DND" then self:Refresh(); return end
        Addon.NearbyUI:SelectPlayer(row.characterKey, false)
        self:Refresh()
    end)
    self.rows[index] = row; return row
end
function UI:Refresh()
    if not self.panel or not self.panel:IsShown() or not self.content then return end
    for _, row in ipairs(self.rows) do row:Hide() end
    self.status:SetText(Addon.Activity:Enabled()
        and "Opt-in users, current zone first. Layer: Unknown. Region means continent.\nFilters use cached data only. Directory membership grants no profile access."
        or "Experimental networking is off or unavailable. Enable it in Privacy.\nParticipation, location sharing and full-profile disclosure are separate choices.")
    local entries = Addon.Activity:Enabled() and Addon.Activity:QueryDirectory(self.filters) or {}
    for index, entry in ipairs(entries) do
        local row = self.rows[index] or self:CreateRow(index)
        row.characterKey = entry.characterKey
        row.identity:SetText(Addon:EscapePlainText(entry.characterKey))
        local location = entry.zone > 0 and MapName(entry.zone) or "Location hidden"
        if entry.subzone ~= "" then location = entry.subzone .. ", " .. location end
        row.location:SetText(Addon:EscapePlainText(location) .. " | " .. Addon:EscapePlainText(MapName(entry.region)))
        local status = entry.availability ~= "NORMAL" and entry.availability or entry.status == "LFRP" and "LF RP" or entry.status
        row.detail:SetText(status .. " | Layer unknown")
        local pending = Addon.ProfileTransfer:IsRequestPending(entry.characterKey, false)
        local cached = Addon.RemoteProfiles:HasProfile(entry.characterKey, false)
        local reachable = Addon.Presence:IsConfirmed(entry.characterKey, false) and Addon.Communication:CanBroadcast()
            and Addon.Privacy:CanInteract(entry.characterKey, "WHISPER", false)
        row.request:SetText(cached and "View Profile" or pending and "Request pending" or reachable and "Request Profile" or "Unavailable")
        row.request:SetEnabled(cached or reachable and not pending)
        row:Show()
    end
    self.content:SetHeight(math.max(380, #entries * 64))
end
