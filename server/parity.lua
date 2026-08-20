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
    return fn()
end

local Store = loadResourceModule('server/storage/sessionStore.lua')
local publicComplaintBuckets = {}
local sessionActorIdentifiers = {}
local sessionActorSequence = 0

local FEATURES = {
    bulletins = true,
    awards = true,
    ia = true,
    ppr = true,
    court = true,
    sops = true,
    patrols = true,
}

local MANAGED_ONLY_CREATE = {
    bulletins = true,
    awards = true,
    court = true,
    sops = true,
    patrols = true,
}

local DEFAULT_SOPS = {
    {
        title = 'Use of Force and De-escalation',
        category = 'use-of-force',
        reference = 'SOP-UOF-1.0',
        content = 'Use only the objectively reasonable force needed to control the incident. When safe and feasible, create distance, use cover, communicate clearly, request appropriate resources, and document any force beyond compliant restraint before the end of shift.',
    },
    {
        title = 'Vehicle Pursuit',
        category = 'pursuit-policy',
        reference = 'SOP-PUR-1.0',
        content = 'Notify dispatch immediately, continuously balance the need to apprehend against public risk, obey supervisor direction, and terminate when conditions become disproportionate. File the pursuit report and document involved units, route, outcome, injuries, and property damage.',
    },
    {
        title = 'Evidence and Chain of Custody',
        category = 'evidence',
        reference = 'SOP-EVI-1.0',
        content = 'Photograph evidence before collection when practical. Package items separately, label the collector, time, location, and related case, then record every transfer. Digital originals must remain unaltered and access must be limited to personnel assigned to the investigation.',
    },
    {
        title = 'Arrest and Booking',
        category = 'arrest',
        reference = 'SOP-ARR-1.0',
        content = 'Confirm legal authority, search and transport safely, provide required warnings before custodial questioning, inventory property, document charges and force, and notify dispatch when booking is complete.',
    },
    {
        title = 'Traffic Stops',
        category = 'traffic',
        reference = 'SOP-TRF-1.0',
        content = 'Choose a safe stopping location, update dispatch with vehicle and occupancy information, maintain a defensible approach, explain enforcement action, and keep the bodycam active for the complete contact.',
    },
    {
        title = 'Internal Affairs Intake',
        category = 'professional-standards',
        reference = 'SOP-IA-1.0',
        content = 'Accept complaints without retaliation or discouragement. Preserve evidence, avoid assigning involved personnel as investigators, record each status change, and restrict complaint details to authorised professional-standards staff.',
    },
}

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function boundedString(value, maximum, fallback)
    local text = trim(value)
    if text == '' then
        return fallback or ''
    end
    if #text > maximum then
        text = text:sub(1, maximum)
    end
    return text
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

