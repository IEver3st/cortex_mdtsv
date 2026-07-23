local resourceName = GetCurrentResourceName()
local resourceVersion = GetResourceMetadata(resourceName, 'version', 0) or '1.0.0'
local activeFrameworkMode
local pendingErsShiftUpdates = {}
local buildOfficerProfile
local ERS_PENDING_SHIFT_TTL_MS = 8000
local ERS_SHIFT_CONFIRM_TIMEOUT_MS = 1800
local ERS_SHIFT_RETRY_TIMEOUT_MS = 1000

local function loadResourceModule(path)
    local chunk = LoadResourceFile(resourceName, path)

    if not chunk then
        error(('[cortex_mdt] Missing resource module: %s'):format(path))
    end

    local fn, err = load(chunk, ('@%s/%s'):format(resourceName, path), 't', _ENV)

    if not fn then
        error(('[cortex_mdt] Failed to compile %s: %s'):format(path, err))
    end

    local result = fn()

    if result == nil then
        error(('[cortex_mdt] Resource module returned no value: %s'):format(path))
    end

    return result
end

local StandaloneCivilian = loadResourceModule('server/standalone.lua')
local LocalMode = loadResourceModule('server/localMode.lua')
CortexStandaloneCivilian = StandaloneCivilian

local rawRegisterCallback = lib and lib.callback and lib.callback.register
local registeredServerCallbacks = {}

local function executeServerCallback(name, source, ...)
    local handler = registeredServerCallbacks[name]

    if type(handler) ~= 'function' then
        return {
            ok = false,
            error = ('Server callback is not registered: %s'):format(tostring(name)),
        }
    end

    local args = { ... }
    local ok, result = xpcall(function()
        return handler(source, table.unpack(args))
    end, debug.traceback)

    if not ok then
        print(('[cortex_mdt] ERROR in server callback %s: %s'):format(name, result))
        return {
            ok = false,
            error = 'Server callback failed. Check server console.',
        }
    end

    if result == nil then
        print(('[cortex_mdt] WARNING: Server callback %s returned nil on the server'):format(name))
        return {
            ok = false,
            error = 'Server callback returned no response.',
        }
    end

    return result
end

if type(rawRegisterCallback) == 'function' then
    lib.callback.register = function(name, handler)
        registeredServerCallbacks[name] = handler

        rawRegisterCallback(name, function(source, ...)
            return executeServerCallback(name, source, ...)
        end)
    end
else
    print('[cortex_mdt] WARNING: lib.callback.register is unavailable. Server callbacks will not be registered.')
end

RegisterNetEvent('cortex_mdt:serverCallback', function(name, requestId, ...)
    local source = source
    local response = executeServerCallback(name, source, ...)
    TriggerClientEvent('cortex_mdt:serverCallbackResponse', source, requestId, response)
end)

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

local function getErsShiftState(source, ersResource)
    local onShift = nil
    local serviceType = ''

    local okService, serviceValue = pcall(function()
        return exports[ersResource]:getPlayerActiveServiceType(source)
    end)

    if okService then
        serviceType = trim(serviceValue):lower()
    end

    local okShift, shiftValue = pcall(function()
        return exports[ersResource]:getIsPlayerOnShift(source)
    end)

    if okShift then
        onShift = shiftValue == true
    end

    return onShift, serviceType
end

AddEventHandler('cortex_mdt:ers:shiftConfirmed', function(playerSource, isOnShift, serviceType)
    local source = tonumber(playerSource)

    if not source or source < 1 then
        return
    end

    pendingErsShiftUpdates[source] = {
        onShift = isOnShift == true,
        serviceType = trim(serviceType):lower(),
        receivedAt = GetGameTimer(),
    }
end)

AddEventHandler('playerDropped', function()
    pendingErsShiftUpdates[source] = nil
end)

local function getErsShiftConfirmation(source, ersResource)
    local pending = pendingErsShiftUpdates[source]

    if type(pending) == 'table' then
        local receivedAt = tonumber(pending.receivedAt) or 0

        if receivedAt > 0 and (GetGameTimer() - receivedAt) <= ERS_PENDING_SHIFT_TTL_MS then
            return pending.onShift == true, trim(pending.serviceType):lower()
        end

        pendingErsShiftUpdates[source] = nil
    end

    local okConfirm, confirmation = pcall(function()
        return exports[ersResource]:cortexConfirmShift(source)
    end)

    if okConfirm and type(confirmation) == 'table' and confirmation.confirmed then
        return confirmation.onShift == true, trim(confirmation.serviceType):lower()
    end

    return getErsShiftState(source, ersResource)
