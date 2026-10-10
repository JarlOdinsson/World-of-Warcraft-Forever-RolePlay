local Addon = ForeverRP
local Auth = {pending = {}, permits = {}, seen = {}, served = {}, revocations = {}, denied = 0}
Addon.ProfileAuthorization = Auth
local function Now() return GetTime and GetTime() or 0 end
local function Count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local function Key(peer) return string.lower(peer) end
local function SavedConnection(peer)
    local store = Addon.Connections:GetStore()
    if store[peer] then return store[peer] end
    for _, connection in pairs(store) do
        if Key(connection.characterKey) == Key(peer) then return connection end
    end
end

function Auth:CanSend(peer, messageId)
    if not Addon.Privacy:CanInteract(peer, "WHISPER", false) then return false end
    if not Addon.Presence:IsConfirmed(peer, false) then return false end
    local mode = Addon.Database:GetDisclosureMode()
    if mode == "public" then return true end
    if mode == "connections" then
        if Addon.Database.character.profileApprovals[Key(peer)] ~= true then return false end
        return SavedConnection(peer) ~= nil
    end
    local permit = self.permits[Key(peer)]
    return permit and permit.id == messageId and permit.untilAt > Now() or false
end

function Auth:Status(peer, id, status)
    local payload = Addon.Communication:Serialize("PROFILE_STATUS", id, status)
    if status == "revoked" then return Addon.Communication:SendRevocation(peer) end
    return payload and Addon.Communication:SendPayload(payload, "WHISPER",
        Addon.Presence:GetTransportRecipient(peer), "PROFILE_STATUS", peer, Addon.Presence:GetTransportRecipientSource(peer))
end

function Auth:HandleRequest(packet, sender, peer)
    self:Tick()
    local key, now = Key(peer), Now()
    if self.seen[key] and now - self.seen[key] < 10 then self.denied = self.denied + 1; return false, "cooldown" end
    if not self.seen[key] and Count(self.seen) >= 100 then self.denied = self.denied + 1; return false, "busy" end
    if not self.requestWindow or now - self.requestWindow >= 60 then
        self.requestWindow, self.requestCount = now, 0
    end
    if self.requestCount >= 20 then self.denied = self.denied + 1; return false, "busy" end
    self.requestCount, self.seen[key] = self.requestCount + 1, now
    if self:CanSend(peer, packet.messageId) then
        local accepted, reason = Addon.ProfileTransfer:SendProfile(peer, packet.messageId, sender)
        if not accepted then self.denied = self.denied + 1 end
        if not accepted and reason == "busy" then self:Status(peer, packet.messageId, "busy") end
        return accepted, reason
    end
    if Addon.Database:GetDisclosureMode() == "approval" and Count(self.pending) < 8 then
        if self.pending[key] then self.denied = self.denied + 1; return false, "pending" end
        self.pending[key] = {peer = peer, sender = sender, id = packet.messageId, untilAt = now + 25}
        self:Status(peer, packet.messageId, "pending")
        if not self.lastNotice or now - self.lastNotice >= 10 then
            self.lastNotice = now
            Addon:Print("A profile access request is waiting in Discovery & Privacy.")
        end
        if Addon.DiscoveryOptions then Addon.DiscoveryOptions:Refresh() end
        return true, "approval"
    end
    self.denied = self.denied + 1
    self:Status(peer, packet.messageId, "denied")
    return false, "denied"
end

function Auth:Decide(peer, allowed)
    local key = Key(peer)
    local request = self.pending[key]
    self.pending[key] = nil
    if not request or request.untilAt <= Now() then return false end
    if allowed and Addon.Database:GetDisclosureMode() == "approval"
        and Addon.Privacy:CanInteract(peer, "WHISPER", false) then
        self.permits[key] = {id = request.id, untilAt = Now() + 30}
        self.revocations[key] = nil
        local accepted, reason = Addon.ProfileTransfer:SendProfile(peer, request.id, request.sender)
        if accepted then return true end
        self.permits[key] = nil
        if reason == "busy" then self.denied = self.denied + 1; self:Status(peer, request.id, "busy"); return false end
    end
    self.denied = self.denied + 1
    self:Status(peer, request.id, "denied")
    return false
end

function Auth:SetConnectionApproval(peer, allowed)
    local connection = SavedConnection(peer)
    local canonical = connection and connection.characterKey
    if not canonical then return false end
    local approvals = Addon.Database.character.profileApprovals
    if allowed and not approvals[Key(canonical)] and Count(approvals) >= 100 then return false end
    approvals[Key(canonical)] = allowed == true or nil
    if allowed then self.revocations[Key(canonical)] = nil end
    if not allowed then
        self.permits[Key(canonical)] = nil
        self:QueueRevocation(canonical)
        Addon.ProfileTransfer:CancelDisallowedResponses()
    end
    return true
end

function Auth:QueueRevocation(peer)
    local key = Key(peer)
    local served = self.served[key]
    if not served then return false end
    self.revocations[key] = {peer = served.peer, recipient = served.recipient, attempts = 0}
    return true
end

function Auth:MarkServed(peer, recipient)
    local key = Key(peer)
    self.revocations[key] = nil -- a fresh, authorized transfer supersedes old notices
    if not self.served[key] and Count(self.served) >= 100 then
        local oldest, at
        for saved, entry in pairs(self.served) do
            if not at or entry.at < at or entry.at == at and saved < oldest then oldest, at = saved, entry.at end
        end
        self.served[oldest], self.revocations[oldest] = nil, nil
    end
    self.served[key] = {peer = peer, recipient = recipient or Addon.Presence:GetTransportRecipient(peer), at = Now()}
end

function Auth:Reset()
    self.pending, self.permits = {}, {}
    for _, entry in pairs(self.served) do self:QueueRevocation(entry.peer) end
    if Addon.ProfileTransfer then Addon.ProfileTransfer:CancelDisallowedResponses() end
    if Addon.Activity then Addon.Activity:Changed(true) end
end

function Auth:Tick()
    local now = Now()
    local changed = false
    if Addon.RemoteProfiles.Expire then Addon.RemoteProfiles:Expire() end
    for key, request in pairs(self.pending) do
        if request.untilAt <= now or not Addon.Privacy:CanInteract(request.peer, "WHISPER", false) then
            self.pending[key] = nil
            changed = true
        end
    end
    if changed and Addon.DiscoveryOptions then Addon.DiscoveryOptions:Refresh() end
    for key, permit in pairs(self.permits) do
        if permit.untilAt <= now then self.permits[key] = nil end
    end
    for key, at in pairs(self.seen) do if now - at >= 300 then self.seen[key] = nil end end
    if not self.lastRevoke or now - self.lastRevoke >= 1 then
        local key, notice = next(self.revocations)
        if key then
            self.lastRevoke = now
            if Addon.Communication:SendRevocation(notice.peer, notice.recipient) or notice.attempts >= 2 then
                self.revocations[key] = nil
            else
                notice.attempts = notice.attempts + 1
            end
        end
    end
end

function Auth:Initialize()
    self.initialized = true -- existing Nearby lifecycle ticker services Tick
end
