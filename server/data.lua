local ActiveOfficers = {}

local function getOfficerId(src)
    local identifier = GetPlayerIdentifierByType(src, 'license') or GetPlayerIdentifierByType(src, 'steam') or tostring(src)
    local result = MySQL.query.await('SELECT id FROM mdt_officers WHERE identifier = ?', { identifier })
    if result and result[1] then
        return result[1].id
    end
    return nil
end

local function ensureOfficer(src, data)
    local identifier = GetPlayerIdentifierByType(src, 'license') or GetPlayerIdentifierByType(src, 'steam') or tostring(src)
    local existing = MySQL.query.await('SELECT id FROM mdt_officers WHERE identifier = ?', { identifier })
    if existing and existing[1] then
        MySQL.update.await('UPDATE mdt_officers SET first_name = ?, last_name = ?, callsign = ?, `rank` = ?, department = ? WHERE id = ?', {
            data.firstName or '', data.lastName or '', data.callsign or '', data.rank or 'Officer', data.departmentKey or 'police', existing[1].id
        })
        return existing[1].id
    end
    local id = MySQL.insert.await('INSERT INTO mdt_officers (identifier, first_name, last_name, callsign, `rank`, department) VALUES (?, ?, ?, ?, ?, ?)', {
        identifier, data.firstName or '', data.lastName or '', data.callsign or '', data.rank or 'Officer', data.departmentKey or 'police'
    })
    return id
end

local function auditLog(officerId, action, category, targetType, targetId, details)
    MySQL.insert('INSERT INTO mdt_audit_logs (officer_id, action, category, target_type, target_id, details) VALUES (?, ?, ?, ?, ?, ?)', {
        officerId or 0, action, category or 'general', targetType, targetId, details and json.encode(details) or nil
    })
end

local function generateNumber(prefix)
    local ts = os.time()
    local rand = math.random(1000, 9999)
    return ('%s-%s-%d'):format(prefix, os.date('%Y%m%d', ts), rand)
end

local function getSetting(key)
    local result = MySQL.query.await('SELECT `value` FROM mdt_settings WHERE `key` = ?', { key })
    if result and result[1] then return result[1].value end
    return nil
end

RegisterNUICallback('cortex_mdt:registerOfficer', function(data, cb)
    local src = source
    if not data or type(data) ~= 'table' then
        cb({ ok = false })
        return
    end
    local officerId = ensureOfficer(src, data)
    cb({ ok = true, officerId = officerId })
end)

RegisterNUICallback('cortex_mdt:getDashboard', function(_, cb)
    local src = source
    local officerId = getOfficerId(src) or 0

    local motd = getSetting('motd') or 'Welcome to the Cortex MDT.'
    local openReports = MySQL.query.await('SELECT COUNT(*) as cnt FROM mdt_reports WHERE status IN ("draft","submitted")') or {}
    local activeWarrants = MySQL.query.await('SELECT COUNT(*) as cnt FROM mdt_warrants WHERE status = "active"') or {}
    local unitsOnDuty = MySQL.query.await('SELECT COUNT(*) as cnt FROM mdt_units WHERE status != "off_duty"') or {}

    local bolos = MySQL.query.await('SELECT b.*, o.first_name, o.last_name FROM mdt_bolos b LEFT JOIN mdt_officers o ON b.issued_by = o.id WHERE b.status = "active" ORDER BY b.created_at DESC LIMIT 10') or {}
    local announcements = MySQL.query.await('SELECT a.*, o.first_name, o.last_name FROM mdt_announcements a LEFT JOIN mdt_officers o ON a.author_id = o.id WHERE a.active = 1 ORDER BY a.pinned DESC, a.created_at DESC LIMIT 5') or {}

    cb({
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
    })
end)

