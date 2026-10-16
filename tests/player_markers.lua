local Fixture = dofile("tests/helpers/client_fixture.lua")
local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function Setup()
    local f = Fixture()
    local Widget = {}; Widget.__index = Widget
    for _, method in ipairs({"SetSize", "EnableMouse", "SetAllPoints", "SetTexture", "SetVertexColor",
        "SetWidth", "SetJustifyH", "SetScrollChild", "SetHeight", "SetShown"}) do
        Widget[method] = function() end
    end
    function Widget:Show() self.shown = true end
    function Widget:Hide() self.shown = false end
    function Widget:SetPoint(_, _, _, x, y) self.px, self.py = x, y; self.anchors = (self.anchors or 0) + 1 end
    function Widget:ClearAllPoints() self.px, self.py = nil, nil end
    function Widget:CreateTexture() return setmetatable({}, Widget) end
    function Widget:CreateFontString() return setmetatable({}, Widget) end
    function Widget:SetText(text) self.text = text end
    function Widget:SetScript(event, callback) self[event] = callback end
    CreateFrame = function() return setmetatable({}, Widget) end
    UIDropDownMenu_Initialize = function() end
    UIDropDownMenu_SetWidth = function() end
    UIDropDownMenu_SetSelectedValue = function() end
    UIDropDownMenu_SetText = function() end
    Minimap = {GetWidth = function() return 200 end, GetHeight = function() return 200 end}
    C_Minimap = {GetViewRadius = function() return f.radius or 100 end}
    GetCVar = function() return f.rotate and "1" or "0" end
    GetPlayerFacing = function() return f.facing end
    local a, db = ForeverRP.Activity, ForeverRP.Database
    db:SetActivitySetting("enabled", true)
    db:SetActivitySetting("markers", true)
    return f, a, db, ForeverRP.PlayerMarkers
end
local function Test(name, callback)
    callback(Setup()); cases = cases + 1; print("PASS " .. name)
end
local function Precise(a, peer, x, y)
    return a:Receive("A2|v|0|public|10|1|" .. (x or 110) .. "|" .. (y or 200)
        .. "|1|IC|NORMAL|0|", "GUILD", peer or "Peer-Realm")
end

Test("actual local marker button immediately hides every pooled frame", function(f, a, db, markers)
    Precise(a); Precise(a, "Other-Realm", 120)
    markers:Refresh(); Check(#markers.pool, 2)
    Check(markers.pool[1].shown, true); Check(markers.pool[2].shown, true)
    dofile("ForeverRP/UI/DiscoveryOptions.lua")
    ForeverRP.DiscoveryOptions:Create({})
    ForeverRP.DiscoveryOptions.markers.OnClick()
    Check(db:GetActivitySettings().markers, false)
    Check(markers.pool[1].shown, false); Check(markers.pool[2].shown, false)
    Check(a:GetPeer("Peer-Realm").x, 110) -- local display preference does not erase remote data
    Check(#f.sent, 0)
    ForeverRP.DiscoveryOptions.markers.OnClick()
    Check(markers.pool[1].shown, true); Check(markers.pool[2].shown, true)
    Check(#markers.pool, 2)
end)

Test("remote hidden and zone-only updates invalidate coordinates and pins immediately", function(f, a, db, markers)
    Precise(a); markers:Refresh(); local pin = markers.pool[1]
    Check(pin.shown, true)
    f.now = 101 -- withholding must bypass the ordinary five-second update cooldown
    Check(a:Receive("A2|v|0|public|0|-|-|-|1|IC|NORMAL|0|", "GUILD", "Peer-Realm"), true)
    Check(a:GetPeer("Peer-Realm").x, nil); Check(a:GetPeer("Peer-Realm").y, nil)
    Check(a:GetPeer("Peer-Realm").space, nil); Check(pin.shown, false)
    f.now = 107; Precise(a); markers:Refresh(); Check(pin.shown, true); Check(#markers.pool, 1)
    f.now = 108
    Check(a:Receive("A2|v|0|public|10|-|-|-|1|IC|NORMAL|0|", "GUILD", "Peer-Realm"), true)
    Check(a:GetPeer("Peer-Realm").x, nil); Check(pin.shown, false)
    f.now = 114; Precise(a); markers:Refresh(); Check(pin.shown, true)
    Check(a:Receive("OFF", "GUILD", "Peer-Realm"), true)
    Check(a:GetPeer("Peer-Realm"), nil); Check(pin.shown, false)
    Check(#f.sent, 0)
end)

Test("lost coordinates expire even with fresh HELLO presence and failed prefix registration", function(f, a, db, markers)
    Precise(a); markers:Refresh(); local pin = markers.pool[1]
    a.wasEnabled, a.registered, a.registrationAttempts = true, false, 3
    f.now = 225; f:Peer()
    Check(a:GetPeer("Peer-Realm").at, 100)
    a:Tick(); Check(pin.shown, true) -- existing 125-second boundary
    f.now = 226; f:Peer()
    Check(a:GetPeer("Peer-Realm").at, 100)
    a:Tick(); Check(pin.shown, false)
    Check(ForeverRP.Presence:IsConfirmed("Peer-Realm", false), true)
    f.now = 251; f:Peer(); a:Tick()
    Check(a:GetPeer("Peer-Realm"), nil); Check(pin.shown, false)
    Check(#f.sent, 0)
end)

Test("stationary heartbeat renews coordinates and pooled reuse preserves movement and zoom", function(f, a, db, markers)
    Precise(a); markers:Refresh(); local pin = markers.pool[1]
    Check(pin.py, 10); local anchors = pin.anchors
    markers:Refresh(); Check(pin.anchors, anchors)
    f.now = 200; Check(Precise(a), true); Check(a:GetPeer("Peer-Realm").at, 200)
    f.now = 226; markers:Refresh(); Check(pin.shown, true)
    Check(a:Receive("OFF", "GUILD", "Peer-Realm"), true); Check(pin.shown, false)
    Check(Precise(a, "Other-Realm", 120), true)
    markers:Refresh()
    Check(markers.pool[1], pin); Check(#markers.pool, 1); Check(pin.py, 20)
    f.x = 110; markers:Refresh(); Check(pin.py, 10)
    f.radius = 50; markers:Refresh(); Check(pin.py, 20)
    f.rotate, f.facing = true, math.pi / 2; markers:Refresh()
    Check(math.abs(pin.px - 20) < 0.001, true); Check(math.abs(pin.py) < 0.001, true)
    f.x = 500; markers:Refresh(); Check(pin.shown, false)
    Check(#f.sent, 0)
end)

Test("network disable and unavailable projection clean pooled pins", function(f, a, db, markers)
    Precise(a); markers:Refresh(); local pin = markers.pool[1]
    C_Minimap.GetViewRadius = function() return f.secret end
    markers:Refresh(); Check(pin.shown, false)
    C_Minimap.GetViewRadius = function() return 100 end
    markers:Refresh(); Check(pin.shown, true)
    db:SetActivitySetting("enabled", false); Check(pin.shown, false)
    a:Tick(); Check(pin.shown, false)
end)
print("PASS: " .. cases .. " player marker cases; " .. checks .. " checks (mock frames and transport only)")
