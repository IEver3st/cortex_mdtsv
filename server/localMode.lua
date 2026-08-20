local LocalMode = {}

local resourceName = GetCurrentResourceName()

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

local LocalStorage = loadResourceModule('server/localStorage.lua')
local Audit = loadResourceModule('server/audit.lua')

local GLOBAL_SETTINGS_KEY = 'cortex_mdt:settings'
local ANNOUNCEMENTS_STORAGE_KEY = 'cortex_mdt:announcements'

local state

local function getStoredGlobalSettings()
    local settings = LocalStorage.get(GLOBAL_SETTINGS_KEY)

    if type(settings) ~= 'table' then
        return {}
    end

    return settings
end

local function getStoredAnnouncements()
    local announcements = LocalStorage.get(ANNOUNCEMENTS_STORAGE_KEY)

    if type(announcements) ~= 'table' then
        return {}
    end

    return announcements
end

state = {
    nextOfficerId = 1,
    nextAnnouncementId = 1,
    nextAuditId = 1,
    nextChatId = 1,
    nextReportId = 1,
    nextCaseId = 1,
    nextEvidenceId = 1,
    nextBoloId = 1,
    nextWarrantId = 1,
    nextWeaponId = 1,
    nextVehicleImpoundId = 1,
    nextAttachmentId = 1,
    nextCitationId = 1,
    officersById = {},
    officerIdsByIdentifier = {},
    unitsByOfficerId = {},
    announcements = {},
    auditLogs = {},
    chatMessages = {},
    settings = {},
    citizenProfiles = {},
    citizenLicenses = {},
    vehicleProfiles = {},
    vehicleProfilesByPlate = {},
    vehicleImpounds = {},
    reports = {},
    reportTimeline = {},
    reportEntities = {},
    reportParticipants = {},
    reportCharges = {},
    cases = {},
    casePersonnel = {},
    caseLinks = {},
    evidence = {},
    evidenceCustody = {},
    bolos = {},
    warrants = {},
    weapons = {},
    weaponHistory = {},
    attachmentsByParent = {},
    citations = {},
}

state.settings = getStoredGlobalSettings()
state.announcements = getStoredAnnouncements()

for i = 1, #state.announcements do
    local announcement = state.announcements[i]
    local id = tonumber(type(announcement) == 'table' and announcement.id or nil)
    if id and id >= state.nextAnnouncementId then
        state.nextAnnouncementId = id + 1
    end
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function normalizePlate(value)
    return trim(value):upper():gsub('%s+', '')
end

local function lower(value)
    return trim(value):lower()
end

local function defaultMugshotUrl()
    return trim(Config and Config.DefaultMugshot or '')
end

local function clone(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}

    for key, entry in pairs(value) do
        copy[key] = clone(entry)
    end

    return copy
end

local SNAPSHOT_STORAGE_KEY = 'cortex_mdt:standalone_records:v2'
local DEFAULT_PERSIST_DEBOUNCE_MS = 350
local snapshotDirty = false
local snapshotFlushScheduled = false

local NUMERIC_KEY_COLLECTIONS = {
    'officersById',
    'unitsByOfficerId',
    'vehicleImpounds',
    'reports',
    'reportTimeline',
    'reportEntities',
    'reportParticipants',
    'reportCharges',
    'cases',
    'casePersonnel',
    'caseLinks',
    'evidence',
    'evidenceCustody',
    'bolos',
    'warrants',
    'weapons',
    'weaponHistory',
    'citations',
}

local COUNTER_KEYS = {
    'nextOfficerId',
    'nextAnnouncementId',
    'nextAuditId',
    'nextChatId',
    'nextReportId',
    'nextCaseId',
    'nextEvidenceId',
    'nextBoloId',
    'nextWarrantId',
    'nextWeaponId',
    'nextVehicleImpoundId',
    'nextAttachmentId',
    'nextCitationId',
}

local DURABLE_COLLECTIONS = {
    'officersById',
    'officerIdsByIdentifier',
    'unitsByOfficerId',
    'announcements',
    'auditLogs',
    'chatMessages',
    'settings',
    'citizenProfiles',
    'citizenLicenses',
    'vehicleProfiles',
    'vehicleProfilesByPlate',
    'vehicleImpounds',
    'reports',
    'reportTimeline',
    'reportEntities',
    'reportParticipants',
    'reportCharges',
    'cases',
    'casePersonnel',
    'caseLinks',
    'evidence',
    'evidenceCustody',
    'bolos',
    'warrants',
    'weapons',
    'weaponHistory',
    'attachmentsByParent',
    'citations',
}

local function standalonePersistenceEnabled()
    local config = type(Config.StandalonePersistence) == 'table' and Config.StandalonePersistence or {}
    return config.enabled ~= false
end

local function normalizeNumericKeys(collection)
    if type(collection) ~= 'table' then
        return {}
    end

    local normalized = {}
    for key, value in pairs(collection) do
        local numericKey = tonumber(key)
        normalized[numericKey or key] = value
    end
    return normalized
end

local function restoreDurableSnapshot()
    if not standalonePersistenceEnabled() then
        return
    end

    local stored = LocalStorage.get(SNAPSHOT_STORAGE_KEY)
    if type(stored) ~= 'table' or tonumber(stored.version) ~= 2 then
        return
    end

    for i = 1, #COUNTER_KEYS do
        local key = COUNTER_KEYS[i]
        state[key] = math.max(1, tonumber(stored[key]) or tonumber(state[key]) or 1)
    end

    for i = 1, #DURABLE_COLLECTIONS do
        local key = DURABLE_COLLECTIONS[i]
        if type(stored[key]) == 'table' then
            state[key] = stored[key]
        end
    end

    for i = 1, #NUMERIC_KEY_COLLECTIONS do
        local key = NUMERIC_KEY_COLLECTIONS[i]
        state[key] = normalizeNumericKeys(state[key])
    end

    state.officerIdsByIdentifier = type(state.officerIdsByIdentifier) == 'table' and state.officerIdsByIdentifier or {}
    for officerId, officer in pairs(state.officersById) do
        if type(officer) == 'table' then
            officer.source = nil
            if trim(officer.identifier) ~= '' then
                state.officerIdsByIdentifier[officer.identifier] = tonumber(officerId) or officerId
            end
        end
    end

    -- Server IDs and on-duty state are session facts. Never restore them after a restart.
    for _, unit in pairs(state.unitsByOfficerId) do
        if type(unit) == 'table' then
            unit.source = nil
            unit.status = 'off_duty'
            unit.assignment = nil
        end
    end

    -- Keep backwards-compatible settings/announcement keys authoritative when present.
    local legacySettings = getStoredGlobalSettings()
    if next(legacySettings) ~= nil then
        state.settings = legacySettings
    end
    local legacyAnnouncements = getStoredAnnouncements()
    if #legacyAnnouncements > 0 then
        state.announcements = legacyAnnouncements
    end
end

local function buildDurableSnapshot()
    local snapshot = { version = 2 }
    for i = 1, #COUNTER_KEYS do
        local key = COUNTER_KEYS[i]
        snapshot[key] = state[key]
    end
    for i = 1, #DURABLE_COLLECTIONS do
        local key = DURABLE_COLLECTIONS[i]
        snapshot[key] = clone(state[key])
    end

    for _, officer in pairs(snapshot.officersById or {}) do
        if type(officer) == 'table' then
            officer.source = nil
        end
    end
    for _, unit in pairs(snapshot.unitsByOfficerId or {}) do
        if type(unit) == 'table' then
            unit.source = nil
            unit.status = 'off_duty'
            unit.assignment = nil
        end
    end

    return snapshot
end

local function flushDurableSnapshot()
    snapshotFlushScheduled = false
    if not snapshotDirty or not standalonePersistenceEnabled() then
        return true
    end

    local ok = LocalStorage.set(SNAPSHOT_STORAGE_KEY, buildDurableSnapshot())
    if ok then
        snapshotDirty = false
    else
        print('[cortex_mdt] Failed to persist standalone records; keeping the current in-memory state.')
    end
    return ok == true
end

local function markDurableSnapshotDirty()
    if not standalonePersistenceEnabled() then
        return
    end

    snapshotDirty = true
    if snapshotFlushScheduled then
        return
    end

    snapshotFlushScheduled = true
    local config = type(Config.StandalonePersistence) == 'table' and Config.StandalonePersistence or {}
    local delay = math.max(100, math.min(5000, tonumber(config.debounceMs) or DEFAULT_PERSIST_DEBOUNCE_MS))
    SetTimeout(delay, flushDurableSnapshot)
end

restoreDurableSnapshot()

local function isoTimestamp()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function epoch()
    return os.time()
end

local function getPlayerIdentifier(source)
    return GetPlayerIdentifierByType(source, 'license')
        or GetPlayerIdentifierByType(source, 'fivem')
        or GetPlayerIdentifierByType(source, 'steam')
        or ('source:%s'):format(tostring(source))
end

local function getStoragePrefix(source)
    return ('player:%s:'):format(getPlayerIdentifier(source))
end

local function getSettingsKey(source)
    return getStoragePrefix(source) .. 'cortex_mdt_settings'
end

local function getStoredSettings(source)
    local settings = LocalStorage.get(getSettingsKey(source))

    if type(settings) ~= 'table' then
        return {}
    end

    return settings
end

local function displayName(firstName, lastName, source)
    local fullName = trim(('%s %s'):format(firstName or '', lastName or '')):gsub('%s+', ' ')

    if fullName ~= '' then
        return fullName
    end

    return GetPlayerName(source or 0) or 'Unknown Officer'
end

local function getStandaloneModule()
    local standalone = rawget(_G, 'CortexStandaloneCivilian')
    if type(standalone) == 'table' then
        return standalone
    end

    return nil
end

local function shallowArray(list)
    local copy = {}
    for i = 1, #(list or {}) do
        copy[i] = clone(list[i])
    end
    return copy
end