RegisterNUICallback('cortex_mdt:globalSearch', function(data, cb)
    local src = source
    local query = data and data.query or ''
    if #query < 2 then
        cb({ ok = true, results = {} })
        return
    end

    local officerId = getOfficerId(src) or 0
    auditLog(officerId, 'global_search', 'search', nil, nil, { query = query })

    local pattern = '%' .. query .. '%'
    local citizens = MySQL.query.await('SELECT id, citizen_id, first_name, last_name, dob FROM mdt_citizens WHERE first_name LIKE ? OR last_name LIKE ? OR citizen_id LIKE ? LIMIT 5', { pattern, pattern, pattern }) or {}
    local vehicles = MySQL.query.await('SELECT id, plate, model, owner_citizen_id FROM mdt_vehicles WHERE plate LIKE ? OR model LIKE ? LIMIT 5', { pattern, pattern }) or {}
    local reports = MySQL.query.await('SELECT id, report_number, title, status FROM mdt_reports WHERE report_number LIKE ? OR title LIKE ? LIMIT 5', { pattern, pattern }) or {}
    local cases = MySQL.query.await('SELECT id, case_number, title, status FROM mdt_cases WHERE case_number LIKE ? OR title LIKE ? LIMIT 5', { pattern, pattern }) or {}

    cb({
        ok = true,
        results = { citizens = citizens, vehicles = vehicles, reports = reports, cases = cases },
    })
end)

RegisterNUICallback('cortex_mdt:searchCitizens', function(data, cb)
    local src = source
    local query = data and data.query or ''
    local officerId = getOfficerId(src) or 0
    auditLog(officerId, 'citizen_search', 'search', nil, nil, { query = query })

    if #query < 1 then
        cb({ ok = true, citizens = {} })
        return
    end

    local pattern = '%' .. query .. '%'
    local results = MySQL.query.await('SELECT * FROM mdt_citizens WHERE first_name LIKE ? OR last_name LIKE ? OR citizen_id LIKE ? OR fingerprint LIKE ? ORDER BY last_name ASC LIMIT 25', { pattern, pattern, pattern, pattern }) or {}

    for i = 1, #results do
        results[i].flags = json.decode(results[i].flags) or {}
    end

    cb({ ok = true, citizens = results })
end)

RegisterNUICallback('cortex_mdt:getCitizen', function(data, cb)
    local src = source
    local citizenId = data and data.citizenId
    if not citizenId then cb({ ok = false }) return end

    local officerId = getOfficerId(src) or 0
    auditLog(officerId, 'citizen_view', 'citizen', 'citizen', nil, { citizenId = citizenId })

    local citizen = MySQL.query.await('SELECT * FROM mdt_citizens WHERE citizen_id = ?', { citizenId })
    if not citizen or not citizen[1] then cb({ ok = false }) return end

    local c = citizen[1]
    c.flags = json.decode(c.flags) or {}

    local vehicles = MySQL.query.await('SELECT * FROM mdt_vehicles WHERE owner_citizen_id = ?', { citizenId }) or {}
    local licenses = MySQL.query.await('SELECT * FROM mdt_citizen_licenses WHERE citizen_id = ?', { citizenId }) or {}
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
        vehicles[i].flags = json.decode(vehicles[i].flags) or {}
    end
    for i = 1, #warrants do
        warrants[i].charges = json.decode(warrants[i].charges) or {}
    end

    cb({
        ok = true,
        citizen = c,
        vehicles = vehicles,
        licenses = licenses,
        reports = reportEntities,
        warrants = warrants,
        bolos = bolos,
    })
end)

RegisterNUICallback('cortex_mdt:updateCitizen', function(data, cb)
    local src = source
    if not data or not data.citizenId then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    MySQL.update.await('UPDATE mdt_citizens SET mugshot = ?, flags = ?, notes = ? WHERE citizen_id = ?', {
        data.mugshot or nil, json.encode(data.flags or {}), data.notes or nil, data.citizenId,
    })
    auditLog(officerId, 'citizen_update', 'citizen', 'citizen', nil, { citizenId = data.citizenId })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:searchVehicles', function(data, cb)
    local src = source
    local query = data and data.query or ''
    local officerId = getOfficerId(src) or 0
    auditLog(officerId, 'vehicle_search', 'search', nil, nil, { query = query })

    if #query < 1 then
        cb({ ok = true, vehicles = {} })
        return
    end

    local pattern = '%' .. query .. '%'
    local results = MySQL.query.await([[
        SELECT v.*, c.first_name as owner_first, c.last_name as owner_last
        FROM mdt_vehicles v
        LEFT JOIN mdt_citizens c ON v.owner_citizen_id = c.citizen_id
        WHERE v.plate LIKE ? OR v.vin LIKE ? OR v.model LIKE ?
        ORDER BY v.plate ASC LIMIT 25
    ]], { pattern, pattern, pattern }) or {}

    for i = 1, #results do
        results[i].flags = json.decode(results[i].flags) or {}
    end

    cb({ ok = true, vehicles = results })
end)