end

local function waitForErsShiftState(source, ersResource, shouldBeOnShift, expectedServiceType, timeoutMs)
    local desiredState = shouldBeOnShift == true
    local expectedService = trim(expectedServiceType):lower()
    local timeout = tonumber(timeoutMs) or ERS_SHIFT_RETRY_TIMEOUT_MS
    local startedAt = GetGameTimer()

    while (GetGameTimer() - startedAt) < timeout do
        local onShift, serviceType = getErsShiftConfirmation(source, ersResource)
        serviceType = trim(serviceType):lower()

        if desiredState == true then
            if onShift == true and (expectedService == '' or serviceType == expectedService) then
                return true, serviceType
            end

            if onShift == true and serviceType == '' and expectedService ~= '' then
                return true, expectedService
            end

            if onShift == true and serviceType ~= '' and expectedService ~= '' and serviceType ~= expectedService then
                return false, serviceType
            end
        else
            if onShift ~= true then
                return true, serviceType
            end

            if serviceType ~= '' and expectedService ~= '' and serviceType ~= expectedService then
                return false, serviceType
            end
        end

        Wait(200)
    end

    local onShift, serviceType = getErsShiftConfirmation(source, ersResource)
    serviceType = trim(serviceType):lower()

    if desiredState == true then
        if onShift == true and serviceType == '' and expectedService ~= '' then
            return true, expectedService
        end

        return onShift == true and (expectedService == '' or serviceType == expectedService), serviceType
    end

    return onShift ~= true, serviceType
end

local function ensureErsPoliceShift(source, ersResource)
    local onShift, serviceType = getErsShiftConfirmation(source, ersResource)
    serviceType = trim(serviceType):lower()

    if onShift == true and serviceType == 'police' then
        return true, serviceType
    end

    if onShift == true and serviceType ~= '' and serviceType ~= 'police' then
        return false, ('You are currently on %s shift. Switch to police to access MDT.'):format(titleCase(serviceType))
    end

    pendingErsShiftUpdates[source] = nil

    local okToggle, toggleError = pcall(function()
        return exports[ersResource]:toggleShift(source, 'police')
    end)

    if not okToggle then
        print(('[cortex_mdt] ERROR: ERS toggleShift failed for source %s: %s'):format(source, tostring(toggleError)))
        return false, 'Unable to toggle police shift in ERS. Please try again.'
    end

    local confirmed, confirmedService = waitForErsShiftState(source, ersResource, true, 'police', ERS_SHIFT_CONFIRM_TIMEOUT_MS)

    if confirmedService ~= '' and confirmedService ~= 'police' then
        return false, ('You are currently on %s shift. Switch to police to access MDT.'):format(titleCase(confirmedService))
    end

    if not confirmed then
        return false, 'Unable to confirm police shift. Please retry biometric login.'
    end

    return true, confirmedService ~= '' and confirmedService or 'police'
end

local function clearPendingErsShiftUpdate(source)
    pendingErsShiftUpdates[source] = nil
end

local function ensureErsPoliceShiftOff(source, ersResource)
    local onShift, serviceType = getErsShiftConfirmation(source, ersResource)
    serviceType = trim(serviceType):lower()

    if onShift ~= true then
        return true, serviceType
    end

    if serviceType ~= '' and serviceType ~= 'police' then
        return false, ('You are currently on %s shift. Switch to police before going off duty in MDT.'):format(titleCase(serviceType))
    end

    clearPendingErsShiftUpdate(source)

    local okToggle, toggleError = pcall(function()
        return exports[ersResource]:toggleShift(source, 'police')
    end)

    if not okToggle then
        print(('[cortex_mdt] ERROR: ERS toggleShift(off) failed for source %s: %s'):format(source, tostring(toggleError)))
        return false, 'Unable to toggle police shift off in ERS. Please try again.'
    end

    local confirmed, confirmedService = waitForErsShiftState(source, ersResource, false, 'police', ERS_SHIFT_CONFIRM_TIMEOUT_MS)

    confirmedService = trim(confirmedService):lower()

    if confirmedService ~= '' and confirmedService ~= 'police' then
        return false, ('You are currently on %s shift. Switch to police before going off duty in MDT.'):format(titleCase(confirmedService))
    end

    if not confirmed then
        return false, 'Unable to confirm police shift was cleared in ERS. Please try again.'
    end

    return true, confirmedService
end

