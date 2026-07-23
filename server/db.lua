local function trim(value)
    if value == nil then
        return ''
    end

    return tostring(value):match('^%s*(.-)%s*$') or ''
end

local function normalizeMode(mode)
    local value = trim(mode):lower()

    if value == 'qbox' then
        value = 'qbx'
    elseif value == 'night_ers' then
        value = 'ers'
    end

    if value == 'standalone' or value == 'qbx' or value == 'ers' then
        return value
    end

    return 'auto'
end

local function isResourceStarted(name)
    local resource = trim(name)

    if resource == '' then
        return false
    end

    local state = GetResourceState(resource)
    return state == 'started' or state == 'starting'
end

local function getFrameworkConfig(mode)
    return type(Config.Frameworks) == 'table' and type(Config.Frameworks[mode]) == 'table'
        and Config.Frameworks[mode]
        or {}
end

local function getConfiguredMode()
    local configuredMode = trim(Config.FrameworkMode)

    if configuredMode == '' then
        configuredMode = trim(Config.Framework)
    end

    return normalizeMode(configuredMode)
end

local function getQbxResourceName()
    local qbxConfig = getFrameworkConfig('qbx')
    local configured = trim(qbxConfig.resourceName)

    if configured ~= '' then
        return configured
    end

    configured = trim(type(Config.FrameworkResources) == 'table' and Config.FrameworkResources.qbx or '')
    if configured ~= '' then
        return configured
    end

    return 'qbx_core'
end

local function getErsResourceNames()
    local ersConfig = getFrameworkConfig('ers')
    local names = {}
    local primary = trim(ersConfig.resourceName)

    if primary == '' then
        primary = trim(type(Config.FrameworkResources) == 'table' and Config.FrameworkResources.ers or '')
    end

    if primary ~= '' then
        names[#names + 1] = primary
    else
        names[#names + 1] = 'night_ers'
    end

    if type(ersConfig.fallbackResourceNames) == 'table' then
        for i = 1, #ersConfig.fallbackResourceNames do
            local candidate = trim(ersConfig.fallbackResourceNames[i])
            if candidate ~= '' then
                names[#names + 1] = candidate
            end
        end
    end

    local configuredFallbacks = type(Config.FrameworkResources) == 'table' and Config.FrameworkResources.ersFallbacks or nil
    if type(configuredFallbacks) == 'table' then
        for i = 1, #configuredFallbacks do
            local candidate = trim(configuredFallbacks[i])
            if candidate ~= '' then
                names[#names + 1] = candidate
            end
        end
    end

    return names
end

local function resolveErsResourceName()
    local names = getErsResourceNames()

    for i = 1, #names do
        if isResourceStarted(names[i]) then
            return names[i]
        end
    end

    return names[1]
end

local function getAutoDetectPriority()
    local configuredPriority = type(Config.FrameworkAutoDetectPriority) == 'table'
        and Config.FrameworkAutoDetectPriority
        or { 'ers', 'qbx', 'standalone' }
    local resolvedPriority = {}

    for i = 1, #configuredPriority do
        local mode = normalizeMode(configuredPriority[i])
        if mode == 'standalone' or mode == 'qbx' or mode == 'ers' then
            resolvedPriority[#resolvedPriority + 1] = mode
        end
    end

    if #resolvedPriority == 0 then
        resolvedPriority = { 'ers', 'qbx', 'standalone' }
    end

    return resolvedPriority
end

local function detectFrameworkMode()
    local priority = getAutoDetectPriority()

    for i = 1, #priority do
        local mode = priority[i]

        if mode == 'ers' and isResourceStarted(resolveErsResourceName()) then
            return 'ers'
        end

        if mode == 'qbx' and isResourceStarted(getQbxResourceName()) then
            return 'qbx'
        end

        if mode == 'standalone' then
            return 'standalone'
        end
    end

    return 'standalone'
end

local function resolveFrameworkMode()
    local configuredMode = getConfiguredMode()
    if configuredMode == 'auto' then
        return detectFrameworkMode()
    end

    return configuredMode
end

local function isDatabaseRequiredForMode(mode)
    local requiredModes = type(Config.DatabaseRequiredModes) == 'table' and Config.DatabaseRequiredModes or nil
    if requiredModes == nil then
        return mode == 'qbx'
    end

    return requiredModes[mode] == true
end

local function hasMySqlRuntime()
    return type(MySQL) == 'table'
        and type(MySQL.query) == 'table'
        and type(MySQL.query.await) == 'function'
end

local function makeStubMethod(resolver)
    local function getResult(...)
        if type(resolver) == 'function' then
            return resolver(...)
        end

        return resolver
    end

    return setmetatable({
        await = function(...)
            return getResult(...)
        end,
    }, {
        __call = function(_, ...)
            return getResult(...)
        end,
    })
end

local resolvedMode = resolveFrameworkMode()
local databaseRequired = isDatabaseRequiredForMode(resolvedMode)
local databaseAvailable = hasMySqlRuntime()

CortexDatabase = {
    mode = resolvedMode,
    required = databaseRequired,
    available = databaseAvailable,
    stubbed = false,
}

if not databaseAvailable and databaseRequired then
    error(('[cortex_mdt] oxmysql is required when framework mode resolves to "%s".'):format(resolvedMode))
end

if not databaseAvailable then
    local stubInsertId = 0

    MySQL = {
        query = makeStubMethod({}),
        update = makeStubMethod(0),
        insert = makeStubMethod(function()
            stubInsertId = stubInsertId + 1
            return stubInsertId
        end),
        scalar = makeStubMethod(nil),
        single = makeStubMethod(nil),
        transaction = makeStubMethod(true),
        prepare = makeStubMethod({}),
        rawExecute = makeStubMethod({}),
    }

    CortexDatabase.available = true
    CortexDatabase.stubbed = true

    print(('[^3cortex_mdt^0] SQL backend disabled for "%s" mode; using no-op MySQL shim.'):format(resolvedMode))
end