local function toArray(map)
    local rows = {}
    for _, value in pairs(map or {}) do
        rows[#rows + 1] = clone(value)
    end
    return rows
end

local function appendUniqueRows(target, rows, identityFn, limit)
    local seen = {}

    for i = 1, #target do
        local identity = identityFn(target[i])
        if identity ~= nil then
            seen[tostring(identity)] = true
        end
    end

    for i = 1, #(rows or {}) do
        local row = rows[i]
        local identity = identityFn(row)
        local key = identity ~= nil and tostring(identity) or nil

        if key == nil or not seen[key] then
            if key ~= nil then
                seen[key] = true
            end
            target[#target + 1] = clone(row)
            if limit and #target >= limit then
                break
            end
        end
    end

    return target
end

local function sortByUpdatedDesc(rows)
    table.sort(rows, function(a, b)
        return tonumber(a.updated_sort or a.created_sort or 0) > tonumber(b.updated_sort or b.created_sort or 0)
    end)
    return rows
end

local function sortByCreatedDesc(rows)
    table.sort(rows, function(a, b)
        return tonumber(a.created_sort or 0) > tonumber(b.created_sort or 0)
    end)
    return rows
end

local function getOfficerDisplay(officerId)
    local officer = LocalMode.getOfficer(officerId)
    if not officer then
        return nil, nil, nil
    end

    return displayName(officer.first_name, officer.last_name, officer.source), officer.first_name, officer.last_name
end

local function createNumber(prefix, counter)
    return ('%s-%s-%04d'):format(prefix, os.date('%Y%m%d'), counter)
end

local function limitPage(rows, page, limit)
    local pageNumber = math.max(1, tonumber(page) or 1)
    local pageSize = math.max(1, tonumber(limit) or 20)
    local offset = (pageNumber - 1) * pageSize
    local paged = {}

    for index = offset + 1, math.min(offset + pageSize, #rows) do
        paged[#paged + 1] = rows[index]
    end

    return paged, #rows, pageNumber
end

local function fetchCitizenDisplayName(citizenId)
    local id = trim(citizenId)
    if id == '' then
        return nil
    end

    local standalone = getStandaloneModule()
    if standalone and type(standalone.getCitizenData) == 'function' then
        local payload = standalone.getCitizenData(id, 0)
        if payload and payload.citizen then
            return displayName(payload.citizen.first_name or payload.citizen.firstName, payload.citizen.last_name or payload.citizen.lastName) or id
        end
    end

    local profile = state.citizenProfiles[id]
    if profile then
        return displayName(profile.first_name or profile.firstName, profile.last_name or profile.lastName) or id
    end

    return id
end

local function serializeExternalCitizen(citizen)
    local row = clone(citizen or {})
    local citizenId = trim(row.citizen_id or row.citizenId or row.id)

    row.id = row.id or citizenId
    row.citizen_id = citizenId
    row.citizenId = citizenId
    row.first_name = row.first_name or row.firstName or 'Unknown'
    row.firstName = row.firstName or row.first_name
    row.last_name = row.last_name or row.lastName or ''
    row.lastName = row.lastName or row.last_name
    row.fullName = row.fullName or displayName(row.first_name, row.last_name)
    row.mugshot = trim(row.mugshot or row.mugshotUrl or row.mugshot_url or row.photoUrl or row.photo_url) ~= ''
        and trim(row.mugshot or row.mugshotUrl or row.mugshot_url or row.photoUrl or row.photo_url)
        or defaultMugshotUrl()
    row.flags = clone(row.flags or {})
    row.properties = clone(row.properties or {})
    if type(row.properties.ersPersonalDetails) == 'table' then
        row.nationality = row.nationality or row.properties.ersPersonalDetails.nationality
        row.address = row.address or row.properties.ersPersonalDetails.address
        row.email = row.email or row.properties.ersPersonalDetails.email
    end
    row.externalKey = row.externalKey or row.external_key or row.ersId or row.ers_id or ''
    row.external_key = row.external_key or row.externalKey
    row.external = row.external ~= false

    return row
end

local function getExternalVehiclesForCitizen(citizenId)
    local id = trim(citizenId)
    local vehicles = {}

    if id == '' then
        return vehicles
    end

    for _, vehicle in pairs(state.vehicleProfiles) do
        if trim(vehicle.owner_citizen_id or vehicle.ownerCitizenId) == id then
            vehicles[#vehicles + 1] = clone(vehicle)
        end
    end

    return vehicles
end

local function getCitizenPayload(citizenId, source)
    local id = trim(citizenId)
    local standalone = getStandaloneModule()
    local payload = standalone and standalone.getCitizenData and standalone.getCitizenData(id, source or 0) or nil
    local citizen = payload and clone(payload.citizen) or nil

    if not citizen then
        citizen = state.citizenProfiles[id] and serializeExternalCitizen(state.citizenProfiles[id]) or nil
        if not citizen then
            return nil
        end
    end

    local overlay = state.citizenProfiles[id] or {}
    for key, value in pairs(overlay) do
        citizen[key] = clone(value)
    end

    citizen.citizen_id = citizen.citizen_id or id
    citizen.flags = clone(citizen.flags or {})
    citizen.properties = clone(citizen.properties or {})

    local vehicles = payload and shallowArray(payload.vehicles) or {}
    appendUniqueRows(vehicles, getExternalVehiclesForCitizen(id), function(row)
        return row.id or row.vehicle_id or row.plate
    end)
    local licenses = clone(state.citizenLicenses[id] or (payload and payload.licenses) or {})
    local reports = {}
    local warrants = payload and shallowArray(payload.warrants) or {}
    local bolos = payload and shallowArray(payload.bolos) or {}

    for _, report in pairs(state.reports) do
        local include = false
        local entities = state.reportEntities[report.id] or {}
        local participants = state.reportParticipants[report.id] or {}

        for i = 1, #entities do
            if entities[i].entity_type == 'citizen' and tostring(entities[i].entity_id) == id then
                include = true
                break
            end
        end

        if not include then
            for i = 1, #participants do
                if tostring(participants[i].citizenId or participants[i].citizen_id) == id then
                    include = true
                    break
                end
            end
        end

        if include then
            reports[#reports + 1] = {
                id = report.id,
                report_number = report.report_number,
                title = report.title,
                status = report.status,
                created_at = report.created_at,
            }
        end
    end

    for _, warrant in pairs(state.warrants) do
        if tostring(warrant.citizen_id or '') == id then
            warrants[#warrants + 1] = clone(warrant)
        end
    end

    for _, bolo in pairs(state.bolos) do
        if tostring(bolo.citizen_id or '') == id then
            bolos[#bolos + 1] = clone(bolo)
        end
    end

    sortByCreatedDesc(reports)
    sortByCreatedDesc(warrants)
    sortByCreatedDesc(bolos)

    citizen.stats = {
        vehicleCount = #vehicles,
        reportCount = #reports,
        warrantCount = #warrants,
        boloCount = #bolos,
        arrestCount = tonumber(citizen.arrest_count or 0) or 0,
        propertyCount = #(citizen.properties or {}),
    }

    return {
        citizen = citizen,
        vehicles = vehicles,
        licenses = licenses,
        reports = reports,
        warrants = warrants,
        bolos = bolos,
    }
end

local function getVehiclePayload(vehicleId, source)
    local id = trim(vehicleId)
    local standalone = getStandaloneModule()
    local payload = standalone and standalone.getVehicleData and standalone.getVehicleData(id, source or 0) or nil
    local vehicle = payload and clone(payload.vehicle) or nil

    if not vehicle then
        local matches = standalone and standalone.searchVehicles and standalone.searchVehicles(id, 1) or {}
        vehicle = matches and matches[1] and clone(matches[1]) or nil
    end

    if not vehicle then
        vehicle = state.vehicleProfiles[id]
            or state.vehicleProfiles[state.vehicleProfilesByPlate[normalizePlate(id)] or '']
        vehicle = vehicle and clone(vehicle) or nil
    end

    if not vehicle then
        return nil
    end

    local impounds = clone(state.vehicleImpounds[id] or {})
    return {
        vehicle = vehicle,
        impounds = impounds,
    }
end

local function attachmentKey(parentType, parentId)
    return ('%s:%s'):format(tostring(parentType or ''), tostring(parentId or ''))
end

local function serializeOfficer(officer)
    return {
        id = officer.id,
        identifier = officer.identifier,
        first_name = officer.first_name,
        last_name = officer.last_name,
        callsign = officer.callsign,
        rank = officer.rank,
        department = officer.department,
        avatar = officer.avatar,
        certifications = clone(officer.certifications or {}),
        status = officer.status or 'active',
    }
end

function LocalMode.getPlayerIdentifier(source)
    return getPlayerIdentifier(source)
end

function LocalMode.getScopedStorageKey(source, key)
    return getStoragePrefix(source) .. tostring(key)
end

function LocalMode.applyProfilePreferences(source, officer)
    if type(officer) ~= 'table' then
        return officer
    end

    local officerId = LocalMode.getOfficerId(source)
    local existingOfficer = officerId and LocalMode.getOfficer(officerId) or nil

    if existingOfficer and trim(existingOfficer.callsign) ~= '' then
        officer.callsign = trim(existingOfficer.callsign)
    end

    if existingOfficer and trim(existingOfficer.avatar) ~= '' then
        officer.avatar = trim(existingOfficer.avatar)
    end

    if existingOfficer and trim(existingOfficer.first_name) ~= '' then
        officer.firstName = trim(existingOfficer.first_name)
    end

    if existingOfficer and trim(existingOfficer.last_name) ~= '' then
        officer.lastName = trim(existingOfficer.last_name)
    end

    return officer
end

function LocalMode.ensureOfficer(source, data)
    if type(data) ~= 'table' then
        return nil
    end

    local identifier = getPlayerIdentifier(source)
    local officerId = state.officerIdsByIdentifier[identifier]
    local officer = officerId and state.officersById[officerId] or nil

    if not officer then
        officerId = state.nextOfficerId
        state.nextOfficerId = state.nextOfficerId + 1

        officer = {
            id = officerId,
            identifier = identifier,
            certifications = {},
            status = 'active',
        }

        state.officersById[officerId] = officer
        state.officerIdsByIdentifier[identifier] = officerId
    end

    officer.source = source
    local firstName = trim(data.firstName or data.first_name)
    local lastName = trim(data.lastName or data.last_name)
    local rank = trim(data.rank)
    local department = trim(data.departmentKey or data.department)
    local callsign = trim(data.callsign)
    local avatar = trim(data.avatar or data.avatarUrl)

    officer.first_name = firstName ~= '' and firstName or officer.first_name or ''
    officer.last_name = lastName ~= '' and lastName or officer.last_name or ''
    officer.rank = rank ~= '' and rank or officer.rank or 'Officer'
    officer.department = department ~= '' and department or officer.department or 'police'
    officer.callsign = callsign ~= '' and callsign or officer.callsign

    if avatar ~= '' then
        officer.avatar = avatar
    elseif data.avatar == nil and data.avatarUrl == nil then
        officer.avatar = officer.avatar
    else
        officer.avatar = nil
    end

    officer.updated_sort = epoch()

    if officer.callsign == '' then
        officer.callsign = tostring(source)
    end

    if type(data.certifications) == 'table' then
        officer.certifications = clone(data.certifications)
    end

    local unit = state.unitsByOfficerId[officerId]
    if unit then
        unit.callsign = officer.callsign
        unit.department = officer.department
        unit.last_updated = isoTimestamp()
        unit.updated_sort = epoch()
    end

    return officerId
end

function LocalMode.getOfficerId(source)
    return state.officerIdsByIdentifier[getPlayerIdentifier(source)]
end

function LocalMode.getOfficer(officerId)
    return state.officersById[tonumber(officerId) or -1]
end

function LocalMode.getOfficerUnitRow(officerId)
    local officer = LocalMode.getOfficer(officerId)
    local unit = state.unitsByOfficerId[tonumber(officerId) or -1]

    if not officer or not unit then
        return nil
    end

    return {
        officer_id = officer.id,
        callsign = unit.callsign or officer.callsign,
        officer_callsign = officer.callsign,
        department = unit.department or officer.department,
        officer_department = officer.department,
        status = unit.status or 'off_duty',
        assignment = unit.assignment or '',
        last_updated = unit.last_updated or isoTimestamp(),
    }
end

function LocalMode.getOfficerDutyProfile(officerId)
    local officer = LocalMode.getOfficer(officerId)

    if not officer then
        return nil
    end

    return {
        callsign = officer.callsign,
        department = officer.department,
    }
end

function LocalMode.upsertOfficerUnitState(officerId, status, assignment)
    local officer = LocalMode.getOfficer(officerId)

    if not officer then
        return nil, 'Officer record not found.'
    end

    local unit = state.unitsByOfficerId[officer.id] or {}
    unit.officer_id = officer.id
    unit.callsign = officer.callsign
    unit.department = officer.department
    unit.status = trim(status) ~= '' and trim(status) or 'available'
    unit.assignment = trim(assignment)
    unit.last_updated = isoTimestamp()
    unit.updated_sort = epoch()
    state.unitsByOfficerId[officer.id] = unit

    return {
        callsign = unit.callsign,
        department = unit.department,
        status = unit.status,
        assignment = unit.assignment,
    }
end

function LocalMode.getUnits()
    local units = {}

    for officerId, unit in pairs(state.unitsByOfficerId) do
        local officer = state.officersById[officerId]
        if officer then
            units[#units + 1] = {
                officer_id = officer.id,
                callsign = unit.callsign or officer.callsign,
                status = unit.status or 'off_duty',
                department = unit.department or officer.department,
                assignment = unit.assignment or '',
                first_name = officer.first_name,
                last_name = officer.last_name,
                rank = officer.rank,
                avatar = officer.avatar,
                dept = officer.department,
                last_updated = unit.last_updated,
                source = officer.source,
            }
        end
    end

    table.sort(units, function(a, b)
        if lower(a.department) == lower(b.department) then
            return lower(a.callsign) < lower(b.callsign)
        end

        return lower(a.department) < lower(b.department)
    end)

    return units
end

function LocalMode.getRoster()
    local officers = {}

    for _, officer in pairs(state.officersById) do
        officers[#officers + 1] = serializeOfficer(officer)
    end

    table.sort(officers, function(a, b)
        if lower(a.department) == lower(b.department) then
            return lower(a.last_name) < lower(b.last_name)
        end

        return lower(a.department) < lower(b.department)
    end)

    return officers
end

function LocalMode.updateOfficerAdmin(data)
    local officer = LocalMode.getOfficer(data and data.officerId)

    if not officer then
        return false
    end

    officer.rank = trim(data.rank) ~= '' and trim(data.rank) or officer.rank
    officer.callsign = trim(data.callsign) ~= '' and trim(data.callsign) or officer.callsign
    officer.department = trim(data.department) ~= '' and trim(data.department) or officer.department
    officer.status = trim(data.status) ~= '' and trim(data.status) or officer.status
    officer.certifications = type(data.certifications) == 'table' and clone(data.certifications) or officer.certifications

    local unit = state.unitsByOfficerId[officer.id]
    if unit then
        unit.callsign = officer.callsign
        unit.department = officer.department
    end

    return true
end

function LocalMode.auditLog(officerId, action, category, targetType, targetId, details)
    local officer = LocalMode.getOfficer(officerId)
    return Audit.write(officerId, action, category, targetType, targetId, details, {
        officer = officer,
        source = officer and officer.source or nil,
    })
end

function LocalMode.getAuditLogs(page, filter)
    return Audit.getLogs(page, filter, 50)
end

function LocalMode.getSetting(key)
    return state.settings[key]
end

function LocalMode.updateSetting(key, value)
    state.settings[key] = value
    LocalStorage.set(GLOBAL_SETTINGS_KEY, state.settings)
    return true
end

function LocalMode.getAnnouncements(limit)
    local maxRows = tonumber(limit) or #state.announcements
    local rows = {}

    for i = 1, #state.announcements do
        local announcement = state.announcements[i]
        if announcement.active ~= false then
            rows[#rows + 1] = clone(announcement)
            if #rows >= maxRows then
                break
            end
        end
    end

    return rows
end

function LocalMode.createAnnouncement(source, data)
    local officerId = LocalMode.getOfficerId(source)
    local officer = officerId and LocalMode.getOfficer(officerId) or nil
    local announcement = {
        id = state.nextAnnouncementId,
        title = trim(data.title),
        content = trim(data.content),
        department = trim(data.department),
        pinned = data.pinned and 1 or 0,
        active = true,
        author_id = officerId or 0,
        author = displayName(officer and officer.first_name, officer and officer.last_name, source),
        created_at = isoTimestamp(),
        created_sort = epoch(),
    }

    state.nextAnnouncementId = state.nextAnnouncementId + 1
    table.insert(state.announcements, announcement)

    table.sort(state.announcements, function(a, b)
        if (a.pinned or 0) == (b.pinned or 0) then
            return tonumber(a.created_sort or 0) > tonumber(b.created_sort or 0)
        end

        return (a.pinned or 0) > (b.pinned or 0)
    end)

    LocalStorage.set(ANNOUNCEMENTS_STORAGE_KEY, state.announcements)

    return clone(announcement)
end

function LocalMode.deleteAnnouncement(id)
    local targetId = tonumber(id)

    for i = 1, #state.announcements do
        if tonumber(state.announcements[i].id) == targetId then
            state.announcements[i].active = false
            LocalStorage.set(ANNOUNCEMENTS_STORAGE_KEY, state.announcements)
            return true
        end
    end

    return false
end

function LocalMode.getChatMessages(limit)
    local maxRows = tonumber(limit) or #state.chatMessages
    local rows = {}
    local startIndex = math.max(1, #state.chatMessages - maxRows + 1)

    for i = startIndex, #state.chatMessages do
        rows[#rows + 1] = clone(state.chatMessages[i])
    end

    return rows
end

function LocalMode.addChatMessage(source, message)
    local officerId = LocalMode.getOfficerId(source)
    local officer = officerId and LocalMode.getOfficer(officerId) or nil
    local rank = trim(officer and officer.rank or 'Officer')

    if #rank > 4 then
        rank = rank:sub(1, 4) .. '.'
    end

    local avatar = nil
    if officer and type(officer.avatar) == 'string' then
        local trimmedAvatar = trim(officer.avatar)
        if trimmedAvatar ~= '' then
            avatar = trimmedAvatar
        end
    end

    local entry = {
        id = state.nextChatId,
        officerId = officerId or 0,
        callsign = officer and officer.callsign or tostring(source),
        name = officer and officer.last_name or (GetPlayerName(source) or 'Officer'),
        rank = rank ~= '' and rank or 'Ofc.',
        message = trim(message),
        timestamp = isoTimestamp(),
        avatar = avatar,
    }

    state.nextChatId = state.nextChatId + 1
    state.chatMessages[#state.chatMessages + 1] = entry

    if #state.chatMessages > 100 then
        table.remove(state.chatMessages, 1)
    end

    return clone(entry)
end

function LocalMode.globalSearch(query)
    local needle = lower(query)
    local results = {
        citizens = {},
        vehicles = {},
        reports = {},
        cases = {},
    }

    if needle == '' then
        return results
    end

    local standalone = getStandaloneModule()
    if standalone and standalone.searchCitizens then
        results.citizens = standalone.searchCitizens(query, 5) or {}
    end

    if standalone and standalone.searchVehicles then
        results.vehicles = standalone.searchVehicles(query, 5) or {}
    end

    for _, report in pairs(state.reports) do
        local haystack = lower(('%s %s'):format(report.report_number or '', report.title or ''))
        if haystack:find(needle, 1, true) then
            results.reports[#results.reports + 1] = {
                id = report.id,
                report_number = report.report_number,
                title = report.title,
                status = report.status,
            }
            if #results.reports >= 5 then
                break
            end
        end
    end

    for _, caseRow in pairs(state.cases) do
        local haystack = lower(('%s %s'):format(caseRow.case_number or '', caseRow.title or ''))
        if haystack:find(needle, 1, true) then
            results.cases[#results.cases + 1] = {
                id = caseRow.id,
                case_number = caseRow.case_number,
                title = caseRow.title,
                status = caseRow.status,
            }
            if #results.cases >= 5 then
                break
            end
        end
    end

    return results
end

function LocalMode.searchCitizens(query, limit)
    local needle = lower(query)
    local results = {}

    if needle == '' then
        return results
    end

    local standalone = getStandaloneModule()
    if standalone and standalone.searchCitizens then
        appendUniqueRows(results, standalone.searchCitizens(query, limit or 25) or {}, function(row)
            return row.citizen_id or row.citizenId or row.id
        end, limit or 25)
    end

    local externalRows = {}
    for _, citizen in pairs(state.citizenProfiles) do
        local row = serializeExternalCitizen(citizen)
        local haystack = lower(('%s %s %s %s %s %s %s %s'):format(
            row.citizen_id or '',
            row.first_name or '',
            row.last_name or '',
            row.phone or '',
            row.fingerprint or '',
            row.fullName or '',
            row.externalKey or row.external_key or '',
            row.notes or ''
        ))

        if haystack:find(needle, 1, true) then
            externalRows[#externalRows + 1] = row
        end
    end

    table.sort(externalRows, function(a, b)
        return lower(a.fullName or a.citizen_id) < lower(b.fullName or b.citizen_id)
    end)

    appendUniqueRows(results, externalRows, function(row)
        return row.citizen_id or row.citizenId or row.id
    end, limit or 25)

    return results
end

function LocalMode.getCitizen(citizenId, source)
    return getCitizenPayload(citizenId, source)
end

function LocalMode.upsertExternalCitizen(data)
    if type(data) ~= 'table' then
        return nil, 'Invalid citizen payload.'
    end

    local citizenId = trim(data.citizenId or data.citizen_id or data.id)
    if citizenId == '' then
        return nil, 'Missing citizen identifier.'
    end

    local existing = state.citizenProfiles[citizenId] or {}
    local row = clone(existing)

    row.id = citizenId
    row.citizen_id = citizenId
    row.citizenId = citizenId
    row.first_name = trim(data.firstName or data.first_name) ~= '' and trim(data.firstName or data.first_name) or row.first_name or 'Unknown'
    row.firstName = row.first_name
    row.last_name = trim(data.lastName or data.last_name) ~= '' and trim(data.lastName or data.last_name) or row.last_name or ''
    row.lastName = row.last_name
    row.dob = trim(data.dob or data.dateOfBirth) ~= '' and trim(data.dob or data.dateOfBirth) or row.dob
    row.gender = trim(data.gender) ~= '' and trim(data.gender) or row.gender
    row.phone = trim(data.phone) ~= '' and trim(data.phone) or row.phone
    row.mugshot = trim(data.mugshot or data.mugshotUrl or data.photoUrl) ~= '' and trim(data.mugshot or data.mugshotUrl or data.photoUrl) or row.mugshot or defaultMugshotUrl()
    row.fingerprint = trim(data.fingerprint) ~= '' and trim(data.fingerprint) or row.fingerprint
    row.occupation = trim(data.occupation or data.job) ~= '' and trim(data.occupation or data.job) or row.occupation
    row.nationality = trim(data.nationality) ~= '' and trim(data.nationality) or row.nationality
    row.address = trim(data.address) ~= '' and trim(data.address) or row.address
    row.email = trim(data.email) ~= '' and trim(data.email) or row.email
    row.notes = trim(data.notes) ~= '' and trim(data.notes) or row.notes
    row.flags = type(data.flags) == 'table' and clone(data.flags) or row.flags or {}
    row.properties = type(data.properties) == 'table' and clone(data.properties) or row.properties or {}
    row.tags = type(data.tags) == 'table' and clone(data.tags) or row.tags
    row.source = data.source or row.source or 'external'
    row.external = true
    row.updated_at = isoTimestamp()
    row.updated_sort = epoch()
    row.created_at = row.created_at or row.updated_at
    row.created_sort = row.created_sort or row.updated_sort

    state.citizenProfiles[citizenId] = row
    if type(data.licenses) == 'table' and #data.licenses > 0 then
        state.citizenLicenses[citizenId] = clone(data.licenses)
    end
    return serializeExternalCitizen(row)
end

function LocalMode.updateCitizen(data)
    local citizenId = trim(data and data.citizenId)
    if citizenId == '' then
        return false
    end

    local overlay = state.citizenProfiles[citizenId] or {}

    for _, key in ipairs({
        'first_name', 'last_name', 'dob', 'gender', 'phone', 'address', 'occupation', 'photo_url', 'mugshot',
        'mugshot_url', 'notes', 'fingerprint', 'dnalabel', 'arrest_count', 'job', 'property_count'
    }) do
        if data[key] ~= nil then
            overlay[key] = key == 'mugshot' and (trim(data[key]) ~= '' and trim(data[key]) or defaultMugshotUrl()) or clone(data[key])
        end
    end

    if data.firstName ~= nil then overlay.first_name = data.firstName end
    if data.lastName ~= nil then overlay.last_name = data.lastName end
    if data.photoUrl ~= nil then overlay.photo_url = data.photoUrl end
    if data.mugshotUrl ~= nil then overlay.mugshot_url = data.mugshotUrl end
    if data.mugshot ~= nil then overlay.mugshot = trim(data.mugshot) ~= '' and trim(data.mugshot) or defaultMugshotUrl() end
    if data.flags ~= nil then overlay.flags = clone(data.flags) end
    if data.properties ~= nil then overlay.properties = clone(data.properties) end
    if data.tags ~= nil then overlay.tags = clone(data.tags) end

    state.citizenProfiles[citizenId] = overlay
    return true
end

function LocalMode.updateCitizenLicenses(citizenId, licenses)
    local id = trim(citizenId)
    if id == '' then
        return false
    end

    state.citizenLicenses[id] = clone(licenses or {})
    return true
end

function LocalMode.fetchLicenseTypes()
    state.licenseTypes = state.licenseTypes or {}

    if next(state.licenseTypes) == nil and type(Config.LicenseTypes) == 'table' and #Config.LicenseTypes > 0 then
        for i = 1, #Config.LicenseTypes do
            local preset = Config.LicenseTypes[i]
            local nextId = #state.licenseTypes + 1
            state.licenseTypes[nextId] = {
                id = nextId,
                type_id = preset.id,
                name = preset.label,
                description = preset.description or '',
                active = 1,
            }
        end
    end

    local rows = {}
    for i = 1, #state.licenseTypes do
        rows[#rows + 1] = clone(state.licenseTypes[i])
    end
    return rows
end

function LocalMode.createLicenseType(data)
    local name = trim(data and data.name or '')
    if name == '' then
        return nil
    end

    state.licenseTypes = state.licenseTypes or {}
    local nextId = #state.licenseTypes + 1
    local typeId = trim(data.type_id or data.typeId or ''):lower():gsub('%s+', '_'):gsub('[^a-z0-9_]', '')
    if typeId == '' then
        typeId = name:lower():gsub('%s+', '_'):gsub('[^a-z0-9_]', '')
    end

    local license = {
        id = nextId,
        type_id = typeId,
        name = name,
        description = trim(data.description or ''),
        active = 1,
    }
    state.licenseTypes[nextId] = license
    return clone(license)
end

function LocalMode.updateLicenseType(data)
    local id = tonumber(data and data.id)
    if not id or not state.licenseTypes or not state.licenseTypes[id] then
        return false
    end

    local license = state.licenseTypes[id]
    if data.name ~= nil then license.name = trim(data.name) end
    if data.description ~= nil then license.description = trim(data.description) end
    if data.active ~= nil then license.active = data.active and 1 or 0 end
    return true
end

function LocalMode.deleteLicenseType(id)
    local targetId = tonumber(id)
    if not targetId or not state.licenseTypes or not state.licenseTypes[targetId] then
        return false
    end

    state.licenseTypes[targetId] = nil
    return true
end

function LocalMode.searchVehicles(query, limit)
    local needle = lower(query)
    local results = {}

    if needle == '' then
        return results
    end

    local standalone = getStandaloneModule()
    if standalone and standalone.searchVehicles then
        appendUniqueRows(results, standalone.searchVehicles(query, limit or 25) or {}, function(row)
            return row.id or row.vehicle_id or row.plate
        end, limit or 25)
    end

    local externalRows = {}
    for _, vehicle in pairs(state.vehicleProfiles) do
        local haystack = lower(('%s %s %s %s %s %s'):format(
            vehicle.id or '',
            vehicle.plate or '',
            vehicle.vin or '',
            vehicle.model or '',
            vehicle.color or '',
            vehicle.owner_name or ''
        ))

        if haystack:find(needle, 1, true) then
            externalRows[#externalRows + 1] = clone(vehicle)
        end
    end

    table.sort(externalRows, function(a, b)
        return lower(a.plate or a.id) < lower(b.plate or b.id)
    end)

    appendUniqueRows(results, externalRows, function(row)
        return row.id or row.vehicle_id or row.plate
    end, limit or 25)

    return results
end

function LocalMode.getVehicle(vehicleId, source)
    return getVehiclePayload(vehicleId, source)
end

function LocalMode.upsertExternalVehicle(data)
    if type(data) ~= 'table' then
        return nil, 'Invalid vehicle payload.'
    end

    local plate = trim(data.plate)
    local vehicleId = trim(data.vehicleId or data.vehicle_id or data.id)
    if vehicleId == '' then
        vehicleId = plate ~= '' and plate or nil
    end
    if not vehicleId then
        return nil, 'Missing vehicle identifier.'
    end

    local existing = state.vehicleProfiles[vehicleId] or {}
    local row = clone(existing)
    local ownerCitizenId = trim(data.ownerCitizenId or data.owner_citizen_id)
    local ownerName = trim(data.ownerName or data.owner_name)

    if ownerName == '' and ownerCitizenId ~= '' then
        ownerName = fetchCitizenDisplayName(ownerCitizenId)
    end

    row.id = vehicleId
    row.vehicleId = vehicleId
    row.vehicle_id = vehicleId
    row.plate = plate ~= '' and plate or row.plate
    row.vin = trim(data.vin) ~= '' and trim(data.vin) or row.vin
    row.ownerCitizenId = ownerCitizenId ~= '' and ownerCitizenId or row.ownerCitizenId
    row.owner_citizen_id = row.ownerCitizenId
    row.ownerName = ownerName ~= '' and ownerName or row.ownerName
    row.owner_name = row.ownerName
    row.model = trim(data.model) ~= '' and trim(data.model) or row.model
    row.color = trim(data.color) ~= '' and trim(data.color) or row.color
    row.vehicleClass = trim(data.vehicleClass or data.vehicle_class) ~= '' and trim(data.vehicleClass or data.vehicle_class) or row.vehicleClass
    row.vehicle_class = row.vehicleClass
    row.registrationStatus = trim(data.registrationStatus or data.registration_status) ~= '' and trim(data.registrationStatus or data.registration_status) or row.registrationStatus or 'valid'
    row.registration_status = row.registrationStatus
    row.flags = type(data.flags) == 'table' and clone(data.flags) or row.flags or {}
    row.notes = trim(data.notes) ~= '' and trim(data.notes) or row.notes
    row.source = data.source or row.source or 'external'
    row.external = true
    row.updated_at = isoTimestamp()
    row.updated_sort = epoch()
    row.created_at = row.created_at or row.updated_at
    row.created_sort = row.created_sort or row.updated_sort

    if existing.plate and normalizePlate(existing.plate) ~= normalizePlate(row.plate) then
        state.vehicleProfilesByPlate[normalizePlate(existing.plate)] = nil
    end

    state.vehicleProfiles[vehicleId] = row
    if row.plate and row.plate ~= '' then
        state.vehicleProfilesByPlate[normalizePlate(row.plate)] = vehicleId
    end

    return clone(row)
end

function LocalMode.impoundVehicle(data, officerId)
    local vehicleId = trim(data and (data.vehicleId or data.plate))
    if vehicleId == '' then
        return false
    end

    state.vehicleImpounds[vehicleId] = state.vehicleImpounds[vehicleId] or {}
    local impound = {
        id = state.nextVehicleImpoundId,
        vehicle_id = vehicleId,
        reason = trim(data.reason),
        fee = tonumber(data.fee or 0) or 0,
        lot_location = trim(data.lotLocation or data.lot_location),
        officer_id = officerId or 0,
        created_at = isoTimestamp(),
        created_sort = epoch(),
        released_at = nil,
        status = 'active',
    }

    state.nextVehicleImpoundId = state.nextVehicleImpoundId + 1
    table.insert(state.vehicleImpounds[vehicleId], 1, impound)
    return clone(impound)
end

function LocalMode.releaseImpound(data)
    local impoundId = tonumber(data and data.impoundId)
    if not impoundId then
        return false
    end

    for _, impounds in pairs(state.vehicleImpounds) do
        for i = 1, #impounds do
            if tonumber(impounds[i].id) == impoundId then
                impounds[i].status = 'released'
                impounds[i].released_at = isoTimestamp()
                return true
            end
        end
    end

    return false
end

function LocalMode.getReports(page, filter, source)
    local officerId = LocalMode.getOfficerId(source) or 0
    local rows = toArray(state.reports)

    rows = sortByUpdatedDesc(rows)
    if filter == 'mine' then
        local mine = {}
        for i = 1, #rows do
            if tonumber(rows[i].author_id or 0) == officerId then
                mine[#mine + 1] = rows[i]
            end
        end
        rows = mine
    elseif filter == 'submitted' or filter == 'draft' then
        local filtered = {}
        for i = 1, #rows do
            if tostring(rows[i].status or 'draft') == filter then
                filtered[#filtered + 1] = rows[i]
            end
        end
        rows = filtered
    end

    local paged, total, pageNumber = limitPage(rows, page, 20)
    return { reports = paged, total = total, page = pageNumber }
end

function LocalMode.getReport(reportId)
    local report = clone(state.reports[tonumber(reportId) or -1])
    if not report then
        return nil
    end

    return {
        report = report,
        timeline = shallowArray(state.reportTimeline[report.id] or {}),
        entities = shallowArray(state.reportEntities[report.id] or {}),
        participants = shallowArray(state.reportParticipants[report.id] or {}),
        charges = shallowArray(state.reportCharges[report.id] or {}),
        attachments = shallowArray(state.attachmentsByParent[attachmentKey('report', report.id)] or {}),
        collaborators = {},
    }
end

function LocalMode.createReport(source, data)
    local officerId = LocalMode.getOfficerId(source) or 0
    local reportId = state.nextReportId
    state.nextReportId = state.nextReportId + 1
    local reportNumber = createNumber(trim(state.settings.report_prefix) ~= '' and state.settings.report_prefix or 'RPT', reportId)
    local authorName, authorFirst, authorLast = getOfficerDisplay(officerId)

    local report = {
        id = reportId,
        report_number = reportNumber,
        title = trim(data.title),
        template = trim(data.template) ~= '' and trim(data.template) or 'general',
        narrative = data.narrative or '',
        author_id = officerId,
        department = (LocalMode.getOfficer(officerId) or {}).department or 'police',
        tags = clone(data.tags or {}),
        status = trim(data.status) ~= '' and trim(data.status) or 'draft',
        priority = trim(data.priority) ~= '' and trim(data.priority) or 'normal',
        restricted = data.restricted and 1 or 0,
        restricted_to = clone(data.restrictedTo or {}),
        created_at = isoTimestamp(),
        updated_at = isoTimestamp(),
        created_sort = epoch(),
        updated_sort = epoch(),
        author_first = authorFirst or '',
        author_last = authorLast or '',
        author = authorName or '',
    }

    state.reports[reportId] = report
    state.reportTimeline[reportId] = {}
    state.reportEntities[reportId] = clone(data.entities or {})
    state.reportParticipants[reportId] = clone(data.participants or {})
    state.reportCharges[reportId] = clone(data.charges or {})

    return reportId, reportNumber
end

function LocalMode.updateReport(data)
    local report = state.reports[tonumber(data and data.reportId) or -1]
    if not report then
        return false
    end

    report.title = data.title or report.title
    report.narrative = data.narrative or report.narrative
    report.status = data.status or report.status
    report.tags = clone(data.tags or report.tags or {})
    report.priority = data.priority or report.priority
    report.restricted = data.restricted and 1 or 0
    report.restricted_to = clone(data.restrictedTo or report.restricted_to or {})
    report.updated_at = isoTimestamp()
    report.updated_sort = epoch()

    if type(data.participants) == 'table' then
        state.reportParticipants[report.id] = clone(data.participants)
    end

    if type(data.charges) == 'table' then
        state.reportCharges[report.id] = clone(data.charges)
    end

    return true
end

function LocalMode.addReportTimeline(source, data)
    local reportId = tonumber(data and data.reportId)
    if not reportId or not state.reports[reportId] then
        return false
    end

    local officerId = LocalMode.getOfficerId(source) or 0
    local _, firstName, lastName = getOfficerDisplay(officerId)
    state.reportTimeline[reportId] = state.reportTimeline[reportId] or {}
    state.reportTimeline[reportId][#state.reportTimeline[reportId] + 1] = {
        id = #state.reportTimeline[reportId] + 1,
        report_id = reportId,
        timestamp = data.timestamp or os.date('%H:%M:%S'),
        description = data.description,
        author_id = officerId,
        first_name = firstName or '',
        last_name = lastName or '',
        created_at = isoTimestamp(),
    }
    return true
end

function LocalMode.addReportEntity(data)
    local reportId = tonumber(data and data.reportId)
    if not reportId or not state.reports[reportId] then
        return false
    end

    state.reportEntities[reportId] = state.reportEntities[reportId] or {}
    local id = #state.reportEntities[reportId] + 1
    state.reportEntities[reportId][#state.reportEntities[reportId] + 1] = {
        id = id,
        report_id = reportId,
        entity_type = data.entityType,
        entity_id = data.entityId,
        role = data.role or 'involved',
    }
    return true
end

function LocalMode.removeReportEntity(data)
    local targetId = tonumber(data and data.id)
    if not targetId then
        return false
    end

    for reportId, entities in pairs(state.reportEntities) do
        for index = 1, #entities do
            if tonumber(entities[index].id) == targetId then
                table.remove(entities, index)
                return true
            end
        end
    end

    return false
end

function LocalMode.getCases(page)
    local rows = sortByUpdatedDesc(toArray(state.cases))
    local paged, total, pageNumber = limitPage(rows, page, 20)
    return { cases = paged, total = total, page = pageNumber }
end

function LocalMode.getCase(caseId)
    local row = clone(state.cases[tonumber(caseId) or -1])
    if not row then
        return nil
    end

    return {
        caseData = row,
        personnel = shallowArray(state.casePersonnel[row.id] or {}),
        links = shallowArray(state.caseLinks[row.id] or {}),
        attachments = shallowArray(state.attachmentsByParent[attachmentKey('case', row.id)] or {}),
    }
end

function LocalMode.createCase(source, data)
    local officerId = LocalMode.getOfficerId(source) or 0
    local caseId = state.nextCaseId
    state.nextCaseId = state.nextCaseId + 1
    local caseNumber = createNumber(trim(state.settings.case_prefix) ~= '' and state.settings.case_prefix or 'CASE', caseId)
    local _, firstName, lastName = getOfficerDisplay(officerId)
    local row = {
        id = caseId,
        case_number = caseNumber,
        title = trim(data.title),
        summary = data.summary or data.description or '',
        status = trim(data.status) ~= '' and trim(data.status) or 'open',
        lead_officer_id = officerId,
        department = (LocalMode.getOfficer(officerId) or {}).department or 'police',
        created_at = isoTimestamp(),
        updated_at = isoTimestamp(),
        created_sort = epoch(),
        updated_sort = epoch(),
        lead_first = firstName or '',
        lead_last = lastName or '',
    }

    state.cases[caseId] = row
    state.casePersonnel[caseId] = clone(data.personnel or {})
    state.casePersonnel[caseId][#state.casePersonnel[caseId] + 1] = {
        id = #state.casePersonnel[caseId] + 1,
        case_id = caseId,
        officer_id = officerId,
        role = 'lead',
        first_name = firstName or '',
        last_name = lastName or '',
        callsign = (LocalMode.getOfficer(officerId) or {}).callsign or '',
        rank = (LocalMode.getOfficer(officerId) or {}).rank or '',
    }
    state.caseLinks[caseId] = clone(data.links or {})
    return caseId, caseNumber
end

function LocalMode.updateCase(data)
    local row = state.cases[tonumber(data and data.caseId) or -1]
    if not row then
        return false
    end

    row.title = data.title or row.title
    row.summary = data.summary or data.description or row.summary
    row.status = data.status or row.status
    row.updated_at = isoTimestamp()
    row.updated_sort = epoch()
    return true
end

function LocalMode.addCaseLink(data)
    local caseId = tonumber(data and data.caseId)
    if not caseId or not state.cases[caseId] then
        return false
    end

    state.caseLinks[caseId] = state.caseLinks[caseId] or {}
    state.caseLinks[caseId][#state.caseLinks[caseId] + 1] = {
        id = #state.caseLinks[caseId] + 1,
        case_id = caseId,
        link_type = data.linkType,
        link_id = data.linkId,
        label = data.label,
    }
    return true
end

function LocalMode.removeCaseLink(data)
    local caseId = tonumber(data and data.caseId)
    local linkId = tonumber(data and data.linkId)
    if not linkId then
        return false
    end

    if caseId and state.caseLinks[caseId] then
        for index = 1, #state.caseLinks[caseId] do
            if tonumber(state.caseLinks[caseId][index].id) == linkId or tonumber(state.caseLinks[caseId][index].link_id) == linkId then
                table.remove(state.caseLinks[caseId], index)
                return true
            end
        end
        return false
    end

    for _, links in pairs(state.caseLinks) do
        for index = 1, #links do
            if tonumber(links[index].id) == linkId or tonumber(links[index].link_id) == linkId then
                table.remove(links, index)
                return true
            end
        end
    end

    return false
end

function LocalMode.addCasePersonnel(data)
    local caseId = tonumber(data and data.caseId)
    if not caseId or not state.cases[caseId] then
        return false
    end

    state.casePersonnel[caseId] = state.casePersonnel[caseId] or {}
    state.casePersonnel[caseId][#state.casePersonnel[caseId] + 1] = {
        id = #state.casePersonnel[caseId] + 1,
        case_id = caseId,
        officer_id = data.officerId,
        role = data.role or 'assigned',
        first_name = data.firstName or '',
        last_name = data.lastName or '',
        callsign = data.callsign or '',
        rank = data.rank or '',
    }
    return true
end

function LocalMode.removeCasePersonnel(data)
    local caseId = tonumber(data and data.caseId)
    local officerId = tonumber(data and data.officerId)
    local rowId = tonumber(data and data.id)

    if caseId and state.casePersonnel[caseId] then
        for index = 1, #state.casePersonnel[caseId] do
            if (officerId and tonumber(state.casePersonnel[caseId][index].officer_id) == officerId)
                or (rowId and tonumber(state.casePersonnel[caseId][index].id) == rowId) then
                table.remove(state.casePersonnel[caseId], index)
                return true
            end
        end
        return false
    end

    for _, personnel in pairs(state.casePersonnel) do
        for index = 1, #personnel do
            if (officerId and tonumber(personnel[index].officer_id) == officerId)
                or (rowId and tonumber(personnel[index].id) == rowId) then
                table.remove(personnel, index)
                return true
            end
        end
    end

    return false
end

function LocalMode.getEvidence(page)
    local rows = sortByUpdatedDesc(toArray(state.evidence))
    local paged, total, pageNumber = limitPage(rows, page, 20)
    return { evidence = paged, total = total, page = pageNumber }
end

function LocalMode.getEvidenceRecord(evidenceId)
    local row = clone(state.evidence[tonumber(evidenceId) or -1])
    if not row then
        return nil
    end

    return {
        evidence = row,
        custody = shallowArray(state.evidenceCustody[row.id] or {}),
        attachments = shallowArray(state.attachmentsByParent[attachmentKey('evidence', row.id)] or {}),
    }
end

function LocalMode.addAttachment(source, data)
    local officerId = LocalMode.getOfficerId(source) or 0
    local key = attachmentKey(data.parentType, data.parentId)
    state.attachmentsByParent[key] = state.attachmentsByParent[key] or {}
    local attachmentId = state.nextAttachmentId
    state.nextAttachmentId = state.nextAttachmentId + 1
    local _, uploaderFirst, uploaderLast = getOfficerDisplay(officerId)
    state.attachmentsByParent[key][#state.attachmentsByParent[key] + 1] = {
        id = attachmentId,
        parent_type = data.parentType,
        parent_id = data.parentId,
        file_name = data.fileName,
        file_url = data.fileUrl,
        file_type = data.fileType,
        uploaded_by = officerId,
        notes = data.notes,
        created_at = isoTimestamp(),
        uploader_first = uploaderFirst or '',
        uploader_last = uploaderLast or '',
        uploader_callsign = (LocalMode.getOfficer(officerId) or {}).callsign or '',
    }
    return attachmentId
end

function LocalMode.getAttachments(parentType, parentId)
    return shallowArray(state.attachmentsByParent[attachmentKey(parentType, parentId)] or {})
end

function LocalMode.removeAttachment(data)
    local attachmentId = tonumber(data and data.attachmentId)
    if not attachmentId then
        return false
    end

    for _, attachments in pairs(state.attachmentsByParent) do
        for index = 1, #attachments do
            if tonumber(attachments[index].id) == attachmentId then
                table.remove(attachments, index)
                return true
            end
        end
    end

    return false
end

function LocalMode.createEvidence(source, data)
    local officerId = LocalMode.getOfficerId(source) or 0
    local evidenceId = state.nextEvidenceId
    state.nextEvidenceId = state.nextEvidenceId + 1
    local evidenceTag = createNumber('EVD', evidenceId)
    local row = {
        id = evidenceId,
        evidence_tag = evidenceTag,
        type = data.type or data.evidenceType or 'general',
        title = data.title or data.name or evidenceTag,
        description = data.description or '',
        status = data.status or 'stored',
        location = data.location or '',
        linked_case_id = data.caseId or data.linkedCaseId,
        created_by = officerId,
        created_at = isoTimestamp(),
        updated_at = isoTimestamp(),
        created_sort = epoch(),
        updated_sort = epoch(),
    }

    state.evidence[evidenceId] = row
    state.evidenceCustody[evidenceId] = {{
        id = 1,
        evidence_id = evidenceId,
        action = 'created',
        officer_id = officerId,
        notes = data.description or 'Evidence created.',
        created_at = isoTimestamp(),
    }}
    return evidenceId, evidenceTag
end

function LocalMode.updateEvidence(source, data)
    local evidenceId = tonumber(data and data.evidenceId)
    local row = state.evidence[evidenceId]
    if not row then
        return false
    end

    row.type = data.type or data.evidenceType or row.type
    row.title = data.title or data.name or row.title
    row.description = data.description or row.description
    row.status = data.status or row.status
    row.location = data.location or row.location
    row.updated_at = isoTimestamp()
    row.updated_sort = epoch()

    local officerId = LocalMode.getOfficerId(source) or 0
    state.evidenceCustody[evidenceId] = state.evidenceCustody[evidenceId] or {}
    state.evidenceCustody[evidenceId][#state.evidenceCustody[evidenceId] + 1] = {
        id = #state.evidenceCustody[evidenceId] + 1,
        evidence_id = evidenceId,
        action = 'updated',
        officer_id = officerId,
        notes = data.notes or 'Evidence record updated.',
        created_at = isoTimestamp(),
    }
    return true
end

function LocalMode.transferEvidence(source, data)
    local evidenceId = tonumber(data and data.evidenceId)
    local row = state.evidence[evidenceId]
    if not row then
        return false
    end

    local officerId = LocalMode.getOfficerId(source) or 0
    row.location = data.toLocation or data.location or row.location
    row.status = data.status or row.status
    row.updated_at = isoTimestamp()
    row.updated_sort = epoch()
    state.evidenceCustody[evidenceId] = state.evidenceCustody[evidenceId] or {}
    state.evidenceCustody[evidenceId][#state.evidenceCustody[evidenceId] + 1] = {
        id = #state.evidenceCustody[evidenceId] + 1,
        evidence_id = evidenceId,
        action = 'transferred',
        officer_id = officerId,
        notes = data.notes or row.location,
        created_at = isoTimestamp(),
    }
    return true
end

function LocalMode.getBolos(filter)
    local rows = {}
    local needle = lower(filter)
    local activeOnly = needle == '' or needle == 'active'
    for _, row in pairs(state.bolos) do
        local haystack = lower(('%s %s %s %s'):format(row.title or '', row.description or '', row.citizen_id or '', row.plate or ''))
        if (activeOnly and tostring(row.status or 'active') == 'active')
            or (not activeOnly and haystack:find(needle, 1, true)) then
            rows[#rows + 1] = clone(row)
        end
    end
    return sortByCreatedDesc(rows)
end

function LocalMode.createBolo(source, data)
    local officerId = LocalMode.getOfficerId(source) or 0
    local id = state.nextBoloId
    state.nextBoloId = state.nextBoloId + 1
    local row = {
        id = id,
        type = data.type or 'person',
        title = data.title or 'BOLO',
        description = data.description or '',
        citizen_id = data.citizenId,
        plate = data.plate,
        vehicle_description = data.vehicleDescription,
        weapon_description = data.weaponDescription,
        photo_url = data.photoUrl or data.imageUrl,
        issued_by = officerId,
        department = (LocalMode.getOfficer(officerId) or {}).department or 'police',
        report_id = data.reportId,
        status = data.status or 'active',
        created_at = isoTimestamp(),
        created_sort = epoch(),
    }
    state.bolos[id] = row
    return id
end

function LocalMode.updateBoloStatus(data)
    local row = state.bolos[tonumber(data and data.boloId) or -1]
    if not row then
        return false
    end
    row.status = data.status or row.status
    return true
end

function LocalMode.getWarrants(filter)
    local rows = {}
    local needle = lower(filter)
    local activeOnly = needle == '' or needle == 'active'
    for _, row in pairs(state.warrants) do
        local haystack = lower(('%s %s %s'):format(row.citizen_id or '', row.citizen_name or '', row.description or ''))
        if (activeOnly and tostring(row.status or 'active') == 'active')
            or (not activeOnly and haystack:find(needle, 1, true)) then
            rows[#rows + 1] = clone(row)
        end
    end
    return sortByCreatedDesc(rows)
end

function LocalMode.createWarrant(source, data)
    local officerId = LocalMode.getOfficerId(source) or 0
    local id = state.nextWarrantId
    state.nextWarrantId = state.nextWarrantId + 1
    state.warrants[id] = {
        id = id,
        citizen_id = data.citizenId,
        citizen_name = data.citizenName or fetchCitizenDisplayName(data.citizenId),
        charges = clone(data.charges or {}),
        description = data.description or '',
        issued_by = officerId,
        department = (LocalMode.getOfficer(officerId) or {}).department or 'police',
        report_id = data.reportId,
        bolo_id = data.boloId,
        status = data.status or 'active',
        served_by = nil,
        served_at = nil,
        created_at = isoTimestamp(),
        created_sort = epoch(),
    }
    return id
end

function LocalMode.updateWarrantStatus(source, data)
    local row = state.warrants[tonumber(data and data.warrantId) or -1]
    if not row then
        return false
    end

    row.status = data.status or row.status
    if row.status == 'served' then
        row.served_by = LocalMode.getOfficerId(source) or 0
        row.served_at = isoTimestamp()
    else
        row.served_by = nil
        row.served_at = nil
    end
    return true
end

function LocalMode.getWeapons(filter)
    local rows = {}
    local needle = lower(filter)
    for _, row in pairs(state.weapons) do
        local haystack = lower(('%s %s %s %s %s'):format(row.serial_number or '', row.owner_name or '', row.weapon_type or '', row.make or '', row.model or ''))
        if needle == '' or haystack:find(needle, 1, true) then
            rows[#rows + 1] = clone(row)
        end
    end
    return sortByUpdatedDesc(rows)
end

function LocalMode.getWeaponRecord(weaponId)
    local row = clone(state.weapons[tonumber(weaponId) or -1])
    if not row then
        return nil
    end
    return {
        weapon = row,
        history = shallowArray(state.weaponHistory[row.id] or {}),
    }
end

function LocalMode.createWeapon(source, data)
    local officerId = LocalMode.getOfficerId(source) or 0
    local weaponId = state.nextWeaponId
    state.nextWeaponId = state.nextWeaponId + 1
    local serialNumber = trim(data.serialNumber) ~= '' and trim(data.serialNumber) or createNumber('WPN', weaponId)
    local ownerCitizenId = data.ownerCitizenId
    state.weapons[weaponId] = {
        id = weaponId,
        serial_number = serialNumber,
        owner_citizen_id = ownerCitizenId,
        owner_name = data.ownerName or fetchCitizenDisplayName(ownerCitizenId),
        weapon_type = data.weaponType,
        make = data.make,
        model = data.model,
        caliber = data.caliber,
        status = data.status or 'registered',
        notes = data.notes,
        image_url = data.photoUrl or data.imageUrl,
        created_at = isoTimestamp(),
        updated_at = isoTimestamp(),
        created_sort = epoch(),
        updated_sort = epoch(),
    }
    state.weaponHistory[weaponId] = {{
        id = 1,
        weapon_id = weaponId,
        action = 'registered',
        from_owner_citizen_id = nil,
        to_owner_citizen_id = ownerCitizenId,
        officer_id = officerId,
        notes = data.notes,
        created_at = isoTimestamp(),
    }}
    return weaponId, serialNumber
end

function LocalMode.updateWeapon(source, data)
    local row = state.weapons[tonumber(data and data.weaponId) or -1]
    if not row then
        return false
    end
    local officerId = LocalMode.getOfficerId(source) or 0
    row.owner_citizen_id = data.ownerCitizenId ~= nil and data.ownerCitizenId or row.owner_citizen_id
    row.owner_name = data.ownerName ~= nil and data.ownerName or row.owner_name
    row.weapon_type = data.weaponType ~= nil and data.weaponType or row.weapon_type
    row.make = data.make ~= nil and data.make or row.make
    row.model = data.model ~= nil and data.model or row.model
    row.caliber = data.caliber ~= nil and data.caliber or row.caliber
    row.status = data.status ~= nil and data.status or row.status
    row.notes = data.notes ~= nil and data.notes or row.notes
    row.image_url = data.photoUrl ~= nil and data.photoUrl or data.imageUrl ~= nil and data.imageUrl or row.image_url
    row.updated_at = isoTimestamp()
    row.updated_sort = epoch()
    state.weaponHistory[row.id] = state.weaponHistory[row.id] or {}
    state.weaponHistory[row.id][#state.weaponHistory[row.id] + 1] = {
        id = #state.weaponHistory[row.id] + 1,
        weapon_id = row.id,
        action = 'updated',
        from_owner_citizen_id = row.owner_citizen_id,
        to_owner_citizen_id = data.ownerCitizenId ~= nil and data.ownerCitizenId or row.owner_citizen_id,
        officer_id = officerId,
        notes = data.notes or 'Registry record updated.',
        created_at = isoTimestamp(),
    }
    return true
end

function LocalMode.transferWeapon(source, data)
    local row = state.weapons[tonumber(data and data.weaponId) or -1]
    if not row then
        return false
    end
    local officerId = LocalMode.getOfficerId(source) or 0
    local fromOwner = row.owner_citizen_id
    local nextOwnerCitizenId = data.toCitizenId or data.ownerCitizenId or nil
    row.owner_citizen_id = nextOwnerCitizenId
    row.owner_name = data.toOwnerName or data.ownerName or fetchCitizenDisplayName(nextOwnerCitizenId)
    row.status = data.status or (nextOwnerCitizenId and 'transferred' or 'evidence')
    row.updated_at = isoTimestamp()
    row.updated_sort = epoch()
    state.weaponHistory[row.id] = state.weaponHistory[row.id] or {}
    state.weaponHistory[row.id][#state.weaponHistory[row.id] + 1] = {
        id = #state.weaponHistory[row.id] + 1,
        weapon_id = row.id,
        action = data.action or 'transfer',
        from_owner_citizen_id = fromOwner,
        to_owner_citizen_id = nextOwnerCitizenId,
        officer_id = officerId,
        notes = data.notes,
        created_at = isoTimestamp(),
    }
    return true
end

function LocalMode.getWeaponAnalytics()
    local analytics = {
        total = 0,
        registered = 0,
        transferred = 0,
        seized = 0,
        evidence = 0,
        stolen = 0,
        destroyed = 0,
        recentTransfers = 0,
    }

    for _, row in pairs(state.weapons) do
        analytics.total = analytics.total + 1
        if analytics[row.status or ''] ~= nil then
            analytics[row.status] = analytics[row.status] + 1
        end
    end

    for _, history in pairs(state.weaponHistory) do
        for i = 1, #history do
            if history[i].action == 'transfer' then
                analytics.recentTransfers = analytics.recentTransfers + 1
            end
        end
    end

    return analytics
end

function LocalMode.getLeaderboard(period)
    local rows = {}
    local summary = {
        totalOfficers = 0,
        totalReports = 0,
        totalArrests = 0,
        averageActivity = 0,
    }

    for officerId, officer in pairs(state.officersById) do
        local reportsCount = 0
        local arrestsCount = 0
        for _, report in pairs(state.reports) do
            if tonumber(report.author_id or 0) == tonumber(officerId) then
                reportsCount = reportsCount + 1
            end
        end
        local activityScore = reportsCount * 10 + arrestsCount * 5
        rows[#rows + 1] = {
            officer_id = officerId,
            name = displayName(officer.first_name, officer.last_name, officer.source),
            callsign = officer.callsign,
            rank = officer.rank,
            department = officer.department,
            avatar = officer.avatar,
            reports_count = reportsCount,
            arrests_count = arrestsCount,
            activity_score = activityScore,
        }
        summary.totalOfficers = summary.totalOfficers + 1
        summary.totalReports = summary.totalReports + reportsCount
        summary.totalArrests = summary.totalArrests + arrestsCount
        summary.averageActivity = summary.averageActivity + activityScore
    end

    if summary.totalOfficers > 0 then
        summary.averageActivity = math.floor(summary.averageActivity / summary.totalOfficers)
    end

    local function topBy(key)
        local cloned = shallowArray(rows)
        table.sort(cloned, function(a, b)
            return tonumber(a[key] or 0) > tonumber(b[key] or 0)
        end)
        while #cloned > 10 do
            table.remove(cloned)
        end
        return cloned
    end

    return {
        period = period or 'week',
        generatedAt = isoTimestamp(),
        summary = summary,
        categories = {
            arrests = topBy('arrests_count'),
            reports = topBy('reports_count'),
            activity = topBy('activity_score'),
        },
    }
end

function LocalMode.getDashboard()
    local units = LocalMode.getUnits()
    local onDutyOfficers = {}
    local unitsOnDuty = 0
    local activeBolos = {}
    local recentReports = {}
    local activeWarrants = 0
    local openReports = 0

    for i = 1, #units do
        local unit = units[i]
        if lower(unit.status) ~= 'off_duty' then
            unitsOnDuty = unitsOnDuty + 1
            onDutyOfficers[#onDutyOfficers + 1] = {
                id = unit.officer_id,
                callsign = unit.callsign,
                status = unit.status,
                department = unit.department,
                first_name = unit.first_name,
                last_name = unit.last_name,
                rank = unit.rank,
                name = displayName(unit.first_name, unit.last_name),
            }
        end
    end

    for _, bolo in pairs(state.bolos) do
        if tostring(bolo.status or 'active') == 'active' then
            activeBolos[#activeBolos + 1] = clone(bolo)
        end
    end
    sortByCreatedDesc(activeBolos)
    while #activeBolos > 10 do
        table.remove(activeBolos)
    end

    for _, warrant in pairs(state.warrants) do
        if tostring(warrant.status or 'active') == 'active' then
            activeWarrants = activeWarrants + 1
        end
    end

    for _, report in pairs(state.reports) do
        local status = tostring(report.status or 'draft')
        if status == 'draft' or status == 'submitted' then
            openReports = openReports + 1
        end
        recentReports[#recentReports + 1] = {
            id = report.id,
            report_number = report.report_number,
            title = report.title,
            status = report.status,
            created_at = report.created_at,
            author = report.author,
            updated_sort = report.updated_sort,
        }
    end
    sortByUpdatedDesc(recentReports)
    while #recentReports > 6 do
        table.remove(recentReports)
    end

    return {
        motd = state.settings.motd or '',
        stats = {
            activeCalls = 0,
            openReports = openReports,
            activeWarrants = activeWarrants,
            unitsOnDuty = unitsOnDuty,
        },
        bolos = activeBolos,
        announcements = LocalMode.getAnnouncements(5),
        recentReports = recentReports,
        onDutyOfficers = onDutyOfficers,
        chatMessages = LocalMode.getChatMessages(50),
        dispatchCalls = {},
    }
end

function LocalMode.saveOfficerAvatar(source, avatarUrl)
    local officerId = LocalMode.getOfficerId(source)
    local officer = officerId and LocalMode.getOfficer(officerId) or nil
    if not officer then
        return false
    end

    local normalizedAvatar = trim(avatarUrl)
    officer.avatar = normalizedAvatar ~= '' and normalizedAvatar or nil

    return true
end

function LocalMode.handlePlayerDropped(source)
    local officerId = LocalMode.getOfficerId(source)
    local officer = officerId and LocalMode.getOfficer(officerId) or nil
    if officer then
        officer.source = nil
    end

    local unit = officerId and state.unitsByOfficerId[officerId] or nil
    if unit then
        unit.status = 'off_duty'
        unit.last_updated = isoTimestamp()
    end
end

local CITATIONS_STORAGE_KEY = 'cortex_mdt:citations'

function LocalMode.issueCitation(source, data)
    local reportId = tonumber(data and data.reportId)
    local citizenId = trim(data and data.citizenId)

    if not reportId or citizenId == '' then
        return { ok = false, error = 'Missing report ID or citizen ID.' }
    end

    local reportInfo = LocalMode.getReport(reportId)
    if not reportInfo or not reportInfo.report then
        return { ok = false, error = 'Report not found.' }
    end

    local report = reportInfo.report
    local charges = reportInfo.charges or {}
    local participants = reportInfo.participants or {}

    if #charges == 0 then
        return { ok = false, error = 'Report has no charges attached. Add charges first.' }
    end

    local recipientName = trim(data.playerName or data.player_name or '')
    if recipientName == '' then
        for i = 1, #participants do
            local p = participants[i]
            if trim(p.citizenId or p.citizen_id) == citizenId then
                recipientName = trim(p.name) ~= '' and trim(p.name) or citizenId
                break
            end
        end
    end
    if recipientName == '' then
        recipientName = fetchCitizenDisplayName(citizenId) or citizenId
    end

    local officerId = LocalMode.getOfficerId(source) or 0
    local officer = officerId > 0 and LocalMode.getOfficer(officerId) or nil
    local deptKey = officer and trim(officer.department) or 'police'
    local dept = (type(Config.Departments) == 'table' and Config.Departments[deptKey]) or Config.Departments['police'] or { label = 'Los Santos Police Department', short = 'LSPD' }

    local citationId = state.nextCitationId
    state.nextCitationId = state.nextCitationId + 1

    local totalFine = 0
    local serializedCharges = {}
    for i = 1, #charges do
        local c = charges[i]
        local count = tonumber(c.count or 1) or 1
        local fine = tonumber(c.fine or 0) or 0
        totalFine = totalFine + fine * count
        serializedCharges[#serializedCharges + 1] = {
            charge = trim(c.charge) ~= '' and trim(c.charge) or 'Violation',
            severity = trim(c.severity) ~= '' and trim(c.severity) or 'infraction',
            count = count,
            fine = fine,
            notes = trim(c.notes or ''),
        }
    end

    local citation = {
        id = citationId,
        citation_number = createNumber('CIT', citationId),
        report_number = report.report_number or ('RPT-' .. reportId),
        report_id = reportId,
        report_title = report.title or '',
        issued_by = {
            callsign = officer and trim(officer.callsign) or '',
            name = officer and displayName(officer.first_name, officer.last_name, source) or 'Unknown Officer',
            rank = officer and trim(officer.rank) or 'Officer',
            department = dept.label or 'Los Santos Police Department',
            department_short = dept.short or 'LSPD',
        },
        issued_to = {
            citizen_id = citizenId,
            name = recipientName,
        },
        issued_at = isoTimestamp(),
        issued_sort = epoch(),
        status = 'pending',
        charges = serializedCharges,
        total_fine = totalFine,
        notes = trim(data.notes or ''),
    }

    state.citations[citationId] = citation

    if Config.Citations and Config.Citations.persist ~= false then
        LocalStorage.set(CITATIONS_STORAGE_KEY, {
            nextCitationId = state.nextCitationId,
            citations = state.citations,
        })
    end

    LocalMode.auditLog(officerId, 'citation_issue', 'citation', 'citation', citationId, {
        report_id = reportId,
        citizen_id = citizenId,
        total_fine = totalFine,
    })

    return {
        ok = true,
        citation = clone(citation),
    }
end

function LocalMode.getCitationsForCitizen(citizenId)
    local results = {}
    for _, cit in pairs(state.citations) do
        if cit.issued_to and cit.issued_to.citizen_id == citizenId then
            results[#results + 1] = clone(cit)
        end
    end

    table.sort(results, function(a, b)
        return (a.issued_sort or 0) > (b.issued_sort or 0)
    end)

    return { ok = true, citations = results }
end

function LocalMode.getCitation(citationId)
    local cit = state.citations[tonumber(citationId) or -1]
    if not cit then
        return { ok = false, error = 'Citation not found.' }
    end

    return { ok = true, citation = clone(cit) }
end

function LocalMode.markCitationViewed(citationId)
    local cit = state.citations[tonumber(citationId) or -1]
    if not cit then
        return { ok = false, error = 'Citation not found.' }
    end

    if cit.status == 'pending' then
        cit.status = 'viewed'
        if Config.Citations and Config.Citations.persist ~= false then
            LocalStorage.set(CITATIONS_STORAGE_KEY, {
                nextCitationId = state.nextCitationId,
                citations = state.citations,
            })
        end
    end

    return { ok = true, citation = clone(cit) }
end

function LocalMode.restoreCitations()
    local stored = LocalStorage.get(CITATIONS_STORAGE_KEY)
    if type(stored) == 'table' then
        state.citations = type(stored.citations) == 'table' and stored.citations or {}
        local maxId = tonumber(stored.nextCitationId) or 1
        for _, cit in pairs(state.citations) do
            local cid = tonumber(cit.id)
            if cid and cid >= maxId then
                maxId = cid + 1
            end
        end
        state.nextCitationId = maxId
    end
end

function LocalMode.flushPersistentState()
    return flushDurableSnapshot()
end

local DURABLE_MUTATORS = {
    'ensureOfficer',
    'upsertOfficerUnitState',
    'updateOfficerAdmin',
    'auditLog',
    'updateSetting',
    'createAnnouncement',
    'deleteAnnouncement',
    'addChatMessage',
    'upsertExternalCitizen',
    'updateCitizen',
    'updateCitizenLicenses',
    'createLicenseType',
    'updateLicenseType',
    'deleteLicenseType',
    'upsertExternalVehicle',
    'impoundVehicle',
    'releaseImpound',
    'createReport',
    'updateReport',
    'addReportTimeline',
    'addReportEntity',
    'removeReportEntity',
    'createCase',
    'updateCase',
    'addCaseLink',
    'removeCaseLink',
    'addCasePersonnel',
    'removeCasePersonnel',
    'addAttachment',
    'removeAttachment',
    'createEvidence',
    'updateEvidence',
    'transferEvidence',
    'createBolo',
    'updateBoloStatus',
    'createWarrant',
    'updateWarrantStatus',
    'createWeapon',
    'updateWeapon',
    'transferWeapon',
    'saveOfficerAvatar',
    'handlePlayerDropped',
    'issueCitation',
    'markCitationViewed',
}

for i = 1, #DURABLE_MUTATORS do
    local methodName = DURABLE_MUTATORS[i]
    local original = LocalMode[methodName]
    if type(original) == 'function' then
        LocalMode[methodName] = function(...)
            local result = table.pack(original(...))
            markDurableSnapshotDirty()
            return table.unpack(result, 1, result.n)
        end
    end
end

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource == resourceName then
        flushDurableSnapshot()
    end
end)

_G.CortexLocalMode = LocalMode

return LocalMode