local function syncErsPoliceDuty(source, shouldBeOnDuty)
    local mode = refreshFrameworkMode()

    if mode ~= 'ers' then
        return {
            ok = true,
            synced = false,
            serviceType = '',
            frameworkMode = mode,
        }
    end

    local ersResource = resolveErsResourceName()

    if not isResourceStarted(ersResource) then
        return {
            ok = false,
            error = 'ERS is not started. Please contact server staff.',
            synced = false,
            serviceType = '',
            frameworkMode = mode,
        }
    end

    local ok, errOrService
    if shouldBeOnDuty then
        ok, errOrService = ensureErsPoliceShift(source, ersResource)
        if not ok then
            return {
                ok = false,
                error = errOrService or 'Unable to confirm police shift in ERS.',
                synced = false,
                serviceType = 'police',
                frameworkMode = mode,
            }
        end

        return {
            ok = true,
            synced = true,
            serviceType = 'police',
            frameworkMode = mode,
        }
    end

    ok, errOrService = ensureErsPoliceShiftOff(source, ersResource)
    if not ok then
        return {
            ok = false,
            error = errOrService or 'Unable to clear police shift in ERS.',
            synced = false,
            serviceType = 'police',
            frameworkMode = mode,
        }
    end

    return {
        ok = true,
        synced = true,
        serviceType = trim(errOrService):lower(),
        frameworkMode = mode,
    }
end

CortexDutyBridge = {
    getFrameworkMode = refreshFrameworkMode,
    syncErsPoliceDuty = syncErsPoliceDuty,
    buildOfficerProfile = buildOfficerProfile,
}

buildOfficerProfile = function(source, skipLocalPreferences)
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

    if mode ~= 'qbx' and not skipLocalPreferences then
        officer = LocalMode.applyProfilePreferences(source, officer)
    end

    officer.frameworkMode = mode

    return officer
end

CortexDutyBridge.buildOfficerProfile = buildOfficerProfile

if type(lib) == 'table' and type(lib.callback) == 'table' and type(lib.callback.register) == 'function' then
    lib.callback.register('cortex_mdt:ersBiometricLogin', function(source)
        local dutyResult = syncErsPoliceDuty(source, true)

        if not dutyResult or dutyResult.ok ~= true then
            return dutyResult or {
                ok = false,
                error = 'Unable to confirm police shift in ERS.',
            }
        end

        return {
            ok = true,
            officer = buildOfficerProfile(source),
            shiftType = dutyResult.serviceType or 'police',
            synced = dutyResult.synced == true,
            frameworkMode = dutyResult.frameworkMode,
        }
    end)

    lib.callback.register('cortex_mdt:getOfficerProfile', function(source)
        return buildOfficerProfile(source)
    end)

    lib.callback.register('cortex_mdt:getCivilianProfile', function(source)
        local standalone = rawget(_G, 'CortexStandaloneCivilian')
        if standalone and type(standalone.getCivilianProfile) == 'function' then
            return standalone.getCivilianProfile(source)
        end

        local playerName = GetPlayerName(source) or 'Unknown'
        local firstName, lastName = splitName(playerName)
        if trim(firstName) == '' then
            firstName = playerName
            lastName = ''
        end

        return {
            firstName = firstName,
            lastName = lastName,
            citizenId = nil,
        }
    end)
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

local function extractCitizenId(data)
    if type(data) == 'string' or type(data) == 'number' then
        return trim(data)
    end

    if type(data) == 'table' then
        return trim(data.citizenId or data.citizen_id or data.id or '')
    end

    return ''
end

local function buildStandaloneCivilianResponse(source, extra)
    local payload = StandaloneCivilian.getState(source) or {}
    payload.ok = true
    payload.standaloneEnabled = true
    payload.frameworkMode = refreshFrameworkMode()

    if type(extra) == 'table' then
        for key, value in pairs(extra) do
            payload[key] = value
        end
    end

    return payload
end

local function standaloneCivilianActionError(message)
    return {
        ok = false,
        standaloneEnabled = true,
        frameworkMode = refreshFrameworkMode(),
        error = message or 'Standalone civilian request failed.',
    }
end

-- Session civilian generation/claiming used by the civilian MDT portal.
-- These were previously missing, which made the UI report "not standalone"
-- even when Config.FrameworkMode was already 'standalone'.
lib.callback.register('cortex_mdt:getStandaloneCivilianState', function(source)
    if not isStandaloneCivilianEnabled() then
        return standaloneCivilianUnavailable()
    end

    return buildStandaloneCivilianResponse(source)
end)