local function boundedArray(value, maximumItems, maximumLength)
    local result = {}
    if type(value) ~= 'table' then
        return result
    end
    for i = 1, math.min(#value, maximumItems) do
        local entry = boundedString(value[i], maximumLength, '')
        if entry ~= '' then
            result[#result + 1] = entry
        end
    end
    return result
end

local function boundedUrlArray(value, maximumItems, maximumLength)
    local result = {}
    if type(value) ~= 'table' then return result end
    for i = 1, math.min(#value, maximumItems) do
        local entry = boundedString(value[i], maximumLength, '')
        if entry:match('^https?://') then result[#result + 1] = entry end
    end
    return result
end

local function clone(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, entry in pairs(value) do copy[key] = clone(entry) end
    return copy
end

local function isoTimestamp()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function featureEnabled(kind)
    local cfg = type(Config.FeatureParity) == 'table' and Config.FeatureParity or {}
    local configured = type(cfg.features) == 'table' and cfg.features or {}
    return cfg.enabled ~= false and FEATURES[kind] == true and configured[kind] ~= false
end

local function normalizeDepartment(value)
    local key = boundedString(value, 48, ''):lower()
    if type(Config.DepartmentAliases) == 'table' and Config.DepartmentAliases[key] then
        key = boundedString(Config.DepartmentAliases[key], 48, key):lower()
    end
    return key ~= '' and key or 'police'
end

local function getStableIdentifier(source)
    return GetPlayerIdentifierByType(source, 'license')
        or GetPlayerIdentifierByType(source, 'fivem')
        or GetPlayerIdentifierByType(source, 'steam')
end

local function getActorIdentifier(source)
    local stable = getStableIdentifier(source)
    if stable and stable ~= '' then return stable end

    if not sessionActorIdentifiers[source] then
        sessionActorSequence = sessionActorSequence + 1
        sessionActorIdentifiers[source] = ('session:%x:%x:%x'):format(
            os.time(),
            sessionActorSequence,
            math.random(0, 0x7fffffff)
        )
    end
    return sessionActorIdentifiers[source]
end

local function getOfficer(source)
    local bridge = rawget(_G, 'CortexDutyBridge')
    local officer
    if type(bridge) == 'table' and type(bridge.buildOfficerProfile) == 'function' then
        local ok, result = pcall(bridge.buildOfficerProfile, source)
        if ok and type(result) == 'table' then officer = result end
    end
    officer = officer or {}
    local firstName = boundedString(officer.firstName or officer.first_name, 64, '')
    local lastName = boundedString(officer.lastName or officer.last_name, 64, '')
    local name = trim(('%s %s'):format(firstName, lastName))
    return {
        id = officer.officerId or officer.officer_id or officer.id,
        identifier = getActorIdentifier(source),
        name = name ~= '' and name or (GetPlayerName(source) or 'Unknown Officer'),
        callsign = boundedString(officer.callsign, 32, tostring(source)),
        rank = boundedString(officer.rank, 64, 'Officer'),
        department = normalizeDepartment(officer.departmentKey or officer.department),
        isAdmin = officer.isAdmin == true or officer.admin == true or officer.role == 'admin',
        permissions = type(officer.permissions) == 'table' and clone(officer.permissions) or {},
    }
end

local function canManage(source)
    local access = rawget(_G, 'CortexMdtAccess')
    if type(access) == 'table' and type(access.isAdmin) == 'function' then
        local ok, allowed = pcall(access.isAdmin, source)
        if ok and allowed == true then return true end
    end

    local officer = getOfficer(source)
    if officer.isAdmin then return true end
    local permissions = officer.permissions
    if type(permissions) == 'table'
        and (permissions['mdt.manage'] == true or permissions['cortex_mdt.manage'] == true or permissions.command == true) then
        return true
    end

    local cfg = type(Config.FeatureParity) == 'table' and Config.FeatureParity or {}
    local ace = boundedString(cfg.manageAce, 96, '')
    return ace ~= '' and IsPlayerAceAllowed(source, ace)
end

local function featureNamespace(kind)
    return ('parity:%s'):format(kind)
end

local function departmentsShare(viewerDepartment, targetDepartment, kind)
    if viewerDepartment == targetDepartment then return true end
    local sharing = type(Config.DepartmentSharing) == 'table' and Config.DepartmentSharing or {}

    for _, group in ipairs(type(sharing.mutual) == 'table' and sharing.mutual or {}) do
        local departments = type(group.departments) == 'table' and group.departments or {}
        local features = type(group.features) == 'table' and group.features or {}
        local hasViewer, hasTarget, hasFeature = false, false, #features == 0
        for i = 1, #departments do
            local department = normalizeDepartment(departments[i])
            if department == viewerDepartment then hasViewer = true end
            if department == targetDepartment then hasTarget = true end
        end
        for i = 1, #features do if features[i] == kind then hasFeature = true break end end
        if hasViewer and hasTarget and hasFeature then return true end
    end

    for _, rule in ipairs(type(sharing.oneWay) == 'table' and sharing.oneWay or {}) do
        local hasViewer, hasTarget, hasFeature = false, false, false
        for i = 1, #(rule.viewers or {}) do if normalizeDepartment(rule.viewers[i]) == viewerDepartment then hasViewer = true break end end
        for i = 1, #(rule.targets or {}) do if normalizeDepartment(rule.targets[i]) == targetDepartment then hasTarget = true break end end
        for i = 1, #(rule.features or {}) do if rule.features[i] == kind then hasFeature = true break end end
        if hasViewer and hasTarget and hasFeature then return true end
    end

    return false
end

local function canViewRecord(source, actor, record, kind)
    if canManage(source) then return true end
    if record.visibility == 'all' then return true end
    if record.visibility == 'management' then
        return record.createdBy and record.createdBy.identifier == actor.identifier
    end
    return departmentsShare(actor.department, normalizeDepartment(record.department), kind)
end

local function sanitizePayload(payload, existing)
    payload = type(payload) == 'table' and payload or {}
    existing = type(existing) == 'table' and existing or {}
    local row = clone(existing)

    row.title = boundedString(payload.title ~= nil and payload.title or row.title, 160, '')
    row.content = boundedString(payload.content ~= nil and payload.content or row.content, 12000, '')
    row.summary = boundedString(payload.summary ~= nil and payload.summary or row.summary, 1200, '')
    row.category = boundedString(payload.category ~= nil and payload.category or row.category, 64, 'general'):lower()
    row.status = boundedString(payload.status ~= nil and payload.status or row.status, 32, 'open'):lower()
    row.priority = boundedString(payload.priority ~= nil and payload.priority or row.priority, 24, 'normal'):lower()
    row.subjectName = boundedString(payload.subjectName ~= nil and payload.subjectName or row.subjectName, 160, '')
    row.subjectId = boundedString(payload.subjectId ~= nil and payload.subjectId or row.subjectId, 96, '')
    row.assignee = boundedString(payload.assignee ~= nil and payload.assignee or row.assignee, 160, '')
    row.reference = boundedString(payload.reference ~= nil and payload.reference or row.reference, 96, '')
    row.location = boundedString(payload.location ~= nil and payload.location or row.location, 180, '')
    row.scheduledAt = boundedString(payload.scheduledAt ~= nil and payload.scheduledAt or row.scheduledAt, 48, '')
    row.incidentAt = boundedString(payload.incidentAt ~= nil and payload.incidentAt or row.incidentAt, 48, '')
    row.reporterContact = boundedString(payload.reporterContact ~= nil and payload.reporterContact or row.reporterContact, 160, '')
    row.witnesses = boundedString(payload.witnesses ~= nil and payload.witnesses or row.witnesses, 1600, '')
    row.visibility = boundedString(payload.visibility ~= nil and payload.visibility or row.visibility, 24, 'department'):lower()
    if row.visibility ~= 'all' and row.visibility ~= 'department' and row.visibility ~= 'management' then
        row.visibility = 'department'
    end
    row.score = finiteNumber(payload.score ~= nil and payload.score or row.score, 0, 10, nil)
    row.radius = finiteNumber(payload.radius ~= nil and payload.radius or row.radius, 25, 5000, nil)
    if payload.pinned ~= nil then
        row.pinned = payload.pinned == true
    else
        row.pinned = row.pinned == true
    end
    row.tags = payload.tags ~= nil and boundedArray(payload.tags, 16, 48) or clone(row.tags or {})
    row.audience = payload.audience ~= nil and boundedArray(payload.audience, 16, 48) or clone(row.audience or {})
    row.evidence = payload.evidence ~= nil and boundedUrlArray(payload.evidence, 8, 512) or clone(row.evidence or {})

    local coords = payload.coords ~= nil and payload.coords or row.coords
    if type(coords) == 'table' then
        local x = finiteNumber(coords.x or coords[1], -10000, 10000, nil)
        local y = finiteNumber(coords.y or coords[2], -10000, 10000, nil)
        local z = finiteNumber(coords.z or coords[3], -2000, 3000, nil)
        row.coords = x and y and z and { x = x, y = y, z = z } or nil
    end

    return row
end

local function audit(source, action, kind, recordId, details)
    local auditApi = rawget(_G, 'CortexAudit')
    if type(auditApi) ~= 'table' or type(auditApi.write) ~= 'function' then return end
    local actor = getOfficer(source)
    auditApi.write(actor.id or 0, action, kind, kind, recordId, details, { officer = actor, source = source })
end

local function listRecords(source, kind, filter)
    if not featureEnabled(kind) then return {} end
    local actor = getOfficer(source)
    local query = boundedString(type(filter) == 'table' and filter.query or '', 96, ''):lower()
    local status = boundedString(type(filter) == 'table' and filter.status or '', 32, ''):lower()
    local rows = {}

    for _, record in ipairs(Store.list(featureNamespace(kind))) do
        if type(record) == 'table' and canViewRecord(source, actor, record, kind) then
            local haystack = ('%s %s %s %s %s'):format(record.title or '', record.summary or '', record.content or '', record.subjectName or '', record.reference or ''):lower()
            if (query == '' or haystack:find(query, 1, true)) and (status == '' or status == 'all' or record.status == status) then
                rows[#rows + 1] = clone(record)
            end
        end
    end

    table.sort(rows, function(left, right)
        if left.pinned ~= right.pinned then return left.pinned == true end
        return tostring(left.updatedAt or left.createdAt or '') > tostring(right.updatedAt or right.createdAt or '')
    end)

    local limit = finiteNumber(type(filter) == 'table' and filter.limit or nil, 1, 250, 100)
    while #rows > limit do table.remove(rows) end
    return rows
end

local function seedSops()
    if #Store.list(featureNamespace('sops')) > 0 then return end
    local now = isoTimestamp()
    for i = 1, #DEFAULT_SOPS do
        local row = sanitizePayload(DEFAULT_SOPS[i])
        row.id = Store.nextId('sop')
        row.kind = 'sops'
        row.department = 'police'
        row.visibility = 'all'
        row.status = 'active'
        row.version = 1
        row.createdAt = now
        row.updatedAt = now
        row.createdBy = { identifier = 'system', name = 'Cortex MDT', callsign = 'SYSTEM', rank = 'System' }
        Store.set(featureNamespace('sops'), row.id, row)
    end
end

seedSops()

lib.callback.register('cortex_mdt:getFeatureRecords', function(source, data)
    local kind = boundedString(type(data) == 'table' and data.kind or '', 24, ''):lower()
    if not featureEnabled(kind) then return { ok = false, error = 'Feature is disabled or invalid.' } end
    return {
        ok = true,
        kind = kind,
        records = listRecords(source, kind, data),
        canManage = canManage(source),
    }
end)

lib.callback.register('cortex_mdt:createFeatureRecord', function(source, data)
    local kind = boundedString(type(data) == 'table' and data.kind or '', 24, ''):lower()
    if not featureEnabled(kind) then return { ok = false, error = 'Feature is disabled or invalid.' } end
    if MANAGED_ONLY_CREATE[kind] and not canManage(source) then
        return { ok = false, error = 'Management permission is required.' }
    end

    local cfg = type(Config.FeatureParity) == 'table' and Config.FeatureParity or {}
    local maximum = math.max(50, math.min(10000, tonumber(cfg.maxRecordsPerFeature) or 2000))
    if #Store.list(featureNamespace(kind)) >= maximum then
        return { ok = false, error = 'This feature has reached its configured record limit.' }
    end

    local actor = getOfficer(source)
    local record = sanitizePayload(data)
    if record.title == '' then return { ok = false, error = 'A title is required.' } end
    record.id = Store.nextId(kind:sub(1, 4))
    record.kind = kind
    record.department = actor.department
    record.createdBy = actor
    record.createdAt = isoTimestamp()
    record.updatedAt = record.createdAt
    record.version = 1
    Store.set(featureNamespace(kind), record.id, record)
    audit(source, ('%s_create'):format(kind), kind, record.id, { title = record.title })
    return { ok = true, record = clone(record), canManage = canManage(source) }
end)

lib.callback.register('cortex_mdt:updateFeatureRecord', function(source, data)
    local kind = boundedString(type(data) == 'table' and data.kind or '', 24, ''):lower()
    local id = boundedString(type(data) == 'table' and data.id or '', 64, '')
    if not featureEnabled(kind) or id == '' then return { ok = false, error = 'Invalid record.' } end
    if not canManage(source) then return { ok = false, error = 'Management permission is required.' } end

    local existing = Store.get(featureNamespace(kind), id)
    if type(existing) ~= 'table' then return { ok = false, error = 'Record not found.' } end
    local expectedVersion = tonumber(data.version)
    if expectedVersion and expectedVersion ~= tonumber(existing.version) then
        return { ok = false, error = 'This record changed elsewhere. Refresh and try again.', code = 'version_conflict', record = clone(existing) }
    end

    local record = sanitizePayload(data, existing)
    if record.title == '' then return { ok = false, error = 'A title is required.' } end
    record.id = existing.id
    record.kind = kind
    record.department = existing.department
    record.createdBy = existing.createdBy
    record.createdAt = existing.createdAt
    record.updatedAt = isoTimestamp()
    record.updatedBy = getOfficer(source)
    record.version = (tonumber(existing.version) or 0) + 1
    Store.set(featureNamespace(kind), id, record)
    audit(source, ('%s_update'):format(kind), kind, id, { title = record.title, version = record.version })
    return { ok = true, record = clone(record) }
end)

lib.callback.register('cortex_mdt:deleteFeatureRecord', function(source, data)
    local kind = boundedString(type(data) == 'table' and data.kind or '', 24, ''):lower()
    local id = boundedString(type(data) == 'table' and data.id or '', 64, '')
    if not featureEnabled(kind) or id == '' then return { ok = false, error = 'Invalid record.' } end
    if not canManage(source) then return { ok = false, error = 'Management permission is required.' } end
    if not Store.get(featureNamespace(kind), id) then return { ok = false, error = 'Record not found.' } end
    Store.delete(featureNamespace(kind), id)
    audit(source, ('%s_delete'):format(kind), kind, id, nil)
    return { ok = true }
end)

lib.callback.register('cortex_mdt:acknowledgeSop', function(source, data)
    local sopId = boundedString(type(data) == 'table' and data.id or '', 64, '')
    local sop = Store.get(featureNamespace('sops'), sopId)
    if type(sop) ~= 'table' or sop.status == 'archived' then return { ok = false, error = 'SOP not found.' } end
    local actor = getOfficer(source)
    local key = ('%s:%s'):format(sopId, actor.identifier)
    local acknowledgement = {
        id = key,
        sopId = sopId,
        sopVersion = tonumber(sop.version) or 1,
        officer = actor,
        acknowledgedAt = isoTimestamp(),
    }
    Store.set('parity:sop_acknowledgements', key, acknowledgement)
    audit(source, 'sop_acknowledge', 'sops', sopId, { version = sop.reference })
    return { ok = true, acknowledgement = acknowledgement }
end)

lib.callback.register('cortex_mdt:getSopAcknowledgements', function(source, data)
    local actor = getOfficer(source)
    local includeAll = canManage(source) and type(data) == 'table' and data.includeAll == true
    local acknowledgements = {}
    for _, row in ipairs(Store.list('parity:sop_acknowledgements')) do
        if includeAll or (row.officer and row.officer.identifier == actor.identifier) then
            acknowledgements[#acknowledgements + 1] = clone(row)
        end
    end
    return { ok = true, acknowledgements = acknowledgements, canManage = canManage(source) }
end)

lib.callback.register('cortex_mdt:submitPublicComplaint', function(source, data)
    if not featureEnabled('ia') then return { ok = false, error = 'Complaint intake is disabled.' } end
    local now = GetGameTimer()
    local last = publicComplaintBuckets[source]
    if last and now >= last and now - last < 30000 then
        return { ok = false, error = 'Please wait before submitting another complaint.', code = 'rate_limited' }
    end

    local reporterName = boundedString(type(data) == 'table' and data.reporterName or '', 120, '')
    local subjectName = boundedString(type(data) == 'table' and data.subjectName or '', 160, '')
    local content = boundedString(type(data) == 'table' and data.content or '', 12000, '')
    if reporterName == '' or #content < 20 then
        return { ok = false, error = 'Your name and at least 20 characters of complaint details are required.' }
    end

    publicComplaintBuckets[source] = now
    local record = sanitizePayload({
        title = ('Civilian complaint: %s'):format(subjectName ~= '' and subjectName or 'Unidentified personnel'),
        subjectName = subjectName,
        subjectId = boundedString(data and data.subjectId, 96, ''),
        category = boundedString(data and data.category, 64, 'conduct'),
        summary = boundedString(data and data.summary, 1200, ''),
        content = content,
        location = boundedString(data and data.location, 180, ''),
        incidentAt = boundedString(data and data.incidentAt, 48, ''),
        reporterContact = boundedString(data and data.reporterContact, 160, ''),
        witnesses = boundedString(data and data.witnesses, 1600, ''),
        evidence = type(data) == 'table' and data.evidence or {},
        status = 'open',
        priority = 'normal',
        visibility = 'management',
    })
    record.id = Store.nextId('ia')
    record.kind = 'ia'
    record.department = normalizeDepartment(data and data.department)
    record.createdBy = {
        identifier = getActorIdentifier(source),
        name = reporterName,
        callsign = 'PUBLIC',
        rank = 'Civilian',
    }
    record.createdAt = isoTimestamp()
    record.updatedAt = record.createdAt
    record.version = 1
    Store.set(featureNamespace('ia'), record.id, record)
    return { ok = true, complaintId = record.id }
end)

AddEventHandler('playerDropped', function()
    publicComplaintBuckets[source] = nil
    sessionActorIdentifiers[source] = nil
end)

local Parity = {}

function Parity.listSops(source)
    return listRecords(source, 'sops', { limit = 250 })
end

function Parity.getCapabilities(source)
    local enabled = {}
    for kind in pairs(FEATURES) do enabled[kind] = featureEnabled(kind) end
    return { enabled = enabled, canManage = canManage(source) }
end

_G.CortexMdtParity = Parity
