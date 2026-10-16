-- Real receive/parser/transfer/cache/viewer code; widgets and client APIs mocked.
local Fixture = dofile("tests/helpers/client_fixture.lua")
local checks, cases = 0, 0
local function Check(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function Widget()
    return {SetText = function(self, text) self.text = text end,
        SetShown = function(self, shown) self.shown = shown end,
        SetEnabled = function(self, enabled) self.enabled = enabled end,
        ClearAllPoints = function() end, SetPoint = function() end,
        SetHeight = function() end, GetStringHeight = function() return 18 end}
end
local function Setup()
    local f = Fixture(); f.realm = "ClassicBetaPvE"
    local peer = "Putrick Margrave-ClassicBetaPvE"
    local raw = "pUtRiCk Margrave-ClassicBetaPvE"
    UnitFullName = function(unit)
        if unit == "player" then return "Local", f.realm end
        return "Putrick", "Margrave"
    end
    GetUnitName = function(unit) return unit == "player" and "Local-" .. f.realm or "Putrick Margrave" end
    dofile("ForeverRP/Discovery/PlayerDetection.lua")
    ForeverRP.PlayerDetection:DetectUnit("target", "target")
    ForeverRP.Communication:HandleIncoming("FOREVERRP", "ACK|1|test", "PARTY", raw, false)
    dofile("ForeverRP/Profile/ProfileViewer.lua")
    dofile("ForeverRP/Discovery/MSPCompatibility.lua")
    local v = ForeverRP.ProfileViewer
    v.panel, v.content, v.title, v.contextLabel = {}, Widget(), Widget(), Widget()
    v.rememberButton, v.favoriteButton, v.manageButton = Widget(), Widget(), Widget()
    for _, field in ipairs(ForeverRP.Constants.PROFILE_FIELD_ORDER) do
        v.rows[#v.rows + 1] = {key = field, label = Widget(), value = Widget()}
    end
    ForeverRP.UI = {Show = function(_, panel) f.opened = panel; f.opens = (f.opens or 0) + 1 end}
    msp = {Request = function() end, char = {}}
    local profile = ForeverRP.ProfileTransfer:GetSimulatedProfile()
    profile.rpName, profile.status = "Putrick's FRP profile", "IC"
    f.profile, f.peer, f.raw, f.viewer = profile, peer, raw, v
    function f:MSP(empty)
        msp.char[self.peer] = {field = empty and {VP = "3", VA = "ForeverRP"}
            or {NA = "External MSP name", CU = "MSP text"}}
        return ForeverRP.MSPCompatibility:OnReceived(self.peer)
    end
    function f:Request()
        Check(ForeverRP.ProfileTransfer:Request(self.peer), true)
        local sent = self.sent[#self.sent]
        Check(sent.prefix, "FOREVERRP"); Check(sent.target, self.raw)
        self.messageId = sent.payload:match("^PROFILE_REQUEST|[^|]+|[^|]+|([^|]+)")
        Check(type(self.messageId), "string")
    end
    function f:ReceiveFRP()
        local encoded = ForeverRP.ProfileTransfer:SerializeProfile(self.profile)
        local chunks = ForeverRP.ProfileTransfer:BuildChunks(encoded)
        -- A sender's case can change while the full canonical identity stays
        -- the same. TransferKey is already case-insensitive.
        for index, chunk in ipairs(chunks) do
            local payload = ForeverRP.Communication:Serialize("PROFILE_DATA", self.messageId, index, #chunks, chunk)
            ForeverRP.Communication:HandleIncoming("FOREVERRP", payload, "WHISPER", self.peer:upper(), false)
        end
    end
    return f
end

for _, order in ipairs({"MSP-first", "FRP-first"}) do
    for _, empty in ipairs({true, false}) do
        local f = Setup()
        if order == "MSP-first" then Check(f:MSP(empty), not empty) end
        f:Request(); f:ReceiveFRP()
        Check(ForeverRP.RemoteProfiles:HasProfile(f.peer, false), true)
        Check(ForeverRP.RemoteProfiles:HasProfile(f.raw, false), true)
        Check(ForeverRP.ProfileTransfer:IsRequestPending(f.peer, false), false)
        Check(f.viewer.remoteSource, "ForeverRP")
        Check(f.viewer.title.text, "Putrick's FRP profile")
        Check(f.viewer.contextLabel.text:find("(MSP)", 1, true), nil)
        if order == "FRP-first" then
            local opens = f.opens
            Check(f:MSP(empty), not empty)
            Check(f.opens, opens)
        end
        Check(f.viewer.remoteSource, "ForeverRP")
        Check(f.viewer.rememberButton.shown, true)
        -- Explicit MSP open cannot downgrade a received FRP profile either.
        Check(f.viewer:ShowMSP(f.peer), true)
        Check(f.viewer.remoteSource, "ForeverRP")
        Check(f.viewer.title.text, "Putrick's FRP profile")
        Check(ForeverRP.RemoteProfiles:GetProfile("Putrick Margrave-ClassicBetaPvE2", false), nil)
        Check(ForeverRP.Profile:Get().rpName == f.profile.rpName, false)
        cases = cases + 1
        print("PASS " .. order .. (empty and " empty MSP" or " populated MSP"))
    end
end

do
    local f = Setup(); f:Request()
    Check(f:MSP(false), true)
    Check(f.opened, nil) -- pending FRP request keeps MSP from opening another view
    f:ReceiveFRP(); Check(f.viewer.remoteSource, "ForeverRP")
    -- Case-insensitive replacement/clearing cannot leave a shadow cache entry.
    Check(ForeverRP.RemoteProfiles:StoreProfile(f.peer:lower(), f.profile, {}), true)
    local count = 0; for _ in pairs(ForeverRP.RemoteProfiles.profiles) do count = count + 1 end
    Check(count, 1)
    ForeverRP.RemoteProfiles:ClearProfile(f.peer:lower())
    Check(ForeverRP.RemoteProfiles:HasProfile(f.peer), false)
    ForeverRP.Database:SetPrivacyMode("hidden")
    Check(ForeverRP.MSPCompatibility:GetProfile(f.peer), nil)
    Check(ForeverRP.ProfileViewer:ShowMSP(f.peer), false)
    cases = cases + 1
    print("PASS pending request, case-equivalent cache identity and privacy")
end

do
    local f = Setup()
    Check(f:MSP(true), false)
    Check(f.opened, nil)
    Check(ForeverRP.MSPCompatibility:HasProfile(f.peer), false)
    Check(f:MSP(false), true)
    Check(f.viewer.remoteSource, "MSP")
    Check(f.viewer.rememberButton.shown, false)
    Check(ForeverRP.MSPCompatibility:HasProfile(f.peer:upper()), true)
    Check(ForeverRP.MSPCompatibility:HasProfile("Putrick Margrave-ClassicBetaPvE2"), false)
    cases = cases + 1
    print("PASS empty MSP cannot open; meaningful MSP-only profiles still work")
end

for _, mode in ipairs({"absent", "disabled"}) do
    for _, order in ipairs({"before", "after"}) do
        local f = Setup()
        if mode == "absent" then ForeverRP.MSPCompatibility, msp = nil, nil
        else
            ForeverRP.MSPCompatibility:SetEnabled(false)
            ForeverRP.Database:Initialize()
            Check(ForeverRP.MSPCompatibility:IsEnabled(), false)
        end
        local function IncomingMSP()
            if ForeverRP.MSPCompatibility then Check(f:MSP(false), false) end
        end
        if order == "before" then IncomingMSP() end
        f:Request(); f:ReceiveFRP()
        if order == "after" then IncomingMSP() end
        Check(f.viewer.remoteSource, "ForeverRP")
        Check(f.viewer.title.text, "Putrick's FRP profile")
        Check(f.sent[1].target, f.raw)
        Check(ForeverRP.RemoteProfiles:HasProfile(f.peer), true)
        cases = cases + 1
        print("PASS native FRP with MSP " .. mode .. " and callback " .. order)
    end
end

print(string.format("PASS: %d profile-source cases; %d checks (mock delivery/UI only)", cases, checks))