lib.callback.register('cortex_mdt:generateStandaloneCivilian', function(source, data)
    if not isStandaloneCivilianEnabled() then
        return standaloneCivilianUnavailable()
    end

    local citizen, err = StandaloneCivilian.generateCitizen(source, data)
    if not citizen then
        return standaloneCivilianActionError(err or 'Failed to generate civilian.')
    end

    return buildStandaloneCivilianResponse(source, { citizen = citizen })
end)

lib.callback.register('cortex_mdt:registerStandaloneCivilian', function(source, data)
    if not isStandaloneCivilianEnabled() then
        return standaloneCivilianUnavailable()
    end

    local citizen, err = StandaloneCivilian.registerCivilian(source, data)
    if not citizen then
        return standaloneCivilianActionError(err or 'Failed to register civilian.')
    end

    return buildStandaloneCivilianResponse(source, { citizen = citizen })
end)

lib.callback.register('cortex_mdt:claimStandaloneCivilian', function(source, data)
    if not isStandaloneCivilianEnabled() then
        return standaloneCivilianUnavailable()
    end

    local citizenId = extractCitizenId(data)
    if citizenId == '' then
        return standaloneCivilianActionError('Citizen ID is required.')
    end

    local citizen, err = StandaloneCivilian.claimCitizen(source, citizenId)
    if not citizen then
        return standaloneCivilianActionError(err or 'Failed to claim civilian.')
    end

    return buildStandaloneCivilianResponse(source, { citizen = citizen })
end)

lib.callback.register('cortex_mdt:unclaimStandaloneCivilian', function(source, data)
    if not isStandaloneCivilianEnabled() then
        return standaloneCivilianUnavailable()
    end

    local citizenId = extractCitizenId(data)
    if citizenId == '' then
        return standaloneCivilianActionError('Citizen ID is required.')
    end

    local citizen, err = StandaloneCivilian.unclaimCitizen(source, citizenId)
    if not citizen then
        return standaloneCivilianActionError(err or 'Failed to unclaim civilian.')
    end

    return buildStandaloneCivilianResponse(source, { citizen = citizen })
end)

lib.callback.register('cortex_mdt:updateStandaloneCivilian', function(source, data)
    if not isStandaloneCivilianEnabled() then
        return standaloneCivilianUnavailable()
    end

    local citizen, err = StandaloneCivilian.updateCitizenProfile(source, data)
    if not citizen then
        return standaloneCivilianActionError(err or 'Failed to update civilian.')
    end

    return buildStandaloneCivilianResponse(source, { citizen = citizen })
end)

lib.callback.register('cortex_mdt:deleteStandaloneCivilian', function(source, data)
    if not isStandaloneCivilianEnabled() then
        return standaloneCivilianUnavailable()
    end

    local citizenId = extractCitizenId(data)
    if citizenId == '' then
        return standaloneCivilianActionError('Citizen ID is required.')
    end

    local ok, err = StandaloneCivilian.deleteCitizen(source, citizenId)
    if not ok then
        return standaloneCivilianActionError(err or 'Failed to delete civilian.')
    end

    return buildStandaloneCivilianResponse(source)
end)

lib.callback.register('cortex_mdt:registerStandaloneVehicle', function(source, data)
    if not isStandaloneCivilianEnabled() then
        return standaloneCivilianUnavailable()
    end

    local vehicle, err = StandaloneCivilian.registerVehicle(source, data)
    if not vehicle then
        return standaloneCivilianActionError(err or 'Failed to register vehicle.')
    end

    return buildStandaloneCivilianResponse(source, { vehicle = vehicle })
end)

lib.callback.register('cortex_mdt:deleteStandaloneVehicle', function(source, data)
    if not isStandaloneCivilianEnabled() then
        return standaloneCivilianUnavailable()
    end

    local vehicleId = ''
    if type(data) == 'string' or type(data) == 'number' then
        vehicleId = trim(data)
    elseif type(data) == 'table' then
        vehicleId = trim(data.vehicleId or data.vehicle_id or data.id or '')
    end

    if vehicleId == '' then
        return standaloneCivilianActionError('Vehicle ID is required.')
    end

    local ok, err = StandaloneCivilian.deleteVehicle(source, vehicleId)
    if not ok then
        return standaloneCivilianActionError(err or 'Failed to delete vehicle.')
    end

    return buildStandaloneCivilianResponse(source)
end)

local fallbackDataWarnings = {}

