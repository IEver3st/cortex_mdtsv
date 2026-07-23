local activeCamera = nil
local activeView = nil
--- Bodycam HUD: es_hud toggleHud only (toggleMap duplicates minimap refresh + races bigmap collapse).
local bodycamHudSuppressed = false
local bodycamHudUsedEsExport = false

--- Control indices allowed during bodycam (zoom/pan/tilt/reset + shift/ctrl modifiers). All other gameplay input blocked.
local BODYCAM_ALLOWED_CONTROLS = { 21, 32, 33, 34, 35, 36, 38, 44, 45 }

local function tryEsHudBodycamVisibility(show)
    if GetResourceState('es_hud') ~= 'started' then
        return false
    end
    local ex = exports['es_hud']
    if type(ex) ~= 'table' or type(ex.toggleHud) ~= 'function' then
        return false
    end
    local ok, _ = pcall(function()
        ex:toggleHud(show)
    end)
    return ok
end

local function suppressBodycamHud()
    bodycamHudUsedEsExport = tryEsHudBodycamVisibility(false)
    if bodycamHudUsedEsExport then
        bodycamHudSuppressed = true
        return
    end
    DisplayRadar(false)
    DisplayHud(false)
    bodycamHudSuppressed = true
end

local function restoreBodycamHud()
    if not bodycamHudSuppressed then
        return
    end
    if bodycamHudUsedEsExport then
        local ex = exports['es_hud']
        if type(ex) == 'table' and type(ex.toggleHud) == 'function' then
            pcall(function()
                ex:toggleHud(true)
            end)
        end
        bodycamHudUsedEsExport = false
    else
        DisplayRadar(true)
        DisplayHud(true)
    end
    bodycamHudSuppressed = false
    -- RenderScriptCams / radar hide-show can leave minimap in expanded (big) layout.
    SetRadarBigmapEnabled(false, false)
end

local function bodycamInputGate()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    for i = 1, #BODYCAM_ALLOWED_CONTROLS do
        EnableControlAction(0, BODYCAM_ALLOWED_CONTROLS[i], true)
    end
end

local function getCctvConfig()
    return type(Config.CCTV) == 'table' and Config.CCTV or {}
end

local function getDefaultFov()
    local config = getCctvConfig()
    return tonumber(config.defaultFov) or 52.0
end

local function getMinFov()
    local config = getCctvConfig()
    return tonumber(config.minFov) or 18.0
end

local function getMaxFov()
    local config = getCctvConfig()
    return tonumber(config.maxFov) or 90.0
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function awaitServerCallback(name, payload)
    if type(_G.CortexMdtServerCallback) == 'function' then
        return _G.CortexMdtServerCallback(name, payload)
    end

    local ok, response = pcall(function()
        return lib.callback.await(name, false, payload)
    end)

    if not ok then
        return nil
    end

    return response
end

local function pushBodycamLocation(locationText)
    SendNUIMessage({
        action = 'cortex_mdt:bodycamLocation',
        data = {
            location = locationText or '',
        },
    })
end

local function destroyScriptCamera()
    SetNuiFocusKeepInput(false)
    pushBodycamLocation('')

    restoreBodycamHud()

    if not activeCamera then
        return
    end

    RenderScriptCams(false, true, 250, true, true)
    DestroyCam(activeCamera, false)
    activeCamera = nil
    activeView = nil
end

local function stopCameraView(notifyServer)
    destroyScriptCamera()

    if notifyServer then
        awaitServerCallback('cortex_mdt:stopCameraView')
    end
end

local function applyStaticCameraState()
    if not activeCamera or not activeView or activeView.kind ~= 'static' then
        return
    end

    SetCamCoord(activeCamera, activeView.coords.x, activeView.coords.y, activeView.coords.z)
    SetCamRot(activeCamera, activeView.rotation.x, activeView.rotation.y, activeView.rotation.z, 2)
    SetCamFov(activeCamera, activeView.fov)
end

