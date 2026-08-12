local isOpen = false
--- Used by client/dispatch.lua to push live unit coords while MDT visible (Units tab, etc.).
CortexMdtNuiOpen = false
local currentMode = 'pd'
local mdtEmoteResourceUsed = nil

local function getMdtEmoteConfig()
    if Config.MDTTabletEmote == false then
        return nil
    end
    local cfg = Config.MDTTabletEmote
    if type(cfg) ~= 'table' or cfg.enabled == false then
        return nil
    end
    local emoteName = cfg.emoteName
    if type(emoteName) ~= 'string' or emoteName == '' then
        return nil
    end
    return cfg
end

local function resolveEmoteResource(cfg)
    local want = cfg.resource
    if type(want) == 'string' and want ~= '' and want ~= 'auto' then
        if GetResourceState(want) == 'started' then
            return want
        end
        return nil
    end
    local candidates = { 'rpemotes', 'rpemotes-reborn' }
    for i = 1, #candidates do
        local r = candidates[i]
        if GetResourceState(r) == 'started' then
            return r
        end
    end
    return nil
end

local function mdtEmoteStart()
    local cfg = getMdtEmoteConfig()
    if not cfg then
        return
    end
    mdtEmoteResourceUsed = nil
    local resName = resolveEmoteResource(cfg)
    if not resName then
        return
    end
    local ex = exports[resName]
    if type(ex) ~= 'table' or type(ex.EmoteCommandStart) ~= 'function' then
        return
    end
    local name = cfg.emoteName
    local ok = pcall(function()
        ex:EmoteCommandStart(name, 0)
    end)
    if not ok then
        ok = pcall(function()
            ex:EmoteCommandStart(name)
        end)
    end
    if ok then
        mdtEmoteResourceUsed = resName
    end
end

local function mdtEmoteStop()
    if not mdtEmoteResourceUsed then
        return
    end
    local resName = mdtEmoteResourceUsed
    mdtEmoteResourceUsed = nil
    local ex = exports[resName]
    if type(ex) ~= 'table' or type(ex.EmoteCancel) ~= 'function' then
        return
    end
    pcall(function()
        ex:EmoteCancel()
    end)
end

local PlayerPedId = PlayerPedId
local GetVehiclePedIsIn = GetVehiclePedIsIn
local GetEntityCoords = GetEntityCoords
local GetClosestVehicle = GetClosestVehicle
local DoesEntityExist = DoesEntityExist
local GetVehicleNumberPlateText = GetVehicleNumberPlateText
local GetEntityModel = GetEntityModel
local GetDisplayNameFromVehicleModel = GetDisplayNameFromVehicleModel
local GetLabelText = GetLabelText
local GetVehicleClass = GetVehicleClass

local MDT_UI_CLICK_PRESETS = {
    exec_navigate = { 'Navigate', 'GTAO_Exec_SecuroServ_Computer_Sounds' },
    warehouse_mouse = { 'Mouse_Click', 'GTAO_Exec_SecuroServ_Warehouse_PC_Sounds' },
    hangar_click = { 'Click_Special', 'GTAO_SMG_Hangar_Computer_Sounds' },
}

local pendingServerCallbacks = {}
local serverCallbackRequestId = 0
local SERVER_CALLBACK_TIMEOUT_MS = 15000

RegisterNetEvent('cortex_mdt:serverCallbackResponse', function(requestId, response)
    local pending = pendingServerCallbacks[requestId]

    if pending then
        pendingServerCallbacks[requestId] = nil
        pending:resolve(response)
    end
end)

RegisterNUICallback('cortex_mdt:playSound', function(data, cb)
    local kind = data and data.kind
    if kind == 'ui_click' then
        local preset = (data and data.preset) or 'exec_navigate'
        local p = MDT_UI_CLICK_PRESETS[preset] or MDT_UI_CLICK_PRESETS.exec_navigate
        PlaySoundFrontend(-1, p[1], p[2], true)
    elseif kind == 'biometric' then
        PlaySoundFrontend(-1, 'Click_Special', 'WEB_NAVIGATION_SOUNDS_PHONE', true)
    elseif kind == 'status' then
        PlaySoundFrontend(-1, 'SELECT', 'HUD_MINI_GAME_SOUNDSET', true)
    elseif kind == 'dashboard' then
        PlaySoundFrontend(-1, 'Show_Source_Menu', 'GTAO_SMG_Hangar_Computer_Sounds', true)
    elseif kind == 'logout' then
        PlaySoundFrontend(-1, 'Logout', 'GTAO_Exec_SecuroServ_Computer_Sounds', true)
    end
    cb({ ok = true })
end)

