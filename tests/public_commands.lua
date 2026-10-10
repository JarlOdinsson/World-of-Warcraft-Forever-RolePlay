-- Public command surface: retired commands must have no diagnostic/network effects.
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
Check(ForeverRP.Database:IsDebugEnabled(), false)
Check(ForeverRPDB.debug, false)
Check(ForeverRPDB.connections["Peer-Realm"].privateNote, "Keep my private note")
Check(ForeverRPCharacterDB.profile.rpName, "Keep my profile")
local lines, panel, requests, previews = {}, nil, 0, 0
ForeverRP.GetText = function(_, key) return ForeverRP.Localization.enUS[key] or key end
ForeverRP.Print = function(_, line) lines[#lines + 1] = line end
ForeverRP.UI = {Show = function(_, value) panel = value end}
ForeverRP.ProfileViewer = {ShowLocal = function() previews = previews + 1 end}
ForeverRP.ProfileTransfer = {Request = function(_, target)
    requests = requests + 1
    Check(target, "Linea Aspera-ClassicBetaPvE")
    return true, target
end}
local function Forbidden() error("Retired command reached development functionality") end
ForeverRP.DiscoveryDiagnostics = {Report = Forbidden}
ForeverRP.Communication = {SendHello = Forbidden, Simulate = Forbidden}
ForeverRP.Presence = {GetAll = Forbidden}
ForeverRP.Database.SetDebugEnabled = Forbidden
SlashCmdList = {}
dofile("ForeverRP/Core/Commands.lua")
ForeverRP.Commands:Register()
Check(SLASH_FOREVERRP1, "/frp")
Check(SLASH_FOREVERRP2, "/foreverrp")
for _, command in ipairs({"debug", "debug on", "debug off", "diag", "diag Peer-Realm",
    "sim", "sim hello", "sim notify reset", "hello", "presence", "  DIAG Peer-Realm  "}) do
    local before = #lines
    SlashCmdList.FOREVERRP(command)
    Check(#lines, before + 1)
    Check(lines[#lines], ForeverRP:GetText("UNKNOWN_COMMAND"))
end
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
    Check(lines[#lines]:find("/frp " .. retired, 1, true), nil)
end
SlashCmdList.FOREVERRP("version")
Check(lines[#lines - 2], "Build: public-cleanup-20261010-6")
print(string.format("PASS: %d public command checks", checks))