RegisterNUICallback('cortex_mdt:getVehicle', function(data, cb)
    local src = source
    local vehicleId = data and data.vehicleId
    if not vehicleId then cb({ ok = false }) return end

    local officerId = getOfficerId(src) or 0
    auditLog(officerId, 'vehicle_view', 'vehicle', 'vehicle', vehicleId, nil)

    local vehicle = MySQL.query.await([[
        SELECT v.*, c.first_name as owner_first, c.last_name as owner_last, c.citizen_id as owner_cid
        FROM mdt_vehicles v
        LEFT JOIN mdt_citizens c ON v.owner_citizen_id = c.citizen_id
        WHERE v.id = ?
    ]], { vehicleId })
    if not vehicle or not vehicle[1] then cb({ ok = false }) return end

    local v = vehicle[1]
    v.flags = json.decode(v.flags) or {}

    local impounds = MySQL.query.await([[
        SELECT i.*, o.first_name as officer_first, o.last_name as officer_last
        FROM mdt_impounds i
        LEFT JOIN mdt_officers o ON i.officer_id = o.id
        WHERE i.vehicle_id = ?
        ORDER BY i.created_at DESC
    ]], { vehicleId }) or {}

    cb({ ok = true, vehicle = v, impounds = impounds })
end)

RegisterNUICallback('cortex_mdt:impoundVehicle', function(data, cb)
    local src = source
    if not data or not data.vehicleId then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    local vehicle = MySQL.query.await('SELECT plate FROM mdt_vehicles WHERE id = ?', { data.vehicleId })
    if not vehicle or not vehicle[1] then cb({ ok = false }) return end

    local holdUntil = nil
    if data.holdHours and data.holdHours > 0 then
        holdUntil = os.date('%Y-%m-%d %H:%M:%S', os.time() + (data.holdHours * 3600))
    end

    MySQL.insert.await('INSERT INTO mdt_impounds (vehicle_id, plate, officer_id, reason, lot_location, fee, hold_until) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        data.vehicleId, vehicle[1].plate, officerId, data.reason or '', data.lotLocation or 'Downtown Lot', data.fee or 0, holdUntil
    })
    MySQL.update.await('UPDATE mdt_vehicles SET registration_status = "suspended" WHERE id = ?', { data.vehicleId })

    auditLog(officerId, 'vehicle_impound', 'vehicle', 'vehicle', data.vehicleId, { fee = data.fee, lot = data.lotLocation })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:releaseImpound', function(data, cb)
    local src = source
    if not data or not data.impoundId then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    MySQL.update.await('UPDATE mdt_impounds SET status = "released", released_by = ?, released_at = NOW() WHERE id = ?', { officerId, data.impoundId })
    local impound = MySQL.query.await('SELECT vehicle_id FROM mdt_impounds WHERE id = ?', { data.impoundId })
    if impound and impound[1] then
        MySQL.update.await('UPDATE mdt_vehicles SET registration_status = "valid" WHERE id = ?', { impound[1].vehicle_id })
    end

    auditLog(officerId, 'impound_release', 'vehicle', 'impound', data.impoundId, nil)
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:getReports', function(data, cb)
    local src = source
    local page = (data and data.page) or 1
    local limit = 20
    local offset = (page - 1) * limit
    local filter = data and data.filter or 'all'

    local where = ''
    if filter == 'mine' then
        local officerId = getOfficerId(src) or 0
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

    cb({ ok = true, reports = reports, total = total, page = page })
end)

RegisterNUICallback('cortex_mdt:getReport', function(data, cb)
    local src = source
    local reportId = data and data.reportId
    if not reportId then cb({ ok = false }) return end

    local officerId = getOfficerId(src) or 0
    auditLog(officerId, 'report_view', 'report', 'report', reportId, nil)

    local report = MySQL.query.await([[
        SELECT r.*, o.first_name as author_first, o.last_name as author_last
        FROM mdt_reports r LEFT JOIN mdt_officers o ON r.author_id = o.id
        WHERE r.id = ?
    ]], { reportId })
    if not report or not report[1] then cb({ ok = false }) return end

    local r = report[1]
    r.tags = json.decode(r.tags) or {}
    r.restricted_to = json.decode(r.restricted_to) or {}

    local timeline = MySQL.query.await([[
        SELECT t.*, o.first_name, o.last_name FROM mdt_report_timeline t
        LEFT JOIN mdt_officers o ON t.author_id = o.id
        WHERE t.report_id = ? ORDER BY t.timestamp ASC
    ]], { reportId }) or {}

    local entities = MySQL.query.await('SELECT * FROM mdt_report_entities WHERE report_id = ?', { reportId }) or {}
    local collaborators = MySQL.query.await([[
        SELECT rc.officer_id, o.first_name, o.last_name, o.callsign
        FROM mdt_report_collaborators rc LEFT JOIN mdt_officers o ON rc.officer_id = o.id
        WHERE rc.report_id = ?
    ]], { reportId }) or {}

    cb({ ok = true, report = r, timeline = timeline, entities = entities, collaborators = collaborators })
end)

