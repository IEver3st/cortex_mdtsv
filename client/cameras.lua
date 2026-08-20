local activeCamera = nil
local activeView = nil
--- Bodycam HUD: cortex-hud toggleHud only (toggleMap duplicates minimap refresh + races bigmap collapse).
local bodycamHudSuppressed = false
local bodycamHudUsedEsExport = false
local bodycamStreamDemanded = false
local bodycamViewerCount = 0
local activeAudioSource = nil
local savedVisionState = nil
local dashcamModelOffsetsByHash = nil

--- Control indices allowed during bodycam (zoom/pan/tilt/reset + shift/ctrl modifiers). All other gameplay input blocked.
local BODYCAM_ALLOWED_CONTROLS = { 21, 32, 33, 34, 35, 36, 38, 44, 45 }

local function tryEsHudBodycamVisibility(show)
    if GetResourceState('cortex-hud') ~= 'started' then
        return false
    end
    local ex = exports['cortex-hud']
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
        local ex = exports['cortex-hud']
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

local function pushFeedState(state, details)
    details = type(details) == 'table' and details or {}
    details.state = state
    if activeView then
        details.feedId = details.feedId or activeView.feedId
        details.feedType = details.feedType or activeView.kind
        details.direction = details.direction or activeView.direction
    end
    SendNUIMessage({ action = 'cortex_mdt:cameraFeedState', data = details })
end

local function restoreVisionState()
    if not savedVisionState then return end
    pcall(SetNightvision, savedVisionState.nightvision == true)
    pcall(SetSeethrough, savedVisionState.seethrough == true)
    savedVisionState = nil
end

local function setMirroredVisionMode(mode)
    mode = tostring(mode or 'normal'):lower()
    if mode == 'nightvision' then
        pcall(SetNightvision, true)
        pcall(SetSeethrough, false)
    elseif mode == 'thermal' then
        pcall(SetNightvision, false)
        pcall(SetSeethrough, true)
    else
        pcall(SetNightvision, false)
        pcall(SetSeethrough, false)
    end
end

local function resetBodycamAudio()
    if not activeAudioSource then return end
    pcall(MumbleSetVolumeOverrideByServerId, activeAudioSource, -1.0)
    activeAudioSource = nil
end

local function destroyScriptCamera()
    SetNuiFocusKeepInput(false)
    pushBodycamLocation('')
    resetBodycamAudio()
    restoreVisionState()
    ClearFocus()

    restoreBodycamHud()

    if activeCamera then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(activeCamera, false)
    end
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

local function lerp(first, second, amount)
    return first + ((second - first) * amount)
end

local function lerpAngle(first, second, amount)
    local delta = ((second - first + 180.0) % 360.0) - 180.0
    return first + (delta * amount)
end

local function parseVector(value, fallback)
    value = type(value) == 'table' and value or {}
    return {
        x = tonumber(value.x or value[1]) or fallback.x,
        y = tonumber(value.y or value[2]) or fallback.y,
        z = tonumber(value.z or value[3]) or fallback.z,
    }
end

local function getDashcamModelOffset(modelHash)
    modelHash = tonumber(modelHash)
    if not modelHash then return nil end

    if not dashcamModelOffsetsByHash then
        dashcamModelOffsetsByHash = {}
        local config = type(Config.Dashcams) == 'table' and Config.Dashcams or {}
        local configured = type(config.modelOffsets) == 'table' and config.modelOffsets or {}
        for modelName, entry in pairs(configured) do
            if type(entry) == 'table' then
                local hash = tonumber(modelName)
                if not hash and type(modelName) == 'string' and modelName ~= '' then
                    hash = GetHashKey(modelName)
                end
                if hash then dashcamModelOffsetsByHash[hash] = entry end
            end
        end
    end

    return dashcamModelOffsetsByHash[modelHash]
end

