local resourceName = GetCurrentResourceName()
local resourceVersion = GetResourceMetadata(resourceName, 'version', 0) or '1.0.0'
local activeFrameworkMode
local StandaloneCivilian = dofile(('%s/server/standalone.lua'):format(GetResourcePath(resourceName)))

local function safeString(value)
    if value == nil then
        return ''
    end

    return tostring(value)
end

local function trim(value)
    return safeString(value):match('^%s*(.-)%s*$') or ''
end

local function readText(container, keys)
    if type(container) ~= 'table' then
        return ''
    end

    for i = 1, #keys do
        local raw = container[keys[i]]
        if raw ~= nil then
            local text = trim(raw)
            if text ~= '' then
                return text
            end
        end
    end

    return ''
end

local function splitName(fullName)
    local name = trim(fullName)

    if name == '' then
        return '', ''
    end

    local firstName, lastName = name:match('^(%S+)%s+(.+)$')

    if firstName and lastName then
        return trim(firstName), trim(lastName)
    end

    return name, ''
end

local function titleCase(value)
    local input = trim(value):gsub('_', ' ')

    if input == '' then
        return ''
    end

    return input:gsub('(%a)([%w\']*)', function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

local function buildShortCode(label, fallback)
    local source = trim(label)

    if source == '' then
        source = trim(fallback)
    end

    if source == '' then
        return 'MDT'
    end

    local short = {}

    for word in source:gmatch('[%w]+') do
        short[#short + 1] = word:sub(1, 1):upper()

        if #short == 4 then
            break
        end
    end

    if #short == 0 then
        return source:sub(1, 4):upper()
    end

    return table.concat(short)
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

local function getConfiguredMode()
    local configuredMode = trim(Config.FrameworkMode)

    if configuredMode == '' then
        configuredMode = trim(Config.Framework)
    end

    return normalizeMode(configuredMode)
end

local function getFrameworkConfig(mode)
    return type(Config.Frameworks) == 'table' and type(Config.Frameworks[mode]) == 'table'
        and Config.Frameworks[mode]
        or {}
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

local function refreshFrameworkMode(reason)
    local configuredMode = getConfiguredMode()
    local resolvedMode = configuredMode == 'auto' and detectFrameworkMode() or configuredMode

    if activeFrameworkMode ~= resolvedMode then
        activeFrameworkMode = resolvedMode
        print(('[^2cortex_mdt^0] Framework mode set to %s%s'):format(
            resolvedMode,
            reason and reason ~= '' and (' (%s)'):format(reason) or ''
        ))
    elseif reason == 'startup' then
        print(('[^2cortex_mdt^0] Framework mode set to %s (%s)'):format(resolvedMode, reason))
    end

    return activeFrameworkMode
end

local function resolveDepartmentKey(key, fallback)
    local aliasKey = trim(key):lower()

    if aliasKey ~= '' and type(Config.DepartmentAliases) == 'table' and trim(Config.DepartmentAliases[aliasKey]) ~= '' then
        return trim(Config.DepartmentAliases[aliasKey]):lower()
    end

    if aliasKey ~= '' then
        return aliasKey
    end

    local fallbackKey = trim(fallback):lower()
    if fallbackKey ~= '' then
        return fallbackKey
    end

    return trim(Config.DefaultDepartment):lower()
end

local function getDepartmentEntry(key, fallbackLabel)
    local departmentKey = resolveDepartmentKey(key)
    local departments = type(Config.Departments) == 'table' and Config.Departments or {}
    local department = departments[departmentKey]

    if type(department) == 'table' then
        return departmentKey, department
    end

    local defaultKey = trim(Config.DefaultDepartment):lower()
    local defaultDepartment = departments[defaultKey]

    if type(defaultDepartment) == 'table' then
        return defaultKey, defaultDepartment
    end

    return departmentKey, {
        label = trim(fallbackLabel) ~= '' and trim(fallbackLabel) or titleCase(departmentKey),
        short = buildShortCode(fallbackLabel, departmentKey),
    }
end

local function getServiceRank(fallback, departmentKey, rankFallback)
    local rank = trim(fallback)

    if rank ~= '' then
        return titleCase(rank)
    end

    local aliasKey = trim(departmentKey):lower()
    local configured = type(Config.ServiceRanks) == 'table' and Config.ServiceRanks[aliasKey] or nil

    if trim(configured) ~= '' then
        return trim(configured)
    end

    local fallbackRank = trim(rankFallback)
    if fallbackRank ~= '' then
        return fallbackRank
    end

    return 'Officer'
end

local function createOfficerPayload(source, data)
    local playerName = GetPlayerName(source) or ''
    local firstName = trim(data.firstName)
    local lastName = trim(data.lastName)

    if firstName == '' and lastName == '' then
        firstName, lastName = splitName(trim(data.fullName) ~= '' and data.fullName or playerName)
    end

    local departmentKey, department = getDepartmentEntry(data.departmentKey, data.departmentLabel)
    local callsign = trim(data.callsign)

    if callsign == '' then
        callsign = tostring(source)
    end

    return {
        firstName = firstName ~= '' and firstName or 'Unknown',
        lastName = lastName,
        rank = getServiceRank(data.rank, departmentKey, data.rankFallback),
        callsign = callsign,
        departmentKey = departmentKey,
        department = trim(department.label) ~= '' and trim(department.label) or 'Department',
        departmentShort = trim(department.short) ~= '' and trim(department.short) or buildShortCode(department.label, departmentKey),
        avatar = nil,
        frameworkMode = refreshFrameworkMode(),
    }
end

local function buildStandaloneOfficer(source)
    local standaloneConfig = getFrameworkConfig('standalone')
    local officer = type(standaloneConfig.officer) == 'table' and standaloneConfig.officer or {}

    return createOfficerPayload(source, {
        firstName = officer.firstName,
        lastName = officer.lastName,
        rank = officer.rank,
        callsign = officer.callsign,
        departmentKey = officer.department or Config.DefaultDepartment,
        rankFallback = 'Officer',
    })
end

local function buildQbxOfficer(source)
    local qbxResource = getQbxResourceName()

    if not isResourceStarted(qbxResource) then
        return nil
    end

    local ok, player = pcall(function()
        return exports[qbxResource]:GetPlayer(source)
    end)

    if not ok or not player or type(player.PlayerData) ~= 'table' then
        return nil
    end

    local qbxConfig = getFrameworkConfig('qbx')
    local playerData = player.PlayerData
    local charinfo = type(playerData.charinfo) == 'table' and playerData.charinfo or {}
    local job = type(playerData.job) == 'table' and playerData.job or {}
    local grade = type(job.grade) == 'table' and job.grade or {}
    local metadata = type(playerData.metadata) == 'table' and playerData.metadata or {}
    local metadataKeys = type(qbxConfig.callsignMetadataKeys) == 'table' and qbxConfig.callsignMetadataKeys or { 'callsign', 'callSign' }
    local jobKey = trim(job.name):lower()
    local mappedDepartment = type(qbxConfig.jobDepartmentMap) == 'table' and qbxConfig.jobDepartmentMap[jobKey] or nil

    return createOfficerPayload(source, {
        firstName = readText(charinfo, { 'firstname', 'firstName', 'first_name' }),
        lastName = readText(charinfo, { 'lastname', 'lastName', 'last_name' }),
        fullName = readText(playerData, { 'name' }),
        rank = readText(grade, { 'name', 'label' }),
        callsign = readText(metadata, metadataKeys),
        departmentKey = trim(mappedDepartment) ~= '' and mappedDepartment or (jobKey ~= '' and jobKey or qbxConfig.fallbackDepartment),
        departmentLabel = readText(job, { 'label' }),
        rankFallback = qbxConfig.rankFallback,
    })
end

local function buildErsOfficer(source)
    local ersResource = resolveErsResourceName()

    if not isResourceStarted(ersResource) then
        return nil
    end

    local ersConfig = getFrameworkConfig('ers')
    local ok, responder = pcall(function()
        return exports[ersResource]:cortexGetResponder(source)
    end)

    if not ok or type(responder) ~= 'table' then
        responder = nil
    end

    local serviceType = responder and readText(responder, { 'serviceType', 'serviceName', 'service' }) or ''

    if serviceType == '' then
        local okService, value = pcall(function()
            return exports[ersResource]:getPlayerActiveServiceType(source)
        end)

        if okService then
            serviceType = trim(value)
        end
    end

    local onShift = responder and responder.onDuty or nil

    if onShift == nil then
        local okShift, value = pcall(function()
            return exports[ersResource]:getIsPlayerOnShift(source)
        end)

        if okShift then
            onShift = value
        end
    end

    if responder == nil and onShift ~= true then
        return nil
    end

    local serviceKey = trim(serviceType):lower()
    local mappedDepartment = type(ersConfig.serviceDepartmentMap) == 'table' and ersConfig.serviceDepartmentMap[serviceKey] or nil

    return createOfficerPayload(source, {
        firstName = responder and readText(responder, { 'firstName' }) or '',
        lastName = responder and readText(responder, { 'lastName' }) or '',
        fullName = responder and readText(responder, { 'fullName', 'name' }) or '',
        rank = responder and readText(responder, { 'rank', 'rankLabel', 'grade' }) or '',
        callsign = responder and readText(responder, { 'mdtCallsign', 'callsign' }) or ersConfig.callsignFallback,
        departmentKey = trim(mappedDepartment) ~= '' and mappedDepartment or (serviceKey ~= '' and serviceKey or ersConfig.fallbackDepartment),
        departmentLabel = responder and readText(responder, { 'serviceLabel', 'serviceName' }) or serviceType,
        rankFallback = ersConfig.rankFallback,
    })
end

local function buildOfficerProfile(source)
    local mode = refreshFrameworkMode()
    local officer

    if mode == 'ers' then
        officer = buildErsOfficer(source)
    elseif mode == 'qbx' then
        officer = buildQbxOfficer(source)
    end

    if not officer then
        officer = buildStandaloneOfficer(source)
    end

    officer.frameworkMode = mode

    return officer
end

local function isStandaloneCivilianEnabled()
    local standaloneConfig = type(Config.StandaloneCivilianMode) == 'table' and Config.StandaloneCivilianMode or {}

    if standaloneConfig.enabled == false then
        return false
    end

    return refreshFrameworkMode() == 'standalone'
end

local function standaloneCivilianUnavailable()
    return {
        ok = false,
        standaloneEnabled = false,
        frameworkMode = refreshFrameworkMode(),
        error = 'Standalone civilian mode is only available while the MDT is running in standalone framework mode.',
    }
end

lib.callback.register('cortex_mdt:getOfficerProfile', function(source)
    return buildOfficerProfile(source)
end)

lib.callback.register('cortex_mdt:getCivilianProfile', function(source)
    local profile = StandaloneCivilian.getCivilianProfile(source)
    profile.frameworkMode = refreshFrameworkMode()
    profile.standaloneEnabled = isStandaloneCivilianEnabled()
    return profile
end)

lib.callback.register('cortex_mdt:getStandaloneCivilianState', function(source)
    if not isStandaloneCivilianEnabled() then
        return standaloneCivilianUnavailable()
    end

    local payload = StandaloneCivilian.getState(source)
    payload.ok = true
    payload.frameworkMode = refreshFrameworkMode()
    payload.standaloneEnabled = true
    return payload
end)

lib.callback.register('cortex_mdt:generateStandaloneCivilian', function(source, payload)
    if not isStandaloneCivilianEnabled() then
        return standaloneCivilianUnavailable()
    end

    local citizen, err = StandaloneCivilian.generateCitizen(source, payload)
    if not citizen then
        return {
            ok = false,
            standaloneEnabled = true,
            frameworkMode = refreshFrameworkMode(),
            error = err or 'Unable to generate civilian.',
        }
    end

    local response = StandaloneCivilian.getState(source)
    response.ok = true
    response.citizen = citizen
    response.frameworkMode = refreshFrameworkMode()
    response.standaloneEnabled = true
    return response
end)

lib.callback.register('cortex_mdt:claimStandaloneCivilian', function(source, citizenId)
    if not isStandaloneCivilianEnabled() then
        return standaloneCivilianUnavailable()
    end

    local citizen, err = StandaloneCivilian.claimCitizen(source, citizenId)
    if not citizen then
        return {
            ok = false,
            standaloneEnabled = true,
            frameworkMode = refreshFrameworkMode(),
            error = err or 'Unable to claim civilian.',
        }
    end

    local response = StandaloneCivilian.getState(source)
    response.ok = true
    response.citizen = citizen
    response.frameworkMode = refreshFrameworkMode()
    response.standaloneEnabled = true
    return response
end)

lib.callback.register('cortex_mdt:deleteStandaloneCivilian', function(source, citizenId)
    if not isStandaloneCivilianEnabled() then
        return standaloneCivilianUnavailable()
    end

    local ok, err = StandaloneCivilian.deleteCitizen(source, citizenId)
    if not ok then
        return {
            ok = false,
            standaloneEnabled = true,
            frameworkMode = refreshFrameworkMode(),
            error = err or 'Unable to delete civilian.',
        }
    end

    local response = StandaloneCivilian.getState(source)
    response.ok = true
    response.frameworkMode = refreshFrameworkMode()
    response.standaloneEnabled = true
    return response
end)

exports('getFrameworkMode', function()
    return refreshFrameworkMode()
end)

AddEventHandler('onResourceStart', function(startedResource)
    if startedResource == resourceName or startedResource == getQbxResourceName() then
        refreshFrameworkMode(('resource started: %s'):format(startedResource))
        return
    end

    local ersResources = getErsResourceNames()
    for i = 1, #ersResources do
        if startedResource == ersResources[i] then
            refreshFrameworkMode(('resource started: %s'):format(startedResource))
            return
        end
    end
end)

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource == getQbxResourceName() then
        refreshFrameworkMode(('resource stopped: %s'):format(stoppedResource))
        return
    end

    local ersResources = getErsResourceNames()
    for i = 1, #ersResources do
        if stoppedResource == ersResources[i] then
            refreshFrameworkMode(('resource stopped: %s'):format(stoppedResource))
            return
        end
    end
end)

AddEventHandler('playerDropped', function()
    StandaloneCivilian.handlePlayerDropped(source)
end)

print(('[^2cortex_mdt^0] Server started - v%s'):format(resourceVersion))
refreshFrameworkMode('startup')