local FALLBACK_VALID_UNIT_STATUSES = {
    available = true,
    busy = true,
    en_route = true,
    on_scene = true,
    emergency = true,
    off_duty = true,
}

local FALLBACK_UNIT_STATUS_ALIASES = {
    enroute = 'en_route',
    scene = 'on_scene',
    onscene = 'on_scene',
    offduty = 'off_duty',
}

local function isLocalDataMode()
    local mode = refreshFrameworkMode()
    return mode == 'standalone' or mode == 'ers'
end

local function standaloneDataFallbackUnavailable(name)
    return {
        ok = false,
        frameworkMode = refreshFrameworkMode(),
        error = ('%s is unavailable because local-data fallback callbacks are active and server/data.lua did not provide the normal handler.'):format(name),
    }
end

local function noteFallbackDataCallback(name)
    if fallbackDataWarnings[name] then
        return
    end

    fallbackDataWarnings[name] = true
    print(('[cortex_mdt] WARNING: using local-data fallback registration for %s. Check server/data.lua startup if this persists.'):format(name))
end

local function normalizeFallbackUnitStatus(status, fallback)
    local normalized = tostring(status or ''):lower():gsub('%s+', '_')

    if normalized == '' then
        return fallback or 'off_duty'
    end

    normalized = FALLBACK_UNIT_STATUS_ALIASES[normalized] or normalized

    if FALLBACK_VALID_UNIT_STATUSES[normalized] then
        return normalized
    end

    return fallback or 'off_duty'
end

local function buildFallbackDutyResponse(unitState, ersPayload)
    unitState = type(unitState) == 'table' and unitState or {}

    return {
        ok = true,
        status = normalizeFallbackUnitStatus(unitState.status, 'off_duty'),
        assignment = unitState.assignment or '',
        callsign = unitState.callsign or '',
        department = unitState.department or Config.DefaultDepartment or 'police',
        ers = ersPayload and {
            synced = ersPayload.synced == true,
            serviceType = ersPayload.serviceType or '',
        } or nil,
    }
end

local function ensureFallbackOfficerRecord(source, overrides)
    overrides = type(overrides) == 'table' and overrides or {}

    local officerId = LocalMode.getOfficerId(source)
    local officer = officerId and LocalMode.getOfficer(officerId) or nil
    local profile = buildOfficerProfile(source)
    profile = type(profile) == 'table' and profile or {}

    local firstName
    local lastName

    if overrides.useFrameworkDisplayName then
        local fwProfile = buildOfficerProfile(source, true)
        fwProfile = type(fwProfile) == 'table' and fwProfile or {}
        firstName = trim(fwProfile.firstName)
        lastName = trim(fwProfile.lastName)
    else
        firstName = trim(overrides.firstName)
        if firstName == '' and officer then
            firstName = trim(officer.first_name)
        end
        if firstName == '' then
            firstName = trim(profile.firstName)
        end

        lastName = trim(overrides.lastName)
        if lastName == '' and officer then
            lastName = trim(officer.last_name)
        end
        if lastName == '' then
            lastName = trim(profile.lastName)
        end
    end

    local callsign = trim(overrides.callsign)
    if callsign == '' and officer then
        callsign = trim(officer.callsign)
    end
    if callsign == '' then
        callsign = trim(profile.callsign)
    end

    local rank = trim(overrides.rank)
    if rank == '' and officer then
        rank = trim(officer.rank)
    end
    if rank == '' then
        rank = trim(profile.rank)
    end

    local departmentKey = trim(overrides.departmentKey or overrides.department)
    if departmentKey == '' and officer then
        departmentKey = trim(officer.department)
    end
    if departmentKey == '' then
        departmentKey = trim(profile.departmentKey)
    end
    if departmentKey == '' then
        departmentKey = trim(Config.DefaultDepartment)
    end

    if firstName == '' and lastName == '' and callsign == '' then
        return officerId
    end

    return LocalMode.ensureOfficer(source, {
        firstName = firstName,
        lastName = lastName,
        rank = rank,
        callsign = callsign,
        departmentKey = departmentKey,
        certifications = officer and officer.certifications or nil,
    })
end

local function setFallbackOfficerDutyState(officerId, nextStatus, assignment, options)
    options = type(options) == 'table' and options or {}
    nextStatus = normalizeFallbackUnitStatus(nextStatus, 'available')

    if nextStatus == 'off_duty' then
        assignment = nil
    end

    local unitState, err = LocalMode.upsertOfficerUnitState(officerId, nextStatus, assignment)
    if not unitState then
        return {
            ok = false,
            error = err or 'Unable to save duty state.',
        }
    end

    return buildFallbackDutyResponse(unitState, options.ers)
