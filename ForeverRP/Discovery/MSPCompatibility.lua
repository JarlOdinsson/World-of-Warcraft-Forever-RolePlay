local Addon = ForeverRP

-- LibMSP owns the MSP wire protocol.  This module only consumes profiles for
-- players the client has independently exposed as target or mouseover units.
local MSP = {
    profiles = {},
    requests = {},
    initialized = false,
}
Addon.MSPCompatibility = MSP

-- Temporary requester-side diagnostic switch. Default remains enabled. The
-- optional flag survives /reload so each A/B pass can start with empty caches.
function MSP:IsEnabled()
    local account = Addon.Database and Addon.Database.GetAccount and Addon.Database:GetAccount()
    return not account or account.diagnosticMSPDisabled ~= true
end

function MSP:SetEnabled(enabled)
    local account = Addon.Database:GetAccount()
    account.diagnosticMSPDisabled = enabled == false and true or nil
    self.profiles, self.requests = {}, {}
    if Addon.ProfileViewer then Addon.ProfileViewer:Refresh() end
end

local function Now()
    return GetTime and GetTime() or 0
end

local function Key(characterKey)
    return type(characterKey) == "string" and string.lower(characterKey) or nil
end

local function StoredKey(profiles, characterKey)
    local target = Key(characterKey)
    if not target then return nil end
    if profiles[characterKey] then return characterKey end
    for key in pairs(profiles) do
        if Key(key) == target then return key end
    end
    return characterKey
end

local function HasContent(profile)
    -- The importer supplies OOC as a default; protocol metadata/default status
    -- alone is not an external roleplay profile.
    for _, field in ipairs(Addon.Constants.PROFILE_FIELD_ORDER) do
        if field ~= "status" and type(profile[field]) == "string" and profile[field]:find("%S") then
            return true
        end
    end
    return false
end

local function EmptyProfile()
    local profile = {}
    for _, field in ipairs(Addon.Constants.PROFILE_FIELD_ORDER) do
        profile[field] = ""
    end
    profile.status = "OOC"
    return profile
end

local function ValidText(value, limit)
    if type(value) ~= "string" or #value > limit then
        return nil
    end
    for index = 1, #value do
        local byte = string.byte(value, index)
        if byte == 127 or byte < 32 then
            return nil
        end
    end
    return value
end

function MSP:GetLibrary()
    if type(msp) ~= "table" or type(msp.Request) ~= "function"
        or type(msp.char) ~= "table" then
        return nil
    end
    return msp
end

function MSP:CanRequest(characterKey)
    return self:IsEnabled() and type(characterKey) == "string"
        and not Addon.Presence:IsSelf(characterKey)
        and Addon.Privacy:CanInteract(characterKey, "WHISPER", false)
end

function MSP:ObserveUnit(unit, characterKey, source)
    if source ~= "target" and source ~= "mouseover" then
        return false, "source"
    end
    if not self:CanRequest(characterKey) then
        return false, "privacy"
    end
    local library = self:GetLibrary()
    if not library then
        return false, "unavailable"
    end
    local key = Key(characterKey)
    local requestedAt = self.requests[key]
    local cooldown = Addon.Constants.MSP_REQUEST_COOLDOWN_SECONDS or 30
    if requestedAt and Now() - requestedAt < cooldown then
        return false, "cooldown"
    end

    -- Lookup keys are for MSP's cache, not transport addressing. Shared library
    -- versions without the cancellable Forever adapter cannot safely queue an
    -- automatic observation request; do not replace their globals.
    if type(library.RequestObserved) ~= "function" then return false, "safe-transport-unavailable" end
    local detection = Addon.PlayerDetection.units[unit]
    if not detection or detection.simulated or not Addon.PlayerDetection:IsValid(detection)
        or detection.characterKey ~= characterKey then return false, "stale-observation" end
    local recipient, evidence = detection.transportRecipient, detection.recipientSource
    local trigger = detection.trigger and (":trigger=" .. detection.trigger) or ""
    if not Addon.ValueAccess:IsString(recipient) or recipient == "" then return false, "no-transport-recipient" end
    local function Validate()
        return Addon.Database:IsDiscoveryEnabled() and self:CanRequest(characterKey)
            and Addon.PlayerDetection.units[unit] == detection
            and Addon.PlayerDetection:IsValid(detection)
            and detection.transportRecipient == recipient
    end
    local function Report(result, reason)
        local diagnostics = Addon.DiscoveryDiagnostics
        if diagnostics then
            local accepted = result == true or result == 0
            if reason == "sent" then
                reason = accepted and "accepted" or ((result == 3 or result == 8) and "throttled" or "failed")
            end
            diagnostics:RecordWhisper("C_ChatInfo.SendAddonMessage", "MSP2", recipient,
                "observed-unit:" .. unit .. ":" .. (evidence or "client-identity") .. trigger, accepted, reason, result)
        end
    end
    local requested = library:RequestObserved(characterKey, recipient, Validate, Report)
    if requested == false then
        return false, "rejected"
    end
    self.requests[key] = Now()
    return true
end

function MSP:FindObservedKey(sender)
    local normalized = Addon.Presence:NormalizeCharacterKey(sender)
    if not normalized or Addon.Presence:IsSelf(normalized) then
        return nil
    end
    local target = Key(normalized)
    for _, characterKey in ipairs(Addon.PlayerDetection:GetCharacterKeys(false)) do
        if Key(characterKey) == target then
            return characterKey
        end
    end
    return nil
