local Addon = ForeverRP

local MESSAGE_TYPES = {
    HELLO = true,
    ACK = true,
    PROFILE_REQUEST = true,
    PROFILE_DATA = true,
}

local SIMULATED_CHARACTER_KEY = "ForeverRPTester-TestRealm"
local MALFORMED_CHARACTER_KEY = "ForeverRPMalformed-TestRealm"
local INCOMPATIBLE_CHARACTER_KEY = "ForeverRPIncompatible-TestRealm"

local function EnumValue(enumName, field, fallback)
    local values = Enum and Enum[enumName]
    local value = values and values[field]
    return type(value) == "number" and value or fallback
end

local function IsSuccess(result, enumName)
    return result == true or (type(result) == "number"
        and result == EnumValue(enumName, "Success", 0))
end

local function RegisterPrefix(prefix)
    local register = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
    local apiName = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix
        and "C_ChatInfo.RegisterAddonMessagePrefix" or (register and "RegisterAddonMessagePrefix")
    local result
    if register then
        result = register(prefix)
    end

    -- The query also recognizes prefixes registered before our initialization.
    local isRegistered = C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered
        or IsAddonMessagePrefixRegistered
    if isRegistered then
        return isRegistered(prefix) == true, apiName or "IsAddonMessagePrefixRegistered"
    end
    return IsSuccess(result, "RegisterAddonMessagePrefixResult"), apiName
end

local function SendAddonPacket(prefix, payload, channel, target)
    local send = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if not send then
        return false, "unavailable"
    end
    local result = send(prefix, payload, channel, target)
    if IsSuccess(result, "SendAddonMessageResult") then
        return true, "accepted"
    end
    if type(result) == "number" and (result == EnumValue("SendAddonMessageResult", "AddonMessageThrottle", 3)
        or result == EnumValue("SendAddonMessageResult", "ChannelThrottle", 8)) then
        return false, "throttled", result
    end
    return false, "failed", result
end

local function Now()
    return GetTime and GetTime() or 0
end

local function ChannelSignature(channels)
    return table.concat(channels, "|")
end

local function ChannelSet(channels)
    local results = {}
    for _, channel in ipairs(channels) do
        results[channel] = true
    end
    return results
end

Addon.Communication = {
    initialized = false,
    initialHelloSent = false,
    initialRetryAttempts = 0,
    renewalRetryAttempts = 0,
}

function Addon.Communication:Initialize()
    if self.initialized then
        return self.prefixRegistered
    end

    local registered, apiName = RegisterPrefix(Addon.Constants.COMMUNICATION_PREFIX)
    self.prefixRegistered = registered == true
    self.registrationAPI = apiName
    self.initialized = true
    if self.prefixRegistered then
        Addon:Debug("Addon prefix registered via", apiName)
    else
        Addon:Debug("Addon prefix registration unavailable or failed")
    end
    return self.prefixRegistered
end

function Addon.Communication:CanBroadcast()
    return self.prefixRegistered == true
end

