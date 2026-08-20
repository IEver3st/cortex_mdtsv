local cctvCameras = {}
local cameraViewers = {}
local bodycamViewers = {}
local dashcamViewers = {}
local airFeedViewers = {}
local dashcamFeeds = {}
local sourceViewing = {}
local bodycamOptOut = {}
local bodycamFrameAt = {}
local liveFeedPushRunning = false
local updateBodycamDemand

local function getPersistentStore()
    local store = rawget(_G, 'CortexPersistentSessionStore')
    return type(store) == 'table' and store or nil
end

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

local function finiteNumber(value, minimum, maximum, fallback)
    local number = tonumber(value)
    if not number or number ~= number or math.abs(number) == math.huge then
        return fallback
    end
    if minimum and number < minimum then number = minimum end
    if maximum and number > maximum then number = maximum end
    return number
end

local function getVehicleClassSafely(vehicle)
    local native = rawget(_G, 'GetVehicleClass')
    if type(native) ~= 'function' then
        return nil
    end

    local ok, vehicleClass = pcall(native, vehicle)
    if not ok then
        return nil
    end

    return finiteNumber(vehicleClass, 0, 31, nil)
end

local function getBodycamConfig()
    return type(Config.Bodycams) == 'table' and Config.Bodycams or {}
end

local function getDashcamConfig()
    return type(Config.Dashcams) == 'table' and Config.Dashcams or {}
end

local function getAirSupportConfig()
    return type(Config.AirSupport) == 'table' and Config.AirSupport or {}
end

local function sameRoutingBucket(firstSource, secondSource, allowCrossBucket)
    if allowCrossBucket == true then return true end
    return GetPlayerRoutingBucket(firstSource) == GetPlayerRoutingBucket(secondSource)
end

local function playerExists(source)
    source = tonumber(source)
    return source and source > 0 and GetPlayerName(source) ~= nil
end

local function officerIsOnDuty(source)
    if not playerExists(source) then return false end
    local framework = rawget(_G, 'CortexMdtFramework')
    if type(framework) ~= 'table' or type(framework.isOnDuty) ~= 'function' then
        return false
    end

    local ok, onDuty = pcall(framework.isOnDuty, source)
    return ok and onDuty == true
end

local function airFeedCrewIsOnDuty(feed)
    if type(feed) ~= 'table' then return false end

    local config = getAirSupportConfig()
    local operatorSource = tonumber(feed.operatorSource)
    if not operatorSource or operatorSource <= 0 then
        return false
    end

    if config.requireOperatorOnDuty ~= false and not officerIsOnDuty(operatorSource) then
        return false
    end

    local pilotSource = tonumber(feed.pilotSource)
    if config.requirePilotOnDuty ~= false
        and pilotSource and pilotSource > 0
        and pilotSource ~= operatorSource
        and not officerIsOnDuty(pilotSource) then
        return false
    end

    return true
end

local function countViewers(viewers)
    local count = 0
    for _ in pairs(type(viewers) == 'table' and viewers or {}) do count = count + 1 end
    return count
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
    return countViewers(cameraViewers[cameraId])
end

local function getBodycamViewerCount(targetSource)
    return countViewers(bodycamViewers[targetSource])
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
        if type(updateBodycamDemand) == 'function' then
            updateBodycamDemand(current.bodycamSource)
        end
    elseif current.kind == 'dashcam' and current.feedId then
        local viewers = dashcamViewers[current.feedId]
        if viewers then
            viewers[source] = nil
            if next(viewers) == nil then
                dashcamViewers[current.feedId] = nil
                dashcamFeeds[current.feedId] = nil
            end
        end
    elseif current.kind == 'air' and current.feedId then
        local viewers = airFeedViewers[current.feedId]
        if viewers then
            viewers[source] = nil
            if next(viewers) == nil then airFeedViewers[current.feedId] = nil end
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

