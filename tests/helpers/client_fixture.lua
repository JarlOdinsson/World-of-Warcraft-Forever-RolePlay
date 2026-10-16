-- Historical experimental suites explicitly load the archived Beta 17 modules.
-- Current Phase 1 isolation is tested with helpers/phase1_fixture.lua instead.
local function Fixture()
    local f = {now = 100, sent = {}, timers = {}, zone = 10, x = 100, y = 200, space = 1,
        lines = {}, result = 0, joined = 0, secret = {}, name = "Local", realm = "Realm"}
    ForeverRP, ForeverRPDB, ForeverRPCharacterDB = {State = {}}, nil, nil
    InCombatLockdown = function() return false end
    GetTime = function() return f.now end
    time = function() return 1800000000 end
    canaccessallvalues = function(...)
        for i = 1, select("#", ...) do if select(i, ...) == f.secret then return false end end
        return true
    end
    GetNormalizedRealmName = function() return f.realm end
    GetRealmName = GetNormalizedRealmName
    UnitName = function() return f.name end
    UnitFullName = function() return f.name, f.realm end
    GetUnitName = function() return f.name .. "-" .. f.realm end
    UnitExists, UnitIsPlayer = function() return true end, function() return true end
    UnitPosition = function() return f.x, f.y, 5, f.space end
    UnitIsAFK, UnitIsDND = function() return f.afk end, function() return f.dnd end
    GetSubZoneText = function() return f.subzone or "Brill" end
    C_Map = {GetBestMapForUnit = function() return f.zone end}
    C_Timer = {After = function(_, callback) f.timers[#f.timers + 1] = callback end,
        NewTicker = function() return {} end}
    C_ChatInfo = {RegisterAddonMessagePrefix = function() return 0 end,
        IsAddonMessagePrefixRegistered = function() return true end,
        SendAddonMessage = function(prefix, payload, channel, target)
            f.sent[#f.sent + 1] = {prefix = prefix, payload = payload, channel = channel, target = target}
            return f.result
        end}
    IsInGroup, IsInGuild, IsInRaid = function() return false end, function() return false end, function() return false end
    JoinChannelByName = function() f.joined = f.joined + 1 end
    LeaveChannelByName = function() f.joined = f.joined - 1 end
    GetChannelName = function() return f.joined > 0 and 7 or 0 end
    dofile("ForeverRP/Core/Constants.lua")
    dofile("ForeverRP/Core/ValueAccess.lua")
    dofile("ForeverRP/Core/Database.lua")
    ForeverRP.Database:Initialize()
    ForeverRP.Debug = function() end
    ForeverRP.Print = function(_, message) f.lines[#f.lines + 1] = message end
    ForeverRP.GetText = function(_, key) return key end
    ForeverRP.EscapePlainText = function(_, value) return value:gsub("|", "||") end
    ForeverRP.NearbyPlayers = {IsNearby = function() return false end, Reevaluate = function() end,
        ReevaluateAll = function() end, Remove = function() end}
    dofile("ForeverRP/Discovery/Presence.lua")
    dofile("ForeverRP/Discovery/Privacy.lua")
    dofile("ForeverRP/Discovery/Communication.lua")
    dofile("ForeverRP/Profile/Profile.lua")
    ForeverRP.Profile:Initialize()
    dofile("ForeverRP/Profile/RemoteProfiles.lua")
    dofile("ForeverRP/Discovery/ProfileTransfer.lua")
    dofile("ForeverRP/Modules/Connections.lua")
    dofile("ForeverRP/Discovery/ProfileAuthorization.lua")
    dofile("experiments/beta17/Discovery/Activity.lua")
    dofile("experiments/beta17/UI/PlayerMarkers.lua")
    ForeverRP.Communication:Initialize()
    function f:Peer(peer)
        ForeverRP.Presence:Update(peer or "Peer-Realm", {addonVersion = "0.1.1-beta.7", protocolVersion = 1})
    end
    function f:Request(peer, id)
        self:Peer(peer)
        ForeverRP.Communication:HandleIncoming("FOREVERRP", "PROFILE_REQUEST|1|0.1.1-beta.7|" .. (id or "P1"),
            "WHISPER", peer or "Peer-Realm", false)
    end
    function f:Drain(limit)
        for _ = 1, limit or 1000 do
            local callback = table.remove(self.timers, 1)
            if not callback then return end
            callback()
        end
        error("unbounded timer queue")
    end
    return f
end
return Fixture
