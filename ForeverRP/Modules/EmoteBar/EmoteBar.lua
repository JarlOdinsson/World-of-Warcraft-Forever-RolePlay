local Addon = ForeverRP

local PRESETS = {
    { "Wave", "emote", "WAVE" }, { "Bow", "emote", "BOW" },
    { "Salute", "emote", "SALUTE" }, { "Greet", "emote", "GREET" },
    { "Nod", "emote", "NOD" }, { "Shrug", "emote", "SHRUG" },
    { "Point", "emote", "POINT" }, { "Hug", "emote", "HUG" },
    { "Kiss", "emote", "KISS" }, { "Thank", "emote", "THANK" },
    { "Welcome", "emote", "WELCOME" }, { "Applaud", "emote", "APPLAUD" },
    { "Laugh", "emote", "LAUGH" }, { "Cry", "emote", "CRY" },
    { "Cheer", "emote", "CHEER" }, { "Clap", "emote", "CLAP" },
    { "Sigh", "emote", "SIGH" }, { "Gasp", "emote", "GASP" },
    { "Groan", "emote", "GROAN" }, { "Chuckle", "emote", "CHUCKLE" },
    { "Giggle", "emote", "GIGGLE" }, { "Frown", "emote", "FROWN" },
    { "Smile", "emote", "SMILE" }, { "Blush", "emote", "BLUSH" },
    { "Kneel", "emote", "KNEEL" }, { "Sit", "emote", "SIT" },
    { "Sleep", "emote", "SLEEP" }, { "Dance", "emote", "DANCE" },
    { "Flex", "emote", "FLEX" }, { "Roar", "emote", "ROAR" },
    { "Cower", "emote", "COWER" }, { "Beg", "emote", "BEG" },
    { "Scratch", "emote", "SCRATCH" }, { "Stretch", "emote", "STRETCH" },
    { "Yawn", "emote", "YAWN" }, { "Tap Foot", "emote", "TAP" },
    { "Agree", "emote", "AGREE" }, { "Disagree", "emote", "DISAGREE" },
    { "Yes", "emote", "YES" }, { "No", "emote", "NO" },
    { "Question", "emote", "QUESTION" }, { "Talk", "emote", "TALK" },
    { "Shush", "emote", "SHUSH" }, { "Taunt", "emote", "TAUNT" },
    { "Threaten", "emote", "THREATEN" }, { "Mock", "emote", "MOCK" },
    { "Congratulate", "emote", "CONGRATULATE" }, { "Sorry", "emote", "SORRY" },
    { "Inspect", "custom", "looks them over carefully." },
    { "Think", "custom", "pauses for a moment in thought." },
    { "Drink", "custom", "takes a drink." },
    { "Eat", "custom", "takes a bite of their food." },
    { "Listen", "custom", "falls quiet and listens." },
    { "Glance", "custom", "casts a glance in their direction." },
    { "Smirk", "custom", "gives a faint smirk." },
    { "Grin", "custom", "grins." },
    { "Raise Brow", "custom", "raises an eyebrow." },
    { "Roll Eyes", "custom", "rolls their eyes." },
    { "Cross Arms", "custom", "folds their arms across their chest." },
    { "Look Around", "custom", "glances around the area." },
}

local DEFAULT_TITLES = { "Wave", "Bow", "Nod", "Laugh", "Point", "Shrug" }

Addon.EmoteBar = {
    buttons = {},
    presets = PRESETS,
}

local function Clean(value, limit, singleLine)
    value = type(value) == "string" and value or ""
    if singleLine then
        value = value:gsub("[%c]", " ")
    else
        value = value:gsub("[%z\1-\8\11\12\14-\31\127]", "")
    end
    return value:sub(1, limit)
end

function Addon.EmoteBar:GetSettings()
    return Addon.Database:GetEmoteBarSettings()
end

function Addon.EmoteBar:FindPreset(title)
    for _, preset in ipairs(PRESETS) do
        if preset[1] == title then
            return preset
        end
    end
end

function Addon.EmoteBar:InitializeActions()
    local actions = self:GetSettings().actions
    for index = 1, Addon.Constants.EMOTE_BAR_MAX_SLOTS do
        local action = actions[index]
        if type(action) ~= "table" then
            local title = DEFAULT_TITLES[index]
            local preset = title and self:FindPreset(title)
            action = {
                id = "slot-" .. index,
                title = preset and preset[1] or (Addon:GetText("EMOTE_EMPTY_SLOT") .. " " .. index),
                type = preset and preset[2] or "custom",
                command = preset and preset[3] or "",
            }
            actions[index] = action
        end
        action.id = "slot-" .. index
        action.title = Clean(action.title, 32, true)
        if action.type ~= "emote" and action.type ~= "custom" then
            action.type = "custom"
        end
        action.command = Clean(action.command, 255, action.type == "emote")
    end