updateBodycamDemand = function(targetSource)
    local viewers = bodycamViewers[targetSource]
    local count = countViewers(viewers)
    TriggerClientEvent('cortex_mdtsv:bodycamStreamDemand', targetSource, count > 0, count)
end

local function stopBodycamTarget(targetSource)
    local viewers = bodycamViewers[targetSource]
    if type(viewers) == 'table' then
        local viewerSources = collectKeys(viewers)
        for i = 1, #viewerSources do forceStopCameraView(viewerSources[i]) end
    end
    bodycamViewers[targetSource] = nil
    updateBodycamDemand(targetSource)
end

local function bodycamIsEnabledFor(source)
    local config = getBodycamConfig()
    if config.enabled == false or bodycamOptOut[source] == true then return false end
    return GetPlayerPed(source) ~= 0
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

local function persistLocalCamera(camera)
    if not usesLocalMode() or type(camera) ~= 'table' then return end
    local store = getPersistentStore()
    if not store or type(store.set) ~= 'function' then return end
    store.set('cctv:cameras', camera.camId, {
        camId = camera.camId,
        label = camera.label,
        type = camera.type,
        model = camera.model,
        coords = camera.coords,
        rotation = camera.rotation,
        image = camera.image,
        canRotate = camera.canRotate == true,
        isOnline = camera.isOnline ~= false,
        createdAt = camera.createdAt,
    })
end

local function deletePersistedLocalCamera(cameraId)
    if not usesLocalMode() then return end
    local store = getPersistentStore()
    if store and type(store.delete) == 'function' then
        store.delete('cctv:cameras', cameraId)
    end
end

local function loadLocalCameras()
    cctvCameras = {}
    local store = getPersistentStore()
    local rows = store and type(store.list) == 'function' and store.list('cctv:cameras') or {}
    for i = 1, #rows do
        local row = normalizePresetCameraEntry(rows[i])
        if row then
            cctvCameras[row.camId] = {
                camId = row.camId,
                label = row.label,
                type = row.type,
                model = row.model,
                coords = row.coords,
                rotation = row.rotation,
                image = row.image,
                canRotate = row.canRotate,
                isOnline = row.isOnline,
                createdAt = rows[i].createdAt or 'restored',
            }
        end
    end
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
                    persistLocalCamera(cctvCameras[preset.camId])
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

local function buildBodycamRows(viewerSource)
    local config = getBodycamConfig()
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

                if src and bodycamIsEnabledFor(src)
                    and (not viewerSource or sameRoutingBucket(viewerSource, src, config.allowCrossRoutingBuckets)) then
                    local callsign = trim(row.callsign)
                    if callsign == '' then
                        callsign = tostring(src)
                    end

                    local name = trim((tostring(row.first_name or '') .. ' ' .. tostring(row.last_name or '')))
                    if name == '' then
                        name = GetPlayerName(src) or ('Unit ' .. tostring(src))
                    end

                    result[#result + 1] = {
                        id = ('body:%s'):format(tostring(src)),
                        feedId = ('body:%s'):format(tostring(src)),
                        feedType = 'bodycam',
                        source = src,
                        officerId = row.officer_id,
                        callsign = callsign,
                        name = name,
                        rank = row.rank or 'Officer',
                        department = row.department or row.dept or 'police',
                        viewerCount = getBodycamViewerCount(src),
                        avatar = avatar,
                        status = 'live',
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

        if src and bodycamIsEnabledFor(src)
            and (not viewerSource or sameRoutingBucket(viewerSource, src, config.allowCrossRoutingBuckets)) then
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
                id = ('body:%s'):format(tostring(src)),
                feedId = ('body:%s'):format(tostring(src)),
                feedType = 'bodycam',
                source = src,
                officerId = row.officer_id,
                callsign = callsign,
                name = name,
                rank = row.rank or 'Officer',
                department = row.department or 'police',
                viewerCount = getBodycamViewerCount(src),
                avatar = avatar,
                status = 'live',
            }
        end
    end

    return result
end

