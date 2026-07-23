local cctvCameras = {}
local cameraViewers = {}
local bodycamViewers = {}
local sourceViewing = {}

local function usesLocalMode()
    return type(CortexDatabase) == 'table' and CortexDatabase.mode ~= 'qbx'
end

local function getLocalMode()
    local module = rawget(_G, 'CortexLocalMode')
    if type(module) == 'table' then
        return module
    end

    return nil
end

local function trim(value)
    if value == nil then
        return ''
    end

    return tostring(value):match('^%s*(.-)%s*$') or ''
end

local function getPlayerIdentifier(source)
    local license = GetPlayerIdentifierByType(source, 'license')
    if license and license ~= '' then
        return license
    end

    local steam = GetPlayerIdentifierByType(source, 'steam')
    if steam and steam ~= '' then
        return steam
    end

    local identifiers = GetPlayerIdentifiers(source)
    if identifiers and identifiers[1] then
        return identifiers[1]
    end

    return tostring(source)
end

local function decodeVectorPayload(value, default)
    if type(value) == 'string' then
        local ok, decoded = pcall(json.decode, value)
        if ok then
            value = decoded
        end
    end

    if type(value) ~= 'table' then
        return {
            x = default.x,
            y = default.y,
            z = default.z,
        }
    end

    local x = tonumber(value.x or value[1])
    local y = tonumber(value.y or value[2])
    local z = tonumber(value.z or value[3])

    return {
        x = x or default.x,
        y = y or default.y,
        z = z or default.z,
    }
end

local function getOfficerBySource(source)
    if usesLocalMode() then
        local localMode = getLocalMode()
        if type(localMode) ~= 'table' then
            return nil
        end

        local officerId = type(localMode.getOfficerId) == 'function' and localMode.getOfficerId(source) or nil
        if not officerId then
            return nil
        end

        return type(localMode.getOfficer) == 'function' and localMode.getOfficer(officerId) or nil
    end

    local identifier = getPlayerIdentifier(source)
    local rows = MySQL.query.await('SELECT id, first_name, last_name, callsign, `rank`, department FROM mdt_officers WHERE identifier = ?', { identifier })

    if rows and rows[1] then
        return rows[1]
    end

    return nil
end

local function auditAction(source, action, category, targetType, targetId, details)
    local audit = rawget(_G, 'CortexAudit')
    if type(audit) ~= 'table' or type(audit.write) ~= 'function' then
        return
    end

    local officer = getOfficerBySource(source)
    audit.write(officer and officer.id or 0, action, category, targetType, targetId, details, {
        officer = officer,
        source = source,
    })
end

local function isCameraAdmin(source)
    local cctvConfig = type(Config.CCTV) == 'table' and Config.CCTV or {}
    local ace = trim(cctvConfig.adminAce)

    if ace ~= '' and IsPlayerAceAllowed(source, ace) then
        return true
    end

    local officer = getOfficerBySource(source)
    if not officer then
        return false
    end

    local rank = trim(officer.rank):lower()
    local adminRanks = type(cctvConfig.adminRanks) == 'table' and cctvConfig.adminRanks or {}

    for i = 1, #adminRanks do
        if rank == trim(adminRanks[i]):lower() then
            return true
        end
    end

    return false
end

local function getCameraViewerCount(cameraId)
    local viewers = cameraViewers[cameraId]
    if type(viewers) ~= 'table' then
        return 0
    end

    local count = 0
    for _ in pairs(viewers) do
        count = count + 1
    end

    return count
end

local function getBodycamViewerCount(targetSource)
    local viewers = bodycamViewers[targetSource]
    if type(viewers) ~= 'table' then
        return 0
    end

    local count = 0
    for _ in pairs(viewers) do
        count = count + 1
    end

    return count
end

local function buildCameraPayload(camera)
    return {
        id = camera.camId,
        label = camera.label,
        type = camera.type,
        model = camera.model,
        image = camera.image,
        isOnline = camera.isOnline,
        canRotate = camera.canRotate,
        coords = {
            x = camera.coords.x,
            y = camera.coords.y,
            z = camera.coords.z,
        },
        rotation = {
            x = camera.rotation.x,
            y = camera.rotation.y,
            z = camera.rotation.z,
        },
        createdAt = camera.createdAt,
        viewerCount = getCameraViewerCount(camera.camId),
    }
end

