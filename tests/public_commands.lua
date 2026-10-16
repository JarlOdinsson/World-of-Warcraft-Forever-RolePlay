-- Public and explicitly restored developer command surface.
local checks = 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
ForeverRP = {State = {}}
dofile("ForeverRP/Localization/enUS.lua")
dofile("ForeverRP/Core/Constants.lua")
dofile("ForeverRP/Core/Database.lua")
ForeverRPDB = {debug = true, settings = {debug = true}, connections = {
    ["Peer-Realm"] = {characterKey = "Peer-Realm", privateNote = "Keep my private note"},
}}
ForeverRPCharacterDB = {profile = {rpName = "Keep my profile"}}
ForeverRP.Database:Initialize()
Check(ForeverRP.Database:IsDebugEnabled(), true)
Check(ForeverRPDB.debug, true)
Check(ForeverRPDB.connections["Peer-Realm"].privateNote, "Keep my private note")
Check(ForeverRPCharacterDB.profile.rpName, "Keep my profile")
local lines, panel, requests, previews = {}, nil, 0, 0
ForeverRP.GetText = function(_, key) return ForeverRP.Localization.enUS[key] or key end
ForeverRP.Print = function(_, line) lines[#lines + 1] = line end
ForeverRP.UI = {Show = function(_, value) panel = value end, RefreshSettings = function() end}
ForeverRP.ProfileViewer = {ShowLocal = function() previews = previews + 1 end}
ForeverRP.ProfileTransfer = {Request = function(_, target)
    requests = requests + 1
    Check(target, "Linea Aspera-ClassicBetaPvE")
    return true, target
end}
local calls = {hello = 0, simulation = 0, reports = 0}
ForeverRP.DiscoveryDiagnostics = {Report = function() calls.reports = calls.reports + 1 end}
ForeverRP.Communication = {SendHello = function() calls.hello = calls.hello + 1; return true, "PARTY" end,
    Simulate = function() calls.simulation = calls.simulation + 1 end}
ForeverRP.Presence = {GetAll = function() return {} end}
SlashCmdList = {}
dofile("ForeverRP/Core/Commands.lua")
ForeverRP.Commands:Register()
Check(SLASH_FOREVERRP1, "/frp")
Check(SLASH_FOREVERRP2, "/foreverrp")
SlashCmdList.FOREVERRP("debug off")
Check(ForeverRP.Database:IsDebugEnabled(), false)
SlashCmdList.FOREVERRP("sim hello")
Check(calls.simulation, 0)
SlashCmdList.FOREVERRP("debug on")
SlashCmdList.FOREVERRP("sim hello")
Check(calls.simulation, 1)
SlashCmdList.FOREVERRP("hello")
SlashCmdList.FOREVERRP("diag Peer-Realm")
Check(calls.hello, 1)
Check(calls.reports, 1)
SlashCmdList.FOREVERRP("presence")
Check(lines[#lines], ForeverRP:GetText("PRESENCE_NONE"))
SlashCmdList.FOREVERRP("debug off")
for command, expectedPanel in pairs({[""] = "home", settings = "settings", profile = "profile", view = "viewer"}) do
    SlashCmdList.FOREVERRP(command)
    Check(panel, expectedPanel)
end
Check(previews, 1)
ForeverRP.NearbyPlayers = {GetAll = function(_, includeSimulated)
    Check(includeSimulated, false)
    return {}
end}
SlashCmdList.FOREVERRP("nearby")
Check(lines[#lines], ForeverRP:GetText("NEARBY_NONE"))
SlashCmdList.FOREVERRP("request Linea Aspera-ClassicBetaPvE")
Check(requests, 1)
SlashCmdList.FOREVERRP("help")
Check(lines[#lines], ForeverRP:GetText("HELP"))
for _, retired in ipairs({"debug", "diag", "sim", "hello", "presence"}) do
    Check(lines[#lines]:find("/frp " .. retired, 1, true) ~= nil, true)
end
SlashCmdList.FOREVERRP("version")
Check(lines[#lines - 2], "Build: profile-caret-20261016-20")
print(string.format("PASS: %d public command checks", checks))