function Addon.Communication:Serialize(messageType, ...)
    if not MESSAGE_TYPES[messageType] then
        return nil
    end
    local fields = {
        messageType,
        tostring(Addon.Constants.PROTOCOL_VERSION),
        Addon.Constants.ADDON_VERSION,
    }
    for index = 1, select("#", ...) do
        fields[#fields + 1] = tostring(select(index, ...))
    end
    local payload = table.concat(fields, "|")
    if #payload > Addon.Constants.MAX_MESSAGE_BYTES then
        return nil
    end
    return payload
end

function Addon.Communication:Parse(payload)
    if type(payload) ~= "string" or #payload == 0 then
        return nil, "invalid payload"
    end
    if #payload > Addon.Constants.MAX_MESSAGE_BYTES then
        return nil, "oversized payload"
    end

    local messageType, protocolText, addonVersion, remainder = payload:match("^([A-Z_]+)|(%d+)|([%w%.%-]+)|(.*)$")
    if not messageType then
        messageType, protocolText, addonVersion = payload:match("^([A-Z_]+)|(%d+)|([%w%.%-]+)$")
        remainder = ""
    end
    if not messageType or not MESSAGE_TYPES[messageType] then
        return nil, "unknown message"
    end

    local protocolVersion = tonumber(protocolText)
    if protocolVersion ~= Addon.Constants.PROTOCOL_VERSION then
        return nil, "unsupported protocol"
    end
    if #addonVersion > 32 then
        return nil, "invalid addon version"
    end

    local packet = {
        messageType = messageType,
        protocolVersion = protocolVersion,
        addonVersion = addonVersion,
    }
    if messageType == "HELLO" or messageType == "ACK" then
        if remainder ~= "" then
            return nil, "unexpected message fields"
        end
        return packet
    end

    if messageType == "PROFILE_REQUEST" then
        if not remainder:match("^[%w%-]+$") or #remainder > 24 then
            return nil, "invalid request ID"
        end
        packet.messageId = remainder
        return packet
    end

    local messageId, chunkIndexText, totalChunksText, chunk = remainder:match("^([%w%-]+)|(%d+)|(%d+)|(.*)$")
    local chunkIndex = tonumber(chunkIndexText)
    local totalChunks = tonumber(totalChunksText)
    if not messageId or #messageId > 24 or not chunkIndex or not totalChunks then
        return nil, "invalid profile chunk"
    end
    if totalChunks < 1 or totalChunks > Addon.Constants.MAX_PROFILE_CHUNKS
        or chunkIndex < 1 or chunkIndex > totalChunks
        or #chunk > Addon.Constants.PROFILE_CHUNK_BYTES then
        return nil, "profile chunk outside bounds"
    end
    packet.messageId = messageId
    packet.chunkIndex = chunkIndex
    packet.totalChunks = totalChunks
    packet.chunk = chunk
    return packet
end

function Addon.Communication:GetBroadcastChannels()
    local channels = {}
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        channels[#channels + 1] = "INSTANCE_CHAT"
    elseif IsInRaid and IsInRaid() then
        channels[#channels + 1] = "RAID"
    elseif IsInGroup and IsInGroup() then
        channels[#channels + 1] = "PARTY"
    end
    if IsInGuild and IsInGuild() then
        channels[#channels + 1] = "GUILD"
    end

    local allowed = {}
    for _, channel in ipairs(channels) do
        if Addon.Privacy:CanBroadcast(channel) then
            allowed[#allowed + 1] = channel
        end
    end
    return allowed
end

function Addon.Communication:SelectBroadcastChannel()
    return self:GetBroadcastChannels()[1]
end

function Addon.Communication:Send(messageType, channel, target)
    if not self:CanBroadcast() or type(channel) ~= "string" then
        return false
    end
    local payload = self:Serialize(messageType)
    if not payload then
        return false
    end

    return self:SendPayload(payload, channel, target, messageType)
end

function Addon.Communication:SendPayload(payload, channel, target, debugLabel)
    if not self:CanBroadcast() or type(payload) ~= "string"
        or #payload == 0 or #payload > Addon.Constants.MAX_MESSAGE_BYTES then
        return false
    end
    if target then
        local characterKey = Addon.Presence:NormalizeCharacterKey(target)
        if not characterKey or not Addon.Privacy:CanInteract(characterKey, channel, false) then
            Addon:Debug(debugLabel or "Packet", "suppressed by privacy")
            return false
        end
    elseif not Addon.Privacy:CanBroadcast(channel) then
        Addon:Debug(debugLabel or "Packet", "broadcast suppressed by privacy")
        return false
    end
    -- Acceptance by the client is not confirmation of delivery to another player.
    local accepted, reason, result = SendAddonPacket(Addon.Constants.COMMUNICATION_PREFIX, payload, channel, target)
    if accepted then
        Addon:Debug(debugLabel or "Packet", "accepted for enqueueing via", channel)
        return true, "accepted"
    end
    Addon:Debug(debugLabel or "Packet", "send", reason, "via", channel, "result", tostring(result))
    return false, reason
end

function Addon.Communication:SendHello(channels)
    channels = channels or self:GetBroadcastChannels()
    if #channels == 0 then
        return false, nil, 0
    end

    local sent, firstChannel, sentCount = false, nil, 0
    for _, channel in ipairs(channels) do
        local accepted = self:Send("HELLO", channel)
        if accepted then
            sent = true
            firstChannel = firstChannel or channel
            sentCount = sentCount + 1
        end
    end
    if sent then
        self.lastHelloAt = Now()
        self.initialHelloSent = true
        self.initialRetryAttempts = 0
        self.renewalRetryAttempts = 0
        local activeChannels = self:GetBroadcastChannels()
        self.broadcastChannelSignature = ChannelSignature(activeChannels)
        self.broadcastChannels = ChannelSet(activeChannels)
    end
    return sent, firstChannel or channels[1], sentCount
end

function Addon.Communication:SendInitialHello(channels)
    if self.initialHelloSent then
        return false
    end
    channels = channels or self:GetBroadcastChannels()
    if #channels == 0 or self.initialRetryAttempts >= Addon.Constants.PRESENCE_MAX_RETRIES then
        return false
    end
    self.initialRetryAttempts = self.initialRetryAttempts + 1
    self.lastInitialAttemptAt = Now()
    local sent, channel, sentCount = self:SendHello(channels)
    if sent then
        self.initialHelloSent = true
        self.initialRetryAttempts = 0
    end
    return sent, channel, sentCount
end

function Addon.Communication:OnBroadcastContextChanged()
    local channels = self:GetBroadcastChannels()
    local signature = ChannelSignature(channels)
    if signature == self.broadcastChannelSignature then
        return false
    end

    local previous = self.broadcastChannels or {}
    self.broadcastChannelSignature = signature
    self.broadcastChannels = ChannelSet(channels)
    self.initialRetryAttempts = 0
    self.renewalRetryAttempts = 0

    local added = {}
    for _, channel in ipairs(channels) do
        if not previous[channel] then
            added[#added + 1] = channel
        end
    end
    if #added == 0 then
        return false
    end
    if self.initialHelloSent then
        return self:SendHello(added)
    end
    return self:SendInitialHello(added)
end

function Addon.Communication:TickPresenceLifecycle()
    if Addon.Database:GetPrivacyMode() == "hidden" then
        return false
    end

    local now = Now()
    local channels = self:GetBroadcastChannels()
    if #channels == 0 then
        return false
    end

    if not self.initialHelloSent then
        if (not self.lastInitialAttemptAt or now - self.lastInitialAttemptAt >= Addon.Constants.PRESENCE_RETRY_SECONDS)
            and self.initialRetryAttempts < Addon.Constants.PRESENCE_MAX_RETRIES then
            return self:SendInitialHello(channels)
        end
        return false
    end

    if not self.lastHelloAt or now - self.lastHelloAt < Addon.Constants.PRESENCE_RENEWAL_SECONDS then
        return false
    end
    if self.lastRenewalAttemptAt and now - self.lastRenewalAttemptAt < Addon.Constants.PRESENCE_RETRY_SECONDS then
        return false
    end
    if self.renewalRetryAttempts >= Addon.Constants.PRESENCE_MAX_RETRIES then
        return false
    end

    self.lastRenewalAttemptAt = now
    local sent, channel, sentCount = self:SendHello(channels)
    if not sent then
        self.renewalRetryAttempts = self.renewalRetryAttempts + 1
    end
    return sent, channel, sentCount
end

function Addon.Communication:StartPresenceLifecycle()
    if self.presenceTicker or not C_Timer or not C_Timer.NewTicker then
        return
    end
    self.presenceTicker = C_Timer.NewTicker(Addon.Constants.PRESENCE_LIFECYCLE_TICK_SECONDS, function()
        self:TickPresenceLifecycle()
    end)
end

function Addon.Communication:OnAddonMessage(prefix, payload, channel, sender)
    self:HandleIncoming(prefix, payload, channel, sender, false)
end

function Addon.Communication:HandleIncoming(prefix, payload, channel, sender, simulated)
    if prefix ~= Addon.Constants.COMMUNICATION_PREFIX then
        return
    end

    local characterKey = Addon.Presence:NormalizeCharacterKey(sender)
    if not characterKey then
        Addon:Debug("Malformed packet ignored: invalid sender")
        return
    end

    local packet, reason = self:Parse(payload)
    if not packet then
        if reason == "unsupported protocol" then
            Addon:Debug(Addon:GetText("UNSUPPORTED_PROTOCOL"))
        else
            Addon:Debug("Malformed packet ignored:", reason)
        end
        return
    end

    if Addon.Presence:IsSelf(characterKey) then
        return
    end

    if not Addon.Privacy:CanInteract(characterKey, channel, simulated == true) then
        Addon:Debug(packet.messageType, "ignored by privacy policy", characterKey)
        return
    end

    local presenceMessage = packet.messageType == "HELLO" or packet.messageType == "ACK"
    if not presenceMessage and not Addon.Presence:IsConfirmed(characterKey, simulated == true) then
        Addon:Debug(packet.messageType, "ignored from unconfirmed sender", characterKey)
        return
    end

    packet.simulated = simulated == true
    Addon.Presence:Update(characterKey, packet)
    Addon:Debug(packet.messageType, "received from", characterKey, "via", channel or "unknown")

    if packet.messageType == "HELLO" then
        if simulated then
            Addon:Debug("ACK response exercised for simulated HELLO; transport suppressed")
        else
            self:Send("ACK", "WHISPER", sender)
        end
    elseif packet.messageType == "PROFILE_REQUEST" then
        Addon.ProfileTransfer:HandleRequest(packet, sender, characterKey, simulated == true)
    elseif packet.messageType == "PROFILE_DATA" then
        Addon.ProfileTransfer:HandleChunk(packet, characterKey, simulated == true)
    end
end

function Addon.Communication:GetSimulatedCharacterKey()
    return SIMULATED_CHARACTER_KEY
end

function Addon.Communication:Simulate(action)
    local connectionMode = action:match("^connection%s+(%S+)$")
    if connectionMode then
        local characterKey = self:GetSimulatedCharacterKey()
        if connectionMode == "normal" or connectionMode == "clear" then
            Addon.Connections:Forget(characterKey, true)
        elseif connectionMode == "remembered" then
            Addon.Connections:Remember(characterKey, true)
            Addon.Connections:SetFavorite(characterKey, false, true)
        elseif connectionMode == "favorite" then
            Addon.Connections:SetFavorite(characterKey, true, true)
        else
            Addon:Print(Addon:GetText("SIM_HELP"))
            return
        end
        Addon.Notifications:ResetCooldown(characterKey)
        if Addon.NearbyPlayers:IsNearby(characterKey, true) then
            Addon.NearbyPlayers:Remove(characterKey, "simulation connection reset")
            Addon.NearbyPlayers:Reevaluate(characterKey)
        end
        Addon:Print(string.format(Addon:GetText("SIM_CONNECTION_SET"), connectionMode))
        return
    end

    local privacyMode, relationship = action:match("^privacy%s+(%S+)%s*(%S*)$")
    if privacyMode then
        if privacyMode ~= "visible" and privacyMode ~= "restricted" and privacyMode ~= "hidden" then
            Addon:Print(Addon:GetText("SIM_HELP"))
            return
        end
        relationship = relationship ~= "" and relationship or "unknown"
        if not Addon.Privacy:SetSimulatedRelationship(relationship) then
            Addon:Print(Addon:GetText("SIM_HELP"))
            return
        end
        Addon.Database:SetPrivacyMode(privacyMode, true)
        Addon.UI:RefreshSettings()
        Addon:Print(string.format(Addon:GetText("SIM_PRIVACY_SET"),
            Addon:GetText("PRIVACY_" .. string.upper(privacyMode)), relationship))
        return
    end

    local profileMode = action:match("^profile%s*(.*)$")
    if profileMode ~= nil then
        profileMode = profileMode == "" and "valid" or profileMode
        if profileMode ~= "valid" and profileMode ~= "malformed"
            and profileMode ~= "oversized" and profileMode ~= "clear" then
            Addon:Print(Addon:GetText("SIM_HELP"))
            return
        end
        local succeeded, result = Addon.ProfileTransfer:SimulateProfile(profileMode)
        if not succeeded and result == "presence" then
            Addon:Print(Addon:GetText("SIM_PROFILE_REQUIRES_PRESENCE"))
        elseif not succeeded then
            Addon:Print(Addon:GetText("SIM_PROFILE_BLOCKED"))
        elseif profileMode == "valid" then
            Addon:Print(Addon:GetText("SIM_PROFILE_STORED"))
        elseif profileMode == "clear" then
            Addon:Print(Addon:GetText("SIM_PROFILE_CLEARED"))
        else
            Addon:Print(string.format(Addon:GetText("SIM_PROFILE_REJECTED"), string.upper(profileMode)))
        end
        return
    end

    if action == "hello" or action == "ack" then
        local messageType = action == "hello" and "HELLO" or "ACK"
        self:HandleIncoming(
            Addon.Constants.COMMUNICATION_PREFIX,
            self:Serialize(messageType),
            "WHISPER",
            SIMULATED_CHARACTER_KEY,
            true
        )
        Addon:Print(string.format(Addon:GetText("SIM_PACKET_INJECTED"), messageType))
        return
    end

    if action == "malformed" then
        local packets = {
            "garbage",
            "HELLO",
            "HELLO|banana",
            "UNKNOWN|1|0.0.0",
            "HELLO|1|" .. string.rep("A", Addon.Constants.MAX_MESSAGE_BYTES),
        }
        for _, payload in ipairs(packets) do
            self:HandleIncoming(
                Addon.Constants.COMMUNICATION_PREFIX,
                payload,
                "WHISPER",
                MALFORMED_CHARACTER_KEY,
                true
            )
        end
        Addon:Print(Addon:GetText("SIM_MALFORMED_COMPLETE"))
        return
    end

    if action == "incompatible" then
        self:HandleIncoming(
            Addon.Constants.COMMUNICATION_PREFIX,
            "HELLO|999|0.0.0",
            "WHISPER",
            INCOMPATIBLE_CHARACTER_KEY,
            true
        )
        Addon:Print(Addon:GetText("SIM_INCOMPATIBLE_COMPLETE"))
        return
    end

    if action == "clear" then
        Addon.PlayerDetection:ClearSimulated()
        Addon.Range:ClearSimulated()
        local removed = Addon.Presence:ClearSimulated()
        Addon.Notifications:ClearSimulatedState(SIMULATED_CHARACTER_KEY)
        Addon.Notifications:SetSimulationEnabled(false)
        Addon.ProfileTransfer:ClearSimulated()
        Addon.Connections:ClearSimulated()
        Addon.NearbyPlayers:ReevaluateAll()
        Addon:Print(string.format(Addon:GetText("SIM_CLEARED"), removed))
        return
    end

    local notifyValue = action:match("^notify%s+(%S+)$")
    if notifyValue then
        if notifyValue == "on" then
            Addon.Notifications:SetSimulationEnabled(true)
        elseif notifyValue == "off" then
            Addon.Notifications:SetSimulationEnabled(false)
        elseif notifyValue == "reset" then
            Addon.Notifications:ResetCooldown(SIMULATED_CHARACTER_KEY)
            Addon:Print(Addon:GetText("SIM_NOTIFY_RESET"))
            return
        elseif notifyValue ~= "status" then
            Addon:Print(Addon:GetText("SIM_HELP"))
            return
        end
        local enabled = Addon.Notifications:IsSimulationEnabled()
        Addon:Print(string.format(Addon:GetText("SIM_NOTIFY_MODE"), enabled and Addon:GetText("YES") or Addon:GetText("NO")))
        return
    end

    local rangeValue = action:match("^range%s+(%S+)$")
    if rangeValue then
        local characterKey = self:GetSimulatedCharacterKey()
        local changed, state = Addon.Range:SetSimulatedState(characterKey, rangeValue)
        if changed then
            Addon.PlayerDetection:SetSimulatedCharacter(characterKey)
            Addon.NearbyPlayers:Reevaluate(characterKey)
            Addon:Print(string.format(Addon:GetText("SIM_RANGE_SET"), state))
        else
            Addon:Print(Addon:GetText("SIM_HELP"))
        end
        return
    end

    if action == "status" then
        local player = Addon.Presence:Get(SIMULATED_CHARACTER_KEY, true)
        Addon:Print(Addon:GetText("SIM_STATUS_HEADER"))
        Addon:Print(string.format(Addon:GetText("SIM_STATUS_PLAYER"), SIMULATED_CHARACTER_KEY))
        Addon:Print(string.format(Addon:GetText("SIM_STATUS_CONFIRMED"), player and Addon:GetText("YES") or Addon:GetText("NO")))
        Addon:Print(string.format(Addon:GetText("SIM_STATUS_PROTOCOL"), player and player.protocolVersion or "-"))
        Addon:Print(string.format(Addon:GetText("SIM_STATUS_VERSION"), player and player.addonVersion or "-"))
        local lastSeen = player and string.format("%.1f", player.lastSeen) or "-"
        Addon:Print(string.format(Addon:GetText("SIM_STATUS_LAST_SEEN"), lastSeen))
        local rangeState = Addon.Range:GetSimulatedState(SIMULATED_CHARACTER_KEY) or "-"
        Addon:Print(string.format(Addon:GetText("SIM_STATUS_RANGE"), rangeState))
        local nearby = Addon.NearbyPlayers:IsNearby(SIMULATED_CHARACTER_KEY, true)
        Addon:Print(string.format(Addon:GetText("SIM_STATUS_NEARBY"), nearby and Addon:GetText("YES") or Addon:GetText("NO")))
        local notifyMode = Addon.Notifications:IsSimulationEnabled()
        Addon:Print(string.format(Addon:GetText("SIM_NOTIFY_MODE"), notifyMode and Addon:GetText("YES") or Addon:GetText("NO")))
        Addon:Print(string.format(Addon:GetText("SIM_PRIVACY_STATUS"),
            Addon:GetText("PRIVACY_" .. string.upper(Addon.Database:GetPrivacyMode())),
            Addon.Privacy.simulatedRelationship))
        local connectionLevel = Addon.Connections:GetLevel(SIMULATED_CHARACTER_KEY, true)
        Addon:Print(string.format(Addon:GetText("SIM_CONNECTION_STATUS"), connectionLevel))
        local connection = Addon.Connections:Get(SIMULATED_CHARACTER_KEY, true)
        Addon:Print(string.format(Addon:GetText("SIM_CONNECTION_ENCOUNTER"),
            connection and connection.lastEncountered or "-"))
        return
    end

    Addon:Print(Addon:GetText("SIM_HELP"))
end