local function buildDashcamPayload(source, officer)
    local config = getDashcamConfig()
    if config.enabled == false then return nil end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then return nil end
    local emergencyClass = math.floor(finiteNumber(config.emergencyVehicleClass, 0, 31, 18))
    local vehicleClass = getVehicleClassSafely(vehicle)
    if not vehicleClass or math.floor(vehicleClass) ~= emergencyClass then return nil end
    local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
    if not vehicleNetId or vehicleNetId <= 0 then return nil end

    local callsign = trim(officer and (officer.callsign or officer.unit_callsign))
    if callsign == '' then callsign = tostring(source) end
    local firstName = trim(officer and (officer.first_name or officer.firstName))
    local lastName = trim(officer and (officer.last_name or officer.lastName))
    local officerName = trim(('%s %s'):format(firstName, lastName))
    if officerName == '' then officerName = GetPlayerName(source) or ('Unit ' .. tostring(source)) end
    local plate = trim(GetVehicleNumberPlateText(vehicle))
    local feedId = ('dash:%s'):format(tostring(vehicleNetId))

    return {
        id = feedId,
        feedId = feedId,
        feedType = 'dashcam',
        source = source,
        vehicleNetId = vehicleNetId,
        modelHash = GetEntityModel(vehicle),
        callsign = callsign,
        name = officerName,
        rank = officer and officer.rank or 'Officer',
        department = officer and (officer.department or officer.dept) or 'police',
        plate = plate ~= '' and plate or 'NO PLATE',
        label = ('%s · %s'):format(callsign, plate ~= '' and plate or 'DASHCAM'),
        viewerCount = countViewers(dashcamViewers[feedId]),
        status = 'live',
    }
end

