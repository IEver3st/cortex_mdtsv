local existing = rawget(_G, 'CortexAudit')

if type(existing) == 'table' then
    return existing
end

local Audit = {}

local resourceName = GetCurrentResourceName()
local lastPurgeDay = nil
local sequence = 0
local cappedDays = {}

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function getConfig()
    local config = type(Config) == 'table' and type(Config.AuditLogs) == 'table' and Config.AuditLogs or {}
    local retentionDays = math.max(1, tonumber(config.retentionDays) or 14)
    local purgeLookbackDays = math.max(retentionDays, tonumber(config.purgeLookbackDays) or 365)

    return {
        enabled = config.enabled ~= false,
        retentionDays = retentionDays,
        maxDailyBytes = math.max(65536, tonumber(config.maxDailyBytes) or 5 * 1024 * 1024),
        maxDetailBytes = math.max(256, tonumber(config.maxDetailBytes) or 2048),
        purgeLookbackDays = purgeLookbackDays,
    }
end

local function getAuditDir()
    return ('%s/data/audit'):format(GetResourcePath(resourceName))
end

local function ensureAuditDir()
    local dir = getAuditDir()

    if lib and lib.mkdir then
        lib.mkdir(dir)
        return
    end

    os.execute(('mkdir "%s"'):format(dir))
end

local function dateKey(offsetDays)
    return os.date('!%Y-%m-%d', os.time() - ((tonumber(offsetDays) or 0) * 86400))
end

local function logPath(day)
    return ('%s/%s.ndjson'):format(getAuditDir(), day)
end

local function cloneLimited(value, budget)
    local valueType = type(value)

    if valueType == 'string' then
        if #value <= budget then
            return value
        end

        return value:sub(1, math.max(0, budget - 12)) .. '...[trimmed]'
    end

    if valueType ~= 'table' then
        return value
    end

    local copy = {}
    local used = 2

    for key, entry in pairs(value) do
        if used >= budget then
            copy.truncated = true
            break
        end

        local keyText = tostring(key)
        local remaining = budget - used - #keyText
        if remaining <= 0 then
            copy.truncated = true
            break
        end

        local cloned = cloneLimited(entry, remaining)
        local encoded = json.encode(cloned)
        used = used + #keyText + #(encoded or '')
        copy[key] = cloned
    end

    return copy
end

local function normalizeOfficer(officer)
    officer = type(officer) == 'table' and officer or {}

    return {
        first_name = trim(officer.first_name or officer.firstName),
        last_name = trim(officer.last_name or officer.lastName),
        callsign = trim(officer.callsign),
        department = trim(officer.department or officer.departmentKey),
        rank = trim(officer.rank),
    }
end

local function buildEntry(officerId, action, category, targetType, targetId, details, context)
    context = type(context) == 'table' and context or {}
    sequence = sequence + 1

    local officer = normalizeOfficer(context.officer)
    local now = os.time()

    return {
        id = ('%s-%06d'):format(os.date('!%Y%m%d%H%M%S', now), sequence),
        officer_id = tonumber(officerId) or 0,
        action = trim(action) ~= '' and trim(action) or 'unknown',
        category = trim(category) ~= '' and trim(category) or 'general',
        target_type = trim(targetType) ~= '' and trim(targetType) or nil,
        target_id = targetId,
        details = cloneLimited(details or {}, getConfig().maxDetailBytes),
        created_at = os.date('!%Y-%m-%dT%H:%M:%SZ', now),
        created_sort = now,
        source = tonumber(context.source) or nil,
        first_name = officer.first_name,
        last_name = officer.last_name,
        callsign = officer.callsign,
        department = officer.department,
        rank = officer.rank,
    }
end

local function fileSize(path)
    local file = io.open(path, 'r')

    if not file then
        return 0
    end

    local size = file:seek('end') or 0
    file:close()
    return size
end

local function purgeOldFiles()
    local config = getConfig()
    local today = dateKey(0)

    if lastPurgeDay == today then
        return
    end

    lastPurgeDay = today

    for offset = config.retentionDays, config.purgeLookbackDays do
        os.remove(logPath(dateKey(offset)))
    end
end

function Audit.write(officerId, action, category, targetType, targetId, details, context)
    local config = getConfig()

    if not config.enabled then
        return nil
    end

    ensureAuditDir()
    purgeOldFiles()

    local today = dateKey(0)
    local path = logPath(today)
    if fileSize(path) >= config.maxDailyBytes then
        if cappedDays[today] then
            return nil
        end

        cappedDays[today] = true
        officerId = 0
        action = 'audit_daily_cap_reached'
        category = 'system'
        targetType = 'audit'
        targetId = nil
        details = {
            maxDailyBytes = config.maxDailyBytes,
        }
        context = nil
    end

    local entry = buildEntry(officerId, action, category, targetType, targetId, details, context)
    local file = io.open(path, 'a')

    if not file then
        print(('[cortex_mdt] WARNING: unable to open audit log for append: %s'):format(path))
        return nil
    end

    file:write(json.encode(entry), '\n')
    file:close()

    return entry
end

local function matchesFilter(entry, filter)
    local query = trim(filter):lower()

    if query == '' then
        return true
    end

    local haystack = ('%s %s %s %s %s %s %s'):format(
        entry.first_name or '',
        entry.last_name or '',
        entry.callsign or '',
        entry.action or '',
        entry.category or '',
        entry.target_type or '',
        json.encode(entry.details or {})
    ):lower()

    return haystack:find(query, 1, true) ~= nil
end

function Audit.getLogs(page, filter, limit)
    local config = getConfig()
    local pageNumber = math.max(1, tonumber(page) or 1)
    local pageSize = math.max(1, math.min(100, tonumber(limit) or 50))
    local offset = (pageNumber - 1) * pageSize
    local skipped = 0
    local rows = {}

    if not config.enabled then
        return rows
    end

    purgeOldFiles()

    for dayOffset = 0, config.retentionDays - 1 do
        local file = io.open(logPath(dateKey(dayOffset)), 'r')

        if file then
            local dayRows = {}

            for line in file:lines() do
                local ok, entry = pcall(json.decode, line)
                if ok and type(entry) == 'table' and matchesFilter(entry, filter) then
                    dayRows[#dayRows + 1] = entry
                end
            end

            file:close()

            for index = #dayRows, 1, -1 do
                if skipped < offset then
                    skipped = skipped + 1
                else
                    rows[#rows + 1] = dayRows[index]
                    if #rows >= pageSize then
                        return rows
                    end
                end
            end
        end
    end

    return rows
end

function Audit.countByOfficer(days)
    local config = getConfig()
    local maxDays = math.max(1, math.min(config.retentionDays, tonumber(days) or config.retentionDays))
    local counts = {}

    if not config.enabled then
        return counts
    end

    for dayOffset = 0, maxDays - 1 do
        local file = io.open(logPath(dateKey(dayOffset)), 'r')

        if file then
            for line in file:lines() do
                local ok, entry = pcall(json.decode, line)
                local officerId = ok and type(entry) == 'table' and tonumber(entry.officer_id) or nil

                if officerId then
                    counts[officerId] = (counts[officerId] or 0) + 1
                end
            end

            file:close()
        end
    end

    return counts
end

_G.CortexAudit = Audit

return Audit