RegisterNUICallback('cortex_mdt:createReport', function(data, cb)
    local src = source
    if not data or not data.title then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    local prefix = getSetting('report_prefix') or 'RPT'
    local reportNumber = generateNumber(prefix)
    local officer = MySQL.query.await('SELECT department FROM mdt_officers WHERE id = ?', { officerId })
    local dept = (officer and officer[1] and officer[1].department) or 'police'

    local id = MySQL.insert.await('INSERT INTO mdt_reports (report_number, title, template, narrative, author_id, department, tags) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        reportNumber, data.title, data.template or 'general', data.narrative or '', officerId, dept, json.encode(data.tags or {})
    })

    auditLog(officerId, 'report_create', 'report', 'report', id, { number = reportNumber })
    cb({ ok = true, reportId = id, reportNumber = reportNumber })
end)

RegisterNUICallback('cortex_mdt:updateReport', function(data, cb)
    local src = source
    if not data or not data.reportId then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    MySQL.update.await('UPDATE mdt_reports SET title = ?, narrative = ?, status = ?, tags = ?, priority = ?, restricted = ?, restricted_to = ? WHERE id = ?', {
        data.title or '', data.narrative or '', data.status or 'draft',
        json.encode(data.tags or {}), data.priority or 'normal',
        data.restricted and 1 or 0, json.encode(data.restrictedTo or {}), data.reportId
    })

    auditLog(officerId, 'report_update', 'report', 'report', data.reportId, nil)
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:addReportTimeline', function(data, cb)
    local src = source
    if not data or not data.reportId or not data.description then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    MySQL.insert.await('INSERT INTO mdt_report_timeline (report_id, timestamp, description, author_id) VALUES (?, ?, ?, ?)', {
        data.reportId, data.timestamp or os.date('%H:%M:%S'), data.description, officerId
    })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:addReportEntity', function(data, cb)
    if not data or not data.reportId or not data.entityType or not data.entityId then cb({ ok = false }) return end
    MySQL.insert.await('INSERT IGNORE INTO mdt_report_entities (report_id, entity_type, entity_id, role) VALUES (?, ?, ?, ?)', {
        data.reportId, data.entityType, data.entityId, data.role or 'involved'
    })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:removeReportEntity', function(data, cb)
    if not data or not data.id then cb({ ok = false }) return end
    MySQL.update.await('DELETE FROM mdt_report_entities WHERE id = ?', { data.id })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:getCases', function(data, cb)
    local page = (data and data.page) or 1
    local limit = 20
    local offset = (page - 1) * limit

    local cases = MySQL.query.await([[
        SELECT c.*, o.first_name as lead_first, o.last_name as lead_last
        FROM mdt_cases c LEFT JOIN mdt_officers o ON c.lead_officer_id = o.id
        ORDER BY c.updated_at DESC LIMIT ? OFFSET ?
    ]], { limit, offset }) or {}

    local countResult = MySQL.query.await('SELECT COUNT(*) as cnt FROM mdt_cases') or {}
    local total = (countResult[1] and countResult[1].cnt) or 0

    cb({ ok = true, cases = cases, total = total, page = page })
end)

