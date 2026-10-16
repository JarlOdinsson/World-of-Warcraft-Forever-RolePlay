local Fixture = dofile("tests/helpers/chomp_fixture.lua")
local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual)); checks = checks + 1
end
local function Test(name, callback) callback(); cases = cases + 1; print("PASS " .. name) end

Test("upstream space-format bug reproduces through the real login Battle.net path", function()
    for _, name in ipairs({"Spencer Raven", "Cheese Spy"}) do
        local f = Fixture(120000, "%s %s") -- retain upstream behavior to reproduce the defect
        f:Account(name, "ClassicBetaPvE2", 11)
        local ok, err = pcall(f.Login, f)
        Check(ok, false)
        Check(err:find("name already has a realm name, but realm name also provided", 1, true) ~= nil, true)
    end
end)

Test("actual login and Battle.net refresh preserve reported multiword names and realm keys", function()
    for _ = 1, 2 do -- a fresh library/client session models /reload initialization
        local f = Fixture()
        f:Account("Spencer Raven", "ClassicBetaPvE2", 11)
        f:Account("Cheese Spy", "ClassicBetaPvE2", 12)
        f:Account("Spencer Raven", "ClassicBetaPvE", 13)
        f:Account("Single", "ClassicBetaPvE2", 14)
        f:Login()
        Check(f.internal.bnetGameAccounts["Spencer Raven-ClassicBetaPvE2"], 11)
        Check(f.internal.bnetGameAccounts["Cheese Spy-ClassicBetaPvE2"], 12)
        Check(f.internal.bnetGameAccounts["Spencer Raven-ClassicBetaPvE"], 13)
        Check(f.internal:GetBattleNetAccountID("spencer raven-ClassicBetaPvE2"), 11)
        Check(f.internal:GetBattleNetAccountName(12), "Cheese Spy-ClassicBetaPvE2")
        Check(f.filters.CHAT_MSG_SYSTEM, nil)
        f:Event("BN_FRIEND_INFO_CHANGED"); Check(f.internal.bnetGameAccounts["Single-ClassicBetaPvE2"], 14)
        f:Event("PLAYER_LEAVING_WORLD"); f:Event("PLAYER_ENTERING_WORLD")
        Check(f.internal.bnetGameAccounts["Spencer Raven-ClassicBetaPvE2"], 11)
    end
end)

Test("merge/split is idempotent with explicit realms and never treats a surname as a realm", function()
    local f = Fixture(); local c = f.chomp
    for _, name in ipairs({"Spencer Raven", "Cheese Spy", "Single"}) do
        for _, realm in ipairs({"ClassicBetaPvE", "ClassicBetaPvE2"}) do
            local full = name .. "-" .. realm
            Check(c.NameMergedRealm(name, realm), full)
            Check(c.NameMergedRealm(full), full)
            Check(c.NameMergedRealm(full, realm), full)
            local first, second = c.NameSplitRealm(full); Check(first, name); Check(second, realm)
        end
    end
    Check(c.NameMergedRealm("Spencer Raven"), "Spencer Raven-ClassicBetaPvE")
    Check(c.NameSplitRealm("Spencer Raven"), nil)
    Check(pcall(c.NameMergedRealm, "Spencer Raven-ClassicBetaPvE", "ClassicBetaPvE2"), false)
    Check(FULL_PLAYER_NAME, "%s %s")
    Check(c.NameFromUnit("player"), "Local Person-ClassicBetaPvE")
    f.unitName, f.unitSecond, f.combined = "Single", "OtherRealm", "Single"
    Check(c.NameFromUnit("player"), "Single-OtherRealm")
    f.combined = "Single-ClassicBetaPvE2"; Check(c.NameFromUnit("player"), "Single-ClassicBetaPvE2")
end)