local function awaitServerCallback(name, payload)
    serverCallbackRequestId = serverCallbackRequestId + 1
    local requestId = serverCallbackRequestId
    local p = promise.new()

    pendingServerCallbacks[requestId] = p
    TriggerServerEvent('cortex_mdt:serverCallback', name, requestId, payload)

    SetTimeout(SERVER_CALLBACK_TIMEOUT_MS, function()
        local pending = pendingServerCallbacks[requestId]

        if pending then
            pendingServerCallbacks[requestId] = nil
            pending:resolve(nil)
        end
    end)

    local ok, response = pcall(function()
        return Citizen.Await(p)
    end)

    if not ok then
        print(('[cortex_mdt] ERROR in awaitServerCallback for %s: %s'):format(name, tostring(response)))
        return nil
    end

    if response == nil then
        print(('[cortex_mdt] WARNING: Server callback %s returned nil response (timeout or no result)'):format(name))
    end

    return response
end

_G.CortexMdtServerCallback = awaitServerCallback

local function trimText(value)
    return tostring(value or ''):match('^%s*(.-)%s*$') or ''
end

local function cleanVehicleLabel(label)
    local trimmed = tostring(label or ''):match('^%s*(.-)%s*$') or ''
    if trimmed == '' then
        return ''
    end

    local translated = GetLabelText(trimmed)
    if translated and translated ~= 'NULL' and translated ~= '' then
        return translated
    end

    return trimmed
end