local function resolveDashcamOffset(modelHash, direction)
    local config = type(Config.Dashcams) == 'table' and Config.Dashcams or {}
    local rear = direction == 'rear'
    local fallbackValue = rear and config.defaultRearOffset or config.defaultOffset
    local fallback = parseVector(fallbackValue, rear
        and { x = 0.0, y = -0.82, z = 1.12 }
        or { x = 0.0, y = 0.72, z = 1.18 })
    local defaultPitch = tonumber(rear and config.defaultRearPitch or config.defaultPitch)
        or (rear and -3.0 or -5.0)
    local model = getDashcamModelOffset(modelHash)
    if not model then return fallback, defaultPitch end

    -- Native Cortex format: explicit local-space front/rear vectors where
    -- x = right, y = forward, z = up. Missing axes inherit the defaults.
    local selected = rear and (model.rear or model.rearOffset) or (model.front or model.frontOffset)
    local pitch = selected and tonumber(selected.pitch)
        or tonumber(rear and model.rearPitch or model.frontPitch)

    -- Project Sloth compatible format, so existing per-vehicle tuning can be
    -- copied without translating side/forward/height fields by hand.
    if not selected and (model.side ~= nil or model.forward ~= nil or model.height ~= nil
        or model.rearSide ~= nil or model.rearForward ~= nil or model.rearHeight ~= nil) then
        if rear then
            selected = {
                x = model.rearSide ~= nil and model.rearSide or model.side,
                y = -(tonumber(model.rearForward ~= nil and model.rearForward or model.forward) or math.abs(fallback.y)),
                z = model.rearHeight ~= nil and model.rearHeight or model.height,
            }
            pitch = tonumber(model.rearPitch) or tonumber(model.pitch)
        else
            selected = { x = model.side, y = model.forward, z = model.height }
            pitch = tonumber(model.pitch)
        end
    end

    return parseVector(selected, fallback), clamp(pitch or defaultPitch, -45.0, 45.0)
end

local function frameTransform(frame, previous, amount)
    local coords = parseVector(frame.coords, { x = 0.0, y = 0.0, z = 0.0 })
    local rotation = parseVector(frame.rotation, { x = 0.0, y = 0.0, z = tonumber(frame.heading) or 0.0 })
    if not previous then return coords, rotation end
    local oldCoords = parseVector(previous.coords, coords)
    local oldRotation = parseVector(previous.rotation, rotation)
    return {
        x = lerp(oldCoords.x, coords.x, amount),
        y = lerp(oldCoords.y, coords.y, amount),
        z = lerp(oldCoords.z, coords.z, amount),
    }, {
        x = lerpAngle(oldRotation.x, rotation.x, amount),
        y = lerpAngle(oldRotation.y, rotation.y, amount),
        z = lerpAngle(oldRotation.z, rotation.z, amount),
    }
end

local function applyDashcamOffset(coords, heading, direction, modelHash)
    local offset, pitch = resolveDashcamOffset(modelHash, direction)
    local radians = math.rad(heading)
    return {
        x = coords.x + (offset.x * math.cos(radians)) + (offset.y * math.sin(radians)),
        y = coords.y - (offset.x * math.sin(radians)) + (offset.y * math.cos(radians)),
        z = coords.z + offset.z,
    }, pitch
end

local function applyRemoteFrame(frame)
    if type(frame) ~= 'table' or not activeView or not activeCamera or frame.feedId ~= activeView.feedId then return end
    local normalized = frame
    if activeView.kind == 'air' and frame.preview then
        normalized = {
            feedId = frame.feedId,
            coords = frame.preview.coords,
            rotation = frame.preview.rotation,
            fov = frame.preview.fov,
            visionMode = frame.preview.visionMode,
            tracking = frame.tracking,
        }
    end
    activeView.previousFrame = activeView.currentFrame
    activeView.currentFrame = normalized
    if activeView.kind == 'dashcam' then
        activeView.modelHash = tonumber(frame.modelHash) or activeView.modelHash
    end
    activeView.frameReceivedAt = GetGameTimer()
    activeView.frameState = 'live'
    pushFeedState('live', {
        speed = frame.speed,
        fov = frame.preview and frame.preview.fov or frame.fov,
        visionMode = frame.preview and frame.preview.visionMode or frame.visionMode,
        tracking = frame.tracking,
    })
end