Test("shared library negotiation upgrades v24 and does not replace newer owners", function()
    local f = Fixture(16001, "%s %s", 24)
    Check(f.internal.VERSION, 26); Check(f.internal.ForeverNameCompatibility, true)
    Check(LibStub:NewLibrary("Chomp", 24), nil)
    f = Fixture(16001, "%s %s", 27)
    Check(f.internal.VERSION, 27); Check(f.internal.ForeverNameCompatibility, nil)
    Check(f.chomp.NameMergedRealm, nil); Check(f.chomp.sentinel, true)
end)

Test("other clients retain upstream display/parser behavior and duplicate-realm errors", function()
    local f = Fixture(120000, "%s-%s")
    Check(f.internal.VERSION, 24); Check(f.internal.ForeverNameCompatibility, false)
    Check(f.chomp.NameMergedRealm("Single", "Realm Name"), "Single-RealmName")
    Check(pcall(f.chomp.NameMergedRealm, "Single-Realm", "Realm"), false)
    f = Fixture(120000, "%s %s")
    Check(pcall(f.chomp.NameMergedRealm, "Spencer Raven", "ClassicBetaPvE2"), false)
    Check(f.chomp.NameMergedRealm("Single", "Realm"), "Single Realm")
    f:Login(); Check(type(f.filters.CHAT_MSG_SYSTEM), "function")
end)

