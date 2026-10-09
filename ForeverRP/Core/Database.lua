local Addon = ForeverRP

local ACCOUNT_DEFAULTS = {
    databaseVersion = Addon.Constants.DATABASE_VERSION,
    settings = {
        debug = false,
        minimap = {
            visible = true,
            angle = 220,
        },
        discovery = {
            enabled = true,
            radius = Addon.Constants.DEFAULT_DISCOVERY_RADIUS,
            privacy = Addon.Constants.DEFAULT_PRIVACY_MODE,
            notifications = {
                minimapPulse = true,
                sound = true,
                chat = false,
                cooldown = 600,
            },
        },
        emoteBar = {
            enabled = false,
            slots = Addon.Constants.EMOTE_BAR_DEFAULT_SLOTS,
            locked = false,
            scale = 1,
            point = "CENTER",
            x = 0,
            y = -220,
            actions = {},
        },
    },
    connections = {},
}

local CHARACTER_DEFAULTS = {
    databaseVersion = Addon.Constants.DATABASE_VERSION,
}

Addon.Database = {}

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                MergeDefaults(target[key], value)
            else
                target[key] = value
            end
        elseif type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            MergeDefaults(target[key], value)
        end
    end
end

function Addon.Database:Initialize()
    local recoveredAccount = type(ForeverRPDB) ~= "table"
    local recoveredCharacter = type(ForeverRPCharacterDB) ~= "table"

    if recoveredAccount then
        ForeverRPDB = {}
    end
    if recoveredCharacter then
        ForeverRPCharacterDB = {}
    end

    if type(ForeverRPDB.settings) ~= "table" then
        ForeverRPDB.settings = {}
    end
    if ForeverRPDB.settings.debug == nil and type(ForeverRPDB.debug) == "boolean" then
        ForeverRPDB.settings.debug = ForeverRPDB.debug
    end

    MergeDefaults(ForeverRPDB, ACCOUNT_DEFAULTS)
    MergeDefaults(ForeverRPCharacterDB, CHARACTER_DEFAULTS)

    if type(ForeverRPDB.settings.debug) ~= "boolean" then
        ForeverRPDB.settings.debug = false
    end
    if type(ForeverRPDB.settings.minimap.visible) ~= "boolean" then
        ForeverRPDB.settings.minimap.visible = true
    end
    if type(ForeverRPDB.settings.discovery.enabled) ~= "boolean" then
        ForeverRPDB.settings.discovery.enabled = true
    end
    local validRadius = false
    for _, radius in ipairs(Addon.Constants.DISCOVERY_RADII) do
        if ForeverRPDB.settings.discovery.radius == radius then
            validRadius = true
            break
        end
    end
    if not validRadius then
        ForeverRPDB.settings.discovery.radius = Addon.Constants.DEFAULT_DISCOVERY_RADIUS
    end
    local validPrivacy = false
    for _, mode in ipairs(Addon.Constants.PRIVACY_MODES) do
        if ForeverRPDB.settings.discovery.privacy == mode then
            validPrivacy = true
            break
        end
    end
    if not validPrivacy then
        ForeverRPDB.settings.discovery.privacy = Addon.Constants.DEFAULT_PRIVACY_MODE
    end
    local notifications = ForeverRPDB.settings.discovery.notifications
    if type(notifications.minimapPulse) ~= "boolean" then
        notifications.minimapPulse = true
    end
    if type(notifications.sound) ~= "boolean" then
        notifications.sound = true
    end
    if type(notifications.chat) ~= "boolean" then
        notifications.chat = false
    end
    local cooldown = tonumber(notifications.cooldown)
    if not cooldown or cooldown < 1 or cooldown > 86400 then
        notifications.cooldown = 600
    else
        notifications.cooldown = math.floor(cooldown)
    end

    local emoteBar = ForeverRPDB.settings.emoteBar
    if type(emoteBar.enabled) ~= "boolean" then
        emoteBar.enabled = false
    end
    if type(emoteBar.locked) ~= "boolean" then
        emoteBar.locked = false
    end
    emoteBar.slots = math.max(Addon.Constants.EMOTE_BAR_MIN_SLOTS,
        math.min(Addon.Constants.EMOTE_BAR_MAX_SLOTS, math.floor(tonumber(emoteBar.slots) or 6)))
    local validScale = false
    for _, scale in ipairs(Addon.Constants.EMOTE_BAR_SCALES) do
        if emoteBar.scale == scale then
            validScale = true
            break
        end
    end
    if not validScale then
        emoteBar.scale = 1
    end
    local validPoints = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
        TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
    if not validPoints[emoteBar.point] or type(emoteBar.x) ~= "number" or type(emoteBar.y) ~= "number" then
        emoteBar.point, emoteBar.x, emoteBar.y = "CENTER", 0, -220
    else
        emoteBar.x = math.max(-5000, math.min(5000, emoteBar.x))
        emoteBar.y = math.max(-5000, math.min(5000, emoteBar.y))
    end
    if type(emoteBar.actions) ~= "table" then
        emoteBar.actions = {}
    end
    if type(ForeverRPDB.connections) ~= "table" then
        ForeverRPDB.connections = {}
    end
    for characterKey, connection in pairs(ForeverRPDB.connections) do
        if type(characterKey) ~= "string" or type(connection) ~= "table"
            or connection.characterKey ~= characterKey then
            ForeverRPDB.connections[characterKey] = nil
        else
            connection.rpName = type(connection.rpName) == "string"
                and connection.rpName:sub(1, Addon.Constants.PROFILE_LIMITS.rpName) or ""
            connection.remembered = connection.remembered ~= false
            connection.favorite = connection.favorite == true
            connection.privateNote = type(connection.privateNote) == "string"
                and connection.privateNote:gsub("[%z\1-\8\11\12\14-\31\127]", "")
                    :sub(1, Addon.Constants.CONNECTION_NOTE_LIMIT) or ""
            connection.addedAt = tonumber(connection.addedAt) or 0
            connection.lastEncountered = tonumber(connection.lastEncountered)
            connection.simulated = nil
        end
    end

    -- Keep the Milestone 1 field synchronized while structured settings become canonical.
    ForeverRPDB.debug = ForeverRPDB.settings.debug

    self.account = ForeverRPDB
    self.character = ForeverRPCharacterDB
    Addon.State.databaseRecovered = recoveredAccount or recoveredCharacter
