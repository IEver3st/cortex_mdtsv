local Citations = {}

local resourceName = GetCurrentResourceName()

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function isoTimestamp()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function epoch()
    return os.time()
end

local function citNumber(prefix, counter)
    return ('%s-%s-%04d'):format(prefix or 'CIT', os.date('%Y%m%d'), counter)
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

function Citations.setupLocalMode(LocalMode)
    Citations.LM = LocalMode
end

function Citations.isEnabled()
    return Config.Citations and Config.Citations.enabled ~= false
end

function Citations.issueCitation(LocalMode, source, data)
    if not Citations.isEnabled() then
        return { ok = false, error = 'Citation system is disabled in config.' }
    end

    local reportId = tonumber(data and data.reportId)
    local citizenId = trim(data and data.citizenId)
    local playerName = trim(data and data.playerName)

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

    local recipientName = playerName ~= '' and playerName or citizenId
    for i = 1, #participants do
        local p = participants[i]
        if trim(p.citizenId or p.citizen_id) == citizenId then
            recipientName = trim(p.name) ~= '' and trim(p.name) or recipientName
            break
        end
    end

    local officerId = LocalMode.getOfficerId(source) or 0
    local officer = officerId > 0 and LocalMode.getOfficer(officerId) or nil
    local deptKey = officer and trim(officer.department) or 'police'
    local dept = Config.Departments[deptKey] or Config.Departments['police'] or { label = 'Los Santos Police Department', short = 'LSPD' }

    local cid = LocalMode.getNextCitationId and LocalMode.getNextCitationId()
        or (Citations._nextId or 1)

    local totalFine = 0
    for i = 1, #charges do
        totalFine = totalFine + (tonumber(charges[i].fine or 0) or 0) * (tonumber(charges[i].count or 1) or 1)
    end

    local citation = {
        id = cid,
        citation_number = citNumber('CIT', cid),
        report_number = report.report_number or ('RPT-' .. reportId),
        report_id = reportId,
        report_title = report.title or '',
        issued_by = {
            callsign = officer and trim(officer.callsign) or '',
            name = officer and trim(('%s %s'):format(officer.first_name or '', officer.last_name or '')):gsub('%s+', ' ') or 'Unknown Officer',
            rank = officer and trim(officer.rank) or 'Officer',
            department = dept.label,
            department_short = dept.short,
        },
        issued_to = {
            citizen_id = citizenId,
            name = recipientName,
        },
        issued_at = isoTimestamp(),
        issued_sort = epoch(),
        status = 'pending',
        charges = clone(charges),
        total_fine = totalFine,
        notes = trim(data.notes),
    }

    if not Citations._citations then
        Citations._citations = {}
    end
    Citations._citations[cid] = citation
    if not Citations._nextId or cid >= Citations._nextId then
        Citations._nextId = cid + 1
    end

    return {
        ok = true,
        citation = clone(citation),
    }
end

function Citations.getCitationsForCitizen(citizenId)
    if not Citations.isEnabled() then
        return { ok = true, citations = {} }
    end

    local results = {}
    for _, cit in pairs(Citations._citations or {}) do
        if cit.issued_to and cit.issued_to.citizen_id == citizenId then
            results[#results + 1] = clone(cit)
        end
    end

    table.sort(results, function(a, b)
        return (a.issued_sort or 0) > (b.issued_sort or 0)
    end)

    return { ok = true, citations = results }
end

function Citations.getCitation(citationId)
    if not Citations.isEnabled() then
        return { ok = false, error = 'Citation system is disabled.' }
    end

    local cit = Citations._citations and Citations._citations[tonumber(citationId) or -1]
    if not cit then
        return { ok = false, error = 'Citation not found.' }
    end

    return { ok = true, citation = clone(cit) }
end

function Citations.markCitationViewed(citationId)
    local cit = Citations._citations and Citations._citations[tonumber(citationId) or -1]
    if not cit then
        return { ok = false, error = 'Citation not found.' }
    end

    if cit.status == 'pending' then
        cit.status = 'viewed'
    end

    return { ok = true, citation = clone(cit) }
end

function Citations.persistCitations()
    if not Citations._citations then
        return
    end
    local data = {
        nextId = Citations._nextId or 1,
        citations = {},
    }
    for id, cit in pairs(Citations._citations) do
        data.citations[tostring(id)] = cit
    end
    return data
end

function Citations.restoreCitations(data)
    if type(data) ~= 'table' then
        Citations._citations = {}
        Citations._nextId = 1
        return
    end
    Citations._nextId = tonumber(data.nextId) or 1
    Citations._citations = {}
    if type(data.citations) == 'table' then
        for id, cit in pairs(data.citations) do
            Citations._citations[tonumber(id)] = clone(cit)
        end
    end
end

function Citations.getNextCitationId()
    local cid = Citations._nextId or 1
    Citations._nextId = cid + 1
    return cid
end

return Citations
