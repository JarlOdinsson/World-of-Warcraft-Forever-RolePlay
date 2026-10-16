local Addon = ForeverRP
local Markers = {pool = {}}
Addon.PlayerMarkers = Markers
local function Now() return GetTime and GetTime() or 0 end

function Markers:Project(entry, localPosition, radius, width, height, facing)
    if not entry.x or not localPosition.x or entry.zone ~= localPosition.zone
        or entry.space ~= localPosition.space or Now() - entry.at > 125
        or not radius or radius <= 0 or not width or not height then return nil end
    -- UnitPosition's first axis points north; the second points west.
    local dx, dy = localPosition.y - entry.y, entry.x - localPosition.x
    if dx * dx + dy * dy > radius * radius then return nil end
    if facing then
        local c, s = math.cos(facing), math.sin(facing)
        dx, dy = dx * c + dy * s, -dx * s + dy * c
    end
    return dx * width / (2 * radius), dy * height / (2 * radius)
end

function Markers:Refresh()
    local function Clear() for _, marker in ipairs(self.pool) do marker:Hide() end end
    if not Minimap or not Addon.Activity:Enabled() or not Addon.Database:GetActivitySettings().markers
        or not C_Minimap or not C_Minimap.GetViewRadius then
        Clear()
        return
    end
    local radius = C_Minimap.GetViewRadius()
    if not Addon.ValueAccess:CanAccess(radius) or type(radius) ~= "number" or radius ~= radius
        or radius <= 0 or radius > 100000 then Clear(); return end
    local facing
    if GetCVar and GetCVar("rotateMinimap") == "1" then
        facing = GetPlayerFacing and GetPlayerFacing()
        if not Addon.ValueAccess:CanAccess(facing) or type(facing) ~= "number" or facing ~= facing then Clear(); return end
    end
    local location = Addon.Activity:Location()
    location.zone = Addon.Activity:CurrentZone()
    -- Local position is needed for projection even when our sharing is zone-only.
    if not location.x and UnitPosition then
        local x, y, z, space = UnitPosition("player")
        if Addon.ValueAccess:CanAccess(x, y, z, space) and type(x) == "number" and type(y) == "number"
            and type(space) == "number" and x == x and y == y and math.abs(x) <= 100000
            and math.abs(y) <= 100000 and (x ~= 0 or y ~= 0)
            and space == space and space >= 0 and space <= 100000 then
            location.x, location.y, location.space = x, y, space
        end
    end
    local count = 0
    for _, entry in ipairs(Addon.Activity:GetAll()) do
        local x, y = self:Project(entry, location, radius, Minimap:GetWidth(), Minimap:GetHeight(), facing)
        if x and count < 64 then
            count = count + 1
            local marker = self.pool[count]
            if not marker then
                marker = CreateFrame("Frame", nil, Minimap)
                marker:SetSize(6, 6)
                marker:EnableMouse(false) -- no tooltip, clicks or profile requests
                marker.texture = marker:CreateTexture(nil, "OVERLAY")
                marker.texture:SetAllPoints()
                marker.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
                self.pool[count] = marker
            end
            marker.texture:SetVertexColor(0.7, 0.7, 0.7, 0.9) -- no verified layer evidence
            if marker.x ~= x or marker.y ~= y then
                marker:ClearAllPoints()
                marker:SetPoint("CENTER", Minimap, "CENTER", x, y)
                marker.x, marker.y = x, y
            end
            marker:Show()
        end
    end
    for index = count + 1, #self.pool do self.pool[index]:Hide() end
end
