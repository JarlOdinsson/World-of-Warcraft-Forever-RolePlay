local Addon = ForeverRP

Addon.ValueAccess = Addon.ValueAccess or {}

-- Modern Forever clients can mark values inaccessible to addon Lua. Keep the
-- fallback for clients that do not expose the secret-value API.
function Addon.ValueAccess:CanAccess(...)
    if canaccessallvalues then
        return canaccessallvalues(...) == true
    end
    return true
end

function Addon.ValueAccess:IsString(value)
    return self:CanAccess(value) and type(value) == "string"
end
