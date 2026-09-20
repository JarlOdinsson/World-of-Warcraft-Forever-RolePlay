local Addon = ForeverRP

local PROFILE_FIELDS = {}
for _, field in ipairs(Addon.Constants.PROFILE_FIELD_ORDER) do
    PROFILE_FIELDS[field] = true
end

local SINGLE_LINE_FIELDS = {
    rpName = true,
    title = true,
    race = true,
    class = true,
    age = true,
    pronouns = true,
    status = true,
    currently = true,
}

local function HasUnsafeControlCharacters(field, value)
    for index = 1, #value do
        local byte = string.byte(value, index)
        if byte == 127 or (byte < 32 and (SINGLE_LINE_FIELDS[field]
            or (byte ~= 9 and byte ~= 10 and byte ~= 13))) then
            return true
        end
    end
    return false
end

local function GetCharacterDefaults()
    local name = UnitName and UnitName("player") or ""
    local race = UnitRace and UnitRace("player") or ""
    local class = UnitClass and UnitClass("player") or ""

    return {
        rpName = type(name) == "string" and name or "",
        title = "",
        race = type(race) == "string" and race or "",
        class = type(class) == "string" and class or "",
        age = "",
        pronouns = "",
        status = "OOC",
        currently = "",
        atAGlance = "",
        description = "",
        history = "",
        oocNotes = "",
    }
end

local function IsValidStatus(value)
    for _, status in ipairs(Addon.Constants.PROFILE_STATUSES) do
        if value == status then
            return true
        end
    end
    return false
end

local function LimitValue(field, value)
    value = type(value) == "string" and value or ""
    local limit = Addon.Constants.PROFILE_LIMITS[field]
    if limit and #value > limit then
        value = string.sub(value, 1, limit)
    end
    return value
end

Addon.Profile = {}

function Addon.Profile:Initialize()
    local character = Addon.Database:GetCharacter()
    local defaults = GetCharacterDefaults()

    if type(character.profile) ~= "table" then
        character.profile = defaults
    else
        for field, defaultValue in pairs(defaults) do
            if character.profile[field] == nil then
                character.profile[field] = defaultValue
            elseif field == "status" then
                if not IsValidStatus(character.profile[field]) then
                    character.profile[field] = "OOC"
                end
            else
                character.profile[field] = LimitValue(field, character.profile[field])
            end
        end
    end

    self.data = character.profile
end

function Addon.Profile:Get()
    return self.data
end

function Addon.Profile:GetField(field)
    if not PROFILE_FIELDS[field] then
        return nil
    end
    return self.data[field]
end

function Addon.Profile:SetField(field, value)
    if not PROFILE_FIELDS[field] then
        return false
    end

    if field == "status" then
        if not IsValidStatus(value) then
            return false
        end
        self.data.status = value
        return true
    end

    self.data[field] = LimitValue(field, value)
    return true
end

function Addon.Profile:Reset()
    local character = Addon.Database:GetCharacter()
    character.profile = GetCharacterDefaults()
    self.data = character.profile
end

function Addon.Profile:GetDisplayName()
    local rpName = self:GetField("rpName")
    if rpName and rpName ~= "" then
        return rpName
    end
    return UnitName and UnitName("player") or Addon.Constants.ADDON_DISPLAY_NAME
end

function Addon.Profile:GetCompletion()
    local completed = 0
    local total = 0
    for field in pairs(PROFILE_FIELDS) do
        total = total + 1
        local value = self.data[field]
        if type(value) == "string" and value ~= "" then
            completed = completed + 1
        end
    end
    return completed, total
end

function Addon.Profile:IsValidStatus(value)
    return IsValidStatus(value)
end

function Addon.Profile:SanitizeRemoteProfile(profile)
    if type(profile) ~= "table" then
        return nil, "profile is not a table"
    end
    for field in pairs(profile) do
        if not PROFILE_FIELDS[field] then
            return nil, "unexpected profile field"
        end
    end

    local sanitized = {}
    for _, field in ipairs(Addon.Constants.PROFILE_FIELD_ORDER) do
        local value = profile[field]
        if type(value) ~= "string" then
            return nil, "missing or invalid profile field"
        end
        if HasUnsafeControlCharacters(field, value) then
            return nil, "profile field contains invalid control characters"
        end
        if field == "status" then
            if not IsValidStatus(value) then
                return nil, "invalid profile status"
            end
        else
            local limit = Addon.Constants.PROFILE_LIMITS[field]
            if limit and #value > limit then
                return nil, "profile field exceeds limit"
            end
        end
        sanitized[field] = value
    end
    return sanitized
end
