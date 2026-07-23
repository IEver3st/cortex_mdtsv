local Provider = {}

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

function Provider.getMode()
    return 'standalone'
end

function Provider.getOfficer(source)
    return getBridgeOfficer(source) or {
        id = tostring(source),
        citizenId = tostring(source),
        firstName = GetPlayerName(source) or 'Officer',
        lastName = '',
        frameworkMode = 'standalone',
    }
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
    local officer = getBridgeOfficer(source)
    return type(officer) == 'table' and officer.status ~= 'off_duty'
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

function Provider.getDepartment()
    return 'standalone'
end

return Provider