local function generateCameraId()
    local attempts = 0

    while attempts < 20 do
        attempts = attempts + 1
        local candidate = ('CCTV-%d-%04d'):format(os.time(), math.random(1000, 9999))
        if not cctvCameras[candidate] then
            return candidate
        end
    end

    return ('CCTV-%d-%d'):format(os.time(), math.random(100000, 999999))
end

local function clearViewer(source)
    local current = sourceViewing[source]
    if not current then
        return
    end

    if current.kind == 'static' and current.cameraId then
        local viewers = cameraViewers[current.cameraId]
        if viewers then
            viewers[source] = nil
        end
    elseif current.kind == 'bodycam' and current.bodycamSource then
        local viewers = bodycamViewers[current.bodycamSource]
        if viewers then
            viewers[source] = nil
        end
    end

    sourceViewing[source] = nil
end

local function forceStopCameraView(source)
    TriggerClientEvent('cortex_mdtsv:cameraForceStop', source)
    clearViewer(source)
end

local function collectKeys(map)
    local keys = {}
    if type(map) ~= 'table' then
        return keys
    end

    for key in pairs(map) do
        keys[#keys + 1] = key
    end

    return keys
end

local function validateModelKey(modelKey)
    local models = type(Config.CameraModels) == 'table' and Config.CameraModels or {}
    return trim(modelKey) ~= '' and models[modelKey] ~= nil
end

local allowedCamTypes = {
    placed = true,
    dynamic = true,
    store = true,
    bank = true,
    jewelry = true,
    government = true,
    medical = true,
    other = true,
}

local function normalizeCamType(value)
    local t = trim(tostring(value or '')):lower()
    if t == '' then
        return 'placed'
    end
    if allowedCamTypes[t] then
        return t
    end
    return 'other'
end

local function loadPresetCameraList()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'data/cctv_presets.json')
    if type(raw) ~= 'string' or raw == '' then
        return {}
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        return {}
    end

    return decoded
end

local function normalizePresetCameraEntry(entry)
    if type(entry) ~= 'table' then
        return nil
    end

    local camId = trim(entry.camId)
    if camId == '' then
        return nil
    end

    local model = trim(entry.model)
    if not validateModelKey(model) then
        model = 'security_cam_03'
    end

    local coords = decodeVectorPayload(entry.coords, { x = 0.0, y = 0.0, z = 0.0 })
    local rotation = decodeVectorPayload(entry.rotation, { x = -25.0, y = 0.0, z = 0.0 })
    local ctype = normalizeCamType(entry.type)

    return {
        camId = camId,
        label = trim(entry.label) ~= '' and trim(entry.label) or camId,
        type = ctype,
        model = model,
        coords = coords,
        rotation = rotation,
        image = trim(entry.image),
        canRotate = entry.canRotate ~= false,
        isOnline = entry.isOnline ~= false,
        spawnsModel = entry.spawnsModel == true,
    }
end

local function seedPresetCameras()
    local cctvCfg = type(Config.CCTV) == 'table' and Config.CCTV or {}
    if cctvCfg.seedPresetCameras == false then
        return
    end

    local list = loadPresetCameraList()
    if #list == 0 then
        return
    end

    local inserted = 0

    for i = 1, #list do
        local preset = normalizePresetCameraEntry(list[i])
        if preset then
            if usesLocalMode() then
                if not cctvCameras[preset.camId] then
                    cctvCameras[preset.camId] = {
                        camId = preset.camId,
                        label = preset.label,
                        type = preset.type,
                        model = preset.model,
                        coords = preset.coords,
                        rotation = preset.rotation,
                        image = preset.image,
                        canRotate = preset.canRotate,
                        isOnline = preset.isOnline,
                        createdAt = 'preset',
                    }
                    inserted = inserted + 1
                end
            else
                local exists = MySQL.scalar.await('SELECT 1 FROM mdt_cameras WHERE cam_id = ? LIMIT 1', { preset.camId })
                if not exists then
                    MySQL.insert.await([[
                        INSERT INTO mdt_cameras (cam_id, cam_label, cam_type, model, coords, rotation, image, can_rotate, is_online, spawns_model, created_by)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ]], {
                        preset.camId,
                        preset.label,
                        preset.type,
                        preset.model,
                        json.encode(preset.coords),
                        json.encode(preset.rotation),
                        preset.image,
                        preset.canRotate and 1 or 0,
                        preset.isOnline and 1 or 0,
                        preset.spawnsModel and 1 or 0,
                        'SYSTEM',
                    })
                    inserted = inserted + 1
                end
            end
        end
    end

    if inserted > 0 then
        print(('[^2cortex_mdt^0] Seeded %d preset CCTV camera(s) (ps-mdt style list)'):format(inserted))
    end
