local Addon = ForeverRP
local ValueAccess = Addon.ValueAccess

local STATE_LIMITS = {
    WITHIN_10 = 10,
    WITHIN_15 = 15,
    WITHIN_20 = 20,
    WITHIN_25 = 25,
    WITHIN_30 = 30,
}

local SIMULATED_STATES = {
    ["10"] = "WITHIN_10",
    ["15"] = "WITHIN_15",
    ["20"] = "WITHIN_20",
    ["25"] = "WITHIN_25",
    ["30"] = "WITHIN_30",
    out = "OVER_30",
    unknown = "UNKNOWN",
}

Addon.Range = {
    simulated = {},
}

local function InteractionCheck(unit, index)
    if not ValueAccess:IsString(unit) or not CheckInteractDistance then
        return nil
    end
    -- Do not invoke the protected API in combat: catching its Lua error would
    -- still emit ADDON_ACTION_BLOCKED. Require accessible out-of-combat evidence
    -- before every call, including subsequent brackets in the same evaluation.
    -- No hostile-unit exception is assumed for the Forever client.
    if not InCombatLockdown then return nil end
    local lockdown = InCombatLockdown()
    if not ValueAccess:CanAccess(lockdown) or lockdown ~= false then return nil end
    local result = CheckInteractDistance(unit, index)
    if not ValueAccess:CanAccess(result) then return nil end
    if result == true or result == 1 then return true end
    if result == false or result == 0 then return false end
    return nil
end

function Addon.Range:GetRangeState(unit, characterKey)
    if not ValueAccess:CanAccess(characterKey) then
        return "UNKNOWN"
    end
    if ValueAccess:IsString(characterKey) and self.simulated[characterKey] then
        return self.simulated[characterKey]
    end
    if not ValueAccess:IsString(unit) or not UnitExists or not UnitIsPlayer then
        return "UNKNOWN"
    end
    local exists = UnitExists(unit)
    if not ValueAccess:CanAccess(exists) or (exists ~= true and exists ~= 1) then
        return "UNKNOWN"
    end
    local isPlayer = UnitIsPlayer(unit)
    if not ValueAccess:CanAccess(isPlayer) or (isPlayer ~= true and isPlayer ~= 1) then
        return "UNKNOWN"
    end
    if not CheckInteractDistance then
        return "UNKNOWN"
    end

    local close = InteractionCheck(unit, 3)
    if close == true then
        return "WITHIN_10"
    end
    local trade = InteractionCheck(unit, 2)
    if trade == true then
        return "WITHIN_15"
    end
    local inspect, follow = InteractionCheck(unit, 1), InteractionCheck(unit, 4)
    if inspect == true or follow == true then
        return "WITHIN_30"
    end
    if close == nil or trade == nil or inspect == nil or follow == nil then
        return "UNKNOWN"
    end
    return "OVER_30"
end

function Addon.Range:IsWithin(unit, yards, characterKey)
    local state = self:GetRangeState(unit, characterKey)
    local limit = STATE_LIMITS[state]
    if not limit then
        return false, state
    end

    -- Real checks expose conservative 10, ~11, and ~28 yard brackets only.
    if state == "WITHIN_15" and (yards == 20 or yards == 25) then
        return true, state
    end
    return limit <= yards, state
end

function Addon.Range:SetSimulatedState(characterKey, value)
    local state = SIMULATED_STATES[tostring(value)]
    if not state then
        return false
    end
    self.simulated[characterKey] = state
    return true, state
end

function Addon.Range:GetSimulatedState(characterKey)
    return self.simulated[characterKey]
end

function Addon.Range:ClearSimulated()
    for characterKey in pairs(self.simulated) do
        self.simulated[characterKey] = nil
    end
end