RegisterNUICallback('cortex_mdt:getCase', function(data, cb)
    local src = source
    local caseId = data and data.caseId
    if not caseId then cb({ ok = false }) return end

    local officerId = getOfficerId(src) or 0
    auditLog(officerId, 'case_view', 'case', 'case', caseId, nil)

    local caseData = MySQL.query.await([[
        SELECT c.*, o.first_name as lead_first, o.last_name as lead_last
        FROM mdt_cases c LEFT JOIN mdt_officers o ON c.lead_officer_id = o.id
        WHERE c.id = ?
    ]], { caseId })
    if not caseData or not caseData[1] then cb({ ok = false }) return end

    local personnel = MySQL.query.await([[
        SELECT cp.*, o.first_name, o.last_name, o.callsign, o.`rank`
        FROM mdt_case_personnel cp LEFT JOIN mdt_officers o ON cp.officer_id = o.id
        WHERE cp.case_id = ?
    ]], { caseId }) or {}

    local links = MySQL.query.await('SELECT * FROM mdt_case_links WHERE case_id = ?', { caseId }) or {}

    cb({ ok = true, ['case'] = caseData[1], personnel = personnel, links = links })
end)

RegisterNUICallback('cortex_mdt:createCase', function(data, cb)
    local src = source
    if not data or not data.title then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    local prefix = getSetting('case_prefix') or 'CASE'
    local caseNumber = generateNumber(prefix)
    local officer = MySQL.query.await('SELECT department FROM mdt_officers WHERE id = ?', { officerId })
    local dept = (officer and officer[1] and officer[1].department) or 'police'

    local id = MySQL.insert.await('INSERT INTO mdt_cases (case_number, title, description, lead_officer_id, department, priority) VALUES (?, ?, ?, ?, ?, ?)', {
        caseNumber, data.title, data.description or '', officerId, dept, data.priority or 'normal'
    })
    MySQL.insert.await('INSERT INTO mdt_case_personnel (case_id, officer_id, role) VALUES (?, ?, ?)', { id, officerId, 'lead' })

    auditLog(officerId, 'case_create', 'case', 'case', id, { number = caseNumber })
    cb({ ok = true, caseId = id, caseNumber = caseNumber })
end)

RegisterNUICallback('cortex_mdt:updateCase', function(data, cb)
    local src = source
    if not data or not data.caseId then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    MySQL.update.await('UPDATE mdt_cases SET title = ?, description = ?, status = ?, priority = ?, restricted = ? WHERE id = ?', {
        data.title or '', data.description or '', data.status or 'open', data.priority or 'normal', data.restricted and 1 or 0, data.caseId
    })
    auditLog(officerId, 'case_update', 'case', 'case', data.caseId, nil)
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:addCaseLink', function(data, cb)
    if not data or not data.caseId or not data.entityType or not data.entityId then cb({ ok = false }) return end
    MySQL.insert.await('INSERT IGNORE INTO mdt_case_links (case_id, entity_type, entity_id) VALUES (?, ?, ?)', {
        data.caseId, data.entityType, data.entityId
    })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:removeCaseLink', function(data, cb)
    if not data or not data.id then cb({ ok = false }) return end
    MySQL.update.await('DELETE FROM mdt_case_links WHERE id = ?', { data.id })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:addCasePersonnel', function(data, cb)
    if not data or not data.caseId or not data.officerId then cb({ ok = false }) return end
    MySQL.insert.await('INSERT IGNORE INTO mdt_case_personnel (case_id, officer_id, role) VALUES (?, ?, ?)', {
        data.caseId, data.officerId, data.role or 'assigned'
    })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:removeCasePersonnel', function(data, cb)
    if not data or not data.id then cb({ ok = false }) return end
    MySQL.update.await('DELETE FROM mdt_case_personnel WHERE id = ?', { data.id })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:getEvidence', function(data, cb)
    local page = (data and data.page) or 1
    local limit = 20
    local offset = (page - 1) * limit

    local evidence = MySQL.query.await([[
        SELECT e.*, o.first_name as collector_first, o.last_name as collector_last
        FROM mdt_evidence e LEFT JOIN mdt_officers o ON e.collected_by = o.id
        ORDER BY e.created_at DESC LIMIT ? OFFSET ?
    ]], { limit, offset }) or {}

    local countResult = MySQL.query.await('SELECT COUNT(*) as cnt FROM mdt_evidence') or {}
    local total = (countResult[1] and countResult[1].cnt) or 0

    cb({ ok = true, evidence = evidence, total = total, page = page })
end)