end

local function goFallbackOfficerOnDuty(source, officerId, options)
    options = type(options) == 'table' and options or {}

    local ersResult = syncErsPoliceDuty(source, true)
    if not ersResult or ersResult.ok ~= true then
        return ersResult or {
            ok = false,
            error = 'Unable to confirm police shift in ERS.',
        }
    end

    local response = setFallbackOfficerDutyState(officerId, normalizeFallbackUnitStatus(options.status, 'available'), options.assignment, {
        ers = ersResult,
    })

    if response.ok ~= true and ersResult.synced == true then
        local rollback = syncErsPoliceDuty(source, false)
        if rollback and rollback.ok ~= true then
            print(('[cortex_mdt] ERROR: fallback duty rollback failed for source %s after local-state failure: %s'):format(source, tostring(rollback.error)))
        end
    end

    return response
end

local function goFallbackOfficerOffDuty(source, officerId)
    local ersResult = syncErsPoliceDuty(source, false)
    if not ersResult or ersResult.ok ~= true then
        return ersResult or {
            ok = false,
            error = 'Unable to clear police shift in ERS.',
        }
    end

    return setFallbackOfficerDutyState(officerId, 'off_duty', nil, {
        ers = ersResult,
    })
end

local function registerStandaloneDataFallback(name, handler)
    lib.callback.register(name, function(source, data)
        noteFallbackDataCallback(name)

        if not isLocalDataMode() then
            return standaloneDataFallbackUnavailable(name)
        end

        return handler(source, data)
    end)
end

registerStandaloneDataFallback('cortex_mdt:getDashboard', function()
    local dashboard = LocalMode.getDashboard() or {}
    dashboard.ok = true
    return dashboard
end)

registerStandaloneDataFallback('cortex_mdt:registerOfficer', function(source, data)
    if type(data) ~= 'table' then
        return { ok = false }
    end

    local officerId = ensureFallbackOfficerRecord(source, data)
    return {
        ok = officerId ~= nil,
        officerId = officerId,
    }
end)

registerStandaloneDataFallback('cortex_mdt:globalSearch', function(_, data)
    local query = data and data.query or ''

    if #query < 2 then
        return {
            ok = true,
            results = {
                citizens = {},
                vehicles = {},
                reports = {},
                cases = {},
            },
        }
    end

    return {
        ok = true,
        results = LocalMode.globalSearch(query),
    }
end)

registerStandaloneDataFallback('cortex_mdt:searchCitizens', function(_, data)
    local query = data and data.query or ''

    if #query < 1 then
        return { ok = true, citizens = {} }
    end

    return {
        ok = true,
        citizens = LocalMode.searchCitizens(query, 25),
    }
end)

registerStandaloneDataFallback('cortex_mdt:getCitizen', function(source, data)
    local citizenId = data and data.citizenId
    if not citizenId then
        return { ok = false, error = 'Missing citizen identifier.' }
    end

    local payload = LocalMode.getCitizen(citizenId, source)
    if not payload then
        return { ok = false, error = 'Citizen not found.' }
    end

    return {
        ok = true,
        citizen = payload.citizen,
        vehicles = payload.vehicles,
        licenses = payload.licenses,
        reports = payload.reports,
        warrants = payload.warrants,
        bolos = payload.bolos,
    }
end)

registerStandaloneDataFallback('cortex_mdt:searchVehicles', function(_, data)
    local query = data and data.query or ''

    if #query < 1 then
        return { ok = true, vehicles = {} }
    end

    return {
        ok = true,
        vehicles = LocalMode.searchVehicles(query, 25),
    }
end)

registerStandaloneDataFallback('cortex_mdt:getVehicle', function(source, data)
    local vehicleId = data and data.vehicleId
    if not vehicleId then
        return { ok = false, error = 'Missing vehicle identifier.' }
    end

    local payload = LocalMode.getVehicle(vehicleId, source)
    if not payload then
        return { ok = false, error = 'Vehicle not found.' }
    end

    return {
        ok = true,
        vehicle = payload.vehicle,
        impounds = payload.impounds,
    }
end)

registerStandaloneDataFallback('cortex_mdt:getUnits', function()
    local units = LocalMode.getUnits()
    if type(CortexMdtMergeLiveUnitTelemetry) == 'function' then
        for i = 1, #units do
            CortexMdtMergeLiveUnitTelemetry(units[i])
        end
    end
    return {
        ok = true,
        units = units,
    }
end)

