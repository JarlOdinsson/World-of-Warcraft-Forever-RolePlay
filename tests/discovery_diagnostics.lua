-- Real pipeline modules, mocked client transport/units. No live delivery claim.
local checks = 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function Contains(lines, text)
    return table.concat(lines, "\n"):find(text, 1, true) ~= nil
end
local function Fixture()
    local f = {now = 100, lines = {}, privacy = "visible", enabled = true, sendResult = 0, sent = 0}
    ForeverRP = {}
    GetTime = function() return f.now end
    GetRealmName = function() return "Realm" end
    GetNormalizedRealmName = GetRealmName
    UnitFullName = function(unit)
        if unit == "player" then return "Local", "Realm" end
        if f.units then
            local entry = f.units[unit]
            return entry and entry[1], entry and entry[2]
        end
        return "Peer", "Realm"
    end
    UnitName = UnitFullName
    GetUnitName = function(unit)
        local name, realm = UnitFullName(unit)
        if name then return realm and (name .. "-" .. realm) or name end
    end
    UnitExists = function(unit) return not f.units or unit == "player" or f.units[unit] ~= nil end
    UnitIsPlayer = function() return true end
    CheckInteractDistance = function() return true end
    IsInGroup = function() return f.party == true end
    IsInRaid = function() return false end
    IsInGuild = function() return false end
    LE_PARTY_CATEGORY_INSTANCE = nil
    canaccessallvalues = function(...)
        for i = 1, select("#", ...) do if select(i, ...) == f.secret then return false end end
        return true
    end
    f.secret = {}
    C_ChatInfo = {
        RegisterAddonMessagePrefix = function() return 0 end,
        IsAddonMessagePrefixRegistered = function() return true end,
        SendAddonMessage = function() f.sent = f.sent + 1; return f.sendResult end,
    }
    Enum, C_Timer, RegisterAddonMessagePrefix, IsAddonMessagePrefixRegistered, SendAddonMessage = nil, nil, nil, nil, nil
    dofile("ForeverRP/Core/Constants.lua")
    dofile("ForeverRP/Core/ValueAccess.lua")
    ForeverRP.Debug = function() end
    ForeverRP.Print = function(_, line) f.lines[#f.lines + 1] = line end
    ForeverRP.GetText = function(_, key) return key end
    ForeverRP.Database = {
        GetPrivacyMode = function() return f.privacy end,
        IsDiscoveryEnabled = function() return f.enabled end,
        GetDiscoveryRadius = function() return 20 end,
        IsDebugEnabled = function() return false end,
        GetAccount = function() return {} end,
    }
    ForeverRP.Privacy = {
        CanInteract = function() return f.privacy ~= "hidden" end,
        CanBroadcast = function() return f.privacy ~= "hidden" end,
    }
    dofile("ForeverRP/Core/DiscoveryDiagnostics.lua")
    dofile("ForeverRP/Discovery/Presence.lua")
    dofile("ForeverRP/Discovery/Range.lua")
    dofile("ForeverRP/Discovery/NearbyPlayers.lua")
    dofile("ForeverRP/Discovery/PlayerDetection.lua")
    dofile("ForeverRP/Discovery/Communication.lua")
    ForeverRP.NearbyUI = {rows = {}, Refresh = function() end}
    ForeverRP.ProfileTransfer = {HandleChunk = function() end}
    ForeverRP.Communication:Initialize()
    f.diag = ForeverRP.DiscoveryDiagnostics
    function f:Report(peer)
        self.now = self.now + 5
        self.lines = {}
        Check(self.diag:Report(peer), true)
    end
    function f:Receive(sender, payload, simulated)
        ForeverRP.Communication:HandleIncoming("FOREVERRP", payload or "HELLO|1|0.1.1-beta", "PARTY", sender, simulated)
    end
    return f
end

local f = Fixture()
ForeverRP.Communication:SendHello()
f:Report("Peer-Realm")
Check(Contains(f.lines, "no-eligible-channel"), true)
Check(Contains(f.lines, "transport=C_ChatInfo.SendAddonMessage"), true)
Check(Contains(f.lines, "no-confirmed-presence"), true)
Check(Contains(f.lines, "build=directory-transport-20261010-11"), true)
Check(f.diag:Report("Peer-Realm"), false)

f.party = true
ForeverRP.Communication:SendHello()
f:Receive("Peer-Realm")
f:Report("Peer-Realm")
Check(Contains(f.lines, "rawResult=0"), true)
Check(Contains(f.lines, "decision=accepted"), true)
Check(Contains(f.lines, "presenceCount=1 peerConfirmed=true"), true)
Check(Contains(f.lines, "no-unit-association"), true)
ForeverRP.PlayerDetection:DetectUnit("target", "target")
f:Report("Peer-Realm")
Check(Contains(f.lines, "matched=target valid=true range=WITHIN_10 within=true"), true)
Check(Contains(f.lines, "Nearby=true exclusion=eligible"), true)
Check(f.sent, 2) -- One HELLO, one ACK; diagnostics send no packets.
f.enabled = false
f:Report("Peer-Realm")
Check(Contains(f.lines, "exclusion=discovery-disabled"), true)
f.enabled = true
CheckInteractDistance = function() return false end
ForeverRP.NearbyPlayers:Reevaluate("Peer-Realm")
f:Report("Peer-Realm")
Check(Contains(f.lines, "range=OVER_30"), true)
Check(Contains(f.lines, "exclusion=range-outside-configured-radius"), true)

CheckInteractDistance = nil
ForeverRP.NearbyPlayers:Reevaluate("Peer-Realm")
f:Report("Peer-Realm")
Check(Contains(f.lines, "range=UNKNOWN"), true)
Check(Contains(f.lines, "exclusion=range-unknown"), true)
UnitExists = function() return false end
f:Report("Peer-Realm")
Check(Contains(f.lines, "unit-disappeared-or-identity-changed"), true)

f = Fixture()
f:Receive("Peer-OtherRealm")
ForeverRP.PlayerDetection:DetectUnit("target", "target")
f:Report("Peer-OtherRealm")
Check(Contains(f.lines, "raw=Peer-OtherRealm key=Peer-OtherRealm"), true)
Check(Contains(f.lines, "targetKey=Peer-Realm"), true)
Check(Contains(f.lines, "no-unit-association"), true)
f.privacy = "hidden"
f:Receive("Blocked-Realm")
f:Report("Blocked-Realm")
Check(Contains(f.lines, "decision=privacy"), true)
f:Receive("Peer-Realm", "HELLO|999|0.1.1-beta")
f:Report("Peer-Realm")
Check(Contains(f.lines, "decision=unsupported protocol"), true)
f:Receive("Local-Realm")
Check(f.diag.lastHello.reason, "self")

f = Fixture()
f:Receive("Peer-Realm", "ACK|1|0.1.1-beta")
Check(f.diag.lastAck.kind, "ACK")
local last = f.diag.lastIncoming
f:Receive("Simulator-Realm", nil, true)
Check(f.diag.lastIncoming, last)
f:Receive("Peer-Realm", "PROFILE_DATA|1|0.1.1-beta|id|1|1|PRIVATE_PROFILE_CONTENTS")
Check(f.diag.lastIncoming, last)
for i = 1, 35 do f.diag:RecordIncoming("HELLO", "Peer" .. i .. "-Realm", "Peer" .. i .. "-Realm", "PARTY", "accepted", false) end
local count = 0
for _ in pairs(f.diag.peers) do count = count + 1 end
Check(count, 20)
Check(f.diag.peers["peer1-realm"], nil)
Check(f.diag.peers["peer35-realm"].reason, "accepted")
f:Report("Peer-Realm")
Check(Contains(f.lines, "PRIVATE_PROFILE_CONTENTS"), false)
Check(next(ForeverRP.DiscoveryDiagnostics.peers) ~= nil, true)
f.diag:RecordIncoming("INVALID", f.secret, nil, "PARTY", "invalid-sender", false)
Check(f.diag.lastIncoming.sender, "<inaccessible>")
f:Report("Peer-Realm")
Check(Contains(f.lines, "<inaccessible>"), true)
f.party = true
f.sendResult = 3
ForeverRP.Communication:SendHello()
f:Report("Peer-Realm")
Check(Contains(f.lines, "HELLO-send=throttled accepted=false rawResult=3"), true)
f.sendResult = nil
ForeverRP.Communication:SendHello()
f:Report("Peer-Realm")
Check(Contains(f.lines, "HELLO-send=failed accepted=false rawResult=-"), true)
ForeverRP.Communication.prefixRegistered = false
ForeverRP.Communication:SendHello()
f:Report("Peer-Realm")
Check(Contains(f.lines, "prefix=false clientQuery=true"), true)
Check(Contains(f.lines, "HELLO-send=prefix-unregistered"), true)
local reportCount = #f.lines
dofile("ForeverRP/Core/Commands.lua")
f.diag:Report("Peer-Realm")
Check(#f.lines, reportCount) -- Internal diagnostic reports honor the shared cooldown.
f.now = f.now + 5
f.diag:Report("Peer-Realm")
Check(#f.lines > reportCount, true)

-- Exercise the actual Nearby UI refresh with existing mock row widgets.
local function PrepareUI()
    local function Widget()
        return {
            SetShown = function(self, shown) self.shown = shown end,
            IsShown = function(self) return self.shown == true end,
            SetText = function(self, text) self.text = text end,
            SetHeight = function() end,
        }
    end
    dofile("ForeverRP/UI/Nearby.lua")
    local ui = ForeverRP.NearbyUI
    ui.panel, ui.content, ui.empty = {}, Widget(), Widget()
    local row = Widget()
    row.identity, row.detail, row.connection, row.availability = Widget(), Widget(), Widget(), Widget()
    ui.rows = {row}
    ForeverRP.RemoteProfiles = {GetProfile = function() end, HasProfile = function() return false end}
    ForeverRP.ProfileTransfer.IsRequestPending = function() return false end
    ForeverRP.Connections = {GetLevel = function() return "normal" end, RecordEncounter = function() end}
    return ui, row
end

for _, name in ipairs({"Linea Aspera", "Ravisholan Ruefield"}) do
    f = Fixture()
    local peer = name .. "-ClassicBetaPvE2"
    f.units = {target = {name, "ClassicBetaPvE2"}, party1 = {name, "ClassicBetaPvE2"}}
    local ui, row = PrepareUI()
    Check(ForeverRP.Presence:NormalizeCharacterKey(peer), peer)
    Check(ForeverRP.PlayerDetection:DetectUnit("party1", "group"), true)
    Check(ForeverRP.PlayerDetection:IsValid(ForeverRP.PlayerDetection.units.party1), true)
    f:Receive(peer)
    Check(ForeverRP.Presence:IsConfirmed(peer, false), true)
    Check(ForeverRP.NearbyPlayers:IsNearby(peer, false), true)
    Check(row.characterKey, peer)
    Check(row:IsShown(), true)
    Check(row.identity.text, peer)
    Check(f.diag.pipeline[string.lower(peer)].lastPresence.reason, "eligible")
    Check(f.diag.pipeline[string.lower(peer)].lastPresence.unit, "party1")
    Check(f.diag.uiRefresh.created, true)
    Check(f.diag.uiRefresh.completed, true)
    Check(f.diag.uiRefresh.rowCount, 1)
    f:Report(peer)
    Check(Contains(f.lines, "UFN=[" .. name .. "]/[ClassicBetaPvE2]"), true)
    Check(Contains(f.lines, "presence-triggered-evaluation=eligible"), true)
    Check(Contains(f.lines, "UI-row=true"), true)
end

f = Fixture()
local peer = "Linea Aspera-ClassicBetaPvE2"
f.units = {mouseover = {"Linea Aspera", "ClassicBetaPvE2"}}
local ui, row = PrepareUI()
f:Receive(peer)
Check(f.diag.pipeline[string.lower(peer)].lastPresence.reason, "no-unit-association")
Check(f.diag.uiRefresh, nil) -- No eligible peer means no entry/refresh yet.
Check(ForeverRP.PlayerDetection:DetectUnit("mouseover", "mouseover"), true)
Check(ForeverRP.NearbyPlayers:IsNearby(peer, false), true)
Check(row.characterKey, peer)
Check(f.diag.pipeline[string.lower(peer)].origin, "unit-detected")
ForeverRP.NearbyPlayers:ReevaluateAll()
Check(f.diag.pipeline[string.lower(peer)].count, 3)

-- The proven range defect: unavailable/restricted checks were labelled OVER_30.
for _, result in ipairs({f.secret, "invalid-result"}) do
    CheckInteractDistance = function() return result end
    ForeverRP.NearbyPlayers:Reevaluate(peer)
    Check(ForeverRP.Range:GetRangeState("mouseover"), "UNKNOWN")
    Check(ForeverRP.NearbyPlayers:IsNearby(peer, false), false)
    Check(f.diag.pipeline[string.lower(peer)].reason, "range-unknown")
    Check(row:IsShown(), false)
end
CheckInteractDistance = function() return nil end
Check(ForeverRP.Range:GetRangeState("mouseover"), "UNKNOWN")
CheckInteractDistance = function(_, index) return index == 2 and f.secret or false end
Check(ForeverRP.Range:GetRangeState("mouseover"), "UNKNOWN")
CheckInteractDistance = function() return false end
ForeverRP.NearbyPlayers:Reevaluate(peer)
Check(ForeverRP.Range:GetRangeState("mouseover"), "OVER_30")
Check(f.diag.pipeline[string.lower(peer)].reason, "range-outside-configured-radius")
CheckInteractDistance = function(_, index) return index == 1 end
ForeverRP.NearbyPlayers:Reevaluate(peer)
Check(ForeverRP.Range:GetRangeState("mouseover"), "WITHIN_30")
Check(f.diag.pipeline[string.lower(peer)].reason, "range-bracket-insufficient-for-radius")
CheckInteractDistance = function(_, index) return index == 3 and true or f.secret end
ForeverRP.NearbyPlayers:Reevaluate(peer)
Check(ForeverRP.NearbyPlayers:IsNearby(peer, false), true)
Check(f.diag.pipeline[string.lower(peer)].reason, "eligible")
Check(row:IsShown(), true)

-- Preserve distinct realms; expose a mismatch instead of guessing an alias.
f = Fixture()
f.units = {target = {"Linea Aspera", "OtherClientRealm"}}
f:Receive(peer)
ForeverRP.PlayerDetection:DetectUnit("target", "target")
f:Report(peer)
Check(Contains(f.lines, "decision=accepted"), true)
Check(Contains(f.lines, "targetKey=Linea Aspera-OtherClientRealm"), true)
Check(Contains(f.lines, "UFN=[Linea Aspera]/[OtherClientRealm]"), true)
Check(Contains(f.lines, "no-unit-association"), true)
Check(ForeverRP.NearbyPlayers:IsNearby(peer, false), false)
f.now = f.now + 5
dofile("ForeverRP/Core/Commands.lua")
f.diag:Report(peer)
Check(Contains(f.lines, "peer-input=" .. peer .. " peer=" .. peer), true)
for i = 1, 35 do f.diag:RecordEvaluation("Peer" .. i .. "-Realm", "no-unit-association", nil, "UNKNOWN", "presence-update", 0) end
count = 0
for _ in pairs(f.diag.pipeline) do count = count + 1 end
Check(count, 20)
Check(f.diag.pipeline["peer1-realm"], nil)
local toc = assert(io.open("ForeverRP/ForeverRP.toc", "r"))
local metadata = toc:read("*a")
toc:close()
Check(metadata:find("## X-ForeverRP-Build: " .. ForeverRP.Constants.DIAGNOSTIC_BUILD, 1, true) ~= nil, true)
print("PASS: " .. checks .. " discovery diagnostic checks (mocked APIs, not live discovery)")
