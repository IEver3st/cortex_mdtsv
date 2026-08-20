local function trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$') or ''
end

local function playerExists(source)
    source = tonumber(source)
    return source and source > 0 and GetPlayerName(source) ~= nil
end

local function getFramework()
    local framework = rawget(_G, 'CortexMdtFramework')
    if type(framework) == 'table' then
        return framework
    end
    return nil
end

local function getDutyState(source)
    source = tonumber(source)
    if not playerExists(source) then
        return {
            ok = false,
            onDuty = false,
            status = 'offline',
            code = 'player_unavailable',
        }
    end

    local framework = getFramework()
    if not framework or type(framework.isOnDuty) ~= 'function' then
        return {
            ok = false,
            source = source,
            onDuty = false,
            status = 'off_duty',
            code = 'duty_unavailable',
        }
    end

    local okDuty, onDuty = pcall(framework.isOnDuty, source)
    if not okDuty then
        return {
            ok = false,
            source = source,
            onDuty = false,
            status = 'off_duty',
            code = 'duty_lookup_failed',
        }
    end

    local officer = nil
    if type(framework.getOfficer) == 'function' then
        local okOfficer, result = pcall(framework.getOfficer, source)
        if okOfficer and type(result) == 'table' then
            officer = result
        end
    end

    local status = officer and trim(officer.status):lower() or ''
    if onDuty == true then
        if status == '' or status == 'off_duty' then
            status = 'available'
        end
    else
        status = 'off_duty'
    end

    local frameworkMode = ''
    if type(framework.getMode) == 'function' then
        local okMode, mode = pcall(framework.getMode)
        if okMode then
            frameworkMode = trim(mode):lower()
        end
    end

    return {
        ok = true,
        source = source,
        onDuty = onDuty == true,
        status = status,
        callsign = officer and trim(officer.callsign) or '',
        department = officer and trim(officer.departmentKey or officer.department) or '',
        frameworkMode = frameworkMode,
    }
end

exports('getOfficerDutyState', getDutyState)

exports('isPlayerOnMdtDuty', function(source)
    local state = getDutyState(source)
    return state.ok == true and state.onDuty == true
end)

_G.CortexMdtDutyIntegration = {
    getOfficerDutyState = getDutyState,
    isOnDuty = function(source)
        local state = getDutyState(source)
        return state.ok == true and state.onDuty == true
    end,
}

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        _G.CortexMdtDutyIntegration = nil
    end
end)
