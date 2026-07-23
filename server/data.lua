local ActiveOfficers = {}
local resourceName = GetCurrentResourceName()
local getOfficerId
local getOfficerUnitRow

local function getStandaloneCivilianModule()
    local module = rawget(_G, 'CortexStandaloneCivilian')
    if type(module) == 'table' then
        return module
    end

    return nil
end

local function getDutyBridge()
    local bridge = rawget(_G, 'CortexDutyBridge')
    if type(bridge) == 'table' then
        return bridge
    end

    return nil
end

local function getBridgeOfficerProfile(source, skipLocalPreferences)
    local bridge = getDutyBridge()
    if type(bridge) == 'table' and type(bridge.buildOfficerProfile) == 'function' then
        local ok, profile = pcall(bridge.buildOfficerProfile, source, skipLocalPreferences == true)
        if ok and type(profile) == 'table' then
            return profile
        end
    end

    return nil
end

local VALID_UNIT_STATUSES = {
    available = true,
    busy = true,
    en_route = true,
    on_scene = true,
    emergency = true,
    off_duty = true,
}

local UNIT_STATUS_ALIASES = {
    enroute = 'en_route',
    scene = 'on_scene',
    onscene = 'on_scene',
    offduty = 'off_duty',
}

local function normalizeUnitStatus(status, fallback)
    local normalized = tostring(status or ''):lower():gsub('%s+', '_')

    if normalized == '' then
        return fallback or 'off_duty'
    end

    normalized = UNIT_STATUS_ALIASES[normalized] or normalized

    if VALID_UNIT_STATUSES[normalized] then
        return normalized
    end

    return fallback or 'off_duty'
end

local function isOnDutyStatus(status)
    return normalizeUnitStatus(status) ~= 'off_duty'
end

