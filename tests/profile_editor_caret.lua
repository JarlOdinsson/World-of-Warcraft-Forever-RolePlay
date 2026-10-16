-- Actual profile editor with mocked widgets; rendering still needs a live test.
local checks = 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local Widget = {}; Widget.__index = Widget
local function New(kind, parent)
    return setmetatable({kind = kind, parent = parent, scripts = {}, textures = {}, shown = true,
        height = 0, width = 0, offset = 0, text = ""}, Widget)
end
for _, name in ipairs({"SetAllPoints", "SetAutoFocus", "SetFontObject", "SetMultiLine",
    "SetTextInsets", "SetColorTexture"}) do Widget[name] = function() end end
function Widget:SetPoint(...) self.point = {...} end
function Widget:ClearAllPoints() self.point = nil end
function Widget:SetSize(w, h) self.width, self.height = w, h end
function Widget:SetWidth(w) self.width = w end
function Widget:SetHeight(h) self.height = h end
function Widget:GetHeight() return self.height end
function Widget:SetMaxLetters(n) self.maxLetters = n end
function Widget:SetScript(event, run) self.scripts[event] = run end
function Widget:Fire(event, ...) if self.scripts[event] then self.scripts[event](self, ...) end end
function Widget:Show() self.shown = true; self:Fire("OnShow") end
function Widget:Hide() self.shown = false; self:Fire("OnHide") end
function Widget:SetShown(value) self.shown = value end
function Widget:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Widget:SetFocus() self.focused = true; self:Fire("OnEditFocusGained") end
function Widget:HasFocus() return self.focused == true end
function Widget:ClearFocus()
    local wasFocused = self.focused; self.focused = false
    if wasFocused then self:Fire("OnEditFocusLost") end