local function startRemoteTrackerThread()
    CreateThread(function()
        local locationAt = 0
        local staleNotified = false
        while activeCamera and activeView and activeView.kind ~= 'static' do
            bodycamInputGate()
            local now = GetGameTimer()
            local frame = activeView.currentFrame
            if frame then
                local syncInterval = activeView.kind == 'bodycam'
                    and tonumber((Config.Bodycams or {}).streamIntervalMs)
                    or (activeView.kind == 'air'
                        and tonumber((Config.AirSupport or {}).syncIntervalMs)
                        or tonumber((Config.Dashcams or {}).syncIntervalMs))
                syncInterval = math.max(50, syncInterval or 200)
                local amount = clamp((now - (activeView.frameReceivedAt or now)) / syncInterval, 0.0, 1.0)
                local coords, rotation = frameTransform(frame, activeView.previousFrame, amount)

                if activeView.kind == 'bodycam' then
                    rotation.x = rotation.x + (activeView.pitch or 0.0)
                    rotation.z = rotation.z + (activeView.headingOffset or 0.0)
                elseif activeView.kind == 'dashcam' then
                    local heading = tonumber(frame.heading) or rotation.z
                    local pitch
                    coords, pitch = applyDashcamOffset(coords, heading, activeView.direction, frame.modelHash or activeView.modelHash)
                    rotation = { x = pitch, y = 0.0, z = heading + (activeView.direction == 'rear' and 180.0 or 0.0) }
                elseif activeView.kind == 'air' then
                    activeView.fov = tonumber(frame.fov) or activeView.fov
                    setMirroredVisionMode(frame.visionMode)
                end

                SetCamCoord(activeCamera, coords.x, coords.y, coords.z)
                SetCamRot(activeCamera, rotation.x, rotation.y, rotation.z, 2)
                SetCamFov(activeCamera, activeView.fov)
                SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
                RequestCollisionAtCoord(coords.x, coords.y, coords.z)

                if now - locationAt >= 500 then
                    locationAt = now
                    pushBodycamLocation(formatStreetAtCoords(coords))
                end

                local staleAfter = math.max(500, tonumber((Config.Bodycams or {}).staleFrameMs) or 2000)
                if now - (activeView.frameReceivedAt or now) > staleAfter then
                    if not staleNotified then
                        staleNotified = true
                        pushFeedState('stale', { detail = 'Waiting for the next authorised camera frame.' })
                    end
                else
                    staleNotified = false
                end
            elseif not staleNotified and now - (activeView.startedAt or now) > 750 then
                staleNotified = true
                pushFeedState('connecting', { detail = 'Establishing the secure feed.' })
            end
            Wait(0)
        end
    end)
end

local function startLiveFeedView(feed, direction)
    stopCameraView(false)

    if type(feed) ~= 'table' or type(feed.feedId) ~= 'string' then return false end
    local feedType = tostring(feed.feedType or '')
    if feedType ~= 'bodycam' and feedType ~= 'dashcam' and feedType ~= 'air' then return false end

    activeCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    activeView = {
        kind = feedType,
        feedId = feed.feedId,
        targetSource = tonumber(feed.source),
        modelHash = tonumber(feed.modelHash),
        direction = direction == 'rear' and 'rear' or 'front',
        headingOffset = 0.0,
        pitch = 0.0,
        fov = getDefaultFov(),
        startedAt = GetGameTimer(),
        frameReceivedAt = nil,
    }

    local playerCoords = GetEntityCoords(PlayerPedId())
    SetCamCoord(activeCamera, playerCoords.x, playerCoords.y, playerCoords.z + 1.0)
    SetCamRot(activeCamera, 0.0, 0.0, GetEntityHeading(PlayerPedId()), 2)

    if feedType == 'air' and feed.preview then
        savedVisionState = {
            nightvision = GetUsingnightvision and GetUsingnightvision() or false,
            seethrough = GetUsingseethrough and GetUsingseethrough() or false,
        }
        applyRemoteFrame(feed)
    end

    SetCamActive(activeCamera, true)
    RenderScriptCams(true, true, 250, true, true)
    SetNuiFocusKeepInput(true)
    suppressBodycamHud()
    pushFeedState('connecting')
    startRemoteTrackerThread()
    return true
end

local function startBodycamView(bodycam)
    return startLiveFeedView(bodycam, 'front')
end

local function applyCameraControl(action)
    if not activeView or not activeCamera then
        return
    end

    if activeView.kind == 'air' then return end
    if action == 'toggle_direction' and activeView.kind == 'dashcam' then
        activeView.direction = activeView.direction == 'rear' and 'front' or 'rear'
        pushFeedState('live', { direction = activeView.direction })
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
            activeView.pitch = 0.0
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

RegisterNUICallback('cortex_mdt:getLiveFeeds', function(_, cb)
    local response = awaitServerCallback('cortex_mdt:getLiveFeeds') or {
        ok = false,
        error = 'Failed to load operational camera feeds.',
    }
    cb(response)
end)