local function startStaticCameraView(camera)
    stopCameraView(false)

    local coords = camera.coords or {}
    local rotation = camera.rotation or {}

    local parsedCoords = {
        x = tonumber(coords.x or coords[1]) or 0.0,
        y = tonumber(coords.y or coords[2]) or 0.0,
        z = tonumber(coords.z or coords[3]) or 0.0,
    }

    local parsedRotation = {
        x = tonumber(rotation.x or rotation[1]) or -20.0,
        y = tonumber(rotation.y or rotation[2]) or 0.0,
        z = tonumber(rotation.z or rotation[3]) or 0.0,
    }

    activeCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    activeView = {
        kind = 'static',
        cameraId = camera.id,
        coords = parsedCoords,
        rotation = parsedRotation,
        fov = getDefaultFov(),
    }

    applyStaticCameraState()
    SetCamActive(activeCamera, true)
    RenderScriptCams(true, true, 250, true, true)
    SetNuiFocusKeepInput(true)
    suppressBodycamHud()
end

local function formatStreetAtCoords(coords)
    if not coords then
        return ''
    end

    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)
    local crossing = GetStreetNameFromHashKey(crossingHash)
    street = street and tostring(street) or ''
    crossing = crossing and tostring(crossing) or ''

    if street ~= '' and crossing ~= '' and crossing ~= street then
        return ('%s / %s'):format(street, crossing)
    end

    return street
end

local function startBodycamTrackerThread()
    CreateThread(function()
        local locationTick = 0
        while activeCamera and activeView and activeView.kind == 'bodycam' do
            bodycamInputGate()
            local targetSource = activeView.targetSource
            local playerIndex = GetPlayerFromServerId(targetSource)

            if playerIndex == -1 then
                stopCameraView(true)
                break
            end

            local targetPed = GetPlayerPed(playerIndex)
            if targetPed == 0 or not DoesEntityExist(targetPed) then
                stopCameraView(true)
                break
            end

            local headCoords = GetPedBoneCoords(targetPed, 31086, 0.04, 0.03, 0.01)
            local heading = GetEntityHeading(targetPed)

            SetCamCoord(activeCamera, headCoords.x, headCoords.y, headCoords.z)
            SetCamRot(activeCamera, activeView.pitch, 0.0, heading + activeView.headingOffset, 2)
            SetCamFov(activeCamera, activeView.fov)

            locationTick = locationTick + 1
            if locationTick >= 18 then
                locationTick = 0
                local pedCoords = GetEntityCoords(targetPed)
                pushBodycamLocation(formatStreetAtCoords(pedCoords))
            end

            Wait(0)
        end
    end)
end

local function startBodycamView(bodycam)
    stopCameraView(false)

    local targetSource = tonumber(bodycam.source)
    if not targetSource then
        return false
    end

    activeCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    activeView = {
        kind = 'bodycam',
        targetSource = targetSource,
        headingOffset = 0.0,
        pitch = -4.0,
        fov = getDefaultFov(),
    }

    SetCamActive(activeCamera, true)
    RenderScriptCams(true, true, 250, true, true)
    SetNuiFocusKeepInput(true)
    suppressBodycamHud()
    startBodycamTrackerThread()
    return true
end

