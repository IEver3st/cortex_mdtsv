local Provider = {}

local function getQboxResource()
    local resources = Config and Config.FrameworkResources or {}
    return resources.qbx or resources.qbox or 'qbx_core'
end

local function getPlayer(source)
    local resource = getQboxResource()
    if GetResourceState and GetResourceState(resource) ~= 'started' then
        return nil
    end

    local ok, player = pcall(function()
        return exports[resource]:GetPlayer(source)
    end)

    if ok then
        return player
    end

    return nil
end

local function getCharInfo(player)
    local data = player and player.PlayerData or {}
    return data.charinfo or {}
end

function Provider.getMode()
    return 'qbx'
end

function Provider.getOfficer(source)
    local bridge = rawget(_G, 'CortexDutyBridge')
    if type(bridge) == 'table' and type(bridge.buildOfficerProfile) == 'function' then
        local ok, officer = pcall(bridge.buildOfficerProfile, source)
        if ok and type(officer) == 'table' then
            return officer
        end
    end

    local player = getPlayer(source)
    if not player then
        return nil
    end

    local data = player.PlayerData or {}
    local charinfo = getCharInfo(player)
    return {
        id = data.citizenid,
        citizenId = data.citizenid,
        firstName = charinfo.firstname,
        lastName = charinfo.lastname,
        job = data.job,
        frameworkMode = 'qbx',
    }
end

function Provider.getCivilian(source)
    local player = getPlayer(source)
    if not player then
        return nil
    end

    local data = player.PlayerData or {}
    local charinfo = getCharInfo(player)
    return {
        citizenId = data.citizenid,
        firstName = charinfo.firstname,
        lastName = charinfo.lastname,
    }
end

function Provider.isOnDuty(source)
    local player = getPlayer(source)
    local job = player and player.PlayerData and player.PlayerData.job
    return type(job) == 'table' and job.onduty == true
end

function Provider.setDuty(source, enabled)
    local player = getPlayer(source)
    if player and type(player.Functions) == 'table' and type(player.Functions.SetJobDuty) == 'function' then
        player.Functions.SetJobDuty(enabled == true)
        return true
    end
    return false
end

function Provider.getStableIdentifier(source)
    local player = getPlayer(source)
    local data = player and player.PlayerData or {}
    return data.citizenid or (GetPlayerIdentifierByType and GetPlayerIdentifierByType(source, 'license')) or tostring(source)
end

function Provider.getDepartment(source)
    local player = getPlayer(source)
    local job = player and player.PlayerData and player.PlayerData.job
    if type(job) == 'table' then
        return job.name
    end
    return nil
end

return Provider
