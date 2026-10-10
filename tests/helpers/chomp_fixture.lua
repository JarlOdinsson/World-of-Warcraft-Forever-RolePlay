-- Executes the bundled library files, including real event handlers and LibStub.
local function Fixture(interface, format, priorVersion)
    local f = {now = 100, frames = {}, timers = {}, sent = {}, filters = {}, loggedIn = false, accounts = {},
        unitName = "Local", unitSecond = "Person", combined = "Local Person", realm = "ClassicBetaPvE"}
    LibStub, AddOn_Chomp, __chomp_internal, msp, ChatThrottleLib = nil, nil, nil, nil, nil
    strmatch, tinsert, tremove, unpack = string.match, table.insert, table.remove, unpack
    string.split = function(separator, value)
        local start, finish = value:find(separator, 1, true)
        if start then return value:sub(1, start - 1), value:sub(finish + 1) end
        return value
    end
    local ok, bits = pcall(require, "bit")
    if ok then bit = bits else
        local function Fold(a, b, mode)
            local result, power = 0, 1; a, b = a % 2^32, b % 2^32
            for _ = 1, 32 do
                local x, y = a % 2, b % 2
                if mode == "or" and (x == 1 or y == 1) or mode == "and" and x == 1 and y == 1 or mode == "xor" and x ~= y then result = result + power end
                a, b, power = math.floor(a / 2), math.floor(b / 2), power * 2
            end
            return result
        end
        bit = {band = function(a, b) return Fold(a, b, "and") end,
            bxor = function(a, b) return Fold(a, b, "xor") end,
            bor = function(...) local v = 0; for i = 1, select("#", ...) do v = Fold(v, select(i, ...), "or") end; return v end,
            rshift = function(a, n) return math.floor((a % 2^32) / 2^n) end,
            lshift = function(a, n) return (a * 2^n) % 2^32 end,
            arshift = function(a, n) if a >= 2^31 then a = a - 2^32 end; return math.floor(a / 2^n) end}
    end
    tInvert = function(list) local t = {}; for _, v in ipairs(list) do t[v] = true end; return t end
    Mixin = function(target, ...) for i = 1, select("#", ...) do for k, v in pairs(select(i, ...)) do target[k] = v end end; return target end
    DoublyLinkedListMixin = {
        PushBack = function(self, value) self.items = self.items or {}; table.insert(self.items, value); self.front = self.items[1] end,
        PopFront = function(self) local value = table.remove(self.items, 1); self.front = self.items[1]; return value end,
    }
    GetBuildInfo = function() return "1.60.1", "70170", "date", interface or 16001 end
    FULL_PLAYER_NAME = format or "%s %s"
    GetTime = function() return f.now end
    IsLoggedIn = function() return f.loggedIn end
    GetRealmName = function() return f.realm end
    GetAutoCompleteRealms = function() return {} end
    UnitFullName = function() return f.unitName, f.unitSecond end
    UnitName = UnitFullName
    GetUnitName = function() return f.combined end
    canaccessallvalues = function() return true end
    UnitFactionGroup = function() return "Horde" end
    UnitGUID = function() return "Player-1" end
    UnitRace, UnitClass = function() return "Orc", "ORC" end, function() return "Warrior", "WARRIOR" end
    UnitSex = function() return 2 end
    IsTrialAccount, IsVeteranTrialAccount, IsInRaid = function() return false end, function() return false end, function() return false end
    InCombatLockdown = function() return false end
    UnitRealmRelationship = function() return nil end
    Ambiguate = function(target) return f.ambiguate and f.ambiguate(target) or target end
    BNET_CLIENT_WOW, UNKNOWNOBJECT = "WoW", "Unknown"
    ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
    LE_REALM_RELATION_COALESCED = 2
    BNFeaturesEnabledAndConnected = function() return true end
    BNGetNumFriends = function() return #f.accounts end
    C_BattleNet = {GetFriendNumGameAccounts = function() return 1 end,
        GetFriendGameAccountInfo = function(i) return f.accounts[i] end}
    strcmputf8i = function(a, b) a, b = a:lower(), b:lower(); return a == b and 0 or a < b and -1 or 1 end
    CreateFrame = function()
        local frame = {scripts = {}, events = {}}
        function frame:Hide() end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:SetScript(event, fn) self.scripts[event] = fn end
        f.frames[#f.frames + 1] = frame; return frame
    end
    C_Timer = {After = function(_, callback) f.timers[#f.timers + 1] = callback end}
    C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end,
        IsAddonMessagePrefixRegistered = function() return true end,
        SendAddonMessage = function(prefix, payload, channel, target)
            f.sent[#f.sent + 1] = {prefix = prefix, payload = payload, channel = channel, target = target}; return 0
        end,
        SendAddonMessageLogged = function(prefix, payload, channel, target)
            f.sent[#f.sent + 1] = {prefix = prefix, payload = payload, channel = channel, target = target}; return 0
        end}
    GetNetStats = function() return 0, 0, 0 end
    C_Club = {SendMessage = function() end, EditMessage = function() end}
    SendChatMessage, BNSendWhisper = function() end, function() end
    BNSendGameData = function(target, prefix, payload) f.sent[#f.sent + 1] = {prefix = prefix, target = target, payload = payload, channel = "BATTLENET"} end
    hooksecurefunc = function(object, method, callback)
        if type(object) == "string" then callback, method, object = method, object, _G end
        local original = object[method]
        object[method] = function(...) local result = original(...); callback(...); return result end
    end
    ChatFrame_AddMessageEventFilter = function(event, callback) f.filters[event] = callback end
    CreateFromMixins = function() return {SetGUID = function() end} end
    PlayerLocationMixin = {}
    CallErrorHandler = function(err) error(err) end
    dofile("ForeverRP/Libs/MSP/LibStub/LibStub.lua")
    dofile("ForeverRP/Libs/MSP/CallbackHandler-1.0/CallbackHandler-1.0.lua")
    if priorVersion then
        local prior = LibStub:NewLibrary("Chomp", priorVersion)
        prior.Internal = CreateFrame(); prior.Internal.VERSION = priorVersion; prior.sentinel = true
    end
    dofile("ForeverRP/Libs/MSP/Chomp/Internal.lua")
    dofile("ForeverRP/Libs/MSP/Chomp/Public.lua")
    dofile("ForeverRP/Libs/MSP/Chomp/StringManip.lua")
    dofile("ForeverRP/Libs/MSP/Chomp/CTLCompat.lua")
    f.chomp = LibStub:GetLibrary("Chomp")
    f.internal = f.chomp.Internal
    f.internal.LOADING = nil -- same final script as Chomp.xml
    function f:Event(event, ...)
        self.internal.scripts.OnEvent(self.internal, event, ...)
    end
    function f:Account(name, realm, id)
        self.accounts[#self.accounts + 1] = {isOnline = true, clientProgram = "WoW", characterName = name,
            realmName = realm, factionName = "Alliance", gameAccountID = id}
    end
    function f:Login()
        self.loggedIn = true; self:Event("PLAYER_LOGIN")
    end
    function f:LoadMSP() dofile("ForeverRP/Libs/MSP/LibMSP.lua") end
    function f:Drain()
        for _ = 1, 100 do local callback = table.remove(self.timers, 1); if not callback then return end; callback() end
        error("Unbounded library timer queue")
    end
    return f
end
return Fixture
