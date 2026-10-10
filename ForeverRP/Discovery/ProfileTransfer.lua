local Addon = ForeverRP

Addon.ProfileTransfer = {
    incoming = {},
    pendingRequests = {},
    outgoingResponses = {},
    outgoingResponseOrder = {},
    outgoingResponsePeers = {},
    responseCooldowns = {},
    messageCounter = 0,
    initialized = false,
}

local function Now()
    return GetTime and GetTime() or 0
end

local function TransferKey(characterKey, messageId)
    return string.lower(characterKey) .. "\031" .. messageId
end

local function EncodeValue(value)
    return (value:gsub("([%%&=|%c])", function(character)
        return string.format("%%%02X", string.byte(character))
    end))
end

local function DecodeValue(value)
    if value:gsub("%%[%x][%x]", ""):find("%%", 1, true) then
        return nil
    end
    return (value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

function Addon.ProfileTransfer:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    if C_Timer and C_Timer.NewTicker then
        self.cleanupTicker = C_Timer.NewTicker(10, function()
            self:CleanupExpired()
        end)
    end
end

local function PeerKey(characterKey)
    return string.lower(characterKey)
end

local function TransportRecipient(characterKey)
    return Addon.Presence.GetTransportRecipient and Addon.Presence:GetTransportRecipient(characterKey) or characterKey
end

function Addon.ProfileTransfer:CanRespondTo(characterKey, messageId)
    return Addon.Database:GetPrivacyMode() ~= "hidden"
        and Addon.Privacy:CanInteract(characterKey, "WHISPER", false)
        and (not Addon.ProfileAuthorization or Addon.ProfileAuthorization:CanSend(characterKey, messageId))
end

function Addon.ProfileTransfer:RemoveResponse(responseKey)
    local response = self.outgoingResponses[responseKey]
    if not response then
        return false
    end
    self.outgoingResponses[responseKey] = nil
    self.outgoingResponsePeers[PeerKey(response.characterKey)] = nil
    for index, queuedKey in ipairs(self.outgoingResponseOrder) do
        if queuedKey == responseKey then
            table.remove(self.outgoingResponseOrder, index)
            break
        end
    end
    return true
end

function Addon.ProfileTransfer:ScheduleResponsePump(delay)
    if self.responsePumpScheduled then
        return
    end
    self.responsePumpScheduled = true
    local function Pump()
        self.responsePumpScheduled = false
        self:ProcessResponseQueue()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, Pump)
    else
        Pump()
    end
end

function Addon.ProfileTransfer:ProcessResponseQueue()
    local responseKey = self.outgoingResponseOrder[1]
    local response = responseKey and self.outgoingResponses[responseKey]
    if not response then
        return false
    end
    if response.expiresAt and Now() >= response.expiresAt then
        self:RemoveResponse(responseKey)
        if Addon.ProfileAuthorization then Addon.ProfileAuthorization:Status(response.characterKey, response.messageId, "busy") end
        return self:ProcessResponseQueue()
    end
    if not self:CanRespondTo(response.characterKey, response.messageId) then
        self:RemoveResponse(responseKey)
        return self:ProcessResponseQueue()
    end

    local payload = Addon.Communication:Serialize(
        "PROFILE_DATA", response.messageId, response.nextChunk, #response.chunks, response.chunks[response.nextChunk]
    )
    local accepted = payload and Addon.Communication:SendPayload(payload, "WHISPER",
        response.transportRecipient, "PROFILE_DATA", response.characterKey)
    if accepted then
        if Addon.ProfileAuthorization then Addon.ProfileAuthorization:MarkServed(response.characterKey, response.transportRecipient) end
        response.nextChunk = response.nextChunk + 1
        response.retries = 0
        if response.nextChunk > #response.chunks then
            self.responseCooldowns[PeerKey(response.characterKey)] = Now()
            self:RemoveResponse(responseKey)
            if #self.outgoingResponseOrder > 0 then
                self:ScheduleResponsePump(Addon.Constants.PROFILE_RESPONSE_CHUNK_DELAY_SECONDS or 0.1)
            end
        else
            self:ScheduleResponsePump(Addon.Constants.PROFILE_RESPONSE_CHUNK_DELAY_SECONDS or 0.1)
        end
        return true
    end

    response.retries = response.retries + 1
    if response.retries > (Addon.Constants.PROFILE_RESPONSE_MAX_RETRIES or 2) then
        Addon:Debug("Profile response cancelled after send failure:", response.characterKey)
        self:RemoveResponse(responseKey)
        if #self.outgoingResponseOrder > 0 then
            self:ScheduleResponsePump(0)
        end
        return false
    end
    self:ScheduleResponsePump(Addon.Constants.PROFILE_RESPONSE_RETRY_SECONDS or 1)
    return false
