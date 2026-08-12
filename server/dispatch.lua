local cfg = type(Config.Dispatch) == 'table' and Config.Dispatch or {}
local enabled = cfg.enabled ~= false
local panicCooldownSeconds = tonumber(cfg.panicCooldownSeconds) or 30
local unitUpdateIntervalMs = tonumber(cfg.unitUpdateIntervalMs) or 1000
local bridgeRefreshDebounceMs = tonumber(cfg.bridgeRefreshDebounceMs) or 250
local allowExternalLifecycleReadOnly = cfg.allowExternalLifecycleReadOnly ~= false

local activeCalls, callOrder, attachments = {}, {}, {}
local nextDispatchId = 1
local subscribers, panicCooldowns, trafficStopCooldowns, liveUnits, lastUnitUpdates = {}, {}, {}, {}, {}
local bridgeRefreshScheduled = false

local function trim(v) if v == nil then return '' end local text = tostring(v):match('^%s*(.-)%s*$') or '' if #text > 1024 then return text:sub(1, 1024) end return text end
local function clampPriority(v) local n = tonumber(v) or 3 if n < 1 then n = 1 elseif n > 5 then n = 5 end return math.floor(n) end
local function normalizeCoords(input)
    if type(input) ~= 'table' then return nil end
    local x = tonumber(input.x or input[1])
    local y = tonumber(input.y or input[2])
    local z = tonumber(input.z or input[3]) or 0.0
    if not x or not y or x ~= x or y ~= y or z ~= z then return nil end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 20000 then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end
local function trimBounded(value, maxLength)
    local text = trim(value)
    if #text > maxLength then return text:sub(1, maxLength) end
    return text
end
local function isTrustedServerEvent()
    local caller = tonumber(source)
    return caller == nil or caller <= 0
end
local function isAuthorizedOfficer(sourceId)
    local access = rawget(_G, 'CortexMdtAccess')
    return type(access) == 'table'
        and type(access.isOfficer) == 'function'
        and access.isOfficer(sourceId) == true
end
local function shallow(input)
    local out, count = {}, 0
    if type(input) ~= 'table' then return out end

    for k, v in pairs(input) do
        if count >= 32 then break end
        local key = trimBounded(k, 64)
        if key ~= '' and (type(v) == 'string' or type(v) == 'number' or type(v) == 'boolean') then
            out[key] = type(v) == 'string' and trimBounded(v, 256) or v
            count = count + 1
        end
    end

    return out