RegisterNUICallback('cortex_mdt:getEvidenceRecord', function(data, cb)
    local src = source
    local evidenceId = data and data.evidenceId
    if not evidenceId then cb({ ok = false }) return end

    local officerId = getOfficerId(src) or 0
    auditLog(officerId, 'evidence_view', 'evidence', 'evidence', evidenceId, nil)

    local evidence = MySQL.query.await([[
        SELECT e.*, o.first_name as collector_first, o.last_name as collector_last
        FROM mdt_evidence e LEFT JOIN mdt_officers o ON e.collected_by = o.id
        WHERE e.id = ?
    ]], { evidenceId })
    if not evidence or not evidence[1] then cb({ ok = false }) return end

    local custody = MySQL.query.await([[
        SELECT ec.*, fo.first_name as from_first, fo.last_name as from_last,
            too.first_name as to_first, too.last_name as to_last
        FROM mdt_evidence_custody ec
        LEFT JOIN mdt_officers fo ON ec.from_officer = fo.id
        LEFT JOIN mdt_officers too ON ec.to_officer = too.id
        WHERE ec.evidence_id = ? ORDER BY ec.created_at ASC
    ]], { evidenceId }) or {}

    cb({ ok = true, evidence = evidence[1], custody = custody })
end)

RegisterNUICallback('cortex_mdt:createEvidence', function(data, cb)
    local src = source
    if not data or not data.description then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    local prefix = getSetting('evidence_prefix') or 'EV'
    local evidenceTag = generateNumber(prefix)

    local id = MySQL.insert.await('INSERT INTO mdt_evidence (evidence_id, type, description, photo_url, stash_location, collected_by, report_id, case_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        evidenceTag, data.type or 'general', data.description, data.photoUrl or nil, data.stashLocation or nil, officerId, data.reportId or nil, data.caseId or nil
    })

    MySQL.insert.await('INSERT INTO mdt_evidence_custody (evidence_id, action, to_officer, to_location, notes) VALUES (?, ?, ?, ?, ?)', {
        id, 'Collected', officerId, data.stashLocation or 'N/A', 'Initial collection'
    })

    auditLog(officerId, 'evidence_create', 'evidence', 'evidence', id, { tag = evidenceTag })
    cb({ ok = true, evidenceId = id, evidenceTag = evidenceTag })
end)

RegisterNUICallback('cortex_mdt:transferEvidence', function(data, cb)
    local src = source
    if not data or not data.evidenceId then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

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
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:getBolos', function(data, cb)
    local filter = data and data.filter or 'active'
    local where = filter == 'all' and '' or ' WHERE b.status = "active"'

    local bolos = MySQL.query.await(([[
        SELECT b.*, o.first_name as officer_first, o.last_name as officer_last
        FROM mdt_bolos b LEFT JOIN mdt_officers o ON b.issued_by = o.id
        %s ORDER BY b.created_at DESC LIMIT 50
    ]]):format(where)) or {}

    cb({ ok = true, bolos = bolos })
end)

RegisterNUICallback('cortex_mdt:createBolo', function(data, cb)
    local src = source
    if not data or not data.title then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    local officer = MySQL.query.await('SELECT department FROM mdt_officers WHERE id = ?', { officerId })
    local dept = (officer and officer[1] and officer[1].department) or 'police'

    local id = MySQL.insert.await('INSERT INTO mdt_bolos (type, title, description, citizen_id, plate, vehicle_description, weapon_description, photo_url, issued_by, department, report_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.type or 'person', data.title, data.description or '', data.citizenId or nil,
        data.plate or nil, data.vehicleDescription or nil, data.weaponDescription or nil,
        data.photoUrl or nil, officerId, dept, data.reportId or nil
    })

    auditLog(officerId, 'bolo_create', 'bolo', 'bolo', id, nil)
    cb({ ok = true, boloId = id })
end)

RegisterNUICallback('cortex_mdt:updateBoloStatus', function(data, cb)
    local src = source
    if not data or not data.boloId or not data.status then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    MySQL.update.await('UPDATE mdt_bolos SET status = ? WHERE id = ?', { data.status, data.boloId })
    auditLog(officerId, 'bolo_status', 'bolo', 'bolo', data.boloId, { status = data.status })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:getWarrants', function(data, cb)
    local filter = data and data.filter or 'active'
    local where = filter == 'all' and '' or ' WHERE w.status = "active"'

    local warrants = MySQL.query.await(([[
        SELECT w.*, o.first_name as officer_first, o.last_name as officer_last
        FROM mdt_warrants w LEFT JOIN mdt_officers o ON w.issued_by = o.id
        %s ORDER BY w.created_at DESC LIMIT 50
    ]]):format(where)) or {}

    for i = 1, #warrants do
        warrants[i].charges = json.decode(warrants[i].charges) or {}
    end

    cb({ ok = true, warrants = warrants })
end)

