local dispatchEnabled = type(Config.Dispatch) == 'table' and Config.Dispatch.enabled ~= false
local unitUpdateIntervalMs = type(Config.Dispatch) == 'table' and tonumber(Config.Dispatch.unitUpdateIntervalMs) or 1000
local isSubscribed = false
local mdtOpenInPdMode = false
local cachedIdentity = {
    callsign = '',
    name = '',
    department = '',
    updatedAt = 0,
}

local function invalidateIdentityCache()
    cachedIdentity = {
        callsign = '',
        name = '',
        department = '',
        updatedAt = 0,
    }
end

local function trim(value)
    if value == nil then return '' end
    return tostring(value):match('^%s*(.-)%s*$') or ''
end

local function awaitServerCallback(name, payload)
    if type(_G.CortexMdtServerCallback) == 'function' then
        return _G.CortexMdtServerCallback(name, payload)
    end

    local ok, response = pcall(function()
        return lib.callback.await(name, false, payload)
    end)
    if not ok then return nil end
    return response
end

local function getPlayerCoords()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
end

local function getStreetName()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local streetHash, crossHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash) or ''
    local cross = GetStreetNameFromHashKey(crossHash) or ''
    if street ~= '' and cross ~= '' then return street .. ' / ' .. cross end
    return street ~= '' and street or 'Unknown Street'
end

--- Zone label (e.g. Downtown, Paleto Bay) from game map data.
local function getMapAreaLabel()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local zoneHash = GetNameOfZone(c.x, c.y, c.z)
    local label = GetLabelText(zoneHash)
    label = trim(label)
    if label == '' or label == 'NULL' then
        return ''
    end
    return label
end

local function resolveNearestPostal()
    local ok, postal = pcall(function()
        if GetResourceState('nearest-postal') == 'started' then
            return exports['nearest-postal']:getPostal()
        end
        return nil
    end)
    if ok and postal then return tostring(postal) end
    local ok2, postal2 = pcall(function()
        if GetResourceState('postals') == 'started' then
            return exports['postals']:getNearestPostal()
        end
        return nil
    end)
    if ok2 and postal2 then return tostring(postal2) end
    return ''
end

local function getVehicleInfo()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        local coords = GetEntityCoords(ped)
        vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 70)
    end
    if vehicle == 0 or not DoesEntityExist(vehicle) then return nil, nil, nil end
    local plate = GetVehicleNumberPlateText(vehicle)
    local modelHash = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(modelHash)
    local makeName = GetMakeNameFromVehicleModel(modelHash)
    return trim(plate), trim(makeName), trim(displayName)
end

local function buildDispatchContext()
    local coords = getPlayerCoords()
    local street = getStreetName()
    local postal = resolveNearestPostal()
    local plate, make, model = getVehicleInfo()
    return {
        coords = coords,
        street = street,
        postal = postal,
        vehiclePlate = plate or '',
        vehicleMake = make or '',
        vehicleModel = model or '',
    }
end

local function refreshIdentity(force)
    local now = GetGameTimer()
    if not force and cachedIdentity.updatedAt ~= 0 and now - cachedIdentity.updatedAt < 15000 then return cachedIdentity end
    local profile = awaitServerCallback('cortex_mdt:getOfficerProfile')
    if type(profile) == 'table' then
        local firstName = trim(profile.firstName)
        local lastName = trim(profile.lastName)
        cachedIdentity.callsign = trim(profile.callsign)
        cachedIdentity.name = trim(profile.fullName)
        if cachedIdentity.name == '' then
            cachedIdentity.name = (firstName .. ' ' .. lastName):match('^%s*(.-)%s*$') or ''
        end
        cachedIdentity.department = trim(profile.departmentKey or profile.department or profile.departmentLabel)
        cachedIdentity.updatedAt = now
    end
    if cachedIdentity.callsign == '' then cachedIdentity.callsign = tostring(GetPlayerServerId(PlayerId())) end
    if cachedIdentity.name == '' then cachedIdentity.name = GetPlayerName(PlayerId()) or 'Unknown' end
    if cachedIdentity.department == '' then cachedIdentity.department = 'police' end
    return cachedIdentity
end

RegisterNetEvent('cortex_mdtsv:refreshUnitIdentity', function()
    invalidateIdentityCache()
    refreshIdentity(true)
end)