RegisterNUICallback('cortex_mdt:viewLiveFeed', function(data, cb)
    local response = awaitServerCallback('cortex_mdt:viewLiveFeed', data) or {
        ok = false,
        error = 'Failed to open the live feed.',
    }
    if response.ok and response.feed then
        local started = startLiveFeedView(response.feed, response.direction)
        if not started then
            awaitServerCallback('cortex_mdt:stopCameraView')
            response = { ok = false, error = 'Unable to initialize the camera renderer.' }
        end
    end
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

RegisterNUICallback('cortex_mdt:setBodycamAudio', function(data, cb)
    local audioConfig = type(Config.Bodycams) == 'table' and type(Config.Bodycams.audio) == 'table'
        and Config.Bodycams.audio or {}
    if not activeView or activeView.kind ~= 'bodycam' or audioConfig.enabled ~= true or audioConfig.mode ~= 'proximity' then
        cb({ ok = false, error = 'Bodycam audio is unavailable for this feed.', mode = 'disabled' })
        return
    end

    local targetSource = tonumber(activeView.targetSource)
    if not targetSource then
        cb({ ok = false, error = 'Bodycam audio target is unavailable.', mode = 'disabled' })
        return
    end

    local enabled = type(data) == 'table' and data.enabled == true
    resetBodycamAudio()
    if enabled then
        local volume = clamp(tonumber(audioConfig.volume) or 1.0, 0.0, 1.0)
        local ok = pcall(MumbleSetVolumeOverrideByServerId, targetSource, volume)
        if not ok then
            cb({ ok = false, error = 'Voice override is unavailable.', mode = 'disabled' })
            return
        end
        activeAudioSource = targetSource
    end
    cb({
        ok = true,
        enabled = enabled,
        mode = 'proximity',
        detail = 'Only voice already routed by the server is audible; radio and call targets are unchanged.',
    })
end)

RegisterNetEvent('cortex_mdtsv:bodycamFrame', function(frame)
    applyRemoteFrame(frame)
end)

RegisterNetEvent('cortex_mdtsv:dashcamFrame', function(frame)
    if type(frame) == 'table' then
        frame.rotation = { x = 0.0, y = 0.0, z = tonumber(frame.heading) or 0.0 }
    end
    applyRemoteFrame(frame)
end)

RegisterNetEvent('cortex_mdtsv:airFeedFrame', function(frame)
    applyRemoteFrame(frame)
end)

RegisterNetEvent('cortex_mdtsv:bodycamStreamDemand', function(required, viewerCount)
    bodycamStreamDemanded = required == true
    bodycamViewerCount = math.max(0, tonumber(viewerCount) or 0)
end)

RegisterNetEvent('cortex_mdtsv:bodycamAvailability', function(enabled, message)
    SendNUIMessage({
        action = 'cortex_mdt:bodycamAvailability',
        data = { enabled = enabled == true, message = tostring(message or '') },
    })
end)

RegisterNetEvent('cortex_mdtsv:cameraForceStop', function(reason)
    if activeView then
        pushFeedState('disconnected', { detail = tostring(reason or 'The feed is no longer available.') })
    end
    stopCameraView(false)
end)

RegisterNetEvent('cortex_mdtsv:client:mdtClosed', function()
    stopCameraView(true)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    bodycamStreamDemanded = false
    bodycamViewerCount = 0
    stopCameraView(false)
end)

CreateThread(function()
    while true do
        if bodycamStreamDemanded and (Config.Bodycams or {}).enabled ~= false then
            local ped = PlayerPedId()
            if ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
                local coords = GetPedBoneCoords(ped, 31086, 0.04, 0.08, -0.08)
                local gameplayRotation = GetGameplayCamRot(2)
                TriggerServerEvent('cortex_mdtsv:bodycamFrame', {
                    coords = { x = coords.x, y = coords.y, z = coords.z },
                    rotation = {
                        x = gameplayRotation.x,
                        y = gameplayRotation.y,
                        z = gameplayRotation.z,
                    },
                    fov = GetGameplayCamFov(),
                    speed = GetEntitySpeed(ped),
                })
            end
            Wait(math.max(50, tonumber((Config.Bodycams or {}).streamIntervalMs) or 100))
        else
            Wait(500)
        end
    end
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
        elseif activeView and activeCamera then
            bodycamInputGate()
            if activeView.kind == 'air' then
                Wait(0)
                goto continue
            end
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

            if activeView.kind == 'bodycam' and IsControlPressed(0, 32) then
                activeView.pitch = clamp(activeView.pitch + 1.4 * m, -35.0, 20.0)
            end
            if activeView.kind == 'bodycam' and IsControlPressed(0, 33) then
                activeView.pitch = clamp(activeView.pitch - 1.4 * m, -35.0, 20.0)
            end
            if activeView.kind == 'bodycam' and IsControlPressed(0, 34) then
                activeView.headingOffset = clamp(activeView.headingOffset + 2.4 * m, -35.0, 35.0)
            end
            if activeView.kind == 'bodycam' and IsControlPressed(0, 35) then
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
        ::continue::
    end
end)
