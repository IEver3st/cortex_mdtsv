local Provider = {}

local function trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$') or ''
end

local function getBridgeOfficer(source)
    local bridge = rawget(_G, 'CortexDutyBridge')
    if type(bridge) == 'table' and type(bridge.buildOfficerProfile) == 'function' then
        local ok, officer = pcall(bridge.buildOfficerProfile, source)
        if ok and type(officer) == 'table' then
            return officer
        end
    end
    return nil
end

local function getLocalMode()
    local localMode = rawget(_G, 'CortexLocalMode')
    if type(localMode) == 'table' then
        return localMode
    end
    return nil
end

local function getStandaloneUnit(source)
    source = tonumber(source) or source
    if not source then
        return nil
    end

    local localMode = getLocalMode()
    if not localMode
        or type(localMode.getOfficerId) ~= 'function'
        or type(localMode.getOfficerUnitRow) ~= 'function' then
        return nil
    end

    local okOfficer, officerId = pcall(localMode.getOfficerId, source)
    if not okOfficer or not officerId then
        return nil
    end

    local okUnit, unit = pcall(localMode.getOfficerUnitRow, officerId)
    if not okUnit or type(unit) ~= 'table' then
        return nil
    end

    return unit
end

local function buildFallbackOfficer(source)
    return {
        id = tostring(source),
        citizenId = tostring(source),
        firstName = GetPlayerName(source) or 'Officer',
        lastName = '',
        frameworkMode = 'standalone',
    }
end

function Provider.getMode()
    return 'standalone'
end

function Provider.getOfficer(source)
    local officer = getBridgeOfficer(source) or buildFallbackOfficer(source)
    local unit = getStandaloneUnit(source)

    if unit then
        local status = trim(unit.status):lower()
        officer.status = status ~= '' and status or 'off_duty'
        officer.assignment = trim(unit.assignment)

        local callsign = trim(unit.callsign)
        if callsign ~= '' then
            officer.callsign = callsign
        end

        local department = trim(unit.department)
        if department ~= '' then
            officer.departmentKey = department
        end
    else
        officer.status = 'off_duty'
        officer.assignment = ''
    end

    return officer
end

function Provider.getCivilian(source)
    local standalone = rawget(_G, 'CortexStandaloneCivilian')
    if type(standalone) == 'table' and type(standalone.getCivilianProfile) == 'function' then
        return standalone.getCivilianProfile(source)
    end
    return {
        firstName = GetPlayerName(source) or 'Citizen',
        lastName = '',
        citizenId = nil,
    }
end

function Provider.isOnDuty(source)
    local unit = getStandaloneUnit(source)
    local status = unit and trim(unit.status):lower() or 'off_duty'
    return status ~= '' and status ~= 'off_duty'
end

function Provider.setDuty(source, enabled)
    local bridge = rawget(_G, 'CortexDutyBridge')
    if type(bridge) == 'table' and type(bridge.syncErsPoliceDuty) == 'function' then
        local ok, result = pcall(bridge.syncErsPoliceDuty, source, enabled == true)
        return ok and type(result) == 'table' and result.ok == true
    end
    return true
end

function Provider.getStableIdentifier(source)
    return (GetPlayerIdentifierByType and GetPlayerIdentifierByType(source, 'license')) or tostring(source)
end

function Provider.getDepartment(source)
    local unit = getStandaloneUnit(source)
    local department = unit and trim(unit.department) or ''
    if department ~= '' then
        return department
    end
    return (Config and Config.DefaultDepartment) or 'police'
end

return Provider