local function buildDashcamRows()
    local config = getDashcamConfig()
    if config.enabled == false then return {} end
    local result = {}

    if usesLocalMode() then
        local localMode = getLocalMode()
        local units = type(localMode) == 'table' and type(localMode.getUnits) == 'function' and localMode.getUnits() or {}
        for i = 1, #units do
            local unit = units[i]
            if trim(unit.status):lower() ~= 'off_duty' then
                local officer = type(localMode.getOfficer) == 'function' and localMode.getOfficer(unit.officer_id) or nil
                local source = officer and tonumber(officer.source) or nil
                local row = source and buildDashcamPayload(source, {
                    callsign = unit.callsign,
                    first_name = unit.first_name,
                    last_name = unit.last_name,
                    rank = unit.rank,
                    department = unit.department,
                }) or nil
                if row then result[#result + 1] = row end
            end
        end
    else
        local rows = MySQL.query.await([[
            SELECT u.officer_id, u.callsign AS unit_callsign, u.status,
                   o.identifier, o.first_name, o.last_name, o.callsign, o.`rank`, o.department
            FROM mdt_units u
            JOIN mdt_officers o ON o.id = u.officer_id
            WHERE u.status != 'off_duty'
        ]]) or {}
        local sourceMap = mapOnlineSourcesByIdentifier()
        for i = 1, #rows do
            local source = sourceMap[rows[i].identifier]
            local row = source and buildDashcamPayload(source, rows[i]) or nil
            if row then result[#result + 1] = row end
        end
    end

    table.sort(result, function(a, b) return tostring(a.callsign) < tostring(b.callsign) end)
    return result
end

local function getAirResource()
    local config = getAirSupportConfig()
    local name = trim(config.resource)
    return name ~= '' and name or 'cortex_polcam'
end

local function sanitizeAirFeed(feed)
    if type(feed) ~= 'table' or feed.cameraActive ~= true then return nil end
    local feedId = trim(feed.feedId)
    if not feedId:match('^air:%d+$') then return nil end
    local preview = type(feed.preview) == 'table' and feed.preview or {}
    local coords = type(preview.coords) == 'table' and preview.coords or {}
    local rotation = type(preview.rotation) == 'table' and preview.rotation or {}
    local cleanCoords = {
        x = finiteNumber(coords.x or coords[1], -10000, 10000, nil),
        y = finiteNumber(coords.y or coords[2], -10000, 10000, nil),
        z = finiteNumber(coords.z or coords[3], -2000, 3000, nil),
    }
    local cleanRotation = {
        x = finiteNumber(rotation.x or rotation[1], -180, 180, nil),
        y = finiteNumber(rotation.y or rotation[2], -180, 180, nil),
        z = finiteNumber(rotation.z or rotation[3], -360, 360, nil),
    }
    if not cleanCoords.x or not cleanCoords.y or not cleanCoords.z or not cleanRotation.x or not cleanRotation.y or not cleanRotation.z then
        return nil
    end

    local tracking = type(feed.tracking) == 'table' and feed.tracking or {}
    local targetCoords = type(tracking.targetCoords) == 'table' and {
        x = finiteNumber(tracking.targetCoords.x or tracking.targetCoords[1], -10000, 10000, nil),
        y = finiteNumber(tracking.targetCoords.y or tracking.targetCoords[2], -10000, 10000, nil),
        z = finiteNumber(tracking.targetCoords.z or tracking.targetCoords[3], -2000, 3000, nil),
    } or nil
    if targetCoords and (not targetCoords.x or not targetCoords.y or not targetCoords.z) then targetCoords = nil end
    return {
        id = feedId,
        feedId = feedId,
        feedType = 'air',
        heliNetId = math.floor(finiteNumber(feed.heliNetId, 1, 2147483647, 0)),
        source = math.floor(finiteNumber(feed.operatorSource, 1, 65535, 0)),
        operatorSource = math.floor(finiteNumber(feed.operatorSource, 1, 65535, 0)),
        pilotSource = math.floor(finiteNumber(feed.pilotSource, 1, 65535, 0)),
        label = trim(feed.label):sub(1, 64),
        callsign = trim(feed.callsign):sub(1, 32),
        cameraActive = true,
        preview = {
            coords = cleanCoords,
            rotation = cleanRotation,
            fov = finiteNumber(preview.fov, 1, 130, 50),
            visionMode = trim(preview.visionMode):sub(1, 24),
            status = trim(preview.status):sub(1, 32),
        },
        tracking = {
            active = tracking.active == true,
            targetNetId = finiteNumber(tracking.targetNetId, 1, 2147483647, nil),
            targetType = trim(tracking.targetType):sub(1, 24),
            targetCoords = targetCoords,
            heading = finiteNumber(tracking.heading, -360, 360, nil),
            plate = trim(tracking.plate):sub(1, 16),
            vehicleLabel = trim(tracking.vehicleLabel):sub(1, 64),
        },
        viewerCount = countViewers(airFeedViewers[feedId]),
        status = 'live',
        lastSeenAt = finiteNumber(feed.lastSeenAt, 0, 2147483647, 0),
    }
end

local function getAirFeedById(feedId)
    local config = getAirSupportConfig()
    if config.enabled == false then return nil end
    local resource = getAirResource()
    if GetResourceState(resource) ~= 'started' then return nil end
    local ok, feed = pcall(function() return exports[resource]:GetAirFeedById(feedId) end)
    local sanitized = ok and sanitizeAirFeed(feed) or nil
    if sanitized and not airFeedCrewIsOnDuty(sanitized) then
        return nil
    end
    return sanitized
end

local function buildAirFeedRows(source)
    local config = getAirSupportConfig()
    if config.enabled == false then return {} end
    local resource = getAirResource()
    if GetResourceState(resource) ~= 'started' then return {} end
    local ok, feeds = pcall(function() return exports[resource]:GetActiveAirFeeds() end)
    if not ok or type(feeds) ~= 'table' then return {} end
    local result = {}
    for i = 1, #feeds do
        local feed = sanitizeAirFeed(feeds[i])
        if feed and feed.operatorSource > 0
            and airFeedCrewIsOnDuty(feed)
            and sameRoutingBucket(source, feed.operatorSource, config.allowCrossRoutingBuckets) then
            result[#result + 1] = feed
        end
    end
    table.sort(result, function(a, b) return tostring(a.callsign) < tostring(b.callsign) end)
    return result
end

local function findDashcam(feedId)
    local rows = buildDashcamRows()
    for i = 1, #rows do if rows[i].feedId == feedId then return rows[i] end end
    return nil
end

local function pushDashcamFrame(feed, viewerSource)
    local ped = GetPlayerPed(feed.source)
    local vehicle = ped and GetVehiclePedIsIn(ped, false) or 0
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle)
        or GetPedInVehicleSeat(vehicle, -1) ~= ped
        or NetworkGetNetworkIdFromEntity(vehicle) ~= feed.vehicleNetId then
        return false
    end
    local coords = GetEntityCoords(vehicle)
    local velocity = GetEntityVelocity(vehicle)
    local speed = math.sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y) + (velocity.z * velocity.z))
    TriggerClientEvent('cortex_mdtsv:dashcamFrame', viewerSource, {
        feedId = feed.feedId,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        heading = GetEntityHeading(vehicle),
        speed = speed,
        modelHash = GetEntityModel(vehicle),
        plate = feed.plate,
    })
    return true