local function callbackProxy(nuiName, serverName, defaultError, withContext)
    RegisterNUICallback(nuiName, function(data, cb)
        local payload = data
        if withContext then
            payload = buildDispatchContext()
            if type(data) == 'table' then
                for key, value in pairs(data) do
                    payload[key] = value
                end
            end
        end
        local response = awaitServerCallback(serverName, payload) or { ok = false, error = defaultError }
        cb(response)
    end)
end

callbackProxy('cortex_mdt:getDispatch', 'cortex_mdt:getDispatch', 'Failed to fetch dispatch data.', false)
callbackProxy('cortex_mdt:attachDispatchCall', 'cortex_mdt:attachDispatchCall', 'Failed to attach to dispatch call.', false)
callbackProxy('cortex_mdt:detachDispatchCall', 'cortex_mdt:detachDispatchCall', 'Failed to detach from dispatch call.', false)
callbackProxy('cortex_mdt:triggerPanic', 'cortex_mdt:triggerPanic', 'Failed to trigger panic.', true)
callbackProxy('cortex_mdt:createTrafficStopCall', 'cortex_mdt:createTrafficStopCall', 'Failed to create traffic stop.', true)
callbackProxy('cortex_mdt:updateDispatchCall', 'cortex_mdt:updateDispatchCall', 'Failed to update dispatch call.', false)
callbackProxy('cortex_mdt:closeDispatchCall', 'cortex_mdt:closeDispatchCall', 'Failed to close dispatch call.', false)
callbackProxy('cortex_mdt:addDispatchNote', 'cortex_mdt:addDispatchNote', 'Failed to add dispatch note.', false)
callbackProxy('cortex_mdt:markDispatchCode4', 'cortex_mdt:markDispatchCode4', 'Failed to mark dispatch call.', false)

RegisterNUICallback('cortex_mdt:setWaypoint', function(data, cb)
    if data and data.coords then
        local coords = data.coords
        local x = tonumber(coords.x or coords[1])
        local y = tonumber(coords.y or coords[2])
        if x and y then
            SetNewWaypoint(x + 0.0, y + 0.0)
            cb({ ok = true })
            return
        end
    end
    cb({ ok = false, error = 'Invalid coordinates' })
end)

RegisterNUICallback('cortex_mdt:subscribeDispatch', function(_, cb)
    refreshIdentity(true)
    local response = awaitServerCallback('cortex_mdt:subscribeDispatch') or { ok = false }
    if response.ok then isSubscribed = true end
    cb(response)
end)

RegisterNUICallback('cortex_mdt:unsubscribeDispatch', function(_, cb)
    local response = awaitServerCallback('cortex_mdt:unsubscribeDispatch') or { ok = false }
    isSubscribed = false
    cb(response)
end)

RegisterNetEvent('cortex_mdtsv:dispatchUpdate', function(event, data)
    SendNUIMessage({ action = 'cortex_mdt:update', data = { event = event, data = data } })
end)

RegisterNetEvent('cortex_mdtsv:setWaypoint', function(x, y)
    if x and y then SetNewWaypoint(x + 0.0, y + 0.0) end
end)

RegisterNUICallback('cortex_mdt:dispatchAutoSubscribe', function(data, cb)
    if data and data.mode == 'pd' then
        mdtOpenInPdMode = true
        refreshIdentity(true)
        awaitServerCallback('cortex_mdt:subscribeDispatch')
        isSubscribed = true
    end
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:dispatchAutoUnsubscribe', function(_, cb)
    mdtOpenInPdMode = false
    awaitServerCallback('cortex_mdt:unsubscribeDispatch')
    isSubscribed = false
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        Wait(unitUpdateIntervalMs)
        local nuiOpen = CortexMdtNuiOpen == true
        local pushLive = false
        if dispatchEnabled and (isSubscribed or mdtOpenInPdMode or nuiOpen) then
            pushLive = true
        elseif not dispatchEnabled and nuiOpen then
            pushLive = true
        end
        if pushLive then
            local identity = refreshIdentity(false)
            TriggerServerEvent(
                'cortex_mdtsv:updateUnitCoords',
                getPlayerCoords(),
                identity.callsign,
                identity.name,
                identity.department,
                getStreetName(),
                getMapAreaLabel()
            )
        end
    end
end)

if dispatchEnabled then
    print('[^2cortex_mdt^0] Dispatch client module loaded')
end