registerStandaloneDataFallback('cortex_mdt:updateUnitStatus', function(source, data)
    if not data or not data.status then
        return { ok = false, error = 'Missing duty status.' }
    end

    local officerId = ensureFallbackOfficerRecord(source)
    if not officerId then
        return { ok = false, error = 'Officer record not found.' }
    end

    local nextStatus = normalizeFallbackUnitStatus(data.status, '__invalid__')
    if not FALLBACK_VALID_UNIT_STATUSES[nextStatus] then
        return { ok = false, error = 'Invalid duty status.' }
    end

    if nextStatus == 'off_duty' then
        return goFallbackOfficerOffDuty(source, officerId)
    end

    local existing = LocalMode.getOfficerUnitRow(officerId)
    if not existing or normalizeFallbackUnitStatus(existing.status, 'off_duty') == 'off_duty' then
        return goFallbackOfficerOnDuty(source, officerId, {
            status = nextStatus,
            assignment = data.assignment,
        })
    end

    return setFallbackOfficerDutyState(officerId, nextStatus, data.assignment)
end)

registerStandaloneDataFallback('cortex_mdt:goOnDuty', function(source, data)
    local officerId = ensureFallbackOfficerRecord(source, type(data) == 'table' and {
        firstName = data.firstName,
        lastName = data.lastName,
        callsign = data.callsign,
        rank = data.rank,
        departmentKey = data.departmentKey or data.department,
    } or nil)

    if not officerId then
        return { ok = false, error = 'Officer record not found.' }
    end

    local existing = LocalMode.getOfficerUnitRow(officerId)
    return goFallbackOfficerOnDuty(source, officerId, {
        status = 'available',
        assignment = existing and existing.assignment or nil,
    })
end)

registerStandaloneDataFallback('cortex_mdt:goOffDuty', function(source)
    local officerId = ensureFallbackOfficerRecord(source)
    if not officerId then
        return { ok = false, error = 'Officer record not found.' }
    end

    return goFallbackOfficerOffDuty(source, officerId)
end)

registerStandaloneDataFallback('cortex_mdt:getRoster', function()
    return {
        ok = true,
        officers = LocalMode.getRoster(),
    }
end)

registerStandaloneDataFallback('cortex_mdt:getAnnouncements', function()
    return {
        ok = true,
        announcements = LocalMode.getAnnouncements(),
    }
end)

registerStandaloneDataFallback('cortex_mdt:createAnnouncement', function(source, data)
    if not data or not data.title or not data.content then
        return { ok = false }
    end

    local officerId = ensureFallbackOfficerRecord(source) or 0
    local announcement = LocalMode.createAnnouncement(source, data)

    if announcement then
        LocalMode.auditLog(officerId, 'announcement_create', 'admin', 'announcement', announcement.id, {
            title = data.title,
        })
    end

    return { ok = announcement ~= nil, announcement = announcement }
end)

registerStandaloneDataFallback('cortex_mdt:deleteAnnouncement', function(source, data)
    if not data or not data.id then
        return { ok = false }
    end

    local officerId = LocalMode.getOfficerId(source) or ensureFallbackOfficerRecord(source) or 0
    local ok = LocalMode.deleteAnnouncement(data.id)

    if ok then
        LocalMode.auditLog(officerId, 'announcement_delete', 'admin', 'announcement', data.id, nil)
    end

    return { ok = ok }
end)

registerStandaloneDataFallback('cortex_mdt:getSettings', function()
    return {
        ok = true,
        settings = {
            motd = LocalMode.getSetting('motd') or '',
        },
    }
end)

registerStandaloneDataFallback('cortex_mdt:updateSetting', function(source, data)
    if not data or not data.key or data.value == nil then
        return { ok = false }
    end

    local officerId = LocalMode.getOfficerId(source) or ensureFallbackOfficerRecord(source) or 0
    LocalMode.updateSetting(data.key, data.value)
    LocalMode.auditLog(officerId, 'setting_update', 'admin', 'setting', nil, { key = data.key })

    return { ok = true }
end)

