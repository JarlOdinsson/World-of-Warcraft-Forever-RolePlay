local Fixture = dofile("tests/helpers/client_fixture.lua")
local checks = 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local f = Fixture()
local a, db = ForeverRP, ForeverRP.Database
local widgets = {}
local Widget = {}; Widget.__index = Widget
for _, method in ipairs({"SetJustifyH", "SetAllPoints", "SetScrollChild", "SetHeight", "SetAutoFocus", "SetMaxLetters", "ClearFocus", "ClearAllPoints"}) do Widget[method] = function() end end
function Widget:SetWidth(w) self.width = w end
function Widget:SetSize(w, h) self.width, self.height = w, h end
function Widget:SetPoint(_, x, y) self.x, self.y = x, y end
function Widget:SetText(text) self.text = text end
function Widget:GetText() return self.text or "" end
function Widget:SetScript(event, run) self[event] = run end
function Widget:Show() self.shown = true end
function Widget:Hide() self.shown = false end
function Widget:IsShown() return self.shown ~= false end
function Widget:SetShown(value) self.shown = value end
function Widget:SetEnabled(value) self.enabled = value end
local function New(kind) local w = setmetatable({kind = kind}, Widget); widgets[#widgets + 1] = w; return w end
function Widget:CreateFontString() return New("text") end
CreateFrame = function(kind) return New(kind) end
UIDropDownMenu_SetWidth = function(widget, width) widget.width = width end
UIDropDownMenu_Initialize = function(widget, run) widget.initialize = run end
UIDropDownMenu_CreateInfo = function() return {} end
UIDropDownMenu_SetText = function(widget, text) widget.text = text end
UIDropDownMenu_SetSelectedValue = function() end
UIDropDownMenu_AddButton = function() end
dofile("ForeverRP/UI/DiscoveryOptions.lua")
dofile("ForeverRP/UI/Activity.lua")
local privacy, directory = a.DiscoveryOptions, a.ActivityUI
privacy:Create({}); directory:Create({})
local disabled = "Discovery disabled: enable discovery in Settings."
local hidden = "Hidden visibility blocks networking: Settings > Discovery Visibility."
local off = "Experimental Network OFF: enable in Privacy > Experimental Network."
-- All eight combinations: saved preference must not change the effective gate.
for _, discovery in ipairs({false, true}) do
    for _, visibility in ipairs({"hidden", "visible"}) do
        for _, network in ipairs({false, true}) do
            db:SetDiscoveryEnabled(discovery); db:SetPrivacyMode(visibility, true); db:SetActivitySetting("enabled", network)
            local expected = {}
            if not discovery then expected[#expected + 1] = disabled end
            if visibility == "hidden" then expected[#expected + 1] = hidden end
            if not network then expected[#expected + 1] = off end
            Check(table.concat(a.Activity:GetNetworkingBlockers(), "\n"), table.concat(expected, "\n"))
            Check(a.Activity:Enabled(), discovery and visibility ~= "hidden" and network)
            Check(privacy.experimental.text, "Experimental Network: " .. (network and "ON" or "OFF"))
            Check(privacy.visibilityStatus.text, "Discovery Visibility: " .. (visibility == "hidden" and "Hidden" or "Visible") .. " (change in Settings)")
            if #expected > 0 then Check(directory.status.text, table.concat(expected, "\n")) end
            if not network then Check(privacy.networkStatus.text, "Saved preference: OFF. Networking disabled.")
            elseif not discovery and visibility == "hidden" then Check(privacy.networkStatus.text, "Saved preference: ON - paused by discovery disabled and Hidden visibility.")
            elseif not discovery then Check(privacy.networkStatus.text, "Saved preference: ON - paused by discovery disabled.")
            elseif visibility == "hidden" then Check(privacy.networkStatus.text, "Saved preference: ON - paused by Hidden visibility.")
            else Check(privacy.networkStatus.text, "Settings permit networking; connection and delivery are not confirmed.") end
        end
    end
end
-- Listing and location are independent of browsing; do not auto-opt-in.
db:SetActivitySetting("directory", false); db:SetActivitySetting("location", "hidden")
Check(a.Activity:Enabled(), true)
Check(privacy.directory.text, "Directory Participation: OFF")
Check(privacy.dropdowns[2].widget.text, "Don't share my location")
a.Activity:Receive("A2|v|0|public|10|-|-|-|1|IC|NORMAL|0|", "GUILD", "Other-Realm")
directory:Refresh(); Check(directory.rows[1].characterKey, "Other-Realm")
db:SetPrivacyMode("restricted", true)
Check(privacy.visibilityStatus.text, "Discovery Visibility: Friends/Guild Only (change in Settings)")
Check(a.Activity:Enabled(), true)
Check(#a.Activity:GetNetworkingBlockers(), 0)
-- Actual panel switching refreshes; no new OnUpdate/polling timer needed.
a.UI = {panels = {privacy = privacy.panel, activity = directory.panel, home = New("Frame")}}
dofile("ForeverRP/UI/MainWindow.lua")
a.UI:ShowPanel("privacy"); db:SetPrivacyMode("hidden", true)
Check(privacy.networkStatus.text, "Saved preference: ON - paused by Hidden visibility.")
a.UI:ShowPanel("activity"); Check(directory.status.text, hidden)
db:SetDiscoveryEnabled(false); Check(directory.status.text, disabled .. "\n" .. hidden)
db:SetActivitySetting("enabled", false); Check(directory.status.text, disabled .. "\n" .. hidden .. "\n" .. off)
a.UI:ShowPanel("privacy"); Check(privacy.experimental.text, "Experimental Network: OFF")
-- SavedVariables initialization and panel recreation model /reload (not a live client reload).
db:Initialize(); privacy:Refresh(); a.UI:ShowPanel("activity")
Check(directory.status.text, disabled .. "\n" .. hidden .. "\n" .. off)
Check(db:GetPrivacyMode(), "hidden"); Check(db:GetActivitySettings().directory, false)
Check(db:GetActivitySettings().location, "hidden"); Check(db:GetActivitySettings().enabled, false)
-- Recreate widgets from saved settings, as a fresh UI does after /reload.
privacy:Create({}); directory:Create({})
Check(privacy.visibilityStatus.text, "Discovery Visibility: Hidden (change in Settings)")
Check(privacy.experimental.text, "Experimental Network: OFF")
Check(directory.status.text, disabled .. "\n" .. hidden .. "\n" .. off)
db:SetActivitySetting("enabled", true)
Check(db:GetPrivacyMode(), "hidden"); Check(db:IsDiscoveryEnabled(), false)
Check(privacy.networkStatus.text, "Saved preference: ON - paused by discovery disabled and Hidden visibility.")
Check(directory.status.text, disabled .. "\n" .. hidden)
db:SetDiscoveryEnabled(true)
Check(privacy.networkStatus.text, "Saved preference: ON - paused by Hidden visibility.")
Check(db:GetActivitySettings().location, "hidden")
-- Conservative mock fit estimate: six pixels per glyph, 12 per line. No font-rendering claim.
for _, text in ipairs({disabled, hidden, off}) do Check(#text * 6 <= 480, true) end
for _, button in ipairs({privacy.experimental, privacy.markers, privacy.directory, privacy.subzone}) do
    Check(#button.text * 6 <= button.width - 16, true)
end
for _, item in ipairs(privacy.dropdowns) do
    for _, choice in ipairs(item.choices) do Check(#choice[2] * 6 <= item.widget.width - 16, true) end
end
Check(privacy.visibilityStatus.y, -110); Check(privacy.networkStatus.y, -290)
local statusLines = math.ceil(#privacy.networkStatus.text * 6 / privacy.networkStatus.width)
Check(statusLines * 12 <= 30, true)
Check(#privacy.visibilityStatus.text * 6 <= privacy.visibilityStatus.width, true)
for _, w in ipairs(widgets) do
    if w.kind == "text" and w.text then
        local lines = 0
        for line in (w.text .. "\n"):gmatch("(.-)\n") do lines = lines + math.max(1, math.ceil(#line * 6 / (w.width or 480))) end
        if w.y == -185 then Check(lines * 12 <= 45, true) end
        if w.y == -390 then Check(lines * 12 <= 45, true) end
    end
end
print("PASS: privacy UX; " .. checks .. " checks (mock layout only)")