end
local function copyArray(input)
    local out = {}
    if type(input) ~= 'table' then return out end

    for i = 1, math.min(#input, 64) do
        local value = input[i]
        if type(value) == 'table' then
            out[#out + 1] = shallow(value)
        elseif type(value) == 'string' then
            out[#out + 1] = trimBounded(value, 256)
        elseif type(value) == 'number' or type(value) == 'boolean' then
            out[#out + 1] = value
        end
    end

    return out
end
local function statusKey(v) local s = string.upper(trimBounded(v, 32)); return s ~= '' and s or 'NEW' end
local function statusLabel(v) local s = statusKey(v); if s == 'ON_SCENE' then return 'On Scene' elseif s == 'CODE4' then return 'Code 4' elseif s == 'CANCELLED' then return 'Cancelled' elseif s == 'CLOSED' then return 'Closed' elseif s == 'ASSIGNED' then return 'Assigned' end return 'New' end
local function resolved(v) local s = statusKey(v); return s == 'CODE4' or s == 'CLOSED' or s == 'CANCELLED' end
local function severity(priority, status, icons) local p = clampPriority(priority); local s = statusKey(status); if s == 'CLOSED' or s == 'CANCELLED' then return 'Low' end if type(icons) == 'table' and icons.gun == true and p <= 2 then return 'Critical' end if p == 1 then return 'Critical' elseif p == 2 then return 'High' elseif p == 3 then return 'Medium' end return 'Low' end
local function detailValue(details, keys) if type(details) ~= 'table' then return '' end for i=1,#keys do local v = details[keys[i]] if trim(v) ~= '' then return trim(v) end end for k,v in pairs(details) do for i=1,#keys do if string.lower(trim(k)) == string.lower(trim(keys[i])) and trim(v) ~= '' then return trim(v) end end end return '' end
local function locationText(street, cross, area) street = trim(street); cross = trim(cross); area = trim(area); if street ~= '' and cross ~= '' then return ('%s / %s'):format(street, cross) elseif street ~= '' and area ~= '' then return ('%s, %s'):format(street, area) elseif street ~= '' then return street elseif area ~= '' then return area end return 'Unknown Location' end
local function started(name) local state = GetResourceState(trim(name)); return state == 'started' or state == 'starting' end
local function bridgeName() local name = trim(cfg.authoritativeBridge); if name == '' then return 'cortex-dispatch' end return string.lower(name) end
local function bridgeFlags() local bridges = type(cfg.bridges) == 'table' and cfg.bridges or {}; return { cortex = bridges['cortex-dispatch'] ~= false and started('cortex-dispatch'), ps = bridges['ps-dispatch'] ~= false and started('ps-dispatch') } end
local function bridgeEnabled() local flags = bridgeFlags(); return enabled and bridgeName() == 'cortex-dispatch' and flags.cortex end
local function psDispatchEnabled() local flags = bridgeFlags(); return enabled and bridgeName() == 'ps-dispatch' and flags.ps end
local function getRosterBridge() local bridge = rawget(_G, 'CortexMdtUnitsBridge'); return type(bridge) == 'table' and bridge or nil end
local function normalizeRosterStatus(value)
    local bridge = getRosterBridge()
    if bridge and type(bridge.normalizeUnitStatus) == 'function' then
        local ok, normalized = pcall(bridge.normalizeUnitStatus, value, 'off_duty')
        if ok and trim(normalized) ~= '' then
            return trim(normalized)
        end
    end

    local status = string.lower(trim(value)):gsub('%s+', '_')
    if status == 'enroute' then return 'en_route' end
    if status == 'scene' then return 'on_scene' end
    if status == 'offduty' then return 'off_duty' end
    return status ~= '' and status or 'off_duty'
end
local function rosterAvailability(status)
    local normalized = normalizeRosterStatus(status)
    if normalized == 'available' then return 'Available' end
    if normalized == 'busy' then return 'Busy' end
    if normalized == 'en_route' then return 'En Route' end
    if normalized == 'on_scene' then return 'On Scene' end
    if normalized == 'emergency' then return 'Emergency' end
    return 'Off Duty'
end
local function buildAuthoritativeUnits()
    local bridge = getRosterBridge()
    if not bridge or type(bridge.getDispatchUnits) ~= 'function' then
        return {}
    end

    local ok, rosterUnits = pcall(bridge.getDispatchUnits)
    if not ok or type(rosterUnits) ~= 'table' then
        return {}
    end

    local units = {}

    for i = 1, #rosterUnits do
        local rosterUnit = type(rosterUnits[i]) == 'table' and rosterUnits[i] or {}
        local status = normalizeRosterStatus(rosterUnit.status)
        if status ~= 'off_duty' then
            local source = tonumber(rosterUnit.source) or nil
            local live = source and liveUnits[source] or nil
            if not live then
                local rosterCallsign = trim(rosterUnit.callsign)
                if rosterCallsign ~= '' then
                    for liveSource, liveUnit in pairs(liveUnits) do
                        if trim(liveUnit.callsign) == rosterCallsign then
                            source = liveSource
                            live = liveUnit
                            break
                        end
                    end
                end
            end

            units[#units + 1] = {
                source = source,
                officerId = tonumber(rosterUnit.officer_id) or tonumber(rosterUnit.officerId) or nil,
                unitId = trim(rosterUnit.callsign) ~= '' and trim(rosterUnit.callsign) or tostring(rosterUnit.officer_id or source or ''),
                callsign = trim(rosterUnit.callsign) ~= '' and trim(rosterUnit.callsign) or tostring(source or rosterUnit.officer_id or ''),
                name = trim(rosterUnit.name) ~= '' and trim(rosterUnit.name) or trim(('%s %s'):format(rosterUnit.first_name or '', rosterUnit.last_name or '')),
                role = trim(rosterUnit.department) ~= '' and trim(rosterUnit.department) or trim(rosterUnit.dept) ~= '' and trim(rosterUnit.dept) or 'police',
                onDuty = true,
                status = status,
                vehicleState = 'foot',
                coords = live and normalizeCoords(live.coords) or nil,
                heading = live and tonumber(live.heading) or 0.0,
                locationStreet = live and trim(live.street) or '',
                mapArea = live and trim(live.mapArea) or '',
                attachedCalls = {},
                dutyStatus = 'On Duty',
                availability = rosterAvailability(status),
                department = trim(rosterUnit.department) ~= '' and trim(rosterUnit.department) or trim(rosterUnit.dept) ~= '' and trim(rosterUnit.dept) or 'police',
                assignment = trim(rosterUnit.assignment),
                rank = trim(rosterUnit.rank),
            }
        end
    end

    table.sort(units, function(a, b) return tostring(a.callsign or '') < tostring(b.callsign or '') end)
    return units
end
local function resolveAuthoritativeUnit(source)
    for _, unit in ipairs(buildAuthoritativeUnits()) do
        if tonumber(unit.source) == tonumber(source) then
            return unit
        end
    end

    return nil
end
local function createLocalCall(data)
    data = type(data) == 'table' and data or {}
    local id = tostring(nextDispatchId)
    nextDispatchId = nextDispatchId + 1
    local call = { id = id, bridgeCallId = nil, code = trim(data.code) ~= '' and trim(data.code) or '10-00', title = trim(data.title) ~= '' and trim(data.title) or 'Dispatch Call', location = trim(data.location) ~= '' and trim(data.location) or 'Unknown Location', priority = clampPriority(data.priority), severity = severity(data.priority, data.status, data.icons), unitCount = tonumber(data.unitCount) or 0, coords = normalizeCoords(data.coords), street = trim(data.street), postal = trim(data.postal), locationArea = trim(data.locationArea), locationCross = trim(data.locationCross), primaryCallsign = trim(data.primaryCallsign), vehiclePlate = trim(data.vehiclePlate), vehicleMake = trim(data.vehicleMake), vehicleModel = trim(data.vehicleModel), codeName = string.lower(statusKey(data.status)), status = statusKey(data.status), statusLabel = statusLabel(data.status), sourceSystem = trim(data.sourceSystem), externalId = trim(data.externalId), serviceType = trim(data.serviceType), externalLifecycle = data.externalLifecycle == true, details = shallow(data.details), notes = copyArray(data.notes), respondingUnits = copyArray(data.respondingUnits), respondingUnitDetails = copyArray(data.respondingUnitDetails), callerName = trim(data.callerName), anonymous = data.anonymous == true, closed = resolved(data.status), mutationsAllowed = data.mutationsAllowed ~= false, createdAt = data.createdAt or os.date('!%Y-%m-%dT%H:%M:%SZ'), callerSource = data.callerSource }
    activeCalls[id] = call; callOrder[#callOrder + 1] = id; attachments[id] = attachments[id] or {}
    while #callOrder > 50 do local old = table.remove(callOrder, 1); activeCalls[old] = nil; attachments[old] = nil end
    return call
end

local function fetchBridgeCalls() if not bridgeEnabled() then return {} end for _, name in ipairs({ 'GetDispatchCalls', 'GetCalls', 'GetAllCalls' }) do local ok, response = pcall(function() return exports['cortex-dispatch'][name]() end); if ok and type(response) == 'table' then return response end end return {} end
local function fetchBridgeUnits() if not bridgeEnabled() then return {} end local ok, response = pcall(function() return exports['cortex-dispatch']:GetUnits() end); if ok and type(response) == 'table' then return response end return {} end

local function mapUnit(unit)
    unit = type(unit) == 'table' and unit or {}
    local attachedCalls = copyArray(unit.attachedCalls)
    local rawStatus = trim(unit.status)
    local normalized = string.upper(rawStatus)
    local availability = 'available'
    if normalized == '10-7' or normalized == 'OFF_DUTY' then availability = 'off duty' elseif normalized == '10-76' or normalized == 'EN_ROUTE' then availability = 'en route' elseif normalized == '10-97' or normalized == 'ON_SCENE' then availability = 'on scene' elseif #attachedCalls > 0 then availability = 'en route' end
    return { unitId = trim(unit.unitId) ~= '' and trim(unit.unitId) or tostring(unit.source or ''), source = tonumber(unit.source) or nil, name = trim(unit.name) ~= '' and trim(unit.name) or 'Unknown', callsign = trim(unit.callsign) ~= '' and trim(unit.callsign) or tostring(unit.source or ''), role = trim(unit.role) ~= '' and trim(unit.role) or 'police', onDuty = unit.onDuty ~= false, status = rawStatus ~= '' and rawStatus or '10-8', vehicleState = trim(unit.vehicleState) ~= '' and trim(unit.vehicleState) or 'foot', coords = normalizeCoords(unit.coords) or { x = 0.0, y = 0.0, z = 0.0 }, heading = tonumber(unit.heading) or 0.0, attachedCalls = attachedCalls, dutyStatus = unit.onDuty == false and 'Off Duty' or 'On Duty', availability = availability, department = trim(unit.role) ~= '' and trim(unit.role) or 'police' }
end

local function mapCall(call, unitsById)
    if type(call) ~= 'table' or not tonumber(call.id) then return nil end
    local details = shallow(call.details)
    local location = type(call.location) == 'table' and call.location or {}
    local street, area, cross = trim(location.street), trim(location.area), trim(location.cross)
    local respondingUnits = copyArray(call.respondingUnits)
    local respondingUnitDetails, primaryCallsign = {}, detailValue(details, { 'Unit', 'Primary Unit', 'Callsign', 'PrimaryUnit' })
    for i = 1, #respondingUnits do local unit = unitsById[tostring(respondingUnits[i])]; if unit then respondingUnitDetails[#respondingUnitDetails + 1] = unit; if primaryCallsign == '' then primaryCallsign = trim(unit.callsign) end end end
    local status = statusKey(call.status)
    local icons = type(call.icons) == 'table' and call.icons or {}
    local icon = 'fa-location-dot'; if icons.gun == true then icon = 'fa-gun' elseif icons.medical == true then icon = 'fa-truck-medical' elseif icons.car == true then icon = 'fa-car-burst' end
    return { id = ('ctx-%s'):format(tonumber(call.id)), bridgeCallId = tonumber(call.id), code = trim(call.code) ~= '' and trim(call.code) or '10-00', title = trim(call.title) ~= '' and trim(call.title) or 'Dispatch Call', location = locationText(street, cross, area), priority = clampPriority(call.priority), severity = severity(call.priority, status, icons), unitCount = #respondingUnits, coords = normalizeCoords(location.coords) or normalizeCoords(call.coords), street = street, postal = detailValue(details, { 'Postal', 'postal', 'PostalCode', 'Postal Code' }), locationArea = area, locationCross = cross, primaryCallsign = primaryCallsign, vehiclePlate = detailValue(details, { 'Plate', 'Vehicle Plate' }), vehicleMake = detailValue(details, { 'Make', 'Vehicle Make' }), vehicleModel = detailValue(details, { 'Model', 'Vehicle Model', 'Vehicle' }), codeName = string.lower(status), status = status, statusLabel = statusLabel(status), sourceSystem = trim(call.sourceSystem), externalId = trim(call.externalId), serviceType = trim(call.serviceType), externalLifecycle = call.externalLifecycle == true, details = details, notes = copyArray(call.notes), respondingUnits = respondingUnits, respondingUnitDetails = respondingUnitDetails, callerName = detailValue(details, { 'Caller', 'caller', 'Patient' }), anonymous = detailValue(details, { 'Anonymous', 'anonymous' }) ~= '', closed = resolved(status), mutationsAllowed = call.externalLifecycle ~= true, createdAt = call.timestamp and os.date('!%Y-%m-%dT%H:%M:%SZ', tonumber(call.timestamp)) or os.date('!%Y-%m-%dT%H:%M:%SZ') }
end
local function snapshot()
    if bridgeEnabled() then
        local unitsById, units, calls = {}, buildAuthoritativeUnits(), {}
        for _, unit in ipairs(fetchBridgeUnits()) do local mapped = mapUnit(unit); unitsById[mapped.unitId] = mapped end
        for _, call in ipairs(fetchBridgeCalls()) do local mapped = mapCall(call, unitsById); if mapped then calls[#calls + 1] = mapped end end
        table.sort(calls, function(a, b) return tonumber(a.bridgeCallId or 0) > tonumber(b.bridgeCallId or 0) end)
        return { calls = calls, units = units }
    end
    local units, calls = buildAuthoritativeUnits(), {}
    for i = #callOrder, 1, -1 do local call = activeCalls[callOrder[i]]; if call then calls[#calls + 1] = call end end
    return { calls = calls, units = units }
end

local function push(event, data) for src in pairs(subscribers) do TriggerClientEvent('cortex_mdtsv:dispatchUpdate', src, event, data) end end
local function refresh(data) data = data or snapshot(); push('dispatch', data.calls); push('units', data.units) end
local function encode(data) return json.encode(data or {}) or '' end
local lastBridgeSignature = ''
local function queueBridgeRefresh(force) if not bridgeEnabled() then if force then refresh() end return end if bridgeRefreshScheduled then return end bridgeRefreshScheduled = true CreateThread(function() Wait(bridgeRefreshDebounceMs) bridgeRefreshScheduled = false refresh() end) end
local function resolveCallId(data) if type(data) == 'number' then return math.floor(data) end if type(data) == 'table' then if tonumber(data.bridgeCallId) then return math.floor(tonumber(data.bridgeCallId)) end if tonumber(data.callId) then return math.floor(tonumber(data.callId)) end data = data.dispatchId or data.id end local text = tostring(data or ''); local direct = tonumber(text); if direct then return math.floor(direct) end local suffix = text:match(':(%d+)$') or text:match('(%d+)$'); return suffix and math.floor(tonumber(suffix)) or nil end
local function bridgeCallById(id) for _, call in ipairs(fetchBridgeCalls()) do if tonumber(call.id) == id then return call end end return nil end
local function resolveUnit(source) local authoritative = resolveAuthoritativeUnit(source); if authoritative then return authoritative end local liveCallsign = liveUnits[source] and trim(liveUnits[source].callsign) or ''; for _, unit in ipairs(fetchBridgeUnits()) do if tonumber(unit.source) == source then return unit end end if liveCallsign ~= '' then for _, unit in ipairs(fetchBridgeUnits()) do if trim(unit.callsign) == liveCallsign then return unit end end end return nil end
local function bridgeCall(name, ...)
    local args = { ... }
    local ok, response = pcall(function()
        return exports['cortex-dispatch'][name](table.unpack(args))
    end)
    if ok then return response end
    return nil
end

local function auditDispatchAction(source, action, targetId, details)
    local audit = rawget(_G, 'CortexAudit')
    if type(audit) ~= 'table' or type(audit.write) ~= 'function' then
        return
    end

    local unit = resolveAuthoritativeUnit(source) or liveUnits[source] or {}
    local officerId = tonumber(unit.officerId or unit.officer_id) or 0
    audit.write(officerId, action, 'dispatch', 'dispatch_call', targetId, details, {
        source = source,
        officer = {
            first_name = trim(unit.name),
            callsign = trim(unit.callsign),
            department = trim(unit.department or unit.role),
            rank = trim(unit.rank),
        },
    })
end

local function ingestPsDispatchCall(callData)
    if type(callData) ~= 'table' then
        return
    end

    createLocalCall({
        code = trim(callData.code) ~= '' and trim(callData.code) or '10-00',
        title = trim(callData.message) ~= '' and trim(callData.message) or trim(callData.codeName) ~= '' and trim(callData.codeName) or 'Dispatch Call',
        location = trim(callData.street) ~= '' and trim(callData.street) or 'Unknown Location',
        priority = tonumber(callData.priority) or 2,
        coords = callData.coords,
        street = callData.street,
        postal = callData.postal,
        primaryCallsign = trim(callData.callsign),
        vehiclePlate = trim(callData.plate),
        vehicleMake = trim(callData.make),
        vehicleModel = trim(callData.vehicle),
        sourceSystem = 'ps-dispatch',
        status = 'NEW',
        externalLifecycle = allowExternalLifecycleReadOnly,
        mutationsAllowed = not allowExternalLifecycleReadOnly,
        details = {
            gender = trim(callData.gender),
            codeName = trim(callData.codeName),
            class = trim(callData.class),
            color = trim(callData.color),
        }
    })
    refresh()
end

local function notifyPsDispatch(callData)
    if not psDispatchEnabled() or type(callData) ~= 'table' then
        return false
    end

    local usedExport = false
    local ok = pcall(function()
        if started('ps-dispatch') and exports['ps-dispatch'] and exports['ps-dispatch'].CustomAlert then
            usedExport = true
            exports['ps-dispatch']:CustomAlert(callData)
            return
        end

        TriggerEvent('dispatch:server:notify', callData)
    end)

    if ok and usedExport then
        ingestPsDispatchCall(callData)
    end

    return ok
end

lib.callback.register('cortex_mdt:getDispatch', function() local data = snapshot(); local currentBridge = 'local'; if bridgeEnabled() then currentBridge = 'cortex-dispatch' elseif psDispatchEnabled() then currentBridge = 'ps-dispatch' end return { ok = true, calls = data.calls, units = data.units, bridge = currentBridge } end)
lib.callback.register('cortex_mdt:attachDispatchCall', function(source, data)
    local id = resolveCallId(data)
    if bridgeEnabled() then
        if not id then return { ok = false, error = 'Invalid dispatch call.' } end
        if not resolveUnit(source) then return { ok = false, error = 'You must be an active dispatch unit to attach.' } end
        if bridgeCall('AttachUnit', id, source) then
            refresh()
            auditDispatchAction(source, 'dispatch_attach', id, nil)
            return { ok = true, dispatchId = 'ctx-' .. tostring(id), bridgeCallId = id }
        end
        return { ok = false, error = 'Failed to attach unit to call.' }
    end

    id = tostring(type(data) == 'table' and data.dispatchId or '')
    if id == '' or not activeCalls[id] then return { ok = false, error = 'Dispatch call not found.' } end
    if not (resolveAuthoritativeUnit(source) or liveUnits[source]) then return { ok = false, error = 'You must be an active dispatch unit to attach.' } end
    if attachments[id][source] then return { ok = true, dispatchId = id, alreadyAttached = true } end
    attachments[id][source] = true
    activeCalls[id].unitCount = (activeCalls[id].unitCount or 0) + 1
    refresh()
    auditDispatchAction(source, 'dispatch_attach', id, nil)
    return { ok = true, dispatchId = id }
end)

lib.callback.register('cortex_mdt:detachDispatchCall', function(source, data)
    local id = resolveCallId(data)
    if bridgeEnabled() then
        if not id then return { ok = false, error = 'Invalid dispatch call.' } end
        if not resolveUnit(source) then return { ok = false, error = 'You must be an active dispatch unit to detach.' } end
        if bridgeCall('DetachUnit', id, source) then
            refresh()
            auditDispatchAction(source, 'dispatch_detach', id, nil)
            return { ok = true, dispatchId = 'ctx-' .. tostring(id), bridgeCallId = id }
        end
        return { ok = false, error = 'Failed to detach unit from call.' }
    end

    id = tostring(type(data) == 'table' and data.dispatchId or '')
    if id == '' or not attachments[id] or not attachments[id][source] then return { ok = false, error = 'You are not attached to this call.' } end
    attachments[id][source] = nil
    if activeCalls[id] and (activeCalls[id].unitCount or 0) > 0 then activeCalls[id].unitCount = activeCalls[id].unitCount - 1 end
    refresh()
    auditDispatchAction(source, 'dispatch_detach', id, nil)
    return { ok = true, dispatchId = id }
end)

lib.callback.register('cortex_mdt:setWaypoint', function(source, data)
    local coords = type(data) == 'table' and normalizeCoords(data.coords) or nil
    if not coords then return { ok = false, error = 'Invalid coordinates.' } end
    TriggerClientEvent('cortex_mdtsv:setWaypoint', source, coords.x, coords.y)
    auditDispatchAction(source, 'dispatch_waypoint_set', nil, { x = coords.x, y = coords.y, z = coords.z })
    return { ok = true }
end)
lib.callback.register('cortex_mdt:triggerPanic', function(source, data)
    local now = os.time(); if now - (panicCooldowns[source] or 0) < panicCooldownSeconds then return { ok = false, error = 'Panic is on cooldown.' } end; panicCooldowns[source] = now
    local payload = type(data) == 'table' and data or {}; local unit = resolveUnit(source) or liveUnits[source]; if not unit then return { ok = false, error = 'Must be on duty' } end; local ped = GetPlayerPed(source); local coords = (ped and ped > 0 and normalizeCoords(GetEntityCoords(ped)) or nil) or normalizeCoords(unit.coords); if not coords then return { ok = false, error = 'Unable to resolve officer coordinates.' } end
    if bridgeEnabled() then local created = bridgeCall('CreateCall', { code = '10-99', title = 'Officer Panic', priority = 1, sourceSystem = 'cortex_mdt', location = { street = trim(payload.street) ~= '' and trim(payload.street) or 'Unknown Street', area = trim(payload.postal), coords = coords }, icons = { gun = true, car = false, medical = false }, details = { ['Primary Unit'] = trim(unit.callsign) ~= '' and trim(unit.callsign) or tostring(source), Postal = trim(payload.postal), Caller = trim(unit.name) ~= '' and trim(unit.name) or (GetPlayerName(source) or 'Officer'), Plate = trim(payload.vehiclePlate), ['Vehicle Make'] = trim(payload.vehicleMake), ['Vehicle Model'] = trim(payload.vehicleModel) } }); local callId = created and tonumber(created.id) or resolveCallId(created); if not callId then return { ok = false, error = 'Failed to create panic call.' } end; bridgeCall('AttachUnit', callId, source); refresh(); TriggerClientEvent('cortex_mdtsv:dispatchUpdate', source, 'dispatch:selectCall', { dispatchId = 'ctx-' .. tostring(callId), bridgeCallId = callId }); auditDispatchAction(source, 'dispatch_panic', callId, { bridge = 'cortex-dispatch' }); return { ok = true, dispatchId = 'ctx-' .. tostring(callId), bridgeCallId = callId } end
    if psDispatchEnabled() then local psCfg = type(cfg.psDispatch) == 'table' and cfg.psDispatch or {}; notifyPsDispatch({ message = 'Officer Panic', codeName = trim(psCfg.panicCodeName) ~= '' and trim(psCfg.panicCodeName) or 'officerdown', code = trim(psCfg.panicCode) ~= '' and trim(psCfg.panicCode) or '10-99', icon = 'fas fa-triangle-exclamation', priority = 1, coords = coords, street = locationText(trim(payload.street), '', trim(payload.postal)), jobs = type(psCfg.jobs) == 'table' and psCfg.jobs or { 'leo' }, vehicle = trim(payload.vehicleModel), plate = trim(payload.vehiclePlate), color = trim(payload.vehicleColor), callsign = trim(unit.callsign), name = trim(unit.name) }) end
    local call = createLocalCall({ code = '10-99', title = 'Officer Panic', location = trim(payload.street) ~= '' and trim(payload.street) or 'Unknown Location', priority = 1, coords = coords, street = payload.street, postal = payload.postal, primaryCallsign = trim(unit.callsign) ~= '' and trim(unit.callsign) or tostring(source), vehiclePlate = payload.vehiclePlate, vehicleMake = payload.vehicleMake, vehicleModel = payload.vehicleModel, sourceSystem = 'local', callerSource = source, callerName = trim(unit.name) ~= '' and trim(unit.name) or (GetPlayerName(source) or 'Officer') }); attachments[call.id][source] = true; call.unitCount = 1; push('dispatch:panic', { dispatchId = call.id, source = source, callsign = call.primaryCallsign, coords = coords }); refresh(); TriggerClientEvent('cortex_mdtsv:dispatchUpdate', source, 'dispatch:selectCall', { dispatchId = call.id }); auditDispatchAction(source, 'dispatch_panic', call.id, { bridge = psDispatchEnabled() and 'ps-dispatch' or 'local' }); return { ok = true, dispatchId = call.id }
end)
lib.callback.register('cortex_mdt:createTrafficStopCall', function(source, data)
    local now = GetGameTimer()
    if now - (trafficStopCooldowns[source] or 0) < 5000 then return { ok = false, error = 'Traffic stop creation is on cooldown.' } end
    trafficStopCooldowns[source] = now
    local payload = type(data) == 'table' and data or {}; local unit = resolveUnit(source) or liveUnits[source]; if not unit then return { ok = false, error = 'Must be on duty' } end; local ped = GetPlayerPed(source); local coords = (ped and ped > 0 and normalizeCoords(GetEntityCoords(ped)) or nil) or normalizeCoords(unit.coords); if not coords then return { ok = false, error = 'Unable to resolve officer coordinates.' } end
    if bridgeEnabled() then local created = bridgeCall('CreateCall', { code = '10-11', title = 'Traffic Stop', priority = 3, sourceSystem = 'cortex_mdt', location = { street = trim(payload.street) ~= '' and trim(payload.street) or 'Unknown Street', area = trim(payload.postal), coords = coords }, icons = { gun = false, car = true, medical = false }, details = { ['Primary Unit'] = trim(unit.callsign) ~= '' and trim(unit.callsign) or tostring(source), Postal = trim(payload.postal), Plate = trim(payload.vehiclePlate), ['Vehicle Make'] = trim(payload.vehicleMake), ['Vehicle Model'] = trim(payload.vehicleModel), Caller = trim(unit.name) ~= '' and trim(unit.name) or (GetPlayerName(source) or 'Officer') } }); local callId = created and tonumber(created.id) or resolveCallId(created); if not callId then return { ok = false, error = 'Failed to create traffic stop.' } end; bridgeCall('AttachUnit', callId, source); refresh(); auditDispatchAction(source, 'dispatch_traffic_stop_create', callId, { bridge = 'cortex-dispatch', plate = trim(payload.vehiclePlate) }); return { ok = true, dispatchId = 'ctx-' .. tostring(callId), bridgeCallId = callId } end
    if psDispatchEnabled() then local psCfg = type(cfg.psDispatch) == 'table' and cfg.psDispatch or {}; notifyPsDispatch({ message = 'Traffic Stop', codeName = trim(psCfg.trafficStopCodeName) ~= '' and trim(psCfg.trafficStopCodeName) or 'trafficstop', code = trim(psCfg.trafficStopCode) ~= '' and trim(psCfg.trafficStopCode) or '10-11', icon = 'fas fa-car', priority = 2, coords = coords, street = locationText(trim(payload.street), '', trim(payload.postal)), jobs = type(psCfg.jobs) == 'table' and psCfg.jobs or { 'leo' }, vehicle = trim(payload.vehicleModel), plate = trim(payload.vehiclePlate), color = trim(payload.vehicleColor), callsign = trim(unit.callsign), name = trim(unit.name) }) end
    local call = createLocalCall({ code = '10-11', title = 'Traffic Stop', location = trim(payload.street) ~= '' and trim(payload.street) or 'Unknown Location', priority = 3, coords = coords, street = payload.street, postal = payload.postal, primaryCallsign = trim(unit.callsign) ~= '' and trim(unit.callsign) or tostring(source), vehiclePlate = payload.vehiclePlate, vehicleMake = payload.vehicleMake, vehicleModel = payload.vehicleModel, sourceSystem = 'local', callerSource = source, callerName = trim(unit.name) ~= '' and trim(unit.name) or (GetPlayerName(source) or 'Officer') }); attachments[call.id][source] = true; call.unitCount = 1; refresh(); auditDispatchAction(source, 'dispatch_traffic_stop_create', call.id, { bridge = psDispatchEnabled() and 'ps-dispatch' or 'local', plate = trim(payload.vehiclePlate) }); return { ok = true, dispatchId = call.id }
end)
lib.callback.register('cortex_mdt:updateDispatchCall', function(source, data) if not bridgeEnabled() then return { ok = false, error = 'Bridge not available.' } end local id = resolveCallId(data); local call = bridgeCallById(id); if not call then return { ok = false, error = 'Dispatch call not found.' } end; if call.externalLifecycle == true then return { ok = false, error = 'This call is managed externally and is read-only.' } end; local patch = {}; if type(data) == 'table' then if trim(data.title) ~= '' then patch.title = trimBounded(data.title, 160) end; if data.priority ~= nil then patch.priority = clampPriority(data.priority) end; if type(data.details) == 'table' then patch.details = shallow(data.details) end; if trim(data.status) ~= '' then patch.status = statusKey(data.status) end end; if next(patch) == nil then return { ok = false, error = 'Nothing to update.' } end; if bridgeCall('UpdateCall', id, patch) then refresh(); auditDispatchAction(source, 'dispatch_update', id, patch); return { ok = true, dispatchId = 'ctx-' .. tostring(id), bridgeCallId = id } end return { ok = false, error = 'Failed to update dispatch call.' } end)
lib.callback.register('cortex_mdt:closeDispatchCall', function(source, data) if not bridgeEnabled() then return { ok = false, error = 'Bridge not available.' } end local id = resolveCallId(data); local call = bridgeCallById(id); if not call then return { ok = false, error = 'Dispatch call not found.' } end; if call.externalLifecycle == true then return { ok = false, error = 'This call is managed externally and is read-only.' } end; local reason = trimBounded(type(data) == 'table' and data.reason or '', 256); if reason == '' then reason = 'Closed from MDT' end; if bridgeCall('CloseCall', id, reason) then refresh(); auditDispatchAction(source, 'dispatch_close', id, { reason = reason }); return { ok = true, dispatchId = 'ctx-' .. tostring(id), bridgeCallId = id } end return { ok = false, error = 'Failed to close dispatch call.' } end)
lib.callback.register('cortex_mdt:addDispatchNote', function(source, data) if not bridgeEnabled() then return { ok = false, error = 'Bridge not available.' } end local id = resolveCallId(data); local text = trimBounded(type(data) == 'table' and data.text or '', 1000); local call = bridgeCallById(id); if not call then return { ok = false, error = 'Dispatch call not found.' } end; if call.externalLifecycle == true then return { ok = false, error = 'This call is managed externally and is read-only.' } end; if text == '' then return { ok = false, error = 'Invalid note payload.' } end; if bridgeCall('AddNote', id, text) then refresh(); auditDispatchAction(source, 'dispatch_note_add', id, nil); return { ok = true, dispatchId = 'ctx-' .. tostring(id), bridgeCallId = id } end return { ok = false, error = 'Failed to add dispatch note.' } end)
lib.callback.register('cortex_mdt:markDispatchCode4', function(source, data) if not bridgeEnabled() then return { ok = false, error = 'Bridge not available.' } end local id = resolveCallId(data); local call = bridgeCallById(id); if not call then return { ok = false, error = 'Dispatch call not found.' } end; if call.externalLifecycle == true then return { ok = false, error = 'This call is managed externally and is read-only.' } end; if bridgeCall('MarkCode4', id) then refresh(); auditDispatchAction(source, 'dispatch_code4', id, nil); return { ok = true, dispatchId = 'ctx-' .. tostring(id), bridgeCallId = id } end return { ok = false, error = 'Failed to mark call Code 4.' } end)
lib.callback.register('cortex_mdt:subscribeDispatch', function(source) subscribers[source] = true; refresh(); return { ok = true } end)
lib.callback.register('cortex_mdt:unsubscribeDispatch', function(source) subscribers[source] = nil; return { ok = true } end)
RegisterNetEvent('cortex_mdtsv:updateUnitCoords', function(coords, callsign, name, department, street, mapArea)
    local sourceId = source
    if not isAuthorizedOfficer(sourceId) then
        liveUnits[sourceId] = nil
        return
    end

    local now = GetGameTimer()
    local lastUpdate = lastUnitUpdates[sourceId]
    if lastUpdate and now >= lastUpdate and now - lastUpdate < math.max(500, math.floor(unitUpdateIntervalMs / 2)) then
        return
    end
    lastUnitUpdates[sourceId] = now

    local rosterBridge = getRosterBridge()
    if rosterBridge and type(rosterBridge.isSourceOnDuty) == 'function' then
        local ok, onDuty = pcall(rosterBridge.isSourceOnDuty, source)
        if not ok or onDuty ~= true then
            liveUnits[source] = nil
            return
        end
    end

    local ped = GetPlayerPed(sourceId)
    local normalized = ped and ped > 0 and normalizeCoords(GetEntityCoords(ped)) or nil
    if not normalized then return end

    local authoritative = resolveAuthoritativeUnit(sourceId) or {}

    liveUnits[sourceId] = {
        source = sourceId,
        coords = normalized,
        heading = GetEntityHeading(ped) or 0.0,
        callsign = trim(authoritative.callsign) ~= '' and trim(authoritative.callsign) or tostring(sourceId),
        name = trim(authoritative.name) ~= '' and trim(authoritative.name) or (GetPlayerName(sourceId) or 'Unknown'),
        department = trim(authoritative.department or authoritative.role) ~= '' and trim(authoritative.department or authoritative.role) or 'police',
        street = trimBounded(street, 96),
        mapArea = trimBounded(mapArea, 96),
        updatedAt = os.time(),
    }
end)

--- Merge live GPS telemetry into roster unit rows (see server/data.lua getUnits).
function CortexMdtMergeLiveUnitTelemetry(unit)
    if type(unit) ~= 'table' then
        return
    end
    local src = tonumber(unit.source)
    if not src then
        return
    end
    local live = liveUnits[src]
    if not live then
        return
    end
    unit.locationStreet = trim(live.street)
    unit.mapArea = trim(live.mapArea)
end
AddEventHandler('playerDropped', function() liveUnits[source] = nil; subscribers[source] = nil; panicCooldowns[source] = nil; trafficStopCooldowns[source] = nil; lastUnitUpdates[source] = nil end)
CreateThread(function() if not enabled then return end while true do Wait(unitUpdateIntervalMs) if next(subscribers) then if bridgeEnabled() then local data = snapshot(); local signature = encode(data); if signature ~= lastBridgeSignature then lastBridgeSignature = signature; refresh(data) end else push('units', snapshot().units) end end end end)
RegisterNetEvent('cortex_mdt:server:addDispatchCall', function() if not isTrustedServerEvent() then return end if bridgeEnabled() then refresh() end end)
RegisterNetEvent('cortex-dispatch:server:callCreated', function(call) if not isTrustedServerEvent() then return end if bridgeEnabled() then refresh() return end if type(call) ~= 'table' then return end createLocalCall({ code = trim(call.code), title = trim(call.title), location = locationText(call.location and call.location.street, call.location and call.location.cross, call.location and call.location.area), priority = clampPriority(call.priority), coords = call.location and call.location.coords or call.coords, street = call.location and call.location.street, postal = detailValue(call.details, { 'Postal', 'postal' }), sourceSystem = trim(call.sourceSystem), status = call.status }) refresh() end)
RegisterNetEvent('cortex-dispatch:server:callUpdated', function() if not isTrustedServerEvent() then return end if bridgeEnabled() then refresh() end end)
RegisterNetEvent('cortex-dispatch:server:ersCallCreated', function() if not isTrustedServerEvent() then return end if bridgeEnabled() then refresh() end end)
RegisterNetEvent('night_ers:server:calloutCreated', function(calloutData) if not isTrustedServerEvent() then return end if bridgeEnabled() then refresh() return end if type(calloutData) ~= 'table' then return end createLocalCall({ code = trim(calloutData.Code) ~= '' and trim(calloutData.Code) or '10-00', title = trim(calloutData.CalloutName or calloutData.CalloutType or calloutData.title), location = locationText(calloutData.StreetName or calloutData.street, nil, calloutData.Postal or calloutData.PostalCode or calloutData.postal), priority = tonumber(calloutData.Priority) or 2, coords = calloutData.Coordinates or calloutData.coords, street = calloutData.StreetName or calloutData.street, postal = calloutData.Postal or calloutData.PostalCode or calloutData.postal, sourceSystem = 'ers', status = 'NEW', externalLifecycle = allowExternalLifecycleReadOnly, mutationsAllowed = not allowExternalLifecycleReadOnly }) refresh() end)
RegisterNetEvent('ps-dispatch:server:notify', function(callData) if not isTrustedServerEvent() or not psDispatchEnabled() then return end ingestPsDispatchCall(callData) end)
RegisterNetEvent('dispatch:server:notify', function(callData) if not isTrustedServerEvent() or not psDispatchEnabled() then return end ingestPsDispatchCall(callData) end)
RegisterNetEvent('EmergencyResponseSimulator:server:calloutCreated', function(calloutData) if not isTrustedServerEvent() then return end TriggerEvent('night_ers:server:calloutCreated', calloutData) end)
if enabled then print('[^2cortex_mdt^0] Dispatch module loaded') end