end

function Addon.ProfileTransfer:CreateMessageId()
    self.messageCounter = (self.messageCounter % 9999) + 1
    return string.format("P%d-%d", math.floor(Now() * 1000) % 1000000000, self.messageCounter)
end

function Addon.ProfileTransfer:SerializeProfile(profile)
    local sanitized = Addon.Profile:SanitizeRemoteProfile(profile)
    if not sanitized then
        return nil, "invalid profile"
    end
    -- Older ForeverRP peers only understand IC/OOC/AFK/DND in full profiles.
    -- The optional directory packet carries the more specific LF RP state.
    if sanitized.status == "LFRP" then sanitized.status = "IC" end

    local fields = {}
    for _, field in ipairs(Addon.Constants.PROFILE_FIELD_ORDER) do
        fields[#fields + 1] = field .. "=" .. EncodeValue(sanitized[field])
    end
    local encoded = table.concat(fields, "&")
    if #encoded > Addon.Constants.MAX_PROFILE_ENCODED_BYTES then
        return nil, "oversized profile"
    end
    return encoded
end

function Addon.ProfileTransfer:DeserializeProfile(encoded)
    if type(encoded) ~= "string" or #encoded == 0
        or #encoded > Addon.Constants.MAX_PROFILE_ENCODED_BYTES then
        return nil, "profile outside bounds"
    end

    local expected = {}
    for _, field in ipairs(Addon.Constants.PROFILE_FIELD_ORDER) do
        expected[field] = true
    end

    local profile = {}
    for field in (encoded .. "&"):gmatch("([^&]*)&") do
        local key, value = field:match("^([%a][%w]*)=(.*)$")
        if not key or not expected[key] or profile[key] ~= nil then
            return nil, "malformed profile schema"
        end
        value = DecodeValue(value)
        if value == nil then
            return nil, "malformed profile encoding"
        end
        profile[key] = value
    end

    for _, field in ipairs(Addon.Constants.PROFILE_FIELD_ORDER) do
        if profile[field] == nil then
            return nil, "incomplete profile schema"
        end
    end
    return Addon.Profile:SanitizeRemoteProfile(profile)
end

function Addon.ProfileTransfer:BuildChunks(encoded)
    local chunks = {}
    for index = 1, #encoded, Addon.Constants.PROFILE_CHUNK_BYTES do
        chunks[#chunks + 1] = encoded:sub(index, index + Addon.Constants.PROFILE_CHUNK_BYTES - 1)
    end
    if #chunks == 0 or #chunks > Addon.Constants.MAX_PROFILE_CHUNKS then
        return nil
    end
    return chunks
end

function Addon.ProfileTransfer:SendProfile(characterKey, messageId, recipient)
    if not self:CanRespondTo(characterKey, messageId) then
        return false, "privacy"
    end
    local peer = PeerKey(characterKey)
    local responseKey = TransferKey(characterKey, messageId)
    if self.outgoingResponses[responseKey] or self.outgoingResponsePeers[peer] then
        return false, "duplicate"
    end
    local cooldown = self.responseCooldowns[peer]
    if cooldown and Now() - cooldown < (Addon.Constants.PROFILE_RESPONSE_PEER_COOLDOWN_SECONDS or 10) then
        return false, "cooldown"
    end
    if #self.outgoingResponseOrder >= (Addon.Constants.PROFILE_RESPONSE_QUEUE_MAX or 8) then
        return false, "busy"
    end
    local encoded = self:SerializeProfile(Addon.Profile:Get())
    local chunks = encoded and self:BuildChunks(encoded)
    if not chunks then
        return false, "profile"
    end
    -- Admit only work that can complete inside the existing client's timeout.
    local queuedChunks = #chunks
    for _, queued in pairs(self.outgoingResponses) do
        queuedChunks = queuedChunks + #queued.chunks - queued.nextChunk + 1
    end
    local delay = Addon.Constants.PROFILE_RESPONSE_CHUNK_DELAY_SECONDS or 0.1
    if queuedChunks * delay > Addon.Constants.PROFILE_TRANSFER_TIMEOUT - 3 then return false, "busy" end

    self.outgoingResponses[responseKey] = {
        characterKey = characterKey,
        transportRecipient = recipient or TransportRecipient(characterKey),
        messageId = messageId,
        chunks = chunks,
        nextChunk = 1,
        retries = 0,
        expiresAt = Now() + Addon.Constants.PROFILE_TRANSFER_TIMEOUT - 1,
    }
    self.outgoingResponseOrder[#self.outgoingResponseOrder + 1] = responseKey
    self.outgoingResponsePeers[peer] = responseKey
    self.responseCooldowns[peer] = Now()
    self:ScheduleResponsePump(0)
    return true
end

function Addon.ProfileTransfer:Request(value)
    local characterKey = Addon.Presence:ResolveKnownKey(value, false)
    if not characterKey or Addon.Presence:IsSelf(characterKey) then
        return false, "unknown"
    end
    if self:IsRequestPending(characterKey, false) then
        return false, "pending"
    end
    local pendingCount = 0
    for _ in pairs(self.pendingRequests) do pendingCount = pendingCount + 1 end
    if pendingCount >= (Addon.Constants.PROFILE_MAX_PENDING_REQUESTS or 20) then
        return false, "busy"
    end

    local messageId = self:CreateMessageId()
    local payload = Addon.Communication:Serialize("PROFILE_REQUEST", messageId)
    if not payload or not Addon.Communication:SendPayload(payload, "WHISPER",
        TransportRecipient(characterKey), "PROFILE_REQUEST", characterKey) then
        return false, "send"
    end
    self.pendingRequests[TransferKey(characterKey, messageId)] = {
        createdAt = Now(),
        simulated = false,
    }
    return true, characterKey
end

function Addon.ProfileTransfer:HandleRequest(packet, sender, characterKey, simulated)
    if simulated or Addon.Presence:IsSelf(characterKey) then
        return false
    end
    if Addon.ProfileAuthorization then
        return Addon.ProfileAuthorization:HandleRequest(packet, sender, characterKey)
    end
    return self:SendProfile(characterKey, packet.messageId, sender)
end

function Addon.ProfileTransfer:HandleStatus(packet, characterKey)
    if packet.status == "revoked" then
        Addon.RemoteProfiles:ClearProfile(characterKey)
        for key in pairs(self.pendingRequests) do
            if key:sub(1, #characterKey + 1) == string.lower(characterKey) .. "\031" then
                self.pendingRequests[key], self.incoming[key] = nil, nil
            end
        end
    else
        local key = TransferKey(characterKey, packet.messageId)
        local request = self.pendingRequests[key]
        if not request or request.simulated then return false end
        if packet.status == "denied" or packet.status == "busy" then
            self.pendingRequests[key], self.incoming[key] = nil, nil
            Addon.RemoteProfiles:ClearProfile(characterKey)
            Addon:Print(packet.status == "busy" and "Profile transfer is busy; try again shortly." or "Profile access was denied.")
        elseif packet.status == "pending" then
            if not request.approvalNotice then
                request.approvalNotice = true
                request.createdAt = Now() + 30 -- one bounded extension for owner approval
                Addon:Print("Profile access is waiting for the owner's approval.")
            end
        end
    end
    if Addon.NearbyUI then Addon.NearbyUI:Refresh() end
    if Addon.ConnectionsUI then Addon.ConnectionsUI:Refresh() end
    if Addon.ActivityUI then Addon.ActivityUI:Refresh() end
    return true
end

function Addon.ProfileTransfer:CleanupExpired()
    local cutoff = Now() - Addon.Constants.PROFILE_TRANSFER_TIMEOUT
    local expired = false
    for transferKey, transfer in pairs(self.incoming) do
        if transfer.createdAt < cutoff then
            self.incoming[transferKey] = nil
        end
    end
    for transferKey, request in pairs(self.pendingRequests) do
        if request.createdAt < cutoff then
            self.pendingRequests[transferKey] = nil
            expired = true
        end
    end
    if expired then
        if Addon.NearbyUI then Addon.NearbyUI:Refresh() end
        if Addon.ConnectionsUI then Addon.ConnectionsUI:Refresh() end
        if Addon.ActivityUI then Addon.ActivityUI:Refresh() end
    end
end

function Addon.ProfileTransfer:IsRequestPending(characterKey, simulated)
    self:CleanupExpired()
    local target = string.lower(characterKey)
    for transferKey, request in pairs(self.pendingRequests) do
        if transferKey:sub(1, #target + 1) == target .. "\031"
            and request.simulated == (simulated == true) then
            return true
        end
    end
    return false
end

function Addon.ProfileTransfer:ResetForPrivacyChange()
    self.incoming = {}
    self.pendingRequests = {}
    self.outgoingResponses = {}
    self.outgoingResponseOrder = {}
    self.outgoingResponsePeers = {}
    if Addon.NearbyUI then
        Addon.NearbyUI:Refresh()
    end
end

function Addon.ProfileTransfer:CancelDisallowedResponses()
    local cancelled = 0
    for responseKey, response in pairs(self.outgoingResponses) do
        if not self:CanRespondTo(response.characterKey, response.messageId) then
            if self:RemoveResponse(responseKey) then
                cancelled = cancelled + 1
            end
        end
    end
    return cancelled
end

function Addon.ProfileTransfer:HandleChunk(packet, characterKey, simulated)
    self:CleanupExpired()
    local transferKey = TransferKey(characterKey, packet.messageId)
    local request = self.pendingRequests[transferKey]
    if not request or request.simulated ~= (simulated == true) then
        return false
    end
    local transfer = self.incoming[transferKey]
    if not transfer then
        transfer = {
            characterKey = characterKey,
            totalChunks = packet.totalChunks,
            chunks = {},
            receivedChunks = 0,
            receivedBytes = 0,
            createdAt = Now(),
            addonVersion = packet.addonVersion,
            protocolVersion = packet.protocolVersion,
            simulated = simulated == true,
        }
        self.incoming[transferKey] = transfer
    elseif transfer.totalChunks ~= packet.totalChunks or transfer.simulated ~= (simulated == true) then
        self.incoming[transferKey] = nil
        return false
    end

    local existing = transfer.chunks[packet.chunkIndex]
    if existing then
        if existing ~= packet.chunk then
            self.incoming[transferKey] = nil
            return false
        end
        return true
    end

    transfer.receivedBytes = transfer.receivedBytes + #packet.chunk
    if transfer.receivedBytes > Addon.Constants.MAX_PROFILE_ENCODED_BYTES then
        self.incoming[transferKey] = nil
        return false
    end
    transfer.chunks[packet.chunkIndex] = packet.chunk
    transfer.receivedChunks = transfer.receivedChunks + 1
    if transfer.receivedChunks < transfer.totalChunks then
        return true
    end

    local encoded = table.concat(transfer.chunks, "")
    self.incoming[transferKey] = nil
    self.pendingRequests[transferKey] = nil
    local profile = self:DeserializeProfile(encoded)
    if not profile then
        Addon:Debug("Remote profile rejected from", characterKey)
        return false
    end

    local stored = Addon.RemoteProfiles:StoreProfile(characterKey, profile, transfer)
    if stored and Addon.ProfileViewer then
        Addon.ProfileViewer:ShowRemote(characterKey, simulated == true)
    end
    return stored
end

function Addon.ProfileTransfer:ClearSimulated()
    for transferKey, transfer in pairs(self.incoming) do
        if transfer.simulated then
            self.incoming[transferKey] = nil
        end
    end
    for transferKey, request in pairs(self.pendingRequests) do
        if request.simulated then
            self.pendingRequests[transferKey] = nil
        end
    end
    Addon.RemoteProfiles:ClearSimulated()
    if Addon.ProfileViewer then
        Addon.ProfileViewer:RefreshIfViewing(Addon.Communication:GetSimulatedCharacterKey())
    end
end

function Addon.ProfileTransfer:GetSimulatedProfile()
    return {
        rpName = "Aveline Starfall",
        title = "Wayfarer of the Long Road",
        race = "Human",
        class = "Mage",
        age = "32",
        pronouns = "she/her",
        status = "IC",
        currently = "Sketching constellations beside a quiet campfire.",
        atAGlance = "Silver-streaked hair; ink-stained gloves; a weathered blue journal.",
        description = "A composed traveler with an observant gaze and a patient manner.",
        history = "Aveline studies forgotten roads and records the stories found along them.",
        oocNotes = "Simulator profile used for ForeverRP transfer validation.",
    }
end

function Addon.ProfileTransfer:InjectSimulated(encoded, mode)
    local characterKey = Addon.Communication:GetSimulatedCharacterKey()
    if not Addon.Presence:IsConfirmed(characterKey, true) then
        return false, "presence"
    end
    local messageId = self:CreateMessageId()
    self.pendingRequests[TransferKey(characterKey, messageId)] = {
        createdAt = Now(),
        simulated = true,
    }
    if mode == "oversized" then
        local payload = table.concat({
            "PROFILE_DATA", tostring(Addon.Constants.PROTOCOL_VERSION), Addon.Constants.ADDON_VERSION,
            messageId, "1", tostring(Addon.Constants.MAX_PROFILE_CHUNKS + 1), "x",
        }, "|")
        Addon.Communication:HandleIncoming(
            Addon.Constants.COMMUNICATION_PREFIX, payload, "WHISPER", characterKey, true
        )
        return true
    end

    local chunks = self:BuildChunks(encoded)
    if not chunks then
        return false, "encoding"
    end
    for index, chunk in ipairs(chunks) do
        local payload = Addon.Communication:Serialize("PROFILE_DATA", messageId, index, #chunks, chunk)
        Addon.Communication:HandleIncoming(
            Addon.Constants.COMMUNICATION_PREFIX, payload, "WHISPER", characterKey, true
        )
    end
    return true
end

function Addon.ProfileTransfer:SimulateProfile(mode)
    if mode == "clear" then
        self:ClearSimulated()
        return true, "cleared"
    end

    local encoded = self:SerializeProfile(self:GetSimulatedProfile())
    if mode == "malformed" then
        encoded = "rpName=Malformed&unexpected=value"
    end
    local injected, reason = self:InjectSimulated(encoded, mode)
    if not injected then
        return false, reason
    end

    local characterKey = Addon.Communication:GetSimulatedCharacterKey()
    if mode == "valid" and Addon.RemoteProfiles:HasProfile(characterKey, true) then
        Addon.ProfileViewer:ShowRemote(characterKey, true)
    elseif mode == "valid" then
        return false, "rejected"
    end
    return true, mode
end
