-- Real discovery/transport/privacy/notification modules; no live-delivery claim.
local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function Fixture()
    local f = {now = 100, units = {}, sent = {}, inaccessible = {}, mode = "visible",
        enabled = true, result = 0, alerts = 0, refreshes = 0, range = true, trusted = false, lines = {},
        sounds = {}, entries = 0}
    ForeverRP = {}
    GetTime = function() return f.now end
    SOUNDKIT = {READY_CHECK = 8960}
    PlaySound = function(kit, channel)
        f.sounds[#f.sounds + 1] = {kit = kit, channel = channel}
        return true
    end
    GetRealmName = function() return "Realm" end
    GetNormalizedRealmName = GetRealmName
    GetNumGroupMembers = function() return 1 end
    IsInGroup, IsInRaid, IsInGuild = function() return false end, function() return false end, function() return false end
    C_FriendList, GetNumFriends, GetFriendInfo, GetNumGuildMembers, GetGuildRosterInfo = nil, nil, nil, nil, nil
    canaccessallvalues = function(...)
        for i = 1, select("#", ...) do
            local value = select(i, ...)
            if value ~= nil and f.inaccessible[value] then return false end
        end
        return true
    end
    UnitExists = function(unit)
        assert(not f.inaccessible[unit], "inaccessible unit reached UnitExists")
        return unit == "player" or f.units[unit] ~= nil
    end
    UnitIsPlayer = function(unit) return unit == "player" or (f.units[unit] and not f.units[unit].npc) end
    UnitFullName = function(unit)
        if unit == "player" then return "Local", "Realm" end
        local data = f.units[unit]
        return data and data[1], data and data[2]
    end
    UnitName = UnitFullName
    GetUnitName = nil
    CheckInteractDistance = function() return f.range end
    Enum, SendAddonMessage, RegisterAddonMessagePrefix, IsAddonMessagePrefixRegistered = nil, nil, nil, nil
    C_ChatInfo = {
        RegisterAddonMessagePrefix = function() return 0 end,
        IsAddonMessagePrefixRegistered = function() return true end,
        SendAddonMessage = function(prefix, payload, channel, target)
            f.sent[#f.sent + 1] = {prefix = prefix, payload = payload, channel = channel, target = target}
            return f.result
        end,
    }
    C_Timer = {NewTicker = function(_, callback) f.tick = callback; return {} end}
    CreateFrame = function()
        return {RegisterEvent = function() end, SetScript = function() end}
    end
    dofile("ForeverRP/Core/Constants.lua")
    dofile("ForeverRP/Core/ValueAccess.lua")
    ForeverRP.Debug = function(_, message)
        if message == "Player entered discovery range:" then f.entries = f.entries + 1 end
    end
    ForeverRP.GetText = function() return "%s" end
    ForeverRP.Print = function(_, line)
        if line:find("DIAG ", 1, true) or line:find("WHISPER ", 1, true) then f.lines[#f.lines + 1] = line
        else f.alerts = f.alerts + 1 end
    end
    ForeverRP.Database = {
        GetAccount = function() return {} end,
        GetPrivacyMode = function() return f.mode end,
        IsDiscoveryEnabled = function() return f.enabled end,
        IsDebugEnabled = function() return true end,
        GetDiscoveryRadius = function() return f.radius or 20 end,
        GetNotificationSettings = function() return {chat = true, sound = true, cooldown = 600} end,
    }
    dofile("ForeverRP/Core/DiscoveryDiagnostics.lua")
    dofile("ForeverRP/Discovery/Presence.lua")
    dofile("ForeverRP/Discovery/Privacy.lua")
    ForeverRP.Privacy.IsFriend = function() return f.trusted end
    dofile("ForeverRP/Discovery/Communication.lua")
    dofile("ForeverRP/Discovery/Range.lua")
    dofile("ForeverRP/Discovery/NearbyPlayers.lua")
    dofile("ForeverRP/Discovery/PlayerDetection.lua")
    dofile("ForeverRP/Discovery/ObservedDiscovery.lua")
    dofile("ForeverRP/UI/Notifications.lua")
    dofile("ForeverRP/Core/Events.lua")
    ForeverRP.NearbyUI = {Refresh = function() f.refreshes = f.refreshes + 1 end}
    ForeverRP.Communication:Initialize()
    ForeverRP.NearbyPlayers:Initialize()
    function f:Detect(token, name, realm, source)
        self.units[token] = {name or "Linea Aspera", realm or "ClassicBetaPvE2"}
        return ForeverRP.PlayerDetection:DetectUnit(token, source or token)
    end
    function f:Receive(sender, kind)
        ForeverRP.Communication:HandleIncoming("FOREVERRP", (kind or "ACK") .. "|1|0.1.1-beta",
            "WHISPER", sender or "Linea Aspera-ClassicBetaPvE2", false)
    end
    function f:Advance(seconds) self.now = self.now + seconds; self.tick() end
    return f
end
local function Test(name, callback)
    callback(Fixture()); cases = cases + 1; print("PASS " .. name)
end
local function Count(tableValue) local count = 0; for _ in pairs(tableValue) do count = count + 1 end; return count end

Test("mouseover probes unrelated player; ACK enters Nearby, refreshes UI and notifies once", function(f)
    f.units.mouseover = {"Linea Aspera", "ClassicBetaPvE2"}
    ForeverRP.Events.handlers.UPDATE_MOUSEOVER_UNIT()
    Check(#f.sent, 1)
    Check(f.sent[1].channel, "WHISPER")
    Check(f.sent[1].target, "Linea Aspera-ClassicBetaPvE2")
    Check(f.sent[1].payload:match("^HELLO|1|"), "HELLO|1|")
    Check(ForeverRP.Presence:IsConfirmed(f.sent[1].target, false), false)
    Check(f.alerts, 0)
    f:Receive()
    Check(ForeverRP.NearbyPlayers:IsNearby(f.sent[1].target, false), true)
    Check(f.alerts, 1)
    Check(f.refreshes, 1)
    f:Receive()
    f:Advance(15)
    Check(#f.sent, 1)
    Check(f.alerts, 1)
end)

Test("target and nameplate tokens share one peer handshake", function(f)
    f:Detect("target")
    f.units.nameplate1 = {"Linea Aspera", "ClassicBetaPvE2"}
    ForeverRP.Events.handlers.NAME_PLATE_UNIT_ADDED("nameplate1")
    Check(#f.sent, 1)
    f:Receive(nil, "HELLO")
    Check(#f.sent, 2)
    Check(f.sent[2].payload:match("^ACK|1|"), "ACK|1|")
    Check(ForeverRP.NearbyPlayers:IsNearby("Linea Aspera-ClassicBetaPvE2", false), true)
end)

Test("repeated events and missing ACK allow only two attempts per five minutes", function(f)
    for _ = 1, 40 do f:Detect("target") end
    Check(#f.sent, 1)
    f:Advance(15)
    Check(#f.sent, 2)
    for _ = 1, 20 do f:Advance(5); f:Detect("target") end
    Check(#f.sent, 2)
    Check(ForeverRP.Presence:IsConfirmed("Linea Aspera-ClassicBetaPvE2", false), false)
    f:Advance(600)
    Check(#f.sent, 2)
    f.units.target = nil; f:Advance(301)
    f:Detect("target"); Check(#f.sent, 3)
end)

Test("throttled, failed and boolean sends remain bounded without false confirmation", function(f)
    for _, result in ipairs({3, 99, false, true, 0}) do
        f = Fixture(); f.result = result
        f:Detect("target"); f:Advance(15); f:Advance(15)
        Check(#f.sent, 2)
        Check(ForeverRP.Presence:IsConfirmed("Linea Aspera-ClassicBetaPvE2", false), false)
        Check(f.alerts, 0)
    end
end)

Test("privacy revocation and discovery disable cancel queued sends and reject directed presence", function(f)
    for _, mode in ipairs({"hidden", "restricted", "disabled"}) do
        f = Fixture(); f:Detect("target")
        if mode == "disabled" then f.enabled = false else f.mode = mode end
        f:Advance(15); f:Receive(nil, "HELLO")
        Check(#f.sent, 1)
        Check(ForeverRP.Presence:IsConfirmed("Linea Aspera-ClassicBetaPvE2", false), false)
        Check(f.alerts, 0)
    end
    f = Fixture(); f.mode = "restricted"; f.trusted = true
    f:Detect("target"); Check(#f.sent, 1)
    f.trusted = false; ForeverRP.Privacy:OnRelationshipsChanged()
    f:Advance(15); Check(#f.sent, 1)
end)

Test("hidden and restricted strangers never initiate; disabled never responds", function(f)
    f.mode = "hidden"; f:Detect("target"); Check(#f.sent, 0)
    f.mode = "restricted"; f:Detect("target"); Check(#f.sent, 0)
    f.mode = "visible"; f.enabled = false; f:Detect("target"); f:Receive(nil, "HELLO")
    Check(#f.sent, 0)
end)

Test("NPCs, inaccessible units/identities and self do not send", function(f)
    local secret = {}; f.inaccessible[secret] = true
    Check(ForeverRP.PlayerDetection:DetectUnit(secret, "mouseover"), false)
    f.units.mouseover = {secret, "Realm"}
    Check(ForeverRP.PlayerDetection:DetectUnit("mouseover", "mouseover"), false)
    f.units.mouseover = {"Guard", "Realm", npc = true}
    Check(ForeverRP.PlayerDetection:DetectUnit("mouseover", "mouseover"), false)
    f:Detect("target", "Local", "Realm")
    Check(#f.sent, 0)
end)

Test("removed or reused nameplates cannot send stale retry", function(f)
    f:Detect("nameplate1", nil, nil, "nameplate")
    ForeverRP.Events.handlers.NAME_PLATE_UNIT_REMOVED("nameplate1")
    f:Advance(15); Check(#f.sent, 1)
    f = Fixture(); f:Detect("nameplate1", nil, nil, "nameplate")
    f.units.nameplate1 = {"Different", "Realm"}
    f:Advance(15); Check(#f.sent, 1)
end)

Test("unknown range can handshake but never enters Nearby; movement reevaluates", function(f)
    f.range = nil; f:Detect("target"); Check(#f.sent, 1)
    f:Receive(); Check(f.alerts, 0)
    Check(ForeverRP.NearbyPlayers:IsNearby("Linea Aspera-ClassicBetaPvE2", false), false)
    f.range = true; f:Advance(1)
    Check(ForeverRP.NearbyPlayers:IsNearby("Linea Aspera-ClassicBetaPvE2", false), true)
    Check(f.alerts, 1)
    f.range = false; f:Advance(1)
    Check(ForeverRP.NearbyPlayers:IsNearby("Linea Aspera-ClassicBetaPvE2", false), false)
end)

Test("out-of-range observations wait for a usable bracket", function(f)
    f.range = false; f:Detect("target"); Check(#f.sent, 0)
    f.range = true; f:Advance(1); Check(#f.sent, 1)
end)

Test("different incoming realm remains unmatched; no guessed alias", function(f)
    f:Detect("target")
    f:Receive("Linea Aspera-OtherRealm")
    Check(ForeverRP.Presence:IsConfirmed("Linea Aspera-OtherRealm", false), true)
    Check(ForeverRP.NearbyPlayers:IsNearby("Linea Aspera-OtherRealm", false), false)
    Check(f.alerts, 0)
end)

Test("group-only observations and simulation never initiate directed probes", function(f)
    f:Detect("party1", "Party", "Realm", "group")
    ForeverRP.Range:SetSimulatedState("Tester-Realm", "10")
    ForeverRP.PlayerDetection:SetSimulatedCharacter("Tester-Realm")
    f:Advance(15); Check(#f.sent, 0)
end)

Test("crowd queue, burst and rolling minute limits include retries", function(f)
    for index = 1, 100 do f:Detect("nameplate" .. index, "Peer" .. index, "Realm", "nameplate") end
    Check(#f.sent, 4)
    local pending = 0
    for _, peer in pairs(ForeverRP.ObservedDiscovery.peers) do if peer.pending then pending = pending + 1 end end
    Check(pending, 32)
    for _ = 1, 59 do f:Advance(1) end
    Check(#f.sent, 20)
    Check(Count(ForeverRP.ObservedDiscovery.peers) <= 128, true)
end)

Test("directed HELLO response storm shares burst budget and per-peer cooldown", function(f)
    for _ = 1, 50 do f:Receive(nil, "HELLO") end
    Check(#f.sent, 1)
    for index = 1, 50 do f:Receive("Other" .. index .. "-Realm", "HELLO") end
    Check(#f.sent, 4)
    Check(f.alerts, 0)
end)

Test("transport throttling pauses probes to other peers", function(f)
    f.result = 3; f:Detect("target")
    f:Detect("nameplate1", "Other", "Realm", "nameplate")
    Check(#f.sent, 1)
    f.result = 0; f:Advance(9); Check(#f.sent, 1)
    f:Advance(1); Check(#f.sent, 2)
end)

Test("history capacity does not evict non-responder suppression or grow without bound", function(f)
    for index = 1, 140 do
        f:Detect("nameplate" .. index, "Peer" .. index, "Realm", "nameplate")
        f:Advance(15)
    end
    Check(Count(ForeverRP.ObservedDiscovery.peers), 128)
    Check(ForeverRP.ObservedDiscovery.peers["peer1-realm"] ~= nil, true)
    Check(#f.sent, 256)
end)

Test("observed confirmed peers renew before 900-second expiry", function(f)
    f:Detect("target"); f:Receive()
    f:Advance(599); Check(#f.sent, 1)
    f:Advance(1); Check(#f.sent, 2)
    f:Receive(); f:Advance(301)
    Check(ForeverRP.Presence:IsConfirmed("Linea Aspera-ClassicBetaPvE2", false), true)
    Check(f.alerts, 1)
end)

Test("diagnostic report includes the actual observed probe and exact exclusion", function(f)
    f.range = nil; f:Detect("target")
    Check(ForeverRP.DiscoveryDiagnostics:Report("Linea Aspera-ClassicBetaPvE2"), true)
    local output = table.concat(f.lines, "\n")
    Check(output:find("observed-probe=accepted attempts=1 pending=true unit=target range=UNKNOWN", 1, true) ~= nil, true)
    Check(output:find("exclusion=no-confirmed-presence", 1, true) ~= nil, true)
    f:Receive(); f.now = f.now + 5; f.lines = {}
    Check(ForeverRP.DiscoveryDiagnostics:Report("Linea Aspera-ClassicBetaPvE2"), true)
    Check(table.concat(f.lines, "\n"):find("exclusion=range-unknown", 1, true) ~= nil, true)
    Check(f.alerts, 0)
end)

local function ForeverNames(f, realm)
    GetRealmName = function() return realm or "ClassicBetaPvE" end
    GetNormalizedRealmName = GetRealmName
    GetUnitName = function(unit)
        if unit == "player" then return "Local" end
        local data = f.units[unit]
        return data and (data.full or (data[1] .. " " .. data[2]))
    end
end

Test("exact Linea split API returns match accepted presence through target and party2", function(f)
    ForeverNames(f)
    f.radius = 30
    CheckInteractDistance = function(_, index) return index == 1 or index == 4 end
    f:Detect("target", "Linea", "Aspera")
    f:Detect("party2", "Linea", "Aspera", "group")
    local key = "Linea Aspera-ClassicBetaPvE"
    Check(ForeverRP.PlayerDetection.units.target.characterKey, key)
    Check(ForeverRP.PlayerDetection.units.party2.characterKey, key)
    Check(f.sent[1].target, "Linea Aspera")
    Check(ForeverRP.ObservedDiscovery.peers[string.lower(key)].characterKey, key)
    f:Receive(key)
    Check(#ForeverRP.PlayerDetection:GetUnits(key, false), 2)
    Check(ForeverRP.NearbyPlayers:IsNearby(key, false), true)
    Check(ForeverRP.NearbyPlayers:Get(key, false).rangeState, "WITHIN_30")
    Check(f.alerts, 1)
    Check(f.refreshes, 1)
    Check(ForeverRP.DiscoveryDiagnostics:Report(key), true)
    local output = table.concat(f.lines, "\n")
    Check(output:find("UFN=[Linea]/[Aspera] UN=[Linea]/[Aspera] GUN=[Linea Aspera] normalized=[" .. key .. "]", 1, true) ~= nil, true)
    Check(output:find("matched=none", 1, true) == nil, true)
    Check(output:find("exclusion=eligible", 1, true) ~= nil, true)
end)

Test("exact Ravisholan split API returns associate even when HELLO arrived first", function(f)
    ForeverNames(f)
    local key = "Ravisholan Ruefield-ClassicBetaPvE"
    f:Receive(key, "HELLO")
    Check(ForeverRP.NearbyPlayers:IsNearby(key, false), false)
    f:Detect("mouseover", "Ravisholan", "Ruefield")
    Check(ForeverRP.PlayerDetection.units.mouseover.characterKey, key)
    Check(ForeverRP.NearbyPlayers:IsNearby(key, false), true)
    Check(f.alerts, 1)
    Check(#f.sent, 1) -- ACK only; confirmed peer needs no probe.
    Check(f.sent[1].target, key)
    Check(ForeverRP.Presence:IsConfirmed("Ravisholan-Ruefield", false), false)
end)

Test("ClassicBetaPvE2 remains a distinct realm, not a hardcoded alias", function(f)
    ForeverNames(f, "ClassicBetaPvE2")
    f:Detect("nameplate1", "Linea", "Aspera", "nameplate")
    f:Receive("Linea Aspera-ClassicBetaPvE")
    Check(ForeverRP.NearbyPlayers:IsNearby("Linea Aspera-ClassicBetaPvE", false), false)
    f:Receive("Linea Aspera-ClassicBetaPvE2")
    Check(ForeverRP.NearbyPlayers:IsNearby("Linea Aspera-ClassicBetaPvE2", false), true)
    Check(#ForeverRP.PlayerDetection:GetUnits("Linea Aspera-ClassicBetaPvE", false), 0)
end)

Test("explicit GetUnitName realm preserves same-name cross-realm peers and raw recipients", function(f)
    ForeverNames(f)
    f.units.target = {"Linea", "Aspera", full = "Linea Aspera-Other-Realm"}
    f.units.nameplate1 = {"Linea", "Aspera", full = "Linea Aspera-AnotherRealm"}
    ForeverRP.PlayerDetection:DetectUnit("target", "target")
    ForeverRP.PlayerDetection:DetectUnit("nameplate1", "nameplate")
    Check(f.sent[1].target, "Linea Aspera-Other-Realm")
    Check(f.sent[2].target, "Linea Aspera-AnotherRealm")
    Check(ForeverRP.PlayerDetection.units.target.characterKey, "Linea Aspera-OtherRealm")
    f:Receive("Linea Aspera-Other-Realm")
    f:Receive("Linea Aspera-AnotherRealm")
    Check(ForeverRP.NearbyPlayers:GetCount(false), 2)
    Check(ForeverRP.Presence:GetTransportRecipient("Linea Aspera-OtherRealm"), "Linea Aspera-Other-Realm")
    Check(#ForeverRP.PlayerDetection:GetUnits("Linea Aspera-ClassicBetaPvE", false), 0)
end)

Test("genuine UnitFullName realm is retained when it is not part of the complete name", function(f)
    ForeverNames(f)
    f.units.target = {"Linea Aspera", "OtherRealm", full = "Linea Aspera"}
    ForeverRP.PlayerDetection:DetectUnit("target", "target")
    Check(ForeverRP.PlayerDetection.units.target.characterKey, "Linea Aspera-OtherRealm")
    Check(f.sent[1].target, "Linea Aspera-OtherRealm")
    f:Receive("Linea Aspera-OtherRealm")
    Check(ForeverRP.NearbyPlayers:IsNearby("Linea Aspera-OtherRealm", false), true)
end)

Test("tooltip and self-filter use complete Forever names", function(f)
    ForeverNames(f)
    f:Detect("target", "Linea", "Aspera")
    f:Receive("Linea Aspera-ClassicBetaPvE")
    ForeverRP.RemoteProfiles = {GetProfile = function() return nil end}
    dofile("ForeverRP/UI/PlayerTooltip.lua")
    local lines = 0
    ForeverRP.PlayerTooltip:Process({GetUnit = function() return "Linea Aspera", "target" end,
        AddLine = function() lines = lines + 1 end, Show = function() end})
    Check(lines, 1)
    local previous = UnitFullName
    UnitFullName = function(unit)
        if unit == "player" then return "Ravisholan", "Ruefield" end
        return previous(unit)
    end
    UnitName = UnitFullName
    GetUnitName = function() return "Ravisholan Ruefield" end
    Check(ForeverRP.Presence:IsSelf("Ravisholan Ruefield-ClassicBetaPvE"), true)
    Check(ForeverRP.Presence:IsSelf("Ravisholan-Ruefield"), false)
    Check(ForeverRP.Presence:IsSelf("Ravisholan Ruefield-OtherRealm"), false)
end)

Test("conflicting, restricted and missing complete-name evidence is skipped safely", function(f)
    ForeverNames(f)
    f.units.target = {"Linea", "Aspera", full = "Unrelated Display Name"}
    Check(ForeverRP.PlayerDetection:DetectUnit("target", "target"), false)
    local secret = {}; f.inaccessible[secret] = true
    GetUnitName = function() return secret end
    Check(ForeverRP.PlayerDetection:DetectUnit("target", "target"), false)
    GetUnitName = function() return nil end
    Check(ForeverRP.PlayerDetection:DetectUnit("target", "target"), false)
    GetUnitName = function() return "Linea Aspera" end
    f.units.target[2] = secret
    Check(ForeverRP.PlayerDetection:DetectUnit("target", "target"), false)
    Check(#f.sent, 0)
end)

Test("profile requests and responses preserve raw sender addresses separately from keys", function(f)
    ForeverNames(f)
    local raw, key = "Linea Aspera-Other-Realm", "Linea Aspera-OtherRealm"
    f.units.target = {"Linea", "Aspera", full = raw}
    ForeverRP.PlayerDetection:DetectUnit("target", "target")
    f:Receive(raw)
    dofile("ForeverRP/Profile/Profile.lua")
    ForeverRP.Profile.Get = function()
        local profile = {}
        for _, field in ipairs(ForeverRP.Constants.PROFILE_FIELD_ORDER) do profile[field] = "" end
        profile.status = "IC"
        return profile
    end
    dofile("ForeverRP/Discovery/ProfileTransfer.lua")
    local accepted, requestedKey = ForeverRP.ProfileTransfer:Request(key)
    Check(accepted, true)
    Check(requestedKey, key)
    Check(f.sent[#f.sent].target, raw)
    Check(ForeverRP.ProfileTransfer:IsRequestPending(key, false), true)
    Check(ForeverRP.ProfileTransfer:HandleRequest({messageId = "incoming"}, raw, key, false), true)
    Check(f.sent[#f.sent].target, raw)
    Check(f.sent[#f.sent].payload:match("^PROFILE_DATA|"), "PROFILE_DATA|")
end)

Test("separate lookup key cannot authorize an invalid or different transport identity", function(f)
    local secret = {}; f.inaccessible[secret] = true
    Check(ForeverRP.Communication:Send("HELLO", "WHISPER", secret, "Peer-Realm"), false)
    Check(ForeverRP.Communication:Send("HELLO", "WHISPER", "Other-Realm", "Peer-Realm"), false)
    Check(ForeverRP.Communication:Send("HELLO", "WHISPER", "Peer|bad-Realm", "Peer-Realm"), false)
    Check(#f.sent, 0)
end)

Test("eligible bracket and unit changes never replay alerts; reentry respects cooldown", function(f)
    local peer = "Linea Aspera-ClassicBetaPvE2"
    f.radius = 30
    f:Detect("target"); f:Receive()
    Check(#f.sounds, 1); Check(f.entries, 1)
    for _, within10 in ipairs({false, true, false, true}) do
        CheckInteractDistance = function(_, index) return index == 1 or index == 4 or within10 end
        ForeverRP.NearbyPlayers:Reevaluate(peer)
        Check(#f.sounds, 1); Check(f.entries, 1)
    end
    f:Detect("party2"); f.units.target = nil
    ForeverRP.PlayerDetection:RemoveUnit("target")
    ForeverRP.NearbyPlayers:Reevaluate(peer)
    Check(#f.sounds, 1); Check(f.alerts, 1)
    CheckInteractDistance = function() return false end
    ForeverRP.NearbyPlayers:Reevaluate(peer)
    Check(ForeverRP.NearbyPlayers:IsNearby(peer, false), false)
    CheckInteractDistance = function() return true end
    ForeverRP.NearbyPlayers:Reevaluate(peer)
    Check(#f.sounds, 1); Check(f.alerts, 1)
    f.now = f.now + 600
    f:Receive(); Check(#f.sounds, 1)
    CheckInteractDistance = function() return false end
    ForeverRP.NearbyPlayers:Reevaluate(peer)
    CheckInteractDistance = function() return true end
    ForeverRP.NearbyPlayers:Reevaluate(peer)
    Check(#f.sounds, 2); Check(f.alerts, 2)
end)

print(string.format("PASS: %d observed discovery cases; %d checks", cases, checks))