local function applyCameraControl(action)
    if not activeView or not activeCamera then
        return
    end

    local minFov = getMinFov()
    local maxFov = getMaxFov()

    if action == 'zoom_in' then
        activeView.fov = clamp(activeView.fov - 3.0, minFov, maxFov)
    elseif action == 'zoom_out' then
        activeView.fov = clamp(activeView.fov + 3.0, minFov, maxFov)
    elseif action == 'reset' then
        activeView.fov = getDefaultFov()
        if activeView.kind == 'static' then
            activeView.rotation.x = -20.0
            activeView.rotation.y = 0.0
        else
            activeView.pitch = -4.0
            activeView.headingOffset = 0.0
        end
    elseif activeView.kind == 'static' then
        if action == 'pan_left' then
            activeView.rotation.z = activeView.rotation.z + 3.5
        elseif action == 'pan_right' then
            activeView.rotation.z = activeView.rotation.z - 3.5
        elseif action == 'tilt_up' then
            activeView.rotation.x = clamp(activeView.rotation.x + 2.0, -89.0, 25.0)
        elseif action == 'tilt_down' then
            activeView.rotation.x = clamp(activeView.rotation.x - 2.0, -89.0, 25.0)
        end
    elseif activeView.kind == 'bodycam' then
        if action == 'pan_left' then
            activeView.headingOffset = clamp(activeView.headingOffset + 2.5, -35.0, 35.0)
        elseif action == 'pan_right' then
            activeView.headingOffset = clamp(activeView.headingOffset - 2.5, -35.0, 35.0)
        elseif action == 'tilt_up' then
            activeView.pitch = clamp(activeView.pitch + 1.5, -35.0, 20.0)
        elseif action == 'tilt_down' then
            activeView.pitch = clamp(activeView.pitch - 1.5, -35.0, 20.0)
        end
    end

    if activeView.kind == 'static' then
        applyStaticCameraState()
    end
end

RegisterNUICallback('cortex_mdt:getCameras', function(_, cb)
    local response = awaitServerCallback('cortex_mdt:getCameras') or {
        ok = false,
        error = 'Failed to load CCTV cameras.',
    }

    cb(response)
end)

RegisterNUICallback('cortex_mdt:getCameraModels', function(_, cb)
    local response = awaitServerCallback('cortex_mdt:getCameraModels') or {
        ok = false,
        error = 'Failed to load camera models.',
    }

    cb(response)
end)

RegisterNUICallback('cortex_mdt:createStaticCamera', function(data, cb)
    local payload = type(data) == 'table' and data or {}
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local heading = GetEntityHeading(ped)

    payload.coords = payload.coords or {
        x = pedCoords.x + (forward.x * 1.5),
        y = pedCoords.y + (forward.y * 1.5),
        z = pedCoords.z + 0.85,
    }
    payload.rotation = payload.rotation or {
        x = -20.0,
        y = 0.0,
        z = heading + 180.0,
    }

    local response = awaitServerCallback('cortex_mdt:createStaticCamera', payload) or {
        ok = false,
        error = 'Failed to create camera.',
    }

    cb(response)
end)

RegisterNUICallback('cortex_mdt:deleteCamera', function(data, cb)
    local response = awaitServerCallback('cortex_mdt:deleteCamera', data) or {
        ok = false,
        error = 'Failed to delete camera.',
    }

    cb(response)
end)

RegisterNUICallback('cortex_mdt:setCameraOnline', function(data, cb)
    local response = awaitServerCallback('cortex_mdt:setCameraOnline', data) or {
        ok = false,
        error = 'Failed to update camera state.',
    }

    cb(response)
end)

RegisterNUICallback('cortex_mdt:viewCamera', function(data, cb)
    local response = awaitServerCallback('cortex_mdt:viewCamera', data) or {
        ok = false,
        error = 'Failed to view camera.',
    }

    if response.ok and response.camera then
        startStaticCameraView(response.camera)
    end

    cb(response)
end)

RegisterNUICallback('cortex_mdt:getBodycams', function(_, cb)
    local response = awaitServerCallback('cortex_mdt:getBodycams') or {
        ok = false,
        error = 'Failed to load bodycams.',
    }

    cb(response)
end)

RegisterNUICallback('cortex_mdt:viewBodycam', function(data, cb)
    local response = awaitServerCallback('cortex_mdt:viewBodycam', data) or {
        ok = false,
        error = 'Failed to view bodycam.',
    }

    if response.ok and response.bodycam then
        local started = startBodycamView(response.bodycam)
        if not started then
            response = {
                ok = false,
                error = 'Unable to start bodycam feed.',
            }
        end
    end

    cb(response)
end)

