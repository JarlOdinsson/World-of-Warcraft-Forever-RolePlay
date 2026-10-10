-- Run from the repository root with Lua 5.1. No real audio or visual validation.
local checks = 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
ForeverRP = {State = {}, UI = {}}
dofile("ForeverRP/Core/Constants.lua")
dofile("ForeverRP/Localization/enUS.lua")
ForeverRP.GetText = function(_, key) return ForeverRP.Localization.enUS[key] or key end
ForeverRP.Debug = function() end
local message
ForeverRP.Print = function(_, text) message = text end
dofile("ForeverRP/Core/Database.lua")
ForeverRPDB, ForeverRPCharacterDB = nil, nil
ForeverRP.Database:Initialize()
local db = ForeverRP.Database
Check(db:GetNotificationSettings().soundChannel, "Master")
Check(db:SetNotificationSoundChannel("SFX"), true)
db:SetNotificationCooldown(123)
db:Initialize()
Check(db:GetNotificationSettings().soundChannel, "SFX")
Check(db:GetNotificationSettings().cooldown, 123)
Check(db:SetNotificationSoundChannel("invalid"), false)
Check(db:GetNotificationSettings().soundChannel, "SFX")
db:GetNotificationSettings().soundChannel = {}
db:Initialize()
Check(db:GetNotificationSettings().soundChannel, "Master")
db:GetNotificationSettings().soundChannel = nil -- existing SavedVariables without the new key
db:Initialize()
Check(db:GetNotificationSettings().soundChannel, "Master")

local now, sounds = 100, {}
GetTime = function() return now end
SOUNDKIT = {READY_CHECK = 8960, IG_QUEST_LOG_OPEN = 844}
PlaySound = function(kit, channel)
    sounds[#sounds + 1] = {kit = kit, channel = channel}
    return true
end
SetCVar = function() error("must not change global audio settings") end
C_CVar = {SetCVar = SetCVar}
dofile("ForeverRP/UI/Notifications.lua")
local notifications = ForeverRP.Notifications
for _, level in ipairs({"normal", "remembered", "favorite"}) do
    Check(notifications:PlayDiscoverySound(level), true)
    Check(sounds[#sounds].kit, SOUNDKIT.READY_CHECK)
    Check(sounds[#sounds].channel, "Master")
end
db:SetNotificationSoundChannel("SFX")
notifications:PlayDiscoverySound()
Check(sounds[#sounds].channel, "SFX")
db:SetNotificationSetting("sound", false)
notifications.notifiedAt["Peer-Realm"] = 99
Check(notifications:TestSound(), true)
Check(notifications:TestSound(), false)
Check(#sounds, 5)
Check(notifications.notifiedAt["Peer-Realm"], 99)
Check(db:GetNotificationSettings().sound, false)
now = now + 2
Check(notifications:TestSound(), true)
PlaySound = function() return false end
now = now + 2
Check(notifications:TestSound(), false)
Check(message, ForeverRP:GetText("NOTIFICATION_SOUND_UNAVAILABLE"))
PlaySound = nil
now = now + 2
Check(notifications:TestSound(), false)

-- Exercise actual settings callbacks rather than duplicating their implementation.
local Widget = {}
Widget.__index = Widget
function Widget:SetPoint(...) self.point = {...} end
function Widget:SetAllPoints() end
function Widget:SetSize() end
function Widget:SetText(text) self.label = text end
function Widget:SetChecked(value) self.checked = value end
function Widget:SetScript(event, callback) self[event] = callback end
function Widget:CreateFontString() return CreateFrame() end
CreateFrame = function() return setmetatable({}, Widget) end
UIDropDownMenu_SetWidth = function() end
UIDropDownMenu_Initialize = function(widget, callback) widget.initialize = callback end
UIDropDownMenu_CreateInfo = function() return {} end
local options = {}
UIDropDownMenu_AddButton = function(info) options[#options + 1] = info end
UIDropDownMenu_SetSelectedValue = function(widget, value) widget.selected = value end
UIDropDownMenu_SetText = function(widget, text) widget.label = text end
ForeverRP.EmoteBar = {GetSettings = function() return db:GetEmoteBarSettings() end}
dofile("ForeverRP/UI/Settings.lua")
local panel = ForeverRP.UI:CreateSettingsPanel(CreateFrame())
ForeverRP.UI:RefreshSettings()
Check(panel.soundChannelDropdown.selected, "SFX")
Check(panel.testSound.label, "Test Sound")
panel.soundChannelDropdown.initialize(nil, 1)
Check(#options, 2)
Check(options[1].value, "Master")
Check(options[2].value, "SFX")
options[1].func()
Check(db:GetNotificationSettings().soundChannel, "Master")
Check(panel.soundChannelDropdown.selected, "Master")
local previews = 0
notifications.TestSound = function() previews = previews + 1 end
panel.testSound.OnClick()
Check(previews, 1)
Check(panel.emoteScaleDropdown.point[4], 8) -- preserve the user's spacing adjustment
print(string.format("PASS: %d notification/settings checks", checks))
