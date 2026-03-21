local isOpen = false
local currentMode = 'pd'

local function awaitServerCallback(name, payload)
    local ok, response = pcall(function()
        return lib.callback.await(name, false, payload)
    end)

    if not ok then
        return nil
    end

    return response
end

local function buildFallbackOfficer()
    local dept = Config.Departments[Config.DefaultDepartment] or Config.Departments['police']
    local playerName = GetPlayerName(PlayerId()) or 'Unknown'

    return {
        firstName = playerName,
        lastName = '',
        rank = Config.ServiceRanks and Config.ServiceRanks[Config.DefaultDepartment] or 'Officer',
        callsign = tostring(GetPlayerServerId(PlayerId())),
        department = dept and dept.label or 'Department',
        departmentShort = dept and dept.short or 'MDT',
        avatar = nil,
        frameworkMode = 'standalone',
    }
end

local function buildFallbackCivilian()
    local playerName = GetPlayerName(PlayerId()) or 'Unknown'
    return {
        firstName = playerName,
        lastName = '',
        citizenId = 'LS-' .. tostring(GetPlayerServerId(PlayerId())),
    }
end

local function getOfficerProfile()
    local officer = awaitServerCallback('cortex_mdt:getOfficerProfile')

    if type(officer) ~= 'table' then
        return buildFallbackOfficer()
    end

    return officer
end

local function getCivilianProfile()
    local civilian = awaitServerCallback('cortex_mdt:getCivilianProfile')

    if type(civilian) ~= 'table' then
        return buildFallbackCivilian()
    end

    return civilian
end

local function openMDT()
    if isOpen then return end
    isOpen = true
    currentMode = 'pd'

    SendNUIMessage({
        action = 'cortex_mdt:show',
        data = {
            mode = 'pd',
            officer = getOfficerProfile(),
        },
    })

    SetNuiFocus(true, true)
end

local function openCivilian()
    if isOpen then return end
    isOpen = true
    currentMode = 'civilian'

    SendNUIMessage({
        action = 'cortex_mdt:show',
        data = {
            mode = 'civilian',
            civilian = getCivilianProfile(),
        },
    })

    SetNuiFocus(true, true)
end

local function closeMDT()
    if not isOpen then return end
    isOpen = false
    currentMode = 'pd'

    SendNUIMessage({
        action = 'cortex_mdt:hide',
    })

    SetNuiFocus(false, false)
end

RegisterNUICallback('cortex_mdt:close', function(_, cb)
    closeMDT()
    cb('ok')
end)

RegisterNUICallback('cortex_mdt:getStandaloneCivilianState', function(_, cb)
    local response = awaitServerCallback('cortex_mdt:getStandaloneCivilianState') or {
        ok = false,
        error = 'Failed to load standalone civilian state.',
    }

    cb(response)
end)

RegisterNUICallback('cortex_mdt:generateStandaloneCivilian', function(data, cb)
    local response = awaitServerCallback('cortex_mdt:generateStandaloneCivilian', data) or {
        ok = false,
        error = 'Failed to generate civilian.',
    }

    cb(response)
end)

RegisterNUICallback('cortex_mdt:claimStandaloneCivilian', function(data, cb)
    local response = awaitServerCallback('cortex_mdt:claimStandaloneCivilian', data and data.citizenId) or {
        ok = false,
        error = 'Failed to claim civilian.',
    }

    cb(response)
end)

RegisterNUICallback('cortex_mdt:deleteStandaloneCivilian', function(data, cb)
    local response = awaitServerCallback('cortex_mdt:deleteStandaloneCivilian', data and data.citizenId) or {
        ok = false,
        error = 'Failed to delete civilian.',
    }

    cb(response)
end)

RegisterCommand(Config.OpenCommand, function()
    if isOpen then
        closeMDT()
    else
        openMDT()
    end
end, false)

RegisterKeyMapping(Config.OpenCommand, 'Open Cortex MDT', 'keyboard', Config.OpenKey)

RegisterCommand('civilian', function()
    if isOpen then
        closeMDT()
    else
        openCivilian()
    end
end, false)