end

local function startLiveFeedPushThread()
    if liveFeedPushRunning then return end
    liveFeedPushRunning = true
    CreateThread(function()
        while next(bodycamViewers) ~= nil or next(dashcamViewers) ~= nil or next(airFeedViewers) ~= nil do
            for feedId, viewers in pairs(dashcamViewers) do
                local feed = dashcamFeeds[feedId]
                local viewerSources = collectKeys(viewers)
                for i = 1, #viewerSources do
                    local viewer = viewerSources[i]
                    local allowed = playerExists(viewer) and officerIsOnDuty(viewer) and feed
                        and officerIsOnDuty(feed.source)
                        and sameRoutingBucket(viewer, feed.source, getDashcamConfig().allowCrossRoutingBuckets)
                    if not allowed or not pushDashcamFrame(feed, viewer) then forceStopCameraView(viewer) end
                end
                if next(viewers) == nil then dashcamViewers[feedId] = nil end
            end

            for feedId, viewers in pairs(airFeedViewers) do
                local feed = getAirFeedById(feedId)
                local viewerSources = collectKeys(viewers)
                for i = 1, #viewerSources do
                    local viewer = viewerSources[i]
                    local allowed = playerExists(viewer) and officerIsOnDuty(viewer)
                        and feed and feed.operatorSource > 0 and playerExists(feed.operatorSource)
                        and airFeedCrewIsOnDuty(feed)
                        and sameRoutingBucket(viewer, feed.operatorSource, getAirSupportConfig().allowCrossRoutingBuckets)
                    if allowed then
                        TriggerClientEvent('cortex_mdtsv:airFeedFrame', viewer, feed)
                    else
                        forceStopCameraView(viewer)
                    end
                end
                if next(viewers) == nil then airFeedViewers[feedId] = nil end
            end

            local now = GetGameTimer()
            local staleAfter = math.floor(finiteNumber(getBodycamConfig().staleFrameMs, 500, 15000, 2000))
            for targetSource, viewers in pairs(bodycamViewers) do
                local targetAvailable = bodycamIsEnabledFor(targetSource) and officerIsOnDuty(targetSource)
                local lastFrame = tonumber(bodycamFrameAt[targetSource]) or 0
                if not targetAvailable or (lastFrame > 0 and now >= lastFrame and now - lastFrame > staleAfter) then
                    stopBodycamTarget(targetSource)
                else
                    local viewerSources = collectKeys(viewers)
                    for i = 1, #viewerSources do
                        local viewer = viewerSources[i]
                        if not playerExists(viewer) or not officerIsOnDuty(viewer)
                            or not sameRoutingBucket(viewer, targetSource, getBodycamConfig().allowCrossRoutingBuckets) then
                            forceStopCameraView(viewer)
                        end
                    end
                end
            end

            local dashInterval = finiteNumber(getDashcamConfig().syncIntervalMs, 100, 2000, 200)
            local airInterval = finiteNumber(getAirSupportConfig().syncIntervalMs, 100, 2000, 200)
            Wait(math.floor(math.min(dashInterval, airInterval, 250)))
        end
        liveFeedPushRunning = false
    end)
