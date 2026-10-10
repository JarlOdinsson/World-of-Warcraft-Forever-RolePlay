local Addon = ForeverRP
local Options = {rows = {}, dropdowns = {}}
Addon.DiscoveryOptions = Options
local function Text(parent, value, x, y, width)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width or 480)
    label:SetJustifyH("LEFT")
    label:SetText(value)
    return label
end
local function Button(parent, text, x, y, width, action)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width, 24)
    button:SetText(text)
    button:SetScript("OnClick", action)
    return button
end

function Options:Dropdown(parent, name, title, x, y, choices, get, set)
    Text(parent, title, x, y, 240)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", x - 16, y - 18)
    UIDropDownMenu_SetWidth(dropdown, 190)
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, choice in ipairs(choices) do
            local value, label = choice[1], choice[2]
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value, info.checked = label, value, get() == value
            info.func = function() set(value); self:Refresh() end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self.dropdowns[#self.dropdowns + 1] = {widget = dropdown, choices = choices, get = get}
end

function Options:Create(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    self.panel = panel
    Text(panel, "Discovery & Privacy", 20, -20)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -45)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(480, 900)
    scroll:SetScrollChild(content)
    self.content = content
    self:Dropdown(content, "ForeverRPDisclosureDropdown", "Full-profile disclosure", 12, -5,
        {{"public", "Public"}, {"approval", "Approval Required"}, {"connections", "Connections Only"}},
        function() return Addon.Database:GetDisclosureMode() end,
        function(value) Addon.Database:SetDisclosureMode(value) end)
    Text(content, "Public uses existing visibility rules. Approval Required asks before each transfer.\nConnections Only requires both Remember and your explicit approval below.\nAn approval grants access to your full profile; it is not mutual authorization.", 12, -65)
    self.visibilityStatus = Text(content, "", 12, -110, 460)
    self:Dropdown(content, "ForeverRPLocationDropdown", "Location sharing (experimental network only)", 12, -130,
        {{"hidden", "Don't share my location"}, {"zone", "Share zone only"}, {"precise", "Share precise location"}},
        function() return Addon.Database:GetActivitySettings().location end,
        function(value) Addon.Database:SetActivitySetting("location", value) end)
    Text(content, "Withholding location still allows browsing when networking is enabled.\nHidden Discovery Visibility disables networking and location sharing.\nLayer: Unknown; coordinates do not prove a shared layer.", 12, -185, 460)
    self.experimental = Button(content, "", 12, -230, 230, function()
        Addon.Database:SetActivitySetting("enabled", not Addon.Database:GetActivitySettings().enabled)
        self:Refresh()
    end)
    self.markers = Button(content, "", 252, -230, 220, function()
        Addon.Database:SetActivitySetting("markers", not Addon.Database:GetActivitySettings().markers)
        self:Refresh()
    end)
    Text(content, "Experimental networking defaults OFF. Cross-layer delivery is unverified.\nMarkers are neutral and never open or request profiles.", 12, -260, 460)
    self.networkStatus = Text(content, "", 12, -290, 460)
    Button(content, "RP Directory", 12, -320, 150, function() Addon.UI:ShowPanel("activity") end)
    self.directory = Button(content, "", 170, -320, 230, function()
        Addon.Database:SetActivitySetting("directory", not Addon.Database:GetActivitySettings().directory)
        self:Refresh()
    end)
    self.subzone = Button(content, "", 12, -355, 230, function()
        Addon.Database:SetActivitySetting("subzone", not Addon.Database:GetActivitySettings().subzone)
        self:Refresh()
    end)
    Text(content, "Directory Participation lists your character; OFF still allows browsing.\nDon't share my location omits zone, region and subzone; DND is never listed.\nDirectory listing grants no full-profile access and is separate from Nearby.", 12, -390, 460)
    Text(content, "Pending requests (expire after 25 seconds)", 12, -435)
    Text(content, "Explicit Connections approvals — these apply only to this character's profile", 12, -750)
    self:Refresh()
    return panel
end

function Options:Refresh()
    if not self.panel then return end
    for _, item in ipairs(self.dropdowns) do
        local value = item.get()
        UIDropDownMenu_SetSelectedValue(item.widget, value)
        for _, choice in ipairs(item.choices) do
            if choice[1] == value then UIDropDownMenu_SetText(item.widget, choice[2]) end
        end
    end
    local settings = Addon.Database:GetActivitySettings()
    local labels = {visible = "Visible", restricted = "Friends/Guild Only", hidden = "Hidden"}
    self.visibilityStatus:SetText("Discovery Visibility: " .. (labels[Addon.Database:GetPrivacyMode()] or "Unknown") .. " (change in Settings)")
    self.networkStatus:SetText(Addon.Activity:GetNetworkingStatus())
    self.experimental:SetText(settings.enabled and "Experimental Network: ON" or "Experimental Network: OFF")
    self.markers:SetText(settings.markers and "Minimap Markers: ON" or "Minimap Markers: OFF")
    self.directory:SetText(settings.directory and "Directory Participation: ON" or "Directory Participation: OFF")
    self.subzone:SetText(settings.subzone and "Share Subzone: ON" or "Share Subzone: OFF")
    for _, row in ipairs(self.rows) do row.frame:Hide() end
    local index = 0
    local function Row(peer, y, primary, action, deny)
        index = index + 1
        local row = self.rows[index]
        if not row then
            row = {frame = CreateFrame("Frame", nil, self.content)}
            row.frame:SetSize(480, 30)
            row.label = Text(row.frame, "", 0, 0, 260)
            row.primary = Button(row.frame, "", 270, 0, 90, function() row.action() end)
            row.deny = Button(row.frame, "Deny", 365, 0, 90, function() row.denyAction() end)
            self.rows[index] = row
        end
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", 12, y)
        row.label:SetText(Addon:EscapePlainText(peer))
        row.primary:SetText(primary)
        row.action = function() action(); self:Refresh() end
        row.denyAction = function() if deny then deny() end; self:Refresh() end
        row.deny:SetShown(deny ~= nil)
        row.frame:Show()
    end
    local pending = {}
    for _, request in pairs(Addon.ProfileAuthorization.pending) do pending[#pending + 1] = request end
    table.sort(pending, function(a, b) return a.peer < b.peer end)
    for i, request in ipairs(pending) do
        local peer = request.peer
        Row(peer, -465 - (i - 1) * 34, "Approve", function() Addon.ProfileAuthorization:Decide(peer, true) end,
            function() Addon.ProfileAuthorization:Decide(peer, false) end)
    end
    local connections = Addon.Connections:GetAll(false)
    for i, connection in ipairs(connections) do
        if i > 100 then break end
        local peer = connection.characterKey
        local approved = Addon.Database.character.profileApprovals[string.lower(peer)] == true
        Row(peer, -780 - (i - 1) * 34, approved and "Revoke" or "Approve",
            function() Addon.ProfileAuthorization:SetConnectionApproval(peer, not approved) end)
    end
    self.content:SetHeight(820 + math.min(100, #connections) * 34)
end