end

function MSP:BuildProfile(fields)
    if type(fields) ~= "table" then
        return nil
    end
    local profile = EmptyProfile()
    local mapping = {
        NA = "rpName",
        NT = "title",
        RA = "race",
        FC = "class",
        CU = "currently",
    }
    for mspField, profileField in pairs(mapping) do
        local value = fields[mspField]
        if value ~= nil then
            value = ValidText(value, Addon.Constants.PROFILE_LIMITS[profileField] or 0)
            if not value then
                return nil
            end
            profile[profileField] = value
        end
    end
    return Addon.Profile:SanitizeRemoteProfile(profile)
end

function MSP:EvictOldest()
    local oldestKey, oldestAt
    for characterKey, entry in pairs(self.profiles) do
        local receivedAt = type(entry.receivedAt) == "number" and entry.receivedAt or -math.huge
        if not oldestKey or receivedAt < oldestAt or (receivedAt == oldestAt and characterKey < oldestKey) then
            oldestKey, oldestAt = characterKey, receivedAt
        end
    end
    if oldestKey then
        self.profiles[oldestKey] = nil
        if Addon.ProfileViewer then
            Addon.ProfileViewer:RefreshIfViewing(oldestKey)
        end
    end
end

function MSP:StoreProfile(characterKey, profile)
    if not self:CanRequest(characterKey) then
        return false, "privacy"
    end
    local sanitized = Addon.Profile:SanitizeRemoteProfile(profile)
    if not sanitized or not HasContent(sanitized) then
        return false, "profile"
    end
    characterKey = StoredKey(self.profiles, characterKey)
    if not self.profiles[characterKey] then
        local count = 0
        for _ in pairs(self.profiles) do count = count + 1 end
        if count >= (Addon.Constants.REMOTE_PROFILE_CACHE_MAX or math.huge) then
            self:EvictOldest()
        end
    end
    self.profiles[characterKey] = {
        characterKey = characterKey,
        profile = sanitized,
        receivedAt = Now(),
        source = "MSP",
    }
    return true
end

function MSP:OnReceived(sender)
    if not self:IsEnabled() then return false end
    local library = self:GetLibrary()
    local characterKey = self:FindObservedKey(sender)
    if not library or not characterKey then
        return false
    end
    local character = library.char[sender]
    local profile = character and self:BuildProfile(character.field)
    if not profile or not self:StoreProfile(characterKey, profile) then
        return false
    end
    if Addon.ProfileViewer then
        if Addon.RemoteProfiles:HasProfile(characterKey, false) then
            Addon.ProfileViewer:RefreshIfViewing(characterKey)
        elseif not Addon.ProfileTransfer or not Addon.ProfileTransfer:IsRequestPending(characterKey, false) then
            Addon.ProfileViewer:ShowMSP(characterKey)
        end
    end
    return true
end

function MSP:GetProfile(characterKey)
    characterKey = StoredKey(self.profiles, characterKey)
    if not characterKey or not self:CanRequest(characterKey) then return nil end
    local entry = self.profiles[characterKey]
    if not entry then
        return nil
    end
    local profile = {}
    for _, field in ipairs(Addon.Constants.PROFILE_FIELD_ORDER) do
        profile[field] = entry.profile[field]
    end
    return {
        characterKey = entry.characterKey,
        profile = profile,
        receivedAt = entry.receivedAt,
        source = entry.source,
    }
end

function MSP:HasProfile(characterKey)
    return self:GetProfile(characterKey) ~= nil
end

function MSP:InitializeTransportDiagnostics()
    if self.transportHooks or not hooksecurefunc then return end
    self.transportHooks = true
    local function Record(api, prefix, channel, target)
        local access = Addon.ValueAccess
        if not access or not access:CanAccess(prefix, channel, target)
            or prefix ~= "MSP2" or channel ~= "WHISPER" then return end
        if Addon.DiscoveryDiagnostics then
            -- Secure post-hooks expose arguments, NOT the original API's result.
            Addon.DiscoveryDiagnostics:RecordWhisper(api, "MSP2", target,
                "shared-MSP2:API-bound", nil, "result-not-exposed-by-hook")
        end
    end
    for _, method in ipairs({"SendAddonMessage", "SendAddonMessageLogged"}) do
        if C_ChatInfo and type(C_ChatInfo[method]) == "function" then
            local api = "C_ChatInfo." .. method
            hooksecurefunc(C_ChatInfo, method, function(prefix, _, channel, target) Record(api, prefix, channel, target) end)
        end
    end
    if type(BNSendGameData) == "function" then
        hooksecurefunc("BNSendGameData", function(accountID, prefix)
            if Addon.ValueAccess:CanAccess(accountID, prefix) and prefix == "MSP2" and Addon.DiscoveryDiagnostics then
                Addon.DiscoveryDiagnostics:RecordWhisper("BNSendGameData", "MSP2", accountID,
                    "shared-MSP2:Battle.net-cache", nil, "result-not-exposed-by-hook")
            end
        end)
    end
end

function MSP:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    self:InitializeTransportDiagnostics()
    local library = self:GetLibrary()
    if not library then
        return
    end
    library.callback = library.callback or {}
    library.callback.received = library.callback.received or {}
    table.insert(library.callback.received, function(sender)
        self:OnReceived(sender)
    end)
end