end

function Addon.Database:GetAccount()
    return self.account
end

function Addon.Database:GetCharacter()
    return self.character
end

function Addon.Database:IsDebugEnabled()
    return self.account.settings.debug == true
end

function Addon.Database:SetDebugEnabled(enabled)
    local value = enabled == true
    self.account.settings.debug = value
    self.account.debug = value
    if not value and Addon.Notifications then
        Addon.Notifications:SetSimulationEnabled(false)
    end
    if Addon.NearbyPlayers then
        Addon.NearbyPlayers:ReevaluateAll()
    end
    if Addon.ConnectionsUI then
        Addon.ConnectionsUI:Refresh()
    end
end

function Addon.Database:IsMinimapVisible()
    return self.account.settings.minimap.visible ~= false
end

function Addon.Database:SetMinimapVisible(visible)
    self.account.settings.minimap.visible = visible == true
end

function Addon.Database:GetMinimapAngle()
    local angle = tonumber(self.account.settings.minimap.angle) or 220
    angle = angle % 360
    self.account.settings.minimap.angle = angle
    return angle
end

function Addon.Database:SetMinimapAngle(angle)
    self.account.settings.minimap.angle = (tonumber(angle) or 220) % 360
end

function Addon.Database:IsDiscoveryEnabled()
    return self.account.settings.discovery.enabled == true
end

function Addon.Database:SetDiscoveryEnabled(enabled)
    self.account.settings.discovery.enabled = enabled == true
    if Addon.NearbyPlayers then
        Addon.NearbyPlayers:ReevaluateAll()
    end
end

function Addon.Database:GetDiscoveryRadius()
    return self.account.settings.discovery.radius
end

function Addon.Database:SetDiscoveryRadius(radius)
    radius = tonumber(radius)
    for _, allowed in ipairs(Addon.Constants.DISCOVERY_RADII) do
        if radius == allowed then
            self.account.settings.discovery.radius = allowed
            if Addon.NearbyPlayers then
                Addon.NearbyPlayers:ReevaluateAll()
            end
            return true
        end
    end
    return false
end

function Addon.Database:GetPrivacyMode()
    return self.account.settings.discovery.privacy
end

function Addon.Database:SetPrivacyMode(mode, suppressBroadcast)
    for _, allowed in ipairs(Addon.Constants.PRIVACY_MODES) do
        if mode == allowed then
            if self.account.settings.discovery.privacy == allowed then
                return true
            end
            self.account.settings.discovery.privacy = allowed
            if Addon.Privacy then
                Addon.Privacy:ResetRuntimeTrust()
            end
            if Addon.Presence then
                Addon.Presence:ClearAll()
            end
            if Addon.ProfileTransfer then
                Addon.ProfileTransfer:ResetForPrivacyChange()
            end
            if Addon.NearbyPlayers then
                Addon.NearbyPlayers:ReevaluateAll()
            end
            if Addon.Communication and allowed ~= "hidden" and not suppressBroadcast then
                Addon.Communication:SendHello()
            end
            return true
        end
    end
    return false
end

function Addon.Database:GetNotificationSettings()
    return self.account.settings.discovery.notifications
end

function Addon.Database:SetNotificationSetting(key, value)
    if key ~= "minimapPulse" and key ~= "sound" and key ~= "chat" then
        return false
    end
    self.account.settings.discovery.notifications[key] = value == true
    return true
end

function Addon.Database:SetNotificationCooldown(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds < 1 or seconds > 86400 then
        return false
    end
    self.account.settings.discovery.notifications.cooldown = math.floor(seconds)
    return true
end

function Addon.Database:GetEmoteBarSettings()
    return self.account.settings.emoteBar
end

function Addon.Database:GetConnections()
    return self.account.connections
end