end

local function getLiveFeedCapabilities()
    local audio = type(getBodycamConfig().audio) == 'table' and getBodycamConfig().audio or {}
    local dashcamClassNative = rawget(_G, 'GetVehicleClass')
    return {
        bodycams = getBodycamConfig().enabled ~= false,
        dashcams = getDashcamConfig().enabled ~= false and type(dashcamClassNative) == 'function',
        airSupport = getAirSupportConfig().enabled ~= false,
        airSupportConnected = GetResourceState(getAirResource()) == 'started',
        bodycamAudio = audio.enabled == true,
        bodycamAudioMode = audio.mode == 'proximity' and 'proximity' or 'disabled',
    }
end

local function getLiveFeeds(source)
    if not officerIsOnDuty(source) then
        return { ok = false, error = 'You must be on duty to access live operational feeds.', code = 'off_duty' }
    end

    local bodycams = buildBodycamRows(source)
    local dashcamOk, dashcams = pcall(buildDashcamRows)
    if not dashcamOk or type(dashcams) ~= 'table' then dashcams = {} end
    local visibleDashcams = {}
    for i = 1, #dashcams do
        local feed = dashcams[i]
        if sameRoutingBucket(source, feed.source, getDashcamConfig().allowCrossRoutingBuckets) then
            visibleDashcams[#visibleDashcams + 1] = feed
        end
    end
    local airFeeds = buildAirFeedRows(source)

    return {
        ok = true,
        bodycams = bodycams,
        dashcams = visibleDashcams,
        airFeeds = airFeeds,
        feeds = {
            bodycams = bodycams,
            dashcams = visibleDashcams,
            air = airFeeds,
        },
        capabilities = getLiveFeedCapabilities(),
    }
end

local function findBodycam(source, feedId)
    local rows = buildBodycamRows(source)
    for i = 1, #rows do
        if rows[i].feedId == feedId then return rows[i] end
    end
    return nil
end

local function startLiveFeedView(source, data)
    if not officerIsOnDuty(source) then
        return { ok = false, error = 'You must be on duty to view live feeds.', code = 'off_duty' }
    end
    if type(data) ~= 'table' then return { ok = false, error = 'Invalid feed request.' } end

    local feedType = trim(data.feedType):lower()
    local feedId = trim(data.feedId)
    if #feedId > 80 then return { ok = false, error = 'Invalid feed identifier.' } end
    local maximumViewers = math.floor(finiteNumber(getBodycamConfig().maxViewersPerFeed, 1, 64, 16))
    local feed
    local currentView = sourceViewing[source]

    if feedType == 'bodycam' then
        feed = findBodycam(source, feedId)
        if not feed then return { ok = false, error = 'Bodycam is unavailable or outside your routing bucket.' } end
        local alreadyWatching = currentView and currentView.kind == 'bodycam' and currentView.feedId == feedId
        if not alreadyWatching and getBodycamViewerCount(feed.source) >= maximumViewers then
            return { ok = false, error = 'This bodycam has reached its viewer limit.', code = 'viewer_limit' }
        end
        clearViewer(source)
        bodycamViewers[feed.source] = bodycamViewers[feed.source] or {}
        bodycamViewers[feed.source][source] = true
        sourceViewing[source] = { kind = 'bodycam', bodycamSource = feed.source, feedId = feed.feedId }
        bodycamFrameAt[feed.source] = GetGameTimer()
        updateBodycamDemand(feed.source)
        startLiveFeedPushThread()
    elseif feedType == 'dashcam' then
        feed = findDashcam(feedId)
        if not feed or not sameRoutingBucket(source, feed.source, getDashcamConfig().allowCrossRoutingBuckets) then
            return { ok = false, error = 'Dashcam is unavailable or outside your routing bucket.' }
        end
        local alreadyWatching = currentView and currentView.kind == 'dashcam' and currentView.feedId == feedId
        if not alreadyWatching and countViewers(dashcamViewers[feedId]) >= maximumViewers then
            return { ok = false, error = 'This dashcam has reached its viewer limit.', code = 'viewer_limit' }
        end
        clearViewer(source)
        dashcamFeeds[feedId] = feed
        dashcamViewers[feedId] = dashcamViewers[feedId] or {}
        dashcamViewers[feedId][source] = true
        sourceViewing[source] = { kind = 'dashcam', feedId = feedId, source = feed.source }
        startLiveFeedPushThread()
    elseif feedType == 'air' then
        feed = getAirFeedById(feedId)
        if not feed or feed.operatorSource <= 0
            or not airFeedCrewIsOnDuty(feed)
            or not sameRoutingBucket(source, feed.operatorSource, getAirSupportConfig().allowCrossRoutingBuckets) then
            return { ok = false, error = 'Air-support feed is unavailable, off duty, or outside your routing bucket.' }
        end
        local alreadyWatching = currentView and currentView.kind == 'air' and currentView.feedId == feedId
        if not alreadyWatching and countViewers(airFeedViewers[feedId]) >= maximumViewers then
            return { ok = false, error = 'This air-support feed has reached its viewer limit.', code = 'viewer_limit' }
        end
        clearViewer(source)
        airFeedViewers[feedId] = airFeedViewers[feedId] or {}
        airFeedViewers[feedId][source] = true
        sourceViewing[source] = { kind = 'air', feedId = feedId, source = feed.operatorSource }
        startLiveFeedPushThread()
    else
        return { ok = false, error = 'Unsupported feed type.' }
    end

    feed.viewerCount = feedType == 'bodycam' and getBodycamViewerCount(feed.source)
        or (feedType == 'dashcam' and countViewers(dashcamViewers[feedId]) or countViewers(airFeedViewers[feedId]))
    local direction = data.direction == 'rear' and 'rear' or 'front'
    auditAction(source, 'live_feed_view', 'camera', feedType, feedId, { direction = direction })
    return {
        ok = true,
        feed = feed,
        direction = direction,
        capabilities = getLiveFeedCapabilities(),
    }
end

lib.callback.register('cortex_mdt:getLiveFeeds', function(source)
    return getLiveFeeds(source)
end)

lib.callback.register('cortex_mdt:viewLiveFeed', function(source, data)
    return startLiveFeedView(source, data)
end)

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
    persistLocalCamera(cctvCameras[camId])

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
    deletePersistedLocalCamera(cameraId)

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
    persistLocalCamera(camera)

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
    return getLiveFeeds(source)
end)

