-- Optional argument: extracted Beta 12 addon root for actual mixed-version replay.
local Fixture = dofile("tests/helpers/client_fixture.lua")
local legacy = arg and arg[1]
local requesterVersion = arg and arg[2] or "0.1.1-beta.13"
local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function Activate(f) for key, value in pairs(f.env) do _G[key] = value end end
local function Label()
    return {SetText = function(self, value) self.text = value end, SetHeight = function() end}
end
local function Client(name, realm, root)
    local f = Fixture(); f.name, f.realm = name, realm
    if root then
        for _, file in ipairs({"Core/Constants.lua", "Core/ValueAccess.lua", "Discovery/Presence.lua",
            "Discovery/Privacy.lua", "Discovery/Communication.lua", "Profile/Profile.lua",
            "Profile/RemoteProfiles.lua", "Discovery/ProfileTransfer.lua", "Modules/Connections.lua",
            "Discovery/ProfileAuthorization.lua"}) do dofile(root .. "/" .. file) end
        ForeverRP.Profile:Initialize(); ForeverRP.Communication:Initialize()
        ForeverRP.Constants.ADDON_VERSION = "0.1.1-beta.12"
    else
        ForeverRP.Constants.ADDON_VERSION = requesterVersion
    end
    ForeverRP.Database:SetDebugEnabled(true)
    ForeverRP.Debug = function(_, ...) f.lines[#f.lines + 1] = table.concat({...}, " ") end
    dofile("ForeverRP/Core/DiscoveryDiagnostics.lua")
    dofile("ForeverRP/UI/Nearby.lua")
    dofile("ForeverRP/Profile/ProfileViewer.lua")
    local v = ForeverRP.ProfileViewer
    v.panel, v.content, v.title, v.contextLabel = {}, Label(), Label(), Label()
    ForeverRP.UI = {Show = function(_, panel) f.panel = panel end}
    f.addon, f.env = ForeverRP, {}
    for key, value in pairs(_G) do f.env[key] = value end
    return f
end
local function Contains(f, needle)
    for _, line in ipairs(f.lines) do if line:find(needle, 1, true) then return true end end
    return false
end
local function Hello(f, sender)
    Activate(f)
    f.addon.Communication:HandleIncoming("FOREVERRP", "ACK|1|0.1.1-beta.12", "PARTY", sender, false)
end
local function Click(f, key)
    Activate(f)
    -- Execute the actual Nearby row OnClick callback, not just Request().
    CreateFrame = function()
        local widget = {scripts = {}}
        function widget:SetScript(event, fn) self.scripts[event] = fn end
        function widget:CreateFontString() return CreateFrame() end
        for _, method in ipairs({"SetHeight", "SetPoint", "SetHighlightTexture", "SetJustifyH", "SetSize"}) do
            widget[method] = function() end
        end
        return widget
    end
    local row = f.addon.NearbyUI:CreateRow(1)
    row.characterKey, row.simulated = key, false
    row.scripts.OnClick(row)
    f.env.CreateFrame = CreateFrame
    return f.sent[#f.sent]
end

for _, failure in ipairs({"none", "requester-realm", "responder-realm", "approval"}) do
    local requester = Client("Requester Person", "ClassicBetaPvE")
    local responder = Client("Putrick Margrave", "ClassicBetaPvE2", legacy)
    Hello(requester, "Putrick Margrave"); Hello(responder, "Requester Person")
    Activate(responder)
    responder.addon.Profile:SetField("rpName", "PRIVATE PROFILE MARKER")
    responder.addon.Profile:SetField("description", string.rep("private text ", 100))
    if failure == "approval" then responder.addon.Database:SetDisclosureMode("approval") end
    local outgoing = Click(requester, "Putrick Margrave-ClassicBetaPvE")
    Check(outgoing.target, "Putrick Margrave")
    Check(outgoing.payload:match("^PROFILE_REQUEST|1|([^|]+)|"), requesterVersion)
    local id = outgoing.payload:match("^PROFILE_REQUEST|[^|]+|[^|]+|([^|]+)")
    Check(type(id), "string")
    Check(Contains(requester, "stage=nearby-click"), true)
    Check(Contains(requester, "id=" .. id), true)
    Activate(responder)
    responder.addon.Communication:HandleIncoming(outgoing.prefix, outgoing.payload, "WHISPER",
        failure == "responder-realm" and "Requester Person-ClassicBetaPvE" or "Requester Person", false)
    responder:Drain()
    if failure == "responder-realm" then
        Check(#responder.sent, 0)
        Check(Contains(responder, "ignored from unconfirmed sender"), true)
    else
        Check(#responder.sent > 0, true)
        Activate(requester)
        for _, reply in ipairs(responder.sent) do
            Check(reply.target, "Requester Person")
            requester.addon.Communication:HandleIncoming(reply.prefix, reply.payload, "WHISPER",
                failure == "requester-realm" and "Putrick Margrave-ClassicBetaPvE2" or "Putrick Margrave", false)
        end
        if failure == "none" then
            Check(requester.addon.RemoteProfiles:HasProfile("Putrick Margrave-ClassicBetaPvE"), true)
            Check(requester.addon.ProfileViewer.title.text, "PRIVATE PROFILE MARKER")
            Check(Contains(requester, "stage=cache"), true)
            Check(Contains(requester, "stage=viewer"), true)
            Check(Contains(requester, "stage=chunk-accepted"), true)
        else
            Check(requester.addon.RemoteProfiles:HasProfile("Putrick Margrave-ClassicBetaPvE"), false)
            Check(Contains(requester, failure == "approval" and "reason=pending" or "reason=unconfirmed-sender"), true)
        end
    end
    for _, line in ipairs(requester.lines) do
        Check(line:find("PRIVATE PROFILE MARKER", 1, true), nil)
        Check(line:find("private text", 1, true), nil)
    end
    cases = cases + 1
    print("PASS mixed-version pipeline: " .. failure .. (legacy and " (actual Beta 12 responder)" or " (current responder)"))
end

do
    local f = Fixture(); dofile("ForeverRP/Core/DiscoveryDiagnostics.lua")
    local d = ForeverRP.DiscoveryDiagnostics
    d:RecordProfile("test", "Peer-Realm", "ID", "decision")
    Check(d.profileTrace, nil)
    ForeverRP.Database:SetDebugEnabled(true)
    for i = 1, 100 do d:RecordProfile("test", "Peer-Realm", "ID" .. i, "decision") end
    Check(#d.profileTrace, 60); Check(#f.lines, 60)
    f.now = f.now + 60
    for i = 1, 100 do d:RecordProfile("test", "Peer-Realm", "ID" .. i, "decision") end
    Check(#d.profileTrace, 64); Check(#f.lines, 120)
    d:RecordProfile("test", f.secret, "ID", "decision"); Check(#f.lines, 120)
    Check(d:ReportProfiles(), true); Check(d:ReportProfiles(), false)
    cases = cases + 1
    print("PASS metadata tracing caps, inaccessible values, debug off and report rate limit")
end
print(string.format("PASS: %d profile-pipeline cases; %d checks (mock transport; actual legacy code only when root supplied)", cases, checks))
