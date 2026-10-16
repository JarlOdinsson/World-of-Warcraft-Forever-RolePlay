local Addon = ForeverRP
local Access = Addon.ValueAccess
local Markers = {pool = {}}
Addon.PlayerMarkers = Markers

local function Number(value, limit)
    return Access:CanAccess(value) and type(value) == "number" and value == value
        and math.abs(value) <= (limit or 100000)
end

function Markers:Clear()
    for _, marker in ipairs(self.pool) do marker:Hide() end
end

function Markers:Position(unit)
    if not UnitPosition or not InCombatLockdown then return nil end
    local lockdown = InCombatLockdown()
    if not Access:CanAccess(lockdown) or lockdown ~= false then return nil end
    local x, y, z, space = UnitPosition(unit)
    if not Access:CanAccess(x, y, z, space) or not Number(x) or not Number(y)
        or not Number(z) or not Number(space) or space < 0 or (x == 0 and y == 0) then return nil end
    return {x = x, y = y, space = space}
end

function Markers:PeerPosition(peer)
    if peer.simulated or not Addon.Presence:IsConfirmed(peer.characterKey, false)
        or not Addon.Privacy:CanInteract(peer.characterKey, "WHISPER", false) then return nil end
    -- A target and group token may refer to the same player but expose different
    -- position availability. Validate every candidate; never guess an alias.
    for _, detection in ipairs(Addon.PlayerDetection:GetUnits(peer.characterKey, false)) do
        if not detection.simulated and detection.characterKey == peer.characterKey
            and Addon.PlayerDetection:IsValid(detection) then
            local visible = UnitIsVisible and UnitIsVisible(detection.unit)
            if Access:CanAccess(visible) and (visible == true or visible == 1)
                and Addon.Range:IsWithin(detection.unit, Addon.Database:GetDiscoveryRadius(), peer.characterKey) then
                local position = self:Position(detection.unit)
                if position then return position end
            end
        end
    end
end

function Markers:Project(entry, position, radius, width, height, facing)
    if entry.space ~= position.space then return nil end
    -- Retain the existing north/west projection, rotating-minimap handling and pool.
    local dx, dy = position.y - entry.y, entry.x - position.x
    if dx * dx + dy * dy > radius * radius then return nil end
    if facing then
        local c, s = math.cos(facing), math.sin(facing)
        dx, dy = dx * c + dy * s, -dx * s + dy * c
    end
    return dx * width / (2 * radius), dy * height / (2 * radius)
end

function Markers:Refresh()
    -- Read only currently observed, privacy-qualified Nearby units. Coordinates
    -- are never stored in a peer cache or sent. Message/group membership alone
    -- cannot create a dot; Unknown positions/range remain unavailable.
    if not Addon.Database or not Addon.Database:GetAccount() or not Minimap
        or not Addon.Database:IsDiscoveryEnabled() or Addon.Database:GetPrivacyMode() == "hidden"
        or not Addon.Database:GetActivitySettings().markers or not Addon.NearbyPlayers
        or not C_Minimap or not C_Minimap.GetViewRadius or not InCombatLockdown then
        self:Clear(); return
    end
    local lockdown = InCombatLockdown()
    if not Access:CanAccess(lockdown) or lockdown ~= false then self:Clear(); return end
    local radius, width, height = C_Minimap.GetViewRadius(), Minimap:GetWidth(), Minimap:GetHeight()
    if not Number(radius) or radius <= 0 or not Number(width) or width <= 0
        or not Number(height) or height <= 0 then self:Clear(); return end
    local facing
    if GetCVar and GetCVar("rotateMinimap") == "1" then
        facing = GetPlayerFacing and GetPlayerFacing()
        if not Number(facing) then self:Clear(); return end
    end
    local position = self:Position("player")
    if not position then self:Clear(); return end
    local count = 0
    for _, peer in ipairs(Addon.NearbyPlayers:GetAll(false)) do
        local entry = self:PeerPosition(peer)
        if entry then
            local x, y
            x, y = self:Project(entry, position, radius, width, height, facing)
            if x and count < 64 then
                count = count + 1
                local marker = self.pool[count]
                if not marker then
                    marker = CreateFrame("Frame", nil, Minimap)
                    marker:SetSize(6, 6)
                    marker:EnableMouse(false)
                    marker.texture = marker:CreateTexture(nil, "OVERLAY")
                    marker.texture:SetAllPoints()
                    marker.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
                    self.pool[count] = marker
                end
                marker.texture:SetVertexColor(0.7, 0.7, 0.7, 0.9)
                if marker.x ~= x or marker.y ~= y then
                    marker:ClearAllPoints()
                    marker:SetPoint("CENTER", Minimap, "CENTER", x, y)
                    marker.x, marker.y = x, y
                end
                marker:Show()
            end
        end
    end
    for index = count + 1, #self.pool do self.pool[index]:Hide() end
end