lib.callback.register('cortex_mdt:viewBodycam', function(source, data)
    local targetSource = tonumber(type(data) == 'table' and data.targetSource or nil)
    if not targetSource or not playerExists(targetSource) then
        return { ok = false, error = 'Bodycam target is offline.' }
    end
    local response = startLiveFeedView(source, {
        feedType = 'bodycam',
        feedId = ('body:%s'):format(tostring(targetSource)),
    })
    if response.ok then response.bodycam = response.feed end
    return response
end)

lib.callback.register('cortex_mdt:stopCameraView', function(source)
    local current = sourceViewing[source]
    clearViewer(source)
    if current then
        auditAction(source, 'camera_view_stop', 'camera', current.kind, current.cameraId or current.feedId or current.bodycamSource, nil)
    end
    return { ok = true }
end)

RegisterNetEvent('cortex_mdtsv:bodycamFrame', function(payload)
    local sourceId = source
    local viewers = bodycamViewers[sourceId]
    if type(viewers) ~= 'table' or next(viewers) == nil then return end
    if type(payload) ~= 'table' or not bodycamIsEnabledFor(sourceId) or not officerIsOnDuty(sourceId) then
        stopBodycamTarget(sourceId)
        return
    end

    local now = GetGameTimer()
    local minimumInterval = math.floor(finiteNumber(getBodycamConfig().streamIntervalMs, 50, 1000, 100))
    local previousAt = tonumber(bodycamFrameAt[sourceId]) or 0
    if previousAt > 0 and now >= previousAt and now - previousAt < math.max(30, minimumInterval - 15) then return end

    local coords = type(payload.coords) == 'table' and payload.coords or {}
    local rotation = type(payload.rotation) == 'table' and payload.rotation or {}
    local x = finiteNumber(coords.x or coords[1], -10000, 10000, nil)
    local y = finiteNumber(coords.y or coords[2], -10000, 10000, nil)
    local z = finiteNumber(coords.z or coords[3], -2000, 3000, nil)
    local rx = finiteNumber(rotation.x or rotation[1], -89, 89, nil)
    local ry = finiteNumber(rotation.y or rotation[2], -180, 180, nil)
    local rz = finiteNumber(rotation.z or rotation[3], -720, 720, nil)
    if not x or not y or not z or not rx or not ry or not rz then return end

    local ped = GetPlayerPed(sourceId)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    local serverCoords = GetEntityCoords(ped)
    local dx, dy, dz = x - serverCoords.x, y - serverCoords.y, z - serverCoords.z
    if (dx * dx) + (dy * dy) + (dz * dz) > 25.0 then return end

    bodycamFrameAt[sourceId] = now
    local frame = {
        feedId = ('body:%s'):format(tostring(sourceId)),
        source = sourceId,
        coords = { x = x, y = y, z = z },
        rotation = { x = rx, y = ry, z = rz },
        fov = finiteNumber(payload.fov, 20, 100, 55),
        speed = finiteNumber(payload.speed, 0, 150, 0),
    }

    local viewerSources = collectKeys(viewers)
    for i = 1, #viewerSources do
        local viewer = viewerSources[i]
        if playerExists(viewer) and officerIsOnDuty(viewer)
            and sameRoutingBucket(viewer, sourceId, getBodycamConfig().allowCrossRoutingBuckets) then
            TriggerClientEvent('cortex_mdtsv:bodycamFrame', viewer, frame)
        else
            forceStopCameraView(viewer)
        end
    end
end)

