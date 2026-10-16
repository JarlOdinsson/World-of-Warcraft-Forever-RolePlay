local Addon = ForeverRP
local Access = Addon.ValueAccess

-- Runtime only. A probe is not proof of delivery, consent, or proximity.
local Discovery = {peers = {}, replies = {}, tokens = 4, sends = {}, sequence = 0}
Addon.ObservedDiscovery = Discovery
local WINDOW, MAX_PEERS, MAX_PENDING = 300, 128, 32
local function Now() return GetTime and GetTime() or 0 end

function Discovery:Enabled()
    return Addon.Database and Addon.Database:GetAccount()
        and Addon.Database:IsDiscoveryEnabled()
        and Addon.Database:GetPrivacyMode() ~= "hidden"
end

function Discovery:Prune(now)
    -- Observation bursts must not repeat a full history scan for every token.
    if self.lastPruneAt and now - self.lastPruneAt < 1 then return end
    self.lastPruneAt = now
    for key, peer in pairs(self.peers) do
        if now >= peer.expires then
            -- Never turn a continuously observed non-responder into an endless
            -- retry loop. Retain its bounded suppression record while present.
            local presence = Addon.Presence:Get(peer.characterKey, false)
            if peer.attempts >= 2 and not presence and self:Candidate(peer.characterKey) then
                peer.expires = now + WINDOW
            else
                self.peers[key] = nil
            end
        end
    end
    for key, at in pairs(self.replies) do
        if now - at >= WINDOW then self.replies[key] = nil end
    end
    while self.sends[1] and now - self.sends[1] >= 60 do table.remove(self.sends, 1) end
end

function Discovery:TakeBudget(hello)
    local now = Now()
    self:Prune(now)
    self.tokens = math.min(4, self.tokens + math.max(0, now - (self.refilledAt or now)) * 2)
    self.refilledAt = now
    if now < (self.pausedUntil or 0) or self.tokens < 1 or (hello and #self.sends >= 20) then return false end
    self.tokens = self.tokens - 1
    if hello then self.sends[#self.sends + 1] = now end
    return true
end

function Discovery:Candidate(characterKey)
    if not Access:IsString(characterKey) then return nil, "invalid-identity" end
    if not self:Enabled() or Addon.Presence:IsSelf(characterKey)
        or not Addon.Privacy:CanInteract(characterKey, "WHISPER", false) then
        return nil, "privacy-or-discovery"
    end
    local presence = Addon.Presence:Get(characterKey, false)
    if presence and presence.confirmed and Now() - presence.lastSeen < 600 then
        return nil, "already-confirmed"
    end
    local reason = "no-observed-unit"
    for _, detection in ipairs(Addon.PlayerDetection:GetUnits(characterKey, false)) do
        if not detection.simulated and (detection.source == "target"
            or detection.source == "mouseover" or detection.source == "nameplate")
            and Addon.PlayerDetection:IsValid(detection) then
            local range = Addon.Range:GetRangeState(detection.unit, characterKey)
            if range ~= "OVER_30" then return detection, range end
            reason = "observed-out-of-range"
        end
    end
    return nil, reason
end

function Discovery:Observe(characterKey)
    if not Access:IsString(characterKey) then return false end
    local now = Now()
    self:Prune(now)
    local key = string.lower(characterKey)
    if self.peers[key] then return false end
    local detection = self:Candidate(characterKey)
    if not detection then return false end
    local count, pending = 0, 0
    for _, peer in pairs(self.peers) do
        count = count + 1
        if peer.pending then pending = pending + 1 end
    end
    -- Reject growth instead of evicting cooldown records to admit more traffic.
    if count >= MAX_PEERS or pending >= MAX_PENDING then return false end
    self.sequence = self.sequence + 1
    local peer = {characterKey = characterKey, attempts = 0, pending = true,
        nextAt = now, expires = now + WINDOW, deadline = now + 30,
        sequence = self.sequence, reason = "queued"}
    self.peers[key] = peer
    self:Attempt(peer)
    return true
end

function Discovery:Attempt(peer)
    local now = Now()
    if not peer.pending then return end
    if now >= peer.deadline then peer.pending = false; peer.reason = "queue-expired"; return end
    local detection, range = self:Candidate(peer.characterKey)
    if not detection then peer.pending = false; peer.reason = range; return end
    peer.unit, peer.range = detection.unit, range
    if not Access:IsString(detection.transportRecipient) or detection.transportRecipient == "" then
        peer.pending = false; peer.reason = "no-transport-recipient"; return
    end
    peer.transportRecipient = detection.transportRecipient
    if now < peer.nextAt then return end
    if not Addon.Communication:CanBroadcast() then peer.reason = "prefix-unregistered"; return end
    if not self:TakeBudget(true) then peer.reason = "traffic-limit"; return end
    peer.attempts = peer.attempts + 1
    local trigger = detection.trigger and (":trigger=" .. detection.trigger
        .. (peer.attempts > 1 and ":retry-tick" or ":initial-probe")) or ""
    local accepted, reason = Addon.Communication:Send("HELLO", "WHISPER", peer.transportRecipient, peer.characterKey,
        "observed-unit:" .. detection.unit .. ":" .. (detection.recipientSource or "client-identity") .. trigger)
    peer.reason = reason or (accepted and "accepted" or "failed")
    if reason == "throttled" then self.pausedUntil = now + 10 end
    peer.nextAt = now + 10 + (peer.sequence % 6)
    peer.pending = peer.attempts < 2
end

function Discovery:Tick()
    self:Prune(Now())
    -- Existing visible tokens can move into range or need presence renewal.
    local keys = Addon.PlayerDetection:GetCharacterKeys(false)
    table.sort(keys)
    for _, key in ipairs(keys) do self:Observe(key) end
    local pending = {}
    for _, peer in pairs(self.peers) do
        if peer.pending then pending[#pending + 1] = peer end
    end
    table.sort(pending, function(a, b) return a.sequence < b.sequence end)
    for _, peer in ipairs(pending) do self:Attempt(peer) end
end

function Discovery:Reply(sender, characterKey)
    if not self:Enabled() or not Access:IsString(sender) or not Access:IsString(characterKey)
        or not Addon.Privacy:CanInteract(characterKey, "WHISPER", false) then return false end
    self:Prune(Now())
    local key = string.lower(characterKey)
    local previous = self.replies[key]
    if previous and Now() - previous < 10 then return false end
    local count = 0
    for _ in pairs(self.replies) do count = count + 1 end
    if not previous and count >= MAX_PEERS then return false end
    if not self:TakeBudget(false) then return false end
    self.replies[key] = Now()
    local accepted, reason = Addon.Communication:Send("ACK", "WHISPER", sender, characterKey, "received-sender:HELLO")
    if reason == "throttled" then self.pausedUntil = Now() + 10 end
    return accepted, reason
end