end

local function mapOnlineSourcesByIdentifier()
    local map = {}
    local players = GetPlayers()

    for i = 1, #players do
        local src = tonumber(players[i])
        if src then
            local identifiers = GetPlayerIdentifiers(src)
            for j = 1, #identifiers do
                map[identifiers[j]] = src
            end
        end
    end

    return map
end

local function loadCamerasFromDatabase()
    if usesLocalMode() then
        cctvCameras = cctvCameras or {}
        return
    end

    local rows = MySQL.query.await('SELECT cam_id, cam_label, cam_type, model, coords, rotation, image, can_rotate, is_online, created_at FROM mdt_cameras ORDER BY created_at DESC') or {}
    local loaded = {}

    for i = 1, #rows do
        local row = rows[i]
        local coords = decodeVectorPayload(row.coords, { x = 0.0, y = 0.0, z = 0.0 })
        local rotation = decodeVectorPayload(row.rotation, { x = 0.0, y = 0.0, z = 0.0 })

        loaded[row.cam_id] = {
            camId = row.cam_id,
            label = row.cam_label or 'Unnamed Camera',
            type = row.cam_type or 'placed',
            model = row.model or 'security_cam_03',
            coords = coords,
            rotation = rotation,
            image = row.image or '',
            canRotate = row.can_rotate ~= 0,
            isOnline = row.is_online ~= 0,
            createdAt = row.created_at,
        }
    end

    cctvCameras = loaded
    print(('[^2cortex_mdt^0] Loaded %d CCTV cameras'):format(#rows))
end

local function buildBodycamRows()
    if usesLocalMode() then
        local localMode = getLocalMode()
        if type(localMode) ~= 'table' or type(localMode.getUnits) ~= 'function' then
            return {}
        end

        local rows = localMode.getUnits() or {}
        local result = {}

        for i = 1, #rows do
            local row = rows[i]
            if trim(row.status):lower() ~= 'off_duty' then
                local officer = type(localMode.getOfficer) == 'function' and localMode.getOfficer(row.officer_id) or nil
                local src = officer and officer.source or nil
                local avatar = nil
                if officer and type(officer.avatar) == 'string' then
                    local trimmedAvatar = trim(officer.avatar)
                    if trimmedAvatar ~= '' then
                        avatar = trimmedAvatar
                    end
                end

                if src and GetPlayerPed(src) ~= 0 then
                    local callsign = trim(row.callsign)
                    if callsign == '' then
                        callsign = tostring(src)
                    end

                    local name = trim((tostring(row.first_name or '') .. ' ' .. tostring(row.last_name or '')))
                    if name == '' then
                        name = GetPlayerName(src) or ('Unit ' .. tostring(src))
                    end

                    result[#result + 1] = {
                        source = src,
                        officerId = row.officer_id,
                        callsign = callsign,
                        name = name,
                        rank = row.rank or 'Officer',
                        department = row.department or row.dept or 'police',
                        viewerCount = getBodycamViewerCount(src),
                        avatar = avatar,
                    }
                end
            end
        end

        table.sort(result, function(a, b)
            return tostring(a.callsign or ''):lower() < tostring(b.callsign or ''):lower()
        end)

        return result
    end

    local rows = MySQL.query.await([[
        SELECT u.officer_id, u.callsign as unit_callsign, u.status,
               o.identifier, o.first_name, o.last_name, o.callsign, o.`rank`, o.department, o.avatar
        FROM mdt_units u
        JOIN mdt_officers o ON o.id = u.officer_id
        WHERE u.status != 'off_duty'
        ORDER BY u.callsign ASC
    ]]) or {}

    local sourceMap = mapOnlineSourcesByIdentifier()
    local result = {}

    for i = 1, #rows do
        local row = rows[i]
        local src = sourceMap[row.identifier]

        if src and GetPlayerPed(src) ~= 0 then
            local callsign = trim(row.unit_callsign)
            if callsign == '' then
                callsign = trim(row.callsign)
            end
            if callsign == '' then
                callsign = tostring(src)
            end

            local firstName = trim(row.first_name)
            local lastName = trim(row.last_name)
            local name = trim((firstName .. ' ' .. lastName))
            if name == '' then
                name = GetPlayerName(src) or ('Unit ' .. tostring(src))
            end

            local avatar = trim(row.avatar or '')
            if avatar == '' then
                avatar = nil
            end

            result[#result + 1] = {
                source = src,
                officerId = row.officer_id,
                callsign = callsign,
                name = name,
                rank = row.rank or 'Officer',
                department = row.department or 'police',
                viewerCount = getBodycamViewerCount(src),
                avatar = avatar,
            }
        end
    end

    return result
end

lib.callback.register('cortex_mdt:getCameras', function(source)
    local list = {}

    for _, camera in pairs(cctvCameras) do
        list[#list + 1] = buildCameraPayload(camera)
    end

    table.sort(list, function(a, b)
        return tostring(a.label):lower() < tostring(b.label):lower()
    end)

    return {
        ok = true,
        cameras = list,
        canManage = isCameraAdmin(source),
    }
end)

lib.callback.register('cortex_mdt:getCameraModels', function(source)
    local models = {}
    local configuredModels = type(Config.CameraModels) == 'table' and Config.CameraModels or {}

    for key, modelName in pairs(configuredModels) do
        models[#models + 1] = {
            value = key,
            label = (key:gsub('_', ' '):upper()) .. ' (' .. modelName .. ')',
            model = modelName,
        }
    end

    table.sort(models, function(a, b)
        return a.label < b.label
    end)

    return {
        ok = true,
        models = models,
        canManage = isCameraAdmin(source),
    }
end)

lib.callback.register('cortex_mdt:createStaticCamera', function(source, data)
    if not isCameraAdmin(source) then
        return { ok = false, error = 'Insufficient permissions.' }
    end

    if type(data) ~= 'table' then
        return { ok = false, error = 'Invalid payload.' }
    end

    local label = trim(data.label)
    if label == '' then
        label = 'Unnamed Camera'
    end

    local model = trim(data.model)
    if not validateModelKey(model) then
        return { ok = false, error = 'Invalid camera model.' }
    end

    local coords = decodeVectorPayload(data.coords, { x = 0.0, y = 0.0, z = 0.0 })
    if math.abs(coords.x) < 0.001 and math.abs(coords.y) < 0.001 and math.abs(coords.z) < 0.001 then
        return { ok = false, error = 'Invalid camera coordinates.' }
    end

    local rotation = decodeVectorPayload(data.rotation, { x = -20.0, y = 0.0, z = 0.0 })
    local camId = generateCameraId()
    if not usesLocalMode() then
        local identifier = getPlayerIdentifier(source)

        local inserted = MySQL.insert.await([[
            INSERT INTO mdt_cameras (cam_id, cam_label, cam_type, model, coords, rotation, image, can_rotate, is_online, spawns_model, created_by)
            VALUES (?, ?, 'placed', ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            camId,
            label,
            model,
            json.encode(coords),
            json.encode(rotation),
            trim(data.image),
            data.canRotate == false and 0 or 1,
            data.isOnline == false and 0 or 1,
            1,
            identifier,
        })

        if not inserted then
            return { ok = false, error = 'Failed to create camera.' }
        end
    end

    cctvCameras[camId] = {
        camId = camId,
        label = label,
        type = 'placed',
        model = model,
        coords = coords,
        rotation = rotation,
        image = trim(data.image),
        canRotate = data.canRotate == false and false or true,
        isOnline = data.isOnline == false and false or true,
        createdAt = os.date('%Y-%m-%d %H:%M:%S'),
    }

    auditAction(source, 'camera_create', 'camera', 'camera', camId, {
        label = label,
        model = model,
    })

    return {
        ok = true,
        camera = buildCameraPayload(cctvCameras[camId]),
        canManage = true,
    }
end)

lib.callback.register('cortex_mdt:deleteCamera', function(source, data)
    if not isCameraAdmin(source) then
        return { ok = false, error = 'Insufficient permissions.' }
    end

    local cameraId = trim(type(data) == 'table' and data.cameraId or nil)
    if cameraId == '' or not cctvCameras[cameraId] then
        return { ok = false, error = 'Camera not found.' }
    end

    local viewers = cameraViewers[cameraId] or {}
    local viewerSources = collectKeys(viewers)
    for i = 1, #viewerSources do
        local viewerSource = viewerSources[i]
        forceStopCameraView(viewerSource)
    end

    if not usesLocalMode() then
        MySQL.update.await('DELETE FROM mdt_cameras WHERE cam_id = ?', { cameraId })
    end

    cctvCameras[cameraId] = nil
    cameraViewers[cameraId] = nil

    auditAction(source, 'camera_delete', 'camera', 'camera', cameraId, nil)

    return { ok = true }
end)

lib.callback.register('cortex_mdt:setCameraOnline', function(source, data)
    if not isCameraAdmin(source) then
        return { ok = false, error = 'Insufficient permissions.' }
    end

    if type(data) ~= 'table' then
        return { ok = false, error = 'Invalid payload.' }
    end

    local cameraId = trim(data.cameraId)
    local camera = cctvCameras[cameraId]
    if not camera then
        return { ok = false, error = 'Camera not found.' }
    end

    local isOnline = data.isOnline == true
    camera.isOnline = isOnline

    if not usesLocalMode() then
        MySQL.update.await('UPDATE mdt_cameras SET is_online = ? WHERE cam_id = ?', {
            isOnline and 1 or 0,
            cameraId,
        })
    end

    if not isOnline then
        local viewers = cameraViewers[cameraId] or {}
        local viewerSources = collectKeys(viewers)
        for i = 1, #viewerSources do
            local viewerSource = viewerSources[i]
            forceStopCameraView(viewerSource)
        end
    end

    auditAction(source, 'camera_status_update', 'camera', 'camera', cameraId, {
        isOnline = isOnline,
    })

    return {
        ok = true,
        camera = buildCameraPayload(camera),
    }
end)

lib.callback.register('cortex_mdt:viewCamera', function(source, data)
    local cameraId = trim(type(data) == 'table' and data.cameraId or nil)
    local camera = cctvCameras[cameraId]

    if not camera then
        return { ok = false, error = 'Camera not found.' }
    end

    if camera.isOnline == false then
        return { ok = false, error = 'Camera is offline.' }
    end

    clearViewer(source)
    cameraViewers[cameraId] = cameraViewers[cameraId] or {}
    cameraViewers[cameraId][source] = true
    sourceViewing[source] = {
        kind = 'static',
        cameraId = cameraId,
    }

    auditAction(source, 'camera_view', 'camera', 'camera', cameraId, nil)

    return {
        ok = true,
        camera = buildCameraPayload(camera),
    }
end)

lib.callback.register('cortex_mdt:getBodycams', function(source)
    return {
        ok = true,
        bodycams = buildBodycamRows(),
    }
end)

lib.callback.register('cortex_mdt:viewBodycam', function(source, data)
    local targetSource = tonumber(type(data) == 'table' and data.targetSource or nil)
    if not targetSource or GetPlayerPed(targetSource) == 0 then
        return { ok = false, error = 'Bodycam target is offline.' }
    end

    local availableBodycams = buildBodycamRows()
    local selected = nil

    for i = 1, #availableBodycams do
        if availableBodycams[i].source == targetSource then
            selected = availableBodycams[i]
            break
        end
    end

    if not selected then
        return { ok = false, error = 'Bodycam is not available.' }
    end

    clearViewer(source)
    bodycamViewers[targetSource] = bodycamViewers[targetSource] or {}
    bodycamViewers[targetSource][source] = true
    sourceViewing[source] = {
        kind = 'bodycam',
        bodycamSource = targetSource,
    }

    auditAction(source, 'bodycam_view', 'camera', 'bodycam', targetSource, {
        callsign = selected.callsign,
    })

    return {
        ok = true,
        bodycam = selected,
    }
end)

lib.callback.register('cortex_mdt:stopCameraView', function(source)
    local current = sourceViewing[source]
    clearViewer(source)
    if current then
        auditAction(source, 'camera_view_stop', 'camera', current.kind, current.cameraId or current.bodycamSource, nil)
    end
    return { ok = true }
end)

AddEventHandler('playerDropped', function()
    local sourceId = source
    clearViewer(sourceId)

    local targetViewers = bodycamViewers[sourceId]
    if targetViewers then
        local viewerSources = collectKeys(targetViewers)
        for i = 1, #viewerSources do
            local viewerSource = viewerSources[i]
            forceStopCameraView(viewerSource)
        end
        bodycamViewers[sourceId] = nil
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if usesLocalMode() then
        cctvCameras = {}
        seedPresetCameras()
        return
    end

    seedPresetCameras()
    loadCamerasFromDatabase()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    local viewerSources = collectKeys(sourceViewing)
    for i = 1, #viewerSources do
        local viewerSource = viewerSources[i]
        forceStopCameraView(viewerSource)
    end
end)

exports('isViewingCamera', function(source)
    return sourceViewing[source] ~= nil
end)