end
function Widget:SetText(text) self.text = text; self:Fire("OnTextChanged", false) end
function Widget:GetText() return self.text end
function Widget:SetScrollChild(child) self.child = child end
function Widget:UpdateScrollChildRect() self.updates = (self.updates or 0) + 1 end
function Widget:GetVerticalScroll() return self.offset end
function Widget:SetVerticalScroll(offset) self.offset = offset end
function Widget:CreateFontString() return New("FontString", self) end
function Widget:CreateTexture(_, layer)
    local texture = New("Texture", self); texture.layer = layer
    self.textures[#self.textures + 1] = texture
    return texture
end
CreateFrame = function(kind, _, parent) return New(kind, parent) end
UIDropDownMenu_SetWidth = function() end
UIDropDownMenu_Initialize = function() end
UIDropDownMenu_SetSelectedValue = function() end
UIDropDownMenu_SetText = function() end
StaticPopupDialogs, YES, NO, ChatFontNormal = {}, "Yes", "No", {}
local saved, secret = {description = "Saved description", history = "Saved history"}, {}
ForeverRP = {Constants = {PROFILE_LIMITS = {}, PROFILE_STATUSES = {"OOC"}},
    Profile = {GetField = function(_, key) return saved[key] end,
        SetField = function(_, key, value) saved[key] = value end,
        GetCompletion = function() return 0, 11 end},
    GetText = function(_, key) return key == "PROFILE_COMPLETION" and "%d/%d" or key end,
    ValueAccess = {CanAccess = function(_, ...)
        for i = 1, select("#", ...) do if select(i, ...) == secret then return false end end
        return true
    end}}
for _, key in ipairs({"rpName", "title", "race", "class", "age", "pronouns", "currently",
    "atAGlance", "description", "history", "oocNotes"}) do ForeverRP.Constants.PROFILE_LIMITS[key] = 2000 end
dofile("ForeverRP/Profile/ProfileEditor.lua")
local editor = ForeverRP.ProfileEditor
editor:Create(New("Frame"))

-- No idle timers or caret on short fields; all long fields start unfocused.
Check(#editor.fields.rpName.textures, 0)
for _, key in ipairs({"atAGlance", "description", "history", "oocNotes"}) do
    local box = editor.fields[key]
    Check(#box.textures, 1)
    Check(box.textures[1].shown, false)
    Check(box.scripts.OnUpdate, nil)
    Check(box.maxLetters, 2000)
end
local box = editor.fields.description
local caret, scroll = box.textures[1], box.parent
box:SetFocus()
Check(caret.shown, false) -- Wait for actual cursor geometry, never guess a position.
box:Fire("OnCursorChanged", 6, -6, 1, 14)
Check(caret.shown, true)
Check(caret.layer, "OVERLAY")
Check(caret.point[2], box)
Check(caret.point[4], 6)
Check(caret.point[5], -6)
Check(caret.width, 2)
Check(caret.height, 14)
box:Fire("OnUpdate", 0.5)
Check(caret.shown, false)
box:Fire("OnUpdate", 0.5)
Check(caret.shown, true)
box:Fire("OnUpdate", 0.6)
box:Fire("OnCursorChanged", 85, -24, 1, 18) -- Typing/arrows restart the visible phase.
Check(caret.shown, true)
Check(caret.point[4], 85)
Check(caret.point[5], -24)
Check(caret.height, 18)

-- Native wrapped position can exceed the old text-length height estimate.
box:SetText(string.rep("W", 80))
Check(box:GetHeight(), 130)
box:Fire("OnCursorChanged", 40, -190, 1, 20)
Check(box:GetHeight(), 216)
Check(scroll:GetVerticalScroll(), 80)
Check(-caret.point[5] + caret.height <= scroll.offset + scroll.height, true)
box:Fire("OnCursorChanged", 6, -6, 1, 14)
Check(scroll.offset, 6)

-- Losing focus saves exactly the multiline text and stops blinking.
local draft = "  draft\nsecond line  "
box:SetText(draft)
box:ClearFocus()
Check(saved.description, draft)
Check(box:GetText(), draft)
Check(caret.shown, false)
Check(box.scripts.OnUpdate, nil)
scroll:SetVerticalScroll(40)
box:Fire("OnCursorChanged", 6, -6, 1, 14)
Check(scroll.offset, 40)
Check(caret.shown, false)
box:SetFocus()
Check(caret.shown, true)
box:SetText("unsaved replacement")
box:Fire("OnEscapePressed")
Check(box:GetText(), draft)
Check(saved.description, draft)
Check(box:HasFocus(), false)
Check(box.scripts.OnUpdate, nil)

-- A hidden field cannot keep blinking or restart from a layout event.
box:SetFocus()
box:Hide()
Check(caret.shown, false)
Check(box.scripts.OnUpdate, nil)
box:Fire("OnCursorChanged", 9, -6, 1, 14)
Check(caret.shown, false)
box:Show()
Check(caret.shown, true)
box.focused = false -- Defensive cleanup if focus changes without its callback.
box:Fire("OnUpdate", 0.1)
Check(caret.shown, false)
Check(box.scripts.OnUpdate, nil)

-- Invalid/restricted geometry hides the caret instead of drawing a false position.
box:SetFocus()
for _, metrics in ipairs({{secret, -6, 14}, {6, "bad", 14}, {6, -6, 0},
    {0/0, -6, 14}, {math.huge, -6, 14}, {6, -math.huge, 14}, {6, -6, math.huge}}) do
    box:Fire("OnCursorChanged", metrics[1], metrics[2], 1, metrics[3])
    Check(caret.shown, false)
    Check(box.scripts.OnUpdate, nil)
end
box:Fire("OnCursorChanged", 6, -6, 1, 14)
Check(caret.shown, true)
Check(box:GetText(), draft)
box:ClearFocus()
local history = editor.fields.history
history:Fire("OnCursorChanged", 6, -6, 1, 14)
history:SetFocus()
Check(history.textures[1].shown, true)
Check(caret.shown, false)
history:ClearFocus()
editor.fields.rpName:SetText("  Example Name  ")
editor:CommitField("rpName")
Check(saved.rpName, "Example Name")
print("PASS: " .. checks .. " profile editor caret checks (mock widgets; live rendering unverified)")