end

function Addon.EmoteBar:Initialize()
    self:InitializeActions()
    self:CreateFrame()
    self:Refresh()
end

function Addon.EmoteBar:CreateFrame()
    if self.frame then
        return
    end
    local frame = CreateFrame("Frame", "ForeverRPEmoteBar", UIParent)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.04, 0.04, 0.04, 0.9)
    frame:SetScript("OnDragStart", function(owner)
        if not self:GetSettings().locked then
            owner:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(owner)
        owner:StopMovingOrSizing()
        local point, _, _, x, y = owner:GetPoint(1)
        local settings = self:GetSettings()
        settings.point, settings.x, settings.y = point or "CENTER", x or 0, y or 0
    end)

    local handle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    handle:SetPoint("TOP", 0, -5)
    handle:SetText(Addon:GetText("EMOTE_BAR_TITLE"))
    frame.handle = handle

    for index = 1, Addon.Constants.EMOTE_BAR_MAX_SLOTS do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(80, 26)
        button:SetScript("OnClick", function()
            self:Execute(index)
        end)
        self.buttons[index] = button
    end
    self.frame = frame
end

function Addon.EmoteBar:Execute(index)
    local action = self:GetSettings().actions[index]
    if not action or action.command == "" then
        return
    end
    if action.type == "emote" then
        if DoEmote then
            pcall(DoEmote, action.command)
        end
    elseif action.type == "custom" and SendChatMessage then
        local text = Clean(action.command, 255, false)
        text = text:gsub("^%s*/[Ee][Mm][Oo][Tt][Ee]%s+", "")
        text = text:gsub("^%s*/[Ee]%s+", "")
        if text ~= "" then
            pcall(SendChatMessage, text, "EMOTE")
        end
    end
end

function Addon.EmoteBar:Refresh()
    if not self.frame then
        return
    end
    local settings = self:GetSettings()
    self.frame:ClearAllPoints()
    self.frame:SetPoint(settings.point, UIParent, settings.point, settings.x, settings.y)
    self.frame:SetScale(settings.scale)
    self.frame.handle:SetShown(not settings.locked)

    local count = settings.slots
    local columns = math.min(4, count)
    local rows = math.ceil(count / 4)
    self.frame:SetSize((columns * 84) + 8, (rows * 30) + 24)
    for index, button in ipairs(self.buttons) do
        button:SetShown(index <= count)
        if index <= count then
            local column = (index - 1) % 4
            local row = math.floor((index - 1) / 4)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", 6 + (column * 84), -20 - (row * 30))
            button:SetText(settings.actions[index].title)
        end
    end
    self.frame:SetShown(settings.enabled == true)
end

function Addon.EmoteBar:SetEnabled(enabled)
    self:GetSettings().enabled = enabled == true
    self:Refresh()
end

function Addon.EmoteBar:SetLocked(locked)
    self:GetSettings().locked = locked == true
    self:Refresh()
end

function Addon.EmoteBar:SetSlots(count)
    count = math.floor(tonumber(count) or Addon.Constants.EMOTE_BAR_DEFAULT_SLOTS)
    self:GetSettings().slots = math.max(1, math.min(12, count))
    self:Refresh()
end

function Addon.EmoteBar:SetScale(scale)
    for _, allowed in ipairs(Addon.Constants.EMOTE_BAR_SCALES) do
        if scale == allowed then
            self:GetSettings().scale = allowed
            self:Refresh()
            return true
        end
    end
    return false
end

function Addon.EmoteBar:SetAction(index, title, actionType, command)
    index = tonumber(index)
    if not index or index < 1 or index > 12
        or (actionType ~= "emote" and actionType ~= "custom") then
        return false
    end
    local action = self:GetSettings().actions[index]
    action.title = Clean(title, 32, true)
    action.command = Clean(command, 255, actionType == "emote")
    action.type = actionType
    if action.title == "" then
        action.title = Addon:GetText("EMOTE_EMPTY_SLOT") .. " " .. index
    end
    self:Refresh()
    return true
end

function Addon.EmoteBar:ResetPosition()
    local settings = self:GetSettings()
    settings.point, settings.x, settings.y = "CENTER", 0, -220
    self:Refresh()
end
