local Addon = ForeverRP

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
    if not CheckInteractDistance then
        return false
    end
    local result = CheckInteractDistance(unit, index)
    return result == true or result == 1
end

function Addon.Range:GetRangeState(unit, characterKey)
    if characterKey and self.simulated[characterKey] then
        return self.simulated[characterKey]
    end
    if not UnitExists or not UnitExists(unit) or not UnitIsPlayer or not UnitIsPlayer(unit) then
        return "UNKNOWN"
    end
    if not CheckInteractDistance then
        return "UNKNOWN"
    end

    if InteractionCheck(unit, 3) then
        return "WITHIN_10"
    end
    if InteractionCheck(unit, 2) then
        return "WITHIN_15"
    end
    if InteractionCheck(unit, 1) or InteractionCheck(unit, 4) then
        return "WITHIN_30"
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
