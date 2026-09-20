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
    },
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