RegisterNUICallback('cortex_mdt:createWarrant', function(data, cb)
    local src = source
    if not data or not data.citizenId or not data.citizenName then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    local officer = MySQL.query.await('SELECT department FROM mdt_officers WHERE id = ?', { officerId })
    local dept = (officer and officer[1] and officer[1].department) or 'police'

    local id = MySQL.insert.await('INSERT INTO mdt_warrants (citizen_id, citizen_name, charges, description, issued_by, department, report_id, bolo_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        data.citizenId, data.citizenName, json.encode(data.charges or {}), data.description or '',
        officerId, dept, data.reportId or nil, data.boloId or nil
    })

    auditLog(officerId, 'warrant_create', 'warrant', 'warrant', id, nil)
    cb({ ok = true, warrantId = id })
end)

RegisterNUICallback('cortex_mdt:updateWarrantStatus', function(data, cb)
    local src = source
    if not data or not data.warrantId or not data.status then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    MySQL.update.await('UPDATE mdt_warrants SET status = ? WHERE id = ?', { data.status, data.warrantId })
    auditLog(officerId, 'warrant_status', 'warrant', 'warrant', data.warrantId, { status = data.status })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:getUnits', function(_, cb)
    local units = MySQL.query.await([[
        SELECT u.*, o.first_name, o.last_name, o.`rank`, o.department as dept
        FROM mdt_units u LEFT JOIN mdt_officers o ON u.officer_id = o.id
        ORDER BY u.department ASC, u.callsign ASC
    ]]) or {}
    cb({ ok = true, units = units })
end)

RegisterNUICallback('cortex_mdt:updateUnitStatus', function(data, cb)
    local src = source
    if not data or not data.status then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0
    if officerId == 0 then cb({ ok = false }) return end

    local existing = MySQL.query.await('SELECT id FROM mdt_units WHERE officer_id = ?', { officerId })
    if existing and existing[1] then
        MySQL.update.await('UPDATE mdt_units SET status = ?, assignment = ? WHERE officer_id = ?', {
            data.status, data.assignment or nil, officerId
        })
    else
        local officer = MySQL.query.await('SELECT callsign, department FROM mdt_officers WHERE id = ?', { officerId })
        if officer and officer[1] then
            MySQL.insert.await('INSERT INTO mdt_units (callsign, officer_id, department, status, assignment) VALUES (?, ?, ?, ?, ?)', {
                officer[1].callsign or '', officerId, officer[1].department or 'police', data.status, data.assignment or nil
            })
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:goOnDuty', function(_, cb)
    local src = source
    local officerId = getOfficerId(src)
    if not officerId then cb({ ok = false }) return end

    local officer = MySQL.query.await('SELECT callsign, department FROM mdt_officers WHERE id = ?', { officerId })
    if officer and officer[1] then
        MySQL.query.await('INSERT INTO mdt_units (callsign, officer_id, department, status) VALUES (?, ?, ?, "available") ON DUPLICATE KEY UPDATE status = "available"', {
            officer[1].callsign or '', officerId, officer[1].department or 'police'
        })
    end
    ActiveOfficers[src] = officerId
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:goOffDuty', function(_, cb)
    local src = source
    local officerId = getOfficerId(src)
    if not officerId then cb({ ok = false }) return end

    MySQL.update.await('UPDATE mdt_units SET status = "off_duty" WHERE officer_id = ?', { officerId })
    ActiveOfficers[src] = nil
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:getRoster', function(_, cb)
    local officers = MySQL.query.await('SELECT * FROM mdt_officers ORDER BY department ASC, `rank` ASC, last_name ASC') or {}
    for i = 1, #officers do
        officers[i].certifications = json.decode(officers[i].certifications) or {}
    end
    cb({ ok = true, officers = officers })
end)