local function trimText(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local CITIZEN_TAG_COLORS = {
    red = true,
    orange = true,
    yellow = true,
    green = true,
    cyan = true,
    blue = true,
    purple = true,
    white = true,
}

local function normalizeCitizenTagColor(value)
    local key = trimText(value):lower()
    if key == '' or not CITIZEN_TAG_COLORS[key] then
        return 'blue'
    end
    return key
end

local function normalizeUnitRow(row)
    if type(row) ~= 'table' then
        return row
    end

    row.status = normalizeUnitStatus(row.status)
    row.assignment = row.assignment or ''
    row.callsign = row.callsign or row.officer_callsign or ''
    row.department = row.department or row.officer_department or row.dept or Config.DefaultDepartment or 'police'
    row.name = trimText(('%s %s'):format(row.first_name or '', row.last_name or ''))

    return row
end

local function findOfficerSource(officerId)
    for source, activeOfficerId in pairs(ActiveOfficers) do
        if tonumber(activeOfficerId) == tonumber(officerId) then
            return source
        end
    end

    return nil
end

local function getDispatchUnitsSnapshot()
    local units = MySQL.query.await([[
        SELECT
            u.*,
            o.first_name,
            o.last_name,
            o.`rank`,
            o.department as dept
        FROM mdt_units u
        LEFT JOIN mdt_officers o ON u.officer_id = o.id
        WHERE u.status != "off_duty"
        ORDER BY u.department ASC, u.callsign ASC
    ]]) or {}

    for i = 1, #units do
        local unit = normalizeUnitRow(units[i])
        unit.source = findOfficerSource(unit.officer_id)
    end

    return units
end

local function isSourceMarkedOnDuty(source)
    local officerId = ActiveOfficers[source]
    if officerId then
        return true, officerId
    end

    officerId = getOfficerId(source)
    if not officerId then
        return false, nil
    end

    local unitRow = getOfficerUnitRow(officerId)
    if unitRow and isOnDutyStatus(unitRow.status) then
        ActiveOfficers[source] = officerId
        return true, officerId
    end

    return false, officerId
end

local function ensureUnitStatusSchema()
    local okColumns, columns = pcall(function()
        return MySQL.query.await("SHOW COLUMNS FROM mdt_units LIKE 'status'")
    end)
    columns = okColumns and columns or {}

    if not columns[1] then
        return
    end

    local ok, err = pcall(function()
        MySQL.query.await("ALTER TABLE mdt_units MODIFY COLUMN status ENUM('available','busy','enroute','scene','en_route','on_scene','emergency','off_duty') DEFAULT 'available'")
    end)

    if not ok then
        print(('[cortex_mdt] WARNING: unable to update mdt_units.status enum: %s'):format(tostring(err)))
    end
end

CreateThread(function()
    ensureUnitStatusSchema()
end)

local function appendUniqueRows(target, rows, identityFn, limit)
    local seen = {}

    for i = 1, #target do
        local row = target[i]
        local identity = identityFn(row)
        if identity ~= nil then
            seen[tostring(identity)] = true
        end
    end

    for i = 1, #rows do
        local row = rows[i]
        local identity = identityFn(row)
        local key = identity ~= nil and tostring(identity) or nil

        if key == nil or not seen[key] then
            if key ~= nil then
                seen[key] = true
            end
            target[#target + 1] = row
            if limit and #target >= limit then
                break
            end
        end
    end

    return target
end

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

local CortexMdtPageContracts = loadResourceModule('server/pages/index.lua')
local LocalMode = loadResourceModule('server/localMode.lua')
local LocalStorage = loadResourceModule('server/localStorage.lua')
local SessionStore = loadResourceModule('server/storage/sessionStore.lua')
local Audit = loadResourceModule('server/audit.lua')
local ChargeCatalog = loadResourceModule('server/charges.lua')
local Citations = loadResourceModule('server/citations.lua')
local DEFAULT_CHARGES = type(ChargeCatalog) == 'table' and ChargeCatalog.defaults or {}
local CHARGE_STORAGE_KEY = 'cortex_mdt:charges'
local lastKnownCitizenSources = {}

local function defaultMugshotUrl()
    return trimText(Config and Config.DefaultMugshot or '')
end

local function usesLocalMode()
    return type(CortexDatabase) == 'table' and CortexDatabase.mode ~= 'qbx'
end

local function normalizeBoolean(value, fallback)
    if value == nil then
        return fallback == true
    end

    if value == true or value == 1 or value == '1' then
        return true
    end

    if type(value) == 'string' then
        local lowered = trimText(value):lower()
        if lowered == 'true' or lowered == 'yes' then
            return true
        end
    end

    return false
end

local function normalizeChargeRecord(charge, fallback)
    fallback = type(fallback) == 'table' and fallback or {}
    charge = type(charge) == 'table' and charge or {}

    local jailTime = tonumber(charge.jailTime ~= nil and charge.jailTime or fallback.jailTime or 0) or 0
    local maxJail = tonumber(charge.maxJail ~= nil and charge.maxJail or fallback.maxJail or jailTime) or jailTime
    if maxJail < jailTime then
        maxJail = jailTime
    end

    return {
        id = tonumber(charge.id or fallback.id or 0) or 0,
        charge = trimText(charge.charge or fallback.charge),
        category = trimText(charge.category or fallback.category or 'other'),
        severity = trimText(charge.severity or fallback.severity or 'infraction'),
        fine = tonumber(charge.fine ~= nil and charge.fine or fallback.fine or 0) or 0,
        jailTime = jailTime,
        maxJail = maxJail,
        points = tonumber(charge.points ~= nil and charge.points or fallback.points or 0) or 0,
        stackable = normalizeBoolean(charge.stackable, fallback.stackable),
        requiresEvidence = normalizeBoolean(charge.requiresEvidence, fallback.requiresEvidence),
    }
end

local function getStoredChargeOverrides()
    local stored = LocalStorage.get(CHARGE_STORAGE_KEY)
    if type(stored) ~= 'table' then
        return {}
    end

    return stored
end

local function buildChargeList()
    local overrides = getStoredChargeOverrides()
    local charges = {}

    for i = 1, #DEFAULT_CHARGES do
        local base = DEFAULT_CHARGES[i]
        local override = overrides[tostring(base.id)] or overrides[base.id]
        charges[#charges + 1] = normalizeChargeRecord(override, base)
    end

    return charges
end

local function updateStoredCharge(data)
    local chargeId = tonumber(type(data) == 'table' and (data.chargeId or data.id) or nil)
    if not chargeId then
        return nil, 'Missing charge id.'
    end

    local baseCharge
    for i = 1, #DEFAULT_CHARGES do
        if tonumber(DEFAULT_CHARGES[i].id) == chargeId then
            baseCharge = DEFAULT_CHARGES[i]
            break
        end
    end

    if not baseCharge then
        return nil, 'Charge not found.'
    end

    local normalized = normalizeChargeRecord({
        id = chargeId,
        fine = data.fine,
        jailTime = data.jailTime,
        maxJail = data.maxJail,
    }, baseCharge)

    local overrides = getStoredChargeOverrides()
    overrides[tostring(chargeId)] = {
        id = chargeId,
        fine = normalized.fine,
        jailTime = normalized.jailTime,
        maxJail = normalized.maxJail,
    }

    LocalStorage.set(CHARGE_STORAGE_KEY, overrides)
    return normalized
end

local function getScopedLocalStorageKey(source, key)
    return LocalMode.getScopedStorageKey(source, key)
end

getOfficerId = function(src)
    if usesLocalMode() then
        return LocalMode.getOfficerId(src)
    end

    local identifier = GetPlayerIdentifierByType(src, 'license') or GetPlayerIdentifierByType(src, 'steam') or tostring(src)
    local result = MySQL.query.await('SELECT id FROM mdt_officers WHERE identifier = ?', { identifier })
    if result and result[1] then
        return result[1].id
    end
    return nil
end

getOfficerUnitRow = function(officerId)
    if usesLocalMode() then
        return LocalMode.getOfficerUnitRow(officerId)
    end

    local result = MySQL.query.await('SELECT u.*, o.callsign as officer_callsign, o.department as officer_department FROM mdt_units u LEFT JOIN mdt_officers o ON o.id = u.officer_id WHERE u.officer_id = ? LIMIT 1', { officerId })
    if result and result[1] then
        return normalizeUnitRow(result[1])
    end

    return nil
end

local function getOfficerDutyProfile(officerId)
    if usesLocalMode() then
        return LocalMode.getOfficerDutyProfile(officerId)
    end

    local result = MySQL.query.await('SELECT callsign, department FROM mdt_officers WHERE id = ? LIMIT 1', { officerId })
    if result and result[1] then
        return result[1]
    end

    return nil
end

local function getOfficerRecord(officerId)
    if not officerId then
        return nil
    end

    if usesLocalMode() then
        return LocalMode.getOfficer(officerId)
    end

    local result = MySQL.query.await('SELECT id, first_name, last_name, callsign, `rank`, department FROM mdt_officers WHERE id = ? LIMIT 1', { officerId })
    if result and result[1] then
        return result[1]
    end

    return nil
end

local function upsertOfficerUnitState(officerId, status, assignment)
    if usesLocalMode() then
        return LocalMode.upsertOfficerUnitState(officerId, status, assignment)
    end

    local officer = getOfficerDutyProfile(officerId)
    if not officer then
        return nil, 'Officer record not found.'
    end

    local nextStatus = normalizeUnitStatus(status, 'available')
    local callsign = officer.callsign or ''
    local department = officer.department or 'police'
    local nextAssignment = assignment

    if nextAssignment ~= nil and tostring(nextAssignment) == '' then
        nextAssignment = nil
    end

    MySQL.query.await('INSERT INTO mdt_units (callsign, officer_id, department, status, assignment) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE callsign = VALUES(callsign), department = VALUES(department), status = VALUES(status), assignment = VALUES(assignment)', {
        callsign,
        officerId,
        department,
        nextStatus,
        nextAssignment,
    })

    return normalizeUnitRow({
        callsign = callsign,
        department = department,
        status = nextStatus,
        assignment = nextAssignment or '',
    })
end

local function buildDutyResponse(unitState, ersPayload)
    unitState = normalizeUnitRow(unitState or {})

    return {
        ok = true,
        status = unitState.status,
        assignment = unitState.assignment or '',
        callsign = unitState.callsign or '',
        department = unitState.department or 'police',
        ers = ersPayload and {
            synced = ersPayload.synced == true,
            serviceType = ersPayload.serviceType or '',
        } or nil,
    }
end

local function syncDutyWithErs(source, shouldBeOnDuty)
    local bridge = getDutyBridge()
    if type(bridge) ~= 'table' or type(bridge.syncErsPoliceDuty) ~= 'function' then
        return {
            ok = true,
            synced = false,
            serviceType = '',
        }
    end

    return bridge.syncErsPoliceDuty(source, shouldBeOnDuty)
end

local function setOfficerUnitState(source, officerId, nextStatus, assignment, options)
    options = type(options) == 'table' and options or {}
    nextStatus = normalizeUnitStatus(nextStatus, 'available')

    if nextStatus == 'off_duty' then
        assignment = nil
    end

    local unitState, err = upsertOfficerUnitState(officerId, nextStatus, assignment)
    if not unitState then
        return {
            ok = false,
            error = err or 'Unable to save duty state.',
        }
    end

    if nextStatus == 'off_duty' then
        ActiveOfficers[source] = nil
    else
        ActiveOfficers[source] = officerId
    end

    return buildDutyResponse(unitState, options.ers)
end

local function goOfficerOnDuty(source, officerId, options)
    options = type(options) == 'table' and options or {}

    local ersResult = syncDutyWithErs(source, true)
    if not ersResult or ersResult.ok ~= true then
        return ersResult or {
            ok = false,
            error = 'Unable to confirm police shift in ERS.',
        }
    end

    local response = setOfficerUnitState(source, officerId, normalizeUnitStatus(options.status, 'available'), options.assignment, {
        ers = ersResult,
    })

    if response.ok ~= true and ersResult.synced == true then
        local rollback = syncDutyWithErs(source, false)
        if rollback and rollback.ok ~= true then
            print(('[cortex_mdt] ERROR: duty rollback failed for source %s after SQL failure: %s'):format(source, tostring(rollback.error)))
        end
    end

    return response
end

local function goOfficerOffDuty(source, officerId)
    local ersResult = syncDutyWithErs(source, false)
    if not ersResult or ersResult.ok ~= true then
        return ersResult or {
            ok = false,
            error = 'Unable to clear police shift in ERS.',
        }
    end

    return setOfficerUnitState(source, officerId, 'off_duty', nil, {
        ers = ersResult,
    })
end

local function ensureOfficer(src, data)
    if usesLocalMode() then
        return LocalMode.ensureOfficer(src, data)
    end

    local identifier = GetPlayerIdentifierByType(src, 'license') or GetPlayerIdentifierByType(src, 'steam') or tostring(src)
    local existing = MySQL.query.await('SELECT id FROM mdt_officers WHERE identifier = ?', { identifier })
    if existing and existing[1] then
        MySQL.update.await('UPDATE mdt_officers SET first_name = ?, last_name = ?, callsign = ?, `rank` = ?, department = ? WHERE id = ?', {
            data.firstName or '', data.lastName or '', data.callsign or '', data.rank or 'Officer', data.departmentKey or 'police', existing[1].id
        })
        MySQL.update.await('UPDATE mdt_units SET callsign = ?, department = ? WHERE officer_id = ?', {
            data.callsign or '',
            data.departmentKey or 'police',
            existing[1].id,
        })
        return existing[1].id
    end
    local id = MySQL.insert.await('INSERT INTO mdt_officers (identifier, first_name, last_name, callsign, `rank`, department) VALUES (?, ?, ?, ?, ?, ?)', {
        identifier, data.firstName or '', data.lastName or '', data.callsign or '', data.rank or 'Officer', data.departmentKey or 'police'
    })
    return id
end

local function ensureOfficerRecordForSource(source, overrides)
    overrides = type(overrides) == 'table' and overrides or {}
    local officerId = getOfficerId(source)
    local existingOfficer = getOfficerRecord(officerId)

    local hasOverrides = trimText(overrides.firstName) ~= ''
        or trimText(overrides.lastName) ~= ''
        or trimText(overrides.callsign) ~= ''
        or trimText(overrides.rank) ~= ''
        or trimText(overrides.departmentKey or overrides.department) ~= ''
        or overrides.useFrameworkDisplayName == true

    if officerId and not hasOverrides then
        return officerId
    end

    local profile = getBridgeOfficerProfile(source)
    profile = type(profile) == 'table' and profile or {}

    local firstName
    local lastName

    if overrides.useFrameworkDisplayName then
        local fwProfile = getBridgeOfficerProfile(source, true) or profile
        firstName = trimText(fwProfile.firstName or fwProfile.first_name or '')
        lastName = trimText(fwProfile.lastName or fwProfile.last_name or '')
    else
        firstName = trimText(overrides.firstName)
        if firstName == '' and existingOfficer then
            firstName = existingOfficer.first_name or existingOfficer.firstName or ''
        end
        if firstName == '' then
            firstName = profile.firstName or profile.first_name or ''
        end

        lastName = trimText(overrides.lastName)
        if lastName == '' and existingOfficer then
            lastName = existingOfficer.last_name or existingOfficer.lastName or ''
        end
        if lastName == '' then
            lastName = profile.lastName or profile.last_name or ''
        end
    end

    local callsign = trimText(overrides.callsign)
    if callsign == '' and existingOfficer then
        callsign = existingOfficer.callsign or ''
    end
    if callsign == '' then
        callsign = profile.callsign or ''
    end

    local rank = trimText(overrides.rank)
    if rank == '' and existingOfficer then
        rank = existingOfficer.rank or ''
    end
    if rank == '' then
        rank = profile.rank or 'Officer'
    end

    local departmentKey = trimText(overrides.departmentKey or overrides.department)
    if departmentKey == '' and existingOfficer then
        departmentKey = existingOfficer.department or ''
    end
    if departmentKey == '' then
        departmentKey = profile.departmentKey or profile.department_key or Config.DefaultDepartment or 'police'
    end

    if firstName == '' and lastName == '' and callsign == '' then
        return officerId
    end

    return ensureOfficer(source, {
        firstName = firstName,
        lastName = lastName,
        callsign = callsign,
        rank = rank,
        departmentKey = departmentKey,
    })
end

local function auditLog(officerId, action, category, targetType, targetId, details)
    if usesLocalMode() then
        LocalMode.auditLog(officerId, action, category, targetType, targetId, details)
        return
    end

    Audit.write(officerId, action, category, targetType, targetId, details, {
        officer = getOfficerRecord(officerId),
    })
end

local function generateNumber(prefix)
    local ts = os.time()
    local rand = math.random(1000, 9999)
    return ('%s-%s-%d'):format(prefix, os.date('%Y%m%d', ts), rand)
end

local function getSetting(key)
    if usesLocalMode() then
        return LocalMode.getSetting(key)
    end

    local result = MySQL.query.await('SELECT `value` FROM mdt_settings WHERE `key` = ?', { key })
    if result and result[1] then return result[1].value end
    return nil
end

local function rememberCitizenSource(citizenId, source)
    local id = trimText(citizenId)
    local src = tonumber(source)

    if id == '' or not src or src < 1 then
        return
    end

    lastKnownCitizenSources[id] = src
end

local function forgetCitizenSourceByPlayer(source)
    local src = tonumber(source)
    if not src then
        return
    end

    for citizenId, mappedSource in pairs(lastKnownCitizenSources) do
        if tonumber(mappedSource) == src then
            lastKnownCitizenSources[citizenId] = nil
        end
    end
end

local function getCitationRecipientSource(citizenId)
    local id = trimText(citizenId)
    if id == '' then
        return nil
    end

    local standalone = getStandaloneCivilianModule()
    if standalone and type(standalone.getOwnerSource) == 'function' then
        local ownerSource = standalone.getOwnerSource(id)
        if tonumber(ownerSource) and tonumber(ownerSource) > 0 then
            return tonumber(ownerSource)
        end
    end

    local cachedSource = tonumber(lastKnownCitizenSources[id])
    if cachedSource and cachedSource > 0 then
        return cachedSource
    end

    local qbxResource = GetResourceState('qbx_core') == 'started' and 'qbx_core' or nil
    if qbxResource then
        for _, playerSource in ipairs(GetPlayers()) do
            local src = tonumber(playerSource)
            if src then
                local ok, player = pcall(function()
                    return exports[qbxResource]:GetPlayer(src)
                end)
                local playerData = ok and player and player.PlayerData or nil
                local charinfo = type(playerData) == 'table' and type(playerData.charinfo) == 'table' and playerData.charinfo or nil
                local qbxCitizenId = charinfo and trimText(charinfo.citizenid or charinfo.citizenId) or ''

                if qbxCitizenId ~= '' and qbxCitizenId == id then
                    rememberCitizenSource(id, src)
                    return src
                end
            end
        end
    end

    return nil
end

local function deliverCitationToPlayer(targetSource, citation)
    local src = tonumber(targetSource)
    if not src or src < 1 or type(citation) ~= 'table' then
        return false
    end

    TriggerClientEvent('cortex_mdt:client:receiveCitation', src, citation)
    TriggerClientEvent('chat:addMessage', src, {
        color = { 0, 255, 204 },
        multiline = false,
        args = {
            'Cortex MDT',
            ('You received citation %s for $%s. Use /%s to view it.'):format(
                citation.citation_number or ('CIT-' .. tostring(citation.id or 'UNKNOWN')),
                tostring(citation.total_fine or 0),
                (Config.Citations and Config.Citations.showCommand) or 'showcitation'
            ),
        },
    })

    return true
end

local function issueCitationInSql(source, data)
    local reportId = tonumber(data and data.reportId)
    local citizenId = trimText(data and data.citizenId)
    local playerName = trimText(data and data.playerName)

    if not reportId or citizenId == '' then
        return { ok = false, error = 'Missing report ID or citizen ID.' }
    end

    local reportPayload = MySQL.query.await('SELECT id, report_number, title FROM mdt_reports WHERE id = ? LIMIT 1', { reportId }) or {}
    if not reportPayload[1] then
        return { ok = false, error = 'Report not found.' }
    end

    local report = reportPayload[1]
    local charges = MySQL.query.await('SELECT charge, severity, count, fine, notes FROM mdt_report_charges WHERE report_id = ? ORDER BY id ASC', { reportId }) or {}
    if #charges == 0 then
        return { ok = false, error = 'Report has no charges attached. Add charges first.' }
    end

    local recipientName = playerName
    if recipientName == '' then
        local participantRows = MySQL.query.await('SELECT name FROM mdt_report_participants WHERE report_id = ? AND participant_type = ? AND citizen_id = ? LIMIT 1', {
            reportId,
            'suspect',
            citizenId,
        }) or {}
        recipientName = trimText(participantRows[1] and participantRows[1].name or '')
    end
    if recipientName == '' then
        recipientName = fetchCitizenDisplayName(citizenId) or citizenId
    end

    local officerId = getOfficerId(source) or 0
    local officer = getOfficerRecord(officerId) or {}
    local deptKey = trimText(officer.department)
    local dept = (type(Config.Departments) == 'table' and Config.Departments[deptKey]) or Config.Departments[Config.DefaultDepartment or 'police'] or { label = 'Los Santos Police Department', short = 'LSPD' }

    local totalFine = 0
    for i = 1, #charges do
        totalFine = totalFine + ((tonumber(charges[i].fine or 0) or 0) * (tonumber(charges[i].count or 1) or 1))
    end

    local citationNumber = generateNumber('CIT')
    local issuedAt = os.date('!%Y-%m-%d %H:%M:%S')
    local issuedSort = os.time()
    local notes = trimText(data and data.notes)
    local citationId = MySQL.insert.await([[
        INSERT INTO mdt_citations (
            citation_number, report_number, report_id, report_title,
            issued_to_citizen_id, issued_to_name,
            issued_by_callsign, issued_by_name, issued_by_rank, issued_by_department, issued_by_department_short,
            charges, total_fine, notes, status, issued_at, issued_sort
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        citationNumber,
        report.report_number,
        report.id,
        report.title,
        citizenId,
        recipientName,
        trimText(officer.callsign),
        trimText(('%s %s'):format(officer.first_name or '', officer.last_name or '')):gsub('^%s+', ''):gsub('%s+$', ''),
        trimText(officer.rank),
        dept.label,
        dept.short,
        json.encode(charges),
        totalFine,
        notes ~= '' and notes or nil,
        'pending',
        issuedAt,
        issuedSort,
    })

    local citation = {
        id = citationId,
        citation_number = citationNumber,
        report_number = report.report_number,
        report_id = report.id,
        report_title = report.title,
        issued_by = {
            callsign = trimText(officer.callsign),
            name = trimText(('%s %s'):format(officer.first_name or '', officer.last_name or '')),
            rank = trimText(officer.rank),
            department = dept.label,
            department_short = dept.short,
        },
        issued_to = {
            citizen_id = citizenId,
            name = recipientName,
        },
        issued_at = issuedAt:gsub(' ', 'T') .. 'Z',
        issued_sort = issuedSort,
        status = 'pending',
        charges = charges,
        total_fine = totalFine,
        notes = notes,
    }

    auditLog(officerId, 'citation_issue', 'citation', 'citation', citationId, {
        report_id = reportId,
        citizen_id = citizenId,
        total_fine = totalFine,
    })

    return { ok = true, citation = citation }
end

local function fetchCitationRowsForCitizen(citizenId)
    local id = trimText(citizenId)
    if id == '' then
        return {}
    end

    local rows = MySQL.query.await('SELECT * FROM mdt_citations WHERE issued_to_citizen_id = ? ORDER BY issued_sort DESC, id DESC', { id }) or {}
    for i = 1, #rows do
        rows[i].charges = safeJsonDecode(rows[i].charges, {})
        rows[i] = {
            id = rows[i].id,
            citation_number = rows[i].citation_number,
            report_number = rows[i].report_number,
            report_id = rows[i].report_id,
            report_title = rows[i].report_title,
            issued_by = {
                callsign = rows[i].issued_by_callsign,
                name = rows[i].issued_by_name,
                rank = rows[i].issued_by_rank,
                department = rows[i].issued_by_department,
                department_short = rows[i].issued_by_department_short,
            },
            issued_to = {
                citizen_id = rows[i].issued_to_citizen_id,
                name = rows[i].issued_to_name,
            },
            issued_at = rows[i].issued_at,
            issued_sort = rows[i].issued_sort,
            status = rows[i].status,
            charges = rows[i].charges,
            total_fine = tonumber(rows[i].total_fine or 0) or 0,
            notes = rows[i].notes or '',
        }
    end

    return rows
end

local function safeJsonDecode(value, fallback)
    if type(value) ~= 'string' or value == '' then
        return fallback
    end

    local ok, decoded = pcall(json.decode, value)
    if ok and decoded ~= nil then
        return decoded
    end

    return fallback
end

local function buildCitizenStats(vehicles, reports, warrants, bolos)
    local arrestCount = 0

    for i = 1, #(reports or {}) do
        local role = tostring(reports[i].role or ''):lower()
        if role == 'arrested' or role == 'suspect' or role == 'detained' or role == 'offender' then
            arrestCount = arrestCount + 1
        end
    end

    return {
        vehicleCount = #(vehicles or {}),
        reportCount = #(reports or {}),
        warrantCount = #(warrants or {}),
        boloCount = #(bolos or {}),
        arrestCount = arrestCount,
    }
end

local function fetchCitizenDisplayName(citizenId)
    if not citizenId or tostring(citizenId) == '' then
        return nil
    end

    if usesLocalMode() then
        local payload = LocalMode.getCitizen(citizenId, 0)
        if payload and payload.citizen then
            return (('%s %s'):format(payload.citizen.first_name or '', payload.citizen.last_name or '')):gsub('^%s+', ''):gsub('%s+$', '')
        end
        return citizenId
    end

    local result = MySQL.query.await('SELECT first_name, last_name FROM mdt_citizens WHERE citizen_id = ? LIMIT 1', { citizenId }) or {}
    if result[1] then
        return (('%s %s'):format(result[1].first_name or '', result[1].last_name or '')):gsub('^%s+', ''):gsub('%s+$', '')
    end

    return citizenId
end

local function fetchAttachments(parentType, parentId)
    if not parentType or not parentId then
        return {}
    end

    if usesLocalMode() then
        if type(LocalMode.getAttachments) == 'function' then
            return LocalMode.getAttachments(parentType, parentId)
        end
        return {}
    end

    return MySQL.query.await([[
        SELECT a.*, o.first_name as uploader_first, o.last_name as uploader_last, o.callsign as uploader_callsign
        FROM mdt_attachments a
        LEFT JOIN mdt_officers o ON o.id = a.uploaded_by
        WHERE a.parent_type = ? AND a.parent_id = ?
        ORDER BY a.created_at DESC
    ]], { parentType, parentId }) or {}
end

local function replaceReportParticipants(reportId, participants)
    MySQL.update.await('DELETE FROM mdt_report_participants WHERE report_id = ?', { reportId })

    if type(participants) ~= 'table' then
        return
    end

    for i = 1, #participants do
        local participant = participants[i]
        local name = tostring(participant.name or ''):gsub('^%s+', ''):gsub('%s+$', '')
        if name ~= '' then
            MySQL.insert.await([[
                INSERT INTO mdt_report_participants (report_id, participant_type, name, citizen_id, officer_id, notes)
                VALUES (?, ?, ?, ?, ?, ?)
            ]], {
                reportId,
                participant.participantType or participant.participant_type or 'other',
                name,
                participant.citizenId or participant.citizen_id or nil,
                participant.officerId or participant.officer_id or nil,
                participant.notes or nil,
            })
        end
    end
end

local function replaceReportCharges(reportId, charges)
    MySQL.update.await('DELETE FROM mdt_report_charges WHERE report_id = ?', { reportId })

    if type(charges) ~= 'table' then
        return
    end

    for i = 1, #charges do
        local charge = charges[i]
        local label = tostring(charge.charge or ''):gsub('^%s+', ''):gsub('%s+$', '')
        if label ~= '' then
            MySQL.insert.await([[
                INSERT INTO mdt_report_charges (report_id, charge, severity, count, fine, notes)
                VALUES (?, ?, ?, ?, ?, ?)
            ]], {
                reportId,
                label,
                charge.severity or 'misdemeanor',
                tonumber(charge.count or 1) or 1,
                tonumber(charge.fine or 0) or 0,
                charge.notes or nil,
            })
        end
    end
end

lib.callback.register('cortex_mdt:registerOfficer', function(source, data)
    if not data or type(data) ~= 'table' then
        return { ok = false }
    end

    if data.useFrameworkDisplayName and usesLocalMode() then
        local profile = getBridgeOfficerProfile(source, true) or {}
        data = {
            firstName = trimText(profile.firstName or profile.first_name or ''),
            lastName = trimText(profile.lastName or profile.last_name or ''),
            callsign = data.callsign,
            rank = data.rank,
            departmentKey = data.departmentKey or data.department,
            avatar = data.avatar,
            avatarUrl = data.avatarUrl,
            certifications = data.certifications,
        }
    end

    local officerId = ensureOfficer(source, data)
    auditLog(officerId or 0, 'officer_register', 'officer', 'officer', officerId, {
        callsign = data.callsign,
        department = data.departmentKey or data.department,
    })
    return { ok = true, officerId = officerId }
end)

lib.callback.register('cortex_mdt:getDashboard', function(source)
    if usesLocalMode() then
        local dashboard = LocalMode.getDashboard()
        dashboard.ok = true
        return dashboard
    end

    local officerId = getOfficerId(source) or 0

    local motd = getSetting('motd') or ''
    local openReports = MySQL.query.await('SELECT COUNT(*) as cnt FROM mdt_reports WHERE status IN ("draft","submitted")') or {}
    local activeWarrants = MySQL.query.await('SELECT COUNT(*) as cnt FROM mdt_warrants WHERE status = "active"') or {}
    local unitsOnDuty = MySQL.query.await('SELECT COUNT(*) as cnt FROM mdt_units WHERE status != "off_duty"') or {}

    local bolos = MySQL.query.await('SELECT b.*, o.first_name, o.last_name FROM mdt_bolos b LEFT JOIN mdt_officers o ON b.issued_by = o.id WHERE b.status = "active" ORDER BY b.created_at DESC LIMIT 10') or {}
    local announcements = MySQL.query.await('SELECT a.*, CONCAT(o.first_name, " ", o.last_name) as author FROM mdt_announcements a LEFT JOIN mdt_officers o ON a.author_id = o.id WHERE a.active = 1 ORDER BY a.pinned DESC, a.created_at DESC LIMIT 5') or {}
    local recentReports = MySQL.query.await([[
        SELECT
            r.id,
            r.report_number,
            r.title,
            r.status,
            r.created_at,
            CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, '')) as author
        FROM mdt_reports r
        LEFT JOIN mdt_officers o ON r.author_id = o.id
        ORDER BY r.updated_at DESC
        LIMIT 6
    ]]) or {}
    local onDutyOfficers = MySQL.query.await([[
        SELECT
            u.officer_id as id,
            u.callsign,
            u.status,
            u.department,
            o.first_name,
            o.last_name,
            o.`rank`,
            o.avatar
        FROM mdt_units u
        LEFT JOIN mdt_officers o ON o.id = u.officer_id
        WHERE u.status != "off_duty"
        ORDER BY u.last_updated DESC
        LIMIT 12
    ]]) or {}

    for i = 1, #onDutyOfficers do
        local officer = onDutyOfficers[i]
        officer.status = normalizeUnitStatus(officer.status, 'available')
        officer.name = (('%s %s'):format(officer.first_name or '', officer.last_name or '')):gsub('^%s+', ''):gsub('%s+$', '')
    end

    return {
        ok = true,
        motd = motd,
        stats = {
            activeCalls = 0,
            openReports = (openReports[1] and openReports[1].cnt) or 0,
            activeWarrants = (activeWarrants[1] and activeWarrants[1].cnt) or 0,
            unitsOnDuty = (unitsOnDuty[1] and unitsOnDuty[1].cnt) or 0,
        },
        bolos = bolos,
        announcements = announcements,
        recentReports = recentReports,
        onDutyOfficers = onDutyOfficers,
        chatMessages = {},
        dispatchCalls = {},
    }
end)

lib.callback.register('cortex_mdt:globalSearch', function(source, data)
    local query = data and data.query or ''
    if #query < 2 then
        return { ok = true, results = {} }
    end

    local officerId = getOfficerId(source) or 0
    auditLog(officerId, 'global_search', 'search', nil, nil, { query = query })

    if usesLocalMode() then
        return { ok = true, results = LocalMode.globalSearch(query) }
    end

    local pattern = '%' .. query .. '%'
    local citizens = MySQL.query.await('SELECT id, citizen_id, first_name, last_name, dob FROM mdt_citizens WHERE first_name LIKE ? OR last_name LIKE ? OR citizen_id LIKE ? LIMIT 5', { pattern, pattern, pattern }) or {}
    local vehicles = MySQL.query.await('SELECT id, plate, model, owner_citizen_id FROM mdt_vehicles WHERE plate LIKE ? OR model LIKE ? LIMIT 5', { pattern, pattern }) or {}
    local reports = MySQL.query.await('SELECT id, report_number, title, status FROM mdt_reports WHERE report_number LIKE ? OR title LIKE ? LIMIT 5', { pattern, pattern }) or {}
    local cases = MySQL.query.await('SELECT id, case_number, title, status FROM mdt_cases WHERE case_number LIKE ? OR title LIKE ? LIMIT 5', { pattern, pattern }) or {}
    local standalone = getStandaloneCivilianModule()

    if standalone then
        citizens = appendUniqueRows(citizens, standalone.searchCitizens(query, 5) or {}, function(row)
            return row.citizen_id or row.citizenId or row.id
        end, 5)
        vehicles = appendUniqueRows(vehicles, standalone.searchVehicles(query, 5) or {}, function(row)
            return row.plate or row.id or row.vehicle_id
        end, 5)
    end

    return {
        ok = true,
        results = { citizens = citizens, vehicles = vehicles, reports = reports, cases = cases },
    }
end)

lib.callback.register('cortex_mdt:searchCitizens', function(source, data)
    local query = data and data.query or ''
    local officerId = getOfficerId(source) or 0
    auditLog(officerId, 'citizen_search', 'search', nil, nil, { query = query })

    if #query < 1 then
        return { ok = true, citizens = {} }
    end

    if usesLocalMode() then
        return { ok = true, citizens = LocalMode.searchCitizens(query, 25) }
    end

    local pattern = '%' .. query .. '%'
    local results = MySQL.query.await('SELECT * FROM mdt_citizens WHERE first_name LIKE ? OR last_name LIKE ? OR citizen_id LIKE ? OR fingerprint LIKE ? OR phone LIKE ? OR occupation LIKE ? OR notes LIKE ? ORDER BY last_name ASC LIMIT 25', { pattern, pattern, pattern, pattern, pattern, pattern, pattern }) or {}
    local standalone = getStandaloneCivilianModule()

    for i = 1, #results do
        results[i].flags = json.decode(results[i].flags) or {}
        results[i].properties = safeJsonDecode(results[i].properties, {})
        results[i].mugshot = trimText(results[i].mugshot) ~= '' and results[i].mugshot or defaultMugshotUrl()
        if type(results[i].properties.ersPersonalDetails) == 'table' then
            results[i].nationality = results[i].nationality or results[i].properties.ersPersonalDetails.nationality
            results[i].address = results[i].address or results[i].properties.ersPersonalDetails.address
            results[i].email = results[i].email or results[i].properties.ersPersonalDetails.email
        end
    end

    if standalone then
        results = appendUniqueRows(results, standalone.searchCitizens(query, 25) or {}, function(row)
            return row.citizen_id or row.citizenId or row.id
        end, 25)
    end

    return { ok = true, citizens = results }
end)

lib.callback.register('cortex_mdt:getCitizen', function(source, data)
    local citizenId = data and data.citizenId
    if not citizenId then return { ok = false } end

    local officerId = getOfficerId(source) or 0
    auditLog(officerId, 'citizen_view', 'citizen', 'citizen', nil, { citizenId = citizenId })

    if usesLocalMode() then
        local payload = LocalMode.getCitizen(citizenId, source)
        if not payload then
            return { ok = false }
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
    end

    local citizen = MySQL.query.await('SELECT * FROM mdt_citizens WHERE citizen_id = ?', { citizenId })
    if not citizen or not citizen[1] then
        local standalone = getStandaloneCivilianModule()
        if standalone then
            local standaloneCitizen = standalone.getCitizenData(citizenId, source)
            if standaloneCitizen then
                local standaloneProfile = standaloneCitizen.citizen or {}
                local standaloneVehicles = standaloneCitizen.vehicles or {}
                local standaloneLicenses = standaloneCitizen.licenses or {}
                local standaloneReports = standaloneCitizen.reports or {}
                local standaloneWarrants = standaloneCitizen.warrants or {}
                local standaloneBolos = standaloneCitizen.bolos or {}

                standaloneProfile.properties = standaloneProfile.properties or {}
                standaloneProfile.stats = buildCitizenStats(standaloneVehicles, standaloneReports, standaloneWarrants, standaloneBolos)
                standaloneProfile.stats.propertyCount = #(standaloneProfile.properties or {})
                standaloneProfile.job = standaloneProfile.occupation or standaloneProfile.job or nil
                standaloneProfile.property_count = #(standaloneProfile.properties or {})
                standaloneProfile.arrest_count = tonumber(standaloneProfile.arrest_count or standaloneProfile.stats.arrestCount or 0) or 0
                standaloneProfile.mugshot = trimText(standaloneProfile.mugshot) ~= '' and standaloneProfile.mugshot or defaultMugshotUrl()

                return {
                    ok = true,
                    citizen = standaloneProfile,
                    vehicles = standaloneVehicles,
                    licenses = standaloneLicenses,
                    reports = standaloneReports,
                    warrants = standaloneWarrants,
                    bolos = standaloneBolos,
                }
            end
        end

        return { ok = false }
    end

    local c = citizen[1]
    c.flags = safeJsonDecode(c.flags, {})
    c.properties = safeJsonDecode(c.properties, {})
    c.mugshot = trimText(c.mugshot) ~= '' and c.mugshot or defaultMugshotUrl()
    if type(c.properties.ersPersonalDetails) == 'table' then
        c.nationality = c.nationality or c.properties.ersPersonalDetails.nationality
        c.address = c.address or c.properties.ersPersonalDetails.address
        c.email = c.email or c.properties.ersPersonalDetails.email
    end
    c.tags = {}

    local vehicles = MySQL.query.await('SELECT * FROM mdt_vehicles WHERE owner_citizen_id = ?', { citizenId }) or {}
    local licenses = MySQL.query.await('SELECT * FROM mdt_citizen_licenses WHERE citizen_id = ?', { citizenId }) or {}
    local tags = MySQL.query.await('SELECT label, color FROM mdt_citizen_tags WHERE citizen_id = ? ORDER BY label ASC', { citizenId }) or {}
    local reportEntities = MySQL.query.await([[
        SELECT r.id, r.report_number, r.title, r.status, r.created_at, re.role
        FROM mdt_report_entities re
        JOIN mdt_reports r ON r.id = re.report_id
        JOIN mdt_citizens ci ON ci.id = re.entity_id AND re.entity_type = 'citizen'
        WHERE ci.citizen_id = ?
        ORDER BY r.created_at DESC LIMIT 20
    ]], { citizenId }) or {}
    local warrants = MySQL.query.await('SELECT * FROM mdt_warrants WHERE citizen_id = ? ORDER BY created_at DESC', { citizenId }) or {}
    local bolos = MySQL.query.await('SELECT * FROM mdt_bolos WHERE citizen_id = ? ORDER BY created_at DESC', { citizenId }) or {}

    for i = 1, #vehicles do
        vehicles[i].flags = safeJsonDecode(vehicles[i].flags, {})
    end
    for i = 1, #warrants do
        warrants[i].charges = safeJsonDecode(warrants[i].charges, {})
    end
    for i = 1, #tags do
        c.tags[#c.tags + 1] = {
            label = tags[i].label,
            color = normalizeCitizenTagColor(tags[i].color),
        }
    end

    c.stats = buildCitizenStats(vehicles, reportEntities, warrants, bolos)
    c.stats.propertyCount = #(c.properties or {})
    c.job = c.occupation or c.job or nil
    c.property_count = #(c.properties or {})
    c.arrest_count = tonumber(c.stats.arrestCount or 0) or 0

    return {
        ok = true,
        citizen = c,
        vehicles = vehicles,
        licenses = licenses,
        reports = reportEntities,
        warrants = warrants,
        bolos = bolos,
    }
end)

lib.callback.register('cortex_mdt:updateCitizen', function(source, data)
    if not data or not data.citizenId then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.updateCitizen(data)
        if ok then
            auditLog(officerId, 'citizen_update', 'citizen', 'citizen', nil, { citizenId = data.citizenId })
        end
        return { ok = ok, error = ok and nil or 'Citizen not found.' }
    end

    local current = MySQL.query.await('SELECT * FROM mdt_citizens WHERE citizen_id = ? LIMIT 1', { data.citizenId }) or {}
    if not current[1] then
        return { ok = false, error = 'Citizen not found.' }
    end

    local currentCitizen = current[1]
    local nextFlags = type(data.flags) == 'table' and data.flags or safeJsonDecode(currentCitizen.flags, {})
    local nextProperties = type(data.properties) == 'table' and data.properties or safeJsonDecode(currentCitizen.properties, {})
    local nextTags = type(data.tags) == 'table' and data.tags or nil

    MySQL.update.await('UPDATE mdt_citizens SET mugshot = ?, flags = ?, notes = ?, fingerprint = ?, occupation = ?, properties = ? WHERE citizen_id = ?', {
        data.mugshot ~= nil and (trimText(data.mugshot) ~= '' and trimText(data.mugshot) or defaultMugshotUrl()) or (trimText(currentCitizen.mugshot) ~= '' and currentCitizen.mugshot or defaultMugshotUrl()),
        json.encode(nextFlags),
        data.notes ~= nil and data.notes or currentCitizen.notes,
        data.fingerprint ~= nil and data.fingerprint or currentCitizen.fingerprint,
        data.occupation ~= nil and data.occupation or currentCitizen.occupation,
        json.encode(nextProperties),
        data.citizenId,
    })

    if type(data.licenses) == 'table' then
        MySQL.update.await('DELETE FROM mdt_citizen_licenses WHERE citizen_id = ?', { data.citizenId })

        for i = 1, #data.licenses do
            local license = data.licenses[i]
            local licenseType = tostring(license.type or ''):gsub('^%s+', ''):gsub('%s+$', '')
            if licenseType ~= '' then
                MySQL.insert.await('INSERT INTO mdt_citizen_licenses (citizen_id, type, status, expires_at) VALUES (?, ?, ?, ?)', {
                    data.citizenId,
                    licenseType,
                    license.status or 'valid',
                    license.expires_at or license.expiresAt or nil,
                })
            end
        end
    end

    if nextTags then
        MySQL.update.await('DELETE FROM mdt_citizen_tags WHERE citizen_id = ?', { data.citizenId })

        for i = 1, #nextTags do
            local item = nextTags[i]
            local label = ''
            local color = 'blue'
            if type(item) == 'string' then
                label = trimText(item)
            elseif type(item) == 'table' then
                label = trimText(item.label or item[1])
                color = normalizeCitizenTagColor(item.color or item.colour)
            end
            if label ~= '' then
                MySQL.insert.await('INSERT IGNORE INTO mdt_citizen_tags (citizen_id, label, color, created_by) VALUES (?, ?, ?, ?)', {
                    data.citizenId,
                    label,
                    color,
                    officerId,
                })
            end
        end
    end

    auditLog(officerId, 'citizen_update', 'citizen', 'citizen', nil, { citizenId = data.citizenId })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:updateCitizenLicenses', function(source, data)
    if not data or not data.citizenId then
        return { ok = false, error = 'Citizen not found.' }
    end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local licenses = type(data.licenses) == 'table' and data.licenses or {}
        local ok = LocalMode.updateCitizenLicenses(data.citizenId, licenses)
        if ok then
            auditLog(officerId, 'citizen_license_update', 'citizen', 'citizen', nil, { citizenId = data.citizenId, count = #licenses })
        end
        return { ok = ok, error = ok and nil or 'Citizen not found.' }
    end

    MySQL.update.await('DELETE FROM mdt_citizen_licenses WHERE citizen_id = ?', { data.citizenId })

    local licenses = type(data.licenses) == 'table' and data.licenses or {}
    for i = 1, #licenses do
        local license = licenses[i]
        local licenseType = tostring(license.type or ''):gsub('^%s+', ''):gsub('%s+$', '')
        if licenseType ~= '' then
            MySQL.insert.await('INSERT INTO mdt_citizen_licenses (citizen_id, type, status, expires_at) VALUES (?, ?, ?, ?)', {
                data.citizenId,
                licenseType,
                license.status or 'valid',
                license.expires_at or license.expiresAt or nil,
            })
        end
    end

    auditLog(officerId, 'citizen_license_update', 'citizen', 'citizen', nil, { citizenId = data.citizenId, count = #licenses })
    return { ok = true }
end)

-- License Type Catalog CRUD

lib.callback.register('cortex_mdt:fetchLicenseTypes', function(source)
    if usesLocalMode() then
        return { ok = true, licenses = LocalMode.fetchLicenseTypes() }
    end

    local rows = MySQL.query.await('SELECT id, type_id, name, description, active FROM mdt_license_types ORDER BY name ASC') or {}

    if #rows == 0 and type(Config.LicenseTypes) == 'table' and #Config.LicenseTypes > 0 then
        for i = 1, #Config.LicenseTypes do
            local preset = Config.LicenseTypes[i]
            MySQL.insert.await('INSERT IGNORE INTO mdt_license_types (type_id, name, description, active) VALUES (?, ?, ?, ?)', {
                preset.id,
                preset.label,
                preset.description or '',
                1,
            })
        end
        rows = MySQL.query.await('SELECT id, type_id, name, description, active FROM mdt_license_types ORDER BY name ASC') or {}
    end

    return { ok = true, licenses = rows }
end)

lib.callback.register('cortex_mdt:createLicenseType', function(source, data)
    if not data or not data.name or trimText(data.name) == '' then
        return { ok = false, error = 'License name is required.' }
    end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local created = LocalMode.createLicenseType(data)
        if created then
            auditLog(officerId, 'license_type_create', 'admin', 'license_type', created.id, { name = data.name })
            return { ok = true, license = created }
        end
        return { ok = false, error = 'Failed to create license type.' }
    end

    local typeId = trimText(data.type_id or data.typeId or ''):lower():gsub('%s+', '_'):gsub('[^a-z0-9_]', '')
    if typeId == '' then
        typeId = trimText(data.name):lower():gsub('%s+', '_'):gsub('[^a-z0-9_]', '')
    end

    MySQL.insert.await('INSERT INTO mdt_license_types (type_id, name, description, active) VALUES (?, ?, ?, ?)', {
        typeId,
        trimText(data.name),
        trimText(data.description or ''),
        1,
    })
    local id = MySQL.insert.await('SELECT LAST_INSERT_ID() as id') or {}
    auditLog(officerId, 'license_type_create', 'admin', 'license_type', id[1] and id[1].id or nil, { name = data.name })
    return { ok = true, license = { id = id[1] and id[1].id, type_id = typeId, name = trimText(data.name), description = trimText(data.description or ''), active = 1 } }
end)

lib.callback.register('cortex_mdt:updateLicenseType', function(source, data)
    if not data or not data.id then
        return { ok = false, error = 'License id is required.' }
    end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.updateLicenseType(data)
        if ok then
            auditLog(officerId, 'license_type_update', 'admin', 'license_type', data.id, nil)
        end
        return { ok = ok ~= false, error = ok and nil or 'License not found.' }
    end

    local updates = {}
    local params = {}

    if data.name ~= nil then
        updates[#updates + 1] = 'name = ?'
        params[#params + 1] = trimText(data.name)
    end
    if data.description ~= nil then
        updates[#updates + 1] = 'description = ?'
        params[#params + 1] = trimText(data.description)
    end
    if data.active ~= nil then
        updates[#updates + 1] = 'active = ?'
        params[#params + 1] = data.active and 1 or 0
    end

    if #updates == 0 then
        return { ok = false, error = 'No fields to update.' }
    end

    params[#params + 1] = data.id
    MySQL.update.await(('UPDATE mdt_license_types SET %s WHERE id = ?'):format(table.concat(updates, ', ')), params)
    auditLog(officerId, 'license_type_update', 'admin', 'license_type', data.id, nil)
    return { ok = true }
end)

lib.callback.register('cortex_mdt:deleteLicenseType', function(source, data)
    if not data or not data.id then
        return { ok = false, error = 'License id is required.' }
    end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.deleteLicenseType(data.id)
        if ok then
            auditLog(officerId, 'license_type_delete', 'admin', 'license_type', data.id, nil)
        end
        return { ok = ok ~= false, error = ok and nil or 'License not found.' }
    end

    MySQL.update.await('DELETE FROM mdt_license_types WHERE id = ?', { data.id })
    auditLog(officerId, 'license_type_delete', 'admin', 'license_type', data.id, nil)
    return { ok = true }
end)

lib.callback.register('cortex_mdt:searchVehicles', function(source, data)
    local query = data and data.query or ''
    local officerId = getOfficerId(source) or 0
    auditLog(officerId, 'vehicle_search', 'search', nil, nil, { query = query })

    if #query < 1 then
        return { ok = true, vehicles = {} }
    end

    if usesLocalMode() then
        return { ok = true, vehicles = LocalMode.searchVehicles(query, 25) }
    end

    local pattern = '%' .. query .. '%'
    local results = MySQL.query.await([[
        SELECT v.*, c.first_name as owner_first, c.last_name as owner_last
        FROM mdt_vehicles v
        LEFT JOIN mdt_citizens c ON v.owner_citizen_id = c.citizen_id
        WHERE v.plate LIKE ? OR v.vin LIKE ? OR v.model LIKE ?
        ORDER BY v.plate ASC LIMIT 25
    ]], { pattern, pattern, pattern }) or {}
    local standalone = getStandaloneCivilianModule()

    for i = 1, #results do
        results[i].flags = json.decode(results[i].flags) or {}
    end

    if standalone then
        results = appendUniqueRows(results, standalone.searchVehicles(query, 25) or {}, function(row)
            return row.plate or row.id or row.vehicle_id
        end, 25)
    end

    return { ok = true, vehicles = results }
end)

lib.callback.register('cortex_mdt:getVehicle', function(source, data)
    local vehicleId = data and data.vehicleId
    if not vehicleId then return { ok = false } end

    local officerId = getOfficerId(source) or 0
    auditLog(officerId, 'vehicle_view', 'vehicle', 'vehicle', vehicleId, nil)

    if usesLocalMode() then
        local payload = LocalMode.getVehicle(vehicleId, source)
        if not payload then
            return { ok = false }
        end

        return { ok = true, vehicle = payload.vehicle, impounds = payload.impounds }
    end

    local vehicle = MySQL.query.await([[
        SELECT v.*, c.first_name as owner_first, c.last_name as owner_last, c.citizen_id as owner_cid
        FROM mdt_vehicles v
        LEFT JOIN mdt_citizens c ON v.owner_citizen_id = c.citizen_id
        WHERE v.id = ?
    ]], { vehicleId })
    if not vehicle or not vehicle[1] then
        local standalone = getStandaloneCivilianModule()
        if standalone then
            local standaloneVehicle = standalone.getVehicleData(vehicleId, source)
            if standaloneVehicle then
                return {
                    ok = true,
                    vehicle = standaloneVehicle.vehicle,
                    impounds = standaloneVehicle.impounds or {},
                }
            end
        end

        return { ok = false }
    end

    local v = vehicle[1]
    v.flags = json.decode(v.flags) or {}

    local impounds = MySQL.query.await([[
        SELECT i.*, o.first_name as officer_first, o.last_name as officer_last
        FROM mdt_impounds i
        LEFT JOIN mdt_officers o ON i.officer_id = o.id
        WHERE i.vehicle_id = ?
        ORDER BY i.created_at DESC
    ]], { vehicleId }) or {}

    return { ok = true, vehicle = v, impounds = impounds }
end)

lib.callback.register('cortex_mdt:impoundVehicle', function(source, data)
    if not data or not data.vehicleId then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local impound = LocalMode.impoundVehicle(data, officerId)
        if impound then
            auditLog(officerId, 'vehicle_impound', 'vehicle', 'vehicle', data.vehicleId, { fee = data.fee, lot = data.lotLocation })
            return { ok = true, impound = impound }
        end
        return { ok = false }
    end

    local vehicle = MySQL.query.await('SELECT plate FROM mdt_vehicles WHERE id = ?', { data.vehicleId })
    if not vehicle or not vehicle[1] then return { ok = false } end

    local holdUntil = nil
    if data.holdHours and data.holdHours > 0 then
        holdUntil = os.date('%Y-%m-%d %H:%M:%S', os.time() + (data.holdHours * 3600))
    end

    MySQL.insert.await('INSERT INTO mdt_impounds (vehicle_id, plate, officer_id, reason, lot_location, fee, hold_until) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        data.vehicleId, vehicle[1].plate, officerId, data.reason or '', data.lotLocation or 'Downtown Lot', data.fee or 0, holdUntil
    })
    MySQL.update.await('UPDATE mdt_vehicles SET registration_status = "suspended" WHERE id = ?', { data.vehicleId })

    auditLog(officerId, 'vehicle_impound', 'vehicle', 'vehicle', data.vehicleId, { fee = data.fee, lot = data.lotLocation })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:releaseImpound', function(source, data)
    if not data or not data.impoundId then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.releaseImpound(data)
        if ok then
            auditLog(officerId, 'impound_release', 'vehicle', 'impound', data.impoundId, nil)
        end
        return { ok = ok }
    end

    MySQL.update.await('UPDATE mdt_impounds SET status = "released", released_by = ?, released_at = NOW() WHERE id = ?', { officerId, data.impoundId })
    local impound = MySQL.query.await('SELECT vehicle_id FROM mdt_impounds WHERE id = ?', { data.impoundId })
    if impound and impound[1] then
        MySQL.update.await('UPDATE mdt_vehicles SET registration_status = "valid" WHERE id = ?', { impound[1].vehicle_id })
    end

    auditLog(officerId, 'impound_release', 'vehicle', 'impound', data.impoundId, nil)
    return { ok = true }
end)

lib.callback.register('cortex_mdt:getReports', function(source, data)
    local page = (data and data.page) or 1
    local limit = 20
    local offset = (page - 1) * limit
    local filter = data and data.filter or 'all'

    if usesLocalMode() then
        local payload = LocalMode.getReports(page, filter, source)
        return { ok = true, reports = payload.reports, total = payload.total, page = payload.page }
    end

    local where = ''
    if filter == 'mine' then
        local officerId = getOfficerId(source) or 0
        where = (' WHERE r.author_id = %d'):format(officerId)
    elseif filter == 'submitted' then
        where = ' WHERE r.status = "submitted"'
    elseif filter == 'draft' then
        where = ' WHERE r.status = "draft"'
    end

    local reports = MySQL.query.await(([[
        SELECT r.*, o.first_name as author_first, o.last_name as author_last
        FROM mdt_reports r
        LEFT JOIN mdt_officers o ON r.author_id = o.id
        %s
        ORDER BY r.updated_at DESC LIMIT ? OFFSET ?
    ]]):format(where), { limit, offset }) or {}

    local countResult = MySQL.query.await(('SELECT COUNT(*) as cnt FROM mdt_reports r %s'):format(where)) or {}
    local total = (countResult[1] and countResult[1].cnt) or 0

    for i = 1, #reports do
        reports[i].tags = json.decode(reports[i].tags) or {}
        reports[i].restricted_to = json.decode(reports[i].restricted_to) or {}
    end

    return { ok = true, reports = reports, total = total, page = page }
end)

lib.callback.register('cortex_mdt:getReport', function(source, data)
    local reportId = data and data.reportId
    if not reportId then return { ok = false } end

    local officerId = getOfficerId(source) or 0
    auditLog(officerId, 'report_view', 'report', 'report', reportId, nil)

    if usesLocalMode() then
        local payload = LocalMode.getReport(reportId)
        if not payload then return { ok = false } end
        return {
            ok = true,
            report = payload.report,
            timeline = payload.timeline,
            entities = payload.entities,
            participants = payload.participants,
            charges = payload.charges,
            attachments = payload.attachments,
            collaborators = payload.collaborators,
        }
    end

    local report = MySQL.query.await([[
        SELECT r.*, o.first_name as author_first, o.last_name as author_last
        FROM mdt_reports r LEFT JOIN mdt_officers o ON r.author_id = o.id
        WHERE r.id = ?
    ]], { reportId })
    if not report or not report[1] then return { ok = false } end

    local r = report[1]
    r.tags = json.decode(r.tags) or {}
    r.restricted_to = json.decode(r.restricted_to) or {}

    local timeline = MySQL.query.await([[
        SELECT t.*, o.first_name, o.last_name FROM mdt_report_timeline t
        LEFT JOIN mdt_officers o ON t.author_id = o.id
        WHERE t.report_id = ? ORDER BY t.timestamp ASC
    ]], { reportId }) or {}

    local entities = MySQL.query.await('SELECT * FROM mdt_report_entities WHERE report_id = ?', { reportId }) or {}
    local participants = MySQL.query.await('SELECT * FROM mdt_report_participants WHERE report_id = ? ORDER BY id ASC', { reportId }) or {}
    local charges = MySQL.query.await('SELECT * FROM mdt_report_charges WHERE report_id = ? ORDER BY id ASC', { reportId }) or {}
    local attachments = fetchAttachments('report', reportId)
    local collaborators = MySQL.query.await([[
        SELECT rc.officer_id, o.first_name, o.last_name, o.callsign
        FROM mdt_report_collaborators rc LEFT JOIN mdt_officers o ON rc.officer_id = o.id
        WHERE rc.report_id = ?
    ]], { reportId }) or {}

    return {
        ok = true,
        report = r,
        timeline = timeline,
        entities = entities,
        participants = participants,
        charges = charges,
        attachments = attachments,
        collaborators = collaborators
    }
end)

lib.callback.register('cortex_mdt:createReport', function(source, data)
    if not data or not data.title then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local id, reportNumber = LocalMode.createReport(source, data)
        auditLog(officerId, 'report_create', 'report', 'report', id, { number = reportNumber })
        return { ok = true, reportId = id, reportNumber = reportNumber }
    end

    local prefix = getSetting('report_prefix') or 'RPT'
    local reportNumber = generateNumber(prefix)
    local officer = MySQL.query.await('SELECT department FROM mdt_officers WHERE id = ?', { officerId })
    local dept = (officer and officer[1] and officer[1].department) or 'police'

    local id = MySQL.insert.await('INSERT INTO mdt_reports (report_number, title, template, narrative, author_id, department, tags) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        reportNumber, data.title, data.template or 'general', data.narrative or '', officerId, dept, json.encode(data.tags or {})
    })

    replaceReportParticipants(id, data.participants)
    replaceReportCharges(id, data.charges)

    auditLog(officerId, 'report_create', 'report', 'report', id, { number = reportNumber })
    return { ok = true, reportId = id, reportNumber = reportNumber }
end)

lib.callback.register('cortex_mdt:updateReport', function(source, data)
    if not data or not data.reportId then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.updateReport(data)
        if ok then
            auditLog(officerId, 'report_update', 'report', 'report', data.reportId, nil)
        end
        return { ok = ok }
    end

    MySQL.update.await('UPDATE mdt_reports SET title = ?, narrative = ?, status = ?, tags = ?, priority = ?, restricted = ?, restricted_to = ? WHERE id = ?', {
        data.title or '', data.narrative or '', data.status or 'draft',
        json.encode(data.tags or {}), data.priority or 'normal',
        data.restricted and 1 or 0, json.encode(data.restrictedTo or {}), data.reportId
    })

    if type(data.participants) == 'table' then
        replaceReportParticipants(data.reportId, data.participants)
    end

    if type(data.charges) == 'table' then
        replaceReportCharges(data.reportId, data.charges)
    end

    auditLog(officerId, 'report_update', 'report', 'report', data.reportId, nil)
    return { ok = true }
end)

lib.callback.register('cortex_mdt:issueCitation', function(source, data)
    if not Config.Citations or Config.Citations.enabled == false then
        return { ok = false, error = 'Citation system is disabled.' }
    end

    local response
    if usesLocalMode() then
        response = LocalMode.issueCitation(source, data)
    else
        response = issueCitationInSql(source, data)
    end

    if not response or response.ok ~= true or type(response.citation) ~= 'table' then
        return response or { ok = false, error = 'Failed to issue citation.' }
    end

    local recipientSource = getCitationRecipientSource(response.citation.issued_to and response.citation.issued_to.citizen_id)
    if recipientSource then
        deliverCitationToPlayer(recipientSource, response.citation)
    end

    return response
end)

lib.callback.register('cortex_mdt:getMyCitations', function(source)
    if not Config.Citations or Config.Citations.enabled == false then
        return { ok = true, citations = {} }
    end

    if usesLocalMode() then
        local standalone = getStandaloneCivilianModule()
        local citations = {}
        local seen = {}

        if standalone and type(standalone.getCivilianProfile) == 'function' then
            local profile = standalone.getCivilianProfile(source)
            local citizenId = trimText(profile and (profile.citizenId or profile.citizen_id))
            if citizenId ~= '' then
                local resp = LocalMode.getCitationsForCitizen(citizenId)
                for i = 1, #(resp and resp.citations or {}) do
                    citations[#citations + 1] = resp.citations[i]
                    seen[resp.citations[i].id] = true
                end
            end
        end

        local fallbackName = trimText(GetPlayerName(source))
        if fallbackName ~= '' then
            local resp = LocalMode.getCitationsForCitizen(fallbackName)
            for i = 1, #(resp and resp.citations or {}) do
                if not seen[resp.citations[i].id] then
                    citations[#citations + 1] = resp.citations[i]
                end
            end
        end

        table.sort(citations, function(a, b)
            return (a.issued_sort or 0) > (b.issued_sort or 0)
        end)

        return { ok = true, citations = citations }
    end

    local qbxCitizenId = ''
    if GetResourceState('qbx_core') == 'started' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(source)
        end)
        local playerData = ok and player and player.PlayerData or nil
        local charinfo = type(playerData) == 'table' and type(playerData.charinfo) == 'table' and playerData.charinfo or nil
        qbxCitizenId = trimText(charinfo and (charinfo.citizenid or charinfo.citizenId))
    end

    if qbxCitizenId == '' then
        local standalone = getStandaloneCivilianModule()
        if standalone and type(standalone.getCivilianProfile) == 'function' then
            local profile = standalone.getCivilianProfile(source)
            qbxCitizenId = trimText(profile and (profile.citizenId or profile.citizen_id))
        end
    end

    if qbxCitizenId == '' then
        return { ok = true, citations = {} }
    end

    rememberCitizenSource(qbxCitizenId, source)
    return { ok = true, citations = fetchCitationRowsForCitizen(qbxCitizenId) }
end)

lib.callback.register('cortex_mdt:getCitation', function(source, data)
    if not Config.Citations or Config.Citations.enabled == false then
        return { ok = false, error = 'Citation system is disabled.' }
    end

    local citationId = tonumber(data and data.citationId)
    if not citationId then
        return { ok = false, error = 'Missing citation ID.' }
    end

    if usesLocalMode() then
        auditLog(getOfficerId(source) or 0, 'citation_view', 'citation', 'citation', citationId, nil)
        return LocalMode.getCitation(citationId)
    end

    local rows = MySQL.query.await('SELECT * FROM mdt_citations WHERE id = ? LIMIT 1', { citationId }) or {}
    if not rows[1] then
        return { ok = false, error = 'Citation not found.' }
    end

    local item = fetchCitationRowsForCitizen(rows[1].issued_to_citizen_id)
    for i = 1, #item do
        if tonumber(item[i].id) == citationId then
            auditLog(getOfficerId(source) or 0, 'citation_view', 'citation', 'citation', citationId, nil)
            return { ok = true, citation = item[i] }
        end
    end

    return { ok = false, error = 'Citation not found.' }
end)

lib.callback.register('cortex_mdt:markCitationViewed', function(source, data)
    if not Config.Citations or Config.Citations.enabled == false then
        return { ok = false, error = 'Citation system is disabled.' }
    end

    local citationId = tonumber(data and data.citationId)
    if not citationId then
        return { ok = false, error = 'Missing citation ID.' }
    end

    if usesLocalMode() then
        local result = LocalMode.markCitationViewed(citationId)
        if result and result.ok then
            auditLog(getOfficerId(source) or 0, 'citation_mark_viewed', 'citation', 'citation', citationId, nil)
        end
        return result
    end

    MySQL.update.await('UPDATE mdt_citations SET status = CASE WHEN status = ? THEN ? ELSE status END WHERE id = ?', {
        'pending', 'viewed', citationId,
    })

    auditLog(getOfficerId(source) or 0, 'citation_mark_viewed', 'citation', 'citation', citationId, nil)
    return { ok = true }
end)

lib.callback.register('cortex_mdt:addReportTimeline', function(source, data)
    if not data or not data.reportId or not data.description then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.addReportTimeline(source, data)
        if ok then
            auditLog(officerId, 'report_timeline_add', 'report', 'report', data.reportId, nil)
        end
        return { ok = ok }
    end

    MySQL.insert.await('INSERT INTO mdt_report_timeline (report_id, timestamp, description, author_id) VALUES (?, ?, ?, ?)', {
        data.reportId, data.timestamp or os.date('%H:%M:%S'), data.description, officerId
    })
    auditLog(officerId, 'report_timeline_add', 'report', 'report', data.reportId, nil)
    return { ok = true }
end)

lib.callback.register('cortex_mdt:addReportEntity', function(source, data)
    if not data or not data.reportId or not data.entityType or not data.entityId then return { ok = false } end
    local officerId = getOfficerId(source) or 0
    if usesLocalMode() then
        local ok = LocalMode.addReportEntity(data)
        if ok then
            auditLog(officerId, 'report_entity_add', 'report', data.entityType, data.entityId, { reportId = data.reportId, role = data.role })
        end
        return { ok = ok }
    end
    MySQL.insert.await('INSERT IGNORE INTO mdt_report_entities (report_id, entity_type, entity_id, role) VALUES (?, ?, ?, ?)', {
        data.reportId, data.entityType, data.entityId, data.role or 'involved'
    })
    auditLog(officerId, 'report_entity_add', 'report', data.entityType, data.entityId, { reportId = data.reportId, role = data.role })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:removeReportEntity', function(source, data)
    if not data or not data.id then return { ok = false } end
    local officerId = getOfficerId(source) or 0
    if usesLocalMode() then
        local ok = LocalMode.removeReportEntity(data)
        if ok then
            auditLog(officerId, 'report_entity_remove', 'report', 'report_entity', data.id, { reportId = data.reportId })
        end
        return { ok = ok }
    end
    MySQL.update.await('DELETE FROM mdt_report_entities WHERE id = ?', { data.id })
    auditLog(officerId, 'report_entity_remove', 'report', 'report_entity', data.id, { reportId = data.reportId })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:getCases', function(source, data)
    local page = (data and data.page) or 1
    local limit = 20
    local offset = (page - 1) * limit

    if usesLocalMode() then
        local payload = LocalMode.getCases(page)
        return { ok = true, cases = payload.cases, total = payload.total, page = payload.page }
    end

    local cases = MySQL.query.await([[
        SELECT c.*, o.first_name as lead_first, o.last_name as lead_last
        FROM mdt_cases c LEFT JOIN mdt_officers o ON c.lead_officer_id = o.id
        ORDER BY c.updated_at DESC LIMIT ? OFFSET ?
    ]], { limit, offset }) or {}

    local countResult = MySQL.query.await('SELECT COUNT(*) as cnt FROM mdt_cases') or {}
    local total = (countResult[1] and countResult[1].cnt) or 0

    return { ok = true, cases = cases, total = total, page = page }
end)

lib.callback.register('cortex_mdt:getCase', function(source, data)
    local caseId = data and data.caseId
    if not caseId then return { ok = false } end

    local officerId = getOfficerId(source) or 0
    auditLog(officerId, 'case_view', 'case', 'case', caseId, nil)

    if usesLocalMode() then
        local payload = LocalMode.getCase(caseId)
        if not payload then return { ok = false } end
        return { ok = true, ['case'] = payload.caseData, personnel = payload.personnel, links = payload.links, attachments = payload.attachments }
    end

    local caseData = MySQL.query.await([[
        SELECT c.*, o.first_name as lead_first, o.last_name as lead_last
        FROM mdt_cases c LEFT JOIN mdt_officers o ON c.lead_officer_id = o.id
        WHERE c.id = ?
    ]], { caseId })
    if not caseData or not caseData[1] then return { ok = false } end

    local personnel = MySQL.query.await([[
        SELECT cp.*, o.first_name, o.last_name, o.callsign, o.`rank`
        FROM mdt_case_personnel cp LEFT JOIN mdt_officers o ON cp.officer_id = o.id
        WHERE cp.case_id = ?
    ]], { caseId }) or {}

    local links = MySQL.query.await('SELECT * FROM mdt_case_links WHERE case_id = ?', { caseId }) or {}
    local attachments = fetchAttachments('case', caseId)

    return { ok = true, ['case'] = caseData[1], personnel = personnel, links = links, attachments = attachments }
end)

lib.callback.register('cortex_mdt:createCase', function(source, data)
    if not data or not data.title then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local id, caseNumber = LocalMode.createCase(source, data)
        auditLog(officerId, 'case_create', 'case', 'case', id, { number = caseNumber })
        return { ok = true, caseId = id, caseNumber = caseNumber }
    end

    local prefix = getSetting('case_prefix') or 'CASE'
    local caseNumber = generateNumber(prefix)
    local officer = MySQL.query.await('SELECT department FROM mdt_officers WHERE id = ?', { officerId })
    local dept = (officer and officer[1] and officer[1].department) or 'police'

    local id = MySQL.insert.await('INSERT INTO mdt_cases (case_number, title, description, lead_officer_id, department, priority) VALUES (?, ?, ?, ?, ?, ?)', {
        caseNumber, data.title, data.description or '', officerId, dept, data.priority or 'normal'
    })
    MySQL.insert.await('INSERT INTO mdt_case_personnel (case_id, officer_id, role) VALUES (?, ?, ?)', { id, officerId, 'lead' })

    auditLog(officerId, 'case_create', 'case', 'case', id, { number = caseNumber })
    return { ok = true, caseId = id, caseNumber = caseNumber }
end)

lib.callback.register('cortex_mdt:updateCase', function(source, data)
    if not data or not data.caseId then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.updateCase(data)
        if ok then
            auditLog(officerId, 'case_update', 'case', 'case', data.caseId, nil)
        end
        return { ok = ok }
    end

    MySQL.update.await('UPDATE mdt_cases SET title = ?, description = ?, status = ?, priority = ?, restricted = ? WHERE id = ?', {
        data.title or '', data.description or '', data.status or 'open', data.priority or 'normal', data.restricted and 1 or 0, data.caseId
    })
    auditLog(officerId, 'case_update', 'case', 'case', data.caseId, nil)
    return { ok = true }
end)

lib.callback.register('cortex_mdt:addCaseLink', function(source, data)
    if not data or not data.caseId or not data.entityType or not data.entityId then return { ok = false } end
    local officerId = getOfficerId(source) or 0
    if usesLocalMode() then
        local ok = LocalMode.addCaseLink({
            caseId = data.caseId,
            linkType = data.entityType,
            linkId = data.entityId,
            label = data.label,
        })
        if ok then
            auditLog(officerId, 'case_link_add', 'case', data.entityType, data.entityId, { caseId = data.caseId })
        end
        return { ok = ok }
    end
    MySQL.insert.await('INSERT IGNORE INTO mdt_case_links (case_id, entity_type, entity_id) VALUES (?, ?, ?)', {
        data.caseId, data.entityType, data.entityId
    })
    auditLog(officerId, 'case_link_add', 'case', data.entityType, data.entityId, { caseId = data.caseId })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:removeCaseLink', function(source, data)
    if not data or not data.id then return { ok = false } end
    local officerId = getOfficerId(source) or 0
    if usesLocalMode() then
        local ok = LocalMode.removeCaseLink({ caseId = data.caseId, linkId = data.id })
        if ok then
            auditLog(officerId, 'case_link_remove', 'case', 'case_link', data.id, { caseId = data.caseId })
        end
        return { ok = ok }
    end
    MySQL.update.await('DELETE FROM mdt_case_links WHERE id = ?', { data.id })
    auditLog(officerId, 'case_link_remove', 'case', 'case_link', data.id, { caseId = data.caseId })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:addCasePersonnel', function(source, data)
    if not data or not data.caseId or not data.officerId then return { ok = false } end
    local officerId = getOfficerId(source) or 0
    if usesLocalMode() then
        local ok = LocalMode.addCasePersonnel(data)
        if ok then
            auditLog(officerId, 'case_personnel_add', 'case', 'officer', data.officerId, { caseId = data.caseId, role = data.role })
        end
        return { ok = ok }
    end
    MySQL.insert.await('INSERT IGNORE INTO mdt_case_personnel (case_id, officer_id, role) VALUES (?, ?, ?)', {
        data.caseId, data.officerId, data.role or 'assigned'
    })
    auditLog(officerId, 'case_personnel_add', 'case', 'officer', data.officerId, { caseId = data.caseId, role = data.role })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:removeCasePersonnel', function(source, data)
    if not data or not data.id then return { ok = false } end
    local officerId = getOfficerId(source) or 0
    if usesLocalMode() then
        local ok = LocalMode.removeCasePersonnel({ caseId = data.caseId, officerId = data.officerId, id = data.id })
        if ok then
            auditLog(officerId, 'case_personnel_remove', 'case', 'case_personnel', data.id, { caseId = data.caseId, officerId = data.officerId })
        end
        return { ok = ok }
    end
    MySQL.update.await('DELETE FROM mdt_case_personnel WHERE id = ?', { data.id })
    auditLog(officerId, 'case_personnel_remove', 'case', 'case_personnel', data.id, { caseId = data.caseId, officerId = data.officerId })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:addAttachment', function(source, data)
    if not data or not data.parentType or not data.parentId or not data.fileName or not data.fileUrl then
        return { ok = false, error = 'Missing attachment data.' }
    end

    local officerId = getOfficerId(source) or 0
    if usesLocalMode() then
        local attachmentId = LocalMode.addAttachment(source, data)
        auditLog(officerId, 'attachment_add', 'attachment', data.parentType, data.parentId, { attachmentId = attachmentId })
        return { ok = true, attachmentId = attachmentId }
    end

    local attachmentId = MySQL.insert.await([[
        INSERT INTO mdt_attachments (parent_type, parent_id, file_name, file_url, file_type, uploaded_by, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.parentType,
        data.parentId,
        data.fileName,
        data.fileUrl,
        data.fileType or nil,
        officerId,
        data.notes or nil,
    })

    auditLog(officerId, 'attachment_add', 'attachment', data.parentType, data.parentId, { attachmentId = attachmentId })
    return { ok = true, attachmentId = attachmentId }
end)

lib.callback.register('cortex_mdt:removeAttachment', function(source, data)
    if not data or not data.attachmentId then
        return { ok = false, error = 'Missing attachment id.' }
    end

    local officerId = getOfficerId(source) or 0
    if usesLocalMode() then
        local ok = LocalMode.removeAttachment(data)
        if ok then
            auditLog(officerId, 'attachment_remove', 'attachment', data.parentType or 'attachment', data.attachmentId, nil)
        end
        return { ok = ok }
    end

    MySQL.update.await('DELETE FROM mdt_attachments WHERE id = ?', { data.attachmentId })
    auditLog(officerId, 'attachment_remove', 'attachment', data.parentType or 'attachment', data.attachmentId, nil)
    return { ok = true }
end)

lib.callback.register('cortex_mdt:getEvidence', function(source, data)
    local page = (data and data.page) or 1
    local limit = 20
    local offset = (page - 1) * limit

    if usesLocalMode() then
        local payload = LocalMode.getEvidence(page)
        return { ok = true, evidence = payload.evidence, total = payload.total, page = payload.page }
    end

    local evidence = MySQL.query.await([[
        SELECT e.*, o.first_name as collector_first, o.last_name as collector_last
        FROM mdt_evidence e LEFT JOIN mdt_officers o ON e.collected_by = o.id
        ORDER BY e.created_at DESC LIMIT ? OFFSET ?
    ]], { limit, offset }) or {}

    local countResult = MySQL.query.await('SELECT COUNT(*) as cnt FROM mdt_evidence') or {}
    local total = (countResult[1] and countResult[1].cnt) or 0

    return { ok = true, evidence = evidence, total = total, page = page }
end)

lib.callback.register('cortex_mdt:getEvidenceRecord', function(source, data)
    local evidenceId = data and data.evidenceId
    if not evidenceId then return { ok = false } end

    local officerId = getOfficerId(source) or 0
    auditLog(officerId, 'evidence_view', 'evidence', 'evidence', evidenceId, nil)

    if usesLocalMode() then
        local payload = LocalMode.getEvidenceRecord(evidenceId)
        if not payload then return { ok = false } end
        return { ok = true, evidence = payload.evidence, custody = payload.custody, attachments = payload.attachments }
    end

    local evidence = MySQL.query.await([[
        SELECT e.*, o.first_name as collector_first, o.last_name as collector_last
        FROM mdt_evidence e LEFT JOIN mdt_officers o ON e.collected_by = o.id
        WHERE e.id = ?
    ]], { evidenceId })
    if not evidence or not evidence[1] then return { ok = false } end

    local custody = MySQL.query.await([[
        SELECT ec.*, fo.first_name as from_first, fo.last_name as from_last,
            too.first_name as to_first, too.last_name as to_last
        FROM mdt_evidence_custody ec
        LEFT JOIN mdt_officers fo ON ec.from_officer = fo.id
        LEFT JOIN mdt_officers too ON ec.to_officer = too.id
        WHERE ec.evidence_id = ? ORDER BY ec.created_at ASC
    ]], { evidenceId }) or {}

    local attachments = fetchAttachments('evidence', evidenceId)

    return { ok = true, evidence = evidence[1], custody = custody, attachments = attachments }
end)

lib.callback.register('cortex_mdt:createEvidence', function(source, data)
    if not data or not data.description then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local id, evidenceTag = LocalMode.createEvidence(source, data)
        auditLog(officerId, 'evidence_create', 'evidence', 'evidence', id, { tag = evidenceTag })
        return { ok = true, evidenceId = id, evidenceTag = evidenceTag }
    end

    local prefix = getSetting('evidence_prefix') or 'EV'
    local evidenceTag = generateNumber(prefix)

    local id = MySQL.insert.await('INSERT INTO mdt_evidence (evidence_id, type, serial_number, description, photo_url, stash_location, collected_by, report_id, case_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        evidenceTag, data.type or 'general', data.serialNumber or nil, data.description, data.photoUrl or nil, data.stashLocation or nil, officerId, data.reportId or nil, data.caseId or nil
    })

    MySQL.insert.await('INSERT INTO mdt_evidence_custody (evidence_id, action, to_officer, to_location, notes) VALUES (?, ?, ?, ?, ?)', {
        id, 'Collected', officerId, data.stashLocation or 'N/A', 'Initial collection'
    })

    auditLog(officerId, 'evidence_create', 'evidence', 'evidence', id, { tag = evidenceTag })
    return { ok = true, evidenceId = id, evidenceTag = evidenceTag }
end)

lib.callback.register('cortex_mdt:updateEvidence', function(source, data)
    if not data or not data.evidenceId then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.updateEvidence(source, data)
        if ok then
            auditLog(officerId, 'evidence_update', 'evidence', 'evidence', data.evidenceId, nil)
        end
        return { ok = ok }
    end

    MySQL.update.await([[
        UPDATE mdt_evidence
        SET type = ?, serial_number = ?, description = ?, photo_url = ?, stash_location = ?, report_id = ?, case_id = ?, status = ?
        WHERE id = ?
    ]], {
        data.type or 'general',
        data.serialNumber or nil,
        data.description or '',
        data.photoUrl or nil,
        data.stashLocation or nil,
        data.reportId or nil,
        data.caseId or nil,
        data.status or 'in_custody',
        data.evidenceId,
    })

    auditLog(officerId, 'evidence_update', 'evidence', 'evidence', data.evidenceId, nil)
    return { ok = true }
end)

lib.callback.register('cortex_mdt:transferEvidence', function(source, data)
    if not data or not data.evidenceId then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.transferEvidence(source, data)
        if ok then
            auditLog(officerId, 'evidence_transfer', 'evidence', 'evidence', data.evidenceId, { toLocation = data.toLocation })
        end
        return { ok = ok }
    end

    MySQL.insert.await('INSERT INTO mdt_evidence_custody (evidence_id, action, from_officer, to_officer, from_location, to_location, notes) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        data.evidenceId, 'Transfer', data.fromOfficer or officerId, data.toOfficer or officerId,
        data.fromLocation or '', data.toLocation or '', data.notes or ''
    })

    if data.newStatus then
        MySQL.update.await('UPDATE mdt_evidence SET status = ?, stash_location = ? WHERE id = ?', {
            data.newStatus, data.toLocation or nil, data.evidenceId
        })
    end

    auditLog(officerId, 'evidence_transfer', 'evidence', 'evidence', data.evidenceId, { toLocation = data.toLocation })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:getBolos', function(source, data)
    local filter = data and data.filter or 'active'
    local where = filter == 'all' and '' or ' WHERE b.status = "active"'

    if usesLocalMode() then
        return { ok = true, bolos = LocalMode.getBolos(filter == 'all' and '' or filter) }
    end

    local bolos = MySQL.query.await(([[
        SELECT b.*, o.first_name as officer_first, o.last_name as officer_last
        FROM mdt_bolos b LEFT JOIN mdt_officers o ON b.issued_by = o.id
        %s ORDER BY b.created_at DESC LIMIT 50
    ]]):format(where)) or {}

    return { ok = true, bolos = bolos }
end)

lib.callback.register('cortex_mdt:createBolo', function(source, data)
    if not data or not data.title then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local id = LocalMode.createBolo(source, data)
        auditLog(officerId, 'bolo_create', 'bolo', 'bolo', id, nil)
        return { ok = true, boloId = id }
    end

    local officer = MySQL.query.await('SELECT department FROM mdt_officers WHERE id = ?', { officerId })
    local dept = (officer and officer[1] and officer[1].department) or 'police'

    local id = MySQL.insert.await('INSERT INTO mdt_bolos (type, title, description, citizen_id, plate, vehicle_description, weapon_description, photo_url, issued_by, department, report_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.type or 'person', data.title, data.description or '', data.citizenId or nil,
        data.plate or nil, data.vehicleDescription or nil, data.weaponDescription or nil,
        data.photoUrl or nil, officerId, dept, data.reportId or nil
    })

    auditLog(officerId, 'bolo_create', 'bolo', 'bolo', id, nil)
    return { ok = true, boloId = id }
end)

lib.callback.register('cortex_mdt:updateBoloStatus', function(source, data)
    if not data or not data.boloId or not data.status then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.updateBoloStatus(data)
        if ok then
            auditLog(officerId, 'bolo_status', 'bolo', 'bolo', data.boloId, { status = data.status })
        end
        return { ok = ok }
    end

    MySQL.update.await('UPDATE mdt_bolos SET status = ? WHERE id = ?', { data.status, data.boloId })
    auditLog(officerId, 'bolo_status', 'bolo', 'bolo', data.boloId, { status = data.status })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:getWarrants', function(source, data)
    local filter = data and data.filter or 'active'
    local where = filter == 'all' and '' or ' WHERE w.status = "active"'

    if usesLocalMode() then
        return { ok = true, warrants = LocalMode.getWarrants(filter == 'all' and '' or filter) }
    end

    local warrants = MySQL.query.await(([[
        SELECT w.*, o.first_name as officer_first, o.last_name as officer_last
        FROM mdt_warrants w LEFT JOIN mdt_officers o ON w.issued_by = o.id
        %s ORDER BY w.created_at DESC LIMIT 50
    ]]):format(where)) or {}

    for i = 1, #warrants do
        warrants[i].charges = json.decode(warrants[i].charges) or {}
    end

    return { ok = true, warrants = warrants }
end)

lib.callback.register('cortex_mdt:createWarrant', function(source, data)
    if not data or not data.citizenId or not data.citizenName then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local id = LocalMode.createWarrant(source, data)
        auditLog(officerId, 'warrant_create', 'warrant', 'warrant', id, nil)
        return { ok = true, warrantId = id }
    end

    local officer = MySQL.query.await('SELECT department FROM mdt_officers WHERE id = ?', { officerId })
    local dept = (officer and officer[1] and officer[1].department) or 'police'

    local id = MySQL.insert.await('INSERT INTO mdt_warrants (citizen_id, citizen_name, charges, description, issued_by, department, report_id, bolo_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        data.citizenId, data.citizenName, json.encode(data.charges or {}), data.description or '',
        officerId, dept, data.reportId or nil, data.boloId or nil
    })

    auditLog(officerId, 'warrant_create', 'warrant', 'warrant', id, nil)
    return { ok = true, warrantId = id }
end)

lib.callback.register('cortex_mdt:updateWarrantStatus', function(source, data)
    if not data or not data.warrantId or not data.status then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.updateWarrantStatus(source, data)
        if ok then
            auditLog(officerId, 'warrant_status', 'warrant', 'warrant', data.warrantId, { status = data.status })
        end
        return { ok = ok }
    end

    if data.status == 'served' then
        MySQL.update.await('UPDATE mdt_warrants SET status = ?, served_by = ?, served_at = NOW() WHERE id = ?', {
            data.status,
            officerId > 0 and officerId or nil,
            data.warrantId,
        })
    else
        MySQL.update.await('UPDATE mdt_warrants SET status = ?, served_by = NULL, served_at = NULL WHERE id = ?', {
            data.status,
            data.warrantId,
        })
    end
    auditLog(officerId, 'warrant_status', 'warrant', 'warrant', data.warrantId, { status = data.status })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:getWeapons', function(source, data)
    local filter = tostring(data and data.filter or '')
    local pattern = ('%%%s%%'):format(filter)
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        auditLog(officerId, 'weapon_search', 'weapon', 'weapon', nil, { filter = filter })
        return { ok = true, weapons = LocalMode.getWeapons(filter) }
    end

    local query = [[
        SELECT
            id,
            serial_number,
            owner_citizen_id,
            owner_name,
            weapon_type,
            make,
            model,
            caliber,
            status,
            image_url AS photo_url,
            image_url,
            notes,
            created_at,
            updated_at
        FROM mdt_weapons
    ]]

    local weapons
    if filter ~= '' then
        weapons = MySQL.query.await(query .. [[
            WHERE serial_number LIKE ?
               OR owner_citizen_id LIKE ?
               OR owner_name LIKE ?
               OR weapon_type LIKE ?
               OR make LIKE ?
               OR model LIKE ?
            ORDER BY updated_at DESC
            LIMIT 100
        ]], { pattern, pattern, pattern, pattern, pattern, pattern }) or {}
    else
        weapons = MySQL.query.await(query .. ' ORDER BY updated_at DESC LIMIT 100') or {}
    end

    auditLog(officerId, 'weapon_search', 'weapon', 'weapon', nil, { filter = filter })
    return { ok = true, weapons = weapons }
end)

lib.callback.register('cortex_mdt:searchWeapons', function(source, data)
    local query = tostring(data and data.query or '')
    local pattern = ('%%%s%%'):format(query)
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        auditLog(officerId, 'weapon_search', 'weapon', 'weapon', nil, { filter = query })
        return { ok = true, weapons = LocalMode.getWeapons(query) }
    end

    local weapons
    if query ~= '' then
        weapons = MySQL.query.await([[
            SELECT
                id,
                serial_number,
                owner_citizen_id,
                owner_name,
                weapon_type,
                make,
                model,
                caliber,
                status,
                image_url AS photo_url,
                image_url,
                notes,
                created_at,
                updated_at
            FROM mdt_weapons
            WHERE serial_number LIKE ?
               OR owner_citizen_id LIKE ?
               OR owner_name LIKE ?
               OR weapon_type LIKE ?
               OR make LIKE ?
               OR model LIKE ?
            ORDER BY updated_at DESC
            LIMIT 100
        ]], { pattern, pattern, pattern, pattern, pattern, pattern }) or {}
    else
        weapons = MySQL.query.await([[
            SELECT
                id,
                serial_number,
                owner_citizen_id,
                owner_name,
                weapon_type,
                make,
                model,
                caliber,
                status,
                image_url AS photo_url,
                image_url,
                notes,
                created_at,
                updated_at
            FROM mdt_weapons
            ORDER BY updated_at DESC
            LIMIT 100
        ]]) or {}
    end

    auditLog(officerId, 'weapon_search', 'weapon', 'weapon', nil, { filter = query })
    return { ok = true, weapons = weapons }
end)

lib.callback.register('cortex_mdt:getWeaponRecord', function(source, data)
    if not data or not data.weaponId then
        return { ok = false }
    end

    local officerId = getOfficerId(source) or 0
    if usesLocalMode() then
        local payload = LocalMode.getWeaponRecord(data.weaponId)
        if not payload then
            return { ok = false, error = 'Weapon not found.' }
        end
        auditLog(officerId, 'weapon_view', 'weapon', 'weapon', data.weaponId, nil)
        return { ok = true, weapon = payload.weapon, history = payload.history }
    end

    local weapon = MySQL.query.await([[
        SELECT
            *,
            image_url AS photo_url
        FROM mdt_weapons
        WHERE id = ? LIMIT 1
    ]], { data.weaponId }) or {}
    if not weapon[1] then
        return { ok = false, error = 'Weapon not found.' }
    end

    local history = MySQL.query.await([[
        SELECT wh.*, o.first_name, o.last_name, o.callsign
        FROM mdt_weapon_history wh
        LEFT JOIN mdt_officers o ON o.id = wh.officer_id
        WHERE wh.weapon_id = ?
        ORDER BY wh.created_at DESC
    ]], { data.weaponId }) or {}

    auditLog(officerId, 'weapon_view', 'weapon', 'weapon', data.weaponId, nil)
    return { ok = true, weapon = weapon[1], history = history }
end)

lib.callback.register('cortex_mdt:getWeapon', function(source, data)
    if not data or not data.weaponId then
        return { ok = false }
    end

    local officerId = getOfficerId(source) or 0
    if usesLocalMode() then
        local payload = LocalMode.getWeaponRecord(data.weaponId)
        if not payload then
            return { ok = false, error = 'Weapon not found.' }
        end
        auditLog(officerId, 'weapon_view', 'weapon', 'weapon', data.weaponId, nil)
        return { ok = true, weapon = payload.weapon, history = payload.history }
    end

    local weapon = MySQL.query.await([[
        SELECT
            *,
            image_url AS photo_url
        FROM mdt_weapons
        WHERE id = ? LIMIT 1
    ]], { data.weaponId }) or {}
    if not weapon[1] then
        return { ok = false, error = 'Weapon not found.' }
    end

    local history = MySQL.query.await([[
        SELECT wh.*, o.first_name, o.last_name, o.callsign
        FROM mdt_weapon_history wh
        LEFT JOIN mdt_officers o ON o.id = wh.officer_id
        WHERE wh.weapon_id = ?
        ORDER BY wh.created_at DESC
    ]], { data.weaponId }) or {}

    auditLog(officerId, 'weapon_view', 'weapon', 'weapon', data.weaponId, nil)
    return { ok = true, weapon = weapon[1], history = history }
end)

lib.callback.register('cortex_mdt:createWeapon', function(source, data)
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        if not data then
            return { ok = false, error = 'Weapon data is required.' }
        end
        local weaponId, serialNumber = LocalMode.createWeapon(source, data)
        auditLog(officerId, 'weapon_create', 'weapon', 'weapon', weaponId, { serialNumber = serialNumber })
        return { ok = true, weaponId = weaponId }
    end

    if not data or not data.serialNumber then
        return { ok = false, error = 'Serial number is required.' }
    end

    local serialNumber = tostring(data.serialNumber or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if serialNumber == '' then
        return { ok = false, error = 'Serial number is required.' }
    end

    local ownerCitizenId = (data.ownerCitizenId and tostring(data.ownerCitizenId) ~= '') and data.ownerCitizenId or nil
    local ownerName = (data.ownerName and tostring(data.ownerName) ~= '') and data.ownerName or fetchCitizenDisplayName(ownerCitizenId)
    local weaponId = MySQL.insert.await([[
        INSERT INTO mdt_weapons (serial_number, owner_citizen_id, owner_name, weapon_type, make, model, caliber, status, notes, image_url, registered_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        serialNumber,
        ownerCitizenId,
        ownerName,
        (data.weaponType and data.weaponType ~= '') and data.weaponType or nil,
        (data.make and data.make ~= '') and data.make or nil,
        (data.model and data.model ~= '') and data.model or nil,
        (data.caliber and data.caliber ~= '') and data.caliber or nil,
        data.status or 'registered',
        data.notes or nil,
        data.photoUrl or data.imageUrl or nil,
        officerId,
    })

    MySQL.insert.await([[
        INSERT INTO mdt_weapon_history (weapon_id, action, from_owner_citizen_id, to_owner_citizen_id, officer_id, notes)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        weaponId,
        'registered',
        nil,
        ownerCitizenId,
        officerId,
        data.notes or nil,
    })

    auditLog(officerId, 'weapon_create', 'weapon', 'weapon', weaponId, { serialNumber = serialNumber })
    return { ok = true, weaponId = weaponId }
end)

lib.callback.register('cortex_mdt:updateWeapon', function(source, data)
    if not data or not data.weaponId then
        return { ok = false, error = 'Weapon id is required.' }
    end

    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.updateWeapon(source, data)
        if ok then
            auditLog(officerId, 'weapon_update', 'weapon', 'weapon', data.weaponId, { status = data.status })
        end
        return { ok = ok, error = ok and nil or 'Weapon not found.' }
    end
    local current = MySQL.query.await('SELECT * FROM mdt_weapons WHERE id = ? LIMIT 1', { data.weaponId }) or {}
    if not current[1] then
        return { ok = false, error = 'Weapon not found.' }
    end

    local row = current[1]
    MySQL.update.await([[
        UPDATE mdt_weapons
        SET owner_citizen_id = ?, owner_name = ?, weapon_type = ?, make = ?, model = ?, caliber = ?, status = ?, notes = ?, image_url = ?
        WHERE id = ?
    ]], {
        data.ownerCitizenId ~= nil and data.ownerCitizenId or row.owner_citizen_id,
        data.ownerName ~= nil and data.ownerName or row.owner_name,
        data.weaponType ~= nil and data.weaponType or row.weapon_type,
        data.make ~= nil and data.make or row.make,
        data.model ~= nil and data.model or row.model,
        data.caliber ~= nil and data.caliber or row.caliber,
        data.status ~= nil and data.status or row.status,
        data.notes ~= nil and data.notes or row.notes,
        data.photoUrl ~= nil and data.photoUrl or data.imageUrl ~= nil and data.imageUrl or row.image_url,
        data.weaponId,
    })

    MySQL.insert.await([[
        INSERT INTO mdt_weapon_history (weapon_id, action, from_owner_citizen_id, to_owner_citizen_id, officer_id, notes)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        data.weaponId,
        'updated',
        row.owner_citizen_id,
        data.ownerCitizenId ~= nil and data.ownerCitizenId or row.owner_citizen_id,
        officerId,
        data.notes or 'Registry record updated.',
    })

    auditLog(officerId, 'weapon_update', 'weapon', 'weapon', data.weaponId, { status = data.status or row.status })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:transferWeapon', function(source, data)
    if not data or not data.weaponId then
        return { ok = false, error = 'Weapon id is required.' }
    end

    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.transferWeapon(source, data)
        if ok then
            auditLog(officerId, 'weapon_transfer', 'weapon', 'weapon', data.weaponId, { to = data.toCitizenId or data.ownerCitizenId })
        end
        return { ok = ok, error = ok and nil or 'Weapon not found.' }
    end
    local current = MySQL.query.await('SELECT * FROM mdt_weapons WHERE id = ? LIMIT 1', { data.weaponId }) or {}
    if not current[1] then
        return { ok = false, error = 'Weapon not found.' }
    end

    local row = current[1]
    local nextOwnerCitizenId = data.toCitizenId or data.ownerCitizenId or nil
    local nextOwnerName = data.toOwnerName or data.ownerName or fetchCitizenDisplayName(nextOwnerCitizenId)
    local nextStatus = data.status or (nextOwnerCitizenId and 'transferred' or 'evidence')

    MySQL.update.await('UPDATE mdt_weapons SET owner_citizen_id = ?, owner_name = ?, status = ? WHERE id = ?', {
        nextOwnerCitizenId,
        nextOwnerName,
        nextStatus,
        data.weaponId,
    })

    MySQL.insert.await([[
        INSERT INTO mdt_weapon_history (weapon_id, action, from_owner_citizen_id, to_owner_citizen_id, officer_id, notes)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        data.weaponId,
        data.action or 'transfer',
        row.owner_citizen_id,
        nextOwnerCitizenId,
        officerId,
        data.notes or nil,
    })

    auditLog(officerId, 'weapon_transfer', 'weapon', 'weapon', data.weaponId, { to = nextOwnerCitizenId })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:getWeaponAnalytics', function(source)
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        auditLog(officerId, 'weapon_analytics', 'analytics', 'weapon', nil, nil)
        return { ok = true, analytics = LocalMode.getWeaponAnalytics() }
    end
    local counts = MySQL.query.await([[
        SELECT status, COUNT(*) AS total
        FROM mdt_weapons
        GROUP BY status
    ]]) or {}
    local transferCount = MySQL.query.await([[
        SELECT COUNT(*) AS total
        FROM mdt_weapon_history
        WHERE action = 'transfer'
          AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ]]) or {}

    local analytics = {
        total = 0,
        registered = 0,
        transferred = 0,
        seized = 0,
        evidence = 0,
        stolen = 0,
        destroyed = 0,
        recentTransfers = (transferCount[1] and transferCount[1].total) or 0,
    }

    for i = 1, #counts do
        local status = tostring(counts[i].status or '')
        local total = tonumber(counts[i].total or 0) or 0
        analytics.total = analytics.total + total
        if analytics[status] ~= nil then
            analytics[status] = total
        end
    end

    auditLog(officerId, 'weapon_analytics', 'analytics', 'weapon', nil, nil)
    return { ok = true, analytics = analytics }
end)

lib.callback.register('cortex_mdt:getLeaderboard', function(source, data)
    local officerId = getOfficerId(source) or 0
    local period = tostring(data and data.period or 'week')
    local reportWindow = period == 'month' and 30 or period == 'week' and 7 or nil

    if usesLocalMode() then
        auditLog(officerId, 'leaderboard_view', 'analytics', 'leaderboard', nil, { period = period })
        return { ok = true, leaderboard = LocalMode.getLeaderboard(period) }
    end

    local reportFilter = reportWindow and ('WHERE status != \'draft\' AND created_at >= DATE_SUB(NOW(), INTERVAL %d DAY)'):format(reportWindow) or 'WHERE status != \'draft\''
    local arrestFilter = reportWindow and ('WHERE (LOWER(COALESCE(re.role, \'\')) IN (\'arrested\', \'suspect\', \'detained\', \'offender\')) AND r.created_at >= DATE_SUB(NOW(), INTERVAL %d DAY)'):format(reportWindow) or 'WHERE LOWER(COALESCE(re.role, \'\')) IN (\'arrested\', \'suspect\', \'detained\', \'offender\')'
    local caseFilter = reportWindow and ('WHERE created_at >= DATE_SUB(NOW(), INTERVAL %d DAY)'):format(reportWindow) or ''

    local leaders = MySQL.query.await(([[
        SELECT
            o.id AS officer_id,
            o.first_name,
            o.last_name,
            o.callsign,
            o.`rank`,
            o.department,
            o.avatar,
            CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, '')) AS name,
            COALESCE(rc.report_count, 0) AS reports_count,
            COALESCE(ac.arrest_count, 0) AS arrests_count,
            COALESCE(cc.case_count, 0) AS cases_count,
            0 AS activity_score
        FROM mdt_officers o
        LEFT JOIN (
            SELECT author_id, COUNT(*) AS report_count
            FROM mdt_reports
            %s
            GROUP BY author_id
        ) rc ON rc.author_id = o.id
        LEFT JOIN (
            SELECT r.author_id, COUNT(DISTINCT r.id) AS arrest_count
            FROM mdt_reports r
            LEFT JOIN mdt_report_entities re ON re.report_id = r.id AND re.entity_type = 'citizen'
            %s
            GROUP BY r.author_id
        ) ac ON ac.author_id = o.id
        LEFT JOIN (
            SELECT lead_officer_id, COUNT(*) AS case_count
            FROM mdt_cases
            %s
            GROUP BY lead_officer_id
        ) cc ON cc.lead_officer_id = o.id
        ORDER BY activity_score DESC, reports_count DESC, arrests_count DESC, last_name ASC
    ]]):format(reportFilter, arrestFilter, caseFilter)) or {}

    local activityCounts = Audit.countByOfficer(reportWindow or 30)
    for i = 1, #leaders do
        leaders[i].activity_score = activityCounts[tonumber(leaders[i].officer_id)] or 0
    end

    local summary = {
        totalOfficers = #leaders,
        totalReports = 0,
        totalArrests = 0,
        averageActivity = 0,
        generatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
    local totalActivity = 0

    for i = 1, #leaders do
        summary.totalReports = summary.totalReports + (leaders[i].reports_count or 0)
        summary.totalArrests = summary.totalArrests + (leaders[i].arrests_count or 0)
        totalActivity = totalActivity + (leaders[i].activity_score or 0)
    end

    if #leaders > 0 then
        summary.averageActivity = math.floor((totalActivity / #leaders) + 0.5)
    end

    local function topBy(field)
        local rows = {}
        for i = 1, #leaders do
            rows[i] = leaders[i]
        end
        table.sort(rows, function(left, right)
            local leftValue = tonumber(left[field] or 0) or 0
            local rightValue = tonumber(right[field] or 0) or 0
            if leftValue == rightValue then
                return tostring(left.last_name or '') < tostring(right.last_name or '')
            end
            return leftValue > rightValue
        end)
        while #rows > 10 do
            table.remove(rows)
        end
        return rows
    end

    auditLog(officerId, 'leaderboard_view', 'analytics', 'leaderboard', nil, { period = period })
    return {
        ok = true,
        leaderboard = {
            period = period,
            generatedAt = summary.generatedAt,
            summary = summary,
            categories = {
                activity = topBy('activity_score'),
                reports = topBy('reports_count'),
                arrests = topBy('arrests_count'),
            },
        },
    }
end)

lib.callback.register('cortex_mdt:getUnits', function(source)
    local function attachLiveTelemetry(rows)
        local merge = CortexMdtMergeLiveUnitTelemetry
        if type(merge) ~= 'function' then
            return
        end
        for i = 1, #rows do
            merge(rows[i])
        end
    end

    if usesLocalMode() then
        local units = LocalMode.getUnits()
        attachLiveTelemetry(units)
        return { ok = true, units = units }
    end

    local units = MySQL.query.await([[
        SELECT u.*, o.first_name, o.last_name, o.`rank`, o.department as dept, o.avatar
        FROM mdt_units u LEFT JOIN mdt_officers o ON u.officer_id = o.id
        ORDER BY u.department ASC, u.callsign ASC
    ]]) or {}

    for i = 1, #units do
        units[i] = normalizeUnitRow(units[i])
        units[i].source = findOfficerSource(units[i].officer_id)
    end

    attachLiveTelemetry(units)

    return { ok = true, units = units }
end)

lib.callback.register('cortex_mdt:updateUnitStatus', function(source, data)
    if not data or not data.status then return { ok = false, error = 'Missing duty status.' } end
    local officerId = ensureOfficerRecordForSource(source) or 0
    if officerId == 0 then return { ok = false, error = 'Officer record not found.' } end

    local nextStatus = normalizeUnitStatus(data.status, '__invalid__')
    if not VALID_UNIT_STATUSES[nextStatus] then
        return { ok = false, error = 'Invalid duty status.' }
    end

    local nextAssignment = data.assignment

    if nextStatus == 'off_duty' then
        local response = goOfficerOffDuty(source, officerId)
        if response and response.ok then
            auditLog(officerId, 'unit_status_update', 'unit', 'officer', officerId, { status = 'off_duty' })
        end
        return response
    end

    local existing = getOfficerUnitRow(officerId)
    if not existing or not isOnDutyStatus(existing.status) then
        local onDutyResponse = goOfficerOnDuty(source, officerId, {
            status = nextStatus,
            assignment = nextAssignment,
        })

        if onDutyResponse.ok == true then
            auditLog(officerId, 'unit_status_update', 'unit', 'officer', officerId, { status = nextStatus, assignment = nextAssignment })
            return onDutyResponse
        end

        return onDutyResponse
    end

    local response = setOfficerUnitState(source, officerId, nextStatus, nextAssignment)
    if response and response.ok then
        auditLog(officerId, 'unit_status_update', 'unit', 'officer', officerId, { status = nextStatus, assignment = nextAssignment })
    end
    return response
end)

lib.callback.register('cortex_mdt:goOnDuty', function(source, data)
    local officerId = ensureOfficerRecordForSource(source, type(data) == 'table' and {
        firstName = data.firstName,
        lastName = data.lastName,
        callsign = data.callsign,
        rank = data.rank,
        departmentKey = data.departmentKey or data.department,
        useFrameworkDisplayName = data.useFrameworkDisplayName,
    } or nil)
    if not officerId then
        return { ok = false, error = 'Officer record not found.' }
    end

    local existing = getOfficerUnitRow(officerId)
    local assignment = existing and existing.assignment or nil

    local response = goOfficerOnDuty(source, officerId, {
        status = 'available',
        assignment = assignment,
    })
    if response and response.ok then
        auditLog(officerId, 'duty_on', 'unit', 'officer', officerId, nil)
    end
    return response
end)

lib.callback.register('cortex_mdt:goOffDuty', function(source)
    local officerId = ensureOfficerRecordForSource(source)
    if not officerId then
        return { ok = false, error = 'Officer record not found.' }
    end

    local response = goOfficerOffDuty(source, officerId)
    if response and response.ok then
        auditLog(officerId, 'duty_off', 'unit', 'officer', officerId, nil)
    end
    return response
end)

_G.CortexMdtUnitsBridge = {
    getDispatchUnits = getDispatchUnitsSnapshot,
    isSourceOnDuty = isSourceMarkedOnDuty,
    normalizeUnitStatus = normalizeUnitStatus,
}

lib.callback.register('cortex_mdt:getRoster', function(source)
    if usesLocalMode() then
        return { ok = true, officers = LocalMode.getRoster() }
    end

    local officers = MySQL.query.await('SELECT * FROM mdt_officers ORDER BY department ASC, `rank` ASC, last_name ASC') or {}
    for i = 1, #officers do
        officers[i].certifications = json.decode(officers[i].certifications) or {}
    end
    return { ok = true, officers = officers }
end)

lib.callback.register('cortex_mdt:updateOfficerAdmin', function(source, data)
    if not data or not data.officerId then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        local ok = LocalMode.updateOfficerAdmin(data)
        if ok then
            auditLog(officerId, 'roster_update', 'admin', 'officer', data.officerId, { rank = data.rank, dept = data.department })
            return { ok = true }
        end

        return { ok = false, error = 'Officer record not found.' }
    end

    MySQL.update.await('UPDATE mdt_officers SET `rank` = ?, callsign = ?, department = ?, certifications = ?, status = ? WHERE id = ?', {
        data.rank or 'Officer', data.callsign or '', data.department or 'police',
        json.encode(data.certifications or {}), data.status or 'active', data.officerId
    })
    auditLog(officerId, 'roster_update', 'admin', 'officer', data.officerId, { rank = data.rank, dept = data.department })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:getAuditLogs', function(source, data)
    local page = (data and data.page) or 1
    local filter = data and data.filter or ''
    auditLog(getOfficerId(source) or 0, 'audit_logs_view', 'admin', 'audit', nil, { page = page, filter = filter })

    return { ok = true, logs = Audit.getLogs(page, filter, 50), page = page }
end)

lib.callback.register('cortex_mdt:getAnnouncements', function(source)
    if usesLocalMode() then
        return { ok = true, announcements = LocalMode.getAnnouncements() }
    end

    local announcements = MySQL.query.await([[
        SELECT a.*, CONCAT(o.first_name, ' ', o.last_name) as author
        FROM mdt_announcements a LEFT JOIN mdt_officers o ON a.author_id = o.id
        WHERE a.active = 1 ORDER BY a.pinned DESC, a.created_at DESC
    ]]) or {}
    return { ok = true, announcements = announcements }
end)

lib.callback.register('cortex_mdt:createAnnouncement', function(source, data)
    if not data or not data.title or not data.content then return { ok = false } end
    local officerId = ensureOfficerRecordForSource(source) or getOfficerId(source) or 0

    if usesLocalMode() then
        local announcement = LocalMode.createAnnouncement(source, data)
        auditLog(officerId, 'announcement_create', 'admin', 'announcement', announcement and announcement.id or nil, {
            title = data.title,
        })
        return { ok = announcement ~= nil, announcement = announcement }
    end

    local id = MySQL.insert.await('INSERT INTO mdt_announcements (title, content, author_id, department, pinned) VALUES (?, ?, ?, ?, ?)', {
        data.title, data.content, officerId, data.department or nil, data.pinned and 1 or 0
    })
    auditLog(officerId, 'announcement_create', 'admin', 'announcement', id, { title = data.title })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:deleteAnnouncement', function(source, data)
    if not data or not data.id then return { ok = false } end

    if usesLocalMode() then
        local officerId = getOfficerId(source) or 0
        local ok = LocalMode.deleteAnnouncement(data.id)
        if ok then
            auditLog(officerId, 'announcement_delete', 'admin', 'announcement', data.id, nil)
        end
        return { ok = ok }
    end

    MySQL.update.await('UPDATE mdt_announcements SET active = 0 WHERE id = ?', { data.id })
    auditLog(getOfficerId(source) or 0, 'announcement_delete', 'admin', 'announcement', data.id, nil)
    return { ok = true }
end)

lib.callback.register('cortex_mdt:getCharges', function(source)
    return {
        ok = true,
        charges = buildChargeList(),
    }
end)

lib.callback.register('cortex_mdt:updateCharge', function(source, data)
    if type(data) ~= 'table' then
        return { ok = false, error = 'Invalid charge payload.' }
    end

    local updatedCharge, err = updateStoredCharge(data)
    if not updatedCharge then
        return { ok = false, error = err or 'Unable to update charge.' }
    end

    auditLog(getOfficerId(source) or 0, 'charge_update', 'admin', 'charge', updatedCharge.id, {
        fine = updatedCharge.fine,
        jailTime = updatedCharge.jailTime,
        maxJail = updatedCharge.maxJail,
    })

    return {
        ok = true,
        charge = updatedCharge,
        charges = buildChargeList(),
    }
end)

lib.callback.register('cortex_mdt:getSettings', function(source)
    if usesLocalMode() then
        return { ok = true, settings = { motd = LocalMode.getSetting('motd') or '' } }
    end

    local settings = MySQL.query.await('SELECT * FROM mdt_settings') or {}
    local result = {}
    for i = 1, #settings do
        result[settings[i].key] = settings[i].value
    end
    return { ok = true, settings = result }
end)

lib.callback.register('cortex_mdt:updateSetting', function(source, data)
    if not data or not data.key or data.value == nil then return { ok = false } end
    local officerId = getOfficerId(source) or 0

    if usesLocalMode() then
        LocalMode.updateSetting(data.key, data.value)
        auditLog(officerId, 'setting_update', 'admin', 'setting', nil, { key = data.key })
        return { ok = true }
    end

    MySQL.query.await('INSERT INTO mdt_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = ?', {
        data.key, data.value, data.value
    })
    auditLog(officerId, 'setting_update', 'admin', 'setting', nil, { key = data.key })
    return { ok = true }
end)

lib.callback.register('cortex_mdt:saveOfficerAvatar', function(source, data)
    if not data then return { ok = false } end

    if usesLocalMode() then
        LocalMode.saveOfficerAvatar(source, data.avatarUrl)
        auditLog(getOfficerId(source) or 0, 'officer_avatar_update', 'officer', 'officer', getOfficerId(source), nil)
        return { ok = true }
    end

    local officerId = getOfficerId(source) or 0
    if officerId == 0 then return { ok = false } end

    MySQL.update.await('UPDATE mdt_officers SET avatar = ? WHERE id = ?', { data.avatarUrl or nil, officerId })
    auditLog(officerId, 'officer_avatar_update', 'officer', 'officer', officerId, nil)
    return { ok = true }
end)

lib.callback.register('cortex_mdt:searchOfficers', function(source, data)
    local query = data and data.query or ''
    if #query < 1 then return { ok = true, officers = {} } end
    auditLog(getOfficerId(source) or 0, 'officer_search', 'search', 'officer', nil, { query = query })

    if usesLocalMode() then
        local pattern = query:lower()
        local officers = {}
        local roster = LocalMode.getRoster()

        for i = 1, #roster do
            local officer = roster[i]
            local haystack = ('%s %s %s'):format(
                tostring(officer.first_name or ''),
                tostring(officer.last_name or ''),
                tostring(officer.callsign or '')
            ):lower()

            if haystack:find(pattern, 1, true) then
                officers[#officers + 1] = {
                    id = officer.id,
                    first_name = officer.first_name,
                    last_name = officer.last_name,
                    callsign = officer.callsign,
                    rank = officer.rank,
                    department = officer.department,
                }
            end

            if #officers >= 10 then
                break
            end
        end

        return { ok = true, officers = officers }
    end

    local pattern = '%' .. query .. '%'
    local officers = MySQL.query.await('SELECT id, first_name, last_name, callsign, `rank`, department FROM mdt_officers WHERE first_name LIKE ? OR last_name LIKE ? OR callsign LIKE ? LIMIT 10', { pattern, pattern, pattern }) or {}
    return { ok = true, officers = officers }
end)

lib.callback.register('cortex_mdt:sendDashboardChat', function(source, data)
    local message = type(data) == 'table' and tostring(data.message or '') or ''
    message = message:gsub('^%s+', ''):gsub('%s+$', '')

    if message == '' then
        return { ok = false, error = 'Message cannot be empty.' }
    end

    if #message > 280 then
        message = message:sub(1, 280)
    end

    if usesLocalMode() then
        local officerId = ensureOfficerRecordForSource(source) or 0
        local chatMessage = LocalMode.addChatMessage(source, message)
        auditLog(officerId, 'dashboard_chat', 'communication', 'chat', chatMessage and chatMessage.id or nil, nil)
        return { ok = chatMessage ~= nil, message = chatMessage }
    end

    local officerId = ensureOfficerRecordForSource(source) or 0
    local profile = getBridgeOfficerProfile(source) or {}
    local rank = tostring(profile.rank or 'Officer')

    if #rank > 4 then
        rank = rank:sub(1, 4) .. '.'
    end

    auditLog(officerId, 'dashboard_chat', 'communication', 'chat', nil, nil)

    return {
        ok = true,
        message = {
            id = os.time(),
            officerId = officerId,
            callsign = profile.callsign or tostring(source),
            name = profile.lastName or GetPlayerName(source) or 'Officer',
            rank = rank,
            message = message,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        },
    }
end)

local function normalizeFtoRecord(payload, existing)
    payload = type(payload) == 'table' and payload or {}
    existing = type(existing) == 'table' and existing or {}

    local now = os.date('!%Y-%m-%dT%H:%M:%SZ')
    local record = {}

    for key, value in pairs(existing) do
        record[key] = value
    end

    record.traineeName = trimText(payload.traineeName or payload.trainee_name or record.traineeName)
    record.traineeId = trimText(payload.traineeId or payload.trainee_id or record.traineeId)
    record.trainerName = trimText(payload.trainerName or payload.trainer_name or record.trainerName)
    record.trainerId = trimText(payload.trainerId or payload.trainer_id or record.trainerId)
    record.phase = math.max(1, math.min(4, tonumber(payload.phase or record.phase) or 1))
    record.score = math.max(0, math.min(10, tonumber(payload.score or record.score) or 0))
    record.status = trimText(payload.status or record.status)
    if record.status == '' then
        record.status = 'active'
    end
    record.notes = trimText(payload.notes or record.notes)
    record.created_at = record.created_at or now
    record.updated_at = now

    return record
end

lib.callback.register('cortex_mdt:getFtoRecords', function()
    local records = SessionStore.list('ftoRecords')
    table.sort(records, function(a, b)
        return tostring(a.updated_at or '') > tostring(b.updated_at or '')
    end)

    return { ok = true, records = records }
end)

lib.callback.register('cortex_mdt:createFtoRecord', function(source, data)
    local record = normalizeFtoRecord(data)
    if record.traineeName == '' then
        return { ok = false, error = 'Trainee name is required.' }
    end

    record.id = SessionStore.nextId('fto')
    SessionStore.set('ftoRecords', record.id, record)
    auditLog(ensureOfficerRecordForSource(source) or 0, 'fto_create', 'training', 'fto', record.id, nil)

    return { ok = true, record = record }
end)

lib.callback.register('cortex_mdt:updateFtoRecord', function(source, data)
    local id = data and data.id
    if not id then
        return { ok = false, error = 'FTO record ID is required.' }
    end

    local existing = SessionStore.get('ftoRecords', id)
    if not existing then
        return { ok = false, error = 'FTO record not found.' }
    end

    local record = normalizeFtoRecord(data, existing)
    record.id = id
    SessionStore.set('ftoRecords', id, record)
    auditLog(ensureOfficerRecordForSource(source) or 0, 'fto_update', 'training', 'fto', id, nil)

    return { ok = true, record = record }
end)

lib.callback.register('cortex_mdt:getCivilianRecords', function(source, data)
    local citizenId = trimText(data and (data.citizenId or data.citizen_id))

    if citizenId == '' then
        local standalone = getStandaloneCivilianModule()
        if standalone and type(standalone.getCivilianProfile) == 'function' then
            local profile = standalone.getCivilianProfile(source)
            citizenId = trimText(profile and (profile.citizenId or profile.citizen_id))
        end
    end

    local records = {
        citations = {},
        warrants = {},
        arrests = {},
        reports = {},
        bolos = {},
    }

    if citizenId == '' then
        return { ok = true, records = records }
    end
    auditLog(getOfficerId(source) or 0, 'civilian_records_view', 'civilian', 'citizen', citizenId, nil)

    if usesLocalMode() then
        local citizen = LocalMode.getCitizen(citizenId, source)
        local citationResp = LocalMode.getCitationsForCitizen(citizenId)
        records.citations = (citationResp and citationResp.citations) or {}
        records.warrants = citizen and citizen.warrants or {}
        records.reports = citizen and citizen.reports or {}
        records.bolos = citizen and citizen.bolos or {}
        return { ok = true, records = records }
    end

    records.citations = MySQL.query.await('SELECT * FROM mdt_citations WHERE issued_to_citizen_id = ? ORDER BY issued_sort DESC, id DESC LIMIT 50', { citizenId }) or {}
    records.warrants = MySQL.query.await('SELECT * FROM mdt_warrants WHERE citizen_id = ? ORDER BY created_at DESC LIMIT 50', { citizenId }) or {}
    records.reports = MySQL.query.await([[
        SELECT r.id, r.report_number, r.title, r.status, r.created_at, re.role
        FROM mdt_report_entities re
        JOIN mdt_reports r ON r.id = re.report_id
        JOIN mdt_citizens ci ON ci.id = re.entity_id AND re.entity_type = 'citizen'
        WHERE ci.citizen_id = ?
        ORDER BY r.created_at DESC LIMIT 50
    ]], { citizenId }) or {}
    records.bolos = MySQL.query.await('SELECT * FROM mdt_bolos WHERE citizen_id = ? ORDER BY created_at DESC LIMIT 50', { citizenId }) or {}

    return { ok = true, records = records }
end)

lib.callback.register('cortex_mdt:getSops', function()
    return {
        ok = true,
        sops = Config.SOPs or Config.Sops or {},
    }
end)

lib.callback.register('cortex_mdt:getConfig', function(source)
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

AddEventHandler('playerDropped', function()
    forgetCitizenSourceByPlayer(source)
    if usesLocalMode() then
        LocalMode.handlePlayerDropped(source)
        ActiveOfficers[source] = nil
        return
    end

    if ActiveOfficers[source] then
        local officerId = ActiveOfficers[source]
        MySQL.update('UPDATE mdt_units SET status = "off_duty" WHERE officer_id = ?', { officerId })
        ActiveOfficers[source] = nil
    end
end)

lib.callback.register('cortex_mdt:getLocalStorage', function(source, key)
    local value = LocalStorage.get(getScopedLocalStorageKey(source, key))
    return { ok = true, key = key, value = value }
end)

lib.callback.register('cortex_mdt:setLocalStorage', function(source, data)
    if not data or not data.key then
        return { ok = false }
    end
    LocalStorage.set(getScopedLocalStorageKey(source, data.key), data.value)
    auditLog(getOfficerId(source) or 0, 'local_storage_set', 'client_state', 'local_storage', data.key, nil)
    return { ok = true }
end)

lib.callback.register('cortex_mdt:getAllLocalStorage', function(source)
    local all = LocalStorage.getAll()
    local prefix = getScopedLocalStorageKey(source, '')
    local scoped = {}

    for key, value in pairs(all) do
        if type(key) == 'string' and key:sub(1, #prefix) == prefix then
            scoped[key:sub(#prefix + 1)] = value
        end
    end

    return { ok = true, data = scoped }
end)

lib.callback.register('cortex_mdt:setLocalStorageMultiple', function(source, data)
    if type(data) ~= 'table' then
        return { ok = false }
    end
    local scoped = {}
    local count = 0

    for key, value in pairs(data) do
        scoped[getScopedLocalStorageKey(source, key)] = value
        count = count + 1
    end

    LocalStorage.setMultiple(scoped)
    auditLog(getOfficerId(source) or 0, 'local_storage_set_multiple', 'client_state', 'local_storage', nil, { count = count })
    return { ok = true }
end)
