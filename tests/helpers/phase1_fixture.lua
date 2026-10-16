-- Native Phase 1 modules with mocked client APIs. No experimental source loads.
local function Fixture(savedAccount, savedCharacter)
    local f = {now = 100, units = {}, sent = {}, timers = {}, tickers = {}, lines = {},
        registrations = {}, joined = 0, leaves = 0, combat = false, rangeCalls = 0,
        positionCalls = 0, secret = {}, alerts = 0, radius = 100, x = 100, y = 200}
    ForeverRP, ForeverRPDB, ForeverRPCharacterDB = {}, savedAccount, savedCharacter
    local a = ForeverRP
    GetTime = function() return f.now end
    time = function() return 1800000000 end
    GetNormalizedRealmName = function() return "Realm" end
    GetRealmName = GetNormalizedRealmName
    GetAddOnMetadata = function(_, key) return key == "Version" and "0.1.1-beta.20" or nil end
    C_AddOns = nil
    canaccessallvalues = function(...)
        for i = 1, select("#", ...) do if select(i, ...) == f.secret then return false end end
        return true
    end
    InCombatLockdown = function() return f.combat end
    UnitExists = function(unit) return unit == "player" or f.units[unit] ~= nil end
    UnitIsPlayer = UnitExists
    UnitIsVisible = function(unit) return f.units[unit] and f.units[unit].visible end
    UnitFullName = function(unit)
        if unit == "player" then return "Local", "Person" end
        local u = f.units[unit]; if u then return u.first, u.second end
    end
    UnitName = UnitFullName
    GetUnitName = function(unit)
        if unit == "player" then return "Local Person" end
        return f.units[unit] and f.units[unit].full
    end
    CheckInteractDistance = function(unit)
        assert(f.combat == false, "restricted range call")
        f.rangeCalls = f.rangeCalls + 1
        return f.units[unit] and f.units[unit].range
    end
    UnitPosition = function(unit)
        assert(f.combat == false, "position read in combat")
        f.positionCalls = f.positionCalls + 1
        if unit == "player" then return f.x, f.y, 5, 1 end
        local u = f.units[unit]; if u then return u.x, u.y, u.z or 5, u.space or 1 end
    end
    UnitIsAFK, UnitIsDND = function() return false end, function() return false end
    IsInGroup = function() return f.group == true end
    IsInGuild = function() return f.guild == true end
    IsInRaid = function() return false end
    GetNumGroupMembers = function() return f.group and 2 or 0 end
    GetNumSubgroupMembers = function() return f.group and 1 or 0 end
    GetNumGuildMembers = function() return f.friend and 1 or 0 end
    GetGuildRosterInfo = function() return "Peer Person-Realm" end
    C_FriendList = {GetFriendInfo = function() return nil end, GetNumFriends = function() return 0 end}
    GetNumFriends, GetFriendInfo = nil, nil
    GetChannelName = function() return f.joined end
    JoinChannelByName = function() error("Phase 1 attempted a channel join") end
    LeaveChannelByName = function(name)
        assert(name == "ForeverRPActivity"); f.leaves = f.leaves + 1; f.joined = 0
    end
    C_ChatInfo = {RegisterAddonMessagePrefix = function(prefix)
        f.registrations[prefix] = true; return 0
    end, IsAddonMessagePrefixRegistered = function(prefix) return f.registrations[prefix] == true end,
    SendAddonMessage = function(prefix, payload, channel, target)
        f.sent[#f.sent + 1] = {prefix = prefix, payload = payload, channel = channel, target = target}
        return 0
    end}
    C_Timer = {After = function(_, run) f.timers[#f.timers + 1] = run end,
        NewTicker = function(seconds, run)
            local t = {seconds = seconds, run = run}; f.tickers[#f.tickers + 1] = t; return t
        end}
    local Widget = {}; Widget.__index = Widget
    for _, name in ipairs({"SetJustifyH", "SetAllPoints", "SetScrollChild", "SetHeight", "SetAutoFocus",
        "SetMaxLetters", "ClearFocus", "SetTexture", "SetVertexColor", "EnableMouse"}) do
        Widget[name] = function() end
    end
    function Widget:SetWidth(width) self.width = width end
    function Widget:SetSize(w, h) self.width, self.height = w, h end
    function Widget:GetWidth() return self.width end
    function Widget:GetHeight() return self.height end
    function Widget:SetPoint(_, parent, anchor, x, y)
        self.x, self.y = x or parent, y or anchor; self.anchors = (self.anchors or 0) + 1
    end
    function Widget:ClearAllPoints() self.x, self.y = nil, nil end
    function Widget:SetText(text) self.text = text end
    function Widget:GetText() return self.text or "" end
    function Widget:SetScript(event, run) self[event] = run end
    function Widget:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
    function Widget:UnregisterEvent(event) self.events[event] = nil end
    function Widget:Show() self.shown = true end
    function Widget:Hide() self.shown = false end
    function Widget:IsShown() return self.shown ~= false end
    function Widget:SetShown(value) self.shown = value end
    function Widget:SetEnabled(value) self.enabled = value end
    function Widget:Disable() self.enabled = false end
    local function New() return setmetatable({}, Widget) end
    Widget.CreateFontString, Widget.CreateTexture = New, New
    CreateFrame = New
    UIDropDownMenu_SetWidth = function(widget, width) widget.width = width end
    UIDropDownMenu_Initialize = function(widget, run) widget.initialize = run end
    UIDropDownMenu_CreateInfo = function() return {} end
    UIDropDownMenu_SetText = function(widget, text) widget.text = text end
    UIDropDownMenu_SetSelectedValue = function() end
    UIDropDownMenu_AddButton = function() end
    UIDropDownMenu_DisableDropDown = function(widget) widget.enabled = false end
    Minimap = New(); Minimap:SetSize(200, 200)
    C_Minimap = {GetViewRadius = function() return f.radius end}
    GetCVar = function() return f.rotate and "1" or "0" end
    GetPlayerFacing = function() return f.facing end
    SlashCmdList = {}
    for _, path in ipairs({"Localization/enUS", "Core/Constants", "Core", "Core/ValueAccess",
        "Core/DiscoveryDiagnostics", "Core/Database", "Profile/Profile", "Profile/RemoteProfiles",
        "Modules/Connections", "Discovery/Presence", "Discovery/Privacy", "Discovery/Communication",
        "Discovery/ProfileTransfer", "Discovery/ProfileAuthorization", "Discovery/Activity", "Discovery/Range",
        "Discovery/NearbyPlayers", "Discovery/PlayerDetection", "Discovery/ObservedDiscovery",
        "UI/Notifications", "UI/PlayerTooltip", "UI/PlayerMarkers", "UI/DiscoveryOptions", "UI/Activity",
        "Core/Commands", "Core/Events"}) do dofile("ForeverRP/" .. path .. ".lua") end
    a.Print = function(_, line) f.lines[#f.lines + 1] = line end
    a.MSPCompatibility = {Initialize = function() end, ObserveUnit = function() end}
    a.EmoteBar = {Initialize = function() end}
    a.UI = {Initialize = function() end, Show = function(_, panel) f.panel = panel end}
    a.MinimapButton = {UpdateNearbyCount = function() end, Pulse = function() f.alerts = f.alerts + 1 end}
    a:OnAddonLoaded("ForeverRP")
    a.Database:GetNotificationSettings().sound = false
    function f:Login() a:OnPlayerLogin() end
    function f:Unit(token, full)
        self.units[token or "target"] = {first = "Peer", second = "Person", full = full or "Peer Person",
            range = true, visible = true, x = 110, y = 200}
        return self.units[token or "target"]
    end
    function f:Receive(payload, sender, channel, prefix)
        a.Events.handlers.CHAT_MSG_ADDON(prefix or "FOREVERRP", payload or "ACK|1|0.1.1-beta.5",
            channel or "WHISPER", sender or "Peer Person-Realm")
    end
    function f:Tick(seconds)
        self.now = self.now + (seconds or 1)
        for _, t in ipairs(self.tickers) do if t.seconds == 1 then t.run() end end
    end
    function f:Drain()
        for _ = 1, 1000 do
            local run = table.remove(self.timers, 1); if not run then return end; run()
        end
        error("unbounded response timers")
    end
    function f:Discover()
        self:Unit("target"); a.Events.handlers.PLAYER_TARGET_CHANGED(); self:Receive()
        self:Tick()
    end
    f.a = a
    return f
end
return Fixture
