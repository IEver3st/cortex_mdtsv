local ProfilePrefs = {}

local function loadLocalStorage()
    local resourceName = GetCurrentResourceName()
    local chunk = LoadResourceFile(resourceName, 'server/storage/localStorage.lua') or LoadResourceFile(resourceName, 'server/localStorage.lua')
    local fn = chunk and load(chunk, ('@%s/server/storage/localStorage.lua'):format(resourceName), 't', _ENV) or nil
    return fn and fn() or {}
end

local Storage = loadLocalStorage()

local DURABLE_KEYS = {
    settings = 'cortex_mdt:settings',
    announcements = 'cortex_mdt:announcements',
    motd = 'cortex_mdt:motd',
    quotes = 'cortex_mdt:quotes',
    charges = 'cortex_mdt:charges',
    licenses = 'cortex_mdt:licenseTypes',
    pageConfig = 'cortex_mdt:pageConfig',
}

local function profileKey(identifier)
    return ('cortex_mdt:profilePrefs:%s'):format(tostring(identifier or 'unknown'))
end

function ProfilePrefs.getDurableKey(name)
    return DURABLE_KEYS[name]
end

function ProfilePrefs.get(name, fallback)
    local key = DURABLE_KEYS[name] or name
    local value = Storage.get and Storage.get(key) or nil
    if value == nil then
        return fallback
    end
    return value
end

function ProfilePrefs.set(name, value)
    local key = DURABLE_KEYS[name] or name
    return Storage.set and Storage.set(key, value) or false
end

function ProfilePrefs.getProfile(identifier)
    local value = Storage.get and Storage.get(profileKey(identifier)) or nil
    return type(value) == 'table' and value or {}
end

function ProfilePrefs.setProfile(identifier, prefs)
    prefs = type(prefs) == 'table' and prefs or {}
    return Storage.set and Storage.set(profileKey(identifier), prefs) or false
end

function ProfilePrefs.updateProfile(identifier, changes)
    local prefs = ProfilePrefs.getProfile(identifier)
    if type(changes) == 'table' then
        for key, value in pairs(changes) do
            prefs[key] = value
        end
    end
    ProfilePrefs.setProfile(identifier, prefs)
    return prefs
end

return ProfilePrefs
