local Addon = ForeverRP

-- Phase 1 compatibility surface for the existing menus and privacy setters.
-- The Beta 17 network implementation is archived outside the installable addon.
-- Saved experimental preferences cannot enable this build's disabled transport.
local Activity = {
    unavailable = true,
    prefix = "FOREVERRPX1",
    channelName = "ForeverRPActivity",
    counters = {sent = 0, received = 0, throttled = 0, duplicates = 0, expired = 0},
}
Addon.Activity = Activity
local reason = "Temporarily unavailable in Phase 1: Directory and layer networking."

function Activity:Enabled() return false end
function Activity:GetNetworkingBlockers() return {reason} end
function Activity:GetNetworkingStatus() return "Phase 1: network paused; saved preferences retained." end
function Activity:GetAll() return {} end
function Activity:QueryDirectory() return {} end
function Activity:GetPeer() return nil end
function Activity:Receive() return false, "phase1-disabled" end
function Activity:Withdraw() end
function Activity:Tick() end
function Activity:Changed() end
function Activity:OnWorldChanged() end
function Activity:ReportTransport() Addon:Print(reason) end
function Activity:ReportTrace() Addon:Print(reason) end
function Activity:SetChannelOnly() return false, "phase1-disabled" end
function Activity:Probe() return false, "phase1-disabled" end

function Activity:Availability()
    local status = Addon.Profile:GetField("status")
    local afk = UnitIsAFK and UnitIsAFK("player")
    local dnd = UnitIsDND and UnitIsDND("player")
    if not Addon.ValueAccess:CanAccess(afk, dnd) then return "DND" end
    if dnd == true or dnd == 1 or status == "DND" then return "DND" end
    if afk == true or afk == 1 or status == "AFK" then return "AFK" end
    return "NORMAL"
end

function Activity:Reset()
    if Addon.PlayerMarkers then Addon.PlayerMarkers:Refresh() end
end

function Activity:Initialize()
    if self.initialized then return end
    self.initialized = true
    -- WoW may retain an old custom-channel subscription across reloads.
    -- Leave once; there is no prefix registration, join, retry, or advertisement.
    local id = GetChannelName and GetChannelName(self.channelName)
    if Addon.ValueAccess:CanAccess(id) and type(id) == "number" and id > 0
        and LeaveChannelByName then LeaveChannelByName(self.channelName) end
end