registerStandaloneDataFallback('cortex_mdt:sendDashboardChat', function(source, data)
    local message = type(data) == 'table' and tostring(data.message or '') or ''
    message = message:gsub('^%s+', ''):gsub('%s+$', '')

    if message == '' then
        return { ok = false, error = 'Message cannot be empty.' }
    end

    if #message > 280 then
        message = message:sub(1, 280)
    end

    local officerId = ensureFallbackOfficerRecord(source) or 0
    local chatMessage = LocalMode.addChatMessage(source, message)

    if chatMessage then
        LocalMode.auditLog(officerId, 'dashboard_chat', 'communication', 'chat', chatMessage.id, nil)
    end

    return { ok = chatMessage ~= nil, message = chatMessage }
end)

registerStandaloneDataFallback('cortex_mdt:saveOfficerAvatar', function(source, data)
    if not data then
        return { ok = false }
    end

    ensureFallbackOfficerRecord(source)
    LocalMode.saveOfficerAvatar(source, data.avatarUrl)
    return { ok = true }
end)

registerStandaloneDataFallback('cortex_mdt:getConfig', function()
    return {
        ok = true,
        config = {
            departments = Config.Departments,
            ranks = Config.Ranks,
            certifications = Config.Certifications,
            reportTemplates = Config.ReportTemplates,
            citizenFlags = Config.CitizenFlags,
            evidenceTypes = Config.EvidenceTypes,
            impoundLots = Config.ImpoundLots,
            unitStatuses = Config.UnitStatuses,
            cameraModels = Config.CameraModels,
            cctv = Config.CCTV,
            licenseTypes = Config.LicenseTypes,
            citations = Config.Citations,
        },
    }
end)

registerStandaloneDataFallback('cortex_mdt:issueCitation', function(source, data)
    if not Config.Citations or Config.Citations.enabled == false then
        return { ok = false, error = 'Citation system is disabled.' }
    end

    local officerId = ensureFallbackOfficerRecord(source)
    if not officerId then
        return { ok = false, error = 'Officer record not found.' }
    end

    return LocalMode.issueCitation(source, data)
end)

registerStandaloneDataFallback('cortex_mdt:getMyCitations', function(source)
    if not Config.Citations or Config.Citations.enabled == false then
        return { ok = true, citations = {} }
    end

    local playerName = GetPlayerName(source) or ''
    local results = LocalMode.getCitationsForCitizen(playerName) or { ok = true, citations = {} }

    local standalone = rawget(_G, 'CortexStandaloneCivilian')
    if standalone and type(standalone.getCivilianProfile) == 'function' then
        local profile = standalone.getCivilianProfile(source)
        if profile and profile.citizenId then
            local byCitizenId = LocalMode.getCitationsForCitizen(profile.citizenId) or { ok = true, citations = {} }
            local seen = {}
            for i = 1, #results.citations do
                seen[results.citations[i].id] = true
            end
            for i = 1, #byCitizenId.citations do
                if not seen[byCitizenId.citations[i].id] then
                    results.citations[#results.citations + 1] = byCitizenId.citations[i]
                end
            end
        end
    end

    table.sort(results.citations, function(a, b)
        return (a.issued_sort or 0) > (b.issued_sort or 0)
    end)

    return results
end)

registerStandaloneDataFallback('cortex_mdt:getCitation', function(_, data)
    if not Config.Citations or Config.Citations.enabled == false then
        return { ok = false, error = 'Citation system is disabled.' }
    end

    local citationId = tonumber(data and data.citationId)
    if not citationId then
        return { ok = false, error = 'Missing citation ID.' }
    end

    return LocalMode.getCitation(citationId)
end)

registerStandaloneDataFallback('cortex_mdt:markCitationViewed', function(_, data)
    if not Config.Citations or Config.Citations.enabled == false then
        return { ok = false }
    end

    local citationId = tonumber(data and data.citationId)
    if not citationId then
        return { ok = false, error = 'Missing citation ID.' }
    end

    return LocalMode.markCitationViewed(citationId)
end)

exports('getFrameworkMode', function()
    return refreshFrameworkMode()
end)

exports('getOfficerData', function(source)
    source = tonumber(source) or source
    if not source then
        return nil
    end

    return buildOfficerProfile(source)
end)

exports('isOfficerOnDuty', function(source)
    source = tonumber(source) or source
    if not source then
        return false
    end

    local officer = buildOfficerProfile(source)
    if type(officer) ~= 'table' then
        return false
    end

    return officer.status ~= 'off_duty'
end)

AddEventHandler('onResourceStart', function(startedResource)
    if startedResource == resourceName then
        refreshFrameworkMode(('resource started: %s'):format(startedResource))
        if Config.Citations and Config.Citations.persist ~= false then
            LocalMode.restoreCitations()
        end
        return
    end

    if startedResource == getQbxResourceName() then
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
