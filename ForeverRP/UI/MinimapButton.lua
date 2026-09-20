local Addon = ForeverRP

Addon.MinimapButton = {
    initialized = false,
}

local function PositionButton(button, angle)
    local radians = math.rad(angle)
    local radius = (math.min(Minimap:GetWidth(), Minimap:GetHeight()) / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

function Addon.MinimapButton:UpdatePosition()
    if self.button then
        PositionButton(self.button, Addon.Database:GetMinimapAngle())
    end
end

function Addon.MinimapButton:SetVisible(visible)
    if self.button then
        self.button:SetShown(visible == true)
    end
end

function Addon.MinimapButton:UpdateNearbyCount(count)
    if not self.countBadge then
        return
    end
    count = math.max(0, math.floor(tonumber(count) or 0))
    if count == 0 then
        self.countBadge:Hide()
        return
    end
    self.countText:SetText(count > 99 and "99+" or tostring(count))
    self.countBadge:Show()
end

function Addon.MinimapButton:Pulse()
    if not self.pulseAnimation then
        return
    end
    if self.pulseAnimation:IsPlaying() then
        self.pulseAnimation:Stop()
    end
    self.pulseTexture:Show()
    self.pulseAnimation:Play()
end

function Addon.MinimapButton:UpdateFromCursor()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local centerX, centerY = Minimap:GetCenter()
    local angle = math.deg(math.atan2((cursorY / scale) - centerY, (cursorX / scale) - centerX))
    Addon.Database:SetMinimapAngle(angle)
    self:UpdatePosition()
end

function Addon.MinimapButton:Initialize()
    if self.initialized then
        return
    end

    local button = CreateFrame("Button", "ForeverRPMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_05")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(32, 32)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    local pulse = button:CreateTexture(nil, "OVERLAY", nil, 1)
    pulse:SetSize(48, 48)
    pulse:SetPoint("CENTER", button, "CENTER")
    pulse:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    pulse:SetBlendMode("ADD")
    pulse:SetAlpha(0)
    pulse:Hide()

    local pulseAnimation = pulse:CreateAnimationGroup()
    local fadeIn = pulseAnimation:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.2)
    fadeIn:SetOrder(1)
    local fadeOut = pulseAnimation:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.8)
    fadeOut:SetOrder(2)
    pulseAnimation:SetScript("OnFinished", function()
        pulse:Hide()
    end)

    local countBadge = CreateFrame("Frame", nil, button)
    countBadge:SetSize(18, 16)
    countBadge:SetPoint("TOPRIGHT", button, "TOPRIGHT", 6, 6)
    countBadge:SetFrameLevel(button:GetFrameLevel() + 12)
    countBadge:Hide()

    local badgeBackground = countBadge:CreateTexture(nil, "BACKGROUND")
    badgeBackground:SetAllPoints()
    badgeBackground:SetColorTexture(0.55, 0.05, 0.05, 0.95)

    local countText = countBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("CENTER", countBadge, "CENTER", 0, 0)
    countText:SetTextColor(1, 1, 1)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            Addon.UI:Show("settings")
        else
            Addon.UI:Toggle("home")
        end
    end)
    button:SetScript("OnDragStart", function()
        button:SetScript("OnUpdate", function()
            self:UpdateFromCursor()
        end)
    end)
    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:AddLine(Addon:GetText("MINIMAP_TOOLTIP_TITLE"))
        GameTooltip:AddLine(Addon:GetText("MINIMAP_TOOLTIP_LEFT"), 1, 1, 1)
        GameTooltip:AddLine(Addon:GetText("MINIMAP_TOOLTIP_RIGHT"), 1, 1, 1)
        GameTooltip:AddLine(Addon:GetText("MINIMAP_TOOLTIP_DRAG"), 1, 1, 1)
        GameTooltip:AddLine(string.format(Addon:GetText("MINIMAP_TOOLTIP_VERSION"), Addon.Constants.ADDON_VERSION), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.button = button
    self.pulseTexture = pulse
    self.pulseAnimation = pulseAnimation
    self.countBadge = countBadge
    self.countText = countText
    self:UpdatePosition()
    self:SetVisible(Addon.Database:IsMinimapVisible())
    self.initialized = true
end