RegisterNUICallback('cortex_mdt:stopCameraView', function(_, cb)
    stopCameraView(true)
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:cameraControl', function(data, cb)
    local action = type(data) == 'table' and tostring(data.action or '') or ''
    if action ~= '' then
        applyCameraControl(action)
    end

    cb({ ok = true })
end)

--- UI audio toggle (extend: route to voice resource).
RegisterNUICallback('cortex_mdt:setBodycamAudio', function(_, cb)
    cb({ ok = true })
end)

RegisterNetEvent('cortex_mdtsv:cameraForceStop', function()
    stopCameraView(false)
end)

RegisterNetEvent('cortex_mdtsv:client:mdtClosed', function()
    stopCameraView(true)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    stopCameraView(false)
end)

--- Axis holds while NUI stays focused (SetNuiFocusKeepInput). Matches CCTV / bodycam on-screen legend.
CreateThread(function()
    while true do
        if activeView and activeCamera and activeView.kind == 'static' then
            local minFov = getMinFov()
            local maxFov = getMaxFov()
            local boost = 1.0
            if IsControlPressed(0, 21) then
                boost = boost * 2.1
            end
            if IsControlPressed(0, 36) then
                boost = boost * 0.42
            end

            local ft = GetFrameTime()
            if ft <= 0.0 then
                ft = 0.016
            end

            local m = boost * ft * 60.0

            if IsControlPressed(0, 32) then
                activeView.rotation.x = clamp(activeView.rotation.x + 1.8 * m, -89.0, 25.0)
            end
            if IsControlPressed(0, 33) then
                activeView.rotation.x = clamp(activeView.rotation.x - 1.8 * m, -89.0, 25.0)
            end
            if IsControlPressed(0, 34) then
                activeView.rotation.z = activeView.rotation.z + 3.2 * m
            end
            if IsControlPressed(0, 35) then
                activeView.rotation.z = activeView.rotation.z - 3.2 * m
            end
            if IsControlPressed(0, 44) then
                activeView.fov = clamp(activeView.fov - 1.2 * m, minFov, maxFov)
            end
            if IsControlPressed(0, 38) then
                activeView.fov = clamp(activeView.fov + 1.2 * m, minFov, maxFov)
            end
            if IsControlJustPressed(0, 45) then
                applyCameraControl('reset')
            end

            applyStaticCameraState()
            Wait(0)
        elseif activeView and activeCamera and activeView.kind == 'bodycam' then
            bodycamInputGate()
            local minFov = getMinFov()
            local maxFov = getMaxFov()
            local boost = 1.0
            if IsControlPressed(0, 21) then
                boost = boost * 2.1
            end
            if IsControlPressed(0, 36) then
                boost = boost * 0.42
            end

            local ft = GetFrameTime()
            if ft <= 0.0 then
                ft = 0.016
            end

            local m = boost * ft * 60.0

            if IsControlPressed(0, 32) then
                activeView.pitch = clamp(activeView.pitch + 1.4 * m, -35.0, 20.0)
            end
            if IsControlPressed(0, 33) then
                activeView.pitch = clamp(activeView.pitch - 1.4 * m, -35.0, 20.0)
            end
            if IsControlPressed(0, 34) then
                activeView.headingOffset = clamp(activeView.headingOffset + 2.4 * m, -35.0, 35.0)
            end
            if IsControlPressed(0, 35) then
                activeView.headingOffset = clamp(activeView.headingOffset - 2.4 * m, -35.0, 35.0)
            end
            if IsControlPressed(0, 44) then
                activeView.fov = clamp(activeView.fov - 1.2 * m, minFov, maxFov)
            end
            if IsControlPressed(0, 38) then
                activeView.fov = clamp(activeView.fov + 1.2 * m, minFov, maxFov)
            end
            if IsControlJustPressed(0, 45) then
                applyCameraControl('reset')
            end

            Wait(0)
        else
            Wait(200)
        end
    end
end)