local bodycamCommand = trim(getBodycamConfig().command)
if bodycamCommand ~= '' then
    RegisterCommand(bodycamCommand, function(sourceId)
        if sourceId <= 0 then return end
        if not officerIsOnDuty(sourceId) then
            TriggerClientEvent('cortex_mdtsv:bodycamAvailability', sourceId, false, 'You must be on duty to change bodycam availability.')
            return
        end
        bodycamOptOut[sourceId] = bodycamOptOut[sourceId] ~= true
        local enabled = bodycamOptOut[sourceId] ~= true
        if not enabled then stopBodycamTarget(sourceId) end
        TriggerClientEvent('cortex_mdtsv:bodycamAvailability', sourceId, enabled,
            enabled and 'Bodycam feed available.' or 'Bodycam feed unavailable.')
    end, false)
end

AddEventHandler('playerDropped', function()
    local sourceId = source
    clearViewer(sourceId)

    bodycamOptOut[sourceId] = nil
    bodycamFrameAt[sourceId] = nil

    local targetViewers = bodycamViewers[sourceId]
    if targetViewers then
        local viewerSources = collectKeys(targetViewers)
        for i = 1, #viewerSources do
            local viewerSource = viewerSources[i]
            forceStopCameraView(viewerSource)
        end
        bodycamViewers[sourceId] = nil
    end

    for feedId, feed in pairs(dashcamFeeds) do
        if feed.source == sourceId then
            local viewers = collectKeys(dashcamViewers[feedId])
            for i = 1, #viewers do forceStopCameraView(viewers[i]) end
            dashcamViewers[feedId] = nil
            dashcamFeeds[feedId] = nil
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if usesLocalMode() then
        loadLocalCameras()
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
