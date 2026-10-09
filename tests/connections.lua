-- Run from the repository root with Lua 5.1 or LuaJIT.
local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end

local Widget = {}
Widget.__index = function(_, key)
    if key == "Text" or key == "text" then return nil end
    return Widget[key] or function() end
end
function Widget:SetScript(event, handler) self.scripts[event] = handler end
function Widget:SetText(text)
    self.text = text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function Widget:GetText() return self.text or "" end
function Widget:Type(text)
    self.text = text
    self.scripts.OnTextChanged(self, true)
end
function Widget:SetShown(shown)
    local wasShown = self.shown
    self.shown = shown
    if wasShown and not shown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Widget:SetEnabled(enabled) self.enabled = enabled end
function Widget:SetChecked(checked) self.checked = checked end
function Widget:GetChecked() return self.checked end
function Widget:ClearFocus()
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function Widget:CreateFontString() return CreateFrame("FontString") end

local function Fixture()
    local f = {store = {}, near = {}, clock = 1000, privacy = "visible", debug = false,
        sent = {}, sendResult = 0, viewed = {}}
    CreateFrame = function() return setmetatable({scripts = {}, shown = true, enabled = true}, Widget) end
    GetTime = function() return f.clock end
    time = function() return 100000 + f.clock end
    GetNormalizedRealmName = function() return "Realm" end
    UnitName = function() return "Self" end
    UnitFullName = nil
    Enum, C_Timer = nil, nil
    C_AddOns, GetAddOnMetadata = nil, nil
    ForeverRP = {}
    dofile("ForeverRP/Localization/enUS.lua")
    dofile("ForeverRP/Core/Constants.lua")
    dofile("ForeverRP/Core/ValueAccess.lua")
    ForeverRP.GetText = function(_, key) return ForeverRP.Localization.enUS[key] or key end
    ForeverRP.Debug = function() end
    ForeverRP.Print = function(_, text) f.message = text end
    ForeverRP.Database = {
        GetConnections = function() return f.store end,
        GetPrivacyMode = function() return f.privacy end,
        IsDebugEnabled = function() return f.debug end,
    }
    ForeverRP.NearbyPlayers = {
        IsNearby = function(_, key) return f.near[key] == true end,
        Reevaluate = function() end,
    }
    C_ChatInfo = {
        RegisterAddonMessagePrefix = function() return 0 end,
        SendAddonMessage = function(prefix, payload, channel, target)
            f.sent[#f.sent + 1] = {prefix = prefix, payload = payload, channel = channel, target = target}
            return f.sendResult
        end,
    }
    dofile("ForeverRP/Discovery/Presence.lua")
    dofile("ForeverRP/Discovery/Privacy.lua")
    ForeverRP.Privacy.IsFriend = function() return f.friend == true end
    ForeverRP.Privacy.IsGuildMember = function() return false end
    dofile("ForeverRP/Discovery/Communication.lua")
    ForeverRP.Communication:Initialize()
    dofile("ForeverRP/Profile/Profile.lua")
    dofile("ForeverRP/Profile/RemoteProfiles.lua")
    dofile("ForeverRP/Discovery/ProfileTransfer.lua")
    dofile("ForeverRP/Modules/Connections.lua")
    dofile("ForeverRP/UI/Connections.lua")
    ForeverRP.ProfileViewer = {
        ShowRemote = function(_, key) f.viewed[#f.viewed + 1] = key end,
        RefreshConnectionActions = function() end,
    }
    ForeverRP.UI = {Show = function() ForeverRP.ConnectionsUI.panel:SetShown(true); ForeverRP.ConnectionsUI:Refresh() end}
    f.addon = ForeverRP
    f.ui = ForeverRP.ConnectionsUI
    f.ui:Create(CreateFrame("Frame"))
    return f
end

local function Confirm(f, key, simulated)
    f.addon.Presence:Update(key, {addonVersion = "0.1.1-beta", protocolVersion = 1, simulated = simulated})
end
local function Remember(f, key) f.addon.Connections:Remember(key, false) end
local function Test(name, run)
    run(Fixture())
    cases = cases + 1
    print("PASS " .. name)
end

Test("unsaved draft survives favorite, name, encounter and repeated refreshes", function(f)
    Remember(f, "Alice-Realm")
    f.ui:Select("Alice-Realm")
    f.ui.note:Type("draft private note")
    f.addon.Connections:SetFavorite("Alice-Realm", true, false)
    f.addon.Connections:CacheRPName("Alice-Realm", "Alice")
    f.addon.Connections:RecordEncounter("Alice-Realm", false)
    f.ui:Refresh()
    Check(f.ui.note:GetText(), "draft private note")
    Check(f.store["Alice-Realm"].privateNote, "")
end)
Test("row selection saves draft to original character", function(f)
    Remember(f, "Alice-Realm"); Remember(f, "Bob-Realm")
    f.ui:Select("Alice-Realm"); f.ui.note:Type("Alice's note")
    f.ui.rows[2].scripts.OnClick(f.ui.rows[2])
    Check(f.ui.selectedKey, "Bob-Realm")
    Check(f.store["Alice-Realm"].privateNote, "Alice's note")
    Check(f.store["Bob-Realm"].privateNote, "")
    Check(f.ui.note:GetText(), "")
    f.ui:Select("Alice-Realm")
    Check(f.ui.note:GetText(), "Alice's note")
end)
Test("programmatic selection preserves empty-note edits", function(f)
    Remember(f, "Alice-Realm"); Remember(f, "Bob-Realm")
    f.addon.Connections:SetNote("Alice-Realm", "old")
    f.ui:Select("Alice-Realm"); f.ui.note:Type("")
    f.ui:Select("Bob-Realm")
    Check(f.store["Alice-Realm"].privateNote, "")
end)
Test("focus loss saves through existing sanitization", function(f)
    Remember(f, "Alice-Realm"); f.ui:Select("Alice-Realm")
    f.ui.note:Type("note\001")
    f.ui.note:ClearFocus()
    Check(f.store["Alice-Realm"].privateNote, "note")
    Check(f.ui.note:GetText(), "note")
    Check(f.ui.noteDirty, false)
end)
Test("panel hiding saves pending edits", function(f)
    Remember(f, "Alice-Realm"); f.ui:Select("Alice-Realm")
    f.ui.note:Type("close draft"); f.ui.panel:SetShown(false)
    Check(f.store["Alice-Realm"].privateNote, "close draft")
end)
Test("logout commits note and preserves existing profile commit", function(f)
    Remember(f, "Alice-Realm"); f.ui:Select("Alice-Realm")
    f.ui.note:Type("logout draft")
    local profileCommits = 0
    f.addon.ProfileEditor = {Commit = function() profileCommits = profileCommits + 1 end}
    dofile("ForeverRP/Core/Events.lua")
    f.addon.Events.handlers.PLAYER_LOGOUT()
    Check(f.store["Alice-Realm"].privateNote, "logout draft")
    Check(profileCommits, 1)
end)
Test("privacy and encounter refreshes cannot erase a draft", function(f)
    Remember(f, "Alice-Realm"); f.ui:Select("Alice-Realm"); f.ui.note:Type("private")
    f.privacy = "hidden"; f.ui:Refresh()
    Check(f.ui.note:GetText(), "private")
    Check(f.ui.detail.shown, false)
    f.privacy = "visible"; f.ui:Refresh()
    Check(f.ui.note:GetText(), "private")
end)
Test("remember confirmed nearby player records epoch timestamp immediately", function(f)
    Confirm(f, "Alice-Realm"); f.near["Alice-Realm"] = true
    Remember(f, "Alice-Realm")
    Check(f.store["Alice-Realm"].lastEncountered, time())
    f.ui:Select("Alice-Realm")
    Check(f.ui.encountered.text, "Last encountered: Just now")
end)
Test("unconfirmed or distant players do not gain encounter timestamps", function(f)
    f.near["Alice-Realm"] = true; Remember(f, "Alice-Realm")
    Confirm(f, "Bob-Realm"); Remember(f, "Bob-Realm")
    Check(f.store["Alice-Realm"].lastEncountered, nil)
    Check(f.store["Bob-Realm"].lastEncountered, nil)
end)
Test("simulated encounter uses epoch time, remains runtime-only, and updates", function(f)
    Confirm(f, "Tester-Realm", true); f.near["Tester-Realm"] = true
    f.addon.Connections:Remember("Tester-Realm", true)
    Check(f.addon.Connections.simulated["Tester-Realm"].lastEncountered, time())
    Check(f.store["Tester-Realm"], nil)
    f.debug = true; f.ui:Select("Tester-Realm", true)
    Check(f.ui.encountered.text, "Last encountered: Just now")
    f.clock = f.clock + 61; f.ui.panel.scripts.OnUpdate(f.ui.panel, 1)
    Check(f.ui.encountered.text, "Last encountered: 1 minutes ago")
end)
Test("real encounter timestamps use epoch time and update", function(f)
    Confirm(f, "Alice-Realm"); f.near["Alice-Realm"] = true; Remember(f, "Alice-Realm")
    Check(f.store["Alice-Realm"].lastEncountered, time())
    f.clock = f.clock + 3601; f.ui:Select("Alice-Realm")
    Check(f.ui.encountered.text, "Last encountered: 1 hours ago")
end)
Test("never encountered Connections display Never", function(f)
    Remember(f, "Alice-Realm"); f.ui:Select("Alice-Realm")
    Check(f.store["Alice-Realm"].lastEncountered, nil)
    Check(f.ui.encountered.text, "Last encountered: Never")
end)
Test("existing persisted encounter timestamps retain elapsed formatting", function(f)
    Remember(f, "Alice-Realm")
    f.store["Alice-Realm"].lastEncountered = time() - (2 * 86400)
    f.ui:Select("Alice-Realm")
    Check(f.ui.encountered.text, "Last encountered: 2 days ago")
end)
Test("simulated Connections appear only while debug is enabled", function(f)
    Confirm(f, "Tester-Realm", true); f.near["Tester-Realm"] = true
    f.addon.Connections:Remember("Tester-Realm", true)
    Check(#f.addon.Connections:GetAll(false), 0)
    Check(f.ui.empty.shown, true)
    f.debug = true; f.ui:Refresh()
    Check(#f.addon.Connections:GetAll(true), 1)
    Check(f.ui.empty.shown, false)
    Check(f.ui.rows[1].characterKey, "Tester-Realm")
    Check(f.ui.rows[1].simulated, true)
    Check(f.ui.rows[1].text.text, "[Known] Tester-Realm [SIM]")
    f.ui.rows[1].scripts.OnClick(f.ui.rows[1])
    Check(f.ui.selectedSimulated, true)
    f.debug = false; f.ui:Refresh()
    Check(f.ui.empty.shown, true)
    Check(f.ui.selectedKey, nil)
end)
Test("simulated Connection actions stay runtime-only", function(f)
    local key = f.addon.Communication:GetSimulatedCharacterKey()
    Confirm(f, key, true); f.near[key] = true; f.debug = true
    f.addon.Connections:Remember(key, true); f.ui:Select(key, true)
    Check(f.ui.selectedSimulated, true)
    f.ui.note:Type("sim note"); f.ui:CommitNote()
    Check(f.addon.Connections.simulated[key].privateNote, "sim note")
    Check(f.store[key], nil)
    f.ui.favorite:SetChecked(true); f.ui.favorite.scripts.OnClick(f.ui.favorite)
    Check(f.addon.Connections:GetLevel(key, true), "favorite")
    f.ui:OpenProfile()
    Check(#f.sent, 0)
    Check(f.viewed[1], key)
    Check(f.addon.RemoteProfiles:HasProfile(key, true), true)
    Check(f.addon.Connections.simulated[key].rpName, "Aveline Starfall")
    f.addon.Connections:Forget(key, true)
    Check(#f.addon.Connections:GetAll(true), 0)
    Check(f.store[key], nil)
end)
Test("uncached confirmed connection uses existing targeted profile request", function(f)
    Remember(f, "Alice-Realm"); Confirm(f, "Alice-Realm"); f.ui:Select("Alice-Realm")
    Check(f.ui.view.text, "Request Profile"); Check(f.ui.view.enabled, true)
    f.ui.view.scripts.OnClick()
    Check(#f.sent, 1); Check(f.sent[1].channel, "WHISPER"); Check(f.sent[1].target, "Alice-Realm")
    Check(f.sent[1].payload:match("^PROFILE_REQUEST|1|"), "PROFILE_REQUEST|1|")
    Check(f.ui.view.text, "Requesting..."); Check(f.ui.view.enabled, false)
    f.ui:OpenProfile(); Check(#f.sent, 1)
end)
Test("unconfirmed connection is unavailable and sends nothing", function(f)
    Remember(f, "Alice-Realm"); f.ui:Select("Alice-Realm")
    Check(f.ui.view.text, "Unavailable"); Check(f.ui.view.enabled, false)
    f.ui:OpenProfile(); Check(#f.sent, 0)
end)
Test("presence expiry updates button and click rechecks reachability", function(f)
    Remember(f, "Alice-Realm"); Confirm(f, "Alice-Realm"); f.ui:Select("Alice-Realm")
    f.clock = f.clock + f.addon.Constants.PRESENCE_EXPIRY_SECONDS + 1
    f.ui:OpenProfile(); Check(#f.sent, 0)
    f.ui.panel.scripts.OnUpdate(f.ui.panel, 1)
    Check(f.ui.view.text, "Unavailable"); Check(f.ui.view.enabled, false)
end)
Test("hidden and restricted unknown peers cannot be requested", function(f)
    Remember(f, "Alice-Realm"); Confirm(f, "Alice-Realm"); f.ui:Select("Alice-Realm")
    f.privacy = "restricted"; f.ui:OpenProfile(); Check(#f.sent, 0)
    f.privacy = "hidden"; f.ui:OpenProfile(); Check(#f.sent, 0)
    Check(f.ui.view.text, "Unavailable")
end)
Test("restricted verified friend can use existing transport", function(f)
    Remember(f, "Alice-Realm"); Confirm(f, "Alice-Realm")
    f.privacy = "restricted"; f.friend = true; f.ui:Select("Alice-Realm")
    f.ui:OpenProfile(); Check(#f.sent, 1)
end)
Test("registration failure disables request", function(f)
    Remember(f, "Alice-Realm"); Confirm(f, "Alice-Realm")
    f.addon.Communication.prefixRegistered = false; f.ui:Select("Alice-Realm")
    Check(f.ui.view.text, "Unavailable"); f.ui:OpenProfile(); Check(#f.sent, 0)
end)
Test("throttle creates no pending request and reports send failure", function(f)
    Remember(f, "Alice-Realm"); Confirm(f, "Alice-Realm"); f.ui:Select("Alice-Realm")
    f.sendResult = 3; f.ui:OpenProfile()
    Check(f.addon.ProfileTransfer:IsRequestPending("Alice-Realm", false), false)
    Check(f.message, "Profile request could not be sent.")
    Check(f.ui.view.text, "Request Profile")
end)
Test("pending timeout enables retry without resetting draft", function(f)
    Remember(f, "Alice-Realm"); Confirm(f, "Alice-Realm"); f.ui:Select("Alice-Realm")
    f.ui:OpenProfile(); f.ui.note:Type("still editing")
    f.clock = f.clock + f.addon.Constants.PROFILE_TRANSFER_TIMEOUT + 1
    f.ui.panel.scripts.OnUpdate(f.ui.panel, 1)
    Check(f.ui.view.text, "Request Profile"); Check(f.ui.note:GetText(), "still editing")
end)
Test("received profile becomes View Profile through existing completion path", function(f)
    Remember(f, "Alice-Realm"); Confirm(f, "Alice-Realm"); f.ui:Select("Alice-Realm")
    f.ui:OpenProfile(); f.ui.note:Type("draft")
    local request = f.addon.Communication:Parse(f.sent[1].payload)
    local profile = {}
    for _, field in ipairs(f.addon.Constants.PROFILE_FIELD_ORDER) do profile[field] = "" end
    profile.rpName, profile.status = "Alice", "IC"
    local encoded = f.addon.ProfileTransfer:SerializeProfile(profile)
    local chunks = f.addon.ProfileTransfer:BuildChunks(encoded)
    for index, chunk in ipairs(chunks) do
        local payload = f.addon.Communication:Serialize("PROFILE_DATA", request.messageId, index, #chunks, chunk)
        f.addon.Communication:HandleIncoming("FOREVERRP", payload, "WHISPER", "Alice-Realm", false)
    end
    Check(f.viewed[1], "Alice-Realm"); Check(f.ui.view.text, "View Profile")
    Check(f.ui.note:GetText(), "draft"); Check(f.store["Alice-Realm"].rpName, "Alice")
    f.ui:OpenProfile(); Check(f.viewed[2], "Alice-Realm"); Check(#f.sent, 1)
end)
print(string.format("PASS: %d Connections regression cases; %d checks", cases, checks))
