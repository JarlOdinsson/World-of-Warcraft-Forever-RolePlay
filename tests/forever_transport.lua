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
    Check(f.internal.VERSION, 25); Check(f.internal.ForeverNameCompatibility, true)
    Check(LibStub:NewLibrary("Chomp", 24), nil)
    f = Fixture(16001, "%s %s", 26)
    Check(f.internal.VERSION, 26); Check(f.internal.ForeverNameCompatibility, nil)
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
    local f = Fixture(); f:LoadMSP(); Check(msp.version, 32)
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
    Check(entry.source, "shared-MSP2:Chomp/CTL-after-Ambiguate")
    Check(msp:Request("Spencer Raven-ClassicBetaPvE2"), true)
    entry = ForeverRP.DiscoveryDiagnostics.whispers[#ForeverRP.DiscoveryDiagnostics.whispers]
    Check(entry.api, "BNSendGameData"); Check(entry.recipient, "11"); Check(entry.accepted, nil)
end)

print(string.format("PASS: %d Forever library/transport cases; %d checks (mocked client only)", cases, checks))
