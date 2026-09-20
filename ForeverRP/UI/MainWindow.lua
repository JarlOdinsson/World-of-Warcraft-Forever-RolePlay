local Addon = ForeverRP
local UI = Addon.UI

UI.panels = UI.panels or {}
UI.initialized = false

local function CreateNavigationButton(parent, text, anchor, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(104, 28)
    button:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

function UI:CreateHomePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 24, -30)
    title:SetText(Addon:GetText("HOME_TITLE"))

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    description:SetJustifyH("LEFT")
    description:SetText(Addon:GetText("HOME_DESCRIPTION"))

    local status = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    status:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -24)
    status:SetText(Addon:GetText("HOME_STATUS"))

    local access = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    access:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -20)
    access:SetText(Addon:GetText("HOME_ACCESS"))

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    version:SetPoint("BOTTOMRIGHT", -18, 16)
    version:SetText(string.format(Addon:GetText("HOME_VERSION"), Addon.Constants.ADDON_VERSION))

    return panel
end

function UI:CreateMainWindow()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "ForeverRPMainWindow", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(700, 500)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    local titleRegion = frame.TitleText or frame.title
    if titleRegion then
        titleRegion:SetText(Addon:GetText("WINDOW_TITLE"))
    end

    local dragArea = CreateFrame("Button", nil, frame)
    dragArea:SetPoint("TOPLEFT", 8, -4)
    dragArea:SetPoint("TOPRIGHT", -32, -4)
    dragArea:SetHeight(22)
    dragArea:RegisterForDrag("LeftButton")
    dragArea:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    dragArea:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    local applicationRoot = CreateFrame("Frame", nil, frame)
    applicationRoot:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -30)
    applicationRoot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)

    local navigation = CreateFrame("Frame", nil, applicationRoot)
    navigation:SetPoint("TOPLEFT", 6, -6)
    navigation:SetPoint("BOTTOMLEFT", 6, 6)
    navigation:SetWidth(120)

    local navTitle = navigation:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    navTitle:SetPoint("TOP", 0, -12)
    navTitle:SetText(Addon:GetText("WINDOW_TITLE"))

    local content = CreateFrame("Frame", nil, applicationRoot)
    content:SetPoint("TOPLEFT", navigation, "TOPRIGHT", 8, 0)
    content:SetPoint("BOTTOMRIGHT", -6, 6)

    self.panels.home = self:CreateHomePanel(content)
    self.panels.nearby = Addon.NearbyUI:Create(content)
    self.panels.profile = Addon.ProfileEditor:Create(content)
    self.panels.viewer = Addon.ProfileViewer:Create(content)
    self.panels.settings = self:CreateSettingsPanel(content)

    self.homeButton = CreateNavigationButton(navigation, Addon:GetText("NAV_HOME"), navTitle, function()
        self:ShowPanel("home")
    end)
    self.nearbyButton = CreateNavigationButton(navigation, Addon:GetText("NAV_NEARBY"), self.homeButton, function()
        self:ShowPanel("nearby")
    end)
    self.profileButton = CreateNavigationButton(navigation, Addon:GetText("NAV_PROFILE"), self.nearbyButton, function()
        self:ShowPanel("profile")
    end)
    self.viewerButton = CreateNavigationButton(navigation, Addon:GetText("NAV_VIEWER"), self.profileButton, function()
        Addon.ProfileViewer:ShowLocal()
        self:ShowPanel("viewer")
    end)
    self.settingsButton = CreateNavigationButton(navigation, Addon:GetText("NAV_SETTINGS"), self.viewerButton, function()
        self:ShowPanel("settings")
    end)

    frame:SetScript("OnHide", function()
        Addon.ProfileEditor:Commit()
    end)

    self.frame = frame
    self.applicationRoot = applicationRoot
    self.navigation = navigation
    self.content = content
    self:ResetPosition()
    self:ShowPanel("home")
    return frame
end

function UI:ResetPosition()
    if not self.frame then
        return
    end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER")
end

function UI:ShowPanel(panelName)
    local selected = self.panels[panelName] and panelName or "home"
    if self.currentPanel == "profile" and selected ~= "profile" then
        Addon.ProfileEditor:Commit()
    end
    for name, panel in pairs(self.panels) do
        panel:SetShown(name == selected)
    end
    self.currentPanel = selected
    if selected == "settings" then
        self:RefreshSettings()
    elseif selected == "profile" then
        Addon.ProfileEditor:Refresh()
    elseif selected == "nearby" then
        Addon.NearbyUI:Refresh()
    elseif selected == "viewer" then
        Addon.ProfileViewer:Refresh()
    end
end

function UI:Show(panelName)
    self:CreateMainWindow()
    self:ShowPanel(panelName or self.currentPanel or "home")
    self.frame:Show()
end

function UI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function UI:Toggle(panelName)
    self:CreateMainWindow()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show(panelName or "home")
    end
end

function UI:Initialize()
    if self.initialized then
        return
    end
    self:CreateMainWindow()
    Addon.MinimapButton:Initialize()
    self.initialized = true
end