RegisterNUICallback('cortex_mdt:updateOfficerAdmin', function(data, cb)
    local src = source
    if not data or not data.officerId then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    MySQL.update.await('UPDATE mdt_officers SET `rank` = ?, callsign = ?, department = ?, certifications = ?, status = ? WHERE id = ?', {
        data.rank or 'Officer', data.callsign or '', data.department or 'police',
        json.encode(data.certifications or {}), data.status or 'active', data.officerId
    })
    auditLog(officerId, 'roster_update', 'admin', 'officer', data.officerId, { rank = data.rank, dept = data.department })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:getAuditLogs', function(data, cb)
    local page = (data and data.page) or 1
    local limit = 50
    local offset = (page - 1) * limit
    local filter = data and data.filter or ''

    local logs
    if filter ~= '' then
        local pattern = '%' .. filter .. '%'
        logs = MySQL.query.await([[
            SELECT al.*, o.first_name, o.last_name, o.callsign
            FROM mdt_audit_logs al LEFT JOIN mdt_officers o ON al.officer_id = o.id
            WHERE o.first_name LIKE ? OR o.last_name LIKE ? OR al.action LIKE ?
            ORDER BY al.created_at DESC LIMIT ? OFFSET ?
        ]], { pattern, pattern, pattern, limit, offset }) or {}
    else
        logs = MySQL.query.await([[
            SELECT al.*, o.first_name, o.last_name, o.callsign
            FROM mdt_audit_logs al LEFT JOIN mdt_officers o ON al.officer_id = o.id
            ORDER BY al.created_at DESC LIMIT ? OFFSET ?
        ]], { limit, offset }) or {}
    end

    for i = 1, #logs do
        logs[i].details = json.decode(logs[i].details) or {}
    end

    cb({ ok = true, logs = logs, page = page })
end)

RegisterNUICallback('cortex_mdt:getAnnouncements', function(_, cb)
    local announcements = MySQL.query.await([[
        SELECT a.*, o.first_name, o.last_name
        FROM mdt_announcements a LEFT JOIN mdt_officers o ON a.author_id = o.id
        WHERE a.active = 1 ORDER BY a.pinned DESC, a.created_at DESC
    ]]) or {}
    cb({ ok = true, announcements = announcements })
end)

RegisterNUICallback('cortex_mdt:createAnnouncement', function(data, cb)
    local src = source
    if not data or not data.title or not data.content then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    MySQL.insert.await('INSERT INTO mdt_announcements (title, content, author_id, department, pinned) VALUES (?, ?, ?, ?, ?)', {
        data.title, data.content, officerId, data.department or nil, data.pinned and 1 or 0
    })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:deleteAnnouncement', function(data, cb)
    if not data or not data.id then cb({ ok = false }) return end
    MySQL.update.await('UPDATE mdt_announcements SET active = 0 WHERE id = ?', { data.id })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:getSettings', function(_, cb)
    local settings = MySQL.query.await('SELECT * FROM mdt_settings') or {}
    local result = {}
    for i = 1, #settings do
        result[settings[i].key] = settings[i].value
    end
    cb({ ok = true, settings = result })
end)

RegisterNUICallback('cortex_mdt:updateSetting', function(data, cb)
    local src = source
    if not data or not data.key or not data.value then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0

    MySQL.query.await('INSERT INTO mdt_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = ?', {
        data.key, data.value, data.value
    })
    auditLog(officerId, 'setting_update', 'admin', 'setting', nil, { key = data.key })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:saveOfficerAvatar', function(data, cb)
    local src = source
    if not data then cb({ ok = false }) return end
    local officerId = getOfficerId(src) or 0
    if officerId == 0 then cb({ ok = false }) return end

    MySQL.update.await('UPDATE mdt_officers SET avatar = ? WHERE id = ?', { data.avatarUrl or nil, officerId })
    cb({ ok = true })
end)

RegisterNUICallback('cortex_mdt:searchOfficers', function(data, cb)
    local query = data and data.query or ''
    if #query < 1 then cb({ ok = true, officers = {} }) return end

    local pattern = '%' .. query .. '%'
    local officers = MySQL.query.await('SELECT id, first_name, last_name, callsign, `rank`, department FROM mdt_officers WHERE first_name LIKE ? OR last_name LIKE ? OR callsign LIKE ? LIMIT 10', { pattern, pattern, pattern }) or {}
    cb({ ok = true, officers = officers })
end)

RegisterNUICallback('cortex_mdt:getConfig', function(_, cb)
    cb({
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
        },
    })
end)

AddEventHandler('playerDropped', function()
    local src = source
    if ActiveOfficers[src] then
        local officerId = ActiveOfficers[src]
        MySQL.update('UPDATE mdt_units SET status = "off_duty" WHERE officer_id = ?', { officerId })
        ActiveOfficers[src] = nil
    end
end)
