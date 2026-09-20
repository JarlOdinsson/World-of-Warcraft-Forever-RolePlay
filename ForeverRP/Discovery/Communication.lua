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

local function RegisterPrefix(prefix)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        return C_ChatInfo.RegisterAddonMessagePrefix(prefix), "C_ChatInfo.RegisterAddonMessagePrefix"
    end
    if RegisterAddonMessagePrefix then
        return RegisterAddonMessagePrefix(prefix), "RegisterAddonMessagePrefix"
    end
    return false, nil
end

local function SendAddonPacket(prefix, payload, channel, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        return C_ChatInfo.SendAddonMessage(prefix, payload, channel, target)
    end
    if SendAddonMessage then
        return SendAddonMessage(prefix, payload, channel, target)
    end
    return false
end

Addon.Communication = {
    initialized = false,
    initialHelloSent = false,
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

function Addon.Communication:SelectBroadcastChannel()
    if Addon.Database:GetPrivacyMode() == "restricted" then
        if IsInGuild and IsInGuild() then
            return "GUILD"
        end
        return nil
    end
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid and IsInRaid() then
        return "RAID"
    end
    if IsInGroup and IsInGroup() then
        return "PARTY"
    end
    if IsInGuild and IsInGuild() then
        return "GUILD"
    end
    return nil
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
    local result = SendAddonPacket(Addon.Constants.COMMUNICATION_PREFIX, payload, channel, target)
    if result ~= false then
        Addon:Debug(debugLabel or "Packet", "sent via", channel)
        return true
    end
    return false
end

function Addon.Communication:SendHello()
    local channel = self:SelectBroadcastChannel()
    if not channel then
        return false, nil
    end
    return self:Send("HELLO", channel), channel
end

function Addon.Communication:SendInitialHello()
    if self.initialHelloSent then
        return
    end
    self.initialHelloSent = true
    self:SendHello()
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
        return
    end

    Addon:Print(Addon:GetText("SIM_HELP"))
end
