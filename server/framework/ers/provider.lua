local Provider = {}

local function getBridge()
    local bridge = rawget(_G, 'CortexDutyBridge')
    return type(bridge) == 'table' and bridge or nil
end

function Provider.getMode()
    return 'ers'
end

function Provider.getOfficer(source)
    local bridge = getBridge()
    if bridge and type(bridge.buildOfficerProfile) == 'function' then
        local ok, officer = pcall(bridge.buildOfficerProfile, source)
        if ok and type(officer) == 'table' then
            return officer
        end
    end
    return nil
end

function Provider.getCivilian(source)
    local standalone = rawget(_G, 'CortexStandaloneCivilian')
    if type(standalone) == 'table' and type(standalone.getCivilianProfile) == 'function' then
        return standalone.getCivilianProfile(source)
    end
    return nil
end

function Provider.isOnDuty(source)
    local officer = Provider.getOfficer(source)
    return type(officer) == 'table' and officer.status ~= 'off_duty'
end

function Provider.setDuty(source, enabled)
    local bridge = getBridge()
    if bridge and type(bridge.syncErsPoliceDuty) == 'function' then
        local ok, result = pcall(bridge.syncErsPoliceDuty, source, enabled == true)
        return ok and type(result) == 'table' and result.ok == true
    end
    return false
end

function Provider.getStableIdentifier(source)
    return (GetPlayerIdentifierByType and GetPlayerIdentifierByType(source, 'license')) or tostring(source)
end

function Provider.getDepartment(source)
    local officer = Provider.getOfficer(source)
    return officer and (officer.department or officer.job or officer.agency) or 'ers'
end

return Provider
