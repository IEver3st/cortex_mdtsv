local Core = {}

local VALID_STATUSES = {
    available = true,
    busy = true,
    en_route = true,
    on_scene = true,
    emergency = true,
    off_duty = true,
}

local STATUS_ALIASES = {
    enroute = 'en_route',
    scene = 'on_scene',
    onscene = 'on_scene',
    offduty = 'off_duty',
}

function Core.trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

function Core.lower(value)
    return Core.trim(value):lower()
end

function Core.normalizePlate(value)
    return Core.trim(value):upper():gsub('%s+', '')
end

function Core.normalizeStatus(value, fallback)
    local status = Core.lower(value):gsub('%s+', '_')
    status = STATUS_ALIASES[status] or status

    if VALID_STATUSES[status] then
        return status
    end

    return fallback or 'off_duty'
end

function Core.nowIso()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

function Core.epoch()
    return os.time()
end

function Core.safeJsonEncode(value)
    local ok, encoded = pcall(json.encode, value)
    if ok then
        return encoded
    end
    return '{}'
end

function Core.ok(data)
    local response = type(data) == 'table' and data or {}
    response.ok = true
    return response
end

function Core.fail(message, code)
    return {
        ok = false,
        error = message or 'Request failed.',
        code = code,
    }
end

function Core.page(rows, page, limit)
    rows = type(rows) == 'table' and rows or {}
    page = math.max(1, tonumber(page) or 1)
    limit = math.max(1, math.min(100, tonumber(limit) or 25))

    local total = #rows
    local startIndex = ((page - 1) * limit) + 1
    local endIndex = math.min(total, startIndex + limit - 1)
    local items = {}

    for i = startIndex, endIndex do
        items[#items + 1] = rows[i]
    end

    return {
        rows = items,
        page = page,
        limit = limit,
        total = total,
    }
end

function Core.clampString(value, maxLength)
    local text = Core.trim(value)
    maxLength = tonumber(maxLength) or 255

    if #text > maxLength then
        return text:sub(1, maxLength)
    end

    return text
end

function Core.clampNumber(value, minValue, maxValue, fallback)
    local number = tonumber(value)
    if not number then
        return fallback or minValue or 0
    end

    if minValue ~= nil and number < minValue then
        number = minValue
    end

    if maxValue ~= nil and number > maxValue then
        number = maxValue
    end

    return number
end

function Core.sanitizeUrl(value)
    local url = Core.clampString(value, 512)
    if url == '' then
        return nil
    end

    if url:match('^https?://') or url:match('^nui://') or url:match('^data:image/') then
        return url
    end

    return nil
end

function Core.makeId(prefix, counter)
    prefix = Core.trim(prefix)
    counter = tonumber(counter) or Core.epoch()

    if prefix == '' then
        prefix = 'id'
    end

    return ('%s:%s'):format(prefix, counter)
end

function Core.getPlayerIdentifier(source)
    source = tonumber(source) or source
    local identifier = GetPlayerIdentifierByType and GetPlayerIdentifierByType(source, 'license') or nil
    if identifier and identifier ~= '' then
        return identifier
    end

    local identifiers = GetPlayerIdentifiers and GetPlayerIdentifiers(source) or {}
    return identifiers[1] or ('source:%s'):format(tostring(source or 0))
end

function Core.audit(source, action, category, targetType, targetId, details)
    local audit = rawget(_G, 'CortexAudit')
    if type(audit) == 'table' and type(audit.write) == 'function' then
        local officer = Core.requireOfficer(source)
        return audit.write(type(officer) == 'table' and (officer.id or officer.officerId) or 0, action, category, targetType, targetId, details, {
            officer = officer,
            source = source,
        })
    end

    return false
end

function Core.requireOfficer(source)
    local framework = rawget(_G, 'CortexMdtFramework')
    if type(framework) == 'table' and type(framework.getOfficer) == 'function' then
        local officer = framework.getOfficer(source)
        if type(officer) == 'table' then
            return officer
        end
    end

    local bridge = rawget(_G, 'CortexDutyBridge')
    if type(bridge) == 'table' and type(bridge.buildOfficerProfile) == 'function' then
        local ok, officer = pcall(bridge.buildOfficerProfile, source)
        if ok and type(officer) == 'table' then
            return officer
        end
    end

    return nil, 'Officer profile unavailable.'
end

function Core.requireAdmin(source, permission)
    local officer, err = Core.requireOfficer(source)
    if not officer then
        return nil, err
    end

    if officer.isAdmin or officer.admin or officer.role == 'admin' then
        return officer
    end

    local perms = officer.permissions
    if permission and type(perms) == 'table' and perms[permission] then
        return officer
    end

    return nil, 'Admin permission required.'
end

return Core