local function getStandaloneVehicleContext()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        local coords = GetEntityCoords(ped)
        vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 70)
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil, 'You must be inside or standing near a vehicle to register it.'
    end

    local plate = (GetVehicleNumberPlateText(vehicle) or ''):match('^%s*(.-)%s*$') or ''
    if plate == '' then
        return nil, 'Unable to read the vehicle plate.'
    end

    local modelHash = GetEntityModel(vehicle)
    local modelCode = GetDisplayNameFromVehicleModel(modelHash)
    local vehicleClass = GetVehicleClass(vehicle)

    return {
        plate = plate,
        model = cleanVehicleLabel(modelCode),
        vehicleClass = tostring(vehicleClass or ''),
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

    if type(officer) ~= 'table' or officer.ok == false then
        return nil, type(officer) == 'table' and officer.error or 'Officer profile is unavailable.'
    end

    return officer
end

local function getCivilianProfile()
    local civilian = awaitServerCallback('cortex_mdt:getCivilianProfile')

    if type(civilian) ~= 'table' or civilian.ok == false then
        return buildFallbackCivilian()
    end

    return civilian
end

local function runPoliceDutyCommand(args)
    local callsign = trimText(args and args[1])
    local payload = callsign ~= '' and { callsign = callsign } or nil
    local response = awaitServerCallback('cortex_mdt:goOnDuty', payload)

    if type(response) == 'table' and response.ok == true then
        TriggerEvent('cortex_mdtsv:refreshUnitIdentity')
        print(('[cortex_mdt] %s command set duty state to %s.'):format(Config.PoliceCommand or 'police', tostring(response.status or 'available')))
        return
    end

    print(('[cortex_mdt] %s command failed: %s'):format(
        Config.PoliceCommand or 'police',
        type(response) == 'table' and tostring(response.error or 'Unknown error.') or 'Server callback failed.'
    ))
end

local function openMDT()
    if isOpen then return end
    local officer, accessError = getOfficerProfile()
    if not officer then
        print(('[cortex_mdt] MDT access denied: %s'):format(tostring(accessError or 'Officer authorization required.')))
        return
    end

    isOpen = true
    CortexMdtNuiOpen = true
    currentMode = 'pd'

    SendNUIMessage({
        action = 'cortex_mdt:show',
        data = {
            mode = 'pd',
            officer = officer,
        },
    })

    SetNuiFocus(true, true)
    mdtEmoteStart()
end

local function openCivilian()
    if isOpen then return end
    isOpen = true
    CortexMdtNuiOpen = true
    currentMode = 'civilian'

    SendNUIMessage({
        action = 'cortex_mdt:show',
        data = {
            mode = 'civilian',
            civilian = getCivilianProfile(),
            playerName = GetPlayerName(PlayerId()) or 'Unknown',
        },
    })

    SetNuiFocus(true, true)
    mdtEmoteStart()
end

local function closeMDT()
    if not isOpen then return end
    isOpen = false
    CortexMdtNuiOpen = false
    currentMode = 'pd'

    mdtEmoteStop()

    TriggerEvent('cortex_mdtsv:client:mdtClosed')

    SendNUIMessage({
        action = 'cortex_mdt:hide',
    })

    SendNUIMessage({
        action = 'cortex_mdt:hideCitation',
    })

    SetNuiFocus(false, false)
end

RegisterNetEvent('cortex_mdt:client:receiveCitation', function(citation)
    SendNUIMessage({
        action = 'cortex_mdt:showCitation',
        data = citation,
    })
end)

RegisterNUICallback('cortex_mdt:close', function(_, cb)
    closeMDT()
    cb('ok')
end)

RegisterNUICallback('cortex_mdt:closeCitation', function(_, cb)
    closeMDT()
    cb('ok')
end)

RegisterNUICallback('cortex_mdt:getStandaloneCivilianState', function(_, cb)
    local isStandalone = Config.FrameworkMode == 'standalone'
    local response = awaitServerCallback('cortex_mdt:getStandaloneCivilianState')

    if not response then
        print('[cortex_mdt] WARNING: getStandaloneCivilianState server callback returned nil - using local config fallback')
        response = {
            ok = isStandalone,
            standaloneEnabled = isStandalone,
            frameworkMode = Config.FrameworkMode or 'standalone',
            citizens = {},
            error = not isStandalone and 'Standalone mode is not enabled in config.' or nil,
        }
    end

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

RegisterNUICallback('cortex_mdt:unclaimStandaloneCivilian', function(data, cb)
    local response = awaitServerCallback('cortex_mdt:unclaimStandaloneCivilian', data and data.citizenId) or {
        ok = false,
        error = 'Failed to unclaim civilian.',
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

RegisterNUICallback('cortex_mdt:registerStandaloneCivilian', function(data, cb)
    local response = awaitServerCallback('cortex_mdt:registerStandaloneCivilian', data) or {
        ok = false,
        error = 'Failed to register civilian.',
    }

    cb(response)
end)

RegisterNUICallback('cortex_mdt:updateStandaloneCivilian', function(data, cb)
    local response = awaitServerCallback('cortex_mdt:updateStandaloneCivilian', data) or {
        ok = false,
        error = 'Failed to update civilian.',
    }

    cb(response)
end)

RegisterNUICallback('cortex_mdt:registerStandaloneVehicle', function(data, cb)
    local response = awaitServerCallback('cortex_mdt:registerStandaloneVehicle', data) or {
        ok = false,
        error = 'Failed to register vehicle.',
    }

    cb(response)
end)

RegisterNUICallback('cortex_mdt:registerCurrentStandaloneVehicle', function(data, cb)
    local vehicleContext, err = getStandaloneVehicleContext()
    if not vehicleContext then
        cb({
            ok = false,
            error = err or 'Unable to capture the current vehicle.',
        })
        return
    end

    local payload = type(data) == 'table' and data or {}
    for key, value in pairs(vehicleContext) do
        if payload[key] == nil or payload[key] == '' then
            payload[key] = value
        end
    end

    local response = awaitServerCallback('cortex_mdt:registerStandaloneVehicle', payload) or {
        ok = false,
        error = 'Failed to register current vehicle.',
    }

    cb(response)
end)

local serverForwardCallbacks = {
    'cortex_mdt:ersBiometricLogin',
    'cortex_mdt:registerOfficer',
    'cortex_mdt:getDashboard',
    'cortex_mdt:globalSearch',
    'cortex_mdt:searchCitizens',
    'cortex_mdt:getCitizen',
    'cortex_mdt:updateCitizen',
    'cortex_mdt:updateCitizenLicenses',
    'cortex_mdt:fetchLicenseTypes',
    'cortex_mdt:createLicenseType',
    'cortex_mdt:updateLicenseType',
    'cortex_mdt:deleteLicenseType',
    'cortex_mdt:searchVehicles',
    'cortex_mdt:getVehicle',
    'cortex_mdt:impoundVehicle',
    'cortex_mdt:releaseImpound',
    'cortex_mdt:getReports',
    'cortex_mdt:getReport',
    'cortex_mdt:createReport',
    'cortex_mdt:updateReport',
    'cortex_mdt:addReportTimeline',
    'cortex_mdt:addReportEntity',
    'cortex_mdt:removeReportEntity',
    'cortex_mdt:getCases',
    'cortex_mdt:getCase',
    'cortex_mdt:createCase',
    'cortex_mdt:updateCase',
    'cortex_mdt:addCaseLink',
    'cortex_mdt:removeCaseLink',
    'cortex_mdt:addCasePersonnel',
    'cortex_mdt:removeCasePersonnel',
    'cortex_mdt:addAttachment',
    'cortex_mdt:removeAttachment',
    'cortex_mdt:getEvidence',
    'cortex_mdt:getEvidenceRecord',
    'cortex_mdt:createEvidence',
    'cortex_mdt:updateEvidence',
    'cortex_mdt:transferEvidence',
    'cortex_mdt:getBolos',
    'cortex_mdt:createBolo',
    'cortex_mdt:updateBoloStatus',
    'cortex_mdt:getWarrants',
    'cortex_mdt:createWarrant',
    'cortex_mdt:updateWarrantStatus',
    'cortex_mdt:getWeapons',
    'cortex_mdt:searchWeapons',
    'cortex_mdt:getWeapon',
    'cortex_mdt:getWeaponRecord',
    'cortex_mdt:getWeaponAnalytics',
    'cortex_mdt:createWeapon',
    'cortex_mdt:updateWeapon',
    'cortex_mdt:transferWeapon',
    'cortex_mdt:getCharges',
    'cortex_mdt:updateCharge',
    'cortex_mdt:getUnits',
    'cortex_mdt:updateUnitStatus',
    'cortex_mdt:goOnDuty',
    'cortex_mdt:goOffDuty',
    'cortex_mdt:getRoster',
    'cortex_mdt:getLeaderboard',
    'cortex_mdt:updateOfficerAdmin',
    'cortex_mdt:getAuditLogs',
    'cortex_mdt:getAnnouncements',
    'cortex_mdt:createAnnouncement',
    'cortex_mdt:deleteAnnouncement',
    'cortex_mdt:sendDashboardChat',
    'cortex_mdt:getSettings',
    'cortex_mdt:updateSetting',
    'cortex_mdt:saveOfficerAvatar',
    'cortex_mdt:searchOfficers',
    'cortex_mdt:getConfig',
    'cortex_mdt:getFtoRecords',
    'cortex_mdt:createFtoRecord',
    'cortex_mdt:updateFtoRecord',
    'cortex_mdt:getCivilianRecords',
    'cortex_mdt:issueCitation',
    'cortex_mdt:getMyCitations',
    'cortex_mdt:getCitation',
    'cortex_mdt:markCitationViewed',
}

for i = 1, #serverForwardCallbacks do
    local name = serverForwardCallbacks[i]
    RegisterNUICallback(name, function(data, cb)
        local response = awaitServerCallback(name, data)
        cb(response or { ok = false })
    end)
end

RegisterCommand(Config.OpenCommand, function()
    if isOpen then
        closeMDT()
    else
        openMDT()
    end
end, false)

RegisterKeyMapping(Config.OpenCommand, 'Open Cortex MDT', 'keyboard', Config.OpenKey)

RegisterCommand(Config.CivilianCommand or Config.civilianCommand or 'civilian', function()
    if isOpen then
        closeMDT()
    else
        openCivilian()
    end
end, false)

RegisterCommand(Config.PoliceCommand or Config.policeCommand or 'police', function(_, args)
    runPoliceDutyCommand(args)
end, false)

if Config.Citations and Config.Citations.enabled ~= false then
    RegisterCommand(Config.Citations.showCommand or 'showcitation', function()
        if isOpen then
            closeMDT()
            return
        end

        isOpen = true
        CortexMdtNuiOpen = true
        currentMode = 'citation'

        SetNuiFocus(true, true)

        SendNUIMessage({
            action = 'cortex_mdt:showCitation',
            data = {
                playerName = GetPlayerName(PlayerId()) or 'Unknown',
            },
        })
    end, false)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    mdtEmoteStop()
end)
