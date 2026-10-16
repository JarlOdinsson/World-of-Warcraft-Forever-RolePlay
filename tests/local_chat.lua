local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function Fixture()
    local f = {windows = {}, opened = 0, main = {}, combat = false, debug = false, selected = nil, secret = {}}
    ForeverRP = {Constants = {ADDON_DISPLAY_NAME = "ForeverRP"}, State = {initialized = true},
        Localization = {enUS = {ADDON_LOADED = "ForeverRP loaded."}},
        Database = {IsDebugEnabled = function() return f.debug end}}
    NUM_CHAT_WINDOWS = 5
    for i = 1, 10 do _G["ChatFrame" .. i] = nil end
    GetChatWindowInfo = function(id)
        local w = f.windows[id]
        if w then return w.name, 12, 1, 1, 1, 1, w.shown, false, w.docked end
    end
    function f:Window(id, name, shown, docked)
        local w = {name = name, shown = shown, docked = docked, lines = {}, editBox = {}, groupsCleared = 0, channelsCleared = 0}
        function w:AddMessage(text) self.lines[#self.lines + 1] = text end
        function w:RemoveAllMessageGroups() self.groupsCleared = self.groupsCleared + 1 end
        function w:RemoveAllChannels() self.channelsCleared = self.channelsCleared + 1 end
        self.windows[id], _G["ChatFrame" .. id] = w, w
        return w
    end
    DEFAULT_CHAT_FRAME = f:Window(1, "General", true, 1)
    f.main, f.selected = DEFAULT_CHAT_FRAME.lines, DEFAULT_CHAT_FRAME
    f:Window(2, "Combat Log", true, 2)
    InCombatLockdown = function() return f.combat end
    canaccessallvalues = function(...)
        for i = 1, select("#", ...) do if select(i, ...) == f.secret then return false end end
        return true
    end
    GENERAL_CHAT_DOCK = {}
    FCFDock_GetSelectedWindow = function() return f.selected end
    FCF_SelectDockFrame = function(frame) f.selected = frame end
    ChatFrameUtil = {SetLastActiveWindow = function(box) f.lastEditBox = box end}
    FCF_OpenNewWindow = function(name, noDefault)
        Check(noDefault, true); Check(f.combat, false)
        f.opened = f.opened + 1
        for i = 3, NUM_CHAT_WINDOWS do
            if not f.windows[i] or not f.windows[i].shown and not f.windows[i].docked then
                local w = f:Window(i, name, true, i); f.selected = w; return w
            end
        end
    end
    local function Forbidden() error("local reports attempted network traffic") end
    JoinChannelByName, SendChatMessage, SendAddonMessage = Forbidden, Forbidden, Forbidden
    C_ChatInfo = {SendAddonMessage = Forbidden, SendChatMessage = Forbidden}
    ChatFrame_RemoveAllMessageGroups, ChatFrame_RemoveAllChannels = nil, nil
    dofile("ForeverRP/Core/ValueAccess.lua")
    dofile("ForeverRP/Core.lua")
    dofile("ForeverRP/UI/ChatOutput.lua")
    f.a = ForeverRP
    return f
end
local function Test(name, run)
    run(Fixture()); cases = cases + 1; print("PASS " .. name)
end

Test("startup is queued and one empty local tab receives notices, commands and debug", function(f)
    local a = f.a
    a:Print("before login", 7); a:Debug("disabled")
    Check(f.opened, 0); Check(#f.main, 0); Check(#a.ChatOutput.pending, 1)
    for _, name in ipairs({"Profile", "ProfileTransfer", "ProfileAuthorization", "Activity", "MSPCompatibility",
        "EmoteBar", "PlayerTooltip", "UI", "Notifications", "NearbyPlayers", "PlayerDetection"}) do
        a[name] = {Initialize = function() end}
    end
    a.Communication = {SendInitialHello = function() end, StartPresenceLifecycle = function() end}
    a:OnPlayerLogin()
    local w = f.windows[3]
    Check(f.opened, 1); Check(w.name, "ForeverRP")
    Check(w.lines[1], "ForeverRP: before login 7")
    Check(w.lines[2], "ForeverRP: ForeverRP loaded.")
    Check(w.groupsCleared, 1); Check(w.channelsCleared, 1)
    Check(f.selected, DEFAULT_CHAT_FRAME); Check(f.lastEditBox, DEFAULT_CHAT_FRAME.editBox)
    a:Print("Version:", "test"); f.debug = true; a:Debug("enabled", 9)
    Check(w.lines[3], "ForeverRP: Version: test")
    Check(w.lines[4], "ForeverRP DEBUG: enabled 9")
    Check(#f.main, 0); Check(f.opened, 1)
end)

Test("reload reuses an existing inactive docked tab without clearing user filters or history", function(f)
    local w = f:Window(4, "ForeverRP", false, 2)
    w.lines[1] = "existing history"
    f.a.ChatOutput:Initialize(); f.a:Print("first session")
    dofile("ForeverRP/UI/ChatOutput.lua")
    f.a.ChatOutput:Initialize(); f.a:Print("after reload")
    Check(f.opened, 0); Check(#w.lines, 3); Check(w.lines[1], "existing history")
    Check(w.groupsCleared, 0); Check(w.channelsCleared, 0); Check(#f.main, 0)
    Check(f.selected, DEFAULT_CHAT_FRAME)
end)

Test("a stale closed or temporary tab is not treated as an output destination", function(f)
    local closed = f:Window(4, "ForeverRP", false, false)
    local temporary = f:Window(5, "ForeverRP", true, 3); temporary.isTemporary = true
    f.a.ChatOutput:Initialize(); f.a:Print("current")
    Check(f.opened, 1); Check(#closed.lines, 0); Check(#temporary.lines, 0)
    Check(f.windows[3].lines[1], "ForeverRP: current")
end)

Test("a renamed window is not written to or reconfigured", function(f)
    f.a.ChatOutput:Initialize(); local w = f.windows[3]; w.name = "My Guild"
    f.a:Print("fallback after rename")
    Check(#w.lines, 0); Check(w.groupsCleared, 1); Check(f.opened, 1)
    Check(f.main[#f.main], "ForeverRP: fallback after rename")
end)

Test("full window slots keep reports local with one warning and no creation loop", function(f)
    for i = 3, 5 do f:Window(i, "Other " .. i, true, i) end
    f.a.ChatOutput:Initialize()
    for i = 1, 5 do f.a:Print("test", i) end
    Check(f.opened, 1); Check(#f.main, 6)
    Check(f.main[1]:find("Local chat tab unavailable", 1, true) ~= nil, true)
    Check(f.main[6], "ForeverRP: test 5")
    for i = 3, 5 do Check(#f.windows[i].lines, 0); Check(f.windows[i].groupsCleared, 0) end
end)

Test("creation is deferred in combat and recovered through the actual event handler", function(f)
    f.combat = true; f.a.ChatOutput:Initialize(); f.a:Print("combat fallback")
    Check(f.opened, 0); Check(f.a.ChatOutput.deferred, true)
    CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
    dofile("ForeverRP/Core/Events.lua")
    f.combat = false; f.a.Events.handlers.PLAYER_REGEN_ENABLED()
    Check(f.opened, 1); f.a:Print("recovered")
    Check(f.windows[3].lines[1], "ForeverRP: recovered")
    f.a.Events.handlers.PLAYER_REGEN_ENABLED(); Check(f.opened, 1)
    f.combat = true; f.a:Print("existing tab in combat")
    Check(f.windows[3].lines[2], "ForeverRP: existing tab in combat")
end)

Test("restricted combat evidence and unavailable APIs use local fallback", function(f)
    f.combat = f.secret; f.a.ChatOutput:Initialize(); f.a:Print("restricted")
    Check(f.opened, 0); Check(f.main[#f.main], "ForeverRP: restricted")
    f.combat = false; FCF_OpenNewWindow = nil; f.a:Print("missing API")
    Check(f.main[#f.main], "ForeverRP: missing API"); Check(#f.main, 3)
end)

Test("legacy chat globals configure only the new output window", function(f)
    local create = FCF_OpenNewWindow
    FCF_OpenNewWindow = function(...)
        local w = create(...); w.RemoveAllMessageGroups, w.RemoveAllChannels = nil, nil; return w
    end
    ChatFrame_RemoveAllMessageGroups = function(w) w.groupsCleared = w.groupsCleared + 1 end
    ChatFrame_RemoveAllChannels = function(w) w.channelsCleared = w.channelsCleared + 1 end
    f.a.ChatOutput:Initialize(); f.a:Print("legacy")
    Check(f.windows[3].groupsCleared, 1); Check(f.windows[3].channelsCleared, 1)
    Check(DEFAULT_CHAT_FRAME.groupsCleared, 0); Check(DEFAULT_CHAT_FRAME.channelsCleared, 0)
end)

Test("startup buffer is bounded and creation errors do not discard command output", function(f)
    for i = 1, 105 do f.a:Print(i) end
    Check(#f.a.ChatOutput.pending, 100)
    FCF_OpenNewWindow = function() error("client creation unavailable") end
    f.a.ChatOutput:Initialize()
    Check(#f.a.ChatOutput.pending, 0); Check(#f.main, 101)
    Check(f.main[2], "ForeverRP: 6"); Check(f.main[101], "ForeverRP: 105")
end)

print("PASS: " .. cases .. " local chat cases; " .. checks .. " checks (mock chat APIs; live layout pending)")