Test("real LibMSP initialization and requests use Chomp keys and API-bound addresses", function()
    local f = Fixture(); f:LoadMSP(); Check(msp.version, 33)
    f:Account("Spencer Raven", "ClassicBetaPvE2", 11)
    f:Login(); msp.eventFrame.scripts.OnEvent(msp.eventFrame, "PLAYER_LOGIN")
    f.now = f.now + 10
    Check(msp:Request("Spencer Raven-ClassicBetaPvE2"), true)
    Check(f.sent[#f.sent].channel, "BATTLENET"); Check(f.sent[#f.sent].target, 11)
    Check(msp:Request("Cheese Spy-ClassicBetaPvE2"), true)
    Check(f.sent[#f.sent].target, "Cheese Spy-ClassicBetaPvE2")
    Check(f.sent[#f.sent].channel, "WHISPER")
    Check(msp:Request("Cheese Spy-ClassicBetaPvE"), true)
    Check(f.sent[#f.sent].target, "Cheese Spy-ClassicBetaPvE")
    Check(msp:Request("Local Person-ClassicBetaPvE"), false)
end)

Test("real MSP path reproduces joined-realm recipients before the Forever parser fix", function()
    for _, name in ipairs({"Cletus Jenkins", "Ellina Stillwind", "Gladiator Trapgodx"}) do
        for _, interface in ipairs({120000, 16001}) do
            local f = Fixture(interface, "%s %s"); f:LoadMSP(); f:Login()
            msp.eventFrame.scripts.OnEvent(msp.eventFrame, "PLAYER_LOGIN")
            f.now = f.now + 10
            local qualified = name .. "-ClassicBetaPvE"
            Check(msp:Request(qualified), true)
            Check(f.sent[#f.sent].channel, "WHISPER")
            Check(f.sent[#f.sent].target, interface == 16001 and qualified or name .. "ClassicBetaPvE")
        end
    end
end)

Test("real observation, ACK, presence, and profile sends retain exact separate recipients", function()
    local AppFixture = dofile("tests/helpers/client_fixture.lua")
    for _, name in ipairs({"Cletus Jenkins", "Ellina Stillwind", "Gladiator Trapgodx"}) do
        local f = AppFixture(); f.realm = "ClassicBetaPvE"
        ForeverRP.Database:SetDebugEnabled(true)
        dofile("ForeverRP/Core/DiscoveryDiagnostics.lua")
        dofile("ForeverRP/Discovery/Range.lua")
        dofile("ForeverRP/Discovery/PlayerDetection.lua")
        dofile("ForeverRP/Discovery/ObservedDiscovery.lua")
        UnitFullName = function(unit)
            if unit == "player" then return "Local", f.realm end
            return name:match("^(%S+) (.+)$")
        end
        GetUnitName = function(unit) return unit == "player" and "Local-" .. f.realm or name end
        InCombatLockdown = function() return false end
        CheckInteractDistance = function() return true end
        Check(ForeverRP.PlayerDetection:DetectUnit("mouseover", "mouseover"), true)
        Check(f.sent[1].payload:match("^HELLO|") ~= nil, true)
        Check(f.sent[1].target, name)
        local d = ForeverRP.DiscoveryDiagnostics
        Check(d.whispers[1].recipient, name)
        Check(d.whispers[1].source, "observed-unit:mouseover:split-name-GetUnitName")
        local sender = name .. "-ClassicBetaPvE"
        ForeverRP.Communication:HandleIncoming("FOREVERRP", "HELLO|1|v", "WHISPER", sender, false)
        Check(f.sent[#f.sent].payload:match("^ACK|") ~= nil, true)
        Check(f.sent[#f.sent].target, sender)
        Check(ForeverRP.Presence:GetTransportRecipient(sender), sender)
        Check(ForeverRP.ProfileTransfer:Request(sender), true)
        Check(f.sent[#f.sent].target, sender)
        Check(d.whispers[#d.whispers].kind, "PROFILE_REQUEST")
        Check(d.whispers[#d.whispers].source, "presence:CHAT_MSG_ADDON.sender:HELLO")
        Check(ForeverRP.ProfileTransfer:SendProfile(sender, "Reply1", sender), true)
        f:Drain()
        Check(f.sent[#f.sent].target, sender)
        Check(d.whispers[#d.whispers].kind, "PROFILE_DATA")
        Check(d.whispers[#d.whispers].source, "received-request-sender")
        local before = #d.whispers
        f.result = 3
        Check(ForeverRP.Communication:Send("HELLO", "WHISPER", name, sender, "explicit-retest"), false)
        Check(d.whispers[#d.whispers].reason, "throttled")
        Check(d.whispers[#d.whispers].result, "3")
        Check(#d.whispers, before + 1)
    end
end)

Test("debug traces are bounded, content-free and off by default", function()
    local f = dofile("tests/helpers/client_fixture.lua")()
    dofile("ForeverRP/Core/DiscoveryDiagnostics.lua")
    local d = ForeverRP.DiscoveryDiagnostics
    d:RecordWhisper("api", "HELLO", "Peer-Realm", "unit", true, "accepted", 0)
    Check(d.whispers, nil); Check(#f.lines, 0)
    ForeverRP.Database:SetDebugEnabled(true)
    for _ = 1, 100 do d:RecordWhisper("api", "HELLO", "Peer-Realm", "unit", true, "accepted", 0) end
    Check(#f.lines, 1)
    for i = 1, 100 do d:RecordWhisper("api", "PROFILE_DATA", "Peer" .. i, "sender", true, "accepted", 0) end
    Check(#f.lines, 30); Check(#d.whispers, 20)
    f.now = f.now + 60
    d:RecordWhisper("api", "ACK", "Peer-Realm", "sender", false, "failed", 1)
    Check(#f.lines, 31)
    ForeverRP.Database:SetDebugEnabled(false)
    d:RecordWhisper("api", "ACK", "Other", "sender", false, "failed", 1)
    Check(#f.lines, 31)
    for _, line in ipairs(f.lines) do Check(line:find("payload", 1, true), nil) end
end)

Test("secure MSP hooks capture post-Ambiguate targets without inventing send success", function()
    local f = Fixture(); f:LoadMSP(); f:Account("Spencer Raven", "ClassicBetaPvE2", 11); f:Login()
    msp.eventFrame.scripts.OnEvent(msp.eventFrame, "PLAYER_LOGIN")
    local lines = {}
    ForeverRP = {Database = {IsDebugEnabled = function() return true end},
        Print = function(_, line) lines[#lines + 1] = line end}
    dofile("ForeverRP/Core/ValueAccess.lua"); dofile("ForeverRP/Core/DiscoveryDiagnostics.lua")
    dofile("ForeverRP/Discovery/MSPCompatibility.lua"); ForeverRP.MSPCompatibility:Initialize()
    f.now = f.now + 10
    f.ambiguate = function(target) return "API-" .. target end -- test evidence capture, not an address recommendation
    Check(msp:Request("Cheese Spy-ClassicBetaPvE2"), true)
    local entry = ForeverRP.DiscoveryDiagnostics.whispers[1]
    Check(f.sent[#f.sent].target, "API-Cheese Spy-ClassicBetaPvE2")
    Check(entry.recipient, f.sent[#f.sent].target)
    Check(entry.accepted, nil)
    Check(entry.reason, "result-not-exposed-by-hook")
    Check(entry.source, "shared-MSP2:API-bound")
    Check(msp:Request("Spencer Raven-ClassicBetaPvE2"), true)
    entry = ForeverRP.DiscoveryDiagnostics.whispers[#ForeverRP.DiscoveryDiagnostics.whispers]
    Check(entry.api, "BNSendGameData"); Check(entry.recipient, "11"); Check(entry.accepted, nil)
end)

Test("observed MSP uses raw multiword recipients through the real library queue", function()
    for _, raw in ipairs({"Asty Pally", "Spencer Raven", "Single", "Cheese Spy-ClassicBetaPvE2"}) do
        local lib = Fixture(); lib:LoadMSP(); lib:Login()
        msp.eventFrame.scripts.OnEvent(msp.eventFrame, "PLAYER_LOGIN")
        local f = dofile("tests/helpers/client_fixture.lua")()
        f.realm = "ClassicBetaPvE"
        dofile("ForeverRP/Discovery/Range.lua")
        dofile("ForeverRP/Discovery/PlayerDetection.lua")
        dofile("ForeverRP/Discovery/ObservedDiscovery.lua")
        dofile("ForeverRP/Discovery/MSPCompatibility.lua")
        local present = true
        UnitExists = function(unit) return unit == "player" or present end
        UnitFullName = function(unit)
            if unit == "player" then return "Local", f.realm end
            if raw:find("-", 1, true) then return "Cheese Spy", "ClassicBetaPvE2" end
            return raw:match("^(%S+) (.+)$") or raw, raw:match("^%S+ (.+)$")
        end
        GetUnitName = function(unit) return unit == "player" and "Local-" .. f.realm or raw end
        -- A deliberately destructive Ambiguate proves the raw path never
        -- round-trips the observed transport string through library lookup keys.
        Ambiguate = function() return "WRONG-ADDRESS" end
        CheckInteractDistance = function() return true end
        Check(ForeverRP.PlayerDetection:DetectUnit("mouseover", "mouseover"), true)
        Check(#f.sent, 1); Check(f.sent[1].prefix, "FOREVERRP"); Check(f.sent[1].target, raw)
        f.now = f.now + 1; lib.internal:RunQueue()
        Check(#f.sent, 2); Check(f.sent[2].prefix, "MSP2"); Check(f.sent[2].target, raw)
        Check(f.sent[2].payload:sub(13, 15), "?TT")
        local key = ForeverRP.PlayerDetection.units.mouseover.characterKey
        Check(ForeverRP.Presence:Get(key, false), nil)
        Check(ForeverRP.NearbyPlayers:IsNearby(key, false), false)
        -- No reply is normal: one bounded HELLO retry, no MSP retry storm.
        f.now = f.now + 12; ForeverRP.ObservedDiscovery:Tick(); lib.internal:RunQueue()
        Check(#f.sent, 3); Check(f.sent[3].target, raw)
        f.now = f.now + 100; ForeverRP.ObservedDiscovery:Tick(); lib.internal:RunQueue()
        Check(#f.sent, 3); Check(ForeverRP.Presence:Get(key, false), nil)
    end
end)

Test("queued observed MSP cancels disappearing, reused, changed-recipient and private units", function()
    for _, change in ipairs({"disappear", "remove", "reuse", "recipient", "hidden", "disabled", "expire"}) do
        local lib = Fixture(); lib:LoadMSP(); lib:Login()
        msp.eventFrame.scripts.OnEvent(msp.eventFrame, "PLAYER_LOGIN")
        local f = dofile("tests/helpers/client_fixture.lua")(); f.realm = "ClassicBetaPvE"
        ForeverRP.Database:SetDebugEnabled(true)
        dofile("ForeverRP/Core/DiscoveryDiagnostics.lua")
        dofile("ForeverRP/Discovery/PlayerDetection.lua")
        dofile("ForeverRP/Discovery/MSPCompatibility.lua")
        local exists, combined = true, "Asty Pally"
        UnitExists = function() return exists end
        UnitFullName = function(unit) if unit == "player" then return "Local", f.realm end; return "Asty", "Pally" end
        GetUnitName = function(unit) return unit == "player" and "Local-" .. f.realm or combined end
        Check(ForeverRP.PlayerDetection:DetectUnit("target", "target"), true)
        Check(lib.internal.observedPending, 1); Check(#f.sent, 0)
        if change == "disappear" then exists = false
        elseif change == "remove" then ForeverRP.PlayerDetection:RemoveUnit("target")
        elseif change == "reuse" then UnitFullName = function() return "Other", "Person" end; combined = "Other Person"
        elseif change == "recipient" then combined = "Asty Pally-ClassicBetaPvE"
        elseif change == "hidden" then ForeverRP.Database:SetPrivacyMode("hidden")
        elseif change == "disabled" then ForeverRP.Database:SetDiscoveryEnabled(false)
        else f.now = f.now + 5 end
        f.now = f.now + 1; lib.internal:RunQueue()
        Check(#f.sent, 0); Check(lib.internal.observedPending, 0)
        Check(ForeverRP.DiscoveryDiagnostics.whispers[1].reason, "stale-observation")
    end
end)

Test("guarded sends expose real boolean/enum results without retrying failures", function()
    for _, result in ipairs({true, false, 0, 1, 3, 8}) do
        local f = Fixture(); f:LoadMSP(); f:Login()
        msp.eventFrame.scripts.OnEvent(msp.eventFrame, "PLAYER_LOGIN")
        local calls, observed = 0, nil
        C_ChatInfo.SendAddonMessage = function(_, _, _, recipient)
            calls = calls + 1; Check(recipient, "Asty Pally"); return result
        end
        Check(msp:RequestObserved("Asty Pally-ClassicBetaPvE", "Asty Pally", function() return true end,
            function(value, reason) observed = value; Check(reason, "sent") end), true)
        f.now = f.now + 1; f.internal:RunQueue()
        Check(observed, result); Check(calls, 1); Check(f.internal.observedPending, 0)
        f.now = f.now + 1; f.internal:RunQueue(); Check(calls, 1)
    end
end)

Test("guarded probes stay bounded and do not use an external noncancellable CTL queue", function()
    local f = Fixture(); f:LoadMSP(); f:Login()
    msp.eventFrame.scripts.OnEvent(msp.eventFrame, "PLAYER_LOGIN")
    local external = 0
    ChatThrottleLib = {SendAddonMessage = function() external = external + 1 end}
    f.internal.ChatThrottleLib = true
    for i = 1, 33 do
        Check(f.chomp.SendObservedMSPRequest("?TT", "Peer " .. i, function() return true end), i <= 32)
    end
    Check(f.internal.observedPending, 32)
    f.now = f.now + 3; f.internal:RunQueue(); Check(external, 0); Check(#f.sent, 32)
    Check(f.internal.observedPending, 0)
    f = Fixture(120000, "%s-%s"); Check(f.chomp.SendObservedMSPRequest, nil)
end)

print(string.format("PASS: %d Forever library/transport cases; %d checks (mocked client only)", cases, checks))